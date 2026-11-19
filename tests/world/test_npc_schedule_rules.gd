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


func _comprobar_seleccion_rutina(errores: Array[String]) -> void:
	var rutinas: Array = [
		{"clave": "trabajo", "hora_inicio": "09:00", "hora_fin": "17:00", "dias_semana": [1], "prioridad": 2},
		{"clave": "guardia", "hora_inicio": "10:00", "hora_fin": "12:00", "dias_semana": [1], "prioridad": 5},
		{"clave": "inactiva", "hora_inicio": "10:00", "hora_fin": "12:00", "dias_semana": [1], "prioridad": 99, "activo": false},
		{"clave": "hora_invalida", "hora_inicio": "25:00", "hora_fin": "12:00", "dias_semana": [1], "prioridad": 100}
	]
	var resultado: Dictionary = Rules.seleccionar_rutina(rutinas, 1, 10 * 60 + 30)
	var elegida: Dictionary = resultado.get("rutina", {})
	if str(elegida.get("clave", "")) != "guardia":
		errores.append("La rutina activa de mayor prioridad no fue seleccionada.")

	var empate: Array = [
		{"clave": "primera", "hora_inicio": "09:00", "hora_fin": "13:00", "prioridad": 3},
		{"clave": "inicio_tardio", "hora_inicio": "10:00", "hora_fin": "14:00", "prioridad": 3}
	]
	resultado = Rules.seleccionar_rutina(empate, 0, 11 * 60)
	elegida = resultado.get("rutina", {})
	if str(elegida.get("clave", "")) != "inicio_tardio":
		errores.append("En empate de prioridad debe ganar la rutina con inicio más tardío.")

	var empate_exacto: Array = [
		{"clave": "primera", "hora_inicio": "09:00", "hora_fin": "13:00"},
		{"clave": "segunda", "hora_inicio": "09:00", "hora_fin": "14:00"}
	]
	resultado = Rules.seleccionar_rutina(empate_exacto, 0, 10 * 60)
	elegida = resultado.get("rutina", {})
	if str(elegida.get("clave", "")) != "primera":
		errores.append("Un empate exacto debe conservar el primer elemento de la lista.")

	var turno_nocturno: Array = [
		{"clave": "guardia_noche", "hora_inicio": "22:00", "hora_fin": "06:00", "dias_semana": [2]}
	]
	resultado = Rules.seleccionar_rutina(turno_nocturno, 2, 23 * 60)
	elegida = resultado.get("rutina", {})
	if str(elegida.get("clave", "")) != "guardia_noche":
		errores.append("El tramo nocturno posterior al inicio debe usar el día actual.")
	resultado = Rules.seleccionar_rutina(turno_nocturno, 3, 2 * 60)
	elegida = resultado.get("rutina", {})
	if str(elegida.get("clave", "")) != "guardia_noche":
		errores.append("El tramo nocturno anterior al fin debe usar el día anterior.")
	resultado = Rules.seleccionar_rutina(turno_nocturno, 3, 2 * 60)
	if not (resultado.get("rechazos", []) as Array).is_empty():
		errores.append("Una rutina nocturna válida no debe generar rechazos.")

	var dia_incorrecto: Dictionary = Rules.seleccionar_rutina(turno_nocturno, 2, 2 * 60)
	if not (dia_incorrecto.get("rutina", {}) as Dictionary).is_empty():
		errores.append("Una rutina nocturna no debe atribuir la madrugada al día equivocado.")

	var original: Array = [{"clave": "copia", "hora_inicio": "08:00", "hora_fin": "12:00", "datos": {"valor": 1}}]
	resultado = Rules.seleccionar_rutina(original, 0, 9 * 60)
	elegida = resultado.get("rutina", {})
	elegida["datos"]["valor"] = 99
	if int(original[0]["datos"]["valor"]) != 1:
		errores.append("La rutina devuelta debe ser una copia profunda y no mutar los datos originales.")


func _comprobar_rutinas_dia_libre(errores: Array[String]) -> void:
	var casos_manana: Array[Dictionary] = [
		{"npc": "Darven", "ubicacion": "cuartel", "actividad": "recorrer_alrededores"},
		{"npc": "Narel", "ubicacion": "archivo_real", "actividad": "leer"},
		{"npc": "Mara", "ubicacion": "vivienda_oeste_01", "actividad": "ordenar_sus_espacios"},
		{"npc": "Ivo", "ubicacion": "vivienda_oeste_02", "actividad": "descansar"},
		{"npc": "Nima", "ubicacion": "casa_estudio", "actividad": "revisar_apuntes"},
		{"npc": "Abel", "ubicacion": "castillo", "actividad": "atender_asuntos_del_castillo"},
		{"npc": "Liam", "ubicacion": "castillo", "actividad": "atender_asuntos_del_castillo"},
		{"npc": "Saira", "ubicacion": "plaza", "actividad": "pasear"},
		{"npc": "Elian", "ubicacion": "plaza", "actividad": "pasear"},
		{"npc": "Bruna", "ubicacion": "plaza", "actividad": "pasear"}
	]
	for caso in casos_manana:
		var rutina: Dictionary = Rules.seleccionar_rutina_dia_libre(caso["npc"], 600)
		if str(rutina.get("ubicacion_clave", "")) != str(caso["ubicacion"]):
			errores.append("Destino matutino incorrecto para %s." % caso["npc"])
		if str(rutina.get("actividad_clave", "")) != str(caso["actividad"]):
			errores.append("Actividad matutina incorrecta para %s." % caso["npc"])

	var casos_tarde: Array[Dictionary] = [
		{"npc": "Saira", "ubicacion": "casa_comercio", "actividad": "visitar_comerciantes"},
		{"npc": "Narel", "ubicacion": "casa_estudio", "actividad": "visitar_estudio"},
		{"npc": "Nima", "ubicacion": "casa_estudio", "actividad": "visitar_estudio"},
		{"npc": "Darven", "ubicacion": "plaza", "actividad": "descansar"},
		{"npc": "Mara", "ubicacion": "plaza", "actividad": "pasear_sin_prisa"},
		{"npc": "Ivo", "ubicacion": "plaza", "actividad": "descansar_y_saludar"},
		{"npc": "Elian", "ubicacion": "casa_elian", "actividad": "descansar_del_trabajo"},
		{"npc": "Bruna", "ubicacion": "casa_bruna", "actividad": "revisar_sus_herramientas"},
		{"npc": "Abel", "ubicacion": "castillo", "actividad": "organizar_asuntos_internos"},
		{"npc": "Liam", "ubicacion": "castillo", "actividad": "organizar_asuntos_internos"}
	]
	for caso in casos_tarde:
		var rutina: Dictionary = Rules.seleccionar_rutina_dia_libre(caso["npc"], 900)
		if str(rutina.get("ubicacion_clave", "")) != str(caso["ubicacion"]):
			errores.append("Destino vespertino incorrecto para %s." % caso["npc"])
		if str(rutina.get("actividad_clave", "")) != str(caso["actividad"]):
			errores.append("Actividad vespertina incorrecta para %s." % caso["npc"])

	var encuentro := Rules.seleccionar_rutina_dia_libre("Mara", 1020)
	if str(encuentro.get("clave", "")) != "dia_libre_encuentro" or str(encuentro.get("actividad_clave", "")) != "conversar":
		errores.append("El tramo de encuentro del día libre debe comenzar a las 17:00.")

	var regreso := Rules.seleccionar_rutina_dia_libre("Mara", 1200)
	if str(regreso.get("clave", "")) != "dia_libre_regreso" or str(regreso.get("ubicacion_clave", "")) != "vivienda_oeste_01":
		errores.append("El regreso al hogar debe comenzar a las 20:00.")

	var nombre_normalizado := Rules.seleccionar_rutina_dia_libre("  MARA  ", 600)
	if str(nombre_normalizado.get("actividad_clave", "")) != "ordenar_sus_espacios":
		errores.append("El nombre del NPC debe normalizar espacios y mayúsculas.")


func _comprobar_calendario_comunitario(errores: Array[String]) -> void:
	var evento := Rules.obtener_evento_comunitario(1, 0, 840)
	if str(evento.get("clave", "")) != "celebracion_estacional":
		errores.append("La celebración estacional debe comenzar a las 14:00 del primer día de estación.")
	evento = Rules.obtener_evento_comunitario(1, 4, 900)
	if str(evento.get("clave", "")) != "celebracion_estacional":
		errores.append("La celebración estacional debe tener prioridad sobre el mercado vecinal.")
	evento = Rules.obtener_evento_comunitario(2, 4, 540)
	if str(evento.get("clave", "")) != "mercado_vecinal":
		errores.append("El mercado vecinal debe comenzar a las 09:00 del quinto día.")
	evento = Rules.obtener_evento_comunitario(2, 4, 1019)
	if str(evento.get("clave", "")) != "mercado_vecinal":
		errores.append("El mercado vecinal debe mantenerse hasta antes de las 17:00.")
	evento = Rules.obtener_evento_comunitario(2, 4, 1020)
	if str(evento.get("clave", "")) != "comida_comunitaria":
		errores.append("La comida comunitaria debe comenzar a las 17:00.")
	evento = Rules.obtener_evento_comunitario(2, 4, 1200)
	if not evento.is_empty():
		errores.append("No debe haber eventos comunitarios desde las 20:00.")
	evento = Rules.obtener_evento_comunitario(2, 3, 900)
	if not evento.is_empty():
		errores.append("El mercado y la comida comunitaria sólo ocurren en el quinto día.")
	evento = Rules.obtener_evento_comunitario(2, 0, 900)
	if not evento.is_empty():
		errores.append("No debe haber evento ordinario fuera del quinto día.")
