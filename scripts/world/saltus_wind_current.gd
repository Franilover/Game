@tool
extends Area2D
## Corriente ambiental reutilizable: acelera al jugador dentro de su volumen.
signal body_affected(body: Node2D)

@export var direction: Vector2 = Vector2.UP
@export_range(0.0, 1800.0, 10.0) var acceleration: float = 520.0
@export_range(0.0, 900.0, 10.0) var max_speed: float = 360.0
@export var affects_group: StringName = &"saltus_player"

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(280.0, 190.0)
		shape_node.shape = rectangle
		add_child(shape_node)
	_crear_indicador()

func _physics_process(delta: float) -> void:
	var impulso := direction.normalized() * acceleration * delta
	for body in get_overlapping_bodies():
		if body == null or not body.is_in_group(affects_group):
			continue
		var velocidad: Vector2 = body.get("velocity")
		velocidad += impulso
		if direction.x != 0.0:
			velocidad.x = clampf(velocidad.x, -max_speed, max_speed)
		if direction.y != 0.0:
			velocidad.y = clampf(velocidad.y, -max_speed, max_speed)
		body.set("velocity", velocidad)
		body_affected.emit(body)

func _crear_indicador() -> void:
	if get_node_or_null("IndicadorCorriente") != null:
		return
	var indicador := Node2D.new()
	indicador.name = "IndicadorCorriente"
	add_child(indicador)
	for indice in range(3):
		var linea := Line2D.new()
		linea.width = 3.0
		linea.default_color = Color(0.78, 0.88, 0.66, 0.52)
		linea.points = PackedVector2Array([
			Vector2(-72.0, 30.0 + indice * 22.0),
			Vector2(-24.0, 8.0 + indice * 22.0),
			Vector2(24.0, 14.0 + indice * 22.0),
			Vector2(72.0, -8.0 + indice * 22.0)
		])
		linea.z_index = 3
		indicador.add_child(linea)
