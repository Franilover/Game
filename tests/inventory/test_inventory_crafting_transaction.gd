extends Node

const RuntimeScript = preload("res://scripts/gameplay/inventory/inventory_runtime.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var runtime := RuntimeScript.new() as InventoryRuntime
	var items: Array = []
	for i in range(18):
		items.append({})
	items[6] = {"id": "wood", "item_id": "", "nombre": "Madera", "cantidad": 2, "max_stack": 10}
	items[7] = {"id": "wood", "item_id": "wood", "nombre": "Madera", "cantidad": 2, "max_stack": 10}
	runtime.establecer_items(items)


	var ingredients: Array = [
		{"item_id": "wood", "cantidad": 2},
		{"item_id": "wood", "cantidad": 1}
	]
	var output := {"id": "plank", "item_id": "plank", "nombre": "Tabla", "cantidad": 2, "max_stack": 10}
	if not runtime.fabricar(ingredients, output):
		errors.append("No fabricó una receta válida repartida entre dos pilas.")
	var wood_left := 0
	var planks := 0
	for item in runtime.state.items:
		var item_id := str(item.get("item_id", item.get("id", "")))
		if item_id == "wood":
			wood_left += int(item.get("cantidad", 1))
		elif item_id == "plank":
			planks += int(item.get("cantidad", 0))
	if wood_left != 1 or planks != 2:
		errors.append("La fabricación válida no conservó las cantidades exactas.")


	var before_missing := runtime.state.items.duplicate(true)
	if runtime.fabricar([{"item_id": "wood", "cantidad": 99}], output):
		errors.append("Fabricó una receta sin materiales suficientes.")
	if runtime.state.items != before_missing:
		errors.append("La receta rechazada por falta de materiales alteró el inventario.")


	var full_items: Array = []
	for i in range(18):
		full_items.append({"id": "occupied_%d" % i, "nombre": "Ocupado", "cantidad": 1, "max_stack": 1})
	full_items[6] = {"id": "wood", "item_id": "wood", "nombre": "Madera", "cantidad": 1, "max_stack": 10}
	runtime.establecer_items(full_items)
	var before_capacity := runtime.state.items.duplicate(true)
	var oversized_output := {"id": "heavy_output", "item_id": "heavy_output", "nombre": "Resultado", "cantidad": 2, "max_stack": 1}
	if runtime.fabricar([{"item_id": "wood", "cantidad": 1}], oversized_output):
		errors.append("Aceptó un resultado que no cabía tras consumir ingredientes.")
	if runtime.state.items != before_capacity:
		errors.append("El fallo por capacidad consumió materiales o alteró slots.")


	if runtime.fabricar([{"item_id": "", "cantidad": 1}], output):
		errors.append("Aceptó un ingrediente sin identidad.")
	if runtime.state.items != before_capacity:
		errors.append("La receta mal formada alteró el inventario.")


	if not errors.is_empty():
		for error in errors:
			push_error("InventoryCraftingTransaction: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryCraftingTransaction: PASS")
	get_tree().quit(0)
