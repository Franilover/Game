extends Node

const WorldEntityManagerScript = preload("res://scripts/world/world_entity_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var manager: Node = WorldEntityManagerScript.new()
	var replica_criatura := Node.new()
	var replica_prop := Node.new()
	var replica_conservada := Node.new()

	manager._replicas_red_by_key = {
		"zona_a|criatura_1": replica_criatura,
		"zona_a|criatura_2": replica_conservada
	}
	manager._replicas_red_props_by_key = {
		"zona_a|prop_1": replica_prop,
		"zona_a|prop_2": replica_conservada
	}
	manager._al_salir_entidad(replica_criatura)
	manager._al_salir_entidad(replica_prop)

	if manager._replicas_red_by_key.has("zona_a|criatura_1"):
		errores.append("La salida de una criatura dejó una referencia de réplica registrada.")
	if manager._replicas_red_props_by_key.has("zona_a|prop_1"):
		errores.append("La salida de un prop dejó una referencia de réplica registrada.")
	if manager._replicas_red_by_key.get("zona_a|criatura_2") != replica_conservada:
		errores.append("La limpieza de criatura eliminó una réplica ajena.")
	if manager._replicas_red_props_by_key.get("zona_a|prop_2") != replica_conservada:
		errores.append("La limpieza de prop eliminó una réplica ajena.")

	manager.free()
	replica_criatura.free()
	replica_prop.free()
	replica_conservada.free()

	if not errores.is_empty():
		for error in errores:
			push_error("WorldEntityReplicaRegistry: FAIL: " + error)
		get_tree().quit(1)
		return
	print("WorldEntityReplicaRegistry: PASS")
	get_tree().quit(0)
