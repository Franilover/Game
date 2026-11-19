extends Node

const Rules = preload("res://scripts/world/npc_schedule_rules.gd")


func _ready() -> void:
	var errores: Array[String] = []

	_comprobar_hora("09:30", 570, errores)
	_comprobar_hora("00:00", 0, errores)
	_comprobar_hora("23:59", 1439, errores)
	_comprobar_hora(" 08:05 ", 485, errores)
	_comprobar_hora("24:00", -1, errores)
	_comprobar_hora("12:60", -1, errores)
	_comprobar_hora("abc", -1, errores)
	_comprobar_hora("12", -1, errores)
	_comprobar_hora("12:30:45", 750, errores)

	_comprobar_dia([], 2, true, errores)
	_comprobar_dia(null, 2, true, errores)
	_comprobar_dia([0, 2, 4], 2, true, errores)
	_comprobar_dia([0.0, 2.0, 4.0], 2, true, errores)
	_comprobar_dia(["0", "2", "4"], 2, true, errores)
	_comprobar_dia([" 2 "], 2, true, errores)
	_comprobar_dia([0, 1, 3], 2, false, errores)
	_comprobar_dia(["martes"], 2, false, errores)
	_comprobar_dia("2", 2, true, errores)

	if errores.is_empty():
		print("NPCScheduleRules: PASS")
		get_tree().quit(0)
		return

	for error in errores:
		push_error("NPCScheduleRules: FAIL: " + error)
	get_tree().quit(1)


func _comprobar_hora(valor: Variant, esperado: int, errores: Array[String]) -> void:
	var obtenido: int = Rules.hora_a_minutos(valor)
	if obtenido != esperado:
		errores.append("hora_a_minutos(%s): esperado %d, obtenido %d" % [str(valor), esperado, obtenido])


func _comprobar_dia(
	dias: Variant,
	dia: int,
	esperado: bool,
	errores: Array[String]
) -> void:
	var obtenido: bool = Rules.coincide_dia(dias, dia)
	if obtenido != esperado:
		errores.append("coincide_dia(%s, %d): esperado %s, obtenido %s" % [
			str(dias), dia, str(esperado), str(obtenido)
	])
