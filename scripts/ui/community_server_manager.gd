extends Control

signal closed

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

const PROFILES_PATH := "user://garlia_community_servers.json"

var _profiles: Array = []
var _list: ItemList
var _name: LineEdit
var _description: LineEdit
var _port: SpinBox
var _status: Label


var _server_pid: int = -1
var _start_local_button: Button
var _stop_local_button: Button
var _file_dialog: FileDialog


func _ready() -> void:
	_build_ui()
	_load_profiles()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_local_theme()

	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.020, 0.017, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	# El panel usa márgenes relativos: se adapta a ventanas pequeñas.
	var panel := PanelContainer.new()
	panel.anchor_left = 0.06
	panel.anchor_top = 0.055
	panel.anchor_right = 0.94
	panel.anchor_bottom = 0.945
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 18)
	outer.add_theme_constant_override("margin_right", 18)
	outer.add_theme_constant_override("margin_top", 16)
	outer.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(outer)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	outer.add_child(layout)

	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 4)
	layout.add_child(heading)

	var title := Label.new()
	title.text = "SERVIDORES DE COMUNIDAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#e8c99e"))
	heading.add_child(title)

	var intro := Label.new()
	intro.text = "Crea y administra un servidor LAN desde este equipo. Para jugar por Internet necesitarás alojamiento público."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#b9a58d"))
	heading.add_child(intro)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color("#66503b"))
	layout.add_child(separator)

	# Todo el formulario y sus acciones pueden desplazarse; el botón Volver
	# queda fuera del ScrollContainer para que nunca desaparezca bajo el borde.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	scroll.add_child(content)

	var profiles_title := Label.new()
	profiles_title.text = "PERFILES GUARDADOS"
	profiles_title.add_theme_color_override("font_color", Color("#d5b58c"))
	content.add_child(profiles_title)

	_list = ItemList.new()
	_list.custom_minimum_size.y = 100
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_color_override("font_color", Color("#eadbc8"))
	_list.add_theme_color_override("font_selected_color", Color("#fff4e5"))
	_list.add_theme_stylebox_override("panel", _make_field_style())
	_list.item_selected.connect(_select_profile)
	content.add_child(_list)

	_name = _add_line(content, "Nombre del servidor")
	_description = _add_line(content, "Descripción")
	_port = _add_spin(content, "Puerto local", 1024, 65535, 7778)

	var profile_actions := VBoxContainer.new()
	profile_actions.add_theme_constant_override("separation", 6)
	content.add_child(profile_actions)
	_add_button(profile_actions, "Guardar perfil", _save_profile)
	_add_button(profile_actions, "Eliminar perfil", _delete_profile)

	var server_title := Label.new()
	server_title.text = "SERVIDOR LOCAL"
	server_title.add_theme_color_override("font_color", Color("#d5b58c"))
	content.add_child(server_title)

	_start_local_button = Button.new()
	_start_local_button.text = "Iniciar servidor LAN"
	_start_local_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_local_button.pressed.connect(_start_local_server)
	_style_button(_start_local_button, true)
	content.add_child(_start_local_button)

	_stop_local_button = Button.new()
	_stop_local_button.text = "Detener servidor"
	_stop_local_button.disabled = true
	_stop_local_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stop_local_button.pressed.connect(_stop_local_server)
	_style_button(_stop_local_button, false)
	content.add_child(_stop_local_button)

	var certificate_title := Label.new()
	certificate_title.text = "CERTIFICADO DE CONEXIÓN"
	certificate_title.add_theme_color_override("font_color", Color("#d5b58c"))
	content.add_child(certificate_title)
	var certificate_actions := VBoxContainer.new()
	certificate_actions.add_theme_constant_override("separation", 6)
	content.add_child(certificate_actions)
	_add_button(certificate_actions, "Exportar certificado", _export_certificate)
	_add_button(certificate_actions, "Confiar en certificado", _import_certificate)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.crt", "Certificado TLS")
	_file_dialog.file_selected.connect(_save_certificate_copy)
	add_child(_file_dialog)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "El certificado se genera automáticamente al iniciar el servidor."
	_status.add_theme_color_override("font_color", Color("#c7ad8e"))
	content.add_child(_status)

	var footer_line := HSeparator.new()
	footer_line.add_theme_color_override("separator", Color("#66503b"))
	layout.add_child(footer_line)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(footer)
	var back_button := Button.new()
	back_button.text = "Volver"
	back_button.custom_minimum_size = Vector2(130, 38)
	back_button.pressed.connect(queue_free)
	_style_button(back_button, false)
	footer.add_child(back_button)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#292017")
	style.border_color = Color("#806044")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _make_field_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1c1712")
	style.border_color = Color("#59432f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _style_button(button: Button, emphasized: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#765236") if emphasized else Color("#403126")
	normal.border_color = Color("#b58a5b") if emphasized else Color("#72563d")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#896344") if emphasized else Color("#594331")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#5a3d29")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _make_field_style())
	button.add_theme_color_override("font_color", Color("#f0dfc9"))
	button.add_theme_color_override("font_hover_color", Color("#fff2df"))
	button.add_theme_color_override("font_disabled_color", Color("#827362"))
	button.add_theme_font_size_override("font_size", 14)


func _apply_local_theme() -> void:
	var theme := Theme.new()
	theme.set_color("font_color", "Label", Color("#e4d2bc"))
	theme.set_color("font_color", "LineEdit", Color("#f0dfc9"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("#9b8874"))
	theme.set_color("font_color", "SpinBox", Color("#f0dfc9"))
	theme.set_color("font_color", "ItemList", Color("#e4d2bc"))
	theme.set_stylebox("normal", "LineEdit", _make_field_style())
	theme.set_stylebox("focus", "LineEdit", _make_field_style())
	theme.set_stylebox("normal", "SpinBox", _make_field_style())
	theme.set_stylebox("read_only", "LineEdit", _make_field_style())
	self.theme = theme


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()


func _add_line(parent: VBoxContainer, hint: String) -> LineEdit:
	var label := Label.new()
	label.text = hint
	parent.add_child(label)
	var field := LineEdit.new()
	field.placeholder_text = hint
	parent.add_child(field)
	return field


func _add_spin(parent: VBoxContainer, label_text: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.value = initial
	field.step = 1
	parent.add_child(field)
	return field


func _add_button(parent: Container, label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)


func _load_profiles() -> void:
	_profiles.clear()
	_list.clear()
	if not FileAccess.file_exists(PROFILES_PATH):
		return
	var file := FileAccess.open(PROFILES_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		return
	for value in parsed:
		if value is Dictionary and not str(value.get("name", "")).strip_edges().is_empty():
			_profiles.append(value)
			_list.add_item("%s  |  :%s" % [value.get("name", "Servidor"), value.get("port", 7778)])


func _write_profiles() -> bool:
	var file := FileAccess.open(PROFILES_PATH, FileAccess.WRITE)
	if file == null:
		_status.text = "No se pudo guardar la lista de perfiles."
		return false
	file.store_string(JSON.stringify(_profiles, "\t"))
	file.close()
	return true


func _select_profile(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	var profile: Dictionary = _profiles[index]
	_name.text = str(profile.get("name", ""))
	_description.text = str(profile.get("description", ""))
	_port.value = int(profile.get("port", 7778))


func _save_profile() -> void:
	var server_name := _name.text.strip_edges()
	if server_name.is_empty():
		_status.text = "Escribe un nombre para el servidor."
		return
	var profile := {"name": server_name, "description": _description.text.strip_edges(), "port": int(_port.value), "max_players": 8}
	var selected := _list.get_selected_items()
	if selected.size() > 0 and selected[0] < _profiles.size():
		_profiles[selected[0]] = profile
	else:
		_profiles.append(profile)
	if _write_profiles():
		_load_profiles()
		_status.text = "Perfil guardado en este dispositivo."


func _delete_profile() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		_status.text = "Selecciona un perfil."
		return
	_profiles.remove_at(selected[0])
	if _write_profiles():
		_load_profiles()
		_status.text = "Perfil eliminado. No se borraron mundos ni certificados."


func _ensure_server_certificate() -> bool:
	var cert_dir := ProjectSettings.globalize_path("user://certs")
	var dir_error := DirAccess.make_dir_recursive_absolute(cert_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_status.text = "No se pudo crear la carpeta de certificados."
		return false
	var cert_path := ProjectSettings.globalize_path("user://certs/garlia_server.crt")
	var key_path := ProjectSettings.globalize_path("user://certs/garlia_server.key")
	if FileAccess.file_exists(cert_path) and FileAccess.file_exists(key_path):
		return true
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	if key == null:
		_status.text = "No se pudo generar la clave TLS."
		return false
	var cert := crypto.generate_self_signed_certificate(key, "CN=Garlia LAN Server")
	if cert == null:
		_status.text = "No se pudo generar el certificado TLS."
		return false
	var key_error := key.save(key_path)
	var cert_error := cert.save(cert_path)
	if key_error != OK or cert_error != OK:
		_status.text = "No se pudo guardar el certificado TLS."
		return false
	return true


func _start_local_server() -> void:
	if _server_pid > 0:
		_status.text = "El servidor ya está iniciado (proceso %d)." % _server_pid
		return
	if not _ensure_server_certificate():
		return
	var selected := _list.get_selected_items()
	if selected.is_empty():
		if _name.text.strip_edges().is_empty():
			_status.text = "Escribe un nombre y guarda el perfil antes de iniciar."
			return
		_save_profile()
		if not _profiles.is_empty():
			_list.select(_profiles.size() - 1)
		selected = _list.get_selected_items()
	if selected.is_empty():
		_status.text = "Guarda y selecciona un perfil antes de iniciar."
		return
	var port := int(_profiles[selected[0]].get("port", 7778))
	var project_path := ProjectSettings.globalize_path("res://")
	var cert_path := ProjectSettings.globalize_path("user://certs/garlia_server.crt")
	var key_path := ProjectSettings.globalize_path("user://certs/garlia_server.key")
	var executable := OS.get_executable_path()
	var arguments := PackedStringArray(["--headless", "--path", project_path, "--", "--garlia-server", "--port=%d" % port, "--tls-cert=%s" % cert_path, "--tls-key=%s" % key_path])
	_server_pid = OS.create_process(executable, arguments, false)
	if _server_pid <= 0:
		_status.text = "No se pudo iniciar el proceso de servidor. Comprueba que el juego esté instalado."
		return
	_start_local_button.disabled = true
	_stop_local_button.disabled = false
	var ips := PackedStringArray(IP.get_local_addresses())
	var usable_ips: Array[String] = []
	for ip in ips:
		if "." in ip and ip != "127.0.0.1" and not usable_ips.has(ip):
			usable_ips.append(ip)
	_status.text = "Servidor iniciado. LAN: %s:%d. Comparte también el certificado con tus amigos." % [", ".join(usable_ips) if not usable_ips.is_empty() else "127.0.0.1", port]


func _stop_local_server() -> void:
	if _server_pid > 0:
		OS.kill(_server_pid)
		_server_pid = -1
	_start_local_button.disabled = false
	_stop_local_button.disabled = true
	_status.text = "Se solicitó detener el servidor local."


func _export_certificate() -> void:
	var cert_path := ProjectSettings.globalize_path("user://certs/garlia_server.crt")
	if not FileAccess.file_exists(cert_path):
		_status.text = "Inicia el servidor primero para generar el certificado."
		return
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.current_file = "garlia_server.crt"
	_file_dialog.popup_centered_ratio(0.7)


func _save_certificate_copy(destination: String) -> void:
	var source := FileAccess.open("user://certs/garlia_server.crt", FileAccess.READ)
	if source == null:
		_status.text = "No se pudo leer el certificado."
		return
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		_status.text = "No se pudo guardar el certificado exportado."
		return
	output.store_buffer(bytes)
	output.close()
	_status.text = "Certificado exportado. Compártelo por un canal seguro con quienes se unirán."


func _import_certificate() -> void:
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.current_file = ""
	_file_dialog.file_selected.disconnect(_save_certificate_copy)
	_file_dialog.file_selected.connect(_trust_certificate_copy, CONNECT_ONE_SHOT)
	_file_dialog.popup_centered_ratio(0.7)


func _trust_certificate_copy(source_path: String) -> void:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		_status.text = "No se pudo leer el certificado seleccionado."
		return
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var directory := ProjectSettings.globalize_path("user://certs")
	DirAccess.make_dir_recursive_absolute(directory)
	var destination := FileAccess.open("user://certs/trusted_server.crt", FileAccess.WRITE)
	if destination == null:
		_status.text = "No se pudo instalar el certificado de confianza."
		return
	destination.store_buffer(bytes)
	destination.close()
	_file_dialog.file_selected.disconnect(_trust_certificate_copy)
	_file_dialog.file_selected.connect(_save_certificate_copy)
	_status.text = "Certificado instalado. Ya puedes conectar a ese servidor."


func _slug(value: String) -> String:
	var result := value.to_lower()
	for character in [" ", "/", "\\", ":", "*", "?", "\"",
		"<", ">", "|", "."]:
		result = result.replace(character, "_")
	while "__" in result:
		result = result.replace("__", "_")
	return result.strip_edges()
