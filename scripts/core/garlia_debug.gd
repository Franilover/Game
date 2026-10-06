extends Node
signal evento_agregado(evento: Dictionary)
signal flujo_actualizado

const MAX_EVENTOS: int = 1200
const MAX_FLUJO: int = 800

var eventos: Array[Dictionary] = []
var flujo: Array[Dictionary] = []
var _pasos_abiertos: Array[String] = []

# Registro universal de diagnósticos. Cualquier sistema puede publicar un
# proveedor sin crear otra consola de debug.
var _proveedores: Dictionary = {}
var _marcadores: Dictionary = {}

var _rendimiento_acumulado: float = 0.0
var _rendimiento_intervalo: float = 1.0
var _secciones_rendimiento: Dictionary = {}
var _ultimo_tiempo_process: float = 0.0
var _ultimo_tiempo_physics: float = 0.0

func _process(delta: float) -> void:
	_rendimiento_acumulado += delta
	if _rendimiento_acumulado < _rendimiento_intervalo:
		return
	_rendimiento_acumulado = 0.0
	registrar("PERFORMANCE", "Snapshot", obtener_rendimiento())
	_secciones_rendimiento.clear()

func obtener_rendimiento() -> Dictionary:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(float(fps), 0.001)
	return {
		"fps": fps,
		"frame_ms_aprox": snappedf(frame_ms, 0.1),
		"process_ms": _medir_tiempo_monitor(Performance.TIME_PROCESS, true),
		"physics_ms": _medir_tiempo_monitor(Performance.TIME_PHYSICS_PROCESS, false),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"physics_2d_active": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		"physics_2d_pairs": Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
		"creatures": get_tree().get_nodes_in_group("creatures").size(),
		"world_props": get_tree().get_nodes_in_group("world_props").size(),
		"secciones_ms": _secciones_rendimiento.duplicate(true)
	}

func rendimiento_inicio(seccion: String) -> void:
	_secciones_rendimiento[seccion] = {
		"inicio": Time.get_ticks_usec(),
		"ms": 0.0
	}

func rendimiento_acumular(seccion: String, milisegundos: float) -> void:
	if not _secciones_rendimiento.has(seccion):
		_secciones_rendimiento[seccion] = {
			"inicio": 0,
			"ms": 0.0
		}
	var datos: Dictionary = _secciones_rendimiento[seccion]
	datos["ms"] = float(datos.get("ms", 0.0)) + milisegundos
	datos["ms"] = snappedf(float(datos["ms"]), 0.01)
	_secciones_rendimiento[seccion] = datos

func _medir_tiempo_monitor(monitor: Performance.Monitor, es_process: bool) -> float:
	var actual := float(Performance.get_monitor(monitor))
	var anterior := _ultimo_tiempo_process if es_process else _ultimo_tiempo_physics
	if es_process:
		_ultimo_tiempo_process = actual
	else:
		_ultimo_tiempo_physics = actual
	return snappedf(maxf(actual - anterior, 0.0) * 1000.0, 0.1)

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

func registrar_proveedor(id: String, sistema: String, nodo: Node, descripcion: String = "") -> void:
	if id.is_empty() or not is_instance_valid(nodo):
		return
	_proveedores[id] = {
		"id": id,
		"sistema": sistema,
		"nodo": nodo,
		"descripcion": descripcion
	}
	flujo_actualizado.emit()

func quitar_proveedor(id: String) -> void:
	_proveedores.erase(id)
	flujo_actualizado.emit()

func marcar(id: String, estado: String, detalle: String = "", datos: Dictionary = {}) -> void:
	_marcadores[id] = {
		"estado": estado,
		"detalle": detalle,
		"datos": datos.duplicate(true),
		"tiempo": Time.get_time_string_from_system()
	}
	flujo_actualizado.emit()

func obtener_proveedores() -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	var borrar: Array[String] = []
	for id in _proveedores:
		var proveedor: Dictionary = _proveedores[id]
		var nodo: Node = proveedor.get("nodo") as Node
		if not is_instance_valid(nodo):
			borrar.append(id)
			continue
		var fila := {
			"id": id,
			"sistema": str(proveedor.get("sistema", id)),
			"descripcion": str(proveedor.get("descripcion", "")),
			"node_path": str(nodo.get_path()),
			"script": _obtener_script_path(nodo),
			"estado": "OK"
		}
		var datos: Variant = null
		if nodo.has_method("obtener_diagnostico"):
			datos = nodo.call("obtener_diagnostico")
		elif nodo.has_method("diagnostico_debug"):
			datos = nodo.call("diagnostico_debug")
		if datos is Dictionary:
			fila["datos"] = datos
		if _marcadores.has(id):
			var marcador: Dictionary = _marcadores[id]
			fila["estado"] = str(marcador.get("estado", "OK"))
			fila["detalle"] = str(marcador.get("detalle", ""))
			fila["marcador"] = marcador.get("datos", {})
		salida.append(fila)
	for id in borrar:
		_proveedores.erase(id)
	return salida

func obtener_marcadores() -> Dictionary:
	return _marcadores.duplicate(true)

func _obtener_script_path(nodo: Node) -> String:
	var script: Variant = nodo.get_script()
	if script is Script:
		return (script as Script).resource_path
	return "<sin script>"

func obtener_auditoria_render() -> Dictionary:
	var canvas_items: Array[Dictionary] = []
	var tilemaps: Array[Dictionary] = []
	var cameras: Array[Dictionary] = []
	var problemas: Array[String] = []
	var pruebas: Array[Dictionary] = []
	var raiz: Node = get_tree().root
	if raiz == null:
		return {"estado": "ERROR", "problemas": ["SceneTree.root es null"], "pruebas": []}

	var viewport := get_viewport()
	var canvas_transform := viewport.get_canvas_transform()
	pruebas.append({
		"prueba": "Viewport valido",
		"ok": is_instance_valid(viewport),
		"detalle": "%dx%d" % [viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y]
	})
	pruebas.append({
		"prueba": "Canvas transform valido",
		"ok": not canvas_transform.is_equal_approx(Transform2D()),
		"detalle": str(canvas_transform)
	})

	for nodo in _recorrer(raiz):
		if nodo is Camera2D:
			var cam := nodo as Camera2D
			cameras.append({
				"path": str(cam.get_path()), "enabled": cam.enabled,
				"position": cam.global_position, "zoom": cam.zoom,
				"visible": cam.is_visible_in_tree()
			})
		if nodo is CanvasItem:
			var item := nodo as CanvasItem
			var fila := {
				"path": str(item.get_path()),
				"type": item.get_class(),
				"visible": item.visible,
				"visible_tree": item.is_visible_in_tree(),
				"modulate": item.modulate,
				"self_modulate": item.self_modulate,
				"z_index": item.z_index,
				"z_relative": item.z_as_relative,
				"global_position": item.global_position,
				"material": str(item.material) if item.material != null else "",
				"top_level": item.top_level
			}
			if item is TileMapLayer:
				var tm := item as TileMapLayer
				var used := tm.get_used_cells()
				var ts := tm.tile_set
				fila["used_cells"] = used.size()
				fila["tile_set"] = str(ts) if ts != null else ""
				fila["tile_size"] = ts.tile_size if ts != null else Vector2i.ZERO
				fila["source_count"] = ts.get_source_count() if ts != null else 0
				if ts != null:
					var sources: Array[String] = []
					for sid in ts.get_source_ids():
						var source := ts.get_source(sid)
						if source is TileSetAtlasSource:
							var atlas := source as TileSetAtlasSource
							sources.append("%d:%s:%d" % [sid, (atlas.texture as Texture2D).resource_path if atlas.texture != null else "<sin textura>", atlas.get_tiles_count()])
					fila["sources"] = sources
				tilemaps.append(fila)
			canvas_items.append(fila)
		else:
			if nodo is CanvasItem:
				canvas_items.append(fila)

	for cam in cameras:
		if bool(cam["enabled"]) and not bool(cam["visible"]):
			problemas.append("Camera2D habilitada pero no visible en el arbol: %s" % cam["path"])
		var pos: Vector2 = cam["position"]
		if not pos.is_finite():
			problemas.append("Camera2D con posicion invalida: %s" % cam["path"])
		var zoom: Vector2 = cam["zoom"]
		if zoom.x <= 0.0 or zoom.y <= 0.0:
			problemas.append("Camera2D con zoom invalido: %s" % cam["path"])

	var tilemaps_con_celdas := 0
	for tm in tilemaps:
		if int(tm.get("used_cells", 0)) > 0:
			tilemaps_con_celdas += 1
			if not bool(tm.get("visible_tree", false)):
				problemas.append("TileMapLayer con celdas pero invisible: %s" % tm["path"])
			if int(tm.get("source_count", 0)) == 0:
				problemas.append("TileMapLayer con celdas pero sin TileSet sources: %s" % tm["path"])
			if float((tm.get("modulate", Color.WHITE) as Color).a) <= 0.001:
				problemas.append("TileMapLayer con alpha 0: %s" % tm["path"])
			if str(tm.get("material", "")).contains("ghost_material"):
				problemas.append("TileMapLayer visual usa ghost_material: %s" % tm["path"])

		pruebas.append({
			"prueba": "TileMaps con celdas",
			"ok": tilemaps_con_celdas > 0,
			"detalle": "%d TileMapLayer con celdas" % tilemaps_con_celdas
		})

	if cameras.is_empty():
		problemas.append("No existe Camera2D en el arbol.")
	pruebas.append({
		"prueba": "Camera2D habilitada",
		"ok": cameras.any(func(c): return bool(c["enabled"])),
		"detalle": JSON.stringify(cameras)
	})

	var estado := "ERROR" if not problemas.is_empty() else "OK"
	return {
		"estado": estado,
		"problemas": problemas,
		"pruebas": pruebas,
		"cameras": cameras,
		"tilemaps": tilemaps,
		"canvas_items": canvas_items,
		"viewport": {
			"size": viewport.get_visible_rect().size,
			"canvas_transform": str(canvas_transform)
		}
	}

func obtener_arbol_diagnostico(raiz: Node = null) -> Array[Dictionary]:
	var origen: Node = raiz if is_instance_valid(raiz) else get_tree().current_scene
	var salida: Array[Dictionary] = []
	if not is_instance_valid(origen):
		return salida
	var pendientes: Array[Dictionary] = [{"nodo": origen, "nivel": 0}]
	while not pendientes.is_empty():
		var entrada: Dictionary = pendientes.pop_front()
		var nodo: Node = entrada["nodo"] as Node
		var nivel: int = int(entrada["nivel"])
		if not is_instance_valid(nodo):
			continue
		var script: Variant = nodo.get_script()
		salida.append({
			"nivel": nivel,
			"nombre": nodo.name,
			"tipo": nodo.get_class(),
			"ruta": str(nodo.get_path()),
			"script": script.resource_path if script is Script else "",
			"process": nodo.is_processing(),
			"physics": nodo.is_physics_processing()
		})
		for hijo in nodo.get_children():
			pendientes.append({"nodo": hijo, "nivel": nivel + 1})
		if salida.size() >= 800:
			break
	return salida

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
