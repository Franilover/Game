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

 
## La ranura y la ficha del objeto deben coincidir antes de cualquier transacción.
static func es_objeto_compatible(slot: String, item: Dictionary) -> bool:
	if item.is_empty() or slot not in ["cabeza", "torso", "pies"]:
		return false
	if str(item.get("tipo", "")).strip_edges().to_lower() != "armadura":
		return false
	var propiedades_variant: Variant = item.get("propiedades_game", {})
	if not propiedades_variant is Dictionary:
		return false
	var propiedades := propiedades_variant as Dictionary
	return str(propiedades.get("ranura_equipamiento", "")).strip_edges().to_lower() == slot
