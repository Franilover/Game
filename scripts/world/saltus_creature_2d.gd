extends CharacterBody2D
class_name SaltusCreature2D

## Movimiento 2D específico de Saltus. No altera el comportamiento del mundo libre.

@export_enum("Zlish", "Flaxis") var especie: String = "Zlish"

@export_category("Zlish")
@export var patrol_range: float = 130.0
@export var patrol_speed: float = 42.0
@export var jump_velocity: float = -285.0
@export var gravity: float = 900.0
@export var jump_interval_min: float = 1.8
@export var jump_interval_max: float = 3.8

@export_category("Flaxis")
@export var detection_range: float = 220.0
@export var flight_speed: float = 100.0
@export var attack_damage: int = 8
@export var attack_range: float = 25.0
@export var attack_cooldown: float = 1.5
@export var attack_windup: float = 0.22
@export var attack_lunge_speed: float = 245.0

@onready var sprite: Sprite2D = $Sprite2D

var _rng := RandomNumberGenerator.new()
var _home_x: float = 0.0
var _direction: float = 1.0
var _jump_timer: float = 2.0
var _animation_time: float = 0.0
var _attack_cooldown_left: float = 0.0
var _windup_left: float = 0.0
var _lunge_left: float = 0.0
var _attack_direction: Vector2 = Vector2.ZERO
var _target: Node2D
var _flaxis_hover_origin: Vector2
var _flaxis_phase: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_home_x = global_position.x
	_flaxis_hover_origin = global_position
	_jump_timer = _rng.randf_range(jump_interval_min, jump_interval_max)
	if especie == "Zlish":
		collision_layer = 4
		collision_mask = 1
	else:
		collision_layer = 0
		collision_mask = 0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_animation_time += delta
	if especie == "Zlish":
		_procesar_zlish(delta)
	else:
		_procesar_flaxis(delta)


func _procesar_zlish(delta: float) -> void:
	_jump_timer -= delta
	if global_position.x <= _home_x - patrol_range:
		_direction = 1.0
	elif global_position.x >= _home_x + patrol_range:
		_direction = -1.0
	velocity.x = _direction * patrol_speed
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
		if _jump_timer <= 0.0:
			velocity.y = jump_velocity
			_jump_timer = _rng.randf_range(jump_interval_min, jump_interval_max)
	move_and_slide()
	if sprite != null:
		sprite.flip_h = _direction < 0.0
		if sprite.hframes > 1:
			sprite.frame = int(_animation_time * 7.0) % sprite.hframes


func _procesar_flaxis(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	_flaxis_phase += delta
	if not is_instance_valid(_target):
		_target = _buscar_jugador()
	var destino := _flaxis_hover_origin + Vector2(0.0, sin(_flaxis_phase * 1.8) * 13.0)
	if is_instance_valid(_target):
		var distancia := global_position.distance_to(_target.global_position)
		if distancia <= detection_range:
			destino = _target.global_position + Vector2(0.0, -12.0)
			if distancia <= detection_range * 0.72 and _attack_cooldown_left <= 0.0 and _windup_left <= 0.0 and _lunge_left <= 0.0:
				_iniciar_ataque(destino)
	if _windup_left > 0.0:
		_windup_left = maxf(0.0, _windup_left - delta)
		velocity = Vector2.ZERO
		if _windup_left <= 0.0:
			_lunge_left = 0.20
	elif _lunge_left > 0.0:
		_lunge_left = maxf(0.0, _lunge_left - delta)
		velocity = _attack_direction * attack_lunge_speed
		move_and_slide()
		if _lunge_left <= 0.0:
			_resolver_ataque()
	else:
		var diferencia := destino - global_position
		var direccion := diferencia.normalized() if diferencia.length_squared() > 4.0 else Vector2.ZERO
		velocity = velocity.move_toward(direccion * flight_speed, flight_speed * 3.5 * delta)
		move_and_slide()
	if sprite != null:
		sprite.flip_h = velocity.x < -1.0


func _iniciar_ataque(destino: Vector2) -> void:
	_attack_direction = (destino - global_position).normalized()
	if _attack_direction == Vector2.ZERO:
		_attack_direction = Vector2.DOWN
	_windup_left = attack_windup
	_attack_cooldown_left = attack_cooldown


func _resolver_ataque() -> void:
	if not is_instance_valid(_target):
		return
	if global_position.distance_to(_target.global_position) > attack_range + 22.0:
		return
	if _target.has_method("take_damage"):
		_target.call("take_damage", attack_damage, "Flaxis de Saltus")


func _buscar_jugador() -> Node2D:
	var candidatos := get_tree().get_nodes_in_group("saltus_player")
	for candidato in candidatos:
		if candidato is Node2D and is_instance_valid(candidato):
			return candidato as Node2D
	return null
