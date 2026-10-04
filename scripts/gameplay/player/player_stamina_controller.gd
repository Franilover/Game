extends RefCounted
class_name PlayerStaminaController

## Estado y reglas locales de energía del jugador.
## No conoce input, movimiento, UI, inventario ni Supabase.

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
	stamina_changed.emit(current, maximum)

func establecer_maximo(maximo: float, conservar_actual: bool = true) -> void:
	maximum = maxf(maximo, 0.0)
	if conservar_actual:
		current = minf(current, maximum)
	else:
		current = maximum
	stamina_changed.emit(current, maximum)

func establecer_actual(actual: float) -> void:
	current = clampf(actual, 0.0, maximum)
	stamina_changed.emit(current, maximum)

func tiene(cantidad: float) -> bool:
	return current >= maxf(cantidad, 0.0)

func gastar(cantidad: float) -> bool:
	var gasto := maxf(cantidad, 0.0)
	if gasto <= 0.0:
		return true
	if current < gasto:
		return false

	current = maxf(current - gasto, 0.0)
	regeneration_timer = maxf(regeneration_delay, 0.0)
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
	if delta <= 0.0 or not puede_regenerar:
		return

	if regeneration_timer > 0.0:
		regeneration_timer = maxf(regeneration_timer - delta, 0.0)
		return

	if current >= maximum or regeneration <= 0.0:
		return

	current = minf(current + regeneration * delta, maximum)
	stamina_changed.emit(current, maximum)

func reiniciar() -> void:
	current = maximum
	regeneration_timer = 0.0
	stamina_changed.emit(current, maximum)

func establecer_regeneracion(valor: float, retraso: float = -1.0) -> void:
	regeneration = maxf(valor, 0.0)
	if retraso >= 0.0:
		regeneration_delay = maxf(retraso, 0.0)
