extends Node
class_name CreatureMovement

var creature: CharacterBody2D = null

var move_speed: float = 20.0
var min_move_time: float = 1.0
var max_move_time: float = 3.0

var limites_chunk: Rect2 = Rect2()

var _move_direction: Vector2 = Vector2.ZERO
var _move_timer: float = 0.0

var _usar_direccion_externa: bool = false
var _direccion_externa: Vector2 = Vector2.ZERO

var _rng := RandomNumberGenerator.new()


func configurar(
	nueva_criatura: CharacterBody2D,
	nueva_velocidad: float,
	nuevo_min_move_time: float,
	nuevo_max_move_time: float,
	semilla: int
) -> void:
	creature = nueva_criatura

	move_speed = maxf(nueva_velocidad, 0.0)
	min_move_time = maxf(nuevo_min_move_time, 0.0)
	max_move_time = maxf(nuevo_max_move_time, min_move_time)

	_rng.seed = semilla

	_move_timer = 0.0
	_move_direction = Vector2.ZERO


func configurar_chunk(nuevos_limites: Rect2) -> void:
	limites_chunk = nuevos_limites


func procesar(delta: float) -> void:
	if creature == null:
		return

	if not is_instance_valid(creature):
		return

	_move_timer -= delta

	if not _usar_direccion_externa and _move_timer <= 0.0:
		_elegir_movimiento()

	var direccion: Vector2 = (
		_direccion_externa
		if _usar_direccion_externa
		else _move_direction
	)

	creature.velocity = direccion * move_speed
	creature.move_and_slide()

	_mantener_en_chunk()


func establecer_direccion(direccion: Vector2) -> void:
	if direccion.length_squared() <= 0.001:
		_direccion_externa = Vector2.ZERO
		return

	_direccion_externa = direccion.normalized()


func tomar_control() -> void:
	_usar_direccion_externa = true


func liberar_control() -> void:
	_usar_direccion_externa = false
	_direccion_externa = Vector2.ZERO
	_move_timer = 0.0


func detener() -> void:
	_move_direction = Vector2.ZERO
	_direccion_externa = Vector2.ZERO

	if creature != null and is_instance_valid(creature):
		creature.velocity = Vector2.ZERO


func _elegir_movimiento() -> void:
	_move_timer = _rng.randf_range(
		min_move_time,
		max_move_time
	)

	if _rng.randf() < 0.30:
		_move_direction = Vector2.ZERO
		return

	var direccion := Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	)

	if direccion.length_squared() <= 0.001:
		_move_direction = Vector2.ZERO
		return

	_move_direction = direccion.normalized()


func _mantener_en_chunk() -> void:
	if creature == null:
		return

	if limites_chunk.size.is_zero_approx():
		return

	var limites: Rect2 = limites_chunk.grow(-10.0)

	if limites.has_point(creature.global_position):
		return

	var centro: Vector2 = limites.get_center()

	var direccion: Vector2 = (
		creature.global_position.direction_to(centro)
	)

	if direccion.length_squared() <= 0.001:
		detener()
		return

	_move_direction = direccion
	_move_timer = 1.0
