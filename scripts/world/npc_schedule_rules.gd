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


## Calcula los minutos hasta el siguiente inicio válido del ciclo semanal.
## Devuelve cero cuando no existe un siguiente inicio en el ciclo de cinco días.
static func obtener_minutos_hasta_siguiente_rutina(
	rutinas_variant: Variant,
	dia_semana: int,
	minutos: int
) -> int:
	if not rutinas_variant is Array or (rutinas_variant as Array).is_empty():
		return 0
	var mejor := 5 * 1440
	var rutinas: Array = rutinas_variant
	for desplazamiento_dia in range(5):
		var dia_candidato := posmod(dia_semana + desplazamiento_dia, 5)
		for rutina_variant in rutinas:
			if not rutina_variant is Dictionary:
				continue
			var rutina := rutina_variant as Dictionary
			if not bool(rutina.get("activo", true)):
				continue
			if not coincide_dia(rutina.get("dias_semana", []), dia_candidato):
				continue
			var inicio := hora_a_minutos(rutina.get("hora_inicio", ""))
			var fin := hora_a_minutos(rutina.get("hora_fin", ""))
			if inicio < 0 or fin < 0 or inicio == fin:
				continue
			var candidato := desplazamiento_dia * 1440 + inicio
			if candidato <= minutos:
				continue
			mejor = mini(mejor, candidato - minutos)
	return mejor if mejor < 5 * 1440 else 0


## Asocia actividades con necesidades que pueden satisfacer.
## Mantiene las palabras clave y ponderaciones existentes del sistema NPC.
static func obtener_satisfaccion_actividad(actividad: String) -> Dictionary:
	var texto := actividad.to_lower()
	var satisfacciones: Dictionary = {}
	if texto.contains("descans") or texto.contains("dorm") or texto.contains("sentarse"):
		satisfacciones["descanso"] = 2.0
	if texto.contains("convers") or texto.contains("salud") or texto.contains("compart") or texto.contains("historia") or texto.contains("amigos"):
		satisfacciones["socializacion"] = 1.8
		satisfacciones["diversion"] = 0.6
	if texto.contains("notas") or texto.contains("observar") or texto.contains("leer") or texto.contains("investig") or texto.contains("informes"):
		satisfacciones["curiosidad"] = 1.8
	if texto.contains("pasear") or texto.contains("visitar") or texto.contains("recorrer"):
		satisfacciones["autonomia"] = 1.3
		satisfacciones["diversion"] = 1.0
	if texto.contains("vigilar") or texto.contains("revisar"):
		satisfacciones["seguridad"] = 0.8
	return satisfacciones


## Permite asistir a eventos si la rutina está vacía o corresponde a un día libre.
static func puede_participar_en_evento(rutina: Dictionary) -> bool:
	if rutina.is_empty():
		return true
	var clave := str(rutina.get("clave", "")).strip_edges().to_lower()
	return clave.begins_with("dia_libre")


## Selecciona el horario provisional de Abel y Liam cuando aún no hay rutina propia.
static func seleccionar_rutina_respaldo_castillo(minutos: int) -> Dictionary:
	if minutos >= 480 and minutos < 1200:
		return {
			"clave": "salida_diurna_castillo",
			"ubicacion_clave": "plaza",
			"actividad_clave": "recorrer_torres",
			"activo": true
		}
	return {
		"clave": "regreso_nocturno_castillo",
		"ubicacion_clave": "castillo",
		"actividad_clave": "dormir",
		"activo": true
	}


## Obtiene un desplazamiento corto y estable para las actividades de ocio en la plaza.
## El mismo NPC, fecha y tramo siempre producen la misma posición.
static func obtener_desplazamiento_ocio(nombre: String, clave_dia: String, tramo: int) -> Vector2:
	var desplazamientos: Array[Vector2] = [
		Vector2(-20.0, -12.0),
		Vector2(16.0, -16.0),
		Vector2(20.0, 12.0),
		Vector2(-16.0, 16.0),
		Vector2(0.0, -20.0)
	]
	var indice := absi(hash(nombre + "|" + clave_dia + "|" + str(tramo) + "|pos")) % desplazamientos.size()
	return desplazamientos[indice]


## Catálogo estático de actividades de ocio disponibles por habitante.
## Sólo contiene datos: la selección y validación siguen en NPCScheduleSystem.
static func obtener_opciones_ocio_npc(nombre: String) -> Dictionary:
	var opciones_por_personaje: Dictionary = {
		"elian": [
			{"id":"acomodar_pedidos","ubicacion_clave":"panaderia","necesidades":{"autonomia":0.45,"curiosidad":0.25},"afinidad_rasgos":{"curiosidad":0.65},"coste":8.0},
			{"id":"conversar_con_vecinos","necesidades":{"socializacion":0.9,"diversion":0.3},"afinidad_rasgos":{"sociabilidad":0.85},"coste":5.0},
			{"id":"compartir_pan","ubicacion_clave":"panaderia","necesidades":{"socializacion":0.65,"diversion":0.7},"afinidad_rasgos":{"generosidad":0.85,"sociabilidad":0.65},"coste":8.0}
		],
		"bruna": [
			{"id":"revisar_herramientas","ubicacion_clave":"forja","necesidades":{"curiosidad":0.8,"autonomia":0.3},"afinidad_rasgos":{"curiosidad":0.7,"prudencia":0.7},"coste":8.0},
			{"id":"observar_trabajos","necesidades":{"curiosidad":0.55,"socializacion":0.2},"afinidad_rasgos":{"curiosidad":0.65},"coste":5.0},
			{"id":"descansar_un_rato","ubicacion_clave":"casa_bruna","necesidades":{"descanso":0.95,"diversion":0.2},"coste":2.0}
		],
		"darven": [
			{"id":"vigilar_plaza","necesidades":{"seguridad":0.8,"autonomia":0.25},"afinidad_rasgos":{"prudencia":0.8},"coste":5.0},
			{"id":"revisar_avisos","necesidades":{"curiosidad":0.6,"autonomia":0.2},"afinidad_rasgos":{"prudencia":0.65},"coste":4.0},
			{"id":"conversar_con_habitantes","necesidades":{"socializacion":0.8,"diversion":0.2},"afinidad_rasgos":{"sociabilidad":0.75},"coste":5.0}
		],
		"saira": [
			{"id":"saludar_comerciantes","necesidades":{"socializacion":0.8,"autonomia":0.25},"afinidad_rasgos":{"sociabilidad":0.85},"coste":5.0},
			{"id":"compartir_noticias","necesidades":{"socializacion":0.55,"curiosidad":0.6},"afinidad_rasgos":{"curiosidad":0.75,"sociabilidad":0.65},"coste":6.0},
			{"id":"escuchar_historias","necesidades":{"socializacion":0.7,"diversion":0.5},"afinidad_rasgos":{"sociabilidad":0.7},"coste":4.0}
		],
		"narel": [
			{"id":"tomar_notas","ubicacion_clave":"archivo_real","necesidades":{"curiosidad":0.95,"autonomia":0.2},"afinidad_rasgos":{"curiosidad":0.9},"coste":7.0},
			{"id":"observar_entorno","necesidades":{"curiosidad":0.8,"diversion":0.15},"afinidad_rasgos":{"curiosidad":0.8,"prudencia":0.6},"coste":5.0},
			{"id":"leer_apuntes","ubicacion_clave":"archivo_real","necesidades":{"curiosidad":0.75,"descanso":0.1},"afinidad_rasgos":{"curiosidad":0.85},"coste":3.0}
		],
		"mara": [
			{"id":"pasear_sin_prisa","necesidades":{"autonomia":0.75,"diversion":0.45},"afinidad_rasgos":{"independencia":0.8},"coste":4.0},
			{"id":"observar_la_plaza","necesidades":{"curiosidad":0.55,"seguridad":0.15},"afinidad_rasgos":{"prudencia":0.6},"coste":3.0},
			{"id":"visitar_un_puesto","ubicacion_clave":"casa_comercio","necesidades":{"diversion":0.65,"socializacion":0.35},"afinidad_rasgos":{"sociabilidad":0.55},"coste":6.0}
		],
		"ivo": [
			{"id":"descansar_y_saludar","ubicacion_clave":"plaza","necesidades":{"descanso":0.8,"socializacion":0.35},"afinidad_rasgos":{"sociabilidad":0.45},"coste":2.0},
			{"id":"sentarse_un_rato","ubicacion_clave":"vivienda_oeste_02","necesidades":{"descanso":0.95,"autonomia":0.2},"coste":1.0},
			{"id":"pasear_a_su_ritmo","necesidades":{"autonomia":0.65,"diversion":0.35},"afinidad_rasgos":{"independencia":0.75},"coste":3.0}
		],
		"nima": [
			{"id":"tomar_notas","necesidades":{"curiosidad":0.95,"autonomia":0.2},"afinidad_rasgos":{"curiosidad":0.9},"coste":7.0},
			{"id":"observar_fenomenos","ubicacion_clave":"casa_estudio","necesidades":{"curiosidad":0.9,"diversion":0.2},"afinidad_rasgos":{"curiosidad":0.85},"coste":5.0},
			{"id":"conversar_con_vecinos","necesidades":{"socializacion":0.65,"diversion":0.25},"afinidad_rasgos":{"sociabilidad":0.65},"coste":4.0}
		],
		"abel": [
			{"id":"revisar_asuntos","ubicacion_clave":"castillo","necesidades":{"seguridad":0.55,"autonomia":0.4},"afinidad_rasgos":{"prudencia":0.8},"coste":5.0},
			{"id":"leer_informes","ubicacion_clave":"castillo","necesidades":{"curiosidad":0.7,"autonomia":0.25},"afinidad_rasgos":{"curiosidad":0.65},"coste":4.0},
			{"id":"conversar_con_guardias","ubicacion_clave":"castillo","necesidades":{"socializacion":0.65,"seguridad":0.25},"afinidad_rasgos":{"sociabilidad":0.55},"coste":5.0}
		],
		"liam": [
			{"id":"ordenar_documentos","ubicacion_clave":"castillo","necesidades":{"curiosidad":0.45,"autonomia":0.35},"afinidad_rasgos":{"prudencia":0.65},"coste":4.0},
			{"id":"recorrer_el_castillo","ubicacion_clave":"castillo","necesidades":{"seguridad":0.5,"autonomia":0.4},"afinidad_rasgos":{"prudencia":0.7},"coste":5.0},
			{"id":"descansar_un_rato","necesidades":{"descanso":0.85,"diversion":0.15},"coste":2.0}
		]
	}
	return {"opciones": opciones_por_personaje.get(nombre, [])}

## Distribuye a los NPC en puntos fijos alrededor de un evento.
## La fecha se recibe ya resuelta para mantener la lectura del mundo fuera de esta regla.
static func obtener_desplazamiento_evento(
	nombre_npc: String,
	clave_evento: String,
	fecha: String
) -> Vector2:
	var posiciones: Array[Vector2] = [
		Vector2(-112.0, -72.0), Vector2(-72.0, -104.0),
		Vector2(-24.0, -112.0), Vector2(32.0, -108.0),
		Vector2(88.0, -80.0), Vector2(112.0, -24.0),
		Vector2(96.0, 48.0), Vector2(48.0, 96.0),
		Vector2(-16.0, 112.0), Vector2(-80.0, 88.0),
		Vector2(-120.0, 32.0), Vector2(-48.0, -40.0),
		Vector2(16.0, -48.0), Vector2(64.0, 16.0),
		Vector2(8.0, 56.0), Vector2(-64.0, 8.0)
	]
	var firma := nombre_npc.strip_edges().to_lower() + "|" + clave_evento + "|" + fecha
	var indice := posmod(hash(firma), posiciones.size())
	return posiciones[indice]
