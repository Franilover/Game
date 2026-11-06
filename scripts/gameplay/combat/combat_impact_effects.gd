extends RefCounted
class_name CombatImpactEffects

## Efectos que suceden después de que CombatDamage confirma una reducción
## real de salud. Esta capa nunca modifica salud ni decide cuánto daño aplicar.

static func procesar_impacto_confirmado(
	game_state: Node,
	jugador: Node,
	atacante: Node,
	objetivo: Entity,
	cantidad: int,
	arma: Dictionary = {}
) -> Dictionary:
	if objetivo == null or not is_instance_valid(objetivo):
		return {}

	var es_criatura := objetivo.is_in_group("creatures")
	var atacante_es_jugador := _es_jugador(atacante)
	var agresion_ecologica := false
	var derrota_registrada := false
	var eterium_absorbido := 0
	var reaccion_ia := false

	if atacante_es_jugador and objetivo is Creature:
		agresion_ecologica = registrar_agresion_bosque(
			jugador,
			objetivo as Creature,
			not objetivo.is_alive
		)

	if es_criatura and not objetivo.is_alive:
		derrota_registrada = registrar_criatura_derrotada(
			game_state,
			objetivo
		)

		if atacante_es_jugador and objetivo is Creature:
			var receptor_eterium: Node = atacante
			if not receptor_eterium.has_method("absorber_eterium_de_criatura"):
				receptor_eterium = jugador
			if (
				receptor_eterium != null
				and is_instance_valid(receptor_eterium)
				and receptor_eterium.has_method("absorber_eterium_de_criatura")
			):
				eterium_absorbido = int(
					receptor_eterium.call("absorber_eterium_de_criatura", objetivo)
				)

	if es_criatura and objetivo.is_alive and not arma.is_empty():
		var ai := obtener_ai_controller(objetivo)
		if ai != null:
			reaccion_ia = notificar_reaccion_ia(ai, arma)

	aplicar_feedback(objetivo, cantidad)

	return {
		"agresion_ecologica": agresion_ecologica,
		"derrota_registrada": derrota_registrada,
		"eterium_absorbido": eterium_absorbido,
		"reaccion_ia": reaccion_ia
	}


static func _es_jugador(atacante: Node) -> bool:
	if atacante == null or not is_instance_valid(atacante):
		return false
	return atacante is Player or atacante.is_in_group("player")


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
