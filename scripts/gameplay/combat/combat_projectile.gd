extends Area2D
class_name CombatProjectile

## Proyectil de combate.
## Su función es transportar una instancia de ataque hasta un objetivo.
## La resolución final del daño sigue pasando por CombatDamage.

var attack: CombatAttack
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 3.0

func configurar(nuevo_ataque: CombatAttack, direccion: Vector2, velocidad: float) -> void:
	attack = nuevo_ataque
	velocity = direccion.normalized() * velocidad

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func intentar_impactar(objetivo: Node) -> bool:
	if attack == null:
		return false
	if not CombatTargeting.es_objetivo_valido(attack.attacker, objetivo):
		return false
	if not CombatDamage.aplicar(objetivo, attack.damage, attack.origin):
		return false
	CombatFeedback.impacto(objetivo, attack.damage)
	queue_free()
	return true
