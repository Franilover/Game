extends Node
class_name WorldClimateSystem

## Simulacion climatica determinista. Las reglas estacionales y los factores
## ambientales proceden de WorldData; el cliente sólo resuelve y ejecuta.

signal clima_transicion_iniciada(estado_objetivo: Dictionary)
signal clima_cambiado(estado: Dictionary)
signal fenomeno_iniciado(fenomeno: Dictionary)
signal fenomeno_finalizado(tipo: String)
signal evento_estacional_iniciado(evento: Dictionary)
signal evento_estacional_finalizado(clave: String)

const PERFILES_CLIMA: Dictionary = {
	"despejado": {
		"cobertura_nubes": 0.08, "precipitacion": 0.0,
		"viento": 0.12, "humedad": 0.30, "visibilidad": 1.0,
		"temperatura_delta_c": 0.0
	},
	"nublado": {
		"cobertura_nubes": 0.78, "precipitacion": 0.0,
		"viento": 0.22, "humedad": 0.58, "visibilidad": 0.88,
		"temperatura_delta_c": -1.0
	},
	"lluvia": {
		"cobertura_nubes": 0.94, "precipitacion": 0.72,
		"viento": 0.42, "humedad": 0.92, "visibilidad": 0.72,
		"temperatura_delta_c": -2.0
	},
	"tormenta": {
		"cobertura_nubes": 1.0, "precipitacion": 1.0,
		"viento": 0.88, "humedad": 1.0, "visibilidad": 0.48,
		"temperatura_delta_c": -3.0
	},
	"niebla": {
		"cobertura_nubes": 0.62, "precipitacion": 0.0,
		"viento": 0.04, "humedad": 0.96, "visibilidad": 0.28,
		"temperatura_delta_c": -1.0
	},
	"nieve": {
		"cobertura_nubes": 0.88, "precipitacion": 0.68,
		"viento": 0.30, "humedad": 0.82, "visibilidad": 0.66,
		"temperatura_delta_c": -5.0
	},
	"ola_calor": {
		"cobertura_nubes": 0.06, "precipitacion": 0.0,
		"viento": 0.08, "humedad": 0.18, "visibilidad": 0.94,
		"temperatura_delta_c": 4.0
	}
}

const FENOMENOS_VALIDOS: Array[String] = [
	"tormenta_electrica", "terremoto", "viento_extremo",
	"inundacion", "granizada"
]
const PROPIEDADES_CLIMA: Array[String] = [
	"cobertura_nubes", "precipitacion", "viento",
	"humedad", "visibilidad", "temperatura_delta_c"
]

var _clima_actual: Dictionary = {
	"tipo": "despejado",
	"intensidad": 1.0,
	"cobertura_nubes": 0.08,
	"precipitacion": 0.0,
	"viento": 0.12,
	"humedad": 0.30,
	"visibilidad": 1.0,
	"temperatura_delta_c": 0.0
}
var _clima_objetivo: Dictionary = {}
var _clima_origen: Dictionary = {}
var _transicion_duracion: float = 0.0
var _transicion_transcurrida: float = 0.0
var _fenomenos_activos: Dictionary = {}
var _eventos_estacionales_activos: Dictionary = {}
var _world_data: WorldDataService
var _world_atmosphere: WorldAtmosphere
var _world_context: WorldContext
var _estados_contexto_cache: Dictionary = {}
var _clave_dia_actual: String = ""


func configurar_dependencias(
	world_data: WorldDataService,
	world_atmosphere: WorldAtmosphere,
	world_context: WorldContext = null
) -> void:
	_world_data = world_data
	_world_atmosphere = world_atmosphere
	_world_context = world_context
	if _world_atmosphere == null:
		push_error("WorldClimateSystem: WorldAtmosphere es obligatorio.")
		return
	if not _world_atmosphere.dia_cambiado.is_connected(_al_cambiar_dia):
		_world_atmosphere.dia_cambiado.connect(_al_cambiar_dia)
	if not _world_atmosphere.estacion_cambiada.is_connected(_al_cambiar_estacion):
		_world_atmosphere.estacion_cambiada.connect(_al_cambiar_estacion)
	if _world_data != null:
		if not _world_data.mundo_listo.is_connected(_al_recibir_datos_mundo):
			_world_data.mundo_listo.connect(_al_recibir_datos_mundo)
		if not _world_data.mundo_actualizado.is_connected(_al_recibir_datos_mundo):
			_world_data.mundo_actualizado.connect(_al_recibir_datos_mundo)
	if _world_data != null and _world_data.esta_cargado():
		_al_recibir_datos_mundo()
	else:
		_actualizar_clima_diario()


func _al_recibir_datos_mundo() -> void:
	_estados_contexto_cache.clear()
	_actualizar_clima_diario()


func _process(delta: float) -> void:
	_actualizar_transicion_clima(delta)
	_actualizar_fenomenos(delta)


func _al_cambiar_dia(_dia: int, _anio: int) -> void:
	_actualizar_clima_diario()


func _al_cambiar_estacion(_estacion: Dictionary) -> void:
	_actualizar_clima_diario()


func _actualizar_clima_diario() -> void:
	_estados_contexto_cache.clear()
	if _world_atmosphere == null or _world_atmosphere.estacion_actual.is_empty():
		return
	var estado := obtener_estado_para_contexto({})
	var clima: Dictionary = estado.get("clima", {})
	establecer_clima(
		str(clima.get("tipo", "despejado")),
		float(clima.get("intensidad", 1.0)),
		_obtener_duracion_transicion()
	)
	_actualizar_eventos_estacionales()


func _obtener_duracion_transicion() -> float:
	var regla := _obtener_regla_climatica({})
	return maxf(float(regla.get("transicion_segundos", 8.0)), 0.0)


func establecer_clima(
	tipo: String,
	intensidad: float = 1.0,
	duracion_transicion: float = 8.0,
	efectos_adicionales: Dictionary = {}
) -> bool:
	if not PERFILES_CLIMA.has(tipo):
		push_warning("WorldClimateSystem: perfil de clima desconocido: " + tipo)
		return false

	var fuerza := clampf(intensidad, 0.0, 1.0)
	var perfil: Dictionary = PERFILES_CLIMA[tipo].duplicate(true)
	for propiedad in PROPIEDADES_CLIMA:
		if efectos_adicionales.has(propiedad):
			perfil[propiedad] = float(efectos_adicionales[propiedad])
	_clima_origen = _clima_actual.duplicate(true)
	_clima_objetivo = {"tipo": tipo, "intensidad": fuerza}
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
	_transicion_transcurrida = minf(_transicion_transcurrida + delta, _transicion_duracion)
	var progreso := clampf(_transicion_transcurrida / maxf(_transicion_duracion, 0.001), 0.0, 1.0)
	progreso = progreso * progreso * (3.0 - 2.0 * progreso)
	var nuevo_estado := {
		"tipo": str(_clima_origen.get("tipo", "despejado")),
		"intensidad": lerpf(
			float(_clima_origen.get("intensidad", 1.0)),
			float(_clima_objetivo["intensidad"]),
			progreso
		)
	}
	for propiedad in PROPIEDADES_CLIMA:
		nuevo_estado[propiedad] = lerpf(
			float(_clima_origen.get(propiedad, _clima_objetivo.get(propiedad, 0.0))),
			float(_clima_objetivo.get(propiedad, 0.0)),
			progreso
		)
	_clima_actual = nuevo_estado
	if _transicion_transcurrida >= _transicion_duracion:
		_clima_actual = _clima_objetivo.duplicate(true)
		_clima_objetivo.clear()
		_clima_origen.clear()
		clima_cambiado.emit(obtener_estado())


func obtener_estado_para_posicion(
	posicion_global: Vector2,
	habitat_clave: String = ""
) -> Dictionary:
	if _world_context == null or not _world_context.tiene_mundo_activo():
		return obtener_estado_para_contexto({})
	var tile := _world_context.get_tile_at(posicion_global)
	var contexto_mundo := _world_context.get_contexto_data_at(tile)
	if contexto_mundo.is_empty():
		return obtener_estado_para_contexto({})
	var bioma_variant: Variant = contexto_mundo.get("bioma", {})
	var ecosistema_variant: Variant = contexto_mundo.get("ecosistema", {})
	var bioma: Dictionary = bioma_variant if bioma_variant is Dictionary else {}
	var ecosistema: Dictionary = ecosistema_variant if ecosistema_variant is Dictionary else {}
	var contexto := {
		"bioma_id": str(bioma.get("id", "")),
		"ecosistema_id": str(ecosistema.get("id", ""))
	}
	var habitats_variant: Variant = contexto_mundo.get("habitats", [])
	if habitats_variant is Array:
		var habitats := habitats_variant as Array
		var buscado := habitat_clave.strip_edges().to_lower()
		if not buscado.is_empty():
			for habitat_variant in habitats:
				if not habitat_variant is Dictionary:
					continue
				var habitat := habitat_variant as Dictionary
				var tipo_habitat_variant: Variant = habitat.get("tipo_habitat", {})
				var tipo_habitat_clave := ""
				if tipo_habitat_variant is Dictionary:
					tipo_habitat_clave = str((tipo_habitat_variant as Dictionary).get("clave", "")).strip_edges().to_lower()
				var claves := [
					str(habitat.get("clave", "")).strip_edges().to_lower(),
					str(habitat.get("nombre", "")).strip_edges().to_lower(),
					tipo_habitat_clave
				]
				if buscado in claves:
					contexto["habitat_id"] = str(habitat.get("id", ""))
					break
	return obtener_estado_para_contexto(contexto)


func obtener_estado_para_contexto(contexto: Dictionary = {}) -> Dictionary:
	var normalizado := _normalizar_contexto(contexto)
	var temporada := _obtener_estacion_actual()
	var estacion_id := str(temporada.get("id", ""))
	var fecha := _obtener_clave_fecha()
	var clave_contexto := str(normalizado.get("habitat_id", ""))
	if clave_contexto.is_empty():
		clave_contexto = str(normalizado.get("ecosistema_id", ""))
	if clave_contexto.is_empty():
		clave_contexto = str(normalizado.get("bioma_id", "global"))
	var cache_key := "%s|%s|%s" % [fecha, estacion_id, clave_contexto]
	if _estados_contexto_cache.has(cache_key):
		return (_estados_contexto_cache[cache_key] as Dictionary).duplicate(true)

	var ambiente := _obtener_factores_ambientales(normalizado, estacion_id)
	var regla := _obtener_regla_climatica(normalizado)
	var seleccion := _seleccionar_perfil_clima(regla, ambiente, cache_key)
	var tipo := str(seleccion.get("tipo", "despejado"))
	var intensidad := clampf(float(seleccion.get("intensidad", 1.0)), 0.0, 1.0)
	var perfil: Dictionary = PERFILES_CLIMA.get(tipo, PERFILES_CLIMA["despejado"]).duplicate(true)
	var efectos_variant: Variant = seleccion.get("efectos", {})
	if efectos_variant is Dictionary:
		for propiedad in PROPIEDADES_CLIMA:
			if (efectos_variant as Dictionary).has(propiedad):
				perfil[propiedad] = float((efectos_variant as Dictionary)[propiedad])
	for propiedad in ["cobertura_nubes", "precipitacion", "viento"]:
		perfil[propiedad] = float(perfil.get(propiedad, 0.0)) * intensidad

	var temperatura_base: Variant = ambiente.get("temperatura_base_c", null)
	var temperatura_resultante: Variant = null
	if temperatura_base is int or temperatura_base is float:
		temperatura_resultante = float(temperatura_base) + float(perfil.get("temperatura_delta_c", 0.0))

	var resultado := {
		"clima": {
			"tipo": tipo,
			"intensidad": intensidad,
			"cobertura_nubes": float(perfil.get("cobertura_nubes", 0.0)),
			"precipitacion": float(perfil.get("precipitacion", 0.0)),
			"viento": float(perfil.get("viento", 0.0)),
			"humedad": float(perfil.get("humedad", ambiente.get("humedad_relativa", 0.5))),
			"visibilidad": float(perfil.get("visibilidad", 1.0)),
			"temperatura_delta_c": float(perfil.get("temperatura_delta_c", 0.0))
		},
		"ambiente": {
			"temperatura_base_c": temperatura_base,
			"temperatura_c": temperatura_resultante,
			"humedad_relativa": float(ambiente.get("humedad_relativa", 0.5)),
			"disponibilidad_agua": float(ambiente.get("disponibilidad_agua", 0.5)),
			"velocidad_medio": float(ambiente.get("velocidad_medio", 0.0))
		},
		"contexto": normalizado,
		"estacion_id": estacion_id,
		"fecha": fecha,
		"eventos": _seleccionar_eventos_estacionales(
			regla,
			ambiente,
			perfil,
			cache_key
		)
	}
	_estados_contexto_cache[cache_key] = resultado
	return resultado.duplicate(true)


func _seleccionar_eventos_estacionales(
	regla: Dictionary,
	ambiente: Dictionary,
	clima: Dictionary,
	semilla_texto: String
) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var eventos_variant: Variant = regla.get("eventos", [])
	if not eventos_variant is Array:
		return resultado
	var estacion := _obtener_estacion_actual()
	var dia := int(estacion.get("dia_de_estacion", 1))
	var duracion := maxi(int(estacion.get("duracion_dias", 1)), 1)
	var temperatura: Variant = ambiente.get("temperatura_base_c", null)
	if temperatura is int or temperatura is float:
		temperatura = float(temperatura) + float(clima.get("temperatura_delta_c", 0.0))

	for evento_variant in eventos_variant as Array:
		if not evento_variant is Dictionary:
			continue
		var evento := (evento_variant as Dictionary).duplicate(true)
		var clave := str(evento.get("clave", "")).strip_edges()
		if clave.is_empty():
			continue
		var inicio := clampi(int(evento.get("dia_inicio", 1)), 1, duracion)
		var fin := clampi(int(evento.get("dia_fin", duracion)), 1, duracion)
		var dentro_del_periodo := dia >= inicio and dia <= fin if inicio <= fin else dia >= inicio or dia <= fin
		if not dentro_del_periodo:
			continue

		var condiciones_variant: Variant = evento.get("condiciones", {})
		var condiciones: Dictionary = condiciones_variant if condiciones_variant is Dictionary else {}
		var climas_variant: Variant = condiciones.get("climas", [])
		if climas_variant is Array and not (climas_variant as Array).is_empty():
			if str(clima.get("tipo", "")) not in climas_variant:
				continue
		if temperatura is int or temperatura is float:
			if condiciones.has("temperatura_minima_c") and float(temperatura) < float(condiciones["temperatura_minima_c"]):
				continue
			if condiciones.has("temperatura_maxima_c") and float(temperatura) > float(condiciones["temperatura_maxima_c"]):
				continue
			if condiciones.has("humedad_minima") and float(clima.get("humedad", 0.0)) < float(condiciones["humedad_minima"]):
				continue

		var probabilidad := clampf(float(evento.get("probabilidad_diaria", 1.0)), 0.0, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = _semilla_determinista(semilla_texto + "|evento|" + clave)
		if rng.randf() > probabilidad:
			continue
		evento["dia_estacion"] = dia
		resultado.append(evento)
	return resultado


func _actualizar_eventos_estacionales() -> void:
	var estado := obtener_estado_para_contexto({})
	var eventos_variant: Variant = estado.get("eventos", [])
	var nuevos: Dictionary = {}
	if eventos_variant is Array:
		for evento_variant in eventos_variant as Array:
			if not evento_variant is Dictionary:
				continue
			var evento := evento_variant as Dictionary
			var clave := str(evento.get("clave", "")).strip_edges()
			if not clave.is_empty():
				nuevos[clave] = evento.duplicate(true)

	for clave_variant in _eventos_estacionales_activos.keys().duplicate():
		var clave := str(clave_variant)
		if not nuevos.has(clave):
			_eventos_estacionales_activos.erase(clave)
			evento_estacional_finalizado.emit(clave)
	for clave_variant in nuevos:
		var clave := str(clave_variant)
		if not _eventos_estacionales_activos.has(clave):
			evento_estacional_iniciado.emit((nuevos[clave] as Dictionary).duplicate(true))
	_eventos_estacionales_activos = nuevos


func _normalizar_contexto(contexto: Dictionary) -> Dictionary:
	var resultado := {}
	for clave in ["bioma_id", "ecosistema_id", "habitat_id"]:
		var valor := str(contexto.get(clave, "")).strip_edges()
		if not valor.is_empty():
			resultado[clave] = valor
	return resultado


func _obtener_estacion_actual() -> Dictionary:
	if _world_atmosphere == null:
		return {}
	return _world_atmosphere.estacion_actual.duplicate(true)


func _obtener_clave_fecha() -> String:
	if _world_atmosphere == null:
		return "sin_fecha"
	return "%s:%s" % [_world_atmosphere.anio, _world_atmosphere.dia_del_anio]


func _semilla_determinista(texto: String) -> int:
	var semilla_mundo := 0
	if _world_context != null and _world_context.tiene_mundo_activo():
		semilla_mundo = _world_context.get_map_seed()
	return abs(hash("%s|mundo:%s" % [texto, semilla_mundo]))


func _obtener_regla_climatica(contexto: Dictionary) -> Dictionary:
	var estacion := _obtener_estacion_actual()
	var config_variant: Variant = estacion.get("config_climatica", {})
	if not config_variant is Dictionary:
		return {}
	var config := config_variant as Dictionary
	for nivel in ["habitats", "ecosistemas", "biomas"]:
		var id := str(contexto.get(
			"habitat_id" if nivel == "habitats" else "ecosistema_id" if nivel == "ecosistemas" else "bioma_id",
			""
		))
		var reglas_variant: Variant = config.get(nivel, {})
		if id.is_empty() or not reglas_variant is Dictionary:
			continue
		var regla_variant: Variant = (reglas_variant as Dictionary).get(id, {})
		if regla_variant is Dictionary and not (regla_variant as Dictionary).is_empty():
			var combinada := config.duplicate(true)
			combinada.merge(regla_variant as Dictionary, true)
			return combinada
	return config


func _obtener_factores_ambientales(contexto: Dictionary, estacion_id: String) -> Dictionary:
	var factores: Dictionary = {}
	if _world_data != null and not estacion_id.is_empty():
		var habitat_id := str(contexto.get("habitat_id", ""))
		var ecosistema_id := str(contexto.get("ecosistema_id", ""))
		if not habitat_id.is_empty():
			factores = _world_data.obtener_ambiente_estacional_habitat(estacion_id, habitat_id)
		if factores.is_empty() and not ecosistema_id.is_empty():
			factores = _world_data.obtener_ambiente_estacional_ecosistema(estacion_id, ecosistema_id)
		if factores.is_empty() and not habitat_id.is_empty():
			factores = _world_data.obtener_factores_ambientales_habitat(habitat_id)
		if factores.is_empty() and not ecosistema_id.is_empty():
			factores = _world_data.obtener_factores_ambientales_ecosistema(ecosistema_id)

	var temperatura_k := _obtener_valor_factor(factores, "temperatura_media", NAN)
	var temperatura_c: Variant = temperatura_k - 273.15 if is_finite(temperatura_k) else null
	var humedad := _obtener_valor_factor(factores, "humedad_relativa", 0.5)
	var agua := _obtener_valor_factor(factores, "disponibilidad_agua", 0.5)
	var velocidad := _obtener_valor_factor(factores, "velocidad_medio", 0.0)
	return {
		"temperatura_base_c": temperatura_c,
		"humedad_relativa": clampf(humedad, 0.0, 1.0),
		"disponibilidad_agua": clampf(agua, 0.0, 1.0),
		"velocidad_medio": maxf(velocidad, 0.0)
	}


func _obtener_valor_factor(factores: Dictionary, clave: String, por_defecto: float) -> float:
	var valor_variant: Variant = factores.get(clave, {})
	if not valor_variant is Dictionary:
		return por_defecto
	var valor: Variant = (valor_variant as Dictionary).get("valor", null)
	if valor is int or valor is float:
		return float(valor)
	return por_defecto


func _seleccionar_perfil_clima(regla: Dictionary, ambiente: Dictionary, semilla_texto: String) -> Dictionary:
	var perfiles: Array = []
	var perfiles_variant: Variant = regla.get("perfiles", [])
	if perfiles_variant is Array:
		for perfil_variant in perfiles_variant as Array:
			if perfil_variant is Dictionary and PERFILES_CLIMA.has(str((perfil_variant as Dictionary).get("tipo", ""))):
				perfiles.append(perfil_variant)
	if perfiles.is_empty():
		perfiles = _crear_perfiles_predeterminados()

	var perfiles_ponderados: Array[Dictionary] = []
	var peso_total := 0.0
	for perfil_variant in perfiles:
		if not perfil_variant is Dictionary:
			continue
		var perfil := perfil_variant as Dictionary
		var tipo := str(perfil.get("tipo", ""))
		var peso_base := maxf(float(perfil.get("peso", 0.0)), 0.0)
		var peso_efectivo := _ajustar_peso_por_ambiente(tipo, peso_base, ambiente)
		if peso_efectivo <= 0.0:
			continue
		var copia := perfil.duplicate(true)
		copia["peso_efectivo"] = peso_efectivo
		perfiles_ponderados.append(copia)
		peso_total += peso_efectivo

	if peso_total <= 0.0:
		return {"tipo": "despejado", "intensidad": 1.0}

	var rng := RandomNumberGenerator.new()
	rng.seed = _semilla_determinista(semilla_texto + "|" + str(_world_atmosphere.anio if _world_atmosphere != null else 0))
	var elegido := perfiles_ponderados.back()
	var objetivo := rng.randf_range(0.0, peso_total)
	for perfil in perfiles_ponderados:
		objetivo -= float(perfil.get("peso_efectivo", 0.0))
		if objetivo <= 0.0:
			elegido = perfil
			break
	var intensidad_min := clampf(float(elegido.get("intensidad_min", 0.65)), 0.0, 1.0)
	var intensidad_max := clampf(float(elegido.get("intensidad_max", 1.0)), intensidad_min, 1.0)
	return {
		"tipo": str(elegido.get("tipo", "despejado")),
		"intensidad": rng.randf_range(intensidad_min, intensidad_max),
		"efectos": elegido.get("efectos", {})
	}


func _ajustar_peso_por_ambiente(tipo: String, peso: float, ambiente: Dictionary) -> float:
	if peso <= 0.0:
		return 0.0
	var temperatura_variant: Variant = ambiente.get("temperatura_base_c", null)
	var tiene_temperatura := temperatura_variant is int or temperatura_variant is float
	var temperatura := float(temperatura_variant) if tiene_temperatura else 20.0
	var humedad := clampf(float(ambiente.get("humedad_relativa", 0.5)), 0.0, 1.0)
	var agua := clampf(float(ambiente.get("disponibilidad_agua", 0.5)), 0.0, 1.0)
	var viento := clampf(float(ambiente.get("velocidad_medio", 0.0)) / 6.0, 0.0, 1.0)

	match tipo:
		"despejado":
			return peso * (1.15 - humedad * 0.25)
		"nublado":
			return peso * (0.75 + humedad * 0.5)
		"lluvia":
			return peso * clampf(0.25 + humedad * 0.9 + agua * 0.4, 0.1, 1.8)
		"niebla":
			return peso * clampf(0.1 + humedad * (1.0 - viento) * 1.6, 0.1, 1.7)
		"tormenta":
			return peso * clampf(0.1 + humedad * viento * 2.2, 0.05, 2.0)
		"nieve":
			if not tiene_temperatura or temperatura > 4.0:
				return 0.0
			return peso * clampf((4.0 - temperatura) / 8.0, 0.2, 2.5)
		"ola_calor":
			if not tiene_temperatura or temperatura < 27.0 or humedad > 0.65:
				return 0.0
			return peso * clampf((temperatura - 26.0) / 6.0 + (0.65 - humedad), 0.2, 2.2)
	return peso


func _crear_perfiles_predeterminados() -> Array[Dictionary]:
	return [
		{"tipo": "despejado", "peso": 42.0},
		{"tipo": "nublado", "peso": 20.0},
		{"tipo": "lluvia", "peso": 15.0},
		{"tipo": "niebla", "peso": 9.0},
		{"tipo": "tormenta", "peso": 5.0},
		{"tipo": "nieve", "peso": 3.0},
		{"tipo": "ola_calor", "peso": 3.0}
	]


func iniciar_fenomeno(tipo: String, intensidad: float = 1.0, duracion_segundos: float = 0.0) -> bool:
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
		"fenomenos": _fenomenos_activos.duplicate(true),
		"eventos_estacionales": _eventos_estacionales_activos.duplicate(true)
	}


func obtener_clima_id() -> String:
	return str(_clima_actual.get("tipo", "despejado"))
