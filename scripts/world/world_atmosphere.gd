extends Node

class_name WorldAtmosphere

## Reloj del mundo y ciclo de iluminación.
## El calendario y sus duraciones provienen de Supabase a través de WorldData.
## La velocidad de simulación (minutos reales por día del mundo) es una
## configuración del runtime, no un dato canónico del calendario.

@export_range(2.0, 60.0, 1.0) var minutos_por_dia: float = 12.0
@export_range(0.0, 1.0, 0.01) var hora_inicial: float = 0.28
@export_range(0.2, 12.0, 0.1) var suavizado_iluminacion_segundos: float = 2.8

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
var _tiempo_bloqueado: bool = false
var _anio_inicio: int = 0

var _modulacion: CanvasModulate
var _color_iluminacion_actual: Color = Color.WHITE
var _iluminacion_inicializada: bool = false
var _world_data: WorldDataService = null


func configurar_dependencias(world_data: WorldDataService) -> void:
	_world_data = world_data
	if _world_data == null:
		push_error("WorldAtmosphere: WorldDataService es obligatorio.")
		return

	if not _world_data.mundo_listo.is_connected(_al_mundo_listo):
		_world_data.mundo_listo.connect(_al_mundo_listo)
	if not _world_data.mundo_actualizado.is_connected(_al_mundo_actualizado):
		_world_data.mundo_actualizado.connect(_al_mundo_actualizado)

	_intentar_cargar_calendario()


func _ready() -> void:
	_modulacion = get_node_or_null("DayNightModulation") as CanvasModulate
	if _modulacion == null:
		push_error("WorldAtmosphere: falta el nodo DayNightModulation en la escena.")
		return

	_intentar_cargar_calendario()
	_actualizar_iluminacion()


func _process(delta: float) -> void:
	if not _calendario_cargado:
		return

	if _tiempo_bloqueado:
		_actualizar_iluminacion(delta)
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

	_actualizar_iluminacion(delta)


func _al_mundo_listo() -> void:
	_intentar_cargar_calendario()


func _al_mundo_actualizado() -> void:
	_intentar_cargar_calendario()


func _intentar_cargar_calendario() -> void:
	if _world_data == null or not _world_data.esta_cargado():
		return

	var calendario: Dictionary = _world_data.obtener_calendario()
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

	var config: Dictionary = config_variant as Dictionary
	var nuevas_estaciones: Array = estaciones_variant as Array

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
		_anio_inicio = anio
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

	var inicio_dia: int = 0

	for estacion_variant in estaciones:
		if not estacion_variant is Dictionary:
			continue

		var estacion: Dictionary = (
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


func _actualizar_iluminacion(delta: float = 0.0) -> void:
	if _modulacion == null or not is_instance_valid(_modulacion):
		return

	var dia_normalizado := hora_del_dia / maxf(horas_por_dia, 1.0)
	var color_objetivo := calcular_color_iluminacion(dia_normalizado)

	if not _iluminacion_inicializada:
		_color_iluminacion_actual = color_objetivo
		_iluminacion_inicializada = true
	elif delta > 0.0:
		# Suavizado exponencial: también evita saltos cuando un administrador
		# cambia la hora directamente o se restaura una partida guardada.
		var duracion := maxf(suavizado_iluminacion_segundos, 0.01)
		var factor := 1.0 - exp(-delta / duracion)
		_color_iluminacion_actual = _color_iluminacion_actual.lerp(
			color_objetivo,
			clampf(factor, 0.0, 1.0)
		)

	_modulacion.color = _color_iluminacion_actual


func calcular_color_iluminacion(hora_normalizada: float) -> Color:
	# Paleta cíclica: noche azul, amanecer rosado/dorado, luz diurna clara
	# y atardecer naranja, coral y violeta antes de volver a la noche.
	const CLAVES_LUZ: Array[Dictionary] = [
		{"hora": 0.00, "color": Color("#263454")},
		{"hora": 0.08, "color": Color("#293B63")},
		{"hora": 0.15, "color": Color("#465A83")},
		{"hora": 0.19, "color": Color("#8A6487")},
		{"hora": 0.22, "color": Color("#D77A67")},
		{"hora": 0.25, "color": Color("#F5A06A")},
		{"hora": 0.29, "color": Color("#FFE0A2")},
		{"hora": 0.34, "color": Color("#FFF0D0")},
		{"hora": 0.50, "color": Color("#FFFDF2")},
		{"hora": 0.66, "color": Color("#FFEBD0")},
		{"hora": 0.72, "color": Color("#FFD49A")},
		{"hora": 0.76, "color": Color("#F9A36F")},
		{"hora": 0.80, "color": Color("#E97862")},
		{"hora": 0.84, "color": Color("#A65E70")},
		{"hora": 0.89, "color": Color("#4E527D")},
		{"hora": 0.95, "color": Color("#2C3A63")},
		{"hora": 1.00, "color": Color("#263454")},
	]

	var hora := clampf(hora_normalizada, 0.0, 1.0)
	for indice in range(CLAVES_LUZ.size() - 1):
		var inicio: Dictionary = CLAVES_LUZ[indice]
		var final: Dictionary = CLAVES_LUZ[indice + 1]
		var hora_inicio := float(inicio["hora"])
		var hora_final := float(final["hora"])
		if hora <= hora_final:
			var progreso := inverse_lerp(hora_inicio, hora_final, hora)
			# Smoothstep evita cambios bruscos de velocidad entre colores.
			progreso = progreso * progreso * (3.0 - 2.0 * progreso)
			var color_inicio: Color = inicio["color"]
			var color_final: Color = final["color"]
			return color_inicio.lerp(color_final, progreso)

	var ultimo_color: Color = CLAVES_LUZ.back()["color"]
	return ultimo_color


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



func bloquear_tiempo() -> void:
	_tiempo_bloqueado = true


func desbloquear_tiempo() -> void:
	_tiempo_bloqueado = false


func esta_bloqueado() -> bool:
	return _tiempo_bloqueado


func establecer_dia() -> bool:
	if not _calendario_cargado:
		return false

	hora_del_dia = horas_por_dia * 0.5
	_actualizar_iluminacion()
	return true


func dormir_hasta_manana() -> bool:
	if not _calendario_cargado or _tiempo_bloqueado:
		return false

	_avanzar_dia()
	hora_del_dia = horas_por_dia * (7.0 / 24.0)
	_actualizar_iluminacion()
	return true


func establecer_noche() -> bool:
	if not _calendario_cargado:
		return false

	hora_del_dia = 0.0
	_actualizar_iluminacion()
	return true


func reiniciar_tiempo() -> bool:
	if not _calendario_cargado:
		return false

	_tiempo_bloqueado = false
	hora_del_dia = clampf(
		hora_inicial,
		0.0,
		1.0
	) * horas_por_dia
	dia_del_anio = 0
	anio = _anio_inicio
	_actualizar_estacion()
	_actualizar_iluminacion()
	return true

func obtener_estacion_id() -> String:
	return str(
		estacion_actual.get(
			"id",
			""
		)
	)


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
		"estacion_id": str(
			estacion.get(
			"id",
				""
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
		"anio": anio,
		"estacion_id": obtener_estacion_id()
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
	var hora_guardada := float(
		estado.get(
			"hora_del_dia",
			hora_del_dia
		)
	)

	hora_del_dia = fposmod(
		hora_guardada,
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
