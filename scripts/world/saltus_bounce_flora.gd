extends Area2D
## Planta elástica reutilizable que impulsa al jugador al tocarla desde arriba.

const TEXTURE_PATH: String = "res://assets/art/kingdom/Saltus/2D Section/Flor Saltarina.png"
signal bounced(body: Node2D)

var _sprite: Sprite2D
var _bounce_tween: Tween

@export_range(-1200.0, -200.0, 10.0) var bounce_velocity: float = -610.0
@export var affects_group: StringName = &"saltus_player"

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_al_entrar_en_contacto)
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 22.0
		shape_node.shape = circle
		shape_node.position.y = -12.0
		add_child(shape_node)
	_crear_visual()

func _al_entrar_en_contacto(body: Node2D) -> void:
	if body == null or not body.is_in_group(affects_group):
		return
	var velocidad: Vector2 = body.get("velocity")
	if velocidad.y < 0.0:
		return
	if body.global_position.y > global_position.y + 20.0:
		return
	velocidad.y = bounce_velocity
	body.set("velocity", velocidad)
	bounced.emit(body)
	_animar_compresion()

func _crear_visual() -> void:
	 _sprite = Sprite2D.new()
	_sprite.name = "FlorSaltarinaSprite"
	_sprite.texture = load(TEXTURE_PATH) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2.0, 2.0)
	if _sprite.texture != null:
		_sprite.position.y = -_sprite.texture.get_height() * _sprite.scale.y * 0.5
	add_child(_sprite)
	if _sprite.texture == null:
		push_error("Saltus: no se pudo cargar " + TEXTURE_PATH)


func _animar_compresion() -> void:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		return
	if _bounce_tween != null and _bounce_tween.is_running():
		_bounce_tween.kill()
	var base := Vector2(2.0, 2.0)
	var altura := float(_sprite.texture.get_height())
	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_BACK)
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_sprite, "scale", Vector2(2.35, 1.45), 0.09)
	_bounce_tween.parallel().tween_property(_sprite, "position:y", -altura * 1.45, 0.09)
	_bounce_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_sprite, "scale", Vector2(1.72, 2.55), 0.13)
	_bounce_tween.parallel().tween_property(_sprite, "position:y", -altura * 2.55, 0.13)
	_bounce_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_sprite, "scale", base, 0.28)
	_bounce_tween.parallel().tween_property(_sprite, "position:y", -altura * 2.0, 0.28)
