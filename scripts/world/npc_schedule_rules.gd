extends RefCounted
class_name NPCScheduleRules

## Convierte una hora HH:MM a minutos desde medianoche.
## Devuelve -1 cuando el formato o sus componentes no son válidos.
static func hora_a_minutos(valor: Variant) -> int:
	var partes := str(valor).strip_edges().split(":")
	if partes.size() < 2:
		return -1
	if not partes[0].is_valid_int() or not partes[1].is_valid_int():
		return -1
	var hora := int(partes[0])
	var minuto := int(partes[1])
	if hora < 0 or hora > 23 or minuto < 0 or minuto > 59:
		return -1
	return hora * 60 + minuto


## Comprueba si el día aparece en la lista recibida desde WorldData.
## Acepta int, float y String numérico porque los datos JSON/RPC pueden
## representar el mismo valor con tipos numéricos distintos.
## Una lista vacía o ausente significa que la rutina aplica todos los días.
static func coincide_dia(dias_variant: Variant, dia: int) -> bool:
	if not dias_variant is Array or (dias_variant as Array).is_empty():
		return true

	for dia_variant in dias_variant as Array:
		if dia_variant is int or dia_variant is float:
			if is_equal_approx(float(dia_variant), float(dia)):
				return true
		elif dia_variant is String:
			var dia_texto := str(dia_variant).strip_edges()
			if dia_texto.is_valid_int() and int(dia_texto) == dia:
				return true
	return false


## Selecciona la rutina activa de una lista sin modificar sus datos de origen.
## El resultado incluye diagnósticos para que la capa de simulación decida cómo mostrarlos.
static func seleccionar_rutina(
	rutinas_variant: Variant,
	dia_semana: int,
	minutos: int
) -> Dictionary:
	var mejor: Dictionary = {}
	var prioridad_mejor := -2147483648
	var inicio_mejor := -1
	var diagnostico_rechazos: Array[String] = []
	if not rutinas_variant is Array:
		return {"rutina": mejor, "rechazos": diagnostico_rechazos}

	var rutinas: Array = rutinas_variant
	for indice in range(rutinas.size()):
		var rutina_variant: Variant = rutinas[indice]
		if not rutina_variant is Dictionary:
			diagnostico_rechazos.append("[%d] no_es_diccionario" % indice)
			continue
		var rutina: Dictionary = rutina_variant
		var clave := str(rutina.get("clave", "sin_clave"))
		if not bool(rutina.get("activo", true)):
			diagnostico_rechazos.append(clave + ": inactiva")
			continue

		var inicio_raw: Variant = rutina.get("hora_inicio", "")
		var fin_raw: Variant = rutina.get("hora_fin", "")
		var inicio := hora_a_minutos(inicio_raw)
		var fin := hora_a_minutos(fin_raw)
		if inicio < 0 or fin < 0 or inicio == fin:
			diagnostico_rechazos.append(
				clave + ": hora_invalida inicio=" + str(inicio_raw)
				+ " fin=" + str(fin_raw)
				+ " parseadas=" + str(inicio) + "/" + str(fin)
			)
			continue

		var dia_referencia := dia_semana
		var esta_activa := false
		if fin > inicio:
			esta_activa = minutos >= inicio and minutos < fin
		elif minutos >= inicio:
			esta_activa = true
		elif minutos < fin:
			esta_activa = true
			dia_referencia = posmod(dia_semana - 1, 5)

		var dias_variant: Variant = rutina.get("dias_semana", [])
		var dia_coincide := coincide_dia(dias_variant, dia_referencia)
		if not esta_activa or not dia_coincide:
			var motivo := "fuera_de_hora" if not esta_activa else "dia_no_coincide"
			diagnostico_rechazos.append(
				clave + ": " + motivo
				+ " ahora=" + str(minutos)
				+ " rango=" + str(inicio) + "-" + str(fin)
				+ " dia=" + str(dia_referencia)
				+ " dias=" + str(dias_variant)
			)
			continue

		var prioridad := int(rutina.get("prioridad", 0))
		if mejor.is_empty() or prioridad > prioridad_mejor or (
			prioridad == prioridad_mejor and inicio > inicio_mejor
		):
			mejor = rutina.duplicate(true)
			prioridad_mejor = prioridad
			inicio_mejor = inicio

	return {"rutina": mejor, "rechazos": diagnostico_rechazos}


## Selecciona la actividad cotidiana de un NPC durante su día libre.
## Sólo depende del nombre visible y los minutos del día.
static func seleccionar_rutina_dia_libre(nombre_npc: String, minutos: int) -> Dictionary:
	var nombre := nombre_npc.strip_edges().to_lower()
	var hogares: Dictionary = {
		"elian": "casa_elian",
		"bruna": "casa_bruna",
		"darven": "casa_darven",
		"saira": "casa_saira",
		"narel": "casa_narel",
		"abel": "castillo",
		"liam": "castillo",
		"mara": "vivienda_oeste_01",
		"ivo": "vivienda_oeste_02",
		"nima": "vivienda_oeste_03"
	}
	var hogar := str(hogares.get(nombre, "plaza"))
	var ubicacion := hogar
	var actividad := "descansar"
	var clave := "dia_libre_casa"

	if minutos >= 540 and minutos < 720:
		clave = "dia_libre_manana"
		actividad = "pasear"
		match nombre:
			"darven":
				ubicacion = "cuartel"
				actividad = "recorrer_alrededores"
			"narel":
				ubicacion = "archivo_real"
				actividad = "leer"
			"mara":
				ubicacion = hogar
				actividad = "ordenar_sus_espacios"
			"ivo":
				ubicacion = hogar
				actividad = "descansar"
			"nima":
				ubicacion = "casa_estudio"
				actividad = "revisar_apuntes"
			"abel", "liam":
				ubicacion = "castillo"
				actividad = "atender_asuntos_del_castillo"
			_:
				ubicacion = "plaza"
	elif minutos >= 840 and minutos < 1020:
		clave = "dia_libre_tarde"
		actividad = "pasear"
		match nombre:
			"saira":
				ubicacion = "casa_comercio"
				actividad = "visitar_comerciantes"
			"narel", "nima":
				ubicacion = "casa_estudio"
				actividad = "visitar_estudio"
			"darven":
				ubicacion = "plaza"
				actividad = "descansar"
			"mara":
				ubicacion = "plaza"
				actividad = "pasear_sin_prisa"
			"ivo":
				ubicacion = "plaza"
				actividad = "descansar_y_saludar"
			"elian":
				ubicacion = hogar
				actividad = "descansar_del_trabajo"
			"bruna":
				ubicacion = hogar
				actividad = "revisar_sus_herramientas"
			"abel", "liam":
				ubicacion = "castillo"
				actividad = "organizar_asuntos_internos"
			_:
				ubicacion = "plaza"
	elif minutos >= 1020 and minutos < 1200:
		clave = "dia_libre_encuentro"
		ubicacion = "plaza"
		actividad = "conversar"
	elif minutos >= 1200:
		clave = "dia_libre_regreso"
		ubicacion = hogar
		actividad = "volver_a_casa"

	return {
		"clave": clave,
		"ubicacion_clave": ubicacion,
		"actividad_clave": actividad,
		"activo": true
	}


## Resuelve el evento comunitario para un día del ciclo y una fecha estacional.
## El evento estacional tiene prioridad sobre los eventos del quinto día.
static func obtener_evento_comunitario(
	dia_estacion: int,
	dia_semana: int,
	minutos: int
) -> Dictionary:
	if dia_estacion == 1 and minutos >= 840 and minutos < 1200:
		return {
			"clave": "celebracion_estacional",
			"nombre": "Celebración de temporada",
			"actividad": "celebrar_el_cambio_de_estacion",
			"aviso": "Hoy los vecinos celebran el comienzo de una nueva estación en la plaza."
		}
	if dia_semana != 4:
		return {}
	if minutos >= 540 and minutos < 1020:
		return {
			"clave": "mercado_vecinal",
			"nombre": "Mercado vecinal",
			"actividad": "visitar_el_mercado",
			"aviso": "Hoy hay mercado vecinal en la plaza de Torres."
		}
	if minutos >= 1020 and minutos < 1200:
		return {
			"clave": "comida_comunitaria",
			"nombre": "Comida comunitaria",
			"actividad": "compartir_comida_con_vecinos",
			"aviso": "Los vecinos se reúnen en la plaza para compartir comida."
		}
	return {}
