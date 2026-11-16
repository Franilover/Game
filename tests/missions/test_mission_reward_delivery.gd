extends Node

const MissionManagerScript = preload("res://scripts/gameplay/mission_manager.gd")
const InventoryScene = preload("res://scenes/ui/inventory.tscn")
const WorldItemsScript = preload("res://scripts/infrastructure/garlia_world_items.gd")
const WorldDataScript = preload("res://scripts/world/world_data.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	await _probar_rollback_sin_reintento_recursivo(errores)
	await _probar_entrega_idempotente(errores)
	_probar_resolucion_item_canonico(errores)
	if not errores.is_empty():
		for error in errores:
			push_error("MissionRewardDelivery: FAIL: " + error)
		get_tree().quit(1)
		return
	print("MissionRewardDelivery: PASS")
	get_tree().quit(0)


func _crear_inventario(capacidad: int) -> GarliaInventory:
	var inventario := InventoryScene.instantiate() as GarliaInventory
	inventario.slot_count = capacidad
	add_child(inventario)
	return inventario


func _crear_gestor(recompensas: Array) -> MissionManagerService:
	var gestor := MissionManagerScript.new() as MissionManagerService
	add_child(gestor)
	var mision := {
		"id": "mision_recompensa_test",
		"nombre": "Recompensa de prueba",
		"objetivos": [],
		"recompensas": recompensas.duplicate(true)
	}
	gestor._misiones = [mision]
	gestor._misiones_por_id = {"mision_recompensa_test": mision.duplicate(true)}
	gestor._estado = {"mision_recompensa_test": "completada"}
	return gestor


func _recompensa(item_id: String, nombre: String) -> Dictionary:
	return {
		"tipo": "item",
		"cantidad": 1,
		"datos": {
			"item_data": {
				"id": item_id,
				"item_id": item_id,
				"nombre": nombre,
				"tipo": "recurso",
				"max_stack": 1
			}
		}
	}


func _probar_rollback_sin_reintento_recursivo(errores: Array[String]) -> void:
	var inventario := _crear_inventario(1)
	var gestor := _crear_gestor([
		_recompensa("manzana_test", "Manzana"),
		_recompensa("pala_test", "Pala de Madera")
	])
	await get_tree().process_frame

	var reintentos_externos := 0
	inventario.inventory_changed.connect(func() -> void:
		# Replica el consumidor de Main: solo programa un reintento cuando el
		# cambio viene de una acción real, no del rollback de la entrega actual.
		if gestor.esta_entregando_recompensas():
			return
		reintentos_externos += 1
		gestor.reintentar_recompensas_pendientes(inventario)
	)

	var entregada := gestor.entregar_recompensas("mision_recompensa_test", inventario)
	if entregada:
		errores.append("Se entregaron dos objetos en un inventario de un solo espacio.")
	if gestor.esta_entregando_recompensas():
		errores.append("El bloqueo de entrega quedó activo después del rollback.")
	if reintentos_externos != 0:
		errores.append("El rollback disparó un reintento automático recursivo.")
	if bool(gestor._recompensas_reclamadas.get("mision_recompensa_test", false)):
		errores.append("Una entrega parcial quedó marcada como reclamada.")
	for objeto in inventario.items:
		if objeto is Dictionary and not (objeto as Dictionary).is_empty():
			errores.append("El rollback no restauró el inventario original.")
			break
	inventario.queue_free()
	gestor.queue_free()
	await get_tree().process_frame


func _probar_entrega_idempotente(errores: Array[String]) -> void:
	var inventario := _crear_inventario(2)
	var gestor := _crear_gestor([
		_recompensa("manzana_test", "Manzana"),
		_recompensa("pala_test", "Pala de Madera")
	])
	await get_tree().process_frame

	var reintentos_externos := 0
	inventario.inventory_changed.connect(func() -> void:
		if gestor.esta_entregando_recompensas():
			return
		reintentos_externos += 1
		gestor.reintentar_recompensas_pendientes(inventario)
	)

	if not gestor.entregar_recompensas("mision_recompensa_test", inventario):
		errores.append("No se pudieron entregar recompensas con espacio suficiente.")
	if not gestor.entregar_recompensas("mision_recompensa_test", inventario):
		errores.append("La segunda llamada idempotente no confirmó la entrega previa.")
	var ocupados := 0
	for objeto in inventario.items:
		if objeto is Dictionary and not (objeto as Dictionary).is_empty():
			ocupados += 1
	if ocupados != 2:
		errores.append("La entrega idempotente duplicó o perdió objetos.")
	if reintentos_externos != 0:
		errores.append("La inserción de recompensas programó reintentos redundantes.")
	if not bool(gestor._recompensas_reclamadas.get("mision_recompensa_test", false)):
		errores.append("La entrega completa no quedó marcada como reclamada.")
	inventario.queue_free()
	gestor.queue_free()
	await get_tree().process_frame


func _probar_resolucion_item_canonico(errores: Array[String]) -> void:
	var world_items := WorldItemsScript.new() as GarliaWorldItems
	world_items.catalogo = [{
		"id": "item_uuid_canonico",
		"item_id": "item_uuid_canonico",
		"nombre": "Espada de Madera",
		"descripcion": "Espada de prueba desde catálogo.",
		"tipo": "arma",
		"max_stack": 1,
		"propiedades_game": {"danio": 8}
	}]
	var recompensa := {
		"tipo": "item",
		"item_id": "item_uuid_canonico",
		"cantidad": 1,
		"datos": {}
	}
	var gestor := _crear_gestor([recompensa])
	var world_data := WorldDataScript.new() as WorldDataService
	gestor.configurar_dependencias(null, world_data, world_items)
	var mision := gestor.obtener_mision("mision_recompensa_test")
	var recompensas: Array = mision.get("recompensas", [])
	var objeto := gestor._construir_objeto_recompensa(recompensas[0] as Dictionary) if not recompensas.is_empty() else {}
	if str(objeto.get("id", "")) != "item_uuid_canonico":
		errores.append("No se resolvió el item_id de la recompensa contra GarliaWorldItems.")
	if str(objeto.get("nombre", "")) != "Espada de Madera":
		errores.append("La recompensa no conservó el nombre canónico del item.")
	if str(objeto.get("tipo", "")) != "arma" or int(objeto.get("max_stack", 0)) != 1:
		errores.append("La recompensa perdió tipo o max_stack del catálogo.")
	if int((objeto.get("propiedades_game", {}) as Dictionary).get("danio", 0)) != 8:
		errores.append("La recompensa no conservó propiedades_game del catálogo.")
	gestor.queue_free()
	world_items.free()
