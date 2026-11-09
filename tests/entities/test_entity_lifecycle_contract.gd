extends Node

const EntityScript = preload("res://scripts/characters/entity.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var entidad := EntityScript.new() as Entity
	entidad.name = "EntityLifecycleContractTarget"
	get_tree().root.add_child(entidad)
	await get_tree().process_frame

	var muertes := {"cantidad": 0}
	entidad.died.connect(
		func() -> void:
			muertes["cantidad"] = int(muertes["cantidad"]) + 1
	)

	entidad.take_damage(150, "Prueba/Muerte")
	if entidad.health != 0 or entidad.is_alive:
		errores.append("El daño letal no dejó la entidad en estado muerto.")
	if int(muertes["cantidad"]) != 1:
		errores.append("La transición a muerto no emitió exactamente una señal died.")

	entidad.take_damage(10, "Prueba/DanioPosterior")
	if int(muertes["cantidad"]) != 1:
		errores.append("Una entidad muerta volvió a emitir died.")

	entidad.restaurar_estado_vital(40, true, 27)
	if not entidad.is_alive or entidad.health != 40:
		errores.append("La restauración viva no recuperó el estado vital.")
	if entidad.mana != 27 or entidad.vital_state.mana != 27:
		errores.append("La restauración no sincronizó maná entre Entity y VitalState.")
	entidad.restaurar_estado_vital(40, true, 150)
	if entidad.mana != entidad.max_mana:
		errores.append("La restauración no limitó el maná al máximo permitido.")
	entidad.restaurar_estado_vital(40, true, 27)
	entidad.take_damage(40, "Prueba/SegundaMuerte")
	if int(muertes["cantidad"]) != 2:
		errores.append("Una entidad restaurada viva no pudo emitir su siguiente muerte.")

	entidad.restaurar_estado_vital(0, false)
	if int(muertes["cantidad"]) != 2:
		errores.append("Restaurar una partida muerta reprodujo indebidamente el evento died.")
	entidad.take_damage(1, "Prueba/EstadoRestauradoMuerto")
	if int(muertes["cantidad"]) != 2:
		errores.append("Una entidad restaurada muerta emitió died otra vez.")

	entidad.queue_free()
	await get_tree().process_frame

	if not errores.is_empty():
		for error in errores:
			push_error("EntityLifecycleContract: FAIL: " + error)
		get_tree().quit(1)
		return

	print("EntityLifecycleContract: PASS")
	get_tree().quit(0)
