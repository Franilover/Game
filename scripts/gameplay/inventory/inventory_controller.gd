extends Node

func _garlia_debug() -> Node:
	return get_node_or_null("/root/GarliaDebug")

class_name InventoryController

## Coordina el runtime del inventario con una implementación de UI.
## No contiene el estado canónico de items, hotbar o equipamiento.

signal inventario_cambio
signal hotbar_cambio(indice: int)
signal equipo_cambio(slot: String, item: Dictionary)

var runtime := InventoryRuntime.new()
var input_gate: GameplayInputGate = null

func configurar_gate(gate: GameplayInputGate) -> void:
	input_gate = gate

func puede_interactuar() -> bool:
	if input_gate == null or not is_instance_valid(input_gate):
		return true
	return not input_gate.esta_bloqueado()

func configurar_items(items: Array, hotbar_indices: Array = []) -> void:
	runtime.establecer_items(items)
	runtime.hotbar.configurar(hotbar_indices)
	inventario_cambio.emit()
	hotbar_cambio.emit(runtime.hotbar.indice_activo)

func cargar_items(items: Array) -> void:
	runtime.establecer_items(items)
	inventario_cambio.emit()
 
func obtener_item(indice: int) -> Dictionary:
	return runtime.obtener_item(indice)

func agregar_objeto(datos: Dictionary) -> bool:
	if not puede_interactuar():
		_garlia_debug().registrar("INVENTORY", "agregar_objeto bloqueado por GameplayInputGate.")
		_garlia_debug().flujo_error("InventoryController bloqueó agregar_objeto por GameplayInputGate.")
		return false
	if datos.is_empty():
		_garlia_debug().flujo_error("InventoryController recibió objeto vacío.")
		return false
	var resultado: bool = runtime.agregar_objeto(datos)
	if resultado:
		_garlia_debug().flujo_paso("InventoryController aceptó el objeto.")
		inventario_cambio.emit()
	return resultado

func quitar_cantidad(indice: int, cantidad: int = 1) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.quitar_cantidad(indice, cantidad)
	if resultado:
		inventario_cambio.emit()
	return resultado

func quitar_objeto(indice: int) -> bool:
	return quitar_cantidad(indice, 999999)

func establecer_objeto(indice: int, datos: Dictionary) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.establecer_objeto(indice, datos)
	if resultado:
		inventario_cambio.emit()
	return resultado

func intercambiar_o_apilar(origen: int, destino: int) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.intercambiar_o_apilar(origen, destino)
	if resultado:
		inventario_cambio.emit()
	return resultado

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

func obtener_equipamiento() -> Dictionary:
	return runtime.obtener_equipamiento()

func serializar() -> Dictionary:
	return {
		"items": runtime.state.items.duplicate(true),
		"hotbar_indices": runtime.hotbar.indices.duplicate(),
		"indice_hotbar_activo": runtime.hotbar.indice_activo,
		"equipo": runtime.equipment.state.slots.duplicate(true)
	}

func equipar_desde_inventario(slot: String, indice: int, item: Dictionary) -> bool:
	# Equipar desde la interfaz es una acción de inventario, no una entrada
	# de gameplay. El gate bloquea movimiento/combate, no operaciones de UI.
	var resultado: bool = runtime.equipar_desde_inventario(slot, indice, item)
	if resultado:
		equipo_cambio.emit(slot, runtime.obtener_equipo(slot))
		inventario_cambio.emit()
	return resultado

func desequipar_a_inventario(slot: String) -> bool:
	# La interfaz debe poder devolver objetos al inventario aunque el gate
	# esté bloqueando las acciones del personaje.
	var resultado: bool = runtime.desequipar_a_inventario(slot)
	if resultado:
		equipo_cambio.emit(slot, {})
		inventario_cambio.emit()
	return resultado

func establecer_hotbar_slot(indice_hotbar: int, indice_inventario: int) -> bool:
	if not puede_interactuar():
		return false
	if not runtime.establecer_hotbar_slot(indice_hotbar, indice_inventario):
		return false
	hotbar_cambio.emit(indice_hotbar)
	return true

func consumir_durabilidad(indice: int) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.consumir_durabilidad(indice)
	if resultado:
		inventario_cambio.emit()
	return resultado

func limpiar() -> void:
	runtime.limpiar()
	inventario_cambio.emit()

func robar_objeto_equipado(slot: String) -> Dictionary:
	if not puede_interactuar():
		return {}
	var objeto := runtime.robar_equipamiento(slot)
	if objeto.is_empty():
		return {}
	equipo_cambio.emit(slot, {})
	inventario_cambio.emit()
	return objeto

func consumir_durabilidad_equipo(slot: String) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.consumir_durabilidad_equipo(slot)
	if resultado:
		equipo_cambio.emit(slot, runtime.obtener_equipo(slot))
		inventario_cambio.emit()
	return resultado

func obtener_objeto_equipado(slot: String = "mano_secundaria") -> Dictionary:
	return runtime.obtener_equipo(slot)
