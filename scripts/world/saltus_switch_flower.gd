extends Area2D
class_name SaltusSwitchFlower
## Flor sensora: detecta al jugador y activa los mecanismos conectados.

signal activated(flower: Node2D)

const TEXTURE_PATH: String = "res://assets/art/kingdom/Saltus/2D Section/Flor Detectora.png"

@export var player_group: StringName = &"saltus_player"
@export var target_group: StringName = &"saltus_switch_targets"
@export var one_shot: bool = true

var is_activated: bool = false
var _sprite: Sprite2D


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_al_detectar_cuerpo)

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 28.0
		shape_node.shape = circle
		shape_node.position = Vector2(0.0, -16.0)
		add_child(shape_node)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.texture = load(TEXTURE_PATH) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2.0, 2.0)
	if _sprite.texture != null:
		_sprite.position.y = -_sprite.texture.get_height() * _sprite.scale.y * 0.5
	add_child(_sprite)
	if _sprite.texture == null:
		push_error("Saltus: no se pudo cargar " + TEXTURE_PATH)


func _al_detectar_cuerpo(body: Node2D) -> void:
	if body == null or not body.is_in_group(player_group):
		return
	if one_shot and is_activated:
		return

	is_activated = true
	if is_instance_valid(_sprite):
		_sprite.modulate = Color(0.78, 1.0, 0.72, 1.0)

	activated.emit(self)
	for target in get_tree().get_nodes_in_group(target_group):
		if is_instance_valid(target) and target.has_method("activate_from_switch"):
			target.call("activate_from_switch", self)


func reset_switch() -> void:
	is_activated = false
	if is_instance_valid(_sprite):
		_sprite.modulate = Color.WHITE
