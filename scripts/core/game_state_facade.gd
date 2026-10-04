extends Node
class_name GameStateFacade

## Fachada de estado del juego.
## Coordina estados separados; no contiene sus datos internos como autoridad.

var player := PlayerRuntime.new()
var world := WorldRuntime.new()
var inventory := InventoryRuntime.new()
var save := SaveState.new()

func limpiar_runtime() -> void:
	player = PlayerRuntime.new()
	world = WorldRuntime.new()
	inventory = InventoryRuntime.new()

func configurar_partida(id: String, nombre: String) -> void:
	save.configurar(id, nombre)

func cerrar_partida() -> void:
	save.limpiar()

func capturar_jugador(nodo: Node) -> void:
	player.aplicar_estado_desde_nodo(nodo)

func aplicar_jugador(nodo: Node) -> void:
	player.aplicar_al_nodo(nodo)

func establecer_semilla_mundo(semilla: int) -> void:
	world.establecer_semilla(semilla)

func obtener_semilla_mundo() -> int:
	return world.obtener_semilla()

func avanzar_tiempo(delta: float) -> void:
	world.avanzar_tiempo(delta)

func serializar_runtime() -> Dictionary:
	return {
		"player": player.state.to_dictionary(),
		"mundo": world.state.to_dictionary(),
		"descubrimientos": world.discovery.to_dictionary(),
		"inventario": {
			"items": inventory.state.items.duplicate(true),
			"hotbar_indices": inventory.hotbar.indices.duplicate(),
			"indice_hotbar_activo": inventory.hotbar.indice_activo,
			"equipo": inventory.equipment.state.slots.duplicate(true)
		}
	}

func restaurar_runtime(data: Dictionary) -> void:
	var player_data: Variant = data.get("player", {})
	if player_data is Dictionary:
		player.state.from_dictionary(player_data as Dictionary)

	var world_data: Variant = data.get("mundo", {})
	if world_data is Dictionary:
		world.state.from_dictionary(world_data as Dictionary)

	var discovery_data: Variant = data.get("descubrimientos", {})
	if discovery_data is Dictionary:
		world.discovery.from_dictionary(discovery_data as Dictionary)

	var inventory_data: Variant = data.get("inventario", {})
	if inventory_data is Dictionary:
		var inv := inventory_data as Dictionary
		var items: Variant = inv.get("items", [])
		if items is Array:
			inventory.establecer_items(items as Array)

		var hotbar_indices: Variant = inv.get("hotbar_indices", [])
		if hotbar_indices is Array:
			inventory.hotbar.indices.clear()
			for value in hotbar_indices as Array:
				inventory.hotbar.indices.append(int(value))

		inventory.hotbar.indice_activo = int(inv.get("indice_hotbar_activo", 0))

		var equipment_data: Variant = inv.get("equipo", {})
		if equipment_data is Dictionary:
			inventory.equipment.state.slots = (equipment_data as Dictionary).duplicate(true)
