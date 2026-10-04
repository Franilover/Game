extends RefCounted
class_name PlayerActionController

## Runtime de acciones temporales del jugador.
## No mueve al personaje ni modifica stamina: solo administra estados y ventanas.

signal accion_iniciada(tipo: String)
signal accion_finalizada(tipo: String)

enum State {
	NONE,
	JUMP,
	DASH
}

var state: State = State.NONE
var direction: Vector2 = Vector2.DOWN
var jump_time: float = 0.0
var jump_cooldown_timer: float = 0.0
var dash_time: float = 0.0
var dash_cooldown_timer: float = 0.0

func actualizar_cooldowns(delta: float) -> void:
	jump_cooldown_timer = maxf(jump_cooldown_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

func puede_saltar() -> bool:
	return state == State.NONE and jump_cooldown_timer <= 0.0 and dash_time <= 0.0

func puede_hacer_dash() -> bool:
	return state == State.NONE and dash_cooldown_timer <= 0.0 and jump_time <= 0.0

func iniciar_salto(nueva_direccion: Vector2, duracion: float, cooldown: float) -> bool:
	if not puede_saltar():
		return false
	state = State.JUMP
	direction = _normalizar_direccion(nueva_direccion)
	jump_time = maxf(duracion, 0.0)
	jump_cooldown_timer = maxf(cooldown, 0.0)
	accion_iniciada.emit("jump")
	return true

func iniciar_dash(nueva_direccion: Vector2, duracion: float, cooldown: float) -> bool:
	if not puede_hacer_dash():
		return false
	state = State.DASH
	direction = _normalizar_direccion(nueva_direccion)
	dash_time = maxf(duracion, 0.0)
	dash_cooldown_timer = maxf(cooldown, 0.0)
	accion_iniciada.emit("dash")
	return true

func avanzar(delta: float) -> void:
	match state:
		State.JUMP:
			jump_time = maxf(jump_time - delta, 0.0)
			if jump_time <= 0.0:
				state = State.NONE
				accion_finalizada.emit("jump")
		State.DASH:
			dash_time = maxf(dash_time - delta, 0.0)
			if dash_time <= 0.0:
				state = State.NONE
				accion_finalizada.emit("dash")

func procesando_salto() -> bool:
	return state == State.JUMP

func procesando_dash() -> bool:
	return state == State.DASH

func obtener_direccion() -> Vector2:
	return direction

func obtener_progreso_salto(duracion: float) -> float:
	var total := maxf(duracion, 0.001)
	return clampf(1.0 - (jump_time / total), 0.0, 1.0)

func obtener_velocidad(duracion: float, distancia: float) -> float:
	return maxf(distancia, 0.0) / maxf(duracion, 0.001)

func _normalizar_direccion(valor: Vector2) -> Vector2:
	if valor.length_squared() <= 0.01:
		return Vector2.DOWN
	return valor.normalized()
