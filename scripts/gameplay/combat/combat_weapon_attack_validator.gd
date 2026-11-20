extends RefCounted
class_name CombatWeaponAttackValidator

## Valida solicitudes de ataque con arma sin ejecutar acciones ni modificar estado.

const COMBAT_ITEM_RESOLVER: Script = preload(
	"res://scripts/gameplay/combat/combat_item_resolver.gd"
)


static func validar(
	atacante: Node,
	objetivo: Entity,
	arma: Dictionary
) -> StringName:
	if not CombatTargeting.es_atacante_valido(atacante):
		return &"atacante_invalido"
	if (
		objetivo == null
		or not is_instance_valid(objetivo)
		or objetivo == atacante
		or not objetivo.is_inside_tree()
		or objetivo.is_queued_for_deletion()
	):
		return &"objetivo_invalido"
	if not objetivo.is_in_group("damageable"):
		return &"objetivo_no_daniable"
	if not objetivo.is_alive:
		return &"objetivo_derrotado"
	if arma.is_empty():
		return &"arma_vacia"
	if not COMBAT_ITEM_RESOLVER.es_arma(arma):
		return &"objeto_no_es_arma"
	return &""
