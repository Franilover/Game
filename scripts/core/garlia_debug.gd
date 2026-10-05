extends Node
signal evento_agregado(evento: Dictionary)
signal flujo_actualizado

const MAX_EVENTOS: int = 1200
const MAX_FLUJO: int = 800

var eventos: Array[Dictionary] = []
var flujo: Array[Dictionary] = []
var _pasos_abiertos: Array[String] = []

var _rendimiento_acumulado: float = 0.0
var _rendimiento_intervalo: float = 1.0
var _secciones_rendimiento: Dictionary = {}

func _process(delta: float) -> void:
	_rendimiento_acumulado += delta
	if _rendimiento_acumulado < _rendimiento_intervalo:
		return
	_rendimiento_acumulado = 0.0
	registrar("PERFORMANCE", "Snapshot", obtener_rendimiento())

func obtener_rendimiento() -> Dictionary:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(float(fps), 0.001)
	return {
		"fps": fps,
		"frame_ms_aprox": snappedf(frame_ms, 0.1),
		"process_ms": snappedf(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0, 0.1),
		"physics_ms": snappedf(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0, 0.1),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"secciones_ms": _secciones_rendimiento.duplicate(true)
	}

func rendimiento_inicio(seccion: String) -> void:
	_secciones_rendimiento[seccion] = {
		"inicio": Time.get_ticks_usec(),
		"ms": 0.0
	}

func rendimiento_fin(seccion: String) -> float:
	if not _secciones_rendimiento.has(seccion):
		return 0.0
	var datos: Dictionary = _secciones_rendimiento[seccion]
	var ms := float(Time.get_ticks_usec() - int(datos.get("inicio", 0))) / 1000.0
	datos["ms"] = snappedf(ms, 0.01)
	_secciones_rendimiento[seccion] = datos
	return ms


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	registrar("DEBUG", "GarliaDebug iniciado.")

func registrar(categoria: String, mensaje: String, datos: Dictionary = {}) -> void:
	var evento := {
		"tiempo": Time.get_time_string_from_system(),
		"categoria": categoria,
		"mensaje": mensaje,
		"datos": datos.duplicate(true)
	}
	eventos.append(evento)
	if eventos.size() > MAX_EVENTOS:
		eventos.pop_front()
	evento_agregado.emit(evento)

func flujo_inicio(paso: String, datos: Dictionary = {}) -> void:
	flujo.append({
		"tipo": "inicio",
		"nivel": _pasos_abiertos.size(),
		"paso": paso,
		"tiempo": Time.get_time_string_from_system(),
		"datos": datos.duplicate(true)
	})
	_pasos_abiertos.append(paso)
	_recortar_flujo()
	flujo_actualizado.emit()

func flujo_ok(mensaje: String, datos: Dictionary = {}) -> void:
	var nivel := maxi(0, _pasos_abiertos.size() - 1)
	flujo.append({
		"tipo": "ok",
		"nivel": nivel,
		"paso": mensaje,
		"tiempo": Time.get_time_string_from_system(),
		"datos": datos.duplicate(true)
	})
	if not _pasos_abiertos.is_empty():
		_pasos_abiertos.pop_back()
	_recortar_flujo()
	flujo_actualizado.emit()

func flujo_error(mensaje: String, datos: Dictionary = {}) -> void:
	var nivel := maxi(0, _pasos_abiertos.size() - 1)
	flujo.append({
		"tipo": "error",
		"nivel": nivel,
		"paso": mensaje,
		"tiempo": Time.get_time_string_from_system(),
		"datos": datos.duplicate(true)
	})
	_recortar_flujo()
	flujo_actualizado.emit()

func flujo_paso(mensaje: String, datos: Dictionary = {}) -> void:
	flujo.append({
		"tipo": "paso",
		"nivel": _pasos_abiertos.size(),
		"paso": mensaje,
		"tiempo": Time.get_time_string_from_system(),
		"datos": datos.duplicate(true)
	})
	_recortar_flujo()
	flujo_actualizado.emit()

func limpiar() -> void:
	eventos.clear()
	flujo.clear()
	_pasos_abiertos.clear()
	registrar("DEBUG", "Historial de debug limpiado.")

func obtener_logs_texto() -> String:
	var salida := PackedStringArray()
	for evento in eventos:
		var linea := "[%s] [%s] %s" % [
			str(evento.get("tiempo", "")),
			str(evento.get("categoria", "LOG")),
			str(evento.get("mensaje", ""))
		]
		var datos: Variant = evento.get("datos", {})
		if datos is Dictionary and not (datos as Dictionary).is_empty():
			linea += " | " + JSON.stringify(datos)
		salida.append(linea)
	return "\n".join(salida)

func obtener_flujo_texto() -> String:
	var salida := PackedStringArray()
	for paso in flujo:
		var prefijo := "  ".repeat(int(paso.get("nivel", 0)))
		var icono := "•"
		match str(paso.get("tipo", "paso")):
			"inicio":
				icono = ">"
			"ok":
				icono = "✓"
			"error":
				icono = "!"
		var linea := "%s%s [%s] %s" % [
			prefijo,
			icono,
			str(paso.get("tiempo", "")),
			str(paso.get("paso", ""))
		]
		var datos: Variant = paso.get("datos", {})
		if datos is Dictionary and not (datos as Dictionary).is_empty():
			linea += " | " + JSON.stringify(datos)
		salida.append(linea)
	return "\n".join(salida)

func _recortar_flujo() -> void:
	while flujo.size() > MAX_FLUJO:
		flujo.pop_front()
