@tool
extends Sprite2D

@export var target_size: Vector2 = Vector2(96.0, 96.0):
	set(value):
		target_size = value
		_fit_to_target()

func _ready() -> void:
	_fit_to_target()

func _fit_to_target() -> void:
	if texture == null or target_size.x <= 0.0 or target_size.y <= 0.0:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var factor := minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	scale = Vector2.ONE * factor
