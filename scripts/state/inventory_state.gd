extends RefCounted
class_name InventoryState

## Estado puro de los objetos del inventario.
## Hotbar y equipamiento tienen estados independientes.

var items: Array[Dictionary] = []

func limpiar() -> void:
	items.clear()

func establecer_items(nuevos_items: Array) -> void:
	items.clear()
	for value in nuevos_items:
		if value is Dictionary:
			items.append((value as Dictionary).duplicate(true))
		else:
			items.append({})

func obtener_item(indice: int) -> Dictionary:
	if indice < 0 or indice >= items.size():
		return {}
	return items[indice].duplicate(true)
