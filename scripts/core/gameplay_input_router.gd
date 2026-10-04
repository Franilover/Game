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

var _interaction_system: Node = null
var _combat_system: Node = null
var _inventory_ui: Node = null
var _admin_console: Node = null
var _dialogue_system: Node = null
var _hud: Node = null

func configurar_sistemas(interaction: Node, combat: Node) -> void:
	_interaction_system = interaction
	_combat_system = combat

func configurar_bloqueos(
	inventory_ui: Node,
	admin_console: Node,
	dialogue_system: Node,
	hud: Node
) -> void:
	_inventory_ui = inventory_ui
	_admin_console = admin_console
	_dialogue_system = dialogue_system
	_hud = hud

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


func esta_entrada_bloqueada(arbol: SceneTree) -> bool:
	if arbol == null:
		return true

	if arbol.paused:
		return true

	if _inventory_ui != null and _inventory_ui.has_method("esta_abierto"):
		if bool(_inventory_ui.call("esta_abierto")):
			return true

	if _admin_console != null and _admin_console is CanvasItem:
		if bool((_admin_console as CanvasItem).visible):
			return true

	if _dialogue_system != null and _dialogue_system.has_method("esta_abierto"):
		if bool(_dialogue_system.call("esta_abierto")):
			return true

	if _hud != null and _hud.has_method("esta_mostrando_panel_interaccion"):
		if bool(_hud.call("esta_mostrando_panel_interaccion")):
			return true

	return false


func _es_accion_primaria_o_secundaria(event: InputEvent) -> bool:
	return (
		event.is_action_pressed("primary_action")
		or event.is_action_pressed("secondary_action")
	)


