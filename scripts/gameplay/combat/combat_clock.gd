extends RefCounted
class_name CombatClock

## Reloj lógico monotónico del combate.
## No usa tiempo de pared ni depende de la frecuencia de renderizado.

var now_us: int = 0


func reset(start_us: int = 0) -> void:
	now_us = maxi(0, start_us)


func advance_to(target_us: int) -> int:
	# El reloj no retrocede aunque llegue una marca temporal antigua.
	now_us = maxi(now_us, target_us)
	return now_us


func advance_by(delta_us: int) -> int:
	if delta_us <= 0:
		return now_us
	now_us += delta_us
	return now_us
