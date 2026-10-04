extends RefCounted
class_name PlayerStaminaController

## Gestión de stamina del jugador.
## No conoce UI ni input.

signal stamina_changed(current: float, maximum: float)

var current: float = 100.0
var maximum: float = 100.0
var regeneration: float = 22.0
var regeneration_delay: float = 0.8
var regeneration_timer: float = 0.0

func configurar(maximo: float, actual: float = -1.0) -> void:
	maximum = maxf(maximo, 0.0)
	current = maximum if actual < 0.0 else clampf(actual, 0.0, maximum)
	regeneration_timer = 0.0

func tiene(cantidad: float) -> bool:
	return current >= maxf(cantidad, 0.0)

func gastar(cantidad: float) -> bool:
	var gasto := maxf(cantidad, 0.0)
	if gasto <= 0.0:
		return true
	if current < gasto:
		return false
	current = maxf(current - gasto, 0.0)
	regeneration_timer = regeneration_delay
	stamina_changed.emit(current, maximum)
	return true

func restaurar(cantidad: float) -> bool:
	var recuperacion := maxf(cantidad, 0.0)
	if recuperacion <= 0.0 or current >= maximum:
		return false
	var anterior := current
	current = minf(current + recuperacion, maximum)
	if current <= anterior:
		return false
	regeneration_timer = 0.0
	stamina_changed.emit(current, maximum)
	return true

func actualizar(delta: float, puede_regenerar: bool) -> void:
	if not puede_regenerar:
		return
	if regeneration_timer > 0.0:
		regeneration_timer = maxf(regeneration_timer - delta, 0.0)
		return
	if current >= maximum:
		return
	current = minf(current + regeneration * delta, maximum)
	stamina_changed.emit(current, maximum)
