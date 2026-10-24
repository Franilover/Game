extends SceneTree

const CreatureScript = preload("res://scripts/creatures/creature.gd")
const AIScript = preload("res://scripts/creatures/creature_ai.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor := CreatureScript.new() as Creature
	actor.criatura_id = "target-policy-actor"
	actor.criatura_nombre = "Criatura neutral"
	actor.comportamiento = ""
	actor.datos = {"id": actor.criatura_id, "nombre": actor.criatura_nombre}

	var player := Node2D.new()
	root.add_child(player)

	var ai := AIScript.new() as CreatureAI
	ai.criatura = actor
	ai.jugador = player
	ai.configuracion_ia = {}
	ai.actividad_horaria = "explorar"
	ai.perfil = AIScript.Perfil.GENERICO

	# Un jugador cercano no debe ser un objetivo implícito de una criatura
	# neutral sin una respuesta definida.
	ai._refrescar_objetivo()
	if ai.objetivo != null:
		_fail("Una criatura neutral eligió al jugador sin respuesta definida.")
		return

	# El comportamiento agresivo sí define una reacción ejecutable.
	actor.comportamiento = "agresivo"
	ai._refrescar_objetivo()
	if ai.objetivo != player:
		_fail("Una criatura agresiva no seleccionó al jugador.")
		return
	if ai._obtener_respuesta_a_objetivo() != "perseguir":
		_fail("La conducta agresiva debe traducirse en perseguir.")
		return

	# Lignianos debe fallar de forma segura: si Supabase/snapshot no
	# entrega la clave, la IA no puede interpretar la ausencia como permiso.
	actor.criatura_nombre = "Lignianos"
	actor.comportamiento = ""
	ai.perfil = AIScript.Perfil.LIGNIANOS
	ai.configuracion_ia = {}
	if ai._movimiento_permitido():
		_fail("Lignianos permitió movimiento al faltar ia_config.")
		return

	# Una decisión explícita y válida de la configuración canónica prevalece.
	ai.configuracion_ia = {"movimiento_permitido": true}
	if not ai._movimiento_permitido():
		_fail("La IA ignoró movimiento_permitido=true explícito.")
		return
	ai.configuracion_ia = {"movimiento_permitido": false}
	if ai._movimiento_permitido():
		_fail("La IA ignoró movimiento_permitido=false explícito.")
		return

	ai.configuracion_ia = {}
	ai._refrescar_objetivo()
	if ai.objetivo != null:
		_fail("Lignianos reaccionó al jugador sin la marca de asesino.")
		return

	player.set_meta("garlia_bosque_asesino", true)
	ai._refrescar_objetivo()
	if ai.objetivo != player:
		_fail("Lignianos no detectó al jugador marcado como asesino.")
		return
	if ai._obtener_respuesta_a_objetivo() != "atacar":
		_fail("La respuesta al asesino del bosque debe ser atacar.")
		return

	# Una política explícita de inmovilidad también debe respetarse en
	# perfiles genéricos, sin alterar su comportamiento cuando falta la clave.
	ai.perfil = AIScript.Perfil.GENERICO
	ai.configuracion_ia = {"movimiento_permitido": false}
	if ai._movimiento_permitido():
		_fail("La política explícita de inmovilidad no se aplicó al perfil genérico.")
		return
	ai.configuracion_ia = {}
	if not ai._movimiento_permitido():
		_fail("El perfil genérico perdió el comportamiento compatible por defecto.")
		return

	# Los ataques de contacto deben acercarse antes de iniciar el golpe.
	player.remove_meta("garlia_bosque_asesino")
	actor.criatura_nombre = "Depredador de prueba"
	actor.comportamiento = ""
	ai.perfil = AIScript.Perfil.GENERICO
	player.position = Vector2(140.0, 0.0)
	ai.objetivo = player
	ai._cambiar_a_respuesta_atacar()
	if ai.estado != AIScript.Estado.PERSIGUIENDO:
		_fail("Un ataque genérico fuera de alcance debe pasar a persecución.")
		return

	# GENÉRICO, GUARDIAN y CAZADOR ya tienen un manejador de contacto;
	# entrar en ATACANDO no debe enviarlos directamente a RECUPERANDO.
	for perfil_prueba in [
		AIScript.Perfil.GENERICO,
		AIScript.Perfil.GUARDIAN,
		AIScript.Perfil.CAZADOR
	]:
		ai.perfil = perfil_prueba
		ai._cambiar_estado(AIScript.Estado.ATACANDO)
		if ai.estado != AIScript.Estado.ATACANDO:
			_fail("Un perfil con ataque de contacto saltó a recuperación al entrar.")
			return
		ai._procesar_atacando(0.016)
		if ai.estado != AIScript.Estado.ATACANDO:
			_fail("Un perfil con ataque de contacto no mantuvo la aproximación.")
			return
		ai._cambiar_estado(AIScript.Estado.RECUPERANDO)

	print("CreatureAITargetPolicy: pruebas de selección y contacto completadas.")
	root.remove_child(player)
	player.free()
	actor.free()
	ai.free()
	quit(0)


func _fail(message: String) -> void:
	push_error("CreatureAITargetPolicy: " + message)
	quit(1)
