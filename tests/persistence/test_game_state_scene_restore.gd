extends Node

const GameStateScript = preload("res://scripts/core/game_state.gd")
const PlayerScene = preload("res://scenes/characters/player.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var player := PlayerScene.instantiate() as Player
	if player == null:
		_finalizar(["No se pudo instanciar la escena real de Player."])
		return
	add_child(player)
	await get_tree().process_frame

	# El test resuelve las dos fuentes de configuración que normalmente llegan
	# desde Supabase, sin conectarse a servicios externos.
	player.eterium.aplicar_runtime({
		"limite_estable_s": 100.0,
		"escala_runtime": 1.0
	}, [])
	var regla_especie := {
		"especie_eterium_v1": {
			"especie_id": "player_restore_contract",
			"capacidad_base": 100
		},
		"eterium_inicial": 100,
		"vida_eterium_compartidos": false
	}
	if not player.eterium.aplicar_especie(regla_especie, "player_restore_contract"):
		errores.append("No se pudo preparar la fisiología de Player para restauración.")
	player.eterium.marcar_especie_configuracion_resuelta()

	var game_state := GameStateScript.new() as GameStateService
	game_state._player = player
	game_state.player_state.health = 64
	game_state.player_state.mana = 37
	game_state.player_state.stamina = 0.65
	game_state.player_state.position = Vector2(321.5, -87.25)
	game_state.player_state.position_valida = true
	game_state.player_state.facing = Vector2.LEFT

	game_state._aplicar_estado_al_juego()

	if player.health != 64:
		errores.append("La salud del snapshot no se aplicó al Player real.")
	if player.mana != 37:
		errores.append("El Eterium del snapshot no se aplicó al Player real.")
	if not is_equal_approx(player.stamina, 0.65):
		errores.append("La stamina no se aplicó mediante el controlador del Player.")
	if player.global_position != Vector2(321.5, -87.25):
		errores.append("La posición del snapshot no se aplicó al Player real.")
	if player.facing != Vector2.LEFT:
		errores.append("La orientación del snapshot no se aplicó al Player real.")
	if not game_state._partida_aplicada_en_escena:
		errores.append("GameState no marcó la aplicación de la partida.")
	if not game_state._estado_vital_restaurado_en_escena:
		errores.append("GameState no confirmó la restauración vital tras resolver Eterium.")

	game_state.free()
	player.queue_free()
	await get_tree().process_frame
	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("GameStateSceneRestore: FAIL: " + error)
		get_tree().quit(1)
		return
	print("GameStateSceneRestore: PASS")
	get_tree().quit(0)
