extends RefCounted
class_name CombatDamage

## Único punto de resolución de daño de gameplay.
## El estado vital pertenece a la entidad; defensa y otras reglas
## se aplican antes de entregar el daño a la entidad.

static func aplicar(
	objetivo: Entity,
	cantidad: int,
	origen: String,
	modificador: Callable = Callable(),
	atacante: Node = null
) -> bool:
	if objetivo == null or not is_instance_valid(objetivo):
		return false
	if not objetivo.is_alive:
		return false

	var dano := maxi(cantidad, 0)
	if modificador.is_valid():
		dano = maxi(int(modificador.call(dano)), 0)

	if dano <= 0:
		return false

	var salud_antes: int = objetivo.health
	if objetivo is Creature and atacante != null and is_instance_valid(atacante):
		(objetivo as Creature).take_damage_desde(atacante, dano, origen)
	else:
		objetivo.take_damage(dano, origen)
	return objetivo.health < salud_antes
