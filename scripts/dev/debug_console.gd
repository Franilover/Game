extends CanvasLayer
class_name GarliaDebugConsole

func _garlia_debug() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GarliaDebug")



var _panel: PanelContainer
var _texto: RichTextLabel
var _titulo: Label
var _estado: Label
var _tab_logs: Button
var _tab_flujo: Button
var _tab_estado: Button
var _abierto := false
var _modo := "logs"
var _auto_scroll := true
var _actualizando_vista := false

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_interfaz()
	visible = false
	if _garlia_debug().has_signal("evento_agregado"):
		_garlia_debug().connect("evento_agregado", Callable(self, "_al_evento"))
	if _garlia_debug().has_signal("flujo_actualizado"):
		_garlia_debug().connect("flujo_actualizado", Callable(self, "_actualizar_vista"))

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
		return
	if _abierto and tecla.keycode == KEY_ESCAPE:
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
	_panel.offset_left = 24
	_panel.offset_top = 20
	_panel.offset_right = -24
	_panel.offset_bottom = -20
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 1000
	add_child(_panel)

	var columna := VBoxContainer.new()
	_panel.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)

	_titulo = Label.new()
	_titulo.text = "GARLIA DEBUG"
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.add_theme_font_size_override("font_size", 14)
	cabecera.add_child(_titulo)

	_estado = Label.new()
	cabecera.add_child(_estado)

	var pestañas := HBoxContainer.new()
	columna.add_child(pestañas)

	_tab_logs = _crear_boton_pestana("LOGS", Callable(self, "_al_tab_logs"))
	pestañas.add_child(_tab_logs)

	_tab_flujo = _crear_boton_pestana("FLUJO", Callable(self, "_al_tab_flujo"))
	pestañas.add_child(_tab_flujo)

	_tab_estado = _crear_boton_pestana("ESTADO", Callable(self, "_al_tab_estado"))
	pestañas.add_child(_tab_estado)

	var botones := HBoxContainer.new()
	columna.add_child(botones)

	var copiar := Button.new()
	copiar.text = "Copiar"
	copiar.focus_mode = Control.FOCUS_NONE
	copiar.mouse_filter = Control.MOUSE_FILTER_STOP
	copiar.pressed.connect(_copiar_actual)
	botones.add_child(copiar)

	var limpiar := Button.new()
	limpiar.text = "Limpiar"
	limpiar.focus_mode = Control.FOCUS_NONE
	limpiar.mouse_filter = Control.MOUSE_FILTER_STOP
	limpiar.pressed.connect(_limpiar)
	botones.add_child(limpiar)

	var auto := CheckButton.new()
	auto.text = "Auto-scroll"
	auto.button_pressed = true
	auto.mouse_filter = Control.MOUSE_FILTER_STOP
auto.toggled.connect(_al_auto_scroll)
	botones.add_child(auto)

	var cerrar_boton := Button.new()
	cerrar_boton.text = "Cerrar (Esc)"
	cerrar_boton.focus_mode = Control.FOCUS_NONE
	cerrar_boton.mouse_filter = Control.MOUSE_FILTER_STOP
	cerrar_boton.pressed.connect(cerrar)
	botones.add_child(cerrar_boton)

	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = false
	_texto.scroll_active = true
	_texto.fit_content = false
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.custom_minimum_size = Vector2(0, 300)
	columna.add_child(_texto)

func _crear_boton_pestana(texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.focus_mode = Control.FOCUS_NONE
	boton.mouse_filter = Control.MOUSE_FILTER_STOP
	boton.pressed.connect(accion)
	return boton

func _al_tab_logs() -> void:
	_cambiar_modo("logs")

func _al_tab_flujo() -> void:
	_cambiar_modo("flujo")

func _al_tab_estado() -> void:
	_cambiar_modo("estado")

func _al_auto_scroll(valor: bool) -> void:
	_auto_scroll = valor

func _cambiar_modo(modo: String) -> void:
	if modo != "logs" and modo != "flujo" and modo != "estado":
		return
	_modo = modo
	_actualizar_estado_pestanas()
	_actualizar_vista()

func _actualizar_estado_pestanas() -> void:
	if is_instance_valid(_tab_logs):
		_tab_logs.button_pressed = _modo == "logs"
	if is_instance_valid(_tab_flujo):
		_tab_flujo.button_pressed = _modo == "flujo"
	if is_instance_valid(_tab_estado):
		_tab_estado.button_pressed = _modo == "estado"

func _al_evento(_evento: Dictionary) -> void:
	if _abierto and _modo == "logs":
		_actualizar_vista()

func _actualizar_vista() -> void:
	if _actualizando_vista or not is_instance_valid(_texto):
		return
	_actualizando_vista = true
	match _modo:
		"logs":
			_texto.text = _garlia_debug().call("obtener_logs_texto")
		"flujo":
			_texto.text = _garlia_debug().call("obtener_flujo_texto")
		"estado":
			_texto.text = _obtener_estado()
	_estado.text = "Modo: %s | Eventos: %d | Flujo: %d" % [
		_modo.to_upper(),
		(_garlia_debug().get("eventos") as Array).size(),
		(_garlia_debug().get("flujo") as Array).size()
	]
	if _auto_scroll:
		_texto.scroll_to_line(maxi(0, _texto.get_line_count() - 1))
	_actualizando_vista = false

func _obtener_estado() -> String:
	var salida := PackedStringArray()
	salida.append("=== RUNTIME ===")
	salida.append("Escena: " + get_tree().current_scene.scene_file_path if get_tree().current_scene else "Escena: <ninguna>")
	salida.append("Pausado: " + str(get_tree().paused))
	salida.append("FPS: " + str(Engine.get_frames_per_second()))
	salida.append("Tiempo escala: " + str(Engine.time_scale))

	var jugadores := get_tree().get_nodes_in_group("player")
	salida.append("Jugadores: " + str(jugadores.size()))

	var inventarios := get_tree().get_nodes_in_group("inventory")
	salida.append("Inventarios: " + str(inventarios.size()))

	if not inventarios.is_empty():
		var inv: Node = inventarios[0]
		if inv.has_method("serializar"):
			var datos_variant: Variant = inv.call("serializar")
			if datos_variant is Dictionary:
				var datos := datos_variant as Dictionary
				var items_variant: Variant = datos.get("items", [])
				if items_variant is Array:
					var ocupados := 0
					for item in items_variant:
						if item is Dictionary and not (item as Dictionary).is_empty():
							ocupados += 1
					salida.append("Slots ocupados: %d/%d" % [ocupados, (items_variant as Array).size()])

	return "\n".join(salida)

func _copiar_actual() -> void:
	var texto_actual := ""
	match _modo:
		"logs":
			texto_actual = _garlia_debug().call("obtener_logs_texto")
		"flujo":
			texto_actual = _garlia_debug().call("obtener_flujo_texto")
		"estado":
			texto_actual = _obtener_estado()
	DisplayServer.clipboard_set(texto_actual)
	_estado.text = "Copiado al portapapeles"

func _limpiar() -> void:
	_garlia_debug().call("limpiar")
	_actualizar_vista()
