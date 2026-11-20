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
	return aplicar_y_obtener_danio(objetivo, cantidad, origen, modificador, atacante) > 0


static func aplicar_y_obtener_danio(
	objetivo: Entity,
	cantidad: int,
	origen: String,
	modificador: Callable = Callable(),
	atacante: Node = null
) -> int:
	if objetivo == null or not is_instance_valid(objetivo):
		return 0
	if not objetivo.is_inside_tree() or objetivo.is_queued_for_deletion():
		return 0
	# El resolver es la última frontera: ningún llamador puede convertir
	# una entidad no combatiente en objetivo por omitir CombatTargeting.
	if not objetivo.is_in_group("damageable"):
		return 0
	if not objetivo.is_alive:
		return 0
	# Si se atribuye el golpe a una entidad, también debe ser un atacante
	# operativo. null queda reservado para daño ambiental o sin atribución.
	if atacante != null and not CombatTargeting.es_atacante_valido(atacante):
		return 0

	var dano := maxi(cantidad, 0)
	if modificador.is_valid():
		dano = maxi(int(modificador.call(dano)), 0)

	if dano <= 0:
		return 0

	# El modificador es código externo y puede provocar señales, muerte o
	# queue_free() del objetivo. Revalidar antes de tocar su estado vital.
	if not is_instance_valid(objetivo):
		return 0
	if not objetivo.is_inside_tree() or objetivo.is_queued_for_deletion():
		return 0
	if not objetivo.is_in_group("damageable") or not objetivo.is_alive:
		return 0
	if atacante != null and not CombatTargeting.es_atacante_valido(atacante):
		return 0

	if objetivo is Creature and atacante != null and is_instance_valid(atacante):
		return (objetivo as Creature).take_damage_desde(atacante, dano, origen)
	return objetivo.take_damage(dano, origen)
