extends Control
class_name GarliaMobileControls

## Capa táctil de Android. Reutiliza el InputMap para no duplicar gameplay.
## El layout se calcula en píxeles de viewport y se adapta a orientación/tamaño.

@export var solo_android: bool = true
@export_range(96, 180, 4) var tamano_joystick: int = 136
@export_range(48, 96, 2) var tamano_accion: int = 68
@export_range(8, 48, 2) var margen_borde: int = 20
@export_range(4, 24, 2) var separacion: int = 10

var _acciones_presionadas: Dictionary = {}
var _botones: Dictionary = {}
var _joystick_touch_index: int = -1
var _joystick_vector := Vector2.ZERO
var _joystick_radio: float = 54.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if solo_android and not OS.has_feature("android"):
		hide()
		return

	_configurar_estilo_joystick()
	_botones = {
		"interact": $Actions/Interact,
		"primary_action": $Actions/Primary,
		"secondary_action": $Actions/Secondary,
		"run": $Actions/Dash,
		"jump": $Actions/Jump,
		"inventory": $Actions/Inventory,
		"hand_q_use": $Actions/UseQ,
		"hand_e_use": $Actions/UseE,
		"hand_q_select": $Actions/SlotQ,
		"hand_e_select": $Actions/SlotE,
		"ium_menu": $Actions/IUM,
	}

	for accion in _botones:
		_configurar_boton(_botones[accion] as BaseButton, str(accion))
		_estilizar_boton(_botones[accion] as Button, str(accion))
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
	var acciones_ui := ["hand_q_use", "hand_e_use", "hand_q_select", "hand_e_select", "ium_menu"]
	if boton == null or (not InputMap.has_action(accion) and not acciones_ui.has(accion) and accion != "inventory"):
		push_warning("Control móvil: no existe la acción InputMap '%s'." % accion)
		return
	boton.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	boton.focus_mode = Control.FOCUS_NONE
	boton.mouse_filter = Control.MOUSE_FILTER_STOP
	if accion == "hand_q_select":
		boton.pressed.connect(func() -> void: _solicitar_hud("abrir_selector_q"))
	elif accion == "hand_e_select":
		boton.pressed.connect(func() -> void: _solicitar_hud("abrir_selector_e"))
	elif accion == "ium_menu":
		boton.pressed.connect(func() -> void: _solicitar_hud("toggle_ium"))
	elif accion == "inventory":
		boton.pressed.connect(func() -> void: _solicitar_hud("toggle_inventory"))
	elif accion == "hand_q_use":
		boton.pressed.connect(func() -> void: _usar_mano("izquierda"))
	elif accion == "hand_e_use":
		boton.pressed.connect(func() -> void: _usar_mano("derecha"))
	else:
		boton.button_down.connect(func() -> void: _presionar_accion(accion))
		boton.button_up.connect(func() -> void: _soltar_accion(accion))


func _estilizar_boton(boton: Button, accion: String) -> void:
	if boton == null:
		return
	var nombres := {
		"interact": "F", "primary_action": "A", "secondary_action": "B",
		"run": "⇢", "jump": "↑", "inventory": "Tab",
		"hand_q_use": "Q", "hand_e_use": "E", "hand_q_select": "Q ·", "hand_e_select": "E ·", "ium_menu": "X"
	}
	boton.text = str(nombres.get(accion, "•"))
	boton.add_theme_font_size_override("font_size", 18 if accion.begins_with("hand_") or accion == "ium_menu" else 22)
	boton.add_theme_color_override("font_color", Color("#eee8d5"))
	boton.add_theme_color_override("font_hover_color", Color("#ffffff"))
	boton.add_theme_color_override("font_pressed_color", Color("#b4cbe0"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.075, 0.065, 0.055, 0.72)
	normal.border_color = Color(0.72, 0.62, 0.43, 0.78)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(18)
	normal.content_margin_left = 4
	normal.content_margin_right = 4
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.30, 0.25, 0.17, 0.94)
	pressed.border_color = Color("#d8c08c")
	boton.add_theme_stylebox_override("normal", normal)
	boton.add_theme_stylebox_override("hover", normal)
	boton.add_theme_stylebox_override("pressed", pressed)
	boton.add_theme_stylebox_override("focus", normal)
	boton.custom_minimum_size = Vector2(tamano_accion, tamano_accion)
	boton.tooltip_text = str({
		"interact": "Interactuar", "primary_action": "Acción principal",
		"secondary_action": "Acción secundaria", "run": "Dash / correr",
		"jump": "Saltar", "inventory": "Abrir inventario", "hand_q_use": "Usar objeto de Q", "hand_e_use": "Usar objeto de E", "hand_q_select": "Elegir objeto para Q", "hand_e_select": "Elegir objeto para E", "ium_menu": "Menú de IUMs"
	}.get(accion, accion.capitalize()))


func _distribuir_controles() -> void:
	if not is_inside_tree() or (solo_android and not OS.has_feature("android")):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_posicionar($Movement, Vector2.ZERO, viewport_size)
	_posicionar($Actions, Vector2.ZERO, viewport_size)
	var compacto := viewport_size.x < 700.0 or viewport_size.y < 420.0
	var joystick_size := minf(float(tamano_joystick), minf(viewport_size.x * 0.32, viewport_size.y * 0.36))
	joystick_size = maxf(96.0, joystick_size)
	var margen := float(margen_borde)
	var joystick_pos := Vector2(margen, viewport_size.y - margen - joystick_size)
	_posicionar($Movement/JoystickBase, joystick_pos, Vector2(joystick_size, joystick_size))
	$Movement/JoystickKnob.custom_minimum_size = Vector2(joystick_size * 0.42, joystick_size * 0.42)
	$Movement/JoystickKnob.size = $Movement/JoystickKnob.custom_minimum_size
	_joystick_radio = joystick_size * 0.30
	_actualizar_visual_joystick()
	# Disposición en dos zonas: utilidades arriba a la izquierda y combate abajo a la derecha.
	var a := clampf(float(tamano_accion) - (8.0 if compacto else 0.0), 48.0, 68.0)
	var gap := maxf(float(separacion), 12.0)
	var right := viewport_size.x - margen
	var bottom := viewport_size.y - margen
	var small := a * 0.78
	# Inventario, IUM y selección de mano quedan separados del joystick.
	_posicionar($Actions/Inventory, Vector2(margen, margen), Vector2(a, a))
	_posicionar($Actions/IUM, Vector2(margen + a + gap, margen), Vector2(a, a))
	_posicionar($Actions/SlotQ, Vector2(margen + (a + gap) * 2.0, margen + (a - small) * 0.5), Vector2(small, small))
	_posicionar($Actions/SlotE, Vector2(margen + (a + gap) * 2.0 + small + gap * 0.5, margen + (a - small) * 0.5), Vector2(small, small))
	# Acciones de combate en bloque compacto, con separación real entre hitboxes.
	_posicionar($Actions/Primary, Vector2(right - a, bottom - a), Vector2(a, a))
	_posicionar($Actions/Jump, Vector2(right - a * 2.0 - gap, bottom - a * 1.65 - gap), Vector2(a, a))
	_posicionar($Actions/Secondary, Vector2(right - a * 2.0 - gap, bottom - a * 0.45), Vector2(a, a))
	_posicionar($Actions/Interact, Vector2(right - a * 3.0 - gap * 2.0, bottom - a * 0.45), Vector2(a, a))
	_posicionar($Actions/Dash, Vector2(right - a * 3.0 - gap * 2.0, bottom - a * 1.65 - gap), Vector2(a, a))
	_posicionar($Actions/UseQ, Vector2(right - a * 2.0 - gap, bottom - a * 2.0 - gap * 2.0), Vector2(a, a))
	_posicionar($Actions/UseE, Vector2(right - a, bottom - a * 2.0 - gap * 2.0), Vector2(a, a))


func _input(event: InputEvent) -> void:
	if solo_android and not OS.has_feature("android"):
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


func _solicitar_hud(accion: String) -> void:
	var hud := get_parent()
	if hud != null and hud.has_method("accion_controles_moviles"):
		hud.call("accion_controles_moviles", accion)


func _usar_mano(mano: String) -> void:
	var inventario := get_tree().get_first_node_in_group("inventory")
	if inventario != null and inventario.has_method("usar_objeto_mano"):
		inventario.call("usar_objeto_mano", mano)


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
	for accion_variant in _acciones_presionadas.keys():
		var accion := str(accion_variant)
		if InputMap.has_action(accion):
			var evento := InputEventAction.new()
			evento.action = accion
			evento.pressed = false
			evento.strength = 0.0
			Input.parse_input_event(evento)
	_acciones_presionadas.clear()
