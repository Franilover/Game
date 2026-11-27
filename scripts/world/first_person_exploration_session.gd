extends Node
class_name FirstPersonExplorationSession

## Mantiene vivo el runtime principal y sustituye temporalmente sólo su presentación.
## El Player 2D, el inventario, GameState y las interfaces siguen siendo los originales.

const ESCENA_EXPLORACION_3D: PackedScene = preload("res://scenes/world/exploracion_3d.tscn")

var _activa: bool = false
var _escena_3d: Node3D = null
var _zona: Node = null
var _jugador: Node2D = null
var _camara_2d: Camera2D = null
var _interaccion: Node = null
var _zona_visible_previa: bool = true
var _jugador_visible_previo: bool = true
var _camara_2d_habilitada_previa: bool = true
var _interaccion_activa_previa: bool = true
var _estado_jugador: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func iniciar() -> bool:
	if _activa or get_tree().paused:
		return false
	var principal := get_parent()
	if not is_instance_valid(principal):
		return false
	var zone_manager := principal.get_node_or_null("World/ZoneManager")
	var zona_actual: Node = zone_manager.call("obtener_zona_actual") if is_instance_valid(zone_manager) and zone_manager.has_method("obtener_zona_actual") else null
	var jugador := principal.get_node_or_null("Entities/Player") as Node2D
	var camara := principal.get_node_or_null("GameCamera") as Camera2D
	if not is_instance_valid(zona_actual) or not is_instance_valid(jugador) or not is_instance_valid(camara):
		push_warning("FirstPersonExplorationSession: faltan la zona, el jugador o la cámara 2D.")
		return false

	var nueva_escena := ESCENA_EXPLORACION_3D.instantiate() as Node3D
	if not is_instance_valid(nueva_escena):
		push_error("FirstPersonExplorationSession: no se pudo instanciar la escena 3D.")
		return false

	_zona = zona_actual
	_jugador = jugador
	_camara_2d = camara
	_zona_visible_previa = (_zona as CanvasItem).visible if _zona is CanvasItem else true
	_jugador_visible_previo = _jugador.visible
	_camara_2d_habilitada_previa = _camara_2d.enabled
	_estado_jugador = _suspender_subarbol(_jugador)
	if _zona is CanvasItem:
		# Se oculta la zona 2D, pero sus habitantes siguen simulando el reloj y sus rutinas.
		(_zona as CanvasItem).visible = false
	_jugador.visible = false
	_camara_2d.enabled = false

	_interaccion = principal.get_node_or_null("Systems/InteractionSystem")
	if is_instance_valid(_interaccion):
		var activo_variant: Variant = _interaccion.get("_activo")
		_interaccion_activa_previa = bool(activo_variant) if activo_variant != null else true
		if _interaccion.has_method("establecer_activo"):
			_interaccion.call("establecer_activo", false)

	nueva_escena.name = "Exploracion3DActiva"
	principal.add_child(nueva_escena)
	_escena_3d = nueva_escena
	_activa = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.notification_pushed.emit("Exploración 3D · WASD para moverte · ratón para mirar · F10 para regresar.")
	return true


func _process(_delta: float) -> void:
	if not _activa:
		return
	if _hay_interfaz_abierta():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _activa or get_tree().paused or _hay_interfaz_abierta():
		return
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and tecla.keycode == KEY_F10:
			get_viewport().set_input_as_handled()
			salir()


func _hay_interfaz_abierta() -> bool:
	if get_tree().paused:
		return true
	var principal := get_parent()
	if is_instance_valid(principal):
		var inventario := principal.get_node_or_null("UI/Inventory")
		if is_instance_valid(inventario) and bool(inventario.get("_abierto")):
			return true
		var pausa := principal.get_node_or_null("UI/PauseMenu")
		if is_instance_valid(pausa) and bool(pausa.get("abierto")):
			return true
	for modal in get_tree().get_nodes_in_group("modal_ui"):
		if is_instance_valid(modal) and (not modal is CanvasItem or (modal as CanvasItem).is_visible_in_tree()):
			return true
	return false


func salir() -> void:
	if not _activa:
		return
	_activa = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_escena_3d):
		_escena_3d.queue_free()
		await _escena_3d.tree_exited
	_escena_3d = null

	_restaurar_subarbol(_estado_jugador)
	_estado_jugador.clear()
	if is_instance_valid(_zona) and _zona is CanvasItem:
		(_zona as CanvasItem).visible = _zona_visible_previa
	if is_instance_valid(_jugador):
		_jugador.visible = _jugador_visible_previo
	if is_instance_valid(_camara_2d):
		_camara_2d.enabled = _camara_2d_habilitada_previa
		if _camara_2d_habilitada_previa:
			_camara_2d.make_current()
	if is_instance_valid(_interaccion) and _interaccion.has_method("establecer_activo"):
		_interaccion.call("establecer_activo", _interaccion_activa_previa)

	_zona = null
	_jugador = null
	_camara_2d = null
	_interaccion = null
	Events.notification_pushed.emit("Has regresado al Centro de Expediciones.")


func _suspender_subarbol(raiz: Node) -> Array[Dictionary]:
	var estados: Array[Dictionary] = []
	if not is_instance_valid(raiz):
		return estados
	_registrar_y_suspender(raiz, estados)
	return estados


func _registrar_y_suspender(nodo: Node, estados: Array[Dictionary]) -> void:
	estados.append({
		"nodo": nodo,
		"process": nodo.is_processing(),
		"physics": nodo.is_physics_processing(),
		"input": nodo.is_processing_input(),
		"unhandled": nodo.is_processing_unhandled_input()
	})
	nodo.set_process(false)
	nodo.set_physics_process(false)
	nodo.set_process_input(false)
	nodo.set_process_unhandled_input(false)
	for hijo in nodo.get_children():
		_registrar_y_suspender(hijo, estados)


func _restaurar_subarbol(estados: Array[Dictionary]) -> void:
	for estado in estados:
		var nodo_variant: Variant = estado.get("nodo")
		if not is_instance_valid(nodo_variant) or not nodo_variant is Node:
			continue
		var nodo := nodo_variant as Node
		nodo.set_process(bool(estado.get("process", false)))
		nodo.set_physics_process(bool(estado.get("physics", false)))
		nodo.set_process_input(bool(estado.get("input", false)))
		nodo.set_process_unhandled_input(bool(estado.get("unhandled", false)))
