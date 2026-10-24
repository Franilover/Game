extends Node

const StaminaControllerScript = preload("res://scripts/gameplay/player/player_stamina_controller.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller := StaminaControllerScript.new() as PlayerStaminaController
	controller.configurar(5.0)
	if controller.maximum != 5.0 or controller.current != 5.0:
		_fail("La reserva de dash debe iniciar con cinco cargas.")
		return

	for _i in range(5):
		if not controller.gastar(1.0):
			_fail("No se pudo gastar una de las cinco cargas.")
			return

	if controller.current != 0.0:
		_fail("Cinco dashes deben consumir exactamente las cinco cargas.")
		return
	if controller.gastar(1.0):
		_fail("Se permitió gastar una sexta carga sin recuperarla.")
		return

	if not controller.restaurar(5.0):
		_fail("No se pudieron restaurar las cinco cargas.")
		return
	if controller.current != 5.0:
		_fail("La restauración no recuperó las cinco cargas.")
		return

	controller.establecer_maximo(8.0)
	if controller.maximum != 5.0:
		_fail("El máximo debe permanecer en cinco cargas.")
		return

	print("PlayerDashCharges: PASS - máximo y recuperación de cinco cargas.")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("PlayerDashCharges: FAIL: " + message)
	get_tree().quit(1)
