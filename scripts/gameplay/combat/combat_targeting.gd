extends RefCounted
class_name CombatTargeting

## Consultas de objetivos. Nunca aplica daño.

static func es_objetivo_valido(
	atacante: Node,
	objetivo: Node
) -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false
	if objetivo == atacante:
		return false
	if not objetivo.is_in_group("damageable"):
		return false
	if "is_alive" in objetivo and not bool(objetivo.get("is_alive")):
		return false
	return true
