extends Node

const Rules = preload("res://scripts/world/npc_schedule_rules.gd")
const ScheduleSystem = preload("res://scripts/world/npc_schedule_system.gd")


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
	_comprobar_horario_nocturno(errores)

	_comprobar_seleccion_rutina(errores)
	_comprobar_rutinas_dia_libre(errores)
	_comprobar_calendario_comunitario(errores)
	_comprobar_siguiente_rutina(errores)
	_comprobar_satisfaccion_y_eventos(errores)
	_comprobar_respaldo_castillo(errores)
	_comprobar_catalogo_ocio(errores)
	_comprobar_desplazamiento_ocio(errores)
	_comprobar_desplazamiento_evento(errores)
	_comprobar_turnos_comercio(errores)
	_comprobar_evaluacion_invitacion(errores)
	_comprobar_requisitos_encuentro_trio(errores)
	_comprobar_ubicaciones_hogar(errores)
	_comprobar_patrones_paseo_exterior(errores)

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


func _comprobar_horario_nocturno(errores: Array[String]) -> void:
	var casos: Array[Dictionary] = [
		{"minutos": -1, "esperado": true},
		{"minutos": 0, "esperado": true},
		{"minutos": 359, "esperado": true},
		{"minutos": 360, "esperado": false},
		{"minutos": 1259, "esperado": false},
		{"minutos": 1260, "esperado": true},
		{"minutos": 1439, "esperado": true},
		{"minutos": 1440, "esperado": true}
	]
	for caso in casos:
		var minutos := int(caso["minutos"])
		var esperado := bool(caso["esperado"])
		if Rules.es_horario_nocturno(minutos) != esperado:
			errores.append("es_horario_nocturno(%d) debe ser %s." % [minutos, str(esperado)])


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


func _comprobar_siguiente_rutina(errores: Array[String]) -> void:
	var rutinas: Array = [
		{"clave": "trabajo_tarde", "hora_inicio": "15:00", "hora_fin": "18:00", "dias_semana": [0]}
	]
	var minutos := Rules.obtener_minutos_hasta_siguiente_rutina(rutinas, 0, 10 * 60)
	if minutos != 300:
		errores.append("El siguiente inicio del mismo día debe calcularse en minutos reales.")

	var siguiente_dia: Array = [
		{"clave": "trabajo_manana", "hora_inicio": "09:00", "hora_fin": "12:00", "dias_semana": [1]}
	]
	minutos = Rules.obtener_minutos_hasta_siguiente_rutina(siguiente_dia, 0, 10 * 60)
	if minutos != 23 * 60:
		errores.append("El inicio del día siguiente debe considerar el cambio de día.")

	var vuelta_ciclo: Array = [
		{"clave": "rutina_dia_cero", "hora_inicio": "06:00", "hora_fin": "08:00", "dias_semana": [0]}
	]
	minutos = Rules.obtener_minutos_hasta_siguiente_rutina(vuelta_ciclo, 4, 1300)
	if minutos != 500:
		errores.append("El cálculo debe envolver correctamente el ciclo de cinco días.")

	var sin_dia: Array = [
		{"clave": "rutina_diaria", "hora_inicio": "08:00", "hora_fin": "09:00"}
	]
	minutos = Rules.obtener_minutos_hasta_siguiente_rutina(sin_dia, 0, 10 * 60)
	if minutos != 22 * 60:
		errores.append("Una rutina sin días específicos debe considerarse diaria.")

	var ignorar_invalidas: Array = [
		{"clave": "inactiva", "hora_inicio": "11:00", "hora_fin": "12:00", "activo": false},
		{"clave": "mal_formada", "hora_inicio": "xx", "hora_fin": "12:00"}
	]
	minutos = Rules.obtener_minutos_hasta_siguiente_rutina(ignorar_invalidas, 0, 10 * 60)
	if minutos != 0:
		errores.append("Las rutinas inactivas o inválidas no deben producir un próximo inicio.")

	if Rules.obtener_minutos_hasta_siguiente_rutina([], 0, 600) != 0:
		errores.append("Una lista de rutinas vacía debe devolver cero.")


func _comprobar_satisfaccion_y_eventos(errores: Array[String]) -> void:
	var descanso := Rules.obtener_satisfaccion_actividad("descansar en casa")
	if not is_equal_approx(float(descanso.get("descanso", 0.0)), 2.0):
		errores.append("Descansar debe satisfacer descanso con valor 2.0.")

	var social := Rules.obtener_satisfaccion_actividad("conversar con amigos")
	if not is_equal_approx(float(social.get("socializacion", 0.0)), 1.8):
		errores.append("Conversar debe satisfacer socialización con valor 1.8.")
	if not is_equal_approx(float(social.get("diversion", 0.0)), 0.6):
		errores.append("Conversar debe satisfacer diversión con valor 0.6.")

	var lectura := Rules.obtener_satisfaccion_actividad("leer informes")
	if not is_equal_approx(float(lectura.get("curiosidad", 0.0)), 1.8):
		errores.append("Leer informes debe satisfacer curiosidad con valor 1.8.")

	var paseo := Rules.obtener_satisfaccion_actividad("visitar la plaza")
	if not is_equal_approx(float(paseo.get("autonomia", 0.0)), 1.3):
		errores.append("Visitar debe satisfacer autonomía con valor 1.3.")
	if not is_equal_approx(float(paseo.get("diversion", 0.0)), 1.0):
		errores.append("Visitar debe satisfacer diversión con valor 1.0.")

	var vigilancia := Rules.obtener_satisfaccion_actividad("vigilar la entrada")
	if not is_equal_approx(float(vigilancia.get("seguridad", 0.0)), 0.8):
		errores.append("Vigilar debe satisfacer seguridad con valor 0.8.")

	var sin_coincidencias := Rules.obtener_satisfaccion_actividad("mirar las nubes")
	if not sin_coincidencias.is_empty():
		errores.append("Una actividad sin palabras clave no debe inventar satisfacciones.")

	if not Rules.puede_participar_en_evento({}):
		errores.append("Una rutina vacía debe permitir participar en eventos.")
	if not Rules.puede_participar_en_evento({"clave": " DIA_LIBRE_MANANA "}):
		errores.append("Una rutina de día libre debe permitir participar en eventos.")
	if Rules.puede_participar_en_evento({"clave": "trabajo_herreria"}):
		errores.append("Una rutina de trabajo no debe permitir participar en eventos.")
	if Rules.puede_participar_en_evento({"clave": "guardia"}):
		errores.append("Una rutina de guardia no debe permitir participar en eventos.")


func _comprobar_respaldo_castillo(errores: Array[String]) -> void:
	var antes := Rules.seleccionar_rutina_respaldo_castillo(479)
	var inicio := Rules.seleccionar_rutina_respaldo_castillo(480)
	var fin := Rules.seleccionar_rutina_respaldo_castillo(1199)
	var despues := Rules.seleccionar_rutina_respaldo_castillo(1200)

	if str(antes.get("clave", "")) != "regreso_nocturno_castillo":
		errores.append("Antes de las 08:00 debe mantenerse el regreso nocturno al castillo.")
	if str(inicio.get("clave", "")) != "salida_diurna_castillo":
		errores.append("A las 08:00 debe comenzar la salida diurna del castillo.")
	if str(fin.get("ubicacion_clave", "")) != "plaza":
		errores.append("La salida diurna debe mantenerse hasta las 19:59.")
	if str(despues.get("ubicacion_clave", "")) != "castillo":
		errores.append("A las 20:00 debe volver el destino del castillo.")



func _comprobar_catalogo_ocio(errores: Array[String]) -> void:
	var nombres: Array[String] = [
		"elian", "bruna", "darven", "saira", "narel",
		"mara", "ivo", "nima", "abel", "liam"
	]
	for nombre in nombres:
		var catalogo: Dictionary = Rules.obtener_opciones_ocio_npc(nombre)
		var opciones: Variant = catalogo.get("opciones", null)
		if not opciones is Array:
			errores.append("El catálogo de %s debe devolver una lista de opciones." % nombre)
			continue
		if (opciones as Array).size() != 3:
			errores.append("El catálogo de %s debe conservar sus tres opciones." % nombre)
		for opcion_variant in opciones as Array:
			if not opcion_variant is Dictionary:
				errores.append("Las opciones de %s deben ser diccionarios." % nombre)
				continue
			var opcion: Dictionary = opcion_variant
			if str(opcion.get("id", "")).strip_edges().is_empty():
				errores.append("Toda opción de %s debe tener identificador." % nombre)
			if not opcion.get("necesidades", {}) is Dictionary:
				errores.append("Las necesidades de %s deben ser un diccionario." % nombre)

	var desconocido: Dictionary = Rules.obtener_opciones_ocio_npc("npc_inexistente")
	if not (desconocido.get("opciones", []) as Array).is_empty():
		errores.append("Un NPC sin catálogo no debe recibir actividades ajenas.")

	var mayusculas: Dictionary = Rules.obtener_opciones_ocio_npc("ELIAN")
	if not (mayusculas.get("opciones", []) as Array).is_empty():
		errores.append("La normalización del nombre debe seguir en la capa llamadora.")


func _comprobar_desplazamiento_ocio(errores: Array[String]) -> void:
	var primero: Vector2 = Rules.obtener_desplazamiento_ocio("Mara", "1:2:3", 1)
	var repetido: Vector2 = Rules.obtener_desplazamiento_ocio("Mara", "1:2:3", 1)
	if primero != repetido:
		errores.append("El desplazamiento de ocio debe ser estable para las mismas entradas.")

	var permitidos: Array[Vector2] = [
		Vector2(-20.0, -12.0),
		Vector2(16.0, -16.0),
		Vector2(20.0, 12.0),
		Vector2(-16.0, 16.0),
		Vector2(0.0, -20.0)
	]
	if not permitidos.has(primero):
		errores.append("El desplazamiento de ocio debe usar uno de los puntos locales permitidos.")
	if Rules.DESPLAZAMIENTOS_OCIO != permitidos:
		errores.append("Cambió el catálogo de desplazamientos de ocio.")


func _comprobar_desplazamiento_evento(errores: Array[String]) -> void:
	var primero: Vector2 = Rules.obtener_desplazamiento_evento(" Mara ", "mercado_vecinal", "3|12|primavera")
	var repetido: Vector2 = Rules.obtener_desplazamiento_evento(" Mara ", "mercado_vecinal", "3|12|primavera")
	var permitidos: Array[Vector2] = [
		Vector2(-112.0, -72.0), Vector2(-72.0, -104.0),
		Vector2(-24.0, -112.0), Vector2(32.0, -108.0),
		Vector2(88.0, -80.0), Vector2(112.0, -24.0),
		Vector2(96.0, 48.0), Vector2(48.0, 96.0),
		Vector2(-16.0, 112.0), Vector2(-80.0, 88.0),
		Vector2(-120.0, 32.0), Vector2(-48.0, -40.0),
		Vector2(16.0, -48.0), Vector2(64.0, 16.0),
		Vector2(8.0, 56.0), Vector2(-64.0, 8.0)
	]
	if primero != repetido:
		errores.append("El desplazamiento de evento debe ser estable para las mismas entradas.")

	var otro_npc: Vector2 = Rules.obtener_desplazamiento_evento("Ivo", "mercado_vecinal", "3|12|primavera")
	var otra_fecha: Vector2 = Rules.obtener_desplazamiento_evento("Mara", "mercado_vecinal", "3|13|primavera")
	if not permitidos.has(otro_npc) or not permitidos.has(otra_fecha):
		errores.append("Cada combinación de NPC y fecha debe producir un punto permitido.")
	if not permitidos.has(primero):
		errores.append("El desplazamiento de evento debe usar uno de los 16 puntos permitidos.")
	if Rules.POSICIONES_EVENTO != permitidos:
		errores.append("Cambió el catálogo de posiciones de eventos comunitarios.")

func _comprobar_turnos_comercio(errores: Array[String]) -> void:
	var libre := {"clave": "dia_libre", "actividad_clave": "pasear"}
	if not Rules.debe_asignar_turno_comercio("bruna", libre, 0, 9 * 60):
		errores.append("El primer vendedor asignado debe cubrir la franja inicial del lunes.")
	if Rules.debe_asignar_turno_comercio("saira", libre, 0, 9 * 60):
		errores.append("Saira coordina el mercado y no debe entrar en los turnos rotativos.")
	if Rules.debe_asignar_turno_comercio("bruna", {"clave": "trabajo", "actividad_clave": "hornear"}, 0, 9 * 60):
		errores.append("Un turno laboral existente no debe ser sustituido.")
	if Rules.debe_asignar_turno_comercio("bruna", {"clave": "evento_mercado", "actividad_clave": "participar"}, 0, 9 * 60):
		errores.append("Un evento comunitario debe conservar prioridad.")
	if Rules.debe_asignar_turno_comercio("bruna", libre, 0, 8 * 60 + 59):
		errores.append("El mercado no debe asignar turnos antes de las 09:00.")
	if Rules.debe_asignar_turno_comercio("bruna", libre, 0, 18 * 60):
		errores.append("El mercado no debe asignar turnos desde las 18:00.")
	if Rules.debe_asignar_turno_comercio("npc_desconocido", libre, 0, 10 * 60):
		errores.append("Un NPC fuera del catálogo no debe recibir un turno comercial.")

func _comprobar_evaluacion_invitacion(errores: Array[String]) -> void:
	var aceptada := {
		"anio": 3,
		"dia": 12,
		"estado": "aceptada",
		"hora_inicio": 17.0,
		"hora_fin": 19.0,
		"ubicacion_clave": " Plaza "
	}
	var activa := Rules.evaluar_invitacion_npc(aceptada, 3, 12, 17 * 60)
	if not bool(activa.get("activa", false)):
		errores.append("Una invitación aceptada debe activarse al inicio de su franja.")
	if str(activa.get("ubicacion_clave", "")) != "plaza":
		errores.append("La evaluación debe normalizar la ubicación sin modificar la invitación.")

	var antes := Rules.evaluar_invitacion_npc(aceptada, 3, 12, 16 * 60 + 59)
	var fin := Rules.evaluar_invitacion_npc(aceptada, 3, 12, 19 * 60)
	if not antes.is_empty() or not fin.is_empty():
		errores.append("La invitación debe respetar los límites de su franja horaria.")

	var futura := Rules.evaluar_invitacion_npc(aceptada, 3, 11, 17 * 60)
	if not futura.is_empty():
		errores.append("Una invitación de otro día no debe activarse.")

	var pendiente := aceptada.duplicate(true)
	pendiente["estado"] = "pendiente"
	if not Rules.evaluar_invitacion_npc(pendiente, 3, 12, 18 * 60).is_empty():
		errores.append("Una invitación no aceptada no debe activarse.")

	var caducada := Rules.evaluar_invitacion_npc(aceptada, 3, 13, 17 * 60)
	if not bool(caducada.get("caducada", false)):
		errores.append("Una invitación de un día anterior debe marcarse como caducada.")

	if str(aceptada.get("ubicacion_clave", "")) != " Plaza ":
		errores.append("La evaluación pura no debe modificar el diccionario original.")


func _comprobar_requisitos_encuentro_trio(errores: Array[String]) -> void:
	var progreso := {
		"mara_ivo_apoyo": {"etapa": 1},
		"nima_ivo_investigacion": {"etapa": 1}
	}
	var relacion_valida := {
		"interacciones": 1,
		"amistad": 0.2,
		"confianza": 0.2,
		"afecto": 0.1,
		"colaboracion": 0.0,
		"tension": 0.0
	}
	var relaciones: Array[Dictionary] = [
		relacion_valida.duplicate(true),
		relacion_valida.duplicate(true),
		relacion_valida.duplicate(true)
	]
	if not Rules.cumple_requisitos_encuentro_trio(progreso, relaciones):
		errores.append("El encuentro debe habilitarse cuando progreso y los tres vínculos cumplen sus requisitos.")

	var historia_incompleta := progreso.duplicate(true)
	(historia_incompleta["nima_ivo_investigacion"] as Dictionary)["etapa"] = 0
	if Rules.cumple_requisitos_encuentro_trio(historia_incompleta, relaciones):
		errores.append("El encuentro no debe habilitarse antes de completar ambas líneas narrativas.")

	var sin_interacciones := relaciones.duplicate(true)
	(sin_interacciones[1] as Dictionary)["interacciones"] = 0
	if Rules.cumple_requisitos_encuentro_trio(progreso, sin_interacciones):
		errores.append("Cada pareja debe tener al menos una interacción registrada.")

	var vinculo_insuficiente := relaciones.duplicate(true)
	(vinculo_insuficiente[2] as Dictionary)["amistad"] = 0.1
	(vinculo_insuficiente[2] as Dictionary)["confianza"] = 0.1
	(vinculo_insuficiente[2] as Dictionary)["afecto"] = 0.1
	if Rules.cumple_requisitos_encuentro_trio(progreso, vinculo_insuficiente):
		errores.append("Un vínculo inferior al umbral conjunto no debe habilitar el encuentro.")

	var tension_alta := relaciones.duplicate(true)
	(tension_alta[0] as Dictionary)["tension"] = 4.0
	if Rules.cumple_requisitos_encuentro_trio(progreso, tension_alta):
		errores.append("Una tensión de 4.0 o superior debe impedir el encuentro.")

	if Rules.cumple_requisitos_encuentro_trio(progreso, relaciones.slice(0, 2)):
		errores.append("El encuentro requiere exactamente las tres relaciones entre participantes.")

	if int((progreso["mara_ivo_apoyo"] as Dictionary).get("etapa", 0)) != 1:
		errores.append("La evaluación del encuentro no debe modificar el progreso narrativo.")


func _comprobar_patrones_paseo_exterior(errores: Array[String]) -> void:
	var esperados: Dictionary = {
		"elian": [Vector2(-24.0, -8.0), Vector2(-12.0, 22.0), Vector2(18.0, 12.0), Vector2(8.0, -24.0)],
		"bruna": [Vector2(-14.0, 8.0), Vector2(12.0, -10.0), Vector2(18.0, 18.0)],
		"darven": [Vector2(-30.0, -18.0), Vector2(28.0, -16.0), Vector2(30.0, 20.0), Vector2(-26.0, 24.0)],
		"saira": [Vector2(26.0, -22.0), Vector2(34.0, 8.0), Vector2(-18.0, 26.0), Vector2(-30.0, -8.0)],
		"narel": [Vector2(-22.0, -26.0), Vector2(8.0, -34.0), Vector2(24.0, 6.0)],
		"mara": [Vector2(-34.0, -12.0), Vector2(-26.0, 22.0), Vector2(12.0, 32.0)],
		"ivo": [Vector2(-12.0, 8.0), Vector2(12.0, -8.0), Vector2(18.0, 12.0)],
		"nima": [Vector2(0.0, -30.0), Vector2(24.0, -18.0), Vector2(-18.0, -20.0), Vector2(12.0, 24.0)]
	}
	for nombre in esperados:
		if ScheduleSystem.DESPLAZAMIENTOS_PASEO_EXTERIOR.get(nombre, []) != esperados[nombre]:
			errores.append("Cambió el recorrido exterior estable de %s." % nombre)


	var respaldo_esperado: Array[Vector2] = [
		Vector2(-28.0, -12.0), Vector2(24.0, -18.0),
		Vector2(32.0, 10.0), Vector2(-18.0, 28.0),
		Vector2(4.0, -34.0), Vector2(18.0, 32.0),
		Vector2(-34.0, 12.0)
	]
	if ScheduleSystem.DESPLAZAMIENTOS_PASEO_EXTERIOR_DEFAULT != respaldo_esperado:
		errores.append("Cambió el recorrido exterior de respaldo para NPC adicionales.")


func _comprobar_ubicaciones_hogar(errores: Array[String]) -> void:
	var posiciones_esperadas := {
		"elian": Vector2(-72.0, 24.0),
		"bruna": Vector2(64.0, 32.0),
		"darven": Vector2(-24.0, -64.0),
		"saira": Vector2(76.0, -52.0),
		"narel": Vector2(-88.0, -48.0),
		"abel": Vector2(12.0, 76.0),
		"liam": Vector2(104.0, 20.0),
		"mara": Vector2(-132.0, -28.0),
		"ivo": Vector2(18.0, 132.0),
		"nima": Vector2(132.0, -18.0)
	}
	for nombre in posiciones_esperadas:
		if ScheduleSystem.POSICIONES_PLAZA.get(nombre) != posiciones_esperadas[nombre]:
			errores.append("Cambió la posición estable de %s en la plaza." % nombre)
	var casos := {
		"Elian": "casa_elian",
		"Bruna": "casa_bruna",
		"Darven": "casa_darven",
		"Saira": "casa_saira",
		"Narel": "casa_narel",
		"Abel": "castillo",
		"Liam": "castillo",
		"Mara": "vivienda_oeste_01",
		"Ivo": "vivienda_oeste_02",
		"Nima": "vivienda_oeste_03"
	}
	for nombre in casos:
		var obtenido := ScheduleSystem.obtener_clave_hogar("  %s  " % nombre)
		if obtenido != casos[nombre]:
			errores.append("El hogar de %s cambió: esperado %s, obtenido %s." % [nombre, casos[nombre], obtenido])
	if ScheduleSystem.obtener_clave_hogar("NPC desconocido") != "plaza":
		errores.append("Un NPC desconocido debe conservar el hogar de respaldo por defecto.")
	if ScheduleSystem.obtener_clave_hogar("NPC desconocido", "casa_bruna") != "casa_bruna":
		errores.append("Un NPC desconocido debe respetar una ubicación de respaldo válida.")
	if ScheduleSystem.obtener_clave_hogar("NPC desconocido", "ubicacion_invalida") != "plaza":
		errores.append("Una ubicación de respaldo inválida debe volver a la plaza.")
