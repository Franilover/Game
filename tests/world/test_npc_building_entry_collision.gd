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

	# Simula el traslado del NPC desde una habitación al contenedor exterior
	# cuando su horario cambia de edificio.
	var contenedor_exterior := Node2D.new()
	var capa_interior := Node2D.new()
	var habitacion := Node2D.new()
	zona.add_child(contenedor_exterior)
	zona.add_child(capa_interior)
	capa_interior.add_child(habitacion)
	zona.set("_contenedor_npcs_exterior", contenedor_exterior)
	zona.set("_capa_interior", capa_interior)
	npc.set_meta("rutina_edificio_id", "panaderia")
	npc.reparent(habitacion, true)
	npc.add_to_group("interactable")
	zona.call("sacar_npc_del_interior", npc)
	if npc.get_parent() != contenedor_exterior:
		errores.append("El NPC no regresó al contenedor exterior al cambiar de edificio.")
	if npc.visible or npc.is_in_group("interactable"):
		errores.append("El NPC quedó visible o interactuable antes de reanudar su ruta.")
	if npc.collision_layer != 0 or npc.collision_mask != 0:
		errores.append("El NPC recuperó colisiones exteriores antes de salir del interior.")

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
