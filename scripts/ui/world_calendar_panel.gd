extends CanvasLayer
class_name WorldCalendarPanel

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

var _atmosfera: Node = null
var _panel: PanelContainer
var _info: Label
var _grid: GridContainer
var _ancho_celda: float = 36.0


func abrir(atmosfera: Node) -> void:
	_atmosfera = atmosfera
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	if _atmosfera.has_signal("dia_cambiado"):
		_atmosfera.connect("dia_cambiado", _al_cambiar_dia)
	if _atmosfera.has_signal("estacion_cambiada"):
		_atmosfera.connect("estacion_cambiada", _al_cambiar_estacion)
	_crear_interfaz()
	_actualizar_calendario()


func _crear_interfaz() -> void:
	var raiz := Control.new()
	raiz.name = "CalendarRoot"
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)

	var centrador := CenterContainer.new()
	centrador.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centrador.mouse_filter = Control.MOUSE_FILTER_PASS
	raiz.add_child(centrador)

	_panel = PanelContainer.new()
	_panel.name = "CalendarPanel"
	var viewport_size := get_viewport().get_visible_rect().size
	var ancho_panel := minf(332.0, maxf(220.0, viewport_size.x - 24.0))
	_panel.custom_minimum_size = Vector2(ancho_panel, minf(292.0, maxf(180.0, viewport_size.y - 24.0)))
	_ancho_celda = clampf((ancho_panel - 56.0) / 7.0, 24.0, 36.0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centrador.add_child(_panel)

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 8)
	_panel.add_child(contenido)

	var encabezado := HBoxContainer.new()
	contenido.add_child(encabezado)
	var titulo := Label.new()
	titulo.name = "CalendarTitle"
	titulo.text = "CALENDARIO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_child(titulo)

	var cerrar := Button.new()
	cerrar.text = "X"
	cerrar.custom_minimum_size = Vector2(34.0, 30.0)
	PIXEL_UI_THEME.apply(cerrar)
	cerrar.pressed.connect(queue_free)
	encabezado.add_child(cerrar)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(_info)

	var separador := HSeparator.new()
	contenido.add_child(separador)

	var etiqueta_dias := Label.new()
	etiqueta_dias.text = "DÍAS DE LA ESTACIÓN"
	etiqueta_dias.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(etiqueta_dias)

	var desplazamiento := ScrollContainer.new()
	desplazamiento.custom_minimum_size = Vector2(maxf(180.0, ancho_panel - 40.0), maxf(80.0, minf(176.0, viewport_size.y - 140.0)))
	desplazamiento.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazamiento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenido.add_child(desplazamiento)

	_grid = GridContainer.new()
	_grid.name = "DaysGrid"
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	desplazamiento.add_child(_grid)
	PIXEL_UI_THEME.apply(raiz)


func _actualizar_calendario() -> void:
	if not is_instance_valid(_grid) or not is_instance_valid(_info):
		return
	for hijo in _grid.get_children():
		hijo.queue_free()
	if not is_instance_valid(_atmosfera) or not _atmosfera.has_method("obtener_tiempo"):
		_info.text = "El calendario no está disponible."
		return

	var tiempo: Dictionary = _atmosfera.call("obtener_tiempo")
	if not bool(tiempo.get("calendario_cargado", false)):
		_info.text = "Cargando calendario…"
		return

	var duracion := maxi(int(tiempo.get("duracion_estacion_dias", 0)), 1)
	var dia_actual := clampi(int(tiempo.get("dia_de_estacion", 1)), 1, duracion)
	var estacion := str(tiempo.get("estacion", "Estación"))
	var estacion_actual_variant: Variant = _atmosfera.get("estacion_actual")
	var estacion_actual: Dictionary = estacion_actual_variant if estacion_actual_variant is Dictionary else {}
	var temporada := str(estacion_actual.get("temporada", estacion_actual.get("nombre_temporada", ""))).strip_edges()
	var anio := int(tiempo.get("anio", 0))
	var restante := maxi(0, duracion - dia_actual)
	var siguiente := _obtener_siguiente_estacion(str(tiempo.get("estacion_id", "")))

	var encabezado := estacion
	if not temporada.is_empty() and temporada.to_lower() != estacion.to_lower():
		encabezado = temporada + " · " + estacion
	_info.text = "%s\nDía %d de %d  ·  Quedan %d días\nAño %d  ·  Siguiente: %s" % [
		encabezado, dia_actual, duracion, restante, anio, siguiente
	]

	for dia in range(1, duracion + 1):
		var celda := PanelContainer.new()
		celda.custom_minimum_size = Vector2(_ancho_celda, 30.0)
		if dia == dia_actual:
			var resaltado := StyleBoxFlat.new()
			resaltado.bg_color = Color("#9b5939")
			resaltado.border_color = Color("#e7c99b")
			resaltado.set_border_width_all(2)
			celda.add_theme_stylebox_override("panel", resaltado)
		else:
			var normal := StyleBoxFlat.new()
			normal.bg_color = Color("#493326")
			normal.border_color = Color("#76503a")
			normal.set_border_width_all(1)
			celda.add_theme_stylebox_override("panel", normal)
		var numero := Label.new()
		numero.text = str(dia)
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		celda.add_child(numero)
		PIXEL_UI_THEME.apply(numero, false)
		_grid.add_child(celda)


func _al_cambiar_dia(_dia: int, _anio: int) -> void:
	_actualizar_calendario()


func _al_cambiar_estacion(_estacion: Dictionary) -> void:
	_actualizar_calendario()


func _obtener_siguiente_estacion(id_actual: String) -> String:
	if not is_instance_valid(_atmosfera):
		return "—"
	var estaciones_variant: Variant = _atmosfera.get("estaciones")
	if not estaciones_variant is Array:
		return "—"
	var estaciones: Array = (estaciones_variant as Array).duplicate(true)
	estaciones.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			if not a is Dictionary:
				return false
			if not b is Dictionary:
				return true
			return int((a as Dictionary).get("orden", 0)) < int((b as Dictionary).get("orden", 0))
	)
	for indice in range(estaciones.size()):
		if not estaciones[indice] is Dictionary:
			continue
		if str((estaciones[indice] as Dictionary).get("id", "")) != id_actual:
			continue
		var siguiente: Dictionary = estaciones[(indice + 1) % estaciones.size()]
		return str(siguiente.get("nombre", "—"))
	return "—"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
			queue_free()
			get_viewport().set_input_as_handled()
