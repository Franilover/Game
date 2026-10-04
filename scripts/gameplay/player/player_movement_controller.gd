extends RefCounted
class_name PlayerMovementController

## Reglas de locomoción del jugador.
## No conoce input, física, acciones especiales, UI ni nodos.

enum State {
	IDLE,
	WALK,
	RUN
}

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN

func calcular_direccion(input_direction: Vector2) -> Vector2:
	if input_direction.length_squared() <= 0.01:
		return Vector2.ZERO
	return input_direction.normalized()

func calcular_velocidad(
	direction: Vector2,
	move_speed: float,
	run_multiplier: float,
	corriendo: bool
) -> Vector2:
	var velocidad_base := maxf(move_speed, 0.0)
	if corriendo:
		velocidad_base *= maxf(run_multiplier, 0.0)
	return direction * velocidad_base

func actualizar_facing(direction: Vector2) -> bool:
	if direction.length_squared() <= 0.01:
		return false

	var nuevo := direction.normalized()
	if nuevo.is_equal_approx(facing):
		return false

	facing = nuevo
	return true

func determinar_estado(
	direction: Vector2,
	corriendo: bool
) -> State:
	if direction.length_squared() <= 0.01:
		return State.IDLE
	if corriendo:
		return State.RUN
	return State.WALK

func actualizar(
	input_direction: Vector2,
	move_speed: float,
	run_multiplier: float,
	corriendo: bool
) -> Vector2:
	var direction := calcular_direccion(input_direction)
	actualizar_facing(direction)
	state = determinar_estado(direction, corriendo)
	return calcular_velocidad(
		direction,
		move_speed,
		run_multiplier,
		corriendo
	)

func reiniciar() -> void:
	state = State.IDLE
	facing = Vector2.DOWN
