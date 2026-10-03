extends Node

class_name WorldAtmosphere

## Reloj del mundo y ciclo de iluminación.
## El calendario y sus duraciones provienen de Supabase a través de WorldData.
## La velocidad de simulación (minutos reales por día del mundo) es una
## configuración del runtime, no un dato canónico del calendario.

@export_range(2.0, 60.0, 1.0) var minutos_por_dia: float = 12.0
@export_range(0.0, 1.0, 0.01) var hora_inicial: float = 0.28

signal dia_cambiado(dia_del_anio: int, anio: int)
signal estacion_cambiada(estacion: Dictionary)

var hora_del_dia: float = 0.0
var dia_del_anio: int = 0
var anio: int = 0

var horas_por_dia: float = 24.0
var dias_por_anio: int = 0
var estaciones: Array = []
var estacion_actual: Dictionary = {}

var _calendario_cargado: bool = false
var _estado_guardado_pendiente: Dictionary = {}

var _modulacion: CanvasModulate


func _ready() -> void:
	_modulacion = CanvasModulate.new()
	_modulacion.name = "DayNightModulation"
	get_tree().current_scene.add_child.call_deferred(_modulacion)

	if not WorldData.mundo_listo.is_connected(
		_al_mundo_listo
	):
		WorldData.mundo_listo.connect(
			_al_mundo_listo
		)

	if not WorldData.mundo_actualizado.is_connected(
		_al_mundo_actualizado
	):
		WorldData.mundo_actualizado.connect(
			_al_mundo_actualizado
		)

	_intentar_cargar_calendario()
	_actualizar_iluminacion()


func _process(delta: float) -> void:
	if not _calendario_cargado:
		return

	var duracion_real_segundos := maxf(
		minutos_por_dia * 60.0,
		0.001
	)

	var incremento_horas := (
		delta * horas_por_dia
		/ duracion_real_segundos
	)

	hora_del_dia += incremento_horas

	while hora_del_dia >= horas_por_dia:
		hora_del_dia -= horas_por_dia
		_avanzar_dia()

	_actualizar_iluminacion()


func _al_mundo_listo() -> void:
	_intentar_cargar_calendario()


func _al_mundo_actualizado() -> void:
	_intentar_cargar_calendario()


func _intentar_cargar_calendario() -> void:
	if not WorldData.esta_cargado():
		return

	var calendario := WorldData.obtener_calendario()
	if calendario.is_empty():
		return

	var config_variant: Variant = calendario.get(
		"config",
		{}
	)

	var estaciones_variant: Variant = calendario.get(
		"estaciones",
		[]
	)

	if not config_variant is Dictionary:
		return

	if not estaciones_variant is Array:
		return

	var config := config_variant as Dictionary
	var nuevas_estaciones := estaciones_variant as Array

	if nuevas_estaciones.is_empty():
		return

	var nuevas_horas_por_dia := maxf(
		float(config.get("horas_por_dia", 0)),
		0.0
	)

	if nuevas_horas_por_dia <= 0.0:
		return

	var nuevas_dias_por_anio := int(
		calendario.get(
			"dias_por_anio",
			0
		)
	)

	if nuevas_dias_por_anio <= 0:
		nuevas_dias_por_anio = 0
		for estacion_variant in nuevas_estaciones:
			if not estacion_variant is Dictionary:
				continue
			nuevas_dias_por_anio += maxi(
				int(
					(estacion_variant as Dictionary).get(
						"duracion_dias",
						0
					)
				),
				0
			)

	if nuevas_dias_por_anio <= 0:
		return

	var era_cargado := _calendario_cargado

	horas_por_dia = nuevas_horas_por_dia
	dias_por_anio = nuevas_dias_por_anio
	estaciones = nuevas_estaciones.duplicate(true)

	if not era_cargado:
		anio = int(
			config.get(
				"anio_inicio",
				0
			)
		)
		hora_del_dia = clampf(
			hora_inicial,
			0.0,
			1.0
		) * horas_por_dia
		dia_del_anio = 0

		_calendario_cargado = true
		_actualizar_estacion()

		if not _estado_guardado_pendiente.is_empty():
			_aplicar_estado_guardado(
				_estado_guardado_pendiente
			)
			_estado_guardado_pendiente.clear()
	else:
		_calendario_cargado = true
		_dia_del_anio_normalizado()
		_actualizar_estacion()


func _dia_del_anio_normalizado() -> void:
	if dias_por_anio <= 0:
		dia_del_anio = 0
		return

	while dia_del_anio >= dias_por_anio:
		dia_del_anio -= dias_por_anio
	while dia_del_anio < 0:
		dia_del_anio += dias_por_anio


func _avanzar_dia() -> void:
	dia_del_anio += 1

	if dia_del_anio >= dias_por_anio:
		dia_del_anio = 0
		anio += 1

	var estacion_anterior_id := str(
		estacion_actual.get(
			"id",
			""
		)
	)

	_actualizar_estacion()

	dia_cambiado.emit(
		dia_del_anio,
		anio
	)

	var estacion_nueva_id := str(
		estacion_actual.get(
			"id",
			""
		)
	)

	if estacion_nueva_id != estacion_anterior_id:
		estacion_cambiada.emit(
			estacion_actual.duplicate(true)
		)


func _actualizar_estacion() -> void:
	estacion_actual = {}
	if estaciones.is_empty():
		return

	var inicio_dia := 0

	for estacion_variant in estaciones:
		if not estacion_variant is Dictionary:
			continue

		var estacion := (
			estacion_variant as Dictionary
		)
		var duracion := maxi(
			int(
				estacion.get(
					"duracion_dias",
					0
				)
			),
			0
		)

		if duracion <= 0:
			continue

		if dia_del_anio < inicio_dia + duracion:
			estacion_actual = estacion.duplicate(true)
			estacion_actual["dia_de_estacion"] = (
			dia_del_anio - inicio_dia + 1
		)
		return

	inicio_dia += duracion


func _actualizar_iluminacion() -> void:
	if _modulacion == null or not is_instance_valid(_modulacion):
		return

	var dia_normalizado := hora_del_dia / maxf(
		horas_por_dia,
		1.0
	)

	var luz: Color
	if dia_normalizado < 0.20:
		luz = Color(0.28, 0.32, 0.52)
	elif dia_normalizado < 0.30:
		luz = Color(0.28, 0.32, 0.52).lerp(
			Color(1.0, 0.79, 0.62),
			(dia_normalizado - 0.20) / 0.10
		)
	elif dia_normalizado < 0.72:
		luz = Color(1.0, 0.97, 0.88)
	elif dia_normalizado < 0.82:
		luz = Color(1.0, 0.97, 0.88).lerp(
			Color(0.65, 0.42, 0.48),
			(dia_normalizado - 0.72) / 0.10
		)
	else:
		luz = Color(0.28, 0.32, 0.52)

	_modulacion.color = luz


func _obtener_periodo() -> String:
	var dia_normalizado := hora_del_dia / maxf(
		horas_por_dia,
		1.0
	)

	if dia_normalizado < 0.20 or dia_normalizado >= 0.82:
		return "Noche"
	if dia_normalizado < 0.30:
		return "Amanecer"
	if dia_normalizado < 0.72:
		return "Día"
	return "Atardecer"


func _obtener_hora_texto() -> String:
	var minutos_totales := int(floor(
		hora_del_dia * 60.0
	))
	var horas := int(floor(
		float(minutos_totales) / 60.0
	))
	var minutos := minutos_totales % 60

	return "%02d:%02d" % [
		horas,
		minutos
	]


func obtener_tiempo() -> Dictionary:
	var estacion := estacion_actual.duplicate(true)
	return {
		"hora": _obtener_hora_texto(),
		"periodo": _obtener_periodo(),
		"dia": dia_del_anio + 1,
		"anio": anio,
		"hora_del_dia": hora_del_dia,
		"horas_por_dia": horas_por_dia,
		"dia_de_estacion": int(
			estacion.get(
				"dia_de_estacion",
				0
			)
		),
		"duracion_estacion_dias": int(
			estacion.get(
				"duracion_dias",
				0
			)
		),
		"estacion": str(
			estacion.get(
				"nombre",
				"—"
			)
		),
		"calendario_cargado": _calendario_cargado
	}


func obtener_estado_guardado() -> Dictionary:
	return {
		"hora_del_dia": hora_del_dia,
		"dia_del_anio": dia_del_anio,
		"anio": anio
	}


func establecer_estado_guardado(
	estado: Dictionary
) -> void:
	if not _calendario_cargado:
		_estado_guardado_pendiente = estado.duplicate(true)
		return

	_aplicar_estado_guardado(
		estado
	)


func _aplicar_estado_guardado(
	estado: Dictionary
) -> void:
	hora_del_dia = clampf(
		float(
			estado.get(
				"hora_del_dia",
				hora_del_dia
			)
		),
		0.0,
		horas_por_dia
	)

	dia_del_anio = int(
		estado.get(
			"dia_del_anio",
			dia_del_anio
		)
	)

	anio = int(
		estado.get(
			"anio",
			anio
		)
	)

	_dia_del_anio_normalizado()
	_actualizar_estacion()
	_actualizar_iluminacion()
