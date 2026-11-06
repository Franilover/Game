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
	feer in
