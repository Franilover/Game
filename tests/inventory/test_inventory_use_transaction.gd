extends Node

const ControllerScript = preload("res://scripts/gameplay/inventory/inventory_controller.gd")
const PlayerScript = preload("res://scripts/characters/player.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var controller := ControllerScript.new() as InventoryController
	var player := PlayerScript.new() as Player
	player.restaurar_estado_vital(40, true, 100)
	var potion := {
		"id": "health_potion",
		"nombre": "Poción",
		"cantidad": 1,
		"categoria": {"clave": "consumibles"},
		"propiedades_game": {"uso": {"tipo": "consumible", "efectos": [{"recurso": "vida", "magnitud": 15}]}}
	}
	if controller.usar_objeto_desde_ui(99, player, potion):
		errors.append("Permitió usar una copia de objeto con un índice fuera del inventario.")
	if player.health != 40:
		errors.append("Aplicó curación antes de comprobar que podía retirar el objeto.")

	var items: Array = []
	for i in range(18):
		items.append({})
	items[6] = potion.duplicate(true)
	controller.configurar_items(items)
	if not controller.usar_objeto_desde_ui(6, player, potion):
		errors.append("No permitió usar un consumible válido.")
	if player.health != 55:
		errors.append("No aplicó el efecto después de consumir el objeto.")
	if not controller.obtener_item(6).is_empty():
		errors.append("No retiró el consumible usado del inventario.")

	# Un consumible no alimenticio sin margen no debe gastarse.
	player.restaurar_estado_vital(100, true, 100)
	items[6] = potion.duplicate(true)
	controller.configurar_items(items)
	if controller.usar_objeto_desde_ui(6, player, potion):
		errors.append("Consumió una poción cuando ningún efecto podía aplicarse.")
	if controller.obtener_item(6).is_empty():
		errors.append("Perdió una poción cuyo efecto no podía aplicarse.")

	# La comida sí se consume aunque sus recursos estén al máximo.
	var food := potion.duplicate(true)
	food["id"] = "bread"
	food["nombre"] = "Pan"
	food["categoria"] = {"clave": "alimentos_bebidas"}
	items[6] = food
	controller.configurar_items(items)
	if not controller.usar_objeto_desde_ui(6, player, food):
		errors.append("No consumió alimento cuando los recursos estaban al máximo.")
	if not controller.obtener_item(6).is_empty():
		errors.append("No retiró el alimento consumido.")

	if not errors.is_empty():
		for error in errors:
			push_error("InventoryUseTransaction: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryUseTransaction: PASS")
	get_tree().quit(0)
