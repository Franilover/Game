extends Control
class_name GarliaMobileControls

## Capa de entrada táctil.
## Traduce botones físicos de pantalla a las mismas acciones de InputMap
## que ya utiliza el gameplay de PC/mando. No contiene lógica de juego.

@export var solo_android: bool = true

var _acciones_presionadas: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if solo_android and not OS.has_feature("android"):
		hide()

	_configurar_boton($Movement/Up, "move_up")
	_configurar_boton($Movement/Down, "move_down")
	_configurar_boton($Movement/Left, "move_left")
	_configurar_boton($Movement/Right, "move_right")

	_configurar_boton($Actions/Interact, "interact")
	_configurar_boton($Actions/Primary, "primary_action")
	_configurar_boton($Actions/Secondary, "secondary_action")
	_configurar_boton($Actions/Dash, "dash")
	_configurar_boton($Actions/Jump, "jump")
	_configurar_boton($Actions/Inventory, "inventory")


func _configurar_boton(boton: BaseButton, accion: String) -> void:
	if boton == null:
		return

	boton.button_down.connect(func() -> void:
		_presionar_accion(accion)
	)
	boton.button_up.connect(func() -> void:
		_soltar_accion(accion)
	)
	boton.mouse_exited.connect(func() -> void:
		if Input.is_action_pressed(accion):
			_soltar_accion(accion)
	)


func _presionar_accion(accion: String) -> void:
	if accion.is_empty():
		return
	_acciones_presionadas[accion] = true
	Input.action_press(accion)


func _soltar_accion(accion: String) -> void:
	if accion.is_empty():
		return
	_acciones_presionadas.erase(accion)
	Input.action_release(accion)


func _exit_tree() -> void:
	for accion_variant in _acciones_presionadas.keys():
		Input.action_release(str(accion_variant))
	_acciones_presionadas.clear()
