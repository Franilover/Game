extends RefCounted
class_name GarumiEteriumClock

## Reloj individual de recuperación de Eterium para una instancia de Garumi.
## No decide cómo se calculan modificadores: recibe la recuperación efectiva
## por tick para mantener esa política fuera del reloj temporal.

var eterium_actual: int = 0
var eterium_maximo: int = 0
var progreso_us: int = 0
var intervalo_us: int = 1_000_000
var recuperacion_efectiva: int = 1


func configurar(
	actual: int,
	maximo: int,
	intervalo_recuperacion_us: int,
	recuperacion_por_tick: int = 1,
	progreso_inicial_us: int = 0
) -> void:
	eterium_maximo = maxi(0, maximo)
	eterium_actual = clampi(actual, 0, eterium_maximo)
	intervalo_us = maxi(1, intervalo_recuperacion_us)
	recuperacion_efectiva = maxi(0, recuperacion_por_tick)
	progreso_us = clampi(progreso_inicial_us, 0, intervalo_us - 1)
	if eterium_actual >= eterium_maximo:
		# Si ya comienza lleno, el progreso queda pausado y se conserva.
		progreso_us = clampi(progreso_inicial_us, 0, intervalo_us - 1)


func avanzar(delta_us: int) -> int:
	if delta_us <= 0 or eterium_actual >= eterium_maximo:
		return 0
	if recuperacion_efectiva <= 0:
		return 0

	progreso_us += delta_us
	var ticks := int(progreso_us / intervalo_us)
	if ticks <= 0:
		return 0

	var recuperacion_solicitada := ticks * recuperacion_efectiva
	var anterior := eterium_actual
	eterium_actual = mini(eterium_maximo, eterium_actual + recuperacion_solicitada)
	var recuperado := eterium_actual - anterior

	if eterium_actual >= eterium_maximo:
		# El tick que alcanza el máximo concluye el intervalo; no se almacena
		# el tiempo restante del mismo delta como ticks futuros.
		progreso_us = 0
	else:
		progreso_us %= intervalo_us
	return recuperado


func gastar(cantidad: int) -> int:
	if cantidad <= 0:
		return 0
	var gastado := mini(cantidad, eterium_actual)
	eterium_actual -= gastado
	return gastado


func agregar(cantidad: int) -> int:
	if cantidad <= 0:
		return 0
	var anterior := eterium_actual
	eterium_actual = mini(eterium_maximo, eterium_actual + cantidad)
	# Una fuente externa que llena el recurso pausa, pero no borra, el progreso.
	return eterium_actual - anterior


func ajustar_maximo(nuevo_maximo: int) -> void:
	eterium_maximo = maxi(0, nuevo_maximo)
	eterium_actual = mini(eterium_actual, eterium_maximo)
	progreso_us = clampi(progreso_us, 0, intervalo_us - 1)


func progreso_normalizado() -> float:
	if intervalo_us <= 0:
		return 0.0
	return float(progreso_us) / float(intervalo_us)
