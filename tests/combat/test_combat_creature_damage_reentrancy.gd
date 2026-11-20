extends Node

const CreatureScript = preload("res://scripts/creatures/creature.gd")
const EntityScript = preload("res://scripts/characters/entity.gd")
const CombatDamageScript = preload("res://scripts/gameplay/combat/combat_damage.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var criatura := CreatureScript.new()
	var atacante_externo := EntityScript.new()
	var atacante_reentrante := EntityScript.new()
	criatura.name = "CreatureDamageReentrancyTarget"
	atacante_externo.name = "CreatureDamageOuterAttacker"
	atacante_reentrante.name = "CreatureDamageNestedAttacker"
	get_tree().root.add_child(criatura)
	get_tree().root.add_child(atacante_externo)
	get_tree().root.add_child(atacante_reentrante)
	await get_tree().process_frame

	var eventos: Array[Dictionary] = []
	var control_reentrada := {"iniciado": false}
	criatura.danio_recibido.connect(
		func(cantidad: int, atacante: Node) -> void:
			eventos.append({
				"cantidad": cantidad,
				"atacante": atacante
			})
	)
	criatura.health_changed.connect(
		func(_actual: int, _maximo: int) -> void:
			if bool(control_reentrada["iniciado"]):
				return
			control_reentrada["iniciado"] = true
			criatura.take_damage_desde(
				atacante_reentrante,
				5,
				"Prueba/Reentrada"
			)
	)

	var danio_externo := CombatDamageScript.aplicar_y_obtener_danio(
		criatura,
		10,
		"Prueba/Externo",
		Callable(),
		atacante_externo
	)

	if danio_externo != 10:
		errores.append("La solicitud externa recibió daño reentrante en su cantidad de retorno.")
	if criatura.health != 85:
		errores.append("El daño anidado no se aplicó exactamente una vez por solicitud.")
	if eventos.size() != 2:
		errores.append("La criatura no publicó exactamente los dos eventos de daño.")
	else:
		if eventos[0].get("atacante") != atacante_reentrante:
			errores.append("El golpe reentrante perdió la identidad de su atacante.")
		if eventos[1].get("atacante") != atacante_externo:
			errores.append("El golpe externo perdió la identidad de su atacante tras la reentrada.")
		if int(eventos[0].get("cantidad", 0)) != 5 or int(eventos[1].get("cantidad", 0)) != 10:
			errores.append("Los eventos no conservaron la cantidad de daño de cada invocación.")

	if not errores.is_empty():
		for error in errores:
			push_error("CreatureDamageReentrancy: FAIL: " + error)
		get_tree().quit(1)
		return

	print("CreatureDamageReentrancy: PASS")
	get_tree().quit(0)
