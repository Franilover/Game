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
	"rendimiento", "arbol", "logs", "flujo"
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
	var copiar := Button.new()
	copiar.text = "Copiar diagnóstico"
	copiar.focus_mode = Control.FOCUS_NONE
	copiar.pressed.connect(_copiar_actual)
	botones.add_child(copiar)
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
	for grupo in ["player", "creatures", "world_props", "inventory"]:
		out.append("  %-18s %d" % [grupo, get_tree().get_nodes_in_group(grupo).size()])
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

	var nombres := ["WorldGenerator", "WorldTerrain", "WorldTerrainVisual", "WorldStreamer", "WorldContext", "ZoneManager"]
	for nombre in nombres:
		var nodo := _buscar_por_nombre(nombre)
		if nodo == null:
			out.append("[--] %s | NO ENCONTRADO" % nombre)
		else:
			out.append("[OK] %s | %s | %s" % [nombre, nodo.get_path(), _script(nodo)])
			var diag: Variant = _diagnostico_nodo(nodo)
			if diag is Dictionary:
				out.append("     " + JSON.stringify(diag))
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
	var out := _encabezado("RENDIMIENTO")
	for clave in datos:
		out.append("%-24s %s" % [str(clave), JSON.stringify(datos[clave])])
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

func _copiar_actual() -> void:
	DisplayServer.clipboard_set(_texto.text)
	_estado.text = "Diagnóstico copiado"

func _limpiar() -> void:
	_garlia_debug().call("limpiar")
	_actualizar_vista()
