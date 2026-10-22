extends RefCounted
class_name PlayerStaminaController

## Reserva discreta de impulsos para dash. No se regenera con el tiempo.
signal stamina_changed(current: float, maximum: float)

const MAX_CARGAS: int = 3
var current: float = MAX_CARGAS
var maximum: float = MAX_CARGAS
var regeneration: float = 0.0
var regeneration_delay: float = 0.0
var regeneration_timer: float = 0.0

func configurar(maximo: float, actual: float = -1.0) -> void:
	maximum = clampf(roundf(maximo), 1.0, float(MAX_CARGAS))
	current = maximum if actual < 0.0 else clampf(roundf(actual), 0.0, maximum)
	regeneration_timer = 0.0
	stamina_changed.emit(current, maximum)

func establecer_maximo(maximo: float, conservar_actual: bool = true) -> void:
	maximum = clampf(roundf(maximo), 1.0, float(MAX_CARGAS))
	current = minf(current, maximum) if conservar_actual else maximum
	stamina_changed.emit(current, maximum)

func establecer_actual(actual: float) -> void:
	current = clampf(roundf(actual), 0.0, maximum)
	stamina_changed.emit(current, maximum)

func tiene(cantidad: float) -> bool:
	return current >= maxf(ceilf(cantidad), 0.0)

func gastar(cantidad: float) -> bool:
	var gasto := maxf(ceilf(cantidad), 0.0)
	if current < gasto:
		return false
	if gasto <= 0.0:
		return true
	current = maxf(current - gasto, 0.0)
	stamina_changed.emit(current, maximum)
	return true

func restaurar(cantidad: float) -> bool:
	var recuperacion := maxf(floorf(cantidad), 0.0)
	if recuperacion <= 0.0 or current >= maximum:
		return false
	var anterior := current
	current = minf(current + recuperacion, maximum)
	if current == anterior:
		return false
	stamina_changed.emit(current, maximum)
	return true

func actualizar(_delta: float, _puede_regenerar: bool) -> void:
	pass

func reiniciar() -> void:
	current = maximum
	regeneration_timer = 0.0
	stamina_changed.emit(current, maximum)

func establecer_regeneracion(_valor: float, _retraso: float = -1.0) -> void:
	# Las cargas solo se recuperan mediante Eterium o descanso.
	regeneration = 0.0
	regeneration_delay = 0.0
