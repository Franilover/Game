extends CharacterBody3D
class_name FirstPerson3DController

## Controlador FPS para escenas 2.5D: escenario 3D y arte pixel art 2D.

@export_category("Movimiento")
@export_range(0.5, 12.0, 0.1) var velocidad: float = 4.0
@export_range(0.0005, 0.01, 0.0005) var sensibilidad: float = 0.002
@export_range(40.0, 100.0, 1.0) var limite_vertical: float = 85.0
@export var capturar_raton_al_iniciar: bool = true

@onready var camara: Camera3D = $Camera3D

var _rotacion_vertical: float = 0.0


func _ready() -> void:
	if camara == null:
		push_error("FirstPerson3DController: falta Camera3D como hija directa.")
		return
	if capturar_raton_al_iniciar:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensibilidad)
		_rotacion_vertical = clampf(
			_rotacion_vertical - event.relative.y * sensibilidad,
			deg_to_rad(-limite_vertical),
			deg_to_rad(limite_vertical)
		)
		camara.rotation.x = _rotacion_vertical


func _physics_process(_delta: float) -> void:
	var entrada := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direccion := (global_basis * Vector3(entrada.x, 0.0, entrada.y)).normalized()
	if entrada.length_squared() > 0.0001:
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
	else:
		velocity.x = move_toward(velocity.x, 0.0, velocidad * 8.0 * _delta)
		velocity.z = move_toward(velocity.z, 0.0, velocidad * 8.0 * _delta)
	velocity.y = 0.0
	move_and_slide()
