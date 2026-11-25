extends Resource
class_name SaltusWorldConnection

enum RequirementType {
	NONE,
	ABILITY,
	WORLD_FLAG,
}

@export var connection_id: StringName = &""
@export var room_a: StringName = &""
@export var room_b: StringName = &""
@export var one_way_from_a: bool = false
@export var requirement_type: RequirementType = RequirementType.NONE
@export var requirement_key: StringName = &""


func is_valid() -> bool:
	if connection_id.is_empty() or room_a.is_empty() or room_b.is_empty():
		return false
	if room_a == room_b:
		return false
	if requirement_type != RequirementType.NONE and requirement_key.is_empty():
		return false
	return true


func connects_room(room_id: StringName) -> bool:
	return room_id == room_a or room_id == room_b


func allows_departure_from(room_id: StringName) -> bool:
	if room_id == room_a:
		return true
	return room_id == room_b and not one_way_from_a


func get_destination_from(room_id: StringName) -> StringName:
	if room_id == room_a:
		return room_b
	if room_id == room_b and not one_way_from_a:
		return room_a
	return &""
