extends Node2D
class_name CombatAttackArea


signal objetivo_detectado(objetivo: Entity)


var atacante: Entity = null
var objeto_ataque: Dictionary = {}
var duracion: float = 0.10


var _afectados: Array[Node] = []
var _area: Area2D


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
	_area.collision_mask = 6 # Hurtboxes (capa 2) y cuerpos de criaturas Saltus (capa 4).
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


	rotation = direccion.angle()

	_area.area_entered.connect(_al_entrar_area)
	_area.body_entered.connect(_al_entrar_cuerpo)


func _physics_process(_delta: float) -> void:
	if not CombatTargeting.es_atacante_valido(atacante):
		queue_free()


func _ready() -> void:
	if _area == null:
		return

	# La hitbox permanece activa para detectar impactos, pero no se dibuja.
	# La animación del arma es el único feedback visual del golpe.
	await get_tree().physics_frame
	if not is_instance_valid(self) or not CombatTargeting.es_atacante_valido(atacante):
		if is_instance_valid(self):
			queue_free()
		return
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
	if not CombatTargeting.es_atacante_valido(atacante):
		queue_free()
		return
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
