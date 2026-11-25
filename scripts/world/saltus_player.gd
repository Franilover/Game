extends CharacterBody2D
class_name SaltusPlayer

const IDLE_TEXTURE_PATH: String = "res://assets/art/kingdom/Torres/Personajes/Sprite-0004.png"
const WALK_TEXTURE_PATH: String = "res://assets/art/kingdom/Torres/Personajes/Sprite-0004_Walking_Left.png"

@export var move_speed: float = 190.0
@export var run_multiplier: float = 1.35
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0
@export var acceleration: float = 1500.0
@export var friction: float = 1900.0

@onready var sprite: Sprite2D = $Sprite2D

var _jump_requested: bool = false
var _elapsed: float = 0.0
var _idle_texture: Texture2D
var _walk_texture: Texture2D


func _ready() -> void:
	add_to_group("saltus_player")
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_idle_texture = load(IDLE_TEXTURE_PATH) as Texture2D
		_walk_texture = load(WALK_TEXTURE_PATH) as Texture2D
		if _idle_texture != null:
			sprite.texture = _idle_texture


func _input(event: InputEvent) -> void:
	# En la expedición 2D, ESPACIO es exclusivamente salto.
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if (tecla.keycode == KEY_SPACE or tecla.physical_keycode == KEY_SPACE) and tecla.pressed and not tecla.echo:
			_jump_requested = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE):
			_jump_requested = true
		elif key.pressed and not key.echo and (key.keycode == KEY_E or key.physical_keycode == KEY_E):
			var gestor := get_tree().get_first_node_in_group("zone_manager")
			if is_instance_valid(gestor) and gestor.has_method("salir_expedicion_saltus"):
				gestor.call("salir_expedicion_saltus")


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
		sprite.flip_h = direction > 0.0
		if _walk_texture != null:
			sprite.texture = _walk_texture
	else:
		if _idle_texture != null:
			sprite.texture = _idle_texture
		sprite.flip_h = false
	if is_on_floor() and absf(velocity.x) > 18.0:
		sprite.position.y = -22.0 + sin(_elapsed * 15.0) * 1.3
	else:
		sprite.position.y = move_toward(sprite.position.y, -22.0, 1.0)
