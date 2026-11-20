extends Node

const GameStateScript = preload("res://scripts/core/game_state.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var game_state := GameStateScript.new() as GameStateService
	var save_valido := {
		"id": "save_contract",
		"version": 3,
		"estado": {"player": {"health": 80, "mana": 40}, "flags": {}}
	}

	if not game_state._datos_partida_cargables("save_contract", save_valido):
		errores.append("Se rechazó un save actual con estructura válida.")

	var legacy := {
		"id": "save_contract",
		"estado": {"player": {"health": 75, "mana": 60}}
	}
	if not game_state._datos_partida_cargables("save_contract", legacy):
		errores.append("Se rechazó un save legacy sin versión explícita.")

	if game_state._datos_partida_cargables("save_contract", {}):
		errores.append("Se aceptó un payload vacío.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "otro_save",
		"version": 3,
		"estado": {}
	}):
		errores.append("Se aceptó un ID interno distinto al archivo solicitado.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract",
		"version": 4,
		"estado": {}
	}):
		errores.append("Se aceptó una versión futura que el runtime no conoce.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract",
		"version": 3,
		"estado": []
	}):
		errores.append("Se aceptó un estado raíz que no es Dictionary.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract",
		"version": 3,
		"estado": {"player": [], "flags": {}}
	}):
		errores.append("Se aceptó un snapshot de Player con tipo incorrecto.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract",
		"version": 3,
		"estado": {"player": {}, "flags": []}
	}):
		errores.append("Se aceptó un snapshot de flags con tipo incorrecto.")

	game_state.free()
	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("GameStateSavePayloadContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("GameStateSavePayloadContract: PASS")
	get_tree().quit(0)
