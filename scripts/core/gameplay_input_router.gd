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

const TIEMPO_CONSUMO_ALIMENTO := 1.0
var _mano_consumo_activa: String = ""
var _accion_consumo_activa: String = ""
var _tiempo_consumo: float = 0.0
var _slot_consumo: int = -1
var _identidad_consumo: String = ""
var _boton_consumo: int = MOUSE_BUTTON_NONE
var _barra_consumo: ProgressBar = null
var _etiqueta_consumo: Label = null

func _ready() -> void:
	add_to_group("gameplay_input_router")
	_crear_indicador_consumo()


func _process(delta: float) -> void:
	if _mano_consumo_activa.is_empty():
		return
	var sigue_presionado := Input.is_mouse_button_pressed(_boton_consumo) if _boton_consumo != MOUSE_BUTTON_NONE else Input.is_action_pressed(_accion_consumo_activa)
	if esta_bloqueado() or not sigue_presionado:
		_cancelar_consumo()
		return
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		_cancelar_consumo()
		return
	if not _inventory_ui.puede_consumir_alimento_en_mano(_mano_consumo_activa):
		_cancelar_consumo()
		return
	if _inventory_ui.obtener_indice_mano_activa(_mano_consumo_activa) != _slot_consumo:
		_cancelar_consumo()
		return
	var objeto_actual := _inventory_ui.obtener_objeto_mano_activa(_mano_consumo_activa)
	var identidad_actual := str(objeto_actual.get("item_id", objeto_actual.get("id", objeto_actual.get("nombre", ""))))
	if identidad_actual != _identidad_consumo:
		_cancelar_consumo()
		return

	_tiempo_consumo = minf(_tiempo_consumo + delta, TIEMPO_CONSUMO_ALIMENTO)
	if is_instance_valid(_barra_consumo):
		_barra_consumo.value = _tiempo_consumo / TIEMPO_CONSUMO_ALIMENTO * 100.0
	if _tiempo_consumo >= TIEMPO_CONSUMO_ALIMENTO:
		_completar_consumo()


func _crear_indicador_consumo() -> void:
	var capa := CanvasLayer.new()
	capa.name = "IndicadorConsumo"
	capa.layer = 30
	add_child(capa)
	var contenedor := Control.new()
	contenedor.name = "Contenedor"
	contenedor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	contenedor.offset_left = -92.0
	contenedor.offset_right = 92.0
	contenedor.offset_top = -82.0
	contenedor.offset_bottom = -48.0
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(contenedor)
	_etiqueta_consumo = Label.new()
	_etiqueta_consumo.text = "COMIENDO"
	_etiqueta_consumo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_consumo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_etiqueta_consumo.offset_bottom = 16.0
	_etiqueta_consumo.add_theme_font_size_override("font_size", 10)
	_etiqueta_consumo.add_theme_color_override("font_color", Color(0.94, 0.86, 0.72, 1.0))
	_etiqueta_consumo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.add_child(_etiqueta_consumo)
	_barra_consumo = ProgressBar.new()
	_barra_consumo.min_value = 0.0
	_barra_consumo.max_value = 100.0
	_barra_consumo.value = 0.0
	_barra_consumo.show_percentage = false
	_barra_consumo.position = Vector2(0.0, 19.0)
	_barra_consumo.size = Vector2(184.0, 12.0)
	_barra_consumo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.12, 0.10, 0.08, 0.92)
	fondo.border_color = Color(0.43, 0.34, 0.24, 1.0)
	fondo.set_border_width_all(1)
	var progreso := StyleBoxFlat.new()
	progreso.bg_color = Color(0.72, 0.52, 0.30, 1.0)
	_barra_consumo.add_theme_stylebox_override("background", fondo)
	_barra_consumo.add_theme_stylebox_override("fill", progreso)
	contenedor.add_child(_barra_consumo)
	contenedor.visible = false


func _iniciar_consumo(mano: String, accion: String, boton: int = MOUSE_BUTTON_NONE) -> void:
	if _mano_consumo_activa == mano:
		return
	_cancelar_consumo()
	_mano_consumo_activa = mano
	_accion_consumo_activa = accion
	_boton_consumo = boton
	_slot_consumo = _inventory_ui.obtener_indice_mano_activa(mano) if is_instance_valid(_inventory_ui) else -1
	var objeto := _inventory_ui.obtener_objeto_mano_activa(mano) if is_instance_valid(_inventory_ui) else {}
	_identidad_consumo = str(objeto.get("item_id", objeto.get("id", objeto.get("nombre", ""))))
	_tiempo_consumo = 0.0
	if is_instance_valid(_barra_consumo):
		_barra_consumo.value = 0.0
		(_barra_consumo.get_parent() as Control).visible = true


func _cancelar_consumo() -> void:
	_mano_consumo_activa = ""
	_accion_consumo_activa = ""
	_boton_consumo = MOUSE_BUTTON_NONE
	_tiempo_consumo = 0.0
	_slot_consumo = -1
	_identidad_consumo = ""
	if is_instance_valid(_barra_consumo):
		_barra_consumo.value = 0.0
		(_barra_consumo.get_parent() as Control).visible = false


func _completar_consumo() -> void:
	var mano := _mano_consumo_activa
	var accion := _accion_consumo_activa
	_cancelar_consumo()
	if GarliaWorldNetwork.es_cliente_en_mundo_global():
		GarliaWorldNetwork.solicitar_accion_local("primary" if accion == "primary_action" else "secondary")
		return
	if _inventory_ui != null and is_instance_valid(_inventory_ui):
		_inventory_ui.usar_objeto_mano(mano)

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
	# Capturar el ratón antes de que otro nodo consuma el evento.
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if esta_bloqueado():
		return
	var accion := "primary_action" if mouse_event.button_index == MOUSE_BUTTON_LEFT else "secondary_action"
	var mano := "izquierda" if mouse_event.button_index == MOUSE_BUTTON_LEFT else "derecha"
	if _intentar_iniciar_consumo(mano, accion, mouse_event.button_index):
		get_viewport().set_input_as_handled()


func _intentar_iniciar_consumo(mano: String, accion: String, boton: int = MOUSE_BUTTON_NONE) -> bool:
	var hay_contexto := (
		_interaction_system != null
		and get_tree().get_nodes_in_group("garumi_combat_arena").is_empty()
		and _interaction_system.hay_interaccion_contextual()
	)
	if hay_contexto or _inventory_ui == null or not is_instance_valid(_inventory_ui):
		return false
	if not _inventory_ui.puede_consumir_alimento_en_mano(mano):
		return false
	_iniciar_consumo(mano, accion, boton)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _es_accion_primaria_o_secundaria(event):
		return
	if not event.is_action_pressed("primary_action") and not event.is_action_pressed("secondary_action"):
		return
	if esta_bloqueado():
		return

	var accion := "primary_action" if event.is_action_pressed("primary_action") else "secondary_action"
	var mano := "izquierda" if accion == "primary_action" else "derecha"
	if _intentar_iniciar_consumo(mano, accion):
		get_viewport().set_input_as_handled()
		return

	if GarliaWorldNetwork.es_cliente_en_mundo_global():
		GarliaWorldNetwork.solicitar_accion_local("primary" if accion == "primary_action" else "secondary")
		get_viewport().set_input_as_handled()
		return

	var combate_garumi_activo := not get_tree().get_nodes_in_group("garumi_combat_arena").is_empty()
	if accion == "primary_action":
		if not combate_garumi_activo and _interaction_system != null and _interaction_system.procesar_accion_primaria():
			get_viewport().set_input_as_handled()
			return
		if _combat_system != null and _combat_system.procesar_accion_primaria():
			get_viewport().set_input_as_handled()
			return
	else:
		if not combate_garumi_activo and _interaction_system != null and _interaction_system.procesar_accion_secundaria():
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

	# Los menús contextuales modales deben recibir los clics antes que el gameplay.
	# _input se ejecuta antes de la GUI; sin este bloqueo, CombatSystem puede consumirlos.
	for interfaz in arbol.get_nodes_in_group("modal_ui"):
		if is_instance_valid(interfaz) and interfaz.is_inside_tree() and not interfaz.is_queued_for_deletion():
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


