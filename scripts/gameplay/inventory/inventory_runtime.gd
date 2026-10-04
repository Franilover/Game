extends RefCounted
class_name InventoryRuntime

## Estado runtime del inventario.
## Objetos, hotbar y equipamiento son estados independientes.

var state := InventoryState.new()
var hotbar := InventoryHotbar.new()
var equipment := InventoryEquipment.new()

func limpiar() -> void:
	state.limpiar()
	hotbar.configurar([])
	equipment.limpiar()

func establecer_items(items: Array) -> void:
	state.establecer_items(items)

func obtener_item(indice: int) -> Dictionary:
	return state.obtener_item(indice)

func seleccionar_hotbar(indice: int) -> bool:
	return hotbar.seleccionar(indice)

func establecer_equipamiento(equipamiento: Dictionary) -> void:
	equipment.limpiar()
	for clave_variant in equipamiento.keys():
		var clave := str(clave_variant)
		var item_variant: Variant = equipamiento.get(clave, {})
		if item_variant is Dictionary and not (item_variant as Dictionary).is_empty():
			equipment.equipar(clave, item_variant as Dictionary)

func equipar(slot: String, item: Dictionary) -> void:
	equipment.equipar(slot, item)

func desequipar(slot: String) -> Dictionary:
	return equipment.desequipar(slot)

func obtener_equipo(slot: String) -> Dictionary:
	return equipment.obtener(slot)

func obtener_equipamiento() -> Dictionary:
	return equipment.state.slots.duplicate(true)
