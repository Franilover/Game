extends CharacterBody3D
class_name FirstPerson3DController

## Controlador FPS para escenas 2.5D: escenario 3D y arte pixel art 2D.

@export_category("Movimiento")
@export_range(0.5, 12.0, 0.1) var velocidad: float = 4.0
@export_range(0.0005, 0.01, 0.0005) var sensibilidad: float = 0.002
@export_range(40.0, 100.0, 1.0) var limite_vertical: float = 85.0
@export var capturar_raton_al_iniciar: bool = true

@onready var camara: Camera3D = $Camera3D

var _rotacion_vertical: float = 0.0
var _controlador_objetos: FirstPerson3DItemController = null


func _ready() -> void:
	if camara == null:
		push_error("FirstPerson3DController: falta Camera3D como hija directa.")
		return
	if capturar_raton_al_iniciar:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_controlador_objetos = FirstPerson3DItemController.new()
	_controlador_objetos.name = "FirstPersonItemController"
	camara.add_child(_controlador_objetos)


func configurar_contexto_objetos(inventario: Node, jugador: Node, resolvedor_visual: Object, world_items: Node = null) -> void:
	if is_instance_valid(_controlador_objetos):
		_controlador_objetos.configurar_contexto(inventario, jugador, resolvedor_visual, world_items)


func _unhandled_input(event: InputEvent) -> void:
	if _hay_interfaz_abierta():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.is_action_pressed("primary_action"):
		if is_instance_valid(_controlador_objetos):
			_controlador_objetos.usar_mano("izquierda")
		get_viewport().set_input_as_handled()
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.is_action_pressed("secondary_action"):
		if is_instance_valid(_controlador_objetos):
			_controlador_objetos.usar_mano("derecha")
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensibilidad)
		_rotacion_vertical = clampf(
			_rotacion_vertical - event.relative.y * sensibilidad,
			deg_to_rad(-limite_vertical),
			deg_to_rad(limite_vertical)
		)
		camara.rotation.x = _rotacion_vertical


func _hay_interfaz_abierta() -> bool:
	if get_tree().paused:
		return true
	var escena_principal := get_tree().current_scene
	if is_instance_valid(escena_principal):
		var inventario := escena_principal.get_node_or_null("UI/Inventory")
		if is_instance_valid(inventario) and bool(inventario.get("_abierto")):
			return true
		var pausa := escena_principal.get_node_or_null("UI/PauseMenu")
		if is_instance_valid(pausa) and bool(pausa.get("abierto")):
			return true
	for modal in get_tree().get_nodes_in_group("modal_ui"):
		if is_instance_valid(modal) and (not modal is CanvasItem or (modal as CanvasItem).is_visible_in_tree()):
			return true
	return false


func _physics_process(_delta: float) -> void:
	if _hay_interfaz_abierta():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var entrada := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direccion := (global_basis * Vector3(entrada.x, 0.0, entrada.y)).normalized()
	if entrada.length_squared() > 0.0001:
		velocity.x = direccion.x * velocidad
		velocity.z = direccion.z * velocidad
	else:
		velocity.x = move_toward(velocity.x, 0.0, velocidad * 8.0 * _delta)
		velocity.z = move_toward(velocity.z, 0.0, velocidad * 8.0 * _delta)
	velocity.y = 0.0
	move_and_slide()
