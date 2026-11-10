extends RefCounted
class_name PixelUITheme

# Texturas opcionales: si todavía no existen, Godot conserva los estilos actuales.
const UI_DIR := "res://assets/art/UI/Menus/"
const PANEL_INSET := 2


static func apply(root: Control) -> void:
	if root == null:
		return
	_apply_control(root)
	for node in root.find_children("*", "Control", true, false):
		_apply_control(node as Control)


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


static func _ensure_panel_background(control: Control) -> void:
	# Configuración ya incorpora esta capa manualmente. Reutilizarla evita
	# duplicar el relleno cuando el tema global se aplica a ese panel.
	var existing := control.get_node_or_null("PanelBackground")
	if existing is TextureRect:
		return

	var path := UI_DIR + "panel_background.png"
	if not ResourceLoader.exists(path):
		return
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("PixelUITheme: no se pudo cargar " + path)
		return

	var background := TextureRect.new()
	background.name = "PanelBackground"
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.offset_left = PANEL_INSET
	background.offset_top = PANEL_INSET
	background.offset_right = -PANEL_INSET
	background.offset_bottom = -PANEL_INSET
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Se dibuja detrás del Panel: el centro transparente del marco deja
	# visible el relleno y el contenido continúa dibujándose por encima.
	background.show_behind_parent = true
	control.add_child(background)


static func slot_style(selected: bool = false) -> StyleBoxTexture:
	return _texture_style("slot_selected.png" if selected else "slot_frame.png", 5)


static func _apply_control(control: Control) -> void:
	if control is Panel or control is PanelContainer:
		_ensure_panel_background(control)
		var panel := _texture_style("panel_frame.png", PANEL_INSET)
		if panel != null:
			control.add_theme_stylebox_override("panel", panel)

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
