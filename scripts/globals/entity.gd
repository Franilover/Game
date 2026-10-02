extends CharacterBody2D
class_name Entity

@export var max_health: int = 100
@export var max_mana: int = 100

var health: int
var mana: int
var is_alive: bool = true

signal health_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal died


func _ready() -> void:
	health = max_health
	mana = max_mana

	add_to_group("damageable")

	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)


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
