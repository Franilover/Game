extends RefCounted
class_name InventoryHotbarState

var indices: Array[int] = []
var indice_activo: int = 0

func seleccionar(indice: int) -> bool:
	if indice < 0:
		return false
	if not indices.is_empty() and indice >= indices.size():
		return false
	indice_activo = indice
	return true

func obtener_indice_item() -> int:
	if indice_activo < 0 or indice_activo >= indices.size():
		return -1
	return indices[indice_activo]

func configurar(nuevos_indices: Array) -> void:
	indices.clear()
	for value in nuevos_indices:
		indices.append(int(value))
	indice_activo = clampi(indice_activo, 0, maxi(indices.size() - 1, 0))
