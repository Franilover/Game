extends RefCounted
class_name EquipmentState

## Estado de equipamiento separado de la hotbar.

var slots: Dictionary = {}

func equipar(slot: String, item: Dictionary) -> void:
	slots[slot] = item.duplicate(true)

func desequipar(slot: String) -> Dictionary:
	var anterior: Variant = slots.get(slot, {})
	slots.erase(slot)
	if anterior is Dictionary:
		return (anterior as Dictionary).duplicate(true)
	return {}

func obtener(slot: String) -> Dictionary:
	var item: Variant = slots.get(slot, {})
	if item is Dictionary:
		return (item as Dictionary).duplicate(true)
	return {}
