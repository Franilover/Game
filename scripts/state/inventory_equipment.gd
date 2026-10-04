extends RefCounted
class_name InventoryEquipment

var state := EquipmentState.new()

func equipar(slot: String, item: Dictionary) -> void:
	state.equipar(slot, item)

func desequipar(slot: String) -> Dictionary:
	return state.desequipar(slot)

func obtener(slot: String) -> Dictionary:
	return state.obtener(slot)

func limpiar() -> void:
	state.slots.clear()
