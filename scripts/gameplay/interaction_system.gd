extends Node


signal objetivo_cambiado(objetivo: Node)


@export var interaction_distance: float = 48.0
@export var scan_interval: float = 0.10


var player: Node = null
var inventory: Node = null
var world_items: Node = null
var input_gate: Node = null

var interaction_controller := InteractionController.new()
var objetivo_actual: Node = null

var _scan_timer: float = 0.0


func configurar(
	nuevo_player: Node,
	nuevo_inventory: Node = null,
	nuevo_world_items: Node = null,
	nuevo_input_gate: Node = null
) -> void:
	player = nuevo_player
	inventory = nuevo_inventory
	world_items = nuevo_world_items
	input_gate = nuevo_input_gate
	if not interaction_controller.objetivo_cambiado.is_connected(_cambiar_objetivo):
		interaction_controller.objetivo_cambiado.connect(_cambiar_objetivo)

	print(
		"InteractionSystem: configurado."
	)


	_cambiar_objetivo(null)
	_buscar_objetivo()


func _process(delta: float) -> void:
	if player == null:
		return

	if _entrada_bloqueada_por_router():
		if objetivo_actual != null:
			_cambiar_objetivo(null)
		return

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = maxf(scan_interval, 0.05)
		_buscar_objetivo()

	if objetivo_actual != null and not is_instance_valid(objetivo_actual):
		_cambiar_objetivo(null)


func _ready() -> void:
	add_to_group("interaction_system")


func procesar_accion_primaria() -> bool:
	if player == null or not player.is_alive:
		return false

	# Revalidamos el objetivo justo al hacer click. Así un objeto que
	# entró en alcance entre dos escaneos no pierde la interacción.
	_buscar_objetivo()

	# La interacción contextual tiene prioridad absoluta sobre combate.
	if interaction_controller.interactuar(player):
		return true

	var inventory_node: Node = self.inventory
	var objeto_activo: Dictionary = {}

	if inventory_node != null and inventory_node.has_method("obtener_objeto_activo"):
		var objeto_activo_variant: Variant = inventory_node.call("obtener_objeto_activo")
		if objeto_activo_variant is Dictionary:
			objeto_activo = (objeto_activo_variant as Dictionary).duplicate(true)

	# Los objetos colocables consumen la acción primaria antes del combate.
	if not objeto_activo.is_empty():
		var world_items_node: Node = self.world_items
		if (
			world_items_node != null
			and world_items_node.has_method("es_objeto_colocable")
			and bool(world_items_node.call("es_objeto_colocable", objeto_activo))
		):
			if world_items_node.has_method("colocar_objeto"):
				var colocado: bool = bool(
					world_items_node.call(
						"colocar_objeto",
						objeto_activo,
						(player as Node2D).get_global_mouse_position()
					)
				)
				if colocado:
					if inventory_node.has_method("consumir_objeto_activo"):
						inventory_node.call("consumir_objeto_activo", 1)
					return true

	# Si no hubo interacción ni colocación, CombatSystem recibe la acción.
	return false


func _entrada_bloqueada_por_router() -> bool:
	if input_gate == null:
		return true
	return bool(input_gate.call("esta_entrada_bloqueada", get_tree()))


func _buscar_objetivo() -> void:
	interaction_controller.buscar_objetivo(
		player,
		interaction_distance
	)



func _cambiar_objetivo(nuevo_objetivo: Node) -> void:
	if objetivo_actual == nuevo_objetivo:
		return

	objetivo_actual = nuevo_objetivo
	objetivo_cambiado.emit(objetivo_actual)

	if objetivo_actual == null:
		print("InteractionSystem: objetivo contextual = <ninguno>")
		return

	var texto := "Recoger"
	if objetivo_actual.has_method("get_interaction_text"):
		texto = str(objetivo_actual.call("get_interaction_text"))

	print(
		"InteractionSystem: objetivo contextual = ",
		objetivo_actual.name,
		" | accion = ",
		texto
	)
