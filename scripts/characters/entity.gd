extends CharacterBody2D
class_name Entity

@export var max_health: int = 100
@export var max_mana: int = 100

var health: int = 100
var mana: int = 100
var is_alive: bool = true

const PROFUNDIDAD_BASE: int = 1000

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal died

var vital_state := VitalState.new()
var _ultima_y_profundidad: int = 2147483647

func _ready() -> void:
	_configurar_estado_vital()
	add_to_group("damageable")
	_crear_hurtbox()
	_actualizar_profundidad()
	_emitir_estado_vital()

func _process(_delta: float) -> void:
	# La profundidad solo cambia cuando cambia Y.
	var y_actual := int(global_position.y + 2.0)
	if y_actual == _ultima_y_profundidad:
		return
	_ultima_y_profundidad = y_actual
	_actualizar_profundidad()

func _configurar_estado_vital() -> void:
	vital_state.configurar(max_health, max_mana)
	_sync_desde_vital()

func _sync_desde_vital() -> void:
	health = vital_state.health
	mana = vital_state.mana
	is_alive = vital_state.is_alive

func _emitir_estado_vital() -> void:
	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)

func _actualizar_profundidad() -> void:
	_ultima_y_profundidad = int(global_position.y + 2.0)
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

func take_damage(cantidad: int, origen: String = "desconocido") -> void:
	if not is_alive:
		return

	var dano_real := vital_state.recibir_danio(cantidad)
	if dano_real <= 0:
		return

	_sync_desde_vital()
	health_changed.emit(health, max_health)

	print(
		"Damage: ",
		origen,
		" → ",
		name,
		" | -",
		dano_real,
		" | Vida: ",
		health,
		"/",
		max_health
	)

	if not is_alive:
		_die()

func heal(cantidad: int) -> void:
	if not is_alive:
		return

	var curacion := vital_state.curar(cantidad)
	if curacion <= 0:
		return

	_sync_desde_vital()
	health_changed.emit(health, max_health)

func _die() -> void:
	if not is_alive:
		return

	is_alive = false
	vital_state.is_alive = false
	died.emit()

	print(name, " murió.")
