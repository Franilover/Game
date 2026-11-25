extends Node
class_name SaltusWorldGraph

const ROOM_SCRIPT = preload("res://scripts/world/saltus_room_definition.gd")
const CONNECTION_SCRIPT = preload("res://scripts/world/saltus_world_connection.gd")

## Logical navigation graph for a seamless world. It does not load or unload rooms.
signal room_discovered(room_id: StringName)
signal connection_unlocked(connection_id: StringName)

@export var rooms: Array = []
@export var connections: Array = []

var _discovered_rooms: Dictionary = {}
var _unlocked_connections: Dictionary = {}


func _ready() -> void:
	_validar_grafo()


func get_room(room_id: StringName):
	for room in rooms:
		if room != null and room.room_id == room_id:
			return room
	return null


func get_room_at(world_position: Vector2):
	var room_found: Variant = null
	var smallest_area: float = INF
	for room in rooms:
		if room == null or not room.contains_point(world_position):
			continue
		var area: float = room.bounds.size.x * room.bounds.size.y
		if area < smallest_area:
			smallest_area = area
			room_found = room
	return room_found


func discover_room(room_id: StringName) -> bool:
	if get_room(room_id) == null or _discovered_rooms.has(room_id):
		return false
	_discovered_rooms[room_id] = true
	room_discovered.emit(room_id)
	return true


func is_room_discovered(room_id: StringName) -> bool:
	return _discovered_rooms.has(room_id)


func get_discovered_room_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for room_id in _discovered_rooms:
		result.append(StringName(str(room_id)))
	return result


func get_connections_for_room(
	room_id: StringName,
	include_locked: bool = true,
	abilities: Dictionary = {},
	world_flags: Dictionary = {}
) -> Array:
	var result: Array = []
	for connection in connections:
		if connection == null or not connection.connects_room(room_id):
			continue
		if not connection.allows_departure_from(room_id):
			continue
		if include_locked or can_traverse(connection.connection_id, room_id, abilities, world_flags):
			result.append(connection)
	return result


func can_traverse(
	connection_id: StringName,
	from_room_id: StringName,
	abilities: Dictionary = {},
	world_flags: Dictionary = {}
) -> bool:
	var connection: Variant = _get_connection(connection_id)
	if connection == null or not connection.allows_departure_from(from_room_id):
		return false
	if _unlocked_connections.has(connection_id):
		return true

	match connection.requirement_type:
		CONNECTION_SCRIPT.RequirementType.NONE:
			return true
		CONNECTION_SCRIPT.RequirementType.ABILITY:
			return bool(abilities.get(connection.requirement_key, false))
		CONNECTION_SCRIPT.RequirementType.WORLD_FLAG:
			return bool(world_flags.get(connection.requirement_key, false))
	return false


func get_destination(
	connection_id: StringName,
	from_room_id: StringName,
	abilities: Dictionary = {},
	world_flags: Dictionary = {}
) -> StringName:
	if not can_traverse(connection_id, from_room_id, abilities, world_flags):
		return &""
	var connection = _get_connection(connection_id)
	if connection == null:
		return &""
	return connection.get_destination_from(from_room_id)


func unlock_connection(connection_id: StringName) -> bool:
	if _get_connection(connection_id) == null:
		return false
	if _unlocked_connections.has(connection_id):
		return false
	_unlocked_connections[connection_id] = true
	connection_unlocked.emit(connection_id)
	return true


func is_connection_unlocked(connection_id: StringName) -> bool:
	return _unlocked_connections.has(connection_id)


func serialize_progress() -> Dictionary:
	var discovered: Array[String] = []
	var unlocked: Array[String] = []
	for room_id in _discovered_rooms:
		discovered.append(str(room_id))
	for connection_id in _unlocked_connections:
		unlocked.append(str(connection_id))
	discovered.sort()
	unlocked.sort()
	return {
		"discovered_rooms": discovered,
		"unlocked_connections": unlocked,
	}


func restore_progress(progress: Dictionary) -> void:
	_discovered_rooms.clear()
	_unlocked_connections.clear()

	var discovered: Variant = progress.get("discovered_rooms", [])
	if discovered is Array:
		for value in discovered:
			var room_id := StringName(str(value))
			if get_room(room_id) != null:
				_discovered_rooms[room_id] = true

	var unlocked: Variant = progress.get("unlocked_connections", [])
	if unlocked is Array:
		for value in unlocked:
			var connection_id := StringName(str(value))
			if _get_connection(connection_id) != null:
				_unlocked_connections[connection_id] = true


func _get_connection(connection_id: StringName):
	for connection in connections:
		if connection != null and connection.connection_id == connection_id:
			return connection
	return null


func _validar_grafo() -> void:
	var room_ids: Dictionary = {}
	for room in rooms:
		if room == null or not room.is_valid():
			push_warning("SaltusWorldGraph: hay una habitación nula o inválida.")
			continue
		if room_ids.has(room.room_id):
			push_warning("SaltusWorldGraph: ID de habitación duplicado: " + str(room.room_id))
		room_ids[room.room_id] = true

	var connection_ids: Dictionary = {}
	for connection in connections:
		if connection == null or not connection.is_valid():
			push_warning("SaltusWorldGraph: hay una conexión nula o inválida.")
			continue
		if connection_ids.has(connection.connection_id):
			push_warning("SaltusWorldGraph: ID de conexión duplicado: " + str(connection.connection_id))
		connection_ids[connection.connection_id] = true
		if not room_ids.has(connection.room_a) or not room_ids.has(connection.room_b):
			push_warning(
				"SaltusWorldGraph: conexión con habitación inexistente: "
				+ str(connection.connection_id)
			)
