extends RefCounted
class_name CombatTargeting

## Consultas de objetivos. Nunca aplica daño.

static func es_objetivo_valido(
	atacante: Node,
	objetivo: Entity
) -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false
	if objetivo == atacante:
		return false
	if not objetivo.is_in_group("damageable"):
		return false
	if not objetivo.is_alive:
		return false
	return true
