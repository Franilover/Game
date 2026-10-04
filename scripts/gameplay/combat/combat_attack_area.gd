extends Node2D
class_name CombatAttackArea


signal objetivo_detectado(objetivo: Entity)


var atacante: Entity = null
var objeto_ataque: Dictionary = {}
var duracion: float = 0.10


var _afectados: Array[Node] = []
var _area: Area2D
var _visual: Polygon2D
var _contorno: Line2D


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
	_visual.z_as_relative = true
	add_child(_visual)

	_contorno = Line2D.new()
	_contorno.name = "AttackOutline"
	_contorno.width = 2.0
	_contorno.default_color = Color(
		color.r,
		color.g,
		color.b,
		minf(color.a + 0.25, 1.0)
	)
	_contorno.z_index = 101
	_contorno.z_as_relative = true
	_contorno.closed = true
	_contorno.points = PackedVector2Array([
		Vector2(inicio, -mitad),
		Vector2(final, -mitad),
		Vector2(final, mitad),
		Vector2(inicio, mitad)
	])
	add_child(_contorno)

	rotation = direccion.angle()

	_area.area_entered.connect(_al_entrar_area)
	_area.body_entered.connect(_al_entrar_cuerpo)


func _ready() -> void:
	if _area == null:
		return

	if _visual != null or _contorno != null:
		var tween := create_tween()
		tween.set_parallel(true)

		if _visual != null:
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

		if _contorno != null:
			tween.tween_property(
				_contorno,
				"modulate:a",
				0.0,
				duracion
			)
			tween.tween_property(
				_contorno,
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

	for body_variant in _area.get_overlapping_bodies():
		if body_variant is Node:
			_procesar_objetivo(body_variant as Node)


func _al_entrar_area(hurtbox: Area2D) -> void:
	_procesar_hurtbox(hurtbox)


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	_procesar_objetivo(cuerpo)


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

	_procesar_objetivo(objetivo)


func _procesar_objetivo(objetivo: Node) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return

	var entidad: Entity = objetivo as Entity
	if entidad == null:
		return
	if not CombatTargeting.es_objetivo_valido(atacante, entidad):
		return

	if entidad in _afectados:
		return

	_afectados.append(entidad)
	print(
		"CombatAttackArea: objetivo detectado → ",
		objetivo.name
	)
	objetivo_detectado.emit(objetivo)
