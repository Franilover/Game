extends RefCounted
class_name PixelUITheme

# Texturas opcionales: si todavía no existen, Godot conserva los estilos actuales.
const UI_DIR := "res://assets/art/UI/Menus/"
const SHARED_ASSET_LIBRARY: Script = preload("res://scripts/shared/assets/shared_asset_library.gd")
static var _style_cache: Dictionary = {}
static var _focus_style: StyleBoxEmpty = null
static var _button_fallback: StyleBoxFlat = null
const PIXEL_TITLE_FONT: Font = preload("res://assets/fonts/Pixelgrafia.ttf")


static func apply(root: Control, use_pixel_titles: bool = true, force: bool = false) -> void:
	if not is_instance_valid(root):
		return
	_apply_control(root, use_pixel_titles, force)
	_vigilar_panel_menu(root)
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		_apply_control(control, use_pixel_titles, force)
		_vigilar_panel_menu(control)


static func _obtener_estilo_foco() -> StyleBoxEmpty:
	if _focus_style == null:
		_focus_style = StyleBoxEmpty.new()
	return _focus_style


static func focus_style() -> StyleBoxEmpty:
	return _obtener_estilo_foco()


static func button_fallback_style() -> StyleBoxFlat:
	if _button_fallback == null:
		_button_fallback = StyleBoxFlat.new()
		_button_fallback.bg_color = Color("#302014")
		_button_fallback.border_color = Color("#9B7950")
		_button_fallback.set_border_width_all(2)
	return _button_fallback


static func _texture_style(file_name: String, margins: int = 8) -> StyleBoxTexture:
	var clave := "%s:%d" % [file_name, margins]
	var cache: Variant = _style_cache.get(clave)
	if cache is StyleBoxTexture and is_instance_valid(cache):
		return cache as StyleBoxTexture

	var texture: Texture2D = SHARED_ASSET_LIBRARY.textura(UI_DIR + file_name)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins
	style.texture_margin_top = margins
	style.texture_margin_right = margins
	style.texture_margin_bottom = margins
	style.draw_center = true
	_style_cache[clave] = style
	return style

static func slot_style(selected: bool = false) -> StyleBoxTexture:
	return _texture_style("slot_selected.png" if selected else "slot_frame.png", 5)


static func button_surface_style() -> StyleBoxTexture:
	return _texture_style("button_normal.png", 5)


static func button_hover_style() -> StyleBoxTexture:
	return _texture_style("button_hover.png", 5)


static func button_pressed_style() -> StyleBoxTexture:
	return _texture_style("button_pressed.png", 5)


static func button_disabled_style() -> StyleBoxTexture:
	return _texture_style("button_disabled.png", 5)


static func _apply_control(control: Control, use_pixel_titles: bool = true, force: bool = false) -> void:
	if not force and control.has_meta("pixel_ui_theme_applied") and bool(control.get_meta("pixel_ui_theme_applied")) == use_pixel_titles:
		return
	# El juego no usa tooltips emergentes: la información vive en sus paneles y etiquetas.
	control.tooltip_text = ""
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

	# El foco de teclado no debe dibujar el contorno blanco predeterminado de Godot.
	# Los estados normal, hover y pressed ya tienen el diseño visual propio del juego.
	if control is BaseButton:
		control.add_theme_stylebox_override("focus", _obtener_estilo_foco())
		var is_slot_button := control is Button and control.name.ends_with("HandSlot")
		if is_slot_button:
			var slot := slot_style(false)
			var selected_slot := slot_style(true)
			if slot != null:
				control.add_theme_stylebox_override("normal", slot)
				control.add_theme_stylebox_override("hover", selected_slot if selected_slot != null else slot)
				control.add_theme_stylebox_override("pressed", selected_slot if selected_slot != null else slot)
		else:
			var normal: StyleBox = button_surface_style()
			var hover: StyleBox = button_hover_style()
			var pressed: StyleBox = button_pressed_style()
			var disabled: StyleBox = button_disabled_style()
			if normal == null:
				normal = button_fallback_style()
			if hover == null:
				hover = normal
			if pressed == null:
				pressed = normal
			if disabled == null:
				disabled = normal
			control.add_theme_stylebox_override("normal", normal)
			control.add_theme_stylebox_override("hover", hover)
			control.add_theme_stylebox_override("pressed", pressed)
			control.add_theme_stylebox_override("disabled", disabled)

	if control is Button:
		# Texto claro con contorno oscuro para mantener la legibilidad.
		control.add_theme_color_override("font_color", Color("#FFF3D6"))
		control.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
		control.add_theme_color_override("font_pressed_color", Color("#F2DDB8"))
		control.add_theme_color_override("font_disabled_color", Color("#D0C3A8"))
		control.add_theme_color_override("font_outline_color", Color("#302014"))
		control.add_theme_constant_override("outline_size", 2)

	if control is Panel or control is PanelContainer:
		var panel_background := _texture_style("background.png", 0)
		if panel_background != null:
			control.add_theme_stylebox_override("panel", panel_background)

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

	control.set_meta("pixel_ui_theme_applied", use_pixel_titles)


static func _vigilar_panel_menu(control: Control) -> void:
	if not (control is PanelContainer or control is Panel) or control.has_meta("pixel_ui_menu_layout_watched"):
		return
	var anclado_al_centro := is_equal_approx(control.anchor_left, 0.5) and is_equal_approx(control.anchor_right, 0.5) and is_equal_approx(control.anchor_top, 0.5) and is_equal_approx(control.anchor_bottom, 0.5)
	var centrado_por_contenedor := control.get_parent() is CenterContainer
	if anclado_al_centro or centrado_por_contenedor:
		MenuLayout.vigilar_panel_centrado(control)
		control.set_meta("pixel_ui_menu_layout_watched", true)
