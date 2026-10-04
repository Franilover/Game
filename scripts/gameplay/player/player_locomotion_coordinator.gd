extends RefCounted
class_name PlayerLocomotionCoordinator

## Coordina movimiento normal, acciones especiales y stamina.
## No conoce Node2D, input, UI, animaciones ni Supabase.

var movement: PlayerMovementController
var actions: PlayerActionController
var stamina: PlayerStaminaController

func configurar(
	nuevo_movement: PlayerMovementController,
	nuevas_actions: PlayerActionController,
	nueva_stamina: PlayerStaminaController
) -> void:
	movement = nuevo_movement
	actions = nuevas_actions
	stamina = nueva_stamina

func actualizar_cooldowns(delta: float) -> void:
	if actions != null:
		actions.actualizar_cooldowns(delta)

func puede_saltar(costo: float) -> bool:
	if actions == null or stamina == null:
		return false
	return actions.puede_saltar() and stamina.tiene(costo)

func puede_hacer_dash(costo: float) -> bool:
	if actions == null or stamina == null:
		return false
	return actions.puede_hacer_dash() and stamina.tiene(costo)

func iniciar_salto(
	direccion: Vector2,
	duracion: float,
	cooldown: float,
	costo: float
) -> bool:
	if not puede_saltar(costo):
		return false
	if not stamina.gastar(costo):
		return false
	return actions.iniciar_salto(direccion, duracion, cooldown)

func iniciar_dash(
	direccion: Vector2,
	duracion: float,
	cooldown: float,
	costo: float
) -> bool:
	if not puede_hacer_dash(costo):
		return false
	if not stamina.gastar(costo):
		return false
	return actions.iniciar_dash(direccion, duracion, cooldown)

func avanzar_accion(delta: float) -> void:
	if actions != null:
		actions.avanzar(delta)

func procesando_accion() -> bool:
	return actions != null and actions.state != PlayerActionController.State.NONE

func procesando_salto() -> bool:
	return actions != null and actions.procesando_salto()

func procesando_dash() -> bool:
	return actions != null and actions.procesando_dash()

func obtener_direccion_accion(fallback: Vector2 = Vector2.DOWN) -> Vector2:
	if actions == null:
		return fallback
	return actions.obtener_direccion()

func obtener_velocidad_accion(duracion: float, distancia: float) -> float:
	if actions == null:
		return 0.0
	return actions.obtener_velocidad(duracion, distancia)

func obtener_progreso_salto(duracion: float) -> float:
	if actions == null:
		return 0.0
	return actions.obtener_progreso_salto(duracion)

func calcular_movimiento(
	input_direction: Vector2,
	move_speed: float,
	run_multiplier: float,
	corriendo: bool
) -> Vector2:
	if movement == null:
		return Vector2.ZERO
	return movement.actualizar(
		input_direction,
		move_speed,
		run_multiplier,
		corriendo
	)

func obtener_direccion_accion(fallback: Vector2 = Vector2.DOWN) -> Vector2:
	if actions == null:
		return fallback
	return actions.obtener_direccion()

func obtener_estado_movimiento() -> PlayerMovementController.State:
	if movement == null:
		return PlayerMovementController.State.IDLE
	return movement.state

func obtener_facing() -> Vector2:
	if movement == null:
		return Vector2.DOWN
	return movement.facing

func reiniciar() -> void:
	if movement != null:
		movement.reiniciar()
	if actions != null:
		actions.state = PlayerActionController.State.NONE
		actions.direction = Vector2.DOWN
		actions.jump_time = 0.0
		actions.dash_time = 0.0
		actions.jump_cooldown_timer = 0.0
		actions.dash_cooldown_timer = 0.0
