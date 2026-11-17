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

	# Layout adaptable: ningún botón puede salir del viewport ni cubrir a otro.
	var tamanos := [Vector2(360.0, 640.0), Vector2(640.0, 360.0), Vector2(320.0, 240.0), Vector2(480.0, 800.0)]
	var rutas_botones := [
		"Actions/Inventory", "Actions/Map", "Actions/Missions", "Actions/Pause",
		"Actions/Garumis", "Actions/Garumi1", "Actions/Garumi2", "Actions/Garumi3",
		"Actions/Primary", "Actions/Secondary", "Actions/Interact", "Actions/Dash",
		"Actions/Jump", "Actions/Meditate"
	]
	for tamano_viewport in tamanos:
		var layout := controles._calcular_layout_movil(tamano_viewport)
		for ruta in rutas_botones:
			var rect: Rect2 = layout.get(ruta, Rect2())
			if rect.position.x < -0.1 or rect.position.y < -0.1 or rect.end.x > tamano_viewport.x + 0.1 or rect.end.y > tamano_viewport.y + 0.1:
				errores.append("El botón %s se sale del viewport %s." % [ruta, tamano_viewport])
		for i in range(rutas_botones.size()):
			var rect_a: Rect2 = layout[rutas_botones[i]]
			for j in range(i + 1, rutas_botones.size()):
				var rect_b: Rect2 = layout[rutas_botones[j]]
				if rect_a.intersects(rect_b):
					errores.append("Los botones %s y %s se superponen en %s." % [rutas_botones[i], rutas_botones[j], tamano_viewport])
	if not controles._botones.has("dash") or controles._botones.has("run"):
		errores.append("El botón Dash no está conectado a la acción InputMap 'dash'.")
	if InputMap.has_action("dash") and controles._botones.has("dash"):
		controles._presionar_accion("dash")
		if not controles._acciones_presionadas.has("dash"):
			errores.append("El botón Dash no registra el estado presionado.")
		controles._soltar_accion("dash")
	if ResourceLoader.exists("res://assets/art/UI/Menus/button_pressed.png"):
		var boton_dash := controles.get_node("Actions/Dash") as Button
		var estilo_presionado := boton_dash.get_theme_stylebox("pressed")
		if not estilo_presionado is StyleBoxTexture:
			errores.append("El botón Dash no utiliza el sprite de estado presionado.")

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
