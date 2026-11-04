extends SceneTree

const MovementScript = preload("res://scripts/gameplay/player/player_movement_controller.gd")
const CoordinatorScript = preload("res://scripts/gameplay/player/player_locomotion_coordinator.gd")
const ActionScript = preload("res://scripts/gameplay/player/player_action_controller.gd")
const StaminaScript = preload("res://scripts/gameplay/player/player_stamina_controller.gd")
const VisualScript = preload("res://scripts/characters/player_visual_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	_probar_intensidad_analogica(errores)
	_probar_limite_direccion_y_estado(errores)
	_probar_coordinador(errores)
	_probar_presentacion_visual(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("PlayerLocomotion: FAIL: " + error)
		quit(1)
		return

	print("PlayerLocomotion: PASS")
	quit(0)


func _probar_intensidad_analogica(errores: Array[String]) -> void:
	var movement = MovementScript.new()
	var velocidad: Vector2 = movement.actualizar(Vector2(0.5, 0.0), 90.0, 1.0, false)
	if not velocidad.is_equal_approx(Vector2(45.0, 0.0)):
		errores.append("La entrada analógica al 50 % no conservó la mitad de velocidad.")
	if movement.state != MovementScript.State.WALK:
		errores.append("Una entrada no nula no produjo estado WALK.")

	# La ausencia de input no debe borrar la última orientación.
	movement.actualizar(Vector2.ZERO, 90.0, 1.0, false)
	if not movement.facing.is_equal_approx(Vector2.RIGHT):
		errores.append("El jugador perdió su orientación al dejar de moverse.")
	if movement.state != MovementScript.State.IDLE:
		errores.append("La ausencia de input no produjo estado IDLE.")


func _probar_limite_direccion_y_estado(errores: Array[String]) -> void:
	var movement = MovementScript.new()
	var velocidad: Vector2 = movement.actualizar(Vector2(1.0, 1.0), 90.0, 1.0, false)
	if not is_equal_approx(velocidad.length(), 90.0):
		errores.append("La dirección diagonal superó la velocidad máxima.")
	if not movement.facing.is_equal_approx(Vector2(1.0, 1.0).normalized()):
		errores.append("La orientación diagonal no se normalizó.")

	velocidad = movement.actualizar(Vector2(0.5, 0.0), 90.0, 1.5, true)
	if not velocidad.is_equal_approx(Vector2(67.5, 0.0)):
		errores.append("El multiplicador de carrera no se aplicó a la intensidad analógica.")
	if movement.state != MovementScript.State.RUN:
		errores.append("El multiplicador de carrera no produjo estado RUN.")

	# El sprint de Eterium puede aumentar velocidad sin cambiar el estado WALK.
	velocidad = movement.actualizar(Vector2.RIGHT, 90.0, 2.0, false)
	if not velocidad.is_equal_approx(Vector2(180.0, 0.0)):
		errores.append("El multiplicador adicional de velocidad no se aplicó.")
	if movement.state != MovementScript.State.WALK:
		errores.append("Un multiplicador adicional alteró el estado visual WALK.")


func _probar_coordinador(errores: Array[String]) -> void:
	var movement = MovementScript.new()
	var coordinator = CoordinatorScript.new()
	coordinator.configurar(movement, ActionScript.new(), StaminaScript.new())

	var velocidad: Vector2 = coordinator.calcular_movimiento(
		Vector2(0.25, 0.0),
		100.0,
		2.0,
		false
	)
	if not velocidad.is_equal_approx(Vector2(50.0, 0.0)):
		errores.append("El coordinador no delegó el cálculo de velocidad.")
	if not coordinator.actualizar_facing(Vector2.UP):
		errores.append("El coordinador no comunicó el cambio de orientación.")
	if not coordinator.obtener_facing().is_equal_approx(Vector2.UP):
		errores.append("El coordinador devolvió una orientación incorrecta.")

 
func _probar_presentacion_visual(errores: Array[String]) -> void:
	var visual = VisualScript.new()
	if visual.obtener_nombre_animacion(0, Vector2.DOWN) != "idle_down":
		errores.append("La presentación no construyó idle_down.")
	if visual.obtener_nombre_animacion(1, Vector2.UP) != "walk_up":
		errores.append("La presentación no construyó walk_up.")
	if visual.obtener_nombre_animacion(2, Vector2.RIGHT) != "run_side":
		errores.append("La presentación no construyó run_side.")
	if visual.obtener_nombre_animacion(3, Vector2.LEFT) != "jump_side":
		errores.append("La presentación no construyó jump_side.")
	if visual.obtener_nombre_animacion(4, Vector2.DOWN) != "dash_down":
		errores.append("La presentación no construyó dash_down.")

	var marcador := ColorRect.new()
	visual.configurar(Node2D.new(), marcador, null)
	visual.actualizar_direccion(Vector2.RIGHT)
	if not marcador.position.is_equal_approx(Vector2(12.0, -26.0)):
		errores.append("El marcador visual no conservó el desplazamiento lateral.")
	visual.actualizar_direccion(Vector2.ZERO)
	if not marcador.position.is_equal_approx(Vector2(-2.0, -12.0)):
		errores.append("El marcador visual no usó DOWN como orientación de reserva.")
