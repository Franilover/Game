extends Entity
class_name SaltusPlayer

const IDLE_TEXTURE_PATH: String = "res://assets/art/kingdom/Torres/Personajes/Sprite-0004.png"
const WALK_TEXTURE_PATH: String = "res://assets/art/kingdom/Torres/Personajes/Sprite-0004_Walking_Left.png"

@export var move_speed: float = 190.0
@export var run_multiplier: float = 1.35
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0
@export var acceleration: float = 1500.0
@export var friction: float = 1900.0
@export var dash_distance: float = 64.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 0.8

@onready var sprite: Sprite2D = $Sprite2D

var _jump_requested: bool = false
var _dash_requested: bool = false
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _air_dash_unlocked: bool = false
var _air_dash_available: bool = false
var _elapsed: float = 0.0
var _idle_texture: Texture2D
var _walk_texture: Texture2D


func _ready() -> void:
	super._ready()
	add_to_group("saltus_player")
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_idle_texture = load(IDLE_TEXTURE_PATH) as Texture2D
		_walk_texture = load(WALK_TEXTURE_PATH) as Texture2D
		if _idle_texture != null:
			sprite.texture = _idle_texture


func unlock_air_dash() -> void:
	_air_dash_unlocked = true
	_air_dash_available = true


func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var tecla := event as InputEventKey
	# En Saltus, ESPACIO salta y SHIFT solicita el dash.
	if tecla.pressed and not tecla.echo:
		if tecla.keycode == KEY_SPACE or tecla.physical_keycode == KEY_SPACE:
			_jump_requested = true
		elif tecla.keycode == KEY_SHIFT or tecla.physical_keycode == KEY_SHIFT:
			_dash_requested = true


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
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	if is_on_floor() and _air_dash_unlocked:
		_air_dash_available = true

	var direction := Input.get_axis("move_left", "move_right")
	var aim_vertical := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	var dash_aim := Vector2(direction, aim_vertical).normalized()

	if _dash_time_left > 0.0:
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
		velocity = _dash_direction * (dash_distance / maxf(dash_duration, 0.01))
		move_and_slide()
		if _dash_time_left <= 0.0:
			velocity = Vector2.ZERO
		_actualizar_presentacion(direction)
		return

	if _dash_requested:
		_dash_requested = false
		if _dash_cooldown_left <= 0.0 and (is_on_floor() or _air_dash_available):
			if not is_on_floor():
				_air_dash_available = false
			if dash_aim.length_squared() > 0.01:
				_dash_direction = dash_aim
			elif absf(direction) > 0.01:
				_dash_direction = Vector2(signf(direction), 0.0)
			else:
				_dash_direction = Vector2.LEFT if sprite != null and sprite.flip_h else Vector2.RIGHT
			_dash_time_left = dash_duration
			_dash_cooldown_left = dash_cooldown
			velocity = _dash_direction * (dash_distance / maxf(dash_duration, 0.01))
			move_and_slide()
			_actualizar_presentacion(direction)
			return

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
