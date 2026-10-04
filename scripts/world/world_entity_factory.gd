extends Node
class_name WorldEntityFactory

const CREATURE_SCENE: PackedScene = preload("res://scenes/creatures/creature.tscn")
const WORLD_PROP_SCENE: PackedScene = preload("res://scenes/world/world_prop.tscn")

var _player: Node = null
var _entity_manager: WorldEntityManager = null
var _inventory: GarliaInventory = null
var _combat_system: CombatSystem = null
var _dialogue_system: DialogueSystem = null
var _mission_manager: MissionManager = null
var _effects_root: Node = null
var _world_context: WorldContext = null
var _world_items: GarliaWorldItems = null
var _world_data: WorldDataService = null
var _relaciones_ecologicas: Array = []


func configurar_dependencias(
	jugador: Node,
	entity_manager: WorldEntityManager,
	inventario: GarliaInventory,
	combat_system: CombatSystem,
	dialogue_system: DialogueSystem,
	mission_manager: MissionManager,
	effects_root: Node,
	world_context: WorldContext,
	world_items: GarliaWorldItems,
	world_data: WorldDataService,
	relaciones_ecologicas: Array = []
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
	_relaciones_ecologicas = relaciones_ecologicas.duplicate(true)


func crear_criatura(data: Dictionary) -> Creature:
	var node := CREATURE_SCENE.instantiate() as Creature
	if node == null:
		push_error("WorldEntityFactory: no se pudo crear Creature.")
		return null

	node.configurar_dependencias(
		_player,
		_entity_manager,
		_inventory,
		_combat_system,
		_dialogue_system,
		_mission_manager,
		_effects_root,
		_world_items,
		_world_data,
		_relaciones_ecologicas
	)
	node.configurar(data)
	return node


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
	var node := WORLD_PROP_SCENE.instantiate() as WorldProp
	if node == null:
		push_error("WorldEntityFactory: no se pudo crear WorldProp.")
		return null
	node.configurar_dependencias(_world_context, _inventory, _world_items)
	node.configurar_desde_game_data(data)
	return node


func configurar_relaciones_ecologicas(relaciones_ecologicas: Array) -> void:
	_relaciones_ecologicas = relaciones_ecologicas.duplicate(true)
	if _entity_manager == null or not is_instance_valid(_entity_manager):
		return

	for entidad in _entity_manager.obtener_entidades_activas():
		if entidad is Creature:
			(entidad as Creature).configurar_relaciones_ecologicas(_relaciones_ecologicas)
