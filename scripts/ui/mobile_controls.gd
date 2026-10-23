extends Control
class_name GarliaMobileControls

## Capa táctil de Android. Reutiliza el InputMap para no duplicar gameplay.
## El layout se calcula en píxeles de viewport y se adapta a orientación/tamaño.

@export var solo_android: bool = true
@export_range(48, 96, 2) var tamano_dpad: int = 64
@export_range(48, 96, 2) var tamano_accion: int = 68
@export_range(8, 48, 2) var margen_borde: int = 20
@export_range(4, 24, 2) var separacion: int = 10

var _acciones_presionadas: Dictionary = {}
var _botones: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if solo_android and not OS.has_feature("android"):
		hide()
		return

	_botones = {
		"move_up": $Movement/Up,
		"move_down": $Movement/Down,
		"move_left": $Movement/Left,
		"move_right": $Movement/Right,
		"interact": $Actions/Interact,
		"primary_action": $Actions/Primary,
		"secondary_action": $Actions/Secondary,
		"run": $Actions/Dash,
		"jump": $Actions/Jump,
		"inventory": $Actions/Inventory,
	}
	for accion in _botones:
		_configurar_boton(_botones[accion] as BaseButton, str(accion))
		_estilizar_boton(_botones[accion] as Button, str(accion))
	get_viewport().size_changed.connect(_distribuir_controles)
	_distribuir_controles()


func _configurar_boton(boton: BaseButton, accion: String) -> void:
	if boton == null or not InputMap.has_action(accion):
		push_warning("Control móvil: no existe la acción InputMap '%s'." % accion)
		return
	boton.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	boton.focus_mode = Control.FOCUS_NONE
	boton.mouse_filter = Control.MOUSE_FILTER_STOP
	boton.button_down.connect(func() -> void:
		_presionar_accion(accion)
	)
	boton.button_up.connect(func() -> void:
		_soltar_accion(accion)
	)


func _estilizar_boton(boton: Button, accion: String) -> void:
	if boton == null:
		return
	var nombres := {
		"move_up": "▲", "move_down": "▼", "move_left": "◀", "move_right": "▶",
		"interact": "E", "primary_action": "A", "secondary_action": "B",
		"run": "⇢", "jump": "↑", "inventory": "▤"
	}
	boton.text = str(nombres.get(accion, "•"))
	boton.add_theme_font_size_override("font_size", 25 if accion.begins_with("move_") else 22)
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
	boton.custom_minimum_size = Vector2(tamano_dpad, tamano_dpad) if accion.begins_with("move_") else Vector2(tamano_accion, tamano_accion)
	boton.tooltip_text = str({
		"interact": "Interactuar", "primary_action": "Acción principal",
		"secondary_action": "Acción secundaria", "run": "Dash / correr",
		"jump": "Saltar", "inventory": "Inventario"
	}.get(accion, accion.capitalize()))


func _distribuir_controles() -> void:
	if not is_inside_tree() or (solo_android and not OS.has_feature("android")):
		return
	var size := get_viewport_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var compacto := size.x < 700.0 or size.y < 420.0
	var d := float(tamano_dpad - (8 if compacto else 0))
	var a := float(tamano_accion - (8 if compacto else 0))
	var gap := float(maxi(separacion - (2 if compacto else 0), 4))
	var margen := float(margen_borde)
	var base_y := size.y - margen - d * 3.0 - gap * 2.0
	var base_x := margen
	# Cruceta compacta: mantiene objetivos táctiles grandes y permite diagonales.
	_posicionar($Movement/Up, Vector2(base_x + d + gap, base_y), Vector2(d, d))
	_posicionar($Movement/Left, Vector2(base_x, base_y + d + gap), Vector2(d, d))
	_posicionar($Movement/Right, Vector2(base_x + (d + gap) * 2.0, base_y + d + gap), Vector2(d, d))
	_posicionar($Movement/Down, Vector2(base_x + d + gap, base_y + (d + gap) * 2.0), Vector2(d, d))

	# Acciones a la derecha, en arco: salto y acción principal quedan más accesibles.
	var right := size.x - margen
	var bottom := size.y - margen
	_posicionar($Actions/Primary, Vector2(right - a, bottom - a), Vector2(a, a))
	_posicionar($Actions/Jump, Vector2(right - a * 2.0 - gap, bottom - a * 1.55 - gap), Vector2(a, a))
	_posicionar($Actions/Secondary, Vector2(right - a * 2.0 - gap, bottom - a * 0.45), Vector2(a, a))
	_posicionar($Actions/Interact, Vector2(right - a * 3.0 - gap * 2.0, bottom - a * 0.45), Vector2(a, a))
	_posicionar($Actions/Dash, Vector2(right - a * 2.0 - gap, bottom - a * 2.65 - gap * 2.0), Vector2(a, a))
	_posicionar($Actions/Inventory, Vector2(right - a * 3.0 - gap * 2.0, bottom - a * 1.55 - gap), Vector2(a, a))


func _posicionar(control: Control, posicion: Vector2, tamano: Vector2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = posicion
	control.size = tamano
	control.custom_minimum_size = tamano


func _presionar_accion(accion: String) -> void:
	if accion.is_empty() or not InputMap.has_action(accion):
		return
	_acciones_presionadas[accion] = true
	Input.action_press(accion)


func _soltar_accion(accion: String) -> void:
	if accion.is_empty():
		return
	_acciones_presionadas.erase(accion)
	if InputMap.has_action(accion):
		Input.action_release(accion)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_liberar_todas_las_acciones()


func _exit_tree() -> void:
	_liberar_todas_las_acciones()


func _liberar_todas_las_acciones() -> void:
	for accion_variant in _acciones_presionadas.keys():
		var accion := str(accion_variant)
		if InputMap.has_action(accion):
			Input.action_release(accion)
	_acciones_presionadas.clear()
