extends RefCounted
class_name InventoryState

## Estado puro del inventario.
## No conoce nodos, UI, input ni Supabase.

var items: Array[Dictionary] = []
var hotbar_indices: Array[int] = []
var equipment: Dictionary = {}

func limpiar() -> void:
	items.clear()
	hotbar_indices.clear()
	equipment.clear()

func obtener_item(indice: int) -> Dictionary:
	if indice < 0 or indice >= items.size():
		return {}
	return items[indice].duplicate(true)
