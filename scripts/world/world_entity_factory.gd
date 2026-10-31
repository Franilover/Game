extends Node
class_name WorldEntityFactory

const CREATURE_SCENE: PackedScene = preload("res://scenes/creatures/creature.tscn")
const GARUMI_SCENE: PackedScene = preload("res://scenes/creatures/garumi.tscn")
const WORLD_PROP_SCENE: PackedScene = preload("res://scenes/world/world_prop.tscn")

var _player: Node = null
var _entity_manager: WorldEntityManager = null
var _inventory: GarliaInventory = null
var _combat_system: CombatSystem = null
var _dialogue_system: DialogueSystem = null
var _mission_manager: MissionManagerService = null
var _effects_root: Node = null
var _world_context: WorldContext = null
var _world_items: GarliaWorldItems = null
var _world_data: WorldDataService = null
var _world_atmosphere: WorldAtmosphere = null
var _relaciones_ecologicas: Array = []
var _creature_pool: Array[Creature] = []
var _garumi_pool: Array[Garumi] = []
var _prop_pool: Array[WorldProp] = []


func configurar_dependencias(
	jugador: Node,
	entity_manager: WorldEntityManager,
	inventario: GarliaInventory,
	combat_system: CombatSystem,
	dialogue_system: DialogueSystem,
	mission_manager: MissionManagerService,
	effects_root: Node,
	world_context: WorldContext,
	world_items: GarliaWorldItems,
	world_data: WorldDataService,
	relaciones_ecologicas: Array = [],
	world_atmosphere: WorldAtmosphere = null
) -> void:
	_player = jugador
	_entity_manager = entity_manager
	_inventory = inventario
	_combat_system = combat_system
	_dialogue_system = dialogue_system
	_mission_manager = mission_manager
	_effects_root = effects_root
	_world_context = world_context
	_world_items = world_items
	_world_data = world_data
	_world_atmosphere = world_atmosphere
	_relaciones_ecologicas = relaciones_ecologicas.duplicate(true)


func crear_criatura(data: Dictionary) -> Creature:
	var es_garumi := str(data.get("categoria_entidad", "")).strip_edges().to_lower() == "garumi"
	var node: Creature = _tomar_garumi_del_pool() if es_garumi else _tomar_criatura_del_pool()
	if node == null:
		if es_garumi:
			node = GARUMI_SCENE.instantiate() as Garumi
		else:
			node = CREATURE_SCENE.instantiate() as Creature
	if node == null:
		push_error("WorldEntityFactory: no se pudo crear Creature.")
		return null

	node.configurar_dependencias(
		_dialogue_system,
		_mission_manager,
		_effects_root,
		_world_items,
		_world_data,
		_relaciones_ecologicas
	)
	node.configurar_dependencias_ia(
		_player,
		_entity_manager,
		_inventory,
		_combat_system,
		_world_items,
		_relaciones_ecologicas,
		_world_atmosphere
	)
	node.configurar(data)
	node.activar_como_proxy()
	return node


func reciclar_criatura(node: Creature) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.desactivar_como_proxy()
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	if node is Garumi:
		if not node in _garumi_pool:
			_garumi_pool.append(node as Garumi)
	else:
		if not node in _creature_pool:
			_creature_pool.append(node)


func _tomar_criatura_del_pool() -> Creature:
	while not _creature_pool.is_empty():
		var node: Creature = _creature_pool.pop_back() as Creature
		if node != null and is_instance_valid(node):
			return node
	return null


func _tomar_garumi_del_pool() -> Garumi:
	while not _garumi_pool.is_empty():
		var node: Garumi = _garumi_pool.pop_back()
		if node != null and is_instance_valid(node):
			return node
	return null


func crear_personaje(
	data: Dictionary,
	dialogo: Array = []
) -> Creature:
	var criatura_data := data.duplicate(true)
	if not dialogo.is_empty():
		criatura_data["dialogo"] = dialogo
	else:
		criatura_data.erase("dialogo")

	return crear_criatura(criatura_data)


func crear_prop(data: Dictionary) -> WorldProp:
	var node: WorldProp = _tomar_prop_del_pool()
	if node == null:
		node = WORLD_PROP_SCENE.instantiate() as WorldProp
	if node == null:
		push_error("WorldEntityFactory: no se pudo crear WorldProp.")
		return null
	var inventory_prop := null if GarliaMultiplayer.es_servidor_dedicado() else _inventory
	var world_items_prop := null if GarliaMultiplayer.es_servidor_dedicado() else _world_items
	node.configurar_dependencias(_world_context, inventory_prop, world_items_prop)
	node.configurar_desde_game_data(data)
	node.activar_como_proxy()
	if GarliaWorldNetwork.es_cliente_en_mundo_global():
		node.ocultar_replica_red_cliente()
	return node


func reciclar_prop(node: WorldProp) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.desactivar_como_proxy()
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	if not node in _prop_pool:
		_prop_pool.append(node)


func _tomar_prop_del_pool() -> WorldProp:
	while not _prop_pool.is_empty():
		var node: WorldProp = _prop_pool.pop_back() as WorldProp
		if node != null and is_instance_valid(node):
			return node
	return null


func configurar_relaciones_ecologicas(relaciones_ecologicas: Array) -> void:
	_relaciones_ecologicas = relaciones_ecologicas.duplicate(true)
	if _entity_manager == null or not is_instance_valid(_entity_manager):
		return

	for entidad in _entity_manager.obtener_entidades_activas():
		if entidad is Creature:
			(entidad as Creature).configurar_relaciones_ecologicas(_relaciones_ecologicas)
