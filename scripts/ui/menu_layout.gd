extends RefCounted
class_name MenuLayout

# Base reutilizable para las interfaces del juego.
# Mantiene los paneles dentro del viewport y estandariza selectores con sprites.

const MARGEN_PANTALLA: float = 14.0
const TAMANO_ICONO_SELECTOR: Vector2 = Vector2(48.0, 48.0)


static func vigilar_panel_centrado(panel: Control, margen: float = MARGEN_PANTALLA) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return
	if not panel.has_meta("menu_base_scale"):
		panel.set_meta("menu_base_scale", panel.scale)
	var viewport := panel.get_viewport()
	var callback := Callable(MenuLayout, "_al_redimensionar_viewport").bind(weakref(panel), margen)
	if not viewport.size_changed.is_connected(callback):
		viewport.size_changed.connect(callback)
	_ajustar_panel_centrado(weakref(panel), margen)


static func _al_redimensionar_viewport(referencia: WeakRef, margen: float) -> void:
	_ajustar_panel_centrado(referencia, margen)


static func _ajustar_panel_centrado(referencia: WeakRef, margen: float) -> void:
	var panel := referencia.get_ref() as Control
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return
	var viewport_size := panel.get_viewport_rect().size
	var panel_size := panel.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return
	var escala_base: Vector2 = panel.get_meta("menu_base_scale", Vector2.ONE)
	var ancho_disponible := maxf(1.0, viewport_size.x - margen * 2.0)
	var alto_disponible := maxf(1.0, viewport_size.y - margen * 2.0)
	var escala_ajuste := minf(
		1.0,
		ancho_disponible / maxf(1.0, panel_size.x * escala_base.x),
		alto_disponible / maxf(1.0, panel_size.y * escala_base.y)
	)
	panel.pivot_offset = panel_size * 0.5
	panel.scale = escala_base * escala_ajuste


static func crear_selector_dos_paneles(
	padre: Control,
	ancho_lista: float = 164.0,
	alto_minimo: float = 220.0,
	separacion: int = 8
) -> Dictionary:
	var distribucion := HBoxContainer.new()
	distribucion.add_theme_constant_override("separation", separacion)
	distribucion.custom_minimum_size = Vector2(0.0, alto_minimo)
	distribucion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distribucion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	padre.add_child(distribucion)

	var panel_lista := PanelContainer.new()
	panel_lista.custom_minimum_size = Vector2(ancho_lista, 0.0)
	panel_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	distribucion.add_child(panel_lista)
	PixelUITheme.apply(panel_lista, false)

	var scroll_lista := ScrollContainer.new()
	scroll_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_lista.add_child(scroll_lista)

	var contenido_lista := GridContainer.new()
	contenido_lista.columns = 3
	contenido_lista.add_theme_constant_override("h_separation", 4)
	contenido_lista.add_theme_constant_override("v_separation", 4)
	contenido_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_lista.add_child(contenido_lista)

	var panel_detalle := PanelContainer.new()
	panel_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	distribucion.add_child(panel_detalle)
	PixelUITheme.apply(panel_detalle, false)

	var scroll_detalle := ScrollContainer.new()
	scroll_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_detalle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_detalle.add_child(scroll_detalle)

	var contenido_detalle := VBoxContainer.new()
	contenido_detalle.add_theme_constant_override("separation", 6)
	contenido_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_detalle.add_child(contenido_detalle)

	return {
		"container": distribucion,
		"list_panel": panel_lista,
		"list_scroll": scroll_lista,
		"list_content": contenido_lista,
		"detail_panel": panel_detalle,
		"detail_scroll": scroll_detalle,
		"detail_content": contenido_detalle
	}


static func crear_boton_sprite(
	textura: Texture2D,
	seleccionado: bool = false,
	tamano: Vector2 = TAMANO_ICONO_SELECTOR
) -> Button:
	var boton := Button.new()
	boton.text = ""
	boton.custom_minimum_size = tamano
	boton.icon = textura
	boton.expand_icon = true
	boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boton.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	boton.toggle_mode = true
	boton.button_pressed = seleccionado
	boton.disabled = textura == null
	boton.focus_mode = Control.FOCUS_ALL
	PixelUITheme.apply(boton, false)
	return boton


static func agregar_cantidad(boton: Button, cantidad: int) -> void:
	var etiqueta := Label.new()
	etiqueta.text = str(cantidad)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.add_theme_color_override("font_color", Color("#FFF3D6"))
	etiqueta.add_theme_color_override("font_outline_color", Color("#302014"))
	etiqueta.add_theme_constant_override("outline_size", 3)
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	etiqueta.offset_left = 3.0
	etiqueta.offset_top = 2.0
	etiqueta.offset_right = -5.0
	etiqueta.offset_bottom = -3.0
	boton.add_child(etiqueta)


static func aplicar_scroll(scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll):
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
