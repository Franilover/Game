extends Node


class FakeGameState:
	extends Node

	var criaturas_registradas: Array[Node] = []

	func registrar_criatura_derrotada(criatura: Node) -> bool:
		if criatura == null:
			return false
		criaturas_registradas.append(criatura)
		return true


class FakePlayer:
	extends Node

	var absorciones: int = 0

	func absorber_eterium_de_criatura(_criatura: Node) -> int:
		absorciones += 1
		return 4


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	_probar_impacto_letal_de_jugador(errores)
	_probar_reaccion_a_arma(errores)
	_probar_muerte_causada_por_criatura(errores)
	_probar_seguridad_de_dependencias(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatImpactEffects: FAIL: " + error)
		get_tree().quit(1)
		return

	print("CombatImpactEffects: PASS")
	get_tree().quit(0)


func _probar_impacto_letal_de_jugador(errores: Array[String]) -> void:
	var jugador := FakePlayer.new()
	jugador.add_to_group("player")
	var game_state := FakeGameState.new()
	var feerin := Creature.new()
	feerin
	feerin.criatura_nombre = "Feerin"
	feerin.add_to_group("creatures")
	feerin.is_alive = false
	feerin.health = 0
	var salud_antes := feerin.health
	var resultado := CombatImpactEffects.procesar_impacto_confirmado(
		game_state,
		jugador,
		jugador,
		feerin,
		12,
		{"nombre": "Arco"}
	)

	if not bool(resultado.get("agresion_ecologica", false)):
		errores.append("El impacto del jugador no registró agresión ecológica.")
	if not bool(resultado.get("derrota_registrada", false)):
		errores.append("El impacto letal no registró la derrota.")
	if int(resultado.get("eterium_absorbido", 0)) != 4:
		errores.append("El impacto letal no devolvió el Eterium absorbido.")
	if not jugador.has_meta("garlia_bosque_agresor") or not jugador.has_meta("garlia_bosque_asesino"):
		errores.append("No conservó ambos marcadores ecológicos al derrotar a Feerin.")
	if jugador.absorciones != 1:
		errores.append("El jugador no absorbió exactamente una vez por el impacto.")
	if game_state.criaturas_registradas.size() != 1:
		errores.append("El objetivo derrotado no se registró exactamente una vez.")
	if feerin.health != salud_antes:
		errores.append("Los efectos posteriores modificaron la salud del objetivo.")

	game_state.free()
	jugador.free()
	feerin.free()


func _probar_reaccion_a_arma(errores: Array[String]) -> void:
	var objetivo := Creature.new()
	objetivo.add_to_group("creatures")
	var ai := CreatureAI.new()
	ai.name = "AIController"
	objetivo.add_child(ai)
	var atacante := FakePlayer.new()
	atacante.add_to_group("player")

	var resultado := CombatImpactEffects.procesar_impacto_confirmado(
		null,
		null,
		atacante,
		objetivo,
		6,
		{"nombre": "Martillo"}
	)
	if not bool(resultado.get("reaccion_ia", false)):
		errores.append("El impacto con arma no notificó al AIController existente.")

	objetivo.free()
	atacante.free()


func _probar_muerte_causada_por_criatura(errores: Array[String]) -> void:
	var jugador := FakePlayer.new()
	jugador.add_to_group("player")
	var atacante := Creature.new()
	atacante.add_to_group("creatures")
	var objetivo := Creature.new()
	objetivo.add_to_group("creatures")
	objetivo.is_alive = false
	objetivo.health = 0
	var game_state := FakeGameState.new()

	var resultado := CombatImpactEffects.procesar_impacto_confirmado(
		game_state,
		jugador,
		atacante,
		objetivo,
		9
	)
	if not bool(resultado.get("derrota_registrada", false)):
		errores.append("La derrota causada por una criatura no se registró.")
	if jugador.absorciones != 0:
		errores.append("El jugador recibió Eterium por una derrota causada por un NPC.")
	if jugador.has_meta("garlia_bosque_agresor"):
		errores.append("Una criatura NPC fue atribuida al jugador como agresión ecológica.")

	game_state.free()
	objetivo.free()
	atacante.free()
	jugador.free()


func _probar_seguridad_de_dependencias(errores: Array[String]) -> void:
	var criatura := Creature.new()
	var nodo := Node.new()

	if CombatImpactEffects.obtener_ai_controller(nodo) != null:
		errores.append("Encontró un AIController inexistente.")
	if CombatImpactEffects.notificar_reaccion_ia(null, {"nombre": "Prueba"}):
		errores.append("Aceptó una reacción de IA sin controlador.")
	if CombatImpactEffects.registrar_criatura_derrotada(null, criatura):
		errores.append("Registró una derrota sin servicio.")
	CombatImpactEffects.aplicar_feedback(nodo, 5)

	nodo.free()
	criatura.free()
