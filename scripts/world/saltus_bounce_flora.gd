extends Area2D
## Planta elástica reutilizable que impulsa al jugador al tocarla desde arriba.
signal bounced(body: Node2D)

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
		shape_node.position.y = -5.0
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

func _crear_visual() -> void:
	var tallo := Line2D.new()
	tallo.width = 4.0
	tallo.default_color = Color("#718C4C")
	tallo.points = PackedVector2Array([Vector2(0.0, 12.0), Vector2(0.0, -9.0)])
	add_child(tallo)
	for indice in range(5):
		var angulo := TAU * float(indice) / 5.0
		var petalo := Polygon2D.new()
		petalo.color = Color("#C3D68A")
		petalo.polygon = PackedVector2Array([
			Vector2(0.0, -5.0), Vector2(7.0, -17.0),
			Vector2(0.0, -27.0), Vector2(-7.0, -17.0)
		])
		petalo.position = Vector2(cos(angulo) * 9.0, sin(angulo) * 5.0 - 12.0)
		petalo.rotation = angulo
		add_child(petalo)
