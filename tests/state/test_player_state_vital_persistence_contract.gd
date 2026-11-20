extends Node

const PlayerStateScript = preload("res://scripts/state/player_state.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []

	var legacy := PlayerStateScript.new() as PlayerState
	legacy.from_dictionary({"health": 75, "mana": 42, "stamina": 50.0})
	if legacy.health != 75 or legacy.mana != 42:
		errores.append("El snapshot legacy no restauró salud y Eterium independientes.")
	if not is_equal_approx(legacy.stamina, 1.5):
		errores.append("La migración legacy de stamina dejó de convertir la escala 0..100.")

	var normalizado := legacy.normalizar_reservas_vitales(60, 30, false)
	if int(normalizado.get("health", -1)) != 60 or int(normalizado.get("mana", -1)) != 30:
		errores.append("Las reservas independientes no se limitaron a las capacidades runtime.")

	legacy.health = 80
	legacy.mana = 35
	var compartido := legacy.normalizar_reservas_vitales(100, 100, true)
	if int(compartido.get("health", -1)) != 35 or int(compartido.get("mana", -1)) != 35:
		errores.append("Un save compartido inconsistente concedió más salud que su reserva menor.")

	legacy.health = -10
	legacy.mana = 140
	var corrupto := legacy.normalizar_reservas_vitales(100, 90, false)
	if int(corrupto.get("health", -1)) != 0 or int(corrupto.get("mana", -1)) != 90:
		errores.append("Los valores corruptos no se limitaron al rango válido.")

	legacy.health = 0
	legacy.mana = 0
	var muerto := legacy.normalizar_reservas_vitales(100, 100, true)
	if int(muerto.get("health", -1)) != 0 or int(muerto.get("mana", -1)) != 0:
		errores.append("La normalización convirtió un snapshot sin salud en una reserva viva.")

	var serializado: Dictionary = legacy.to_dictionary()
	var recargado := PlayerStateScript.new() as PlayerState
	recargado.from_dictionary(serializado)
	var ronda := recargado.normalizar_reservas_vitales(100, 100, true)
	if int(ronda.get("health", -1)) != 0 or int(ronda.get("mana", -1)) != 0:
		errores.append("La ida y vuelta del snapshot perdió el estado agotado.")

	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("PlayerStateVitalPersistenceContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("PlayerStateVitalPersistenceContract: PASS")
	get_tree().quit(0)
