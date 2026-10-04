extends Area2D
class_name CombatProjectile

## Proyectil de combate.
## Transporta una instancia de ataque y resuelve el impacto mediante
## la capa canónica CombatDamage. No busca objetivos en el SceneTree.

signal objetivo_impactado(objetivo: Node, ataque: CombatAttack)

var attack: CombatAttack = null
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 3.0

var _collision_shape: CollisionShape2D = null
var _impactado: bool = false

func configurar(nuevo_ataque: CombatAttack, direccion: Vector2, velocidad: float, vida: float, radio: float) -> void:
	attack = nuevo_ataque
	var direccion_normalizada := direccion.normalized()
	if direccion_normalizada.length_squared() <= 0.0001:
		direccion_normalizada = Vector2.RIGHT
	velocity = direccion_normalizada * maxf(velocidad, 0.0)
	lifetime = maxf(vida, 0.01)
	rotation = direccion_normalizada.angle()
	_configurar_colision(maxf(radio, 1.0))

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_al_entrar_cuerpo)
	area_entered.connect(_al_entrar_area)

func _physics_process(delta: float) -> void:
	if _impactado:
		return
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _configurar_colision(radio: float) -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
	var shape := CircleShape2D.new()
	shape.radius = radio
	_collision_shape.shape = shape

func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	_procesar_objetivo(cuerpo)

func _al_entrar_area(area: Area2D) -> void:
	if area == null or not is_instance_valid(area):
		return
	var objetivo_variant: Variant = area.get_meta("damageable_owner", null)
	if objetivo_variant is Node:
		_procesar_objetivo(objetivo_variant as Node)

func _procesar_objetivo(objetivo: Node) -> void:
	if _impactado or attack == null:
		return
	if not CombatTargeting.es_objetivo_valido(attack.attacker, objetivo):
		return
	if not CombatDamage.aplicar(objetivo, attack.damage, attack.origin):
		return
	_impactado = true
	objetivo_impactado.emit(objetivo, attack)
	CombatFeedback.impacto(objetivo, attack.damage)
	queue_free()
