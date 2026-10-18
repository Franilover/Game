extends CanvasLayer
class_name GarliaDebugConsole

func _garlia_debug() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GarliaDebug")

var _panel: PanelContainer
var _texto: RichTextLabel
var _titulo: Label
var _estado: Label
var _tabs: HBoxContainer
var _abierto := false
var _modo := "resumen"
var _auto_scroll := true
var _actualizando_vista := false

const MODOS := [
	"resumen", "sistemas", "mundo", "entidades", "datos",
	"rendimiento", "arbol", "render", "engine", "supabase", "logs", "flujo"
]

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_interfaz()
	visible = false
	var debug := _garlia_debug()
	if is_instance_valid(debug):
		if debug.has_signal("evento_agregado"):
			debug.connect("evento_agregado", Callable(self, "_al_evento"))
		if debug.has_signal("flujo_actualizado"):
			debug.connect("flujo_actualizado", Callable(self, "_actualizar_vista"))
		_actualizar_vista()

func _process(_delta: float) -> void:
	if _abierto and _modo != "logs" and _modo != "flujo":
		_actualizar_vista()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.keycode == KEY_F4:
		if _abierto:
			cerrar()
		else:
			abrir()
		get_viewport().set_input_as_handled()
	elif _abierto and tecla.keycode == KEY_ESCAPE:
		cerrar()
		get_viewport().set_input_as_handled()

func abrir() -> void:
	_abierto = true
	visible = true
	_actualizar_vista()

func cerrar() -> void:
	_abierto = false
	visible = false

func _crear_interfaz() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 16
	_panel.offset_top = 14
	_panel.offset_right = -16
	_panel.offset_bottom = -14
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 1000
	add_child(_panel)

	var columna := VBoxContainer.new()
	_panel.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	_titulo = Label.new()
	_titulo.text = "GARLIA UNIVERSAL MONITOR"
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.add_theme_font_size_override("font_size", 16)
	cabecera.add_child(_titulo)
	_estado = Label.new()
	cabecera.add_child(_estado)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	columna.add_child(_tabs)
	for modo in MODOS:
		var boton := Button.new()
		boton.text = modo.to_upper()
		boton.toggle_mode = true
		boton.focus_mode = Control.FOCUS_NONE
		boton.mouse_filter = Control.MOUSE_FILTER_STOP
		boton.pressed.connect(_al_tab.bind(modo))
		_tabs.add_child(boton)

	var botones := HBoxContainer.new()
	columna.add_child(botones)
	var copiar_errores := Button.new()
	copiar_errores.text = "Copiar errores"
	copiar_errores.focus_mode = Control.FOCUS_NONE
	copiar_errores.pressed.connect(_copiar_errores)
	botones.add_child(copiar_errores)
	var copiar := Button.new()
	copiar.text = "Copiar diagnóstico"
	copiar.focus_mode = Control.FOCUS_NONE
	copiar.pressed.connect(_copiar_actual)
	botones.add_child(copiar)
	var copiar_terreno := Button.new()
	copiar_terreno.text = "Copiar terreno real"
	copiar_terreno.focus_mode = Control.FOCUS_NONE
	copiar_terreno.pressed.connect(_copiar_diagnostico_terreno_real)
	botones.add_child(copiar_terreno)
	var limpiar := Button.new()
	limpiar.text = "Limpiar logs"
	limpiar.focus_mode = Control.FOCUS_NONE
	limpiar.pressed.connect(_limpiar)
	botones.add_child(limpiar)
	var auto := CheckButton.new()
	auto.text = "Auto"
	auto.button_pressed = true
	auto.toggled.connect(func(v: bool): _auto_scroll = v)
	botones.add_child(auto)
	var cerrar_boton := Button.new()
	cerrar_boton.text = "Cerrar (Esc)"
	cerrar_boton.focus_mode = Control.FOCUS_NONE
	cerrar_boton.pressed.connect(cerrar)
	botones.add_child(cerrar_boton)

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = false
	_texto.scroll_active = true
	_texto.fit_content = false
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.custom_minimum_size = Vector2(0, 300)
	columna.add_child(_texto)

func _al_tab(modo: String) -> void:
	if not MODOS.has(modo):
		return
	_modo = modo
	_actualizar_vista()

func _al_evento(_evento: Dictionary) -> void:
	if _abierto and (_modo == "logs" or _modo == "resumen"):
		_actualizar_vista()

func _actualizar_vista() -> void:
	# GarliaDebug emite señales también durante el gameplay normal. No volver a
	# construir el resumen completo mientras la consola está oculta: las
	# recogidas generan varios eventos de diagnóstico por objeto.
	if not _abierto or not visible:
		return
	if _actualizando_vista or not is_instance_valid(_texto):
		return
	_actualizando_vista = true
	_actualizar_pestanas()
	match _modo:
		"resumen":
			_texto.text = _vista_resumen()
		"sistemas":
			_texto.text = _vista_sistemas()
		"mundo":
			_texto.text = _vista_mundo()
		"entidades":
			_texto.text = _vista_entidades()
		"datos":
			_texto.text = _vista_datos()
		"rendimiento":
			_texto.text = _vista_rendimiento()
		"arbol":
			_texto.text = _vista_arbol()
		"render":
			_texto.text = _vista_render()
		"engine":
			_texto.text = _vista_engine()
		"supabase":
			_texto.text = _vista_supabase()
		"logs":
			_texto.text = str(_garlia_debug().call("obtener_logs_texto"))
		"flujo":
			_texto.text = str(_garlia_debug().call("obtener_flujo_texto"))
	_estado.text = "F4 | %s | %s" % [_modo.to_upper(), Time.get_time_string_from_system()]
	if _auto_scroll:
		_texto.scroll_to_line(maxi(0, _texto.get_line_count() - 1))
	_actualizando_vista = false

func _actualizar_pestanas() -> void:
	for hijo in _tabs.get_children():
		if hijo is Button:
			(hijo as Button).button_pressed = (hijo as Button).text.to_lower() == _modo

func _encabezado(titulo: String) -> PackedStringArray:
	return PackedStringArray(["", "=== " + titulo + " ==="])

func _vista_resumen() -> String:
	var out := _encabezado("SALUD GLOBAL")
	out.append("FPS: %d | Nodes: %d | Objects: %d" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT)
	])
	out.append("Escena: " + (get_tree().current_scene.scene_file_path if get_tree().current_scene else "<ninguna>"))
	out.append("Pausado: %s | TimeScale: %.2f" % [str(get_tree().paused), Engine.time_scale])
	var debug := _garlia_debug()
	var proveedores: Array = debug.call("obtener_proveedores")
	out.append("")
	out.append("SISTEMAS REGISTRADOS: %d" % proveedores.size())
	for p in proveedores:
		out.append(_estado_linea(p))
	out.append("")
	out.append("GRUPOS ACTIVOS")
	var entity_manager := _buscar_por_nombre("WorldEntityManager")
	if entity_manager != null and entity_manager.has_method("obtener_diagnostico_datos"):
		out.append("LOD DATA ENTIDADES: " + JSON.stringify(entity_manager.call("obtener_diagnostico_datos")))
	for grupo in ["player", "creatures", "world_props", "inventory"]:
		out.append("  %-18s %d" % [grupo, get_tree().get_nodes_in_group(grupo).size()])
	out.append("")
	out.append(_errores_globales())
	return "\n".join(out)

func _estado_linea(p: Dictionary) -> String:
	var estado := str(p.get("estado", "OK")).to_upper()
	var marca := "OK" if estado in ["OK", "READY", "LISTO"] else ("!!" if estado in ["ERROR", "FAIL", "FATAL"] else "??")
	var detalle := str(p.get("detalle", p.get("descripcion", "")))
	return "  [%s] %-22s %s | %s" % [marca, str(p.get("sistema", p.get("id", ""))), str(p.get("node_path", "")), detalle]

func _vista_sistemas() -> String:
	var out := _encabezado("SISTEMAS / PROVEEDORES")
	var proveedores: Array = _garlia_debug().call("obtener_proveedores")
	if proveedores.is_empty():
		out.append("No hay proveedores registrados.")
		out.append("Los sistemas pueden registrarse con GarliaDebug.registrar_proveedor().")
	else:
		for p in proveedores:
			out.append(_estado_linea(p))
			if p.has("script"):
				out.append("      script: " + str(p["script"]))
			if p.has("datos"):
				out.append("      estado: " + JSON.stringify(p["datos"]))
	return "\n".join(out)

func _vista_mundo() -> String:
	var out := _encabezado("MUNDO / STREAMING / TERRENO")
	for grupo in ["world_props", "creatures"]:
		out.append("%s activos: %d" % [grupo, get_tree().get_nodes_in_group(grupo).size()])
	var zona_manager: Node = _buscar_por_nombre("ZoneManager")
	if zona_manager != null:
		var zona_diag: Variant = _diagnostico_nodo(zona_manager)
		if zona_diag is Dictionary:
			out.append("ZONA ACTIVA: " + JSON.stringify(zona_diag))
			out.append("")

	var nombres := ["WorldGenerator", "WorldTerrain", "WorldTerrainVisual", "WorldStreamer", "GarliaRenderManager", "WorldContext", "ZoneManager"]
	for nombre in nombres:
		var nodo := _buscar_por_nombre(nombre)
		if nodo == null:
			out.append("[--] %s | NO ENCONTRADO" % nombre)
		else:
			out.append("[OK] %s | %s | %s" % [nombre, nodo.get_path(), _script(nodo)])
			var diag: Variant = _diagnostico_nodo(nodo)
			if diag is Dictionary:
				out.append("     " + JSON.stringify(diag))
				if nombre == "WorldStreamer" and diag.has("lod_logico"):
					var lod: Dictionary = diag["lod_logico"]
					var counts: Dictionary = lod.get("counts", {})
					out.append("     LOD LOGICO: FULL=%s TERRAIN=%s DATA=%s" % [
						str(counts.get("FULL", 0)),
						str(counts.get("TERRAIN", 0)),
						str(counts.get("DATA", 0))
					])
				if nombre == "WorldTerrain" and diag.has("flush_estado"):
					var flush_estado: Dictionary = diag["flush_estado"]
					out.append("     PIPELINE FLUSH: pendiente=%s total=%s ultima=%s/%s %.3fms (convert %.3f + update %.3f)" % [str(flush_estado.get("pendiente", false)), str(flush_estado.get("pendientes_total", 0)), str(flush_estado.get("ultima_zona", "")), str(flush_estado.get("ultima_cantidad", 0)), float(flush_estado.get("ultimo_ms", 0.0)), float(flush_estado.get("ultimo_convert_ms", 0.0)), float(flush_estado.get("ultimo_update_ms", 0.0))])

	var dual := _diagnostico_dual_grid()
	out.append("")
	out.append("DUAL GRID / RECOMPOSICION")
	out.append("  TileMapDual activos: %d | layers: %d" % [int(dual.get("tilemaps", 0)), int(dual.get("layers", 0))])
	out.append("  update_calls=%d world_cells=%d candidates=%d rules=%d" % [
		int(dual.get("update_calls", 0)),
		int(dual.get("world_cells", 0)),
		int(dual.get("display_candidates", 0)),
		int(dual.get("rule_evaluations", 0))
	])
	out.append("  redundantes=%d set_cell=%d" % [
		int(dual.get("redundant_tiles", 0)),
		int(dual.get("set_cells", 0))
	])
	if int(dual.get("display_candidates", 0)) > 0:
		var candidatos: float = float(dual.get("display_candidates", 0))
		var set_count: float = float(dual.get("set_cells", 0))
		out.append("  eficiencia: %.1f%% sin set_cell" % [100.0 * (1.0 - set_count / candidatos)])
	return "\n".join(out)

func _vista_entidades() -> String:
	var out := _encabezado("ENTIDADES / CRIATURAS / IA")
	for grupo in ["player", "creatures", "world_props", "inventory"]:
		var nodos := get_tree().get_nodes_in_group(grupo)
		out.append("%s: %d" % [grupo, nodos.size()])
		for nodo in nodos.slice(0, mini(nodos.size(), 12)):
			out.append("  - %s | %s" % [nodo.get_path(), _script(nodo)])
	return "\n".join(out)

func _vista_datos() -> String:
	var out := _encabezado("DATOS / FUENTES")
	var nombres := ["WorldContext", "WorldItems", "IUMRepository", "IUMManager"]
	for nombre in nombres:
		var nodo := _buscar_por_nombre(nombre)
		if nodo == null:
			out.append("[--] %s | NO ENCONTRADO" % nombre)
		else:
			out.append("[OK] %s | %s" % [nombre, nodo.get_path()])
			var diag: Variant = _diagnostico_nodo(nodo)
			if diag is Dictionary:
				out.append("     " + JSON.stringify(diag))
	return "\n".join(out)

func _vista_rendimiento() -> String:
	var datos: Dictionary = _garlia_debug().call("obtener_rendimiento")
	var out := _encabezado("RENDIMIENTO / CUELLOS DE BOTELLA")
	for clave in ["fps","frame_ms_aprox","process_ms","physics_ms","nodes","objects","orphans","draw_calls","render_objects","render_primitives","physics_2d_active","physics_2d_pairs"]:
		if datos.has(clave):
			out.append("%-24s %s" % [clave, JSON.stringify(datos[clave])])
	out.append("")
	out.append("TRABAJO ACUMULADO")
	var work_ms: Dictionary = datos.get("work_ms", {})
	var work_calls: Dictionary = datos.get("work_calls", {})
	var work_unit: Dictionary = datos.get("work_unit_ms", {})
	var work_max: Dictionary = datos.get("work_max_ms", {})
	var work_last: Dictionary = datos.get("work_last_ms", {})
	var claves: Array = work_ms.keys()
	claves.sort_custom(func(a: Variant, b: Variant) -> bool: return float(work_ms.get(a, 0.0)) > float(work_ms.get(b, 0.0)))
	for clave_variant in claves:
		var clave := str(clave_variant)
		out.append("  %-22s total=%8.2fms calls=%4d unit=%7.4fms max=%7.2fms last=%7.2fms" % [clave, float(work_ms.get(clave, 0.0)), int(work_calls.get(clave, 0)), float(work_unit.get(clave, 0.0)), float(work_max.get(clave, 0.0)), float(work_last.get(clave, 0.0))])
	out.append("")
	out.append("TRABAJO DEL FRAME")
	var frame_work: Dictionary = datos.get("frame_work_ms", {})
	for clave_variant in frame_work.keys():
		out.append("  %-22s %8.3fms" % [str(clave_variant), float(frame_work.get(clave_variant, 0.0))])
	out.append("")
	out.append("PRESUPUESTO")
	for clave in ["render_budget_ms","terrain_service_reserve_ms","frame_used_ms","budget_remaining_ms","deferred_work"]:
		out.append("  %-22s %s" % [clave, JSON.stringify(datos.get(clave, "<n/a>"))])
	return "\n".join(out)

func _vista_render() -> String:
	var out := _encabezado("AUDITORIA ABSOLUTA DE RENDER / VISIBILIDAD")
	var datos: Dictionary = _garlia_debug().call("obtener_auditoria_render")
	out.append("ESTADO GLOBAL: " + str(datos.get("estado", "DESCONOCIDO")))
	out.append("")
	out.append("PRUEBAS AUTOMATICAS")
	for prueba in datos.get("pruebas", []):
		var ok: bool = bool(prueba.get("ok", false))
		out.append("  [%s] %s | %s" % [
			"OK" if ok else "FAIL",
			str(prueba.get("prueba", "")),
			str(prueba.get("detalle", ""))
		])
	out.append("")
	out.append("PROBLEMAS DETECTADOS")
	var problemas: Array = datos.get("problemas", [])
	if problemas.is_empty():
		out.append("  Ninguno por las pruebas automaticas actuales.")
	else:
		for problema in problemas:
			out.append("  [!] " + str(problema))
	out.append("")
	out.append("CAMARAS")
	for cam in datos.get("cameras", []):
		out.append("  %s | enabled=%s visible=%s pos=%s zoom=%s" % [
			str(cam.get("path", "")), str(cam.get("enabled", false)),
			str(cam.get("visible", false)), str(cam.get("position", Vector2.ZERO)),
			str(cam.get("zoom", Vector2.ONE))
		])
	out.append("")
	out.append("TILEMAPS / FUENTES / CELDAS")
	for tm in datos.get("tilemaps", []):
		if int(tm.get("used_cells", 0)) <= 0:
			continue
		out.append("  %s" % str(tm.get("path", "")))
		out.append("      visible=%s tree=%s z=%s pos=%s cells=%s sources=%s tile_size=%s" % [
			str(tm.get("visible", false)), str(tm.get("visible_tree", false)),
			str(tm.get("z_index", 0)), str(tm.get("global_position", Vector2.ZERO)),
			str(tm.get("used_cells", 0)), str(tm.get("source_count", 0)),
			str(tm.get("tile_size", Vector2i.ZERO))
		])
		for source in tm.get("sources", []):
			out.append("      source: " + str(source))
	out.append("")
	out.append("TODOS LOS CANVAS ITEMS")
	for item in datos.get("canvas_items", []):
		out.append("  %s | %s | visible=%s/tree=%s z=%s pos=%s material=%s" % [
			str(item.get("type", "")), str(item.get("path", "")),
			str(item.get("visible", false)), str(item.get("visible_tree", false)),
			str(item.get("z_index", 0)), str(item.get("global_position", Vector2.ZERO)),
			str(item.get("material", ""))
		])
	return "\n".join(out)

func _vista_supabase() -> String:
	var out := _encabezado("SUPABASE / CONEXION / CATALOGO / CACHES")
	var datos: Dictionary = _garlia_debug().call("obtener_auditoria_supabase")
	out.append("ESTADO: " + str(datos.get("estado", "DESCONOCIDO")))
	out.append("CLIENTE: " + str(datos.get("cliente_path", "<ninguno>")))
	out.append("SCRIPT: " + str(datos.get("script", "<ninguno>")))
	out.append("")
	out.append("PROBLEMAS")
	var problemas: Array = datos.get("problemas", [])
	if problemas.is_empty():
		out.append("  Ninguno detectado por el monitor.")
	else:
		for problema in problemas:
			out.append("  [!] " + str(problema))
	var d: Dictionary = datos.get("datos", {})
	out.append("")
	out.append("CONFIGURACION")
	for clave in ["auth_node","configurado","autenticado","url_configurada","publishable_key_configurada","supabase_url"]:
		out.append("  %-28s %s" % [clave, JSON.stringify(d.get(clave, "<n/a>"))])
	out.append("")
	out.append("CACHES CANONICAS")
	var cache: Dictionary = d.get("cache", {})
	for clave in cache:
		out.append("  %-28s %s" % [str(clave), str(cache[clave])])
	out.append("")
	out.append("HTTP REQUESTS")
	for request in d.get("requests", []):
		out.append("  %-28s existe=%s estado=%s" % [
			str(request.get("nombre", "")),
			str(request.get("existe", false)),
			str(request.get("estado", -1))
		])
	out.append("")
	out.append("PROBES DISPONIBLES")
	out.append("  El cliente incluye prueba GET segura sobre reinos_game.")
	out.append("  Para errores reales de backend: revisar HTTP status y logs de Supabase.")
	return "\n".join(out)

func _vista_engine() -> String:
	var out := _encabezado("AUDITORIA UNIVERSAL DEL MOTOR")
	var datos: Dictionary = _garlia_debug().call("obtener_auditoria_engine")
	out.append("ESTADO GLOBAL: " + str(datos.get("estado", "DESCONOCIDO")))
	out.append("")
	out.append("PROBLEMAS")
	var problemas: Array = datos.get("problemas", [])
	if problemas.is_empty():
		out.append("  Ninguno detectado.")
	else:
		for problema in problemas:
			out.append("  [!] " + str(problema))
	var d: Dictionary = datos.get("datos", {})
	out.append("")
	out.append("RUNTIME")
	for clave in ["scene","paused","time_scale","frame","physics_frame","delta","physics_delta","fps","node_count","object_count","orphan_nodes","draw_calls","render_objects","render_primitives","renderer","renderer_api","viewport_size"]:
		out.append("  %-22s %s" % [clave, JSON.stringify(d.get(clave, "<n/a>"))])
	out.append("")
	out.append("GRUPOS")
	for grupo in d.get("groups", {}):
		out.append("  %-28s %s" % [str(grupo), str(d["groups"][grupo])])
	out.append("")
	out.append("PROCESAMIENTO")
	for fila in d.get("processing_nodes", []):
		out.append("  %s | %s | process=%s physics=%s mode=%s priority=%s" % [
			str(fila["path"]), str(fila["type"]), str(fila["process"]),
			str(fila["physics"]), str(fila["mode"]), str(fila["priority"])
		])
	out.append("")
	out.append("TIMERS")
	for timer in d.get("timers", []):
		out.append("  %s | running=%s left=%.3f wait=%.3f one_shot=%s" % [
			str(timer["path"]), str(timer["running"]), float(timer["left"]),
			float(timer["wait"]), str(timer["one_shot"])
		])
	out.append("")
	out.append("CANVAS LAYERS")
	for layer in d.get("canvas_layers", []):
		out.append("  %s | layer=%s visible=%s follow=%s" % [
			str(layer["path"]), str(layer["layer"]), str(layer["visible"]), str(layer["follow_viewport"])
		])
	out.append("")
	out.append("SUBVIEWPORTS")
	for sv in d.get("subviewports", []):
		out.append("  %s | size=%s visible=%s update=%s" % [
			str(sv["path"]), str(sv["size"]), str(sv["visible"]), str(sv["update_mode"])
		])
	out.append("")
	out.append("SEÑALES CONECTADAS")
	for conexion in d.get("signal_connections", []):
		out.append("  %s :: %s -> %s conexión(es)" % [
			str(conexion["node"]), str(conexion["signal"]), str(conexion["connections"])
		])
	out.append("")
	out.append("SCRIPTS CARGADOS")
	for script in d.get("scripts", {}):
		out.append("  %s | instancias=%s" % [str(script), str(d["scripts"][script])])
	return "\n".join(out)

func _vista_arbol() -> String:
	var out := _encabezado("ÁRBOL DE ESCENA / DÓNDE BUSCAR")
	var filas: Array = _garlia_debug().call("obtener_arbol_diagnostico")
	for fila in filas:
		var prefijo := "  ".repeat(int(fila.get("nivel", 0)))
		var marca := ">" if bool(fila.get("process", false)) or bool(fila.get("physics", false)) else "-"
		out.append("%s%s %s [%s]" % [prefijo, marca, str(fila.get("nombre", "")), str(fila.get("tipo", ""))])
		out.append("%s    ruta: %s" % [prefijo, str(fila.get("ruta", ""))])
		var script := str(fila.get("script", ""))
		if not script.is_empty():
			out.append("%s    script: %s" % [prefijo, script])
	return "\n".join(out)

func _diagnostico_dual_grid() -> Dictionary:
	var out: Dictionary = {
		"tilemaps": 0,
		"layers": 0,
		"update_calls": 0,
		"world_cells": 0,
		"display_candidates": 0,
		"rule_evaluations": 0,
		"redundant_tiles": 0,
		"set_cells": 0,
	}
	var raiz: Node = get_tree().root
	if raiz == null:
		return out
	for nodo in _recorrer(raiz):
		if not nodo is TileMapDual:
			continue
		out["tilemaps"] = int(out["tilemaps"]) + 1
		if not nodo.has_method("obtener_diagnostico"):
			continue
		var diag: Variant = nodo.call("obtener_diagnostico")
		if not diag is Dictionary:
			continue
		var metricas: Dictionary = diag.get("renderer_metrics", {})
		out["layers"] = int(out["layers"]) + int(metricas.get("layers", 0))
		for clave in ["update_calls", "world_cells", "display_candidates", "rule_evaluations", "redundant_tiles", "set_cells"]:
			out[clave] = int(out[clave]) + int(metricas.get(clave, 0))
	return out


func _buscar_por_nombre(nombre: String) -> Node:
	# El mundo abierto es una zona dinámica cargada por ZoneManager.
	# No limitar la búsqueda a current_scene: la zona activa puede haber sido
	# instanciada después de arrancar Main y seguir siendo un hijo del árbol raíz.
	var raiz: Node = get_tree().root
	if raiz == null:
		return null
	for nodo in _recorrer(raiz):
		if nodo.name == nombre:
			return nodo
	return null

func _recorrer(raiz: Node) -> Array[Node]:
	var resultado: Array[Node] = [raiz]
	for hijo in raiz.get_children():
		resultado.append_array(_recorrer(hijo))
	return resultado

func _script(nodo: Node) -> String:
	var script: Variant = nodo.get_script()
	return script.resource_path if script is Script else "<sin script>"

func _diagnostico_nodo(nodo: Node) -> Variant:
	if nodo.has_method("obtener_diagnostico"):
		return nodo.call("obtener_diagnostico")
	if nodo.has_method("diagnostico_debug"):
		return nodo.call("diagnostico_debug")
	return null

func _errores_globales() -> String:
	var out := _encabezado("PROBLEMAS DETECTADOS EN TODAS LAS PESTAÑAS")
	var hallazgos: Array[String] = []
	var vistas := {
		"SISTEMAS": _vista_sistemas(),
		"MUNDO": _vista_mundo(),
		"ENTIDADES": _vista_entidades(),
		"DATOS": _vista_datos(),
		"RENDIMIENTO": _vista_rendimiento(),
		"ÁRBOL": _vista_arbol(),
		"RENDER": _vista_render(),
		"ENGINE": _vista_engine(),
		"SUPABASE": _vista_supabase(),
		"LOGS": str(_garlia_debug().call("obtener_logs_texto")),
		"FLUJO": str(_garlia_debug().call("obtener_flujo_texto"))
	}
	for nombre_tab in vistas:
		for linea in str(vistas[nombre_tab]).split("\n"):
			var limpia := linea.strip_edges()
			var mayus := limpia.to_upper()
			if mayus.contains("[FAIL]") or mayus.contains("[ERROR]") or mayus.contains("[!]") or mayus.contains("ERROR:") or mayus.contains("PARSE ERROR"):
				hallazgos.append("[%s] %s" % [nombre_tab, limpia])
	if hallazgos.is_empty():
		out.append("  Ningún error explícito detectado.")
	else:
		out.append("  Total: %d" % hallazgos.size())
		for hallazgo in hallazgos:
			out.append("  " + hallazgo)
	return "\n".join(out)

func _copiar_errores() -> void:
	var texto_errores := _errores_globales()
	DisplayServer.clipboard_set(texto_errores)
	_estado.text = "Errores copiados"

func _copiar_actual() -> void:
	DisplayServer.clipboard_set(_texto.text)
	_estado.text = "Diagnóstico copiado"


func _copiar_diagnostico_terreno_real() -> void:
	# Lee exclusivamente los nodos y celdas del mundo vivo. No genera mapas,
	# no altera tiles y no utiliza el generador aleatorio de dual_test.
	var out := PackedStringArray()
	var raiz: Node = get_tree().root
	var nodos := _recorrer(raiz)
	var jugador: Node2D = null
	var camara: Camera2D = get_viewport().get_camera_2d()
	var visual: Node = null
	var terreno: Node = null

	for nodo in nodos:
		if nodo.name == "WorldTerrainVisual":
			visual = nodo
		elif nodo.name == "WorldTerrain":
			terreno = nodo
		if jugador == null and nodo.is_in_group("player") and nodo is Node2D:
			jugador = nodo as Node2D

	out.append("GARLIA — DIAGNÓSTICO VISUAL DEL TERRENO REAL")
	out.append("Hora: %s | Frame: %d" % [Time.get_datetime_string_from_system(), Engine.get_process_frames()])
	out.append("Escena: %s" % (get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "<ninguna>"))
	out.append("Renderer: %s | Viewport: %s" % [RenderingServer.get_video_adapter_name(), str(get_viewport().size)])
	out.append("")

	if is_instance_valid(jugador):
		out.append("JUGADOR: path=%s global=%s" % [str(jugador.get_path()), str(jugador.global_position)])
	else:
		out.append("JUGADOR: no encontrado en grupo 'player'")
	if is_instance_valid(camara):
		out.append("CÁMARA: path=%s global=%s zoom=%s enabled=%s" % [str(camara.get_path()), str(camara.global_position), str(camara.zoom), str(camara.enabled)])
	else:
		out.append("CÁMARA: ninguna activa")
	out.append("")

	if is_instance_valid(terreno):
		out.append("WORLD TERRAIN: %s | script=%s" % [str(terreno.get_path()), _script(terreno)])
		var diag_terreno: Variant = _diagnostico_nodo(terreno)
		if diag_terreno is Dictionary:
			out.append("estado=" + JSON.stringify(diag_terreno))
	else:
		out.append("WORLD TERRAIN: no encontrado")

	if is_instance_valid(visual):
		out.append("")
		out.append("WORLD TERRAIN VISUAL: %s | script=%s" % [str(visual.get_path()), _script(visual)])
		for propiedad in ["tile_size", "_cell_bioma", "_cell_zone", "_cell_layer_key"]:
			var valor: Variant = visual.get(propiedad)
			if valor is Dictionary:
				out.append("%s: entradas=%d" % [propiedad, valor.size()])
			elif valor != null:
				out.append("%s: %s" % [propiedad, str(valor)])
		for propiedad_capas in ["_layers_by_zone", "_variation_layers_by_bioma"]:
			var capas_variant: Variant = visual.get(propiedad_capas)
			if capas_variant is Dictionary:
				out.append("%s:" % propiedad_capas)
				for clave in capas_variant:
					var capa: Variant = capas_variant[clave]
					out.append("  %s => %s" % [str(clave), str(capa.get_path()) if capa is Node else str(capa)])

	out.append("")
	out.append("CAPAS TILEMAPLAYER REALES Y CELDAS CERCA DEL JUGADOR")
	var total_capas := 0
	for nodo in nodos:
		if not nodo is TileMapLayer:
			continue
		var capa := nodo as TileMapLayer
		total_capas += 1
		var celdas: Array[Vector2i] = capa.get_used_cells()
		out.append("")
		out.append("CAPA %d: %s" % [total_capas, str(capa.get_path())])
		out.append("visible=%s visible_tree=%s z_index=%d y_sort=%s global=%s used_cells=%d tile_size=%s" % [
			str(capa.visible), str(capa.is_visible_in_tree()), capa.z_index,
			str(capa.y_sort_enabled), str(capa.global_position), celdas.size(),
			str(capa.tile_set.tile_size if capa.tile_set != null else Vector2i.ZERO)
		])
		if capa.tile_set == null:
			out.append("TileSet: NULL")
		else:
			for source_index in range(capa.tile_set.get_source_count()):
				var source_id: int = capa.tile_set.get_source_id(source_index)
				var source: TileSetSource = capa.tile_set.get_source(source_id)
				if source is TileSetAtlasSource:
					var atlas := source as TileSetAtlasSource
					out.append("source=%d type=Atlas texture=%s region_size=%s tiles=%d" % [
						source_id,
						atlas.texture.resource_path if atlas.texture != null else "<sin textura>",
						str(atlas.texture_region_size), atlas.get_tiles_count()
					])
				else:
					out.append("source=%d type=%s" % [source_id, source.get_class() if source != null else "<null>"])

		if not is_instance_valid(jugador):
			out.append("Muestra de celdas omitida: sin jugador.")
			continue
		var centro: Vector2i = capa.local_to_map(capa.to_local(jugador.global_position))
		out.append("centro_jugador_celda=%s" % str(centro))
		var muestra := 0
		for celda in celdas:
			if absi(celda.x - centro.x) > 4 or absi(celda.y - centro.y) > 4:
				continue
			out.append("  cell=%s source=%d atlas=%s alternative=%d" % [
				str(celda), capa.get_cell_source_id(celda),
				str(capa.get_cell_atlas_coords(celda)),
				capa.get_cell_alternative_tile(celda)
			])
			muestra += 1
			if muestra >= 100:
				out.append("  ... muestra limitada a 100 celdas por capa")
				break
		if muestra == 0:
			out.append("  No hay celdas usadas dentro de radio 4 del jugador.")
	if total_capas == 0:
		out.append("No se encontraron TileMapLayer en el árbol actual.")

	out.append("")
	out.append("TILEMAPDUAL: DIAGNÓSTICOS DE LOS NODOS REALES")
	var dual_count := 0
	for nodo in nodos:
		# TileMapDual es una clase GDScript que hereda de TileMapLayer.
		# Object.get_class()/is_class() sólo detectan clases nativas, así que
		# identificarlo por el nombre de instancia y su API de diagnóstico.
		if not (nodo is TileMapLayer):
			continue
		if not str(nodo.name).begins_with("TerrainDual_Zone_"):
			continue
		if not nodo.has_method("obtener_diagnostico"):
			continue
		dual_count += 1
		out.append("%s | visible=%s tree=%s z=%d" % [
			str(nodo.get_path()), str(nodo.visible) if nodo is CanvasItem else "<n/a>",
			str(nodo.is_visible_in_tree()), nodo.z_index if nodo is CanvasItem else 0
		])
		var dual_diag: Variant = _diagnostico_nodo(nodo)
		if dual_diag is Dictionary:
			out.append(JSON.stringify(dual_diag))
	if dual_count == 0:
		out.append("No se encontraron nodos TileMapDual.")

	var texto_diagnostico := "\n".join(out)
	DisplayServer.clipboard_set(texto_diagnostico)
	_texto.text = texto_diagnostico
	_modo = "mundo"
	_actualizar_pestanas()
	_estado.text = "Diagnóstico real del terreno copiado"


func _limpiar() -> void:
	_garlia_debug().call("limpiar")
	_actualizar_vista()