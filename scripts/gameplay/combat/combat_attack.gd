extends RefCounted
class_name CombatAttack

## Instancia de una acción de combate.
## Describe el ataque; no decide cómo se aplica el daño.

var attacker: Entity = null
var direction: Vector2 = Vector2.DOWN
var object_data: Dictionary = {}
var mode: String = "melee"
var damage: int = 0
var origin: String = "Jugador/CombatController"

func configurar(
	attacker_node: Entity,
	attack_direction: Vector2,
	attack_object: Dictionary,
	attack_mode: String,
	attack_damage: int,
	attack_origin: String
) -> void:
	attacker = attacker_node
	direction = attack_direction
	object_data = attack_object.duplicate(true)
	mode = attack_mode
	damage = maxi(attack_damage, 0)
	origin = attack_origin
