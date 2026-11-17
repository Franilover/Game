extends Control
class_name GarliaMobileControls

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

## Capa táctil para dispositivos móviles. Reutiliza el InputMap del juego.
## El layout se calcula en píxeles de viewport y se adapta a orientación/tamaño.

@export var solo_dispositivos_moviles: bool = true
@export_range(96, 180, 4) var tamano_joystick: int = 136
@export_range(48, 96, 2) var tamano_accion: int = 68
@export_range(8, 48, 2) var margen_borde: int = 20
@export_range(4, 24, 2) var separacion: int = 10

var _acciones_presionadas: Dictionary = {}
var _botones: Dictionary = {}
var _botones_hud: Dictionary = {}
var _joystick_touch_index: int = -1
var _joystick_vector := Vector2.ZERO
var _joystick_radio: float = 54.0
var _meditar_presionado: bool = false
var _layout_actual: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if solo_dispositivos_moviles and not _es_dispositivo_movil():
		hide()
		return

	_configurar_estilo_joystick()
	_botones = {
		"interact": $Actions/Interact,
		"primary_action": $Actions/Primary,
		"secondary_action": $Actions/Secondary,
		"dash": $Actions/Dash,
		"jump": $Actions/Jump,
		"inventory": $Actions/Inventory,
	}

	_botones_hud = {
		"toggle_map": $Actions/Map,
		"toggle_missions": $Actions/Missions,
		"toggle_garumi_selector": $Actions/Garumis,
		"garumi_slot_1": $Actions/Garumi1,
		"garumi_slot_2": $Actions/Garumi2,
		"garumi_slot_3": $Actions/Garumi3,
	}
	for accion in _botones:
		_configurar_boton(_botones[accion] as BaseButton, str(accion))
		_estilizar_boton(_botones[accion] as Button, str(accion))
	for accion in _botones_hud:
		var boton_hud := _botones_hud[accion] as Button
		boton_hud.pressed.connect(_solicitar_hud.bind(str(accion)))
		_estilizar_boton(boton_hud, str(accion))
	_estilizar_boton($Actions/Meditate, "meditate")
	_estilizar_boton($Actions/Pause, "pause_menu")
	$Actions/Pause.pressed.connect(_alternar_pausa)
	$Actions/Meditate.button_down.connect(_presionar_espacio)
	$Actions/Meditate.button_up.connect(_soltar_espacio)
	get_viewport().size_changed.connect(_distribuir_controles)
	_distribuir_controles()


func _configurar_estilo_joystick() -> void:
	for nodo in [$Movement/JoystickBase, $Movement/JoystickKnob]:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.075, 0.065, 0.055, 0.58) if nodo.name == "JoystickBase" else Color(0.30, 0.25, 0.17, 0.92)
		estilo.border_color = Color(0.72, 0.62, 0.43, 0.85)
		estilo.set_border_width_all(2)
		estilo.set_corner_radius_all(64 if nodo.name == "JoystickBase" else 32)
		nodo.add_theme_stylebox_override("panel", estilo)


func _configurar_boton(boton: BaseButton, accion: String) -> void:
	if boton == null or (not InputMap.has_action(accion) and accion != "inventory"):
		push_warning("Control móvil: no existe la acción InputMap '%s'." % accion)
		return
	boton.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	boton.focus_mode = Control.FOCUS_NONE
	boton.mouse_filter = Control.MOUSE_FILTER_STOP
	if accion == "inventory":
		boton.button_down.connect(func() -> void: _solicitar_inventario())
	else:
		boton.button_down.connect(func() -> void: _presionar_accion(accion))
		boton.button_up.connect(func() -> void: _soltar_accion(accion))


func _estilizar_boton(boton: Button, accion: String) -> void:
	if boton == null:
		return
	var nombres := {
		"interact": "Usar", "primary_action": "Mano I", "secondary_action": "Mano D",
		"dash": "Dash", "jump": "Salto", "inventory": "Bolsa",
		"toggle_map": "Mapa", "toggle_missions": "Misiones", "toggle_garumi_selector": "Garumis",
		"garumi_slot_1": "1", "garumi_slot_2": "2", "garumi_slot_3": "3",
		"meditate": "Meditar", "pause_menu": "Pausa"
	}
	boton.text = str(nombres.get(accion, "•"))
	var texto_largo := accion in ["interact", "primary_action", "secondary_action", "inventory", "toggle_map", "toggle_missions", "toggle_garumi_selector", "meditate", "pause_menu", "dash", "jump"]
	boton.add_theme_font_size_override("font_size", 10 if texto_largo else 18)
	boton.add_theme_color_override("font_color", Color("#FFF3D6"))
	boton.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	boton.add_theme_color_override("font_pressed_color", Color("#F2DDB8"))
	boton.add_theme_color_override("font_disabled_color", Color("#D0C3A8"))
	boton.add_theme_color_override("font_outline_color", Color("#302014"))
	boton.add_theme_constant_override("outline_size", 2)
	var normal: StyleBox = PIXEL_UI_THEME.button_surface_style()
	var hover: StyleBox = PIXEL_UI_THEME.button_hover_style()
	var pressed: StyleBox = PIXEL_UI_THEME.button_pressed_style()
	var disabled: StyleBox = PIXEL_UI_THEME._texture_style("button_disabled.png", 5)
	# Conserva un fallback legible si falta alguna textura opcional.
	if normal == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.075, 0.065, 0.055, 0.82)
		fallback.border_color = Color(0.72, 0.62, 0.43, 0.9)
		fallback.set_border_width_all(2)
		fallback.set_corner_radius_all(12)
		normal = fallback
	if hover == null:
		hover = normal
	if pressed == null:
		var fallback_pressed: StyleBox = normal.duplicate() as StyleBox
		if fallback_pressed is StyleBoxFlat:
			(fallback_pressed as StyleBoxFlat).bg_color = Color("#66543A")
		pressed = fallback_pressed
	boton.add_theme_stylebox_override("normal", normal)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", pressed)
	boton.add_theme_stylebox_override("disabled", disabled if disabled != null else normal)
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	boton.custom_minimum_size = Vector2(tamano_accion, tamano_accion)
	boton.tooltip_text = ""


func _calcular_layout_movil(viewport_size: Vector2) -> Dictionary:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return {}
	var margen := minf(float(margen_borde), minf(viewport_size.x, viewport_size.y) * 0.06)
	var gap := clampf(float(separacion), 6.0, 12.0)
	var joystick_size := minf(float(tamano_joystick), minf(viewport_size.x * 0.32, viewport_size.y * 0.36))
	joystick_size = maxf(64.0, joystick_size)
	var compacto := viewport_size.x < 700.0 or viewport_size.y < 420.0
	var accion := clampf(minf(minf(float(tamano_accion) - (8.0 if compacto else 0.0), viewport_size.x * 0.19), viewport_size.y * 0.17), 42.0, 68.0)
	var pequeno := clampf(accion * 0.72, 34.0, 48.0)
	var right := viewport_size.x - margen
	var bottom := viewport_size.y - margen
	var layout := {}

	var joystick_pos := Vector2(margen, bottom - joystick_size)
	layout["Movement/JoystickBase"] = Rect2(joystick_pos, Vector2.ONE * joystick_size)
	var knob_size := Vector2.ONE * joystick_size * 0.42
	var knob_center := joystick_pos + Vector2.ONE * joystick_size * 0.5
	layout["Movement/JoystickKnob"] = Rect2(knob_center - knob_size * 0.5 + _joystick_vector * joystick_size * 0.30, knob_size)

	# Barra superior: se divide en dos filas cuando los grupos no caben juntos.
	var ancho_utilidades := accion + gap + pequeno * 3.0 + 12.0
	var ancho_garumis := pequeno * 4.0 + gap * 3.0
	var apilar_utilidades := viewport_size.x < ancho_utilidades + ancho_garumis + margen * 2.0 + gap
	layout["Actions/Inventory"] = Rect2(Vector2(margen, margen), Vector2.ONE * accion)
	if apilar_utilidades:
		layout["Actions/Map"] = Rect2(Vector2(margen + accion + gap, margen), Vector2.ONE * pequeno)
		layout["Actions/Missions"] = Rect2(Vector2(margen, margen + pequeno + gap), Vector2.ONE * pequeno)
		layout["Actions/Pause"] = Rect2(Vector2(margen + pequeno + 6.0, margen + pequeno + gap), Vector2.ONE * pequeno)
	else:
		var x := margen + accion + gap
		layout["Actions/Map"] = Rect2(Vector2(x, margen), Vector2.ONE * pequeno)
		x += pequeno + 6.0
		layout["Actions/Missions"] = Rect2(Vector2(x, margen), Vector2.ONE * pequeno)
		x += pequeno + 6.0
		layout["Actions/Pause"] = Rect2(Vector2(x, margen), Vector2.ONE * pequeno)

	var x_garumis := right - ancho_garumis
	layout["Actions/Garumis"] = Rect2(Vector2(x_garumis, margen), Vector2.ONE * pequeno)
	for i in range(3):
		layout["Actions/Garumi%d" % (i + 1)] = Rect2(Vector2(x_garumis + (pequeno + gap) * (i + 1), margen), Vector2.ONE * pequeno)

	# Acciones de juego en una cuadrícula 3x2, sin botones que sobresalgan del borde.
	var ancho_grupo := accion * 3.0 + gap * 2.0
	var x_grupo := right - ancho_grupo
	var y_inferior := bottom - accion
	var y_superior := y_inferior - accion - gap
	layout["Actions/Dash"] = Rect2(Vector2(x_grupo, y_superior), Vector2.ONE * accion)
	layout["Actions/Jump"] = Rect2(Vector2(x_grupo + accion + gap, y_superior), Vector2.ONE * accion)
	layout["Actions/Interact"] = Rect2(Vector2(x_grupo, y_inferior), Vector2.ONE * accion)
	layout["Actions/Secondary"] = Rect2(Vector2(x_grupo + accion + gap, y_inferior), Vector2.ONE * accion)
	layout["Actions/Primary"] = Rect2(Vector2(x_grupo + (accion + gap) * 2.0, y_inferior), Vector2.ONE * accion)

	# Meditar queda encima del joystick, separado de la cuadrícula de combate.
	var y_meditar := maxf(margen, joystick_pos.y - pequeno - gap)
	layout["Actions/Meditate"] = Rect2(Vector2(margen, y_meditar), Vector2.ONE * pequeno)
	return layout


func _distribuir_controles() -> void:
	if not is_inside_tree() or (solo_dispositivos_moviles and not _es_dispositivo_movil()):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	# Los dos contenedores usan coordenadas locales equivalentes al viewport.
	_posicionar($Movement, Vector2.ZERO, viewport_size)
	_posicionar($Actions, Vector2.ZERO, viewport_size)
	_layout_actual = _calcular_layout_movil(viewport_size)
	for ruta in _layout_actual:
		var control := get_node_or_null(NodePath(str(ruta))) as Control
		if not is_instance_valid(control):
			continue
		var rect: Rect2 = _layout_actual[ruta]
		_posicionar(control, rect.position, rect.size)
	_joystick_radio = ($Movement/JoystickBase.size.x * 0.30)
	_actualizar_visual_joystick()


func _input(event: InputEvent) -> void:
	if solo_dispositivos_moviles and not _es_dispositivo_movil():
		return
	if _hay_dialogo_abierto():
		# Un dedo sobre el diálogo nunca debe quedar capturado por el joystick
		# que ocupa la esquina inferior izquierda en móviles.
		if _joystick_touch_index != -1:
			_joystick_touch_index = -1
			_joystick_vector = Vector2.ZERO
			_actualizar_visual_joystick()
			_actualizar_acciones_joystick()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var punto_local: Vector2 = $Movement.get_global_transform_with_canvas().affine_inverse() * touch.position
		var base_rect: Rect2 = Rect2($Movement/JoystickBase.position, $Movement/JoystickBase.size)
		# Captura el toque en el área del joystick, incluso con escala de viewport.
		var zona_captura := base_rect.grow(24.0)
		if touch.pressed and _joystick_touch_index == -1 and zona_captura.has_point(punto_local):
			_joystick_touch_index = touch.index
			_actualizar_joystick_desde_local(punto_local)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_joystick_vector = Vector2.ZERO
			_actualizar_visual_joystick()
			_actualizar_acciones_joystick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joystick_touch_index:
			var punto_local: Vector2 = $Movement.get_global_transform_with_canvas().affine_inverse() * drag.position
			_actualizar_joystick_desde_local(punto_local)
			get_viewport().set_input_as_handled()


func _hay_dialogo_abierto() -> bool:
	for nodo in get_tree().get_nodes_in_group("dialogue_system"):
		if is_instance_valid(nodo) and nodo.has_method("esta_abierto") and bool(nodo.call("esta_abierto")):
			return true
	return false


func _actualizar_joystick_desde_local(punto_local: Vector2) -> void:
	var base_rect: Rect2 = Rect2($Movement/JoystickBase.position, $Movement/JoystickBase.size)
	var centro: Vector2 = base_rect.position + base_rect.size * 0.5
	var desplazamiento: Vector2 = punto_local - centro
	_joystick_vector = desplazamiento.limit_length(_joystick_radio) / maxf(_joystick_radio, 1.0)
	_actualizar_visual_joystick()
	_actualizar_acciones_joystick()


func _actualizar_visual_joystick() -> void:
	if not is_instance_valid($Movement/JoystickKnob):
		return
	var base := $Movement/JoystickBase
	var knob := $Movement/JoystickKnob
	var centro: Vector2 = base.position + base.size * 0.5
	knob.position = centro - knob.size * 0.5 + _joystick_vector * _joystick_radio


func _actualizar_acciones_joystick() -> void:
	var valores := {
		"move_left": maxf(0.0, -_joystick_vector.x),
		"move_right": maxf(0.0, _joystick_vector.x),
		"move_up": maxf(0.0, -_joystick_vector.y),
		"move_down": maxf(0.0, _joystick_vector.y),
	}
	for accion in valores:
		if not InputMap.has_action(accion):
			continue
		var fuerza := float(valores[accion])
		var evento := InputEventAction.new()
		evento.action = accion
		evento.pressed = fuerza > 0.12
		evento.strength = fuerza
		Input.parse_input_event(evento)


func _es_dispositivo_movil() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


func _alternar_pausa() -> void:
	var evento := InputEventKey.new()
	evento.keycode = KEY_ESCAPE
	evento.pressed = true
	Input.parse_input_event(evento)
	var liberacion := evento.duplicate() as InputEventKey
	liberacion.pressed = false
	Input.parse_input_event(liberacion)


func _presionar_espacio() -> void:
	if _meditar_presionado:
		return
	_meditar_presionado = true
	var evento := InputEventKey.new()
	evento.keycode = KEY_SPACE
	evento.physical_keycode = KEY_SPACE
	evento.pressed = true
	Input.parse_input_event(evento)


func _soltar_espacio() -> void:
	if not _meditar_presionado:
		return
	_meditar_presionado = false
	var evento := InputEventKey.new()
	evento.keycode = KEY_SPACE
	evento.physical_keycode = KEY_SPACE
	evento.pressed = false
	Input.parse_input_event(evento)


func _solicitar_inventario() -> void:
	var inventarios := get_tree().get_nodes_in_group("inventory")
	for nodo in inventarios:
		if is_instance_valid(nodo) and nodo.has_method("toggle"):
			nodo.call_deferred("toggle")
			return
	_solicitar_hud("toggle_inventory")


func _solicitar_hud(accion: String) -> void:
	# MobileControls puede estar anidado bajo un contenedor de UI, no directamente bajo el HUD.
	var hud := get_parent()
	if hud != null and hud.has_method("accion_controles_moviles"):
		hud.call("accion_controles_moviles", accion)
		return
	for candidato in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(candidato) and candidato.has_method("accion_controles_moviles"):
			candidato.call("accion_controles_moviles", accion)
			return
	push_warning("Controles móviles: no se encontró un HUD para '%s'." % accion)


func _posicionar(control: Control, posicion: Vector2, tamano: Vector2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = posicion
	control.size = tamano
	control.custom_minimum_size = tamano


func _presionar_accion(accion: String) -> void:
	if accion.is_empty() or not InputMap.has_action(accion):
		return
	_acciones_presionadas[accion] = true
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	evento.strength = 1.0
	# Además de actualizar Input, esto entrega el evento al router de gameplay,
	# que procesa las acciones primaria/secundaria desde _input(event).
	Input.parse_input_event(evento)


func _soltar_accion(accion: String) -> void:
	if accion.is_empty():
		return
	_acciones_presionadas.erase(accion)
	if InputMap.has_action(accion):
		var evento := InputEventAction.new()
		evento.action = accion
		evento.pressed = false
		evento.strength = 0.0
		Input.parse_input_event(evento)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_liberar_todas_las_acciones()


func _exit_tree() -> void:
	_liberar_todas_las_acciones()


func _liberar_todas_las_acciones() -> void:
	_soltar_espacio()
	_joystick_touch_index = -1
	_joystick_vector = Vector2.ZERO
	if is_inside_tree():
		_actualizar_visual_joystick()
		_actualizar_acciones_joystick()
	for accion_variant in _acciones_presionadas.keys():
		var accion := str(accion_variant)
		if InputMap.has_action(accion):
			var evento := InputEventAction.new()
			evento.action = accion
			evento.pressed = false
			evento.strength = 0.0
			Input.parse_input_event(evento)
	_acciones_presionadas.clear()
