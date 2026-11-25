extends CharacterBody2D
class_name SaltusPlayer

@export var move_speed: float = 190.0
@export var run_multiplier: float = 1.35
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0
@export var acceleration: float = 1500.0
@export var friction: float = 1900.0

@onready var sprite: Sprite2D = $Sprite2D

var _jump_requested: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	add_to_group("saltus_player")
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE):
			_jump_requested = true


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var direction := Input.get_axis("move_left", "move_right")
	var speed := move_speed
	if Input.is_action_pressed("run"):
		speed *= run_multiplier

	if absf(direction) > 0.01:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	var jump_pressed := _jump_requested or Input.is_action_just_pressed("jump")
	_jump_requested = false
	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
	_actualizar_presentacion(direction)


func _actualizar_presentacion(direction: float) -> void:
	if sprite == null:
		return
	if absf(direction) > 0.05:
		sprite.flip_h = direction < 0.0
	if is_on_floor() and absf(velocity.x) > 18.0:
		sprite.position.y = -22.0 + sin(_elapsed * 15.0) * 1.3
	else:
		sprite.position.y = move_toward(sprite.position.y, -22.0, 1.0)
