extends Node

const InventoryScript = preload("res://scripts/ui/inventory.gd")
const WorldItemsScript = preload("res://scripts/infrastructure/garlia_world_items.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var inventario := InventoryScript.new() as GarliaInventory
	var world_items := WorldItemsScript.new() as GarliaWorldItems
	var objeto := {
		"id": "objeto_prueba",
		"nombre": "Objeto de prueba",
		"cantidad": 4,
		"max_stack": 10
	}
	inventario.inventory_controller.runtime.establecer_items([objeto])
	inventario._world_items = world_items

	inventario._soltar_objeto_al_mundo(0, inventario.items[0].duplicate(true))
	if inventario.items.size() != 1:
		errores.append("El fallo de creación alteró la capacidad del inventario.")
	elif str(inventario.items[0].get("id", "")) != "objeto_prueba":
		errores.append("El objeto se perdió cuando WorldEntityManager no estaba disponible.")
	elif int(inventario.items[0].get("cantidad", 0)) != 4:
		errores.append("La cantidad del objeto cambió tras un drop rechazado.")

	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("InventoryDropContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryDropContract: PASS")
	get_tree().quit(0)
