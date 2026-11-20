extends RefCounted
class_name CombatTargeting

## Consultas de combate. Nunca aplica daño.

static func es_atacante_valido(atacante: Node) -> bool:
	if atacante == null or not is_instance_valid(atacante):
		return false
	if not atacante is Entity:
		return false
	var entidad := atacante as Entity
	return entidad.is_inside_tree() and entidad.is_alive

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
