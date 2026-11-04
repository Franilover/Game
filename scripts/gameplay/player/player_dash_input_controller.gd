extends RefCounted
class_name PlayerDashInputController

## Ventana de entrada para distinguir Shift (dash) de Shift+M (viaje).
## No consulta Input ni inicia acciones del jugador.

const VENTANA_DASH: float = 0.12

var pendiente: bool = false
var tiempo_restante: float = 0.0
var cancelado_por_combinacion: bool = false


func solicitar() -> void:
	pendiente = true
	tiempo_restante = VENTANA_DASH
	cancelado_por_combinacion = false


func cancelar_por_menu_reinos() -> void:
	pendiente = false
	tiempo_restante = 0.0
	cancelado_por_combinacion = true


func actualizar(delta: float, tecla_menu_presionada: bool) -> bool:
	if not pendiente:
		return false
	tiempo_restante -= maxf(delta, 0.0)
	if tiempo_restante > 0.0:
		return false

	pendiente = false
	return not cancelado_por_combinacion and not tecla_menu_presionada


func reiniciar() -> void:
	pendiente = false
	tiempo_restante = 0.0
	cancelado_por_combinacion = false
