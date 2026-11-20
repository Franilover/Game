extends Node

const WorldEntityManagerScript = preload("res://scripts/world/world_entity_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var manager: Variant = WorldEntityManagerScript.new()
	var replica_criatura := Node.new()
	var replica_prop := Node.new()

	manager._persistent_by_key = {"personaje:1": replica_criatura}
	manager._global_entities = [replica_criatura]
	manager._active_chunks = {Vector2i.ZERO: true}
	manager._active_creature_chunks = {Vector2i.ZERO: true}
	manager._active_prop_chunks = {Vector2i.ZERO: true}
	manager._replicas_red_by_key = {"zona|criatura": replica_criatura}
	manager._replicas_red_props_by_key = {"zona|prop": replica_prop}
	manager._runtime_state_by_key = {"0:0:criatura": {"health": 10}}
	manager._runtime_prop_state_by_key = {"0:0:prop": {"position": Vector2.ZERO}}
	manager._data_by_chunk = {Vector2i.ZERO: {"criaturas": [{"id": "criatura"}]}}

	manager.limpiar_todo()

	var registros: Array[Dictionary] = [
		manager._persistent_by_key,
		manager._active_chunks,
		manager._active_creature_chunks,
		manager._active_prop_chunks,
		manager._replicas_red_by_key,
		manager._replicas_red_props_by_key,
		manager._runtime_state_by_key,
		manager._runtime_prop_state_by_key,
		manager._data_by_chunk
	]
	for registro in registros:
		if not registro.is_empty():
			errores.append("limpiar_todo dejó un registro interno con datos.")
			break
	if not manager._global_entities.is_empty():
		errores.append("limpiar_todo dejó entidades globales registradas.")

	manager.free()
	await get_tree().process_frame
	replica_prop.free()

	if not errores.is_empty():
		for error in errores:
			push_error("WorldEntityManagerReset: FAIL: " + error)
		get_tree().quit(1)
		return
	print("WorldEntityManagerReset: PASS")
	get_tree().quit(0)
