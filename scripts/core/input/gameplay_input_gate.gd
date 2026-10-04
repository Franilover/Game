extends Node
class_name GameplayInputGate

## Única autoridad para decidir si el gameplay puede procesar input.
## No contiene lógica de inventario, diálogo ni HUD: consulta sus contratos públicos.

func esta_bloqueado() -> bool:
	if get_tree().paused:
		return true

	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory != null and inventory.has_method("esta_abierto"):
		if bool(inventory.call("esta_abierto")):
			return true

	var admin_console := get_tree().get_first_node_in_group("admin_console")
	if admin_console != null and admin_console is CanvasItem:
		if bool((admin_console as CanvasItem).visible):
			return true

	var dialogue := get_tree().get_first_node_in_group("dialogue_system")
	if dialogue != null and dialogue.has_method("esta_abierto"):
		if bool(dialogue.call("esta_abierto")):
			return true

	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("esta_mostrando_panel_interaccion"):
		if bool(hud.call("esta_mostrando_panel_interaccion")):
			return true

	return false
