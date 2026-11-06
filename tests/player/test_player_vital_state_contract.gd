extends Node

const PlayerScene = preload("res://scenes/characters/player.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var jugador := PlayerScene.instantiate() as Player
	if jugador == null:
		_finalizar(["No se pudo instanciar Player."])
		return
	get_tree().root.add_child(jugador)
	await get_tree().process_frame

	var muertes := {"cantidad": 0}
	jugador.died.connect(
		func() -> void:
			muertes["cantidad"] = int(muertes["cantidad"]) + 1
	)

	var regla_normal := {
		"especie_eterium_v1": {
			"especie_id": "especie-prueba-normal",
			"capacidad_base": 120
		},
		"eterium_inicial": 60,
		"vida_eterium_compartidos": false,
		"recuperacion_eterium": true
	}
	if not jugador.eterium.aplicar_especie(regla_normal, "especie-prueba-normal"):
		errores.append("No se pudo aplicar la fisiología no compartida de prueba.")

	if not jugador.restaurar_eterium(20.0):
		errores.append("La restauración de Eterium no informó el cambio.")
	if jugador.mana != 80 or jugador.vital_state.mana != 80:
		errores.append("Restaurar Eterium no sincronizó Player y VitalState.")

	jugador.take_damage(10, "Prueba/PlayerVitalState")
	if jugador.health != jugador.max_health - 10:
		errores.append("El daño normal no redujo la vida esperada.")
	if jugador.vital_state.health != jugador.health:
		errores.append("El daño normal dejó desincronizado VitalState.")

	jugador.take_damage(jugador.max_health + 100, "Prueba/MuertePlayer")
	if jugador.is_alive or jugador.vital_state.is_alive or int(muertes["cantidad"]) != 1:
		errores.append("La muerte normal no sincronizó el estado ni emitió died.")

	jugador.reaparecer()
	if (
		not jugador.is_alive
		or jugador.health != jugador.max_health
		or jugador.vital_state.health != jugador.health
		or jugador.mana != jugador.max_mana
		or jugador.vital_state.mana != jugador.mana
	):
		errores.append("Reaparecer no restauró las reservas internas y públicas.")

	jugador.take_damage(jugador.max_health + 100, "Prueba/SegundaMuerte")
	if int(muertes["cantidad"]) != 2:
		errores.append("La reaparición no rearmó el evento de muerte de Entity.")

	jugador.reaparecer()
	var regla_compartida := {
		"especie_eterium_v1": {
			"especie_id": "especie-prueba-compartida",
			"capacidad_base": 120
		},
		"eterium_inicial": 120,
		"vida_eterium_compartidos": true,
		"recuperacion_eterium": true
	}
	if not jugador.eterium.aplicar_especie(regla_compartida, "especie-prueba-compartida"):
		errores.append("No se pudo aplicar la fisiología compartida de prueba.")

	jugador.take_damage(25, "Prueba/DañoCompartido")
	if (
		jugador.health != 95
		or jugador.mana != 95
		or jugador.vital_state.health != 95
		or jugador.vital_state.mana != 95
	):
		errores.append("El daño de fisiología compartida no redujo vida y Eterium juntos.")

	if not jugador.restaurar_eterium(10.0):
		errores.append("La restauración de fisiología compartida no informó el cambio.")
	if jugador.health != 105 or jugador.vital_state.health != 105:
		errores.append("Restaurar Eterium compartido no restauró también la vida.")

	jugador.admin_establecer_maximos(80, 80, 3.0)
	if (
		jugador.max_health != 80
		or jugador.max_mana != 80
		or jugador.vital_state.max_health != 80
		or jugador.vital_state.max_mana != 80
		or jugador.health != 80
		or jugador.mana != 80
	):
		errores.append("La edición de máximos no sincronizó el estado vital compartido.")

	jugador.restaurar_estado_vital(30, true, 20)
	jugador.reaparecer_en_red(Vector2(64, 96))
	if (
		jugador.health != 80
		or jugador.mana != 80
		or jugador.vital_state.health != 80
		or jugador.vital_state.mana != 80
	):
		errores.append("La reaparición de red no restauró el estado vital.")

	jugador.queue_free()
	await get_tree().process_frame
	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("PlayerVitalStateContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("PlayerVitalStateContract: PASS")
	get_tree().quit(0)
