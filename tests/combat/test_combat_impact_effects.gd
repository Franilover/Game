extends Node

const PlayerScene = preload("res://scenes/characters/player.tscn")
const CreatureScript = preload("res://scripts/creatures/creature.gd")
const ImpactEffects = preload("res://scripts/gameplay/combat/combat_impact_effects.gd")


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
	var jugador := PlayerScene.instantiate() as Player
	var feerin := CreatureScript.new() as Creature
	feerin.criatura_nombre = "Feerin"

	if not ImpactEffects.registrar_agresion_bosque(jugador, feerin, false):
		errores.append("No registró agresión contra Feerin.")
	if not jugador.has_meta("garlia_bosque_agresor"):
		errores.append("No marcó al jugador como agresor del bosque.")
	if jugador.has_meta("garlia_bosque_asesino"):
		errores.append("Marcó asesinato aunque la criatura no fue derrotada.")

	if not ImpactEffects.registrar_agresion_bosque(jugador, feerin, true):
		errores.append("No registró la agresión letal contra Feerin.")
	if not jugador.has_meta("garlia_bosque_asesino"):
		errores.append("No marcó al jugador como asesino del bosque.")

	var criatura_ajena := CreatureScript.new() as Creature
	criatura_ajena.criatura_nombre = "Criatura de prueba"
	if ImpactEffects.registrar_agresion_bosque(jugador, criatura_ajena, true):
		errores.append("Registró agresión ecológica para una especie ajena a la regla.")

	jugador.free()
	feer in.free()
	criatura_ajena.free()


func _probar_registro_derrota(errores: Array[String]) -> void:
	var game_state := GameStateService.new()
	var criatura := CreatureScript.new() as Creature
	criatura.criatura_id = "combat-impact-effects-test"
	criatura.add_to_group("creatures")

	if not ImpactEffects.registrar_criatura_derrotada(game_state, criatura):
		errores.append("No delegó el registro de derrota a GameState.")
	var registros_variant: Variant = game_state.world_state.flags.get("enciclopedia_criaturas", {})
	if not registros_variant is Dictionary:
		errores.append("GameState no conservó el registro de enciclopedia como Dictionary.")
	else:
		var registros: Dictionary = registros_variant as Dictionary
		if int(registros.get(criatura.criatura_id, 0)) != 1:
			errores.append("El helper no registró exactamente una derrota en GameState.")

	criatura.remove_from_group("creatures")
	criatura.free()
	game_state.free()


func _probar_seguridad_de_dependencias(errores: Array[String]) -> void:
	var criatura := CreatureScript.new() as Creature
	var nodo := Node.new()

	if ImpactEffects.obtener_ai_controller(nodo) != null:
		errores.append("Encontró un AIController inexistente.")
	if ImpactEffects.notificar_reaccion_ia(null, {"nombre": "Prueba"}):
		errores.append("Aceptó una reacción de IA sin controlador.")
	if ImpactEffects.registrar_criatura_derrotada(null, criatura):
		errores.append("Registró una derrota sin GameState.")
	ImpactEffects.aplicar_feedback(nodo, 5)

	nodo.free()
	criatura.free()
