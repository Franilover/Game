extends Node

const InventoryScene = preload("res://scenes/ui/inventory.tscn")
const HotbarScene = preload("res://scenes/ui/hotbar.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var inventory := InventoryScene.instantiate() as GarliaInventory
	var hotbar := HotbarScene.instantiate() as InventoryHotbar
	if inventory == null or hotbar == null:
		push_error("HotbarSelectionSync: FAIL: No se pudieron instanciar las escenas.")
		get_tree().quit(1)
		return

	get_tree().root.add_child(inventory)
	get_tree().root.add_child(hotbar)
	await get_tree().process_frame
	hotbar.configurar_inventario(inventory)

	if inventory.establecer_hotbar_slot(0, 0):
		errors.append("La hotbar permitió asignar un espacio de mano.")
	if inventory.establecer_hotbar_slot(0, 12):
		errors.append("La hotbar permitió asignar un espacio adicional fuera de la mochila.")
	if not inventory.establecer_hotbar_slot(0, 7):
		errors.append("La hotbar rechazó un espacio válido de mochila.")

	inventory.seleccionar_hotbar(4)
	if hotbar.obtener_indice_seleccionado() != 4:
		errors.append("La hotbar no reflejó la selección restaurada desde InventoryRuntime.")

	hotbar.seleccionar_hotbar(2)
	if inventory.obtener_indice_hotbar_activo() != 2:
		errors.append("La selección de la hotbar no actualizó InventoryRuntime.")

	inventory.seleccionar_hotbar(5)
	if hotbar.obtener_indice_seleccionado() != 5:
		errors.append("La hotbar no reflejó un cambio posterior originado en el inventario.")

	inventory.queue_free()
	hotbar.queue_free()
	await get_tree().process_frame

	if not errors.is_empty():
		for error in errors:
			push_error("HotbarSelectionSync: FAIL: " + error)
		get_tree().quit(1)
		return
	print("HotbarSelectionSync: PASS")
	get_tree().quit(0)
