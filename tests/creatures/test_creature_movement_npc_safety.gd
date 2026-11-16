extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var npc_a := CreatureScene.instantiate() as Creature
	var npc_b := CreatureScene.instantiate() as Creature
	if npc_a == null or npc_b == null:
		_fail(["No se pudieron crear los NPC de prueba."])
		return

	npc_a.position = Vector2.ZERO
	npc_b.position = Vector2(18.0, 0.0)
	get_tree().root.add_child(npc_a)
	get_tree().root.add_child(npc_b)
	npc_a.add_to_group("torres_game_npc")
	npc_b.add_to_group("torres_game_npc")
	await get_tree().process_frame

	var movimiento := npc_a.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		_fail(["El NPC no contiene CreatureMovement."])
		return

	var direccion := movimiento._direccion_evitar_superposicion_npcs(Vector2.RIGHT)
	if absf(direccion.y) < 0.2:
		errores.append("Un NPC que encuentra a otro delante no cede lateralmente.")

	movimiento._ultima_posicion_seguro = npc_a.global_position
	movimiento._tiempo_sin_progreso = 0.0
	var direccion_recuperacion := Vector2.RIGHT
	for _i in range(10):
		direccion_recuperacion = movimiento._aplicar_seguro_atasco_npc(Vector2.RIGHT, 0.1)
	if absf(direccion_recuperacion.y) <= absf(direccion_recuperacion.x):
		errores.append("El seguro de atasco no activa un rodeo lateral tras perder progreso.")

	npc_a.remove_from_group("torres_game_npc")
	npc_b.remove_from_group("torres_game_npc")
	npc_a.queue_free()
	npc_b.queue_free()
	await get_tree().process_frame

	if not errores.is_empty():
		_fail(errores)
		return

	print("CreatureMovementNPCSafety: PASS")
	get_tree().quit(0)


func _fail(errores: Array[String]) -> void:
	for error in errores:
		push_error("CreatureMovementNPCSafety: FAIL: " + error)
	get_tree().quit(1)
