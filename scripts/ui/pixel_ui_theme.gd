extends RefCounted
class_name PixelUITheme

# Texturas opcionales: si todavía no existen, Godot conserva los estilos actuales.
const UI_DIR := "res://assets/art/UI/"

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

static func _apply_control(control: Control) -> void:
	if control is Panel or control is PanelContainer:
		var panel := _texture_style("panel_frame.png", 8)
		if panel != null:
			control.add_theme_stylebox_override("panel", panel)

	if control is Button:
		var normal := _texture_style("button_normal.png", 5)
		var hover := _texture_style("button_hover.png", 5)
		var pressed := _texture_style("button_pressed.png", 5)
		var disabled := _texture_style("button_disabled.png", 5)
		if normal != null:
			control.add_theme_stylebox_override("normal", normal)
		if hover != null:
			control.add_theme_stylebox_override("hover", hover if hover != null else normal)
		if pressed != null:
			control.add_theme_stylebox_override("pressed", pressed)
		if disabled != null:
			control.add_theme_stylebox_override("disabled", disabled)

	if control is LineEdit:
		var input_style := _texture_style("input_frame.png", 4)
		if input_style != null:
			control.add_theme_stylebox_override("normal", input_style)
			control.add_theme_stylebox_override("focus", input_style)

	if control is ProgressBar:
		var bar_background := _texture_style("bar_frame.png", 3)
		var bar_fill := _texture_style("bar_fill.png", 2)
		if bar_background != null:
			control.add_theme_stylebox_override("background", bar_background)
		if bar_fill != null:
			control.add_theme_stylebox_override("fill", bar_fill)
