extends Node

const MobileControlsScene = preload("res://scenes/ui/mobile_controls.tscn")


class MockDialogue extends Node:
	var abierto: bool = true

	func esta_abierto() -> bool:
		return abierto


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var controles := MobileControlsScene.instantiate() as GarliaMobileControls
	controles.solo_dispositivos_moviles = false
	add_child(controles)
	var dialogo := MockDialogue.new()
	dialogo.add_to_group("dialogue_system")
	add_child(dialogo)
	await get_tree().process_frame

	var base := controles.get_node("Movement/JoystickBase") as Control
	var centro := base.get_global_rect().get_center()
	var toque := InputEventScreenTouch.new()
	toque.position = centro
	toque.index = 7
	toque.pressed = true

	controles._input(toque)
	if controles._joystick_touch_index != -1:
		errores.append("El joystick capturó un toque mientras el diálogo estaba abierto.")

	dialogo.abierto = false
	toque.position = centro + Vector2(30.0, 0.0)
	controles._input(toque)
	if controles._joystick_touch_index != 7:
		errores.append("El joystick no capturó el primer dedo cuando el diálogo estaba cerrado.")

	dialogo.abierto = true
	var arrastre_durante_dialogo := InputEventScreenDrag.new()
	arrastre_durante_dialogo.index = 7
	arrastre_durante_dialogo.position = centro + Vector2(70.0, 0.0)
	controles._input(arrastre_durante_dialogo)
	if controles._joystick_touch_index != -1 or controles._joystick_vector != Vector2.ZERO:
		errores.append("El joystick no liberó el movimiento al abrirse un diálogo.")

	dialogo.abierto = false
	var toque_principal := InputEventScreenTouch.new()
	toque_principal.position = centro + Vector2(30.0, 0.0)
	toque_principal.index = 11
	toque_principal.pressed = true
	controles._input(toque_principal)
	var vector_inicial: Vector2 = controles._joystick_vector

	var toque_secundario := InputEventScreenTouch.new()
	toque_secundario.position = centro + Vector2(50.0, 0.0)
	toque_secundario.index = 12
	toque_secundario.pressed = true
	controles._input(toque_secundario)
	var arrastre_secundario := InputEventScreenDrag.new()
	arrastre_secundario.index = 12
	arrastre_secundario.position = centro + Vector2(0.0, 60.0)
	controles._input(arrastre_secundario)
	if controles._joystick_touch_index != 11 or controles._joystick_vector != vector_inicial:
		errores.append("Un segundo dedo desplazó o robó el joystick.")

	var soltar_secundario := InputEventScreenTouch.new()
	soltar_secundario.index = 12
	soltar_secundario.pressed = false
	controles._input(soltar_secundario)
	if controles._joystick_touch_index != 11:
		errores.append("Soltar el segundo dedo liberó el joystick del dedo principal.")

	var soltar_principal := InputEventScreenTouch.new()
	soltar_principal.index = 11
	soltar_principal.pressed = false
	controles._input(soltar_principal)
	if controles._joystick_touch_index != -1 or controles._joystick_vector != Vector2.ZERO:
		errores.append("El joystick no volvió a reposo al soltar el dedo principal.")

	controles.queue_free()
	dialogo.queue_free()
	await get_tree().process_frame
	if not errores.is_empty():
		for error in errores:
			push_error("MobileControlsDialogueTouch: FAIL: " + error)
		get_tree().quit(1)
		return
	print("MobileControlsDialogueTouch: PASS")
	get_tree().quit(0)
