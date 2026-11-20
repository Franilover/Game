extends Node

const INVENTORY_SCENE: PackedScene = preload("res://scenes/ui/inventory.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory := INVENTORY_SCENE.instantiate() as GarliaInventory
	if inventory == null:
		push_error("InventoryOverflowUI: no se pudo instanciar la escena de inventario.")
		get_tree().quit(1)
		return

	add_child(inventory)
	await get_tree().process_frame

	var items: Array = []
	for indice in range(30):
		items.append({
			"id": "saved_item_%d" % indice,
			"nombre": "Objeto guardado %d" % indice,
			"cantidad": 1,
			"max_stack": 1
		})

	inventory.cargar_estado_partida({
		"items": items,
		"hotbar_indices": [6, 7, 8, 9, 10, 11],
		"equipo": {}
	})
	await get_tree().process_frame

	if inventory.items.size() != 30:
		push_error("InventoryOverflowUI: la carga no conservó las 30 ranuras.")
		get_tree().quit(1)
		return
	if inventory.slot_nodes.size() != 30:
		push_error("InventoryOverflowUI: la UI no creó una ranura visible para cada objeto.")
		get_tree().quit(1)
		return
	if inventory.grid.get_child_count() != 5:
		push_error("InventoryOverflowUI: no creó los cinco grupos de seis ranuras.")
		get_tree().quit(1)
		return

	for indice in range(30):
		var slot := inventory.slot_nodes[indice]
		if int(slot.get_meta("inventory_index", -1)) != indice:
			push_error("InventoryOverflowUI: la ranura visual %d apunta al índice incorrecto." % indice)
			get_tree().quit(1)
			return

	print("InventoryOverflowUI: PASS")
	get_tree().quit(0)
