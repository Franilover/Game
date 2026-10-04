extends Node
class_name InteractionSystem


signal objetivo_cambiado(objetivo: Node)


@export var interaction_distance: float = 48.0
@export var scan_interval: float = 0.10


var player: Player = null
var inventory: GarliaInventory = null
var world_items: GarliaWorldItems = null
var input_gate: GameplayInputGate = null
var entity_manager: WorldEntityManager = null

var interaction_controller := InteractionController.new()
var objetivo_actual: Node = null

var _scan_timer: float = 0.0


func configurar(
	nuevo_player: Player,
	nuevo_inventory: GarliaInventory = null,
	nuevo_world_items: GarliaWorldItems = null,
	nuevo_input_gate: GameplayInputGate = null,
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

	# El objetivo contextual pierde validez en cuanto el jugador sale de alcance.
	# Esto se comprueba incluso si otra interfaz está bloqueando temporalmente la entrada.
	if objetivo_actual != null and not _objetivo_sigue_disponible():
		_cambiar_objetivo(null)

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
	var objeto_activo: Dictionary = {}
	if inventory != null:
		objeto_activo = inventory.obtener_objeto_activo().duplicate(true)

	return _procesar_interaccion_de_mano(objeto_activo, true)


func procesar_accion_secundaria() -> bool:
	var objeto_equipado: Dictionary = {}
	if inventory != null:
		objeto_equipado = inventory.obtener_objeto_equipado("mano_secundaria").duplicate(true)

	return _procesar_interaccion_de_mano(objeto_equipado, false)


func _procesar_interaccion_de_mano(objeto: Dictionary, permite_colocacion: bool) -> bool:
	if player == null or not player.is_alive:
		return false

	# Una mano ocupada usa su objeto. La interacción contextual sólo aparece
	# cuando esa mano está vacía. Ambas manos comparten exactamente esta ruta.
	if not objeto.is_empty():
		if permite_colocacion and world_items != null and world_items.es_objeto_colocable(objeto):
			var colocado: bool = world_items.colocar_objeto(
				objeto,
				player.get_global_mouse_position()
			)
			if colocado and inventory != null:
				inventory.consumir_objeto_activo(1)
				return true
		return false

	_buscar_objetivo()
	return interaction_controller.interactuar(player)


func _entrada_bloqueada_por_router() -> bool:
	if input_gate == null:
		return true
	return input_gate.esta_entrada_bloqueada(get_tree())


func _buscar_objetivo() -> void:
	interaction_controller.buscar_objetivo(
		player,
		interaction_distance
	)


func _objetivo_sigue_disponible() -> bool:
	if objetivo_actual == null or not is_instance_valid(objetivo_actual):
		return false
	if not objetivo_actual.is_inside_tree():
		return false
	if objetivo_actual.has_method("can_interact"):
		return bool(objetivo_actual.call("can_interact", player))
	if objetivo_actual is Node2D:
		return player.global_position.distance_to((objetivo_actual as Node2D).global_position) <= interaction_distance
	return false


func obtener_texto_interaccion() -> String:
	return interaction_controller.obtener_texto()


func _cambiar_objetivo(nuevo_objetivo: Node) -> void:
	if objetivo_actual == nuevo_objetivo:
		return

	objetivo_actual = nuevo_objetivo
	objetivo_cambiado.emit(objetivo_actual)

	if objetivo_actual == null:
		print("InteractionSystem: objetivo contextual = <ninguno>")
		return

	var texto := "Recoger"
	if objetivo_actual is Creature:
		texto = (objetivo_actual as Creature).get_interaction_text()

	print(
		"InteractionSystem: objetivo contextual = ",
		objetivo_actual.name,
		" | accion = ",
		texto
	)
