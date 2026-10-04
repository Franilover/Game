extends RefCounted
class_name CombatDamage

## Único punto de resolución de daño de gameplay.
## El estado vital pertenece a la entidad; las reglas de combate pasan por aquí.

static func aplicar(objetivo: Node, cantidad: int, origen: String) -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false
	if not objetivo.has_method("take_damage"):
		return false
	if "is_alive" in objetivo and not bool(objetivo.get("is_alive")):
		return false

	var dano := maxi(cantidad, 0)
	if dano <= 0:
		return false

	objetivo.call("take_damage", dano, origen)
	return true

static func aplicar_con_resolucion(
	objetivo: Node,
	cantidad: int,
	origen: String,
	modificador: Callable
) -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false
	if not objetivo.has_method("take_damage"):
		return false
	if "is_alive" in objetivo and not bool(objetivo.get("is_alive")):
		return false

	var dano := maxi(cantidad, 0)
	if modificador.is_valid():
		dano = maxi(int(modificador.call(dano)), 0)

	if dano <= 0:
		return false

	objetivo.call("take_damage", dano, origen)
	return true
