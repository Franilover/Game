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


func _obtener_estaciones_ordenadas() -> Array:
	var resultado: Array = estaciones.duplicate(true)
	resultado.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			if not a is Dictionary:
				return false
			if not b is Dictionary:
				return true
			return int((a as Dictionary).get("orden", 0)) < int((b as Dictionary).get("orden", 0))
	)
	return resultado


func _actualizar_estacion() -> void:
	estacion_actual = {}
	if estaciones.is_empty():
		return

	var estaciones_ordenadas := _obtener_estaciones_ordenadas()
	var duracion_total := 0
	for estacion_variant in estaciones_ordenadas:
		if not estacion_variant is Dictionary:
			continue
		duracion_total += maxi(int((estacion_variant as Dictionary).get("duracion_dias", 0)), 0)

	if duracion_total <= 0:
		return

	# Resolver el día usando la duración real de las estaciones evita
	# dejar estacion_actual vacío si el calendario trae un orden distinto.
	dia_del_anio = posmod(dia_del_anio, duracion_total)

	var inicio_dia := 0
	for estacion_variant in estaciones_ordenadas:
		if not estacion_variant is Dictionary:
			continue

		var estacion := estacion_variant as Dictionary
		var duracion := maxi(int(estacion.get("duracion_dias", 0)), 0)
		if duracion <= 0:
			continue

		if dia_del_anio >= inicio_dia and dia_del_anio < inicio_dia + duracion:
			estacion_actual = estacion.duplicate(true)
			estacion_actual["dia_de_estacion"] = dia_del_anio - inicio_dia + 1
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


func _obtener_config_visual_estacion() -> Dictionary:
	var config_variant: Variant = estacion_actual.get("config_visual", {})
	if config_variant is Dictionary:
		return (config_variant as Dictionary).duplicate(true)
	return {}


func calcular_color_iluminacion(hora_normalizada: float) -> Color:
	const CLAVES_LUZ_PREDETERMINADAS: Array[Dictionary] = [
		{"hora": 0.00, "color": "#263454"},
		{"hora": 0.08, "color": "#293B63"},
		{"hora": 0.15, "color": "#465A83"},
		{"hora": 0.19, "color": "#8A6487"},
		{"hora": 0.22, "color": "#D77A67"},
		{"hora": 0.25, "color": "#F5A06A"},
		{"hora": 0.29, "color": "#FFE0A2"},
		{"hora": 0.34, "color": "#FFF0D0"},
		{"hora": 0.50, "color": "#FFFDF2"},
		{"hora": 0.66, "color": "#FFEBD0"},
		{"hora": 0.72, "color": "#FFD49A"},
		{"hora": 0.76, "color": "#F9A36F"},
		{"hora": 0.80, "color": "#E97862"},
		{"hora": 0.84, "color": "#A65E70"},
		{"hora": 0.89, "color": "#4E527D"},
		{"hora": 0.95, "color": "#2C3A63"},
		{"hora": 1.00, "color": "#263454"},
	]

	var hora := clampf(hora_normalizada, 0.0, 1.0)
	var config_visual := _obtener_config_visual_estacion()
	var claves_variant: Variant = config_visual.get("claves_luz", [])
	if claves_variant is Array and (claves_variant as Array).size() >= 2:
		var claves_configuradas := _normalizar_claves_luz(claves_variant as Array)
		if claves_configuradas.size() >= 2:
			return _interpolar_claves_luz(claves_configuradas, hora)

	return _interpolar_claves_luz(
		_normalizar_claves_luz(CLAVES_LUZ_PREDETERMINADAS),
		hora
	)


func _normalizar_claves_luz(claves: Array) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for clave_variant in claves:
		if not clave_variant is Dictionary:
			continue
		var clave := clave_variant as Dictionary
		if not clave.has("hora") or not clave.has("color"):
			continue
		var color_texto := str(clave.get("color", "")).strip_edges()
		if color_texto.is_empty():
			continue
		resultado.append({
			"hora": clampf(float(clave.get("hora", 0.0)), 0.0, 1.0),
			"color": Color.from_string(color_texto, Color.WHITE)
		})
	resultado.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("hora", 0.0)) < float(b.get("hora", 0.0))
	)
	return resultado


func _interpolar_claves_luz(
	claves: Array[Dictionary],
	hora: float
) -> Color:
	if claves.is_empty():
		return Color.WHITE
	if claves.size() == 1:
		return claves[0]["color"] as Color

	if hora <= float(claves[0]["hora"]):
		return claves[0]["color"] as Color

	for indice in range(claves.size() - 1):
		var inicio: Dictionary = claves[indice]
		var final: Dictionary = claves[indice + 1]
		var hora_inicio := float(inicio["hora"])
		var hora_final := float(final["hora"])
		if hora <= hora_final:
			var progreso := inverse_lerp(hora_inicio, hora_final, hora)
			progreso = progreso * progreso * (3.0 - 2.0 * progreso)
			var color_inicio: Color = inicio["color"]
			var color_final: Color = final["color"]
			return color_inicio.lerp(color_final, progreso)

	return claves.back()["color"] as Color


func _obtener_periodo() -> String:
	var dia_normalizado := hora_del_dia / maxf(horas_por_dia, 1.0)
	var config_visual := _obtener_config_visual_estacion()
	var horarios_variant: Variant = config_visual.get("horarios", {})
	var horarios: Dictionary = horarios_variant if horarios_variant is Dictionary else {}

	var amanecer_inicio := clampf(float(horarios.get("amanecer_inicio", 0.20)), 0.0, 1.0)
	var amanecer_fin := clampf(float(horarios.get("amanecer_fin", 0.30)), 0.0, 1.0)
	var atardecer_inicio := clampf(float(horarios.get("atardecer_inicio", 0.72)), 0.0, 1.0)
	var atardecer_fin := clampf(float(horarios.get("atardecer_fin", 0.82)), 0.0, 1.0)

	if amanecer_fin <= amanecer_inicio or atardecer_fin <= atardecer_inicio:
		amanecer_inicio = 0.20
		amanecer_fin = 0.30
		atardecer_inicio = 0.72
		atardecer_fin = 0.82

	if dia_normalizado < amanecer_inicio or dia_normalizado >= atardecer_fin:
		return "Noche"
	if dia_normalizado < amanecer_fin:
		return "Amanecer"
	if dia_normalizado < atardecer_inicio:
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

func establecer_hora_del_dia(hora: int, minuto: int) -> bool:
	if not _calendario_cargado:
		return false

	var minutos_dia := maxi(1, int(round(horas_por_dia * 60.0)))
	var hora_maxima := maxi(0, int(ceil(horas_por_dia)) - 1)
	var hora_segura := clampi(hora, 0, hora_maxima)
	var minuto_seguro := clampi(minuto, 0, 59)
	var total_minutos := mini(hora_segura * 60 + minuto_seguro, minutos_dia - 1)
	hora_del_dia = float(total_minutos) / 60.0
	_actualizar_iluminacion()
	return true


func desplazar_dias(cantidad: int) -> bool:
	if not _calendario_cargado or dias_por_anio <= 0 or cantidad == 0:
		return false

	var estacion_anterior_id := obtener_estacion_id()
	dia_del_anio += cantidad
	while dia_del_anio >= dias_por_anio:
		dia_del_anio -= dias_por_anio
		anio += 1
	while dia_del_anio < 0:
		dia_del_anio += dias_por_anio
		anio -= 1

	_actualizar_estacion()
	dia_cambiado.emit(dia_del_anio, anio)
	if obtener_estacion_id() != estacion_anterior_id:
		estacion_cambiada.emit(estacion_actual.duplicate(true))
	return true


func establecer_estacion(estacion_id: String) -> bool:
	if not _calendario_cargado or estacion_id.strip_edges().is_empty():
		return false

	var dia_de_estacion_actual := maxi(0, int(estacion_actual.get("dia_de_estacion", 1)) - 1)
	var inicio_dia := 0
	for estacion_variant in _obtener_estaciones_ordenadas():
		if not estacion_variant is Dictionary:
			continue
		var estacion := estacion_variant as Dictionary
		var duracion := maxi(int(estacion.get("duracion_dias", 0)), 0)
		if duracion <= 0:
			continue
		if str(estacion.get("id", "")).strip_edges() == estacion_id.strip_edges():
			dia_del_anio = inicio_dia + mini(dia_de_estacion_actual, duracion - 1)
			_actualizar_estacion()
			if estacion_actual.is_empty():
				push_error("WorldAtmosphere: no se pudo resolver la estación seleccionada: " + estacion_id)
				return false
			dia_cambiado.emit(dia_del_anio, anio)
			estacion_cambiada.emit(estacion_actual.duplicate(true))
			return true
		inicio_dia += duracion
	return false


func establecer_anio(nuevo_anio: int) -> bool:
	if not _calendario_cargado:
		return false
	anio = nuevo_anio
	dia_cambiado.emit(dia_del_anio, anio)
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
