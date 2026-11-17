extends CanvasLayer
class_name WorldCalendarPanel

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

var _atmosfera: Node = null
var _mueble_origen: Node = null
var _panel: PanelContainer
var _grid: GridContainer
var _boton_estacion: Button
var _estaciones: Array = []
var _indice_estacion_vista: int = 0
var _ancho_celda: float = 48.0
var _dia_actual: int = 1
var _estacion_actual_id: String = ""


func abrir(atmosfera: Node, mueble_origen: Node = null) -> void:
	_atmosfera = atmosfera
	_mueble_origen = mueble_origen
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(is_instance_valid(_mueble_origen))
	add_to_group("modal_ui")
	if _atmosfera.has_signal("dia_cambiado"):
		_atmosfera.connect("dia_cambiado", _al_cambiar_dia)
	if _atmosfera.has_signal("estacion_cambiada"):
		_atmosfera.connect("estacion_cambiada", _al_cambiar_estacion)
	_cargar_estaciones()
	_seleccionar_estacion_actual()
	_crear_interfaz()
	_actualizar_calendario()


func _process(_delta: float) -> void:
	if not is_instance_valid(_mueble_origen) or not _mueble_origen.is_visible_in_tree():
		queue_free()


func _cargar_estaciones() -> void:
	_estaciones.clear()
	if not is_instance_valid(_atmosfera):
		return
	var estaciones_variant: Variant = _atmosfera.get("estaciones")
	if not estaciones_variant is Array:
		return
	_estaciones = (estaciones_variant as Array).duplicate(true)
	_estaciones.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			if not a is Dictionary:
				return false
			if not b is Dictionary:
				return true
			return int((a as Dictionary).get("orden", 0)) < int((b as Dictionary).get("orden", 0))
	)


func _seleccionar_estacion_actual() -> void:
	if not is_instance_valid(_atmosfera):
		return
	var actual_variant: Variant = _atmosfera.get("estacion_actual")
	if not actual_variant is Dictionary:
		return
	_estacion_actual_id = str((actual_variant as Dictionary).get("id", ""))
	for indice in range(_estaciones.size()):
		if not _estaciones[indice] is Dictionary:
			continue
		if str((_estaciones[indice] as Dictionary).get("id", "")) == _estacion_actual_id:
			_indice_estacion_vista = indice
			_dia_actual = maxi(1, int((actual_variant as Dictionary).get("dia_de_estacion", 1)))
			return


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
	_ancho_celda = clampf((ancho_panel - 64.0) / 5.0, 30.0, 48.0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centrador.add_child(_panel)

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 8)
	_panel.add_child(contenido)

	var encabezado := HBoxContainer.new()
	encabezado.add_theme_constant_override("separation", 5)
	contenido.add_child(encabezado)

	var anterior := Button.new()
	anterior.name = "PreviousSeason"
	anterior.text = "‹"
	anterior.custom_minimum_size = Vector2(30.0, 30.0)
	PIXEL_UI_THEME.apply(anterior, false)
	anterior.pressed.connect(_cambiar_estacion_vista.bind(-1))
	encabezado.add_child(anterior)

	_boton_estacion = Button.new()
	_boton_estacion.name = "CalendarSeason"
	_boton_estacion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_estacion.custom_minimum_size = Vector2(0.0, 30.0)
	_boton_estacion.focus_mode = Control.FOCUS_NONE
	PIXEL_UI_THEME.apply(_boton_estacion, false)
	encabezado.add_child(_boton_estacion)

	var siguiente := Button.new()
	siguiente.name = "NextSeason"
	siguiente.text = "›"
	siguiente.custom_minimum_size = Vector2(30.0, 30.0)
	PIXEL_UI_THEME.apply(siguiente, false)
	siguiente.pressed.connect(_cambiar_estacion_vista.bind(1))
	encabezado.add_child(siguiente)

	var cerrar := Button.new()
	cerrar.name = "CloseCalendar"
	cerrar.text = "X"
	cerrar.custom_minimum_size = Vector2(30.0, 30.0)
	PIXEL_UI_THEME.apply(cerrar, false)
	cerrar.pressed.connect(queue_free)
	encabezado.add_child(cerrar)

	var desplazamiento := ScrollContainer.new()
	desplazamiento.name = "DaysScroll"
	desplazamiento.custom_minimum_size = Vector2(maxf(180.0, ancho_panel - 40.0), maxf(80.0, minf(176.0, viewport_size.y - 140.0)))
	desplazamiento.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazamiento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenido.add_child(desplazamiento)

	_grid = GridContainer.new()
	_grid.name = "DaysGrid"
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	desplazamiento.add_child(_grid)
	PIXEL_UI_THEME.apply(raiz)


func _cambiar_estacion_vista(direccion: int) -> void:
	if _estaciones.is_empty():
		return
	_indice_estacion_vista = posmod(_indice_estacion_vista + direccion, _estaciones.size())
	_actualizar_calendario()


func _actualizar_calendario() -> void:
	if not is_instance_valid(_grid) or not is_instance_valid(_boton_estacion):
		return
	for hijo in _grid.get_children():
		_grid.remove_child(hijo)
		hijo.queue_free()

	if not is_instance_valid(_atmosfera) or _estaciones.is_empty():
		_boton_estacion.text = "Calendario no disponible"
		return

	if not _atmosfera.has_method("obtener_tiempo"):
		_boton_estacion.text = "Calendario no disponible"
		return
	var tiempo: Dictionary = _atmosfera.call("obtener_tiempo")
	if not bool(tiempo.get("calendario_cargado", false)):
		_boton_estacion.text = "Cargando calendario…"
		return

	_indice_estacion_vista = clampi(_indice_estacion_vista, 0, _estaciones.size() - 1)
	var estacion_variant: Variant = _estaciones[_indice_estacion_vista]
	if not estacion_variant is Dictionary:
		_boton_estacion.text = "Estación"
		return
	var estacion := estacion_variant as Dictionary
	var nombre_estacion := str(estacion.get("nombre", "Estación"))
	_boton_estacion.text = nombre_estacion

	var duracion := maxi(int(estacion.get("duracion_dias", 0)), 1)
	var es_estacion_actual := str(estacion.get("id", "")) == str(tiempo.get("estacion_id", ""))
	var dia_resaltado := int(tiempo.get("dia_de_estacion", 1)) if es_estacion_actual else -1

	for dia in range(1, duracion + 1):
		var numero := Button.new()
		numero.name = "Day%02d" % dia
		numero.text = str(dia)
		numero.custom_minimum_size = Vector2(_ancho_celda, 32.0)
		numero.focus_mode = Control.FOCUS_NONE
		PIXEL_UI_THEME.apply(numero, false)
		if dia == dia_resaltado:
			var estilo_seleccionado := PIXEL_UI_THEME.button_pressed_style()
			if estilo_seleccionado != null:
				numero.add_theme_stylebox_override("normal", estilo_seleccionado)
				numero.add_theme_stylebox_override("hover", estilo_seleccionado)
				numero.add_theme_stylebox_override("pressed", estilo_seleccionado)
		_grid.add_child(numero)


func _al_cambiar_dia(_dia: int, _anio: int) -> void:
	if not is_instance_valid(_atmosfera):
		return
	var tiempo: Dictionary = _atmosfera.call("obtener_tiempo")
	_estacion_actual_id = str(tiempo.get("estacion_id", ""))
	_dia_actual = int(tiempo.get("dia_de_estacion", 1))
	_actualizar_calendario()


func _al_cambiar_estacion(_estacion: Dictionary) -> void:
	_seleccionar_estacion_actual()
	_actualizar_calendario()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
			queue_free()
			get_viewport().set_input_as_handled()
