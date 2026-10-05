extends Node
class_name GameplayInputRouter
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

var _interaction_system: InteractionSystem = null
var _combat_system: CombatSystem = null
var _inventory_ui: GarliaInventory = null
var _admin_console: Node = null
var _dialogue_system: DialogueSystem = null
var _hud: HUD = null
var _debug_console: Node = null

func _ready() -> void:
	add_to_group("gameplay_input_router")

func configurar_sistemas(interaction: InteractionSystem, combat: CombatSystem) -> void:
	_interaction_system = interaction
	_combat_system = combat

func configurar_bloqueos(
	inventory_ui: GarliaInventory,
	admin_console: Node,
	dialogue_system: DialogueSystem,
	hud: HUD,
	debug_console: Node = null
) -> void:
	_inventory_ui = inventory_ui
	_admin_console = admin_console
	_dialogue_system = dialogue_system
	_hud = hud
	_debug_console = debug_console

func _input(event: InputEvent) -> void:
	if not _es_accion_primaria_o_secundaria(event):
		return

	# Si una interfaz modal está abierta, no consumimos el evento:
	# la UI (Buttons, inventario, diálogo, etc.) debe recibirlo.
	if esta_bloqueado():
		return

	if event.is_action_pressed("primary_action"):
		if _interaction_system != null and _interaction_system.procesar_accion_primaria():
			get_viewport().set_input_as_handled()
			return

		if _combat_system != null and _combat_system.procesar_accion_primaria():
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("secondary_action"):
		if _interaction_system != null and _interaction_system.procesar_accion_secundaria():
			get_viewport().set_input_as_handled()
			return

		if _combat_system != null and _combat_system.procesar_accion_secundaria():
			get_viewport().set_input_as_handled()
			return


func esta_bloqueado() -> bool:
	return esta_entrada_bloqueada(get_tree())


func esta_entrada_bloqueada(arbol: SceneTree) -> bool:
	if arbol == null:
		return true

	if arbol.paused:
		return true

	if _inventory_ui != null and _inventory_ui.esta_abierto():
		return true

	if _admin_console != null and _admin_console is CanvasItem:
		if bool((_admin_console as CanvasItem).visible):
			return true

	if _dialogue_system != null and _dialogue_system.esta_abierto():
		return true

	if _hud != null and _hud.esta_mostrando_panel_interaccion():
		return true

	if _debug_console != null and is_instance_valid(_debug_console) and bool(_debug_console.get("visible")):
		return true

	return false


func _es_accion_primaria_o_secundaria(event: InputEvent) -> bool:
	return (
		event.is_action_pressed("primary_action")
		or event.is_action_pressed("secondary_action")
	)


