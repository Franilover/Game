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

	# La regla especial del bosque no puede ser anulada por el fallback
	# agresivo del perfil: Lignianos ignora al jugador sin marca de asesino.
	actor.criatura_nombre = "Lignianos"
	actor.comportamiento = ""
	ai.perfil = AIScript.Perfil.LIGNIANOS
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

	print("CreatureAITargetPolicy: pruebas de selección completadas.")
	root.remove_child(player)
	player.free()
	actor.free()
	ai.free()
	quit(0)


func _fail(message: String) -> void:
	push_error("CreatureAITargetPolicy: " + message)
	quit(1)
