extends Node
class_name InventoryController

## Coordina el runtime del inventario con una implementación de UI.
## No contiene el estado canónico de items, hotbar o equipamiento.

signal inventario_cambio
signal hotbar_cambio(indice: int)
signal equipo_cambio(slot: String, item: Dictionary)

var runtime := InventoryRuntime.new()
var input_gate: Node = null

func configurar_gate(gate: Node) -> void:
	input_gate = gate

func puede_interactuar() -> bool:
	if input_gate == null or not is_instance_valid(input_gate):
		return true
	if input_gate.has_method("esta_bloqueado"):
		return not bool(input_gate.call("esta_bloqueado"))
	return true

func cargar_items(items: Array) -> void:
	runtime.establecer_items(items)
	inventario_cambio.emit()

func obtener_item(indice: int) -> Dictionary:
	return runtime.obtener_item(indice)

func seleccionar_hotbar(indice: int) -> bool:
	if not runtime.seleccionar_hotbar(indice):
		return false
	hotbar_cambio.emit(runtime.hotbar.indice_activo)
	return true

func equipar(slot: String, item: Dictionary) -> void:
	runtime.equipar(slot, item)
	equipo_cambio.emit(slot, item.duplicate(true))

func desequipar(slot: String) -> Dictionary:
	var anterior := runtime.desequipar(slot)
	equipo_cambio.emit(slot, {})
	return anterior

func obtener_equipo(slot: String) -> Dictionary:
	return runtime.obtener_equipo(slot)

func serializar() -> Dictionary:
	return {
		"items": runtime.state.items.duplicate(true),
		"hotbar_indices": runtime.hotbar.indices.duplicate(),
		"indice_hotbar_activo": runtime.hotbar.indice_activo,
		"equipo": runtime.equipment.state.slots.duplicate(true)
	}
