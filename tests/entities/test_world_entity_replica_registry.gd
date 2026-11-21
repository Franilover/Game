extends Node

const WorldEntityManagerScript = preload("res://scripts/world/world_entity_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var manager: Variant = WorldEntityManagerScript.new()
	var replica_criatura := Node.new()
	var replica_prop := Node.new()
	var replica_conservada := Node.new()

	# Una entidad puede estar asociada a más de una clave de red.
	manager._registrar_clave_replica(
		manager._replicas_red_by_key, manager._replica_keys_by_entity,
		replica_criatura, "zona_a|criatura_1"
	)
	manager._registrar_clave_replica(
		manager._replicas_red_by_key, manager._replica_keys_by_entity,
		replica_criatura, "zona_a|criatura_1_alias"
	)
	manager._registrar_clave_replica(
		manager._replicas_red_by_key, manager._replica_keys_by_entity,
		replica_conservada, "zona_a|criatura_2"
	)
	manager._registrar_clave_replica(
		manager._replicas_red_props_by_key, manager._replica_prop_keys_by_entity,
		replica_prop, "zona_a|prop_1"
	)
	manager._registrar_clave_replica(
		manager._replicas_red_props_by_key, manager._replica_prop_keys_by_entity,
		replica_prop, "zona_a|prop_1_alias"
	)
	manager._registrar_clave_replica(
		manager._replicas_red_props_by_key, manager._replica_prop_keys_by_entity,
		replica_conservada, "zona_a|prop_2"
	)

	manager._al_salir_entidad(replica_criatura)
	manager._al_salir_entidad(replica_prop)

	for clave in ["zona_a|criatura_1", "zona_a|criatura_1_alias"]:
		if manager._replicas_red_by_key.has(clave):
			errores.append("La salida de una criatura dejó una clave de réplica registrada: " + clave)
	for clave in ["zona_a|prop_1", "zona_a|prop_1_alias"]:
		if manager._replicas_red_props_by_key.has(clave):
			errores.append("La salida de un prop dejó una clave de réplica registrada: " + clave)

	if manager._replicas_red_by_key.get("zona_a|criatura_2") != replica_conservada:
		errores.append("La limpieza de criatura eliminó una réplica ajena.")
	if manager._replicas_red_props_by_key.get("zona_a|prop_2") != replica_conservada:
		errores.append("La limpieza de prop eliminó una réplica ajena.")
	if manager._replica_keys_by_entity.has(replica_criatura):
		errores.append("El índice inverso de criatura conservó la entidad descargada.")
	if manager._replica_prop_keys_by_entity.has(replica_prop):
		errores.append("El índice inverso de props conservó la entidad descargada.")

	# Reasignar una clave debe retirar su índice de la entidad anterior.
	manager._registrar_clave_replica(
		manager._replicas_red_by_key, manager._replica_keys_by_entity,
		replica_criatura, "zona_a|clave_reasignada"
	)
	manager._registrar_clave_replica(
		manager._replicas_red_by_key, manager._replica_keys_by_entity,
		replica_conservada, "zona_a|clave_reasignada"
	)
	if manager._replica_keys_by_entity.has(replica_criatura):
		errores.append("La reasignación de clave dejó un índice inverso obsoleto.")

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
