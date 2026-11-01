extends Control
## Editor local de perfiles para servidores comunitarios.
## No publica ni despliega infraestructura: genera configuración y un lanzador.

const PROFILES_PATH := "user://garlia_community_servers.json"
var _profiles: Array[Dictionary] = []
var _list: ItemList
var _name: LineEdit
var _description: LineEdit
var _port: SpinBox
var _players: SpinBox
var _visibility: OptionButton
var _status: Label


func _ready() -> void:
	_build_ui()
	_load_profiles()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -310)
	panel.size = Vector2(520, 620)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var title := Label.new()
	title.text = "ADMINISTRAR SERVIDORES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_list = ItemList.new()
	_list.custom_minimum_size.y = 110
	_list.item_selected.connect(_select_profile)
	content.add_child(_list)
	_name = _add_line(content, "Nombre del servidor")
	_description = _add_line(content, "Descripción")
	_port = _add_spin(content, "Puerto", 1024, 65535, 7778)
	var capacity_note := Label.new()
	capacity_note.text = "Capacidad actual del motor: máximo 8 jugadores"
	content.add_child(capacity_note)
	var visibility_label := Label.new()
	visibility_label.text = "Visibilidad"
	content.add_child(visibility_label)
	_visibility = OptionButton.new()
	_visibility.add_item("Privado (solo con dirección)")
	_visibility.add_item("Público (requiere directorio central)")
	content.add_child(_visibility)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	_add_button(actions, "Guardar perfil", _save_profile)
	_add_button(actions, "Eliminar", _delete_profile)
	_add_button(actions, "Exportar lanzador", _export_launcher)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Los perfiles se guardan en este dispositivo."
	content.add_child(_status)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(close_row)
	_add_button(close_row, "Cerrar", queue_free)


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
	_visibility.select(int(profile.get("visibility", 0)))


func _save_profile() -> void:
	var server_name := _name.text.strip_edges()
	if server_name.is_empty():
		_status.text = "Escribe un nombre para el servidor."
		return
	var profile := {
		"name": server_name,
		"description": _description.text.strip_edges(),
		"port": int(_port.value),
		"max_players": 8,
		"visibility": _visibility.selected,
		"world_data": "user://garlia_servers/%s/world.json" % _slug(server_name)
	}
	var selected := _list.get_selected_items()
	if selected.size() > 0 and selected[0] < _profiles.size():
		_profiles[selected[0]] = profile
	else:
		_profiles.append(profile)
	if not _write_profiles():
		return
	_load_profiles()
	_status.text = "Perfil guardado. Mundo independiente: " + str(profile["world_data"])


func _delete_profile() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		_status.text = "Selecciona un perfil."
		return
	_profiles.remove_at(selected[0])
	if _write_profiles():
		_load_profiles()
		_status.text = "Perfil eliminado. Los archivos de mundo no se borraron."


func _export_launcher() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		_status.text = "Guarda y selecciona un perfil primero."
		return
	var profile: Dictionary = _profiles[selected[0]]
	var slug := _slug(str(profile.get("name", "servidor")))
	var directory := "user://garlia_servers/%s" % slug
	var absolute_dir := ProjectSettings.globalize_path(directory)
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK and error != ERR_ALREADY_EXISTS:
		_status.text = "No se pudo crear la carpeta del servidor."
		return
	var world_path := "/var/lib/garlia/%s/world.json" % slug
	var port := int(profile.get("port", 7778))
	var launcher := "#!/usr/bin/env bash\nset -euo pipefail\n\n# Garlia — %s\n# Copia tu certificado y clave TLS al VPS y ajusta estas rutas.\nGODOT_BIN=godot\nPROJECT_DIR=\"$(pwd)\"\nTLS_CERT=/etc/letsencrypt/live/tu-dominio/fullchain.pem\nTLS_KEY=/etc/letsencrypt/live/tu-dominio/privkey.pem\n\nexec \"$GODOT_BIN\" --headless --path \"$PROJECT_DIR\" -- --garlia-server --port=%d --tls-cert=\"$TLS_CERT\" --tls-key=\"$TLS_KEY\" --world-data=%s\n" % [str(profile.get("name", "Servidor")), port, world_path]
	var launcher_path := absolute_dir.path_join("start_server.sh")
	var file := FileAccess.open(launcher_path, FileAccess.WRITE)
	if file == null:
		_status.text = "No se pudo exportar el lanzador."
		return
	file.store_string(launcher)
	file.close()
	var config_path := absolute_dir.path_join("server.json")
	var config := FileAccess.open(config_path, FileAccess.WRITE)
	if config != null:
		config.store_string(JSON.stringify(profile, "\t"))
		config.close()
	_status.text = "Lanzador exportado: " + launcher_path + ". Público aún no se anuncia en un directorio; requiere Godot, TLS y puerto TCP accesible."


func _slug(value: String) -> String:
	var result := value.to_lower()
	for character in [" ", "/", "\\", ":", "*", "?", "\"",
		"<", ">", "|", "."]:
		result = result.replace(character, "_")
	while "__" in result:
		result = result.replace("__", "_")
	return result.strip_edges()
