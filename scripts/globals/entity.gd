extends CharacterBody2D
class_name Entity

@export var max_health: int = 100
@export var max_mana: int = 100

var health: int
var mana: int
var is_alive: bool = true

const PROFUNDIDAD_BASE: int = 1000

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal died


func _ready() -> void:
	health = max_health
	mana = max_mana

	add_to_group("damageable")
	_crear_hurtbox()
	_actualizar_profundidad()

	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)


func _process(_delta: float) -> void:
	_actualizar_profundidad()


func _actualizar_profundidad() -> void:
	# El punto de apoyo del personaje está unos píxeles por debajo
	# del origen. La profundidad se calcula con ese punto, no con
	# el centro visual del sprite.
	z_index = clampi(
		PROFUNDIDAD_BASE + int(global_position.y + 2.0),
		-4096,
		4096
	)


func _crear_hurtbox() -> void:
	if get_node_or_null("Hurtbox") != null:
		return

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return

	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	hurtbox.monitoring = true
	hurtbox.monitorable = true
	hurtbox.set_meta("damageable_owner", self)
	add_child(hurtbox)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = collision.shape.duplicate(true)
	shape.position = collision.position
	hurtbox.add_child(shape)

	print("Entity: Hurtbox creada → ", name)



func take_damage(cantidad: int) -> void:
	if not is_alive:
		return

	var dano_real: int = max(cantidad, 0)

	if dano_real <= 0:
		return

	health = max(health - dano_real, 0)

	health_changed.emit(health, max_health)

	print(
		name,
		" recibió ",
		dano_real,
		" de daño. Vida: ",
		health,
		"/",
		max_health
	)

	if health <= 0:
		_die()


func heal(cantidad: int) -> void:
	if not is_alive:
		return

	var curacion: int = max(cantidad, 0)

	if curacion <= 0:
		return

	health = min(health + curacion, max_health)
	health_changed.emit(health, max_health)


func _die() -> void:
	if not is_alive:
		return

	is_alive = false
	died.emit()

	print(name, " murió.")
