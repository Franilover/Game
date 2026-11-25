extends Resource
class_name SaltusRoomDefinition

## Logical room bounds in world coordinates. Rooms remain part of one continuous world.
@export var room_id: StringName = &""
@export var region_id: StringName = &""
@export var bounds: Rect2 = Rect2()
@export var tags: PackedStringArray = PackedStringArray()


func is_valid() -> bool:
	return not room_id.is_empty() and bounds.size.x > 0.0 and bounds.size.y > 0.0


func contains_point(world_position: Vector2) -> bool:
	return is_valid() and bounds.has_point(world_position)
