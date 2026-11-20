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

	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": "tres", "estado": {}
	}):
		errores.append("Se aceptó una versión con tipo incorrecto.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": 3,
		"estado": {"player": {"health": "mucha vida"}}
	}):
		errores.append("Se aceptó una reserva del jugador con tipo incorrecto.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": 3, "mundo": "mundo_corrupto",
		"estado": {}
	}):
		errores.append("Se aceptó metadata de mundo con tipo incorrecto.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": 3, "mundo": {"semilla": "sin_semilla"},
		"estado": {}
	}):
		errores.append("Se aceptó una semilla con tipo incorrecto.")
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": 3,
		"estado": {"elapsed_time": "tiempo_invalido"}
	}):
		errores.append("Se aceptó elapsed_time con tipo incorrecto.")

	var inventario_valido := {
		"items": [{"id": "item_a", "cantidad": 2}],
		"hotbar_indices": [6, 7, -1],
		"equipo": {"torso": {"id": "armor_a", "tipo": "armadura"}},
		"mano_izquierda_activa": 0,
		"mano_derecha_activa": 1
	}
	if not game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": 3,
		"estado": {"player": {}, "flags": {"inventario_estado": inventario_valido}}
	}):
		errores.append("Se rechazó un inventario persistido válido.")

	var inventario_corrupto := inventario_valido.duplicate(true)
	inventario_corrupto["items"] = [{"id": "item_a"}, "item_roto"]
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": 3,
		"estado": {"flags": {"inventario_estado": inventario_corrupto}}
	}):
		errores.append("Se aceptó un inventario con elementos que no son Dictionary.")

	inventario_corrupto = inventario_valido.duplicate(true)
	inventario_corrupto["hotbar_indices"] = "indices_invalidos"
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": 3,
		"estado": {"flags": {"inventario_estado": inventario_corrupto}}
	}):
		errores.append("Se aceptó una hotbar con estructura incorrecta.")

	inventario_corrupto = inventario_valido.duplicate(true)
	inventario_corrupto["equipo"] = {"torso": "armadura_rota"}
	if game_state._datos_partida_cargables("save_contract", {
		"id": "save_contract", "version": 3,
		"estado": {"flags": {"inventario_estado": inventario_corrupto}}
	}):
		errores.append("Se aceptó equipamiento con fichas de tipo incorrecto.")


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
