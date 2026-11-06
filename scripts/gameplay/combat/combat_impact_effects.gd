extends RefCounted
class_name CombatImpactEffects

## Efectos que suceden después de que CombatDamage confirma una reducción
## real de salud. Esta capa nunca modifica salud ni decide cuánto daño aplicar.

static func registrar_agresion_bosque(
	jugador: Node,
	criatura: Creature,
	asesinada: bool
) -> bool:
	if jugador == null or not is_instance_valid(jugador):
		return false
	if criatura == null or not is_instance_valid(criatura):
		return false

	var nombre := criatura.get_nombre().strip_edges().to_lower()
	if nombre not in ["feerin", "lignianos", "seiloris"]:
		return false

	jugador.set_meta("garlia_bosque_agresor", true)
	if asesinada:
		jugador.set_meta("garlia_bosque_asesino", true)
	return true


static func registrar_criatura_derrotada(
	game_state: Node,
	objetivo: Entity
) -> bool:
	if game_state == null or not is_instance_valid(game_state):
		return false
	if objetivo == null or not is_instance_valid(objetivo):
		return false
	if not game_state.has_method("registrar_criatura_derrotada"):
		return false
	var resultado: Variant = game_state.call("registrar_criatura_derrotada", objetivo)
	return bool(resultado)


static func obtener_ai_controller(objetivo: Node) -> CreatureAI:
	if objetivo == null or not is_instance_valid(objetivo):
		return null
	return objetivo.get_node_or_null("AIController") as CreatureAI


static func notificar_reaccion_ia(
	ai: CreatureAI,
	arma: Dictionary
) -> bool:
	if ai == null or not is_instance_valid(ai):
		return false
	if arma.is_empty():
		return false
	ai.al_recibir_ataque_con_arma(arma)
	return true


static func aplicar_feedback(objetivo: Node, cantidad: int) -> void:
	CombatFeedback.impacto(objetivo, cantidad)
