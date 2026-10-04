extends Node2D
class_name CombatAttackArea


signal objetivo_detectado(objetivo: Node)


var atacante: Node = null
var objeto_ataque: Dictionary = {}
var duracion: float = 0.10


var _afectados: Array[Node] = []
var _area: Area2D
var _visual: Polygon2D


func configurar(
	nuevo_atacante: Node,
	direccion: Vector2,
	alcance: float,
	ancho: float,
	objeto: Dictionary,
	duracion_ataque: float,
	color: Color
) -> void:
	atacante = nuevo_atacante
	objeto_ataque = objeto.duplicate(true)
	duracion = maxf(duracion_ataque, 0.01)

	_area = Area2D.new()
	_area.name = "Hitbox"
	_area.collision_layer = 0
	_area.collision_mask = 2
	_area.monitoring = true
	_area.monitorable = false
	_area.set_meta("damageable_owner", self)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"

	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(
		maxf(alcance, 1.0),
		maxf(ancho, 1.0)
	)

	shape.shape = rectangle
	shape.position = Vector2(
		8.0 + alcance * 0.5,
		0.0
	)

	_area.add_child(shape)
	add_child(_area)

	_visual = Polygon2D.new()
	_visual.name = "AttackVisual"

	var mitad := ancho * 0.5
	var inicio := 8.0
	var final := inicio + alcance

	_visual.polygon = PackedVector2Array([
		Vector2(inicio, -mitad),
		Vector2(final, -mitad),
		Vector2(final, mitad),
		Vector2(inicio, mitad)
	])
	_visual.color = color
	_visual.z_index = 100
	add_child(_visual)

	rotation = direccion.angle()

	_area.area_entered.connect(_al_entrar_area)


func _ready() -> void:
	if _area == null:
		return

	if _visual != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(
			_visual,
			"modulate:a",
			0.0,
			duracion
		)
		tween.tween_property(
			_visual,
			"scale",
			Vector2(1.08, 1.08),
			duracion
		)

	await get_tree().physics_frame
	_revisar_areas_existentes()

	await get_tree().create_timer(duracion).timeout

	if is_instance_valid(self):
		queue_free()


func _revisar_areas_existentes() -> void:
	if not is_instance_valid(_area):
		return

	for area_variant in _area.get_overlapping_areas():
		if area_variant is Area2D:
			_procesar_hurtbox(area_variant as Area2D)


func _al_entrar_area(hurtbox: Area2D) -> void:
	_procesar_hurtbox(hurtbox)


func _procesar_hurtbox(hurtbox: Area2D) -> void:
	if hurtbox == null or not is_instance_valid(hurtbox):
		return

	var objetivo_variant: Variant = hurtbox.get_meta(
		"damageable_owner",
		null
	)

	if not objetivo_variant is Node:
		return

	var objetivo := objetivo_variant as Node

	if objetivo == atacante or not is_instance_valid(objetivo):
		return

	if objetivo in _afectados:
		return

	if not objetivo.is_in_group("damageable"):
		return

	if "is_alive" in objetivo and not bool(objetivo.get("is_alive")):
		return

	_afectados.append(objetivo)
	objetivo_detectado.emit(objetivo)
