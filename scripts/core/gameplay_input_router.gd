extends Node
## Única autoridad de entrada del gameplay.
##
## Orden de prioridad para acciones primarias:
## 1. Una interfaz/modal abierta bloquea el gameplay y deja que la UI
##    reciba su propio evento.
## 2. Interacción contextual.
## 3. Colocación de objetos.
## 4. Combate.
##
## Los sistemas de gameplay NO deben implementar _input para estas acciones.
## Así no existe una carrera entre InteractionSystem, CombatSystem y la UI.

func _input(event: InputEvent) -> void:
	if not _es_accion_primaria_o_secundaria(event):
		return

	# Si una interfaz modal está abierta, no consumimos el evento:
	# la UI (Buttons, inventario, diálogo, etc.) debe recibirlo.
	if esta_bloqueado():
		return

	if event.is_action_pressed("primary_action"):
		if _interaction_system != null:
			var interaction: Node = _interaction_system
			if interaction.has_method("procesar_accion_primaria"):
				if bool(interaction.call("procesar_accion_primaria")):
					get_viewport().set_input_as_handled()
					print("GameplayInputRouter: primary_action → interacción")
					return

		var combat_primary: Node = _combat_system
		if combat_primary != null and combat_primary.has_method("procesar_accion_primaria"):
			if bool(combat_primary.call("procesar_accion_primaria")):
				get_viewport().set_input_as_handled()
				print("GameplayInputRouter: primary_action → combate")
				return

	if event.is_action_pressed("secondary_action"):
		var combat_secondary: Node = _combat_system
		if combat_secondary != null and combat_secondary.has_method("procesar_accion_secundaria"):
			if bool(combat_secondary.call("procesar_accion_secundaria")):
				get_viewport().set_input_as_handled()
				print("GameplayInputRouter: secondary_action → combate")
				return


func esta_bloqueado() -> bool:
	return esta_entrada_bloqueada(get_tree())


static func esta_entrada_bloqueada(arbol: SceneTree) -> bool:
	if arbol == null:
		return true

	if arbol.paused:
		return true

	var inventory := arbol.get_first_node_in_group("inventory")
	if inventory != null and inventory.has_method("esta_abierto"):
		if bool(inventory.call("esta_abierto")):
			return true

	var admin_console := arbol.get_first_node_in_group("admin_console")
	if admin_console != null and admin_console is CanvasItem:
		if bool((admin_console as CanvasItem).visible):
			return true

	var dialogue := arbol.get_first_node_in_group("dialogue_system")
	if dialogue != null and dialogue.has_method("esta_abierto"):
		if bool(dialogue.call("esta_abierto")):
			return true

	var hud := arbol.get_first_node_in_group("hud")
	if hud != null and hud.has_method("esta_mostrando_panel_interaccion"):
		if bool(hud.call("esta_mostrando_panel_interaccion")):
			return true

	return false


func _es_accion_primaria_o_secundaria(event: InputEvent) -> bool:
	return (
		event.is_action_pressed("primary_action")
		or event.is_action_pressed("secondary_action")
	)


