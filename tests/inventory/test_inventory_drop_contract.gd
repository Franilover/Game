extends Node

const InventoryControllerScript = preload("res://scripts/gameplay/inventory/inventory_controller.gd")
const WorldItemsScript = preload("res://scripts/infrastructure/garlia_world_items.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var controller := InventoryControllerScript.new() as InventoryController
	var world_items := WorldItemsScript.new() as GarliaWorldItems
	var objeto := {
		"id": "objeto_prueba",
		"nombre": "Objeto de prueba",
		"cantidad": 4,
		"max_stack": 10
	}
	controller.runtime.establecer_items([objeto])

	var drop_exitoso := controller.soltar_objeto_al_mundo(
		0,
		Vector2.ZERO,
		world_items
	)
	if drop_exitoso:
		errores.append("Se informó éxito aunque faltaba el root de entidades.")
	var restante := controller.obtener_item(0)
	if str(restante.get("id", "")) != "objeto_prueba":
		errores.append("El objeto se perdió cuando WorldEntityManager no estaba disponible.")
	elif int(restante.get("cantidad", 0)) != 4:
		errores.append("La cantidad del objeto cambió tras un drop rechazado.")

	controller.free()
	world_items.free()
	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("InventoryDropContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryDropContract: PASS")
	get_tree().quit(0)
