extends RefCounted
class_name PixelUITheme

# Texturas opcionales: si todavía no existen, Godot conserva los estilos actuales.
const UI_DIR := "res://assets/art/UI/Menus/"
const PANEL_BACKGROUND_MARGIN := 8
const PIXEL_TITLE_FONT: Font = preload("res://assets/fonts/Pixelgrafia.ttf")


static func apply(root: Control, use_pixel_titles: bool = true) -> void:
	if root == null:
		return
	_apply_control(root, use_pixel_titles)
	for node in root.find_children("*", "Control", true, false):
		_apply_control(node as Control, use_pixel_titles)


static func _texture_style(file_name: String, margins: int = 8) -> StyleBoxTexture:
	var path := UI_DIR + file_name
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("PixelUITheme: no se pudo cargar " + path)
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins
	style.texture_margin_top = margins
	style.texture_margin_right = margins
	style.texture_margin_bottom = margins
	style.draw_center = true
	return style


static func slot_style(selected: bool = false) -> StyleBoxTexture:
	return _texture_style("slot_selected.png" if selected else "slot_frame.png", 5)


static func _apply_control(control: Control, use_pixel_titles: bool = true) -> void:
	if control is Panel or control is PanelContainer:
		# Un único recurso dibuja tanto el fondo como el borde del panel.
		var panel := _texture_style("panel_background.png", PANEL_BACKGROUND_MARGIN)
		if panel != null:
			control.add_theme_stylebox_override("panel", panel)

	# Pixelgrafia queda reservada para encabezados; el resto usa la fuente Open Sans integrada en Godot.
	var control_name := control.name.to_lower()
	var is_title := control_name == "title" or control_name.ends_with("_title") or control_name.begins_with("title_") or control_name == "heading" or control_name.ends_with("_heading")
	if use_pixel_titles and is_title and (control is Label or control is RichTextLabel):
		control.add_theme_font_override("font", PIXEL_TITLE_FONT)

	# Unificar el contorno de los textos con el acabado que ya usa Admin.
	# El borde oscuro mejora el contraste sin cambiar la tipografía ni los sprites.
	if control is Label or control is RichTextLabel or control is CheckBox or control is OptionButton or control is LineEdit or control is TextEdit:
		control.add_theme_color_override("font_outline_color", Color("#302014"))
		control.add_theme_constant_override("outline_size", 2)

	var is_slot_button := control is Button and (
		control.name == "InventorySlot"
		or control.name == "EquipmentSlot"
		or control.name.ends_with("HandSlot")
		or control.name.begins_with("Slot")
	)
	if is_slot_button:
		var slot := slot_style(false)
		var selected_slot := slot_style(true)
		if slot != null:
			control.add_theme_stylebox_override("normal", slot)
			control.add_theme_stylebox_override("hover", selected_slot if selected_slot != null else slot)
			control.add_theme_stylebox_override("pressed", selected_slot if selected_slot != null else slot)

	elif control is Button:
		# Texto claro con contorno oscuro para mantener la legibilidad
		# sobre los fondos de los botones en todos sus estados.
		control.add_theme_color_override("font_color", Color("#FFF3D6"))
		control.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
		control.add_theme_color_override("font_pressed_color", Color("#F2DDB8"))
		control.add_theme_color_override("font_disabled_color", Color("#D0C3A8"))
		control.add_theme_color_override("font_outline_color", Color("#302014"))
		control.add_theme_constant_override("outline_size", 2)
		var normal := _texture_style("button_normal.png", 5)
		var hover := _texture_style("button_hover.png", 5)
		var pressed := _texture_style("button_pressed.png", 5)
		var disabled := _texture_style("button_disabled.png", 5)
		if normal != null:
			control.add_theme_stylebox_override("normal", normal)
			control.add_theme_stylebox_override("hover", hover if hover != null else normal)
			control.add_theme_stylebox_override("pressed", pressed if pressed != null else normal)
			control.add_theme_stylebox_override("disabled", disabled if disabled != null else normal)

	if control is LineEdit:
		var input_style := _texture_style("input_frame.png", 4)
		if input_style != null:
			control.add_theme_stylebox_override("normal", input_style)
			control.add_theme_stylebox_override("focus", input_style)

	if control is ItemList:
		var list_style := _texture_style("input_frame.png", 4)
		if list_style != null:
			control.add_theme_stylebox_override("panel", list_style)

	if control is HSeparator or control is VSeparator:
		var separator_style := _texture_style("panel_separator.png", 3)
		if separator_style != null:
			control.add_theme_stylebox_override("separator", separator_style)

	if control is ProgressBar:
		var bar_background := _texture_style("bar_frame.png", 3)
		var fill_name := "bar_fill_health.png"
		match control.name:
			"HealthBar":
				fill_name = "bar_fill_health.png"
			"EteriumBar":
				fill_name = "bar_fill_eterium.png"
			"StaminaBar":
				fill_name = "bar_fill_stamina.png"
		var bar_fill := _texture_style(fill_name, 2)
		if bar_background != null:
			control.add_theme_stylebox_override("background", bar_background)
		if bar_fill != null:
			control.add_theme_stylebox_override("fill", bar_fill)
