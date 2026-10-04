extends RefCounted
class_name PlayerMovementController

## Reglas de movimiento independientes del nodo Player.
## El nodo Player seguirá siendo responsable de física/animación durante la migración.

enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	DASH
}

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN

func calcular_direccion(input_direction: Vector2) -> Vector2:
	if input_direction == Vector2.ZERO:
		return Vector2.ZERO
	return input_direction.normalized()

func calcular_velocidad(
	direction: Vector2,
	move_speed: float,
	run_multiplier: float,
	corriendo: bool
) -> Vector2:
	var speed := move_speed
	if corriendo:
		speed *= run_multiplier
	return direction * speed

func actualizar_facing(direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	var nuevo := direction.normalized()
	if nuevo == facing:
		return false
	facing = nuevo
	return true

func determinar_estado(
	direction: Vector2,
	corriendo: bool
) -> State:
	if direction == Vector2.ZERO:
		return State.IDLE
	if corriendo:
		return State.RUN
	return State.WALK
