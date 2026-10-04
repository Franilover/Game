extends RefCounted
class_name InventoryRuntime

## Estado runtime del inventario.
## Hotbar y equipamiento son estados independientes.

var state := InventoryState.new()
var hotbar := InventoryHotbar.new()
var equipment := InventoryEquipment.new()

func limpiar() -> void:
	state.limpiar()
	hotbar.indices.clear()
	hotbar.indice_activo = 0
	equipment.state.slots.clear()

func establecer_items(items: Array) -> void:
	state.items.clear()
	for value in items:
		if value is Dictionary:
			state.items.append((value as Dictionary).duplicate(true))
		else:
			state.items.append({})

func obtener_item(indice: int) -> Dictionary:
	return state.obtener_item(indice)

func seleccionar_hotbar(indice: int) -> bool:
	return hotbar.seleccionar(indice)

func equipar(slot: String, item: Dictionary) -> void:
	equipment.equipar(slot, item)

func desequipar(slot: String) -> Dictionary:
	return equipment.desequipar(slot)

func obtener_equipo(slot: String) -> Dictionary:
	return equipment.obtener(slot)
