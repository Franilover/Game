extends RefCounted
class_name PlayerStaminaController

## Una carga de dash que se recupera automáticamente en tres segundos.
signal stamina_changed(current: float, maximum: float)

const DURACION_RECARGA_DASH: float = 3.0

var current: float = 1.0
var maximum: float = 1.0
var regeneration: float = 0.0
var regeneration_delay: float = DURACION_RECARGA_DASH
var regeneration_timer: float = DURACION_RECARGA_DASH

func configurar(_maximo: float, actual: float = -1.0) -> void:
	maximum = 1.0
	current = maximum if actual < 0.0 else clampf(actual, 0.0, maximum)
	regeneration_timer = current / maximum * DURACION_RECARGA_DASH
	stamina_changed.emit(current, maximum)

func establecer_maximo(_maximo: float, _conservar_actual: bool = true) -> void:
	# El dash tiene una sola carga: no se acumulan impulsos adicionales.
	maximum = 1.0
	current = clampf(current, 0.0, maximum)
	regeneration_timer = current / maximum * DURACION_RECARGA_DASH
	stamina_changed.emit(current, maximum)

func establecer_actual(actual: float) -> void:
	current = clampf(actual, 0.0, maximum)
	regeneration_timer = current / maximum * DURACION_RECARGA_DASH
	stamina_changed.emit(current, maximum)

func tiene(cantidad: float) -> bool:
	return current >= maxf(cantidad, 0.0)

func gastar(cantidad: float) -> bool:
	var gasto := maxf(cantidad, 0.0)
	if current + 0.0001 < gasto:
		return false
	if gasto <= 0.0:
		return true
	current = maxf(current - gasto, 0.0)
	regeneration_timer = 0.0
	stamina_changed.emit(current, maximum)
	return true

func restaurar(cantidad: float) -> bool:
	var recuperacion := maxf(cantidad, 0.0)
	if recuperacion <= 0.0 or current >= maximum:
		return false
	var anterior := current
	current = minf(current + recuperacion, maximum)
	regeneration_timer = current / maximum * DURACION_RECARGA_DASH
	if not is_equal_approx(current, anterior):
		stamina_changed.emit(current, maximum)
		return true
	return false

func actualizar(delta: float, puede_regenerar: bool) -> void:
	if not puede_regenerar or current >= maximum:
		return
	regeneration_timer = minf(
		regeneration_timer + maxf(delta, 0.0),
		DURACION_RECARGA_DASH
	)
	var nuevo_actual := maximum if regeneration_timer >= DURACION_RECARGA_DASH else minf(
		regeneration_timer / DURACION_RECARGA_DASH * maximum,
		maximum
	)
	var cambio_real := not is_equal_approx(current, nuevo_actual)
	# Asignar siempre el valor calculado: la comparación aproximada no debe
	# dejar la carga en 0.99999 cuando el temporizador ya terminó.
	current = nuevo_actual
	if cambio_real or current >= maximum:
		stamina_changed.emit(current, maximum)

func reiniciar() -> void:
	current = maximum
	regeneration_timer = DURACION_RECARGA_DASH
	stamina_changed.emit(current, maximum)

func establecer_regeneracion(_valor: float, _retraso: float = -1.0) -> void:
	# La recarga del dash siempre dura tres segundos y no admite ajustes externos.
	regeneration = 0.0
	regeneration_delay = DURACION_RECARGA_DASH
