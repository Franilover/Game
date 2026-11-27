extends Node

const MovementScript = preload("res://scripts/gameplay/player/player_movement_controller.gd")
const CoordinatorScript = preload("res://scripts/gameplay/player/player_locomotion_coordinator.gd")
const ActionScript = preload("res://scripts/gameplay/player/player_action_controller.gd")
const StaminaScript = preload("res://scripts/gameplay/player/player_stamina_controller.gd")
const VisualScript = preload("res://scripts/characters/player_visual_controller.gd")
const EquipmentAnimationScript = preload("res://scripts/characters/player_equipment_animation_controller.gd")
const CharacterAppearanceScript = preload("res://scripts/characters/character_appearance.gd")
const SpriteAnimationScript = preload("res://scripts/shared/animation/shared_sprite_animation_controller.gd")
const InputScript = preload("res://scripts/gameplay/player/player_input_controller.gd")
const PhysicsScript = preload("res://scripts/gameplay/player/player_movement_physics_controller.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	_probar_intensidad_analogica(errores)
	_probar_politica_multiplicador_velocidad(errores)
	_probar_limite_direccion_y_estado(errores)
	_probar_coordinador(errores)
	_probar_recarga_dash_reutilizable(errores)
	_probar_presentacion_visual(errores)
	_probar_animador_spritesheet(errores)
	_probar_perfiles_animacion_equipo(errores)
	_probar_adaptador_input(errores)
	_probar_integracion_fisica(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("PlayerLocomotion: FAIL: " + error)
		get_tree().quit(1)
		return

	print("PlayerLocomotion: PASS")
	get_tree().quit(0)


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


func _probar_politica_multiplicador_velocidad(errores: Array[String]) -> void:
	var movement = MovementScript.new()
	if not is_equal_approx(movement.calcular_multiplicador_velocidad(1.5, false, false, 2.0), 1.0):
		errores.append("Caminar alteró el multiplicador base.")
	if not is_equal_approx(movement.calcular_multiplicador_velocidad(1.5, true, false, 2.0), 1.5):
		errores.append("Correr no aplicó el multiplicador común.")
	if not is_equal_approx(movement.calcular_multiplicador_velocidad(1.5, false, true, 1.8), 2.7):
		errores.append("El sprint de Eterium no combinó ambos multiplicadores.")
	# El sprint tiene prioridad sobre el estado de carrera normal.
	if not is_equal_approx(movement.calcular_multiplicador_velocidad(1.5, true, true, 1.8), 2.7):
		errores.append("La política de sprint cambió cuando correr también estaba solicitado.")


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

 


func _probar_recarga_dash_reutilizable(errores: Array[String]) -> void:
	var stamina = StaminaScript.new()
	stamina.configurar(1.0)
	var actions = ActionScript.new()
	var coordinator = CoordinatorScript.new()
	coordinator.configurar(MovementScript.new(), actions, stamina)

	if not coordinator.iniciar_dash(Vector2.RIGHT, 0.12, 0.8, 1.0):
		errores.append("El primer dash de prueba no pudo iniciarse.")
		return
	coordinator.avanzar_accion(0.12)
	coordinator.actualizar_cooldowns(3.0)

	# Reproduce el último microinstante de recarga, donde una comparación
	# aproximada podía conservar 0.99999 y bloquear el siguiente dash.
	stamina.current = 0.999999
	stamina.regeneration_timer = 3.0 - 0.000001
	stamina.actualizar(0.000001, true)
	if stamina.current != stamina.maximum:
		errores.append("La recarga terminó sin fijar la carga exactamente al 100 %.")
	if not coordinator.iniciar_dash(Vector2.RIGHT, 0.12, 0.8, 1.0):
		errores.append("El segundo dash no pudo iniciarse después de completar la recarga.")


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

	var raiz_visual := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	raiz_visual.add_child(sprite)
	var marcador := ColorRect.new()
	visual.configurar(raiz_visual, marcador, null)
	if visual.sprite == null:
		errores.append("El controlador visual no encontró el nodo Sprite2D.")
	if visual.sprite_idle == null or visual.sprite_walk_left == null or visual.sprite_walk_back == null:
		errores.append("El controlador visual no cargó todas las texturas importadas.")
	visual.actualizar_direccion(Vector2.RIGHT)
	if not marcador.position.is_equal_approx(Vector2(12.0, -26.0)):
		errores.append("El marcador visual no conservó el desplazamiento lateral.")
	visual.actualizar_direccion(Vector2.ZERO)
	if not marcador.position.is_equal_approx(Vector2(-2.0, -12.0)):
		errores.append("El marcador visual no usó DOWN como orientación de reserva.")

	# Los sprites nuevos se aplican a WALK y RUN sin depender de AnimationPlayer.
	visual.actualizar_estado(1, Vector2.LEFT)
	if not _textura_coincide_con_archivo(sprite.texture, "walk_left") or sprite.flip_h:
		errores.append("Caminar hacia la izquierda no usó la nueva pose lateral.")
	visual.actualizar_estado(2, Vector2.RIGHT)
	if not _textura_coincide_con_archivo(sprite.texture, "res://assets/art/characters/Sprite-0004_Walking_Left.png") or not sprite.flip_h:
		errores.append("Correr hacia la derecha no reflejó la pose lateral.")
	visual.actualizar_estado(1, Vector2.UP)
	if not _textura_coincide_con_archivo(sprite.texture, "walk_back") or sprite.flip_h:
		errores.append("Caminar hacia arriba no usó la pose de espalda.")
	visual.actualizar_estado(2, Vector2.DOWN)
	if not _textura_coincide_con_archivo(sprite.texture, "idle_front") or sprite.flip_h:
		errores.append("Caminar hacia abajo no conservó la skin frontal base.")
	visual.actualizar_estado(0, Vector2.LEFT)
	if not _textura_coincide_con_archivo(sprite.texture, "res://assets/art/characters/Sprite-0004.png") or sprite.flip_h:
		errores.append("Al detenerse no se restauró la skin base.")
	raiz_visual.free()
	marcador.free()

 
func _probar_perfiles_animacion_equipo(errores: Array[String]) -> void:
	var espada := {"nombre": "Espada de prueba", "tipo": "arma"}
	if EquipmentAnimationScript.obtener_tipo_animacion(espada) != "espada":
		errores.append("La espada no seleccionó su perfil de barrido.")
	var hacha := {
		"nombre": "Herramienta",
		"tipo": "herramienta",
		"propiedades_game": {"herramienta_recoleccion": {"tipo": "hacha", "nivel": 1}}
	}
	if EquipmentAnimationScript.obtener_tipo_animacion(hacha) != "hacha":
		errores.append("El hacha no seleccionó su perfil desde propiedades_game.")
	var regadera := {"nombre": "Regadera", "tipo": "herramienta"}
	if EquipmentAnimationScript.obtener_tipo_animacion(regadera) != "regadera":
		errores.append("La regadera no seleccionó su perfil de uso.")
	var perfil_espada := EquipmentAnimationScript.obtener_perfil(espada)
	var perfil_hacha := EquipmentAnimationScript.obtener_perfil(hacha)
	var perfil_pala := EquipmentAnimationScript.obtener_perfil({"nombre": "Pala de Madera"})
	if float(perfil_espada.get("duracion", 0.0)) >= float(perfil_hacha.get("duracion", 0.0)):
		errores.append("La espada y el hacha no conservan ritmos de animación distintos.")
	if float(perfil_pala.get("duracion", 0.0)) < 0.60:
		errores.append("La pala sigue teniendo una animación demasiado breve.")
	for tipo in ["espada", "hacha", "pico", "pala", "azada", "regadera"]:
		if EquipmentAnimationScript.obtener_textura_respaldo(tipo) == null:
			errores.append("Falta el sprite de respaldo para la animación de " + tipo + ".")
	if EquipmentAnimationScript.obtener_tipo_animacion({"nombre": "Objeto"}) != "generica":
		errores.append("Un objeto sin clasificación no recibió el perfil genérico.")


func _probar_adaptador_input(errores: Array[String]) -> void:
	var input_controller = InputScript.new()
	var evento_viaje := InputEventKey.new()
	evento_viaje.keycode = KEY_M
	evento_viaje.ctrl_pressed = true
	evento_viaje.pressed = true
	if not input_controller.es_combinacion_viaje(evento_viaje):
		errores.append("El adaptador no reconoció Ctrl+M.")
	evento_viaje.echo = true
	if input_controller.es_combinacion_viaje(evento_viaje):
		errores.append("El adaptador trató una repetición como una nueva combinación.")
	var evento_shift := InputEventKey.new()
	evento_shift.keycode = KEY_M
	evento_shift.shift_pressed = true
	evento_shift.pressed = true
	if input_controller.es_combinacion_viaje(evento_shift):
		errores.append("El adaptador reconoció Shift+M como viaje.")
	var evento_ajeno := InputEventKey.new()
	evento_ajeno.keycode = KEY_M
	evento_ajeno.pressed = true
	if input_controller.es_combinacion_viaje(evento_ajeno):
		errores.append("El adaptador reconoció M sin Ctrl como viaje.")
	if input_controller.es_combinacion_viaje(InputEventMouseButton.new()):
		errores.append("El adaptador reconoció un evento de ratón como combinación de teclado.")

func _probar_integracion_fisica(errores: Array[String]) -> void:
	var physics_controller = PhysicsScript.new()
	var cuerpo := CharacterBody2D.new()
	var velocidad := Vector2(45.0, -30.0)
	physics_controller.establecer_velocidad(cuerpo, velocidad)
	if not cuerpo.velocity.is_equal_approx(velocidad):
		errores.append("El controlador físico no asignó la velocidad calculada al cuerpo.")
	physics_controller.establecer_velocidad(cuerpo, Vector2.ZERO)
	if not cuerpo.velocity.is_zero_approx():
		errores.append("El controlador físico no pudo detener el cuerpo.")
	physics_controller.establecer_velocidad(null, velocidad)
	physics_controller.aplicar_desplazamiento(null)
	cuerpo.free()


func _probar_animador_spritesheet(errores: Array[String]) -> void:
	var sprite := Sprite2D.new()
	sprite.hframes = 4
	var animator: SharedSpriteAnimationController = SpriteAnimationScript.new()
	animator.configurar(sprite)
	animator.reproducir(4.0, 0, 4, true)
	animator.actualizar(0.26)
	if sprite.frame != 1:
		errores.append("El animador compartido no avanzó el spritesheet según sus FPS.")

	animator.reproducir(10.0, 0, 2, false)
	animator.actualizar(0.25)
	if animator.reproduciendo or sprite.frame != 1:
		errores.append("El animador compartido no finalizó una secuencia sin bucle.")
	sprite.free()


func _textura_coincide_con_archivo(textura: Texture2D, clave: String) -> bool:
	if textura == null:
		return false
	var esperada := CharacterAppearanceScript.obtener_textura_sprite(clave)
	return esperada != null and textura == esperada
