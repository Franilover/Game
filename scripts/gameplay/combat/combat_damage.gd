extends RefCounted
class_name CombatDamage

## Único punto de resolución de daño de gameplay.
## El estado vital pertenece a la entidad; defensa y otras reglas
## se aplican antes de entregar el daño a la entidad.

static func aplicar(
	objetivo: Entity,
	cantidad: int,
	origen: String,
	modificador: Callable = Callable()
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

	var salud_antes := -1
	if "health" in objetivo:
		salud_antes = int(objetivo.get("health"))

	objetivo.call("take_damage", dano, origen)

	if "health" in objetivo:
		var salud_despues := int(objetivo.get("health"))
		return salud_despues < salud_antes

	return true
