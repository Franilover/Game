extends Node
class_name InteractionSystem


signal objetivo_cambiado(objetivo: Node)


@export var interaction_distance: float = 48.0
@export var scan_interval: float = 0.10


var player: Player = null
var inventory: GarliaInventory = null
var world_items: GarliaWorldItems = null
var input_gate: Node = null
var entity_manager: WorldEntityManager = null

var interaction_controller := InteractionController.new()
var objetivo_actual: Node = null

var _scan_timer: float = 0.0


func configurar(
	nuevo_player: Player,
	nuevo_inventory: GarliaInventory = null,
	nuevo_world_items: GarliaWorldItems = null,
	nuevo_input_gate: Node = null,
	nuevo_entity_manager: WorldEntityManager = null
) -> void:
	player = nuevo_player
	inventory = nuevo_inventory
	world_items = nuevo_world_items
	input_gate = nuevo_input_gate
	entity_manager = nuevo_entity_manager
	if not interaction_controller.objetivo_cambiado.is_connected(_cambiar_objetivo):
		interaction_controller.objetivo_cambiado.connect(_cambiar_objetivo)
	interaction_controller.configurar_entidades(entity_manager)

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

	var objeto_activo: Dictionary = {}
	if inventory != null:
		objeto_activo = inventory.obtener_objeto_activo().duplicate(true)

	# Los objetos colocables consumen la acción primaria antes del combate.
	if not objeto_activo.is_empty():
		if world_items != null and world_items.es_objeto_colocable(objeto_activo):
			var colocado: bool = world_items.colocar_objeto(
				objeto_activo,
				player.get_global_mouse_position()
			)
			if colocado:
				inventory.consumir_objeto_activo(1)
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
