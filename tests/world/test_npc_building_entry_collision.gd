extends Node

const NPCScheduleScript = preload("res://scripts/world/npc_schedule_system.gd")
const ReinoTorresScript = preload("res://scripts/world/reino_torres.gd")
const CreatureScript = preload("res://scripts/creatures/creature.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var zona := ReinoTorresScript.new() as Node2D
	var sistema := NPCScheduleScript.new() as NPCScheduleSystem
	sistema._zona = zona
	var npc := CreatureScript.new() as Creature
	npc.collision_layer = 4
	npc.collision_mask = 6
	add_child(npc)
	await get_tree().process_frame

	sistema._marcar_npc_dentro_edificio(npc, "panaderia")
	if npc.collision_layer != 0 or npc.collision_mask != 0:
		errores.append("Un NPC oculto dentro del edificio conserva colisión en el exterior.")
	if npc.visible or not bool(npc.get_meta("rutina_en_edificio", false)):
		errores.append("El NPC no quedó marcado como dentro del edificio.")

	# La captura original debe sobrevivir a llamadas repetidas y restaurarse
	# al abandonar el edificio.
	npc.collision_layer = 16
	zona.call("desactivar_colision_npc_exterior", npc)
	zona.call("restaurar_colision_npc", npc)
	if npc.collision_layer != 4 or npc.collision_mask != 6:
		errores.append("La restauración no recuperó las capas/máscaras originales.")

	var forma := CollisionShape2D.new()
	forma.shape = CircleShape2D.new()
	npc.add_child(forma)
	zona.set("_estados_colision_exterior", {forma.get_instance_id(): false})
	forma.disabled = true
	zona.call("_restaurar_formas_colision_npc", npc)
	await get_tree().process_frame
	if forma.disabled:
		errores.append("El NPC no recuperó su forma de colisión al entrar al interior.")

	npc.queue_free()
	zona.free()
	sistema.free()
	await get_tree().process_frame
	if not errores.is_empty():
		for error in errores:
			push_error("NPCBuildingEntryCollision: FAIL: " + error)
		get_tree().quit(1)
		return
	print("NPCBuildingEntryCollision: PASS")
	get_tree().quit(0)
