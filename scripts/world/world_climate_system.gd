extends Node
class_name WorldClimateSystem

## Estado ambiental del mundo. Centraliza clima y fenómenos naturales para que
## los efectos visuales, el audio, la fauna y el gameplay puedan suscribirse
## sin depender entre sí.

signal clima_transicion_iniciada(estado_objetivo: Dictionary)
signal clima_cambiado(estado: Dictionary)
signal fenomeno_iniciado(fenomeno: Dictionary)
signal fenomeno_finalizado(tipo: String)

const PERFILES_CLIMA: Dictionary = {
	"despejado": {
		"cobertura_nubes": 0.08, "precipitacion": 0.0,
		"viento": 0.12, "humedad": 0.30, "visibilidad": 1.0
	},
	"nublado": {
		"cobertura_nubes": 0.78, "precipitacion": 0.0,
		"viento": 0.22, "humedad": 0.58, "visibilidad": 0.88
	},
	"lluvia": {
		"cobertura_nubes": 0.94, "precipitacion": 0.72,
		"viento": 0.42, "humedad": 0.92, "visibilidad": 0.72
	},
	"tormenta": {
		"cobertura_nubes": 1.0, "precipitacion": 1.0,
		"viento": 0.88, "humedad": 1.0, "visibilidad": 0.48
	},
	"niebla": {
		"cobertura_nubes": 0.62, "precipitacion": 0.0,
		"viento": 0.04, "humedad": 0.96, "visibilidad": 0.28
	},
	"nieve": {
		"cobertura_nubes": 0.88, "precipitacion": 0.68,
		"viento": 0.30, "humedad": 0.82, "visibilidad": 0.66
	},
	"ola_calor": {
		"cobertura_nubes": 0.06, "precipitacion": 0.0,
		"viento": 0.08, "humedad": 0.18, "visibilidad": 0.94
	}
}

const FENOMENOS_VALIDOS: Array[String] = [
	"tormenta_electrica",
	"terremoto",
	"viento_extremo",
	"inundacion",
	"granizada"
]

var _clima_actual: Dictionary = {
	"tipo": "despejado",
	"intensidad": 1.0,
	"cobertura_nubes": 0.08,
	"precipitacion": 0.0,
	"viento": 0.12,
	"humedad": 0.30,
	"visibilidad": 1.0
}
var _clima_objetivo: Dictionary = {}
var _clima_origen: Dictionary = {}
var _transicion_duracion: float = 0.0
var _transicion_transcurrida: float = 0.0
var _fenomenos_activos: Dictionary = {}


func _process(delta: float) -> void:
	_actualizar_transicion_clima(delta)
	_actualizar_fenomenos(delta)


func establecer_clima(
	tipo: String,
	intensidad: float = 1.0,
	duracion_transicion: float = 8.0
) -> bool:
	if not PERFILES_CLIMA.has(tipo):
		push_warning("WorldClimateSystem: perfil de clima desconocido: " + tipo)
		return false

	var fuerza := clampf(intensidad, 0.0, 1.0)
	var perfil: Dictionary = PERFILES_CLIMA[tipo].duplicate(true)
	_clima_origen = _clima_actual.duplicate(true)
	_clima_objetivo = {
		"tipo": tipo,
		"intensidad": fuerza
	}
	for propiedad in perfil:
		var valor := float(perfil[propiedad])
		if propiedad in ["cobertura_nubes", "precipitacion", "viento"]:
			valor *= fuerza
		_clima_objetivo[propiedad] = valor

	_transicion_duracion = maxf(duracion_transicion, 0.0)
	_transicion_transcurrida = 0.0
	if _transicion_duracion <= 0.0:
		_clima_actual = _clima_objetivo.duplicate(true)
		_clima_objetivo.clear()
		_clima_origen.clear()
		clima_cambiado.emit(obtener_estado())
	else:
		clima_transicion_iniciada.emit(_clima_objetivo.duplicate(true))
	return true


func _actualizar_transicion_clima(delta: float) -> void:
	if _clima_objetivo.is_empty():
		return
	_transicion_transcurrida = minf(
		_transicion_transcurrida + delta,
		_transicion_duracion
	)
	var progreso := clampf(
		_transicion_transcurrida / maxf(_transicion_duracion, 0.001),
		0.0,
		1.0
	)
	progreso = progreso * progreso * (3.0 - 2.0 * progreso)

	var nuevo_estado := {
		"tipo": str(_clima_origen.get("tipo", "despejado")),
		"intensidad": lerpf(
			float(_clima_origen.get("intensidad", 1.0)),
			float(_clima_objetivo["intensidad"]),
			progreso
		)
	}
	for propiedad in ["cobertura_nubes", "precipitacion", "viento", "humedad", "visibilidad"]:
		nuevo_estado[propiedad] = lerpf(
			float(_clima_origen.get(propiedad, _clima_objetivo[propiedad])),
			float(_clima_objetivo[propiedad]),
			progreso
		)
	_clima_actual = nuevo_estado

	if _transicion_transcurrida >= _transicion_duracion:
		_clima_actual = _clima_objetivo.duplicate(true)
		_clima_objetivo.clear()
		_clima_origen.clear()
		clima_cambiado.emit(obtener_estado())


func iniciar_fenomeno(
	tipo: String,
	intensidad: float = 1.0,
	duracion_segundos: float = 0.0
) -> bool:
	if not FENOMENOS_VALIDOS.has(tipo):
		push_warning("WorldClimateSystem: fenómeno desconocido: " + tipo)
		return false
	var fenomeno := {
		"tipo": tipo,
		"intensidad": clampf(intensidad, 0.0, 1.0),
		"duracion_restante": maxf(duracion_segundos, 0.0)
	}
	_fenomenos_activos[tipo] = fenomeno
	fenomeno_iniciado.emit(fenomeno.duplicate(true))
	return true


func finalizar_fenomeno(tipo: String) -> bool:
	if not _fenomenos_activos.has(tipo):
		return false
	_fenomenos_activos.erase(tipo)
	fenomeno_finalizado.emit(tipo)
	return true


func _actualizar_fenomenos(delta: float) -> void:
	var finalizados: Array[String] = []
	for tipo_variant in _fenomenos_activos:
		var tipo := str(tipo_variant)
		var fenomeno: Dictionary = _fenomenos_activos[tipo]
		var restante := float(fenomeno.get("duracion_restante", 0.0))
		if restante <= 0.0:
			continue
		restante = maxf(restante - delta, 0.0)
		fenomeno["duracion_restante"] = restante
		_fenomenos_activos[tipo] = fenomeno
		if restante <= 0.0:
			finalizados.append(tipo)
	for tipo in finalizados:
		finalizar_fenomeno(tipo)


func obtener_estado() -> Dictionary:
	return {
		"clima": _clima_actual.duplicate(true),
		"en_transicion": not _clima_objetivo.is_empty(),
		"clima_objetivo": _clima_objetivo.duplicate(true),
		"fenomenos": _fenomenos_activos.duplicate(true)
	}


func obtener_clima_id() -> String:
	return str(_clima_actual.get("tipo", "despejado"))
