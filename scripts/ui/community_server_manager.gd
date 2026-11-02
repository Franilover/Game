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
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color("#160F0A")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 24)
	center.add_theme_constant_override("margin_right", 24)
	center.add_theme_constant_override("margin_top", 20)
	center.add_theme_constant_override("margin_bottom", 20)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var heading := Label.new()
	heading.text = "ADMINISTRAR SERVIDORES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	content.add_child(heading)

	var intro := Label.new()
	intro.text = "Crea y administra un servidor local para jugar en tu red. Para conexiones por Internet necesitarás alojamiento público y configurar el acceso de red."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", Color("#D8C6A5"))
	content.add_child(intro)

	var section_title := Label.new()
	section_title.text = "PERFILES GUARDADOS"
	section_title.add_theme_font_size_override("font_size", 14)
	content.add_child(section_title)

	_list = ItemList.new()
	_list.custom_minimum_size.y = 76
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_color_override("font_color", Color("#F4E7CF"))
	_list.item_selected.connect(_select_profile)
	content.add_child(_list)

	var form_title := Label.new()
	form_title.text = "CONFIGURACIÓN DEL SERVIDOR"
	form_title.add_theme_font_size_override("font_size", 14)
	content.add_child(form_title)

	_name = _add_line(content, "Nombre del servidor")
	_description = _add_line(content, "Descripción")
	_port = _add_spin(content, "Puerto local", 1024, 65535, 7778)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	_add_button(actions, "Guardar perfil", _save_profile)
	_add_button(actions, "Eliminar", _delete_profile)

	_start_local_button = Button.new()
	_start_local_button.text = "Iniciar servidor LAN"
	_start_local_button.custom_minimum_size.y = 42
	_start_local_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_local_button.pressed.connect(_start_local_server)
	content.add_child(_start_local_button)

	_stop_local_button = Button.new()
	_stop_local_button.text = "Detener servidor"
	_stop_local_button.custom_minimum_size.y = 38
	_stop_local_button.disabled = true
	_stop_local_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stop_local_button.pressed.connect(_stop_local_server)
	content.add_child(_stop_local_button)

	var certificate_actions := HBoxContainer.new()
	certificate_actions.add_theme_constant_override("separation", 8)
	content.add_child(certificate_actions)
	_add_button(certificate_actions, "Exportar certificado", _export_certificate)
	_add_button(certificate_actions, "Importar confianza", _import_certificate)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.crt", "Certificado TLS")
	_file_dialog.file_selected.connect(_save_certificate_copy)
	add_child(_file_dialog)

	_status = Label.new()
	_status.custom_minimum_size.y = 42
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "El certificado se genera automáticamente al iniciar el servidor."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("#D8C6A5"))
	content.add_child(_status)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(footer)
	var back_button := Button.new()
	back_button.text = "Volver"
	back_button.custom_minimum_size = Vector2(132, 40)
	back_button.pressed.connect(_close_manager)
	footer.add_child(back_button)

	PIXEL_UI_THEME.apply(self)


func _close_manager() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_manager()
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
