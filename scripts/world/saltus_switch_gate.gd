extends StaticBody2D
class_name SaltusSwitchGate
## Barrera del mundo que se retira cuando recibe la activación de una flor detectora.

signal opened

@export var gate_size: Vector2 = Vector2(28.0, 1100.0)
@export var gate_color: Color = Color("#596B4B")


func _ready() -> void:
	add_to_group("saltus_switch_targets")
	collision_layer = 1
	collision_mask = 0

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = gate_size
		shape_node.shape = rectangle
		add_child(shape_node)

	var visual := get_node_or_null("Visual") as Polygon2D
	if visual == null:
		visual = Polygon2D.new()
		visual.name = "Visual"
		visual.polygon = PackedVector2Array([
			Vector2(-gate_size.x * 0.5, -gate_size.y * 0.5),
			Vector2(gate_size.x * 0.5, -gate_size.y * 0.5),
			Vector2(gate_size.x * 0.5, gate_size.y * 0.5),
			Vector2(-gate_size.x * 0.5, gate_size.y * 0.5)
		])
		visual.color = gate_color
		add_child(visual)


func activate_from_switch(_flower: Node2D = null) -> void:
	if not is_inside_tree():
		return
	opened.emit()
	queue_free()
