extends RefCounted
class_name CombatDamage

## Única frontera de resolución de daño del gameplay.
## Entity decide cómo recibe el daño; este objeto decide quién lo solicita.

static func aplicar(
	objetivo: Node,
	cantidad: int,
	origen: String
) -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false

	if not objetivo.has_method("take_damage"):
		return false

	if "is_alive" in objetivo and not bool(objetivo.get("is_alive")):
		return false

	objetivo.call("take_damage", cantidad, origen)
	return true
