extends Node


class FakeGameState:
	extends Node

	var criaturas_registradas: Array[Node] = []

	func registrar_criatura_derrotada(criatura: Node) -> bool:
		if criatura == null:
			return false
		criaturas_registradas.append(criatura)
		return true


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	_probar_agresion_ecologica(errores)
	_probar_registro_derrota(errores)
	_probar_seguridad_de_dependencias(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatImpactEffects: FAIL: " + error)
		get_tree().quit(1)
		return

	print("CombatImpactEffects: PASS")
	get_tree().quit(0)


func _probar_agresion_ecologica(errores: Array[String]) -> void:
	var jugador := Node.new()
	var feerin := Creature.new()
	feerin.criatura_nombre = "Feerin"

	if not CombatImpactEffects.registrar_agresion_bosque(jugador, feerin, false):
		errores.append("No registró agresión contra Feerin.")
	if not jugador.has_meta("garlia_bosque_agresor"):
		errores.append("No marcó al jugador como agresor del bosque.")
	if jugador.has_meta("garlia_bosque_asesino"):
		errores.append("Marcó asesinato aunque la criatura no fue derrotada.")

	if not CombatImpactEffects.registrar_agresion_bosque(jugador, feerin, true):
		errores.append("No registró la agresión letal contra Feerin.")
	if not jugador.has_meta("garlia_bosque_asesino"):
		errores.append("No marcó al jugador como asesino del bosque.")

	var criatura_ajena := Creature.new()
	criatura_ajena.criatura_nombre = "Criatura de prueba"
	if CombatImpactEffects.registrar_agresion_bosque(jugador, criatura_ajena, true):
		errores.append("Registró agresión ecológica para una especie ajena a la regla.")

	jugador.free()
	feerin.free()
	criatura_ajena.free()


func _probar_registro_derrota(errores: Array[String]) -> void:
	var game_state := FakeGameState.new()
	var criatura := Creature.new()

	if not CombatImpactEffects.registrar_criatura_derrotada(game_state, criatura):
		errores.append("No delegó el registro de derrota al servicio.")
	if game_state.criaturas_registradas.size() != 1:
		errores.append("El servicio no recibió exactamente un registro de derrota.")
	elif game_state.criaturas_registradas[0] != criatura:
		errores.append("El servicio recibió una criatura distinta al objetivo.")

	game_state.free()
	criatura.free()


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
