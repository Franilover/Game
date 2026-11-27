extends Area2D
class_name CombatProjectile

const FLECHA_MADERA_TEXTURE: Texture2D = preload("res://assets/art/items/Flecha de Madera.png")

## Proyectil de combate.
## Transporta una instancia de ataque y ejecuta su impacto mediante el
## resolver compartido CombatDamage. No implementa reglas de daño propias
## ni busca objetivos en el SceneTree. CombatSystem consume sus señales
## para feedback y efectos confirmados.

signal contacto_detectado(objetivo: Entity, ataque: CombatAttack)
signal objetivo_impactado(objetivo: Entity, ataque: CombatAttack)

var attack: CombatAttack = null
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 3.0

var _collision_shape: CollisionShape2D = null
var _impactado: bool = false
var _sprite_proyectil: Sprite2D = null

func configurar(nuevo_ataque: CombatAttack, direccion: Vector2, velocidad: float, vida: float, radio: float) -> void:
	attack = nuevo_ataque
	var direccion_normalizada := direccion.normalized()
	if direccion_normalizada.length_squared() <= 0.0001:
		direccion_normalizada = Vector2.RIGHT
	velocity = direccion_normalizada * maxf(velocidad, 0.0)
	lifetime = maxf(vida, 0.01)
	rotation = direccion_normalizada.angle()
	_configurar_colision(maxf(radio, 1.0))
	if is_instance_valid(_sprite_proyectil):
		_sprite_proyectil.rotation = 0.0

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	_crear_sprite_proyectil()
	body_entered.connect(_al_entrar_cuerpo)
	area_entered.connect(_al_entrar_area)

func _physics_process(delta: float) -> void:
	if _impactado:
		return
	if attack == null or not CombatTargeting.es_atacante_valido(attack.attacker):
		_cancelar_por_atacante_invalido()
		return
	var desplazamiento := velocity * delta
	if desplazamiento.length_squared() > 0.0001:
		# El movimiento manual de Area2D puede atravesar hurtboxes pequeñas
		# cuando una propiedad de arma eleva mucho la velocidad. El barrido
		# consulta el segmento completo antes de mover el proyectil.
		var consulta := PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + desplazamiento,
			collision_mask
		)
		consulta.collide_with_areas = true
		consulta.collide_with_bodies = true
		if attack.attacker is CollisionObject2D:
			consulta.exclude = [(attack.attacker as CollisionObject2D).get_rid()]
		var impacto := get_world_2d().direct_space_state.intersect_ray(consulta)
		if not impacto.is_empty():
			var collider: Variant = impacto.get("collider")
			if collider is Area2D:
				_al_entrar_area(collider as Area2D)
			elif collider is Node:
				_procesar_objetivo(collider as Node)
			if _impactado:
				return
		global_position += desplazamiento
	lifetime -= delta
	if lifetime <= 0.0:
		_finalizar()

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
	if not CombatTargeting.es_atacante_valido(attack.attacker):
		_cancelar_por_atacante_invalido()
		return
	var entidad: Entity = objetivo as Entity
	if entidad == null:
		return
	if not CombatTargeting.es_objetivo_valido(attack.attacker, entidad):
		return

	# El contacto es un resultado independiente del daño. Un bloqueo de daño
	# o una capacidad de daño cero no debe dejar vivo al mismo proyectil.
	_impactado = true
	contacto_detectado.emit(entidad, attack)

	# Los listeners de contacto pueden cambiar el estado de combate de forma
	# síncrona. No se aplica daño si el atacante murió durante esa señal.
	if not CombatTargeting.es_atacante_valido(attack.attacker):
		_finalizar()
		return
	if not is_instance_valid(entidad) or not entidad.is_alive:
		_finalizar()
		return

	# objetivo_impactado conserva su contrato histórico: solo se emite cuando
	# CombatDamage confirma una reducción real de salud.
	var danio_real := CombatDamage.aplicar_y_obtener_danio(
		entidad,
		attack.damage,
		attack.origin,
		Callable(),
		attack.attacker
	)
	if danio_real > 0:
		# El ataque transporta el resultado del impacto para que los efectos
		# posteriores y las señales no confundan daño bruto con daño efectivo.
		attack.damage = danio_real
		objetivo_impactado.emit(entidad, attack)

	# El feedback corresponde al consumidor del resultado, no al proyectil;
	# así evitamos aplicar dos veces el mismo flash visual.
	_finalizar()


func _cancelar_por_atacante_invalido() -> void:
	_finalizar()


func _finalizar() -> void:
	# El cierre es idempotente y bloquea callbacks de colisión restantes
	# durante el frame en que se solicita queue_free().
	_impactado = true
	if is_inside_tree():
		set_deferred("monitoring", false)
	queue_free()


func _crear_sprite_proyectil() -> void:
	if is_instance_valid(_sprite_proyectil):
		return
	_sprite_proyectil = Sprite2D.new()
	_sprite_proyectil.name = "FlechaMadera"
	_sprite_proyectil.texture = FLECHA_MADERA_TEXTURE
	_sprite_proyectil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_proyectil.centered = true
	_sprite_proyectil.scale = Vector2.ONE
	_sprite_proyectil.z_index = 1
	add_child(_sprite_proyectil)
