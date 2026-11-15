extends Node
class_name RelationshipSystemService

## Relaciones sociales de la partida.
##
## Supabase define la personalidad y los valores iniciales.
## GameState conserva el estado que cambia durante la partida.

signal relacion_cambiada(personaje_id: String, relacion: Dictionary)
signal recuerdo_registrado(personaje_id: String, recuerdo: Dictionary)
signal reglas_sociales_cargadas

var _reglas: Dictionary = {}
var _regalos: Array = []
var _cargado: bool = false
var _repository: Node = null
var _game_state: Node = null
var _world_atmosphere: Node = null




func configurar(
	repository: Node,
	game_state: Node = null,
	world_atmosphere: Node = null
) -> void:
	_repository = repository
	_game_state = game_state
	_world_atmosphere = world_atmosphere
	if _repository == null or _game_state == null:
		push_error("RelationshipSystem: dependencias no configuradas.")
		return

	if _repository.has_signal("reglas_cargadas"):
		var reglas_signal: Signal = _repository.reglas_cargadas
		if not reglas_signal.is_connected(_al_reglas_cargadas):
			reglas_signal.connect(_al_reglas_cargadas)
	if _repository.has_signal("regalos_cargados"):
		var regalos_signal: Signal = _repository.regalos_cargados
		if not regalos_signal.is_connected(_al_regalos_cargados):
			regalos_signal.connect(_al_regalos_cargados)

	_cargar_reglas_disponibles()


func _cargar_reglas_disponibles() -> void:
	if _repository == null:
		return
	_repository.cargar_regalos()
	_repository.cargar_reglas()


func _al_regalos_cargados(regalos: Array) -> void:
	_regalos = regalos.duplicate(true)


func _al_reglas_cargadas(reglas: Array) -> void:
	_reglas.clear()
	for regla_variant in reglas:
		if not regla_variant is Dictionary:
			continue
		var regla := regla_variant as Dictionary
		var personaje_id := str(regla.get("personaje_game_id", "")).strip_edges()
		if personaje_id.is_empty():
			continue
		_reglas[personaje_id] = regla.duplicate(true)
	# La consulta terminó correctamente aunque algunos NPC no tengan perfil social aún.
	_cargado = true
	reglas_sociales_cargadas.emit()


func esta_cargado() -> bool:
	return _cargado


func obtener_reglas_sociales() -> Dictionary:
	return _reglas.duplicate(true)


func obtener_relacion(personaje_id: String) -> Dictionary:
	if personaje_id.is_empty():
		return {}

	var relaciones := _obtener_relaciones_guardadas()
	if relaciones.has(personaje_id):
		var guardada: Variant = relaciones.get(personaje_id, {})
		if guardada is Dictionary:
			return (guardada as Dictionary).duplicate(true)

	var personaje := WorldData.obtener_personaje_game_por_id(personaje_id)
	if personaje.is_empty():
		return {}

	# Un NPC sin fila en personaje_social_v1 comienza neutral y puede
	# acumular amistad/recuerdos normalmente. No se inventa personalidad canónica.
	var regla_variant: Variant = _reglas.get(personaje_id, {})
	var regla: Dictionary = regla_variant as Dictionary if regla_variant is Dictionary else {}
	var nueva := {
		"amistad": float(regla.get("amistad_inicial", 0.0)),
		"confianza": float(regla.get("confianza_inicial", 0.0)),
		"respeto": float(regla.get("respeto_inicial", 0.0)),
		"afecto": float(regla.get("afecto_inicial", 0.0))
	}

	relaciones[personaje_id] = nueva
	_guardar_relaciones(relaciones)
	return nueva.duplicate(true)


## Estado de la interacción antes de registrar la conversación actual.
## Expone una copia del calendario actual para seleccionar diálogos contextuales.
func obtener_contexto_temporal() -> Dictionary:
	if (
		_world_atmosphere == null
		or not is_instance_valid(_world_atmosphere)
		or not _world_atmosphere.has_method("obtener_tiempo")
	):
		return {}
	var tiempo_variant: Variant = _world_atmosphere.call("obtener_tiempo")
	if tiempo_variant is Dictionary:
		return (tiempo_variant as Dictionary).duplicate(true)
	return {}


func obtener_estado_dialogo(personaje_id: String) -> Dictionary:
	var relacion := obtener_relacion(personaje_id)
	if relacion.is_empty():
		return {}
	var dia_actual := _obtener_clave_dia_actual()
	return {
		"primera_vez": not relacion.has("_ultimo_dialogo_dia"),
		"primera_del_dia": str(relacion.get("_ultimo_dialogo_dia", "")) != dia_actual
	}


func modificar_relacion(
	personaje_id: String,
	cambios: Dictionary,
	recuerdo: Dictionary = {}
) -> Dictionary:
	var relacion := obtener_relacion(personaje_id)
	if relacion.is_empty():
		return {}

	for clave in ["amistad", "confianza", "respeto", "afecto"]:
		if cambios.has(clave):
			relacion[clave] = clampf(
				float(relacion.get(clave, 0.0)) + float(cambios.get(clave, 0.0)),
				-100.0,
				100.0
			)

	var relaciones := _obtener_relaciones_guardadas()
	relaciones[personaje_id] = relacion.duplicate(true)
	_guardar_relaciones(relaciones)

	if not recuerdo.is_empty():
		registrar_recuerdo(personaje_id, recuerdo)

	relacion_cambiada.emit(personaje_id, relacion.duplicate(true))
	return relacion.duplicate(true)


## Registra consecuencias de acciones del jugador sobre un personaje.
## evento_id permite que una misma promesa/misión no aplique dos veces el cambio.
func registrar_evento_social(
	personaje_id: String,
	evento: String,
	evento_id: String = "",
	contexto: Dictionary = {}
) -> Dictionary:
	var id := personaje_id.strip_edges()
	var clave_evento := evento.strip_edges().to_lower()
	if id.is_empty() or clave_evento.is_empty():
		return {}

	var definicion := _obtener_impacto_evento(clave_evento)
	if definicion.is_empty():
		push_warning("RelationshipSystem: evento social desconocido: " + clave_evento)
		return {}

	var id_unico := evento_id.strip_edges()
	if not id_unico.is_empty():
		var recuerdos_previos := obtener_recuerdos(id)
		for recuerdo_variant in recuerdos_previos:
			if not recuerdo_variant is Dictionary:
				continue
			var recuerdo_existente := recuerdo_variant as Dictionary
			if (
				str(recuerdo_existente.get("tipo", "")) == "evento_social"
				and str(recuerdo_existente.get("evento_id", "")) == id_unico
			):
				return obtener_relacion(id)

	var personalidad := obtener_personalidad(id)
	var cambios: Dictionary = definicion.get("cambios", {}).duplicate(true)
	var rasgo := str(definicion.get("rasgo", ""))
	var escala := 1.0
	if not rasgo.is_empty():
		var valor_rasgo := clampf(float(personalidad.get(rasgo, 50.0)), 0.0, 100.0)
		escala = 0.75 + valor_rasgo / 200.0
	if bool(definicion.get("inverso", false)):
		escala = 1.25 - (escala - 0.75)

	for eje in cambios.keys():
		cambios[eje] = float(cambios[eje]) * escala

	var recuerdo := {
		"tipo": "evento_social",
		"evento": clave_evento,
		"evento_id": id_unico,
		"importancia": float(definicion.get("importancia", 2.0)),
		"contexto": contexto.duplicate(true),
		"momento": Time.get_datetime_string_from_system(true)
	}
	var resultado := modificar_relacion(id, cambios, recuerdo)
	var tendencias_variant: Variant = resultado.get("_tendencias_sociales", {})
	var tendencias: Dictionary = tendencias_variant.duplicate(true) if tendencias_variant is Dictionary else {}
	var contador := ""
	match clave_evento:
		"promesa_cumplida": contador = "promesas_cumplidas"
		"promesa_rota": contador = "promesas_rotas"
		"ayudar": contador = "ayudas"
		"apoyar": contador = "apoyos"
		"compartir_conocimiento": contador = "conocimientos_compartidos"
		"mentir": contador = "mentiras"
		"traicionar": contador = "traiciones"
		"faltar_respeto": contador = "faltas_respeto"
	if not contador.is_empty():
		tendencias[contador] = int(tendencias.get(contador, 0)) + 1
		resultado["_tendencias_sociales"] = tendencias
		var relaciones_actuales := _obtener_relaciones_guardadas()
		relaciones_actuales[id] = resultado.duplicate(true)
		_guardar_relaciones(relaciones_actuales)
	return resultado


func _obtener_impacto_evento(evento: String) -> Dictionary:
	# El rasgo modifica la intensidad de la reacción, no decide si la acción
	# fue buena o mala. La escala permanece acotada entre 0.75 y 1.25.
	var tabla := {
		"ayudar": {"cambios": {"amistad": 1.5, "confianza": 1.0}, "rasgo": "generosidad"},
		"apoyar": {"cambios": {"amistad": 2.0, "afecto": 1.0}, "rasgo": "sociabilidad"},
		"promesa_cumplida": {"cambios": {"amistad": 1.5, "confianza": 4.0}, "rasgo": "prudencia", "inverso": true, "importancia": 3.0},
		"promesa_rota": {"cambios": {"amistad": -3.0, "confianza": -10.0}, "rasgo": "prudencia", "importancia": 4.0},
		"decir_verdad": {"cambios": {"confianza": 3.0}, "rasgo": "prudencia", "inverso": true},
		"mentir": {"cambios": {"confianza": -8.0, "respeto": -1.0}, "rasgo": "prudencia", "importancia": 3.0},
		"demostrar_habilidad": {"cambios": {"respeto": 2.5, "amistad": 0.5}, "rasgo": "curiosidad"},
		"compartir_conocimiento": {"cambios": {"amistad": 1.0, "respeto": 1.5}, "rasgo": "curiosidad"},
		"interesarse": {"cambios": {"amistad": 0.8, "confianza": 0.4}, "rasgo": "sociabilidad", "importancia": 1.0},
		"faltar_respeto": {"cambios": {"respeto": -7.0, "amistad": -2.0}, "rasgo": "agresividad", "importancia": 3.0},
		"traicionar": {"cambios": {"confianza": -20.0, "amistad": -8.0, "afecto": -4.0}, "rasgo": "prudencia", "importancia": 5.0}
	}
	return (tabla.get(evento, {}) as Dictionary).duplicate(true)


func registrar_dialogo(personaje_id: String, clave: String) -> Dictionary:
	var id := personaje_id.strip_edges()
	var clave_dialogo := clave.strip_edges()
	if id.is_empty() or clave_dialogo.is_empty():
		return {}

	var relacion_actual := obtener_relacion(id)
	if relacion_actual.is_empty():
		return {}

	var dia_actual := _obtener_clave_dia_actual()
	var primera_conversacion_del_dia := (
		str(relacion_actual.get("_ultimo_dialogo_dia", "")) != dia_actual
	)
	var cambios := {"amistad": 0.5} if primera_conversacion_del_dia else {}
	var recuerdo := {
		"tipo": "dialogo",
		"clave": clave_dialogo,
		"importancia": 1.0,
		"amistad_diaria": primera_conversacion_del_dia,
		"dia_mundo": dia_actual,
		"momento": Time.get_datetime_string_from_system(true)
	}

	var relacion_actualizada := modificar_relacion(id, cambios, recuerdo)
	if relacion_actualizada.is_empty():
		return {}

	relacion_actualizada["_ultimo_dialogo_dia"] = dia_actual
	var relaciones := _obtener_relaciones_guardadas()
	relaciones[id] = relacion_actualizada.duplicate(true)
	_guardar_relaciones(relaciones)
	return relacion_actualizada


func _obtener_clave_dia_actual() -> String:
	if (
		_world_atmosphere != null
		and is_instance_valid(_world_atmosphere)
		and _world_atmosphere.has_method("obtener_tiempo")
	):
		var tiempo_variant: Variant = _world_atmosphere.call("obtener_tiempo")
		if tiempo_variant is Dictionary:
			var tiempo := tiempo_variant as Dictionary
			if (
				bool(tiempo.get("calendario_cargado", false))
				and tiempo.has("anio")
				and tiempo.has("dia")
			):
				return "mundo:%d:%d" % [
					int(tiempo.get("anio", 0)),
					int(tiempo.get("dia", 1))
				]

	return "real:" + Time.get_date_string_from_system()


func registrar_recuerdo(personaje_id: String, recuerdo: Dictionary) -> void:
	if personaje_id.is_empty():
		return

	var recuerdos := _obtener_recuerdos()
	var lista: Array = recuerdos.get(personaje_id, [])
	var nuevo_recuerdo := recuerdo.duplicate(true)
	var tipo := str(nuevo_recuerdo.get("tipo", "")).strip_edges()
	var clave := str(nuevo_recuerdo.get("clave", "")).strip_edges()
	var indice_existente := -1

	# Un tema recurrente conserva una memoria estable en vez de llenar el
	# historial con copias idénticas. Se actualizan el último intercambio y
	# el contador para que el selector pueda dar prioridad a temas menos usados.
	if tipo == "tema_conversacion" and not clave.is_empty():
		for i in range(lista.size()):
			if not lista[i] is Dictionary:
				continue
			var candidato_existente := lista[i] as Dictionary
			if (
				str(candidato_existente.get("tipo", "")) == "tema_conversacion"
				and str(candidato_existente.get("clave", "")).strip_edges() == clave
			):
				indice_existente = i
				break

	if indice_existente >= 0:
		var registro_actualizado := (lista[indice_existente] as Dictionary).duplicate(true)
		var veces := maxi(1, int(registro_actualizado.get("veces_conversado", 1))) + 1
		var uid := str(registro_actualizado.get("recuerdo_uid", ""))
		var mencionado := bool(registro_actualizado.get("mencionado_en_dialogo", false))
		var primera_vez := str(registro_actualizado.get("primer_momento", registro_actualizado.get("momento", "")))
		var importancia_anterior := float(registro_actualizado.get("importancia", 1.0))
		for campo in nuevo_recuerdo.keys():
			registro_actualizado[campo] = nuevo_recuerdo[campo]
		registro_actualizado["recuerdo_uid"] = uid if not uid.is_empty() else "%s:%d:%d" % [personaje_id, Time.get_ticks_usec(), indice_existente]
		registro_actualizado["veces_conversado"] = veces
		registro_actualizado["primer_momento"] = primera_vez
		registro_actualizado["mencionado_en_dialogo"] = mencionado
		registro_actualizado["importancia"] = maxf(importancia_anterior, float(nuevo_recuerdo.get("importancia", 1.0)))
		lista[indice_existente] = registro_actualizado
		nuevo_recuerdo = registro_actualizado.duplicate(true)
	else:
		if str(nuevo_recuerdo.get("recuerdo_uid", "")).is_empty():
			nuevo_recuerdo["recuerdo_uid"] = "%s:%d:%d" % [
				personaje_id,
				Time.get_ticks_usec(),
				lista.size()
			]
		if tipo == "tema_conversacion":
			nuevo_recuerdo["veces_conversado"] = 1
			nuevo_recuerdo["primer_momento"] = str(nuevo_recuerdo.get("momento", ""))
		lista.append(nuevo_recuerdo)

	while lista.size() > 32:
		var indice_descartar := -1
		var menor_importancia := INF
		for i in range(lista.size()):
			if not lista[i] is Dictionary:
				indice_descartar = i
				break
			var importancia := float((lista[i] as Dictionary).get("importancia", 1.0))
			if importancia < menor_importancia:
				menor_importancia = importancia
				indice_descartar = i
		if indice_descartar < 0:
			break
		lista.remove_at(indice_descartar)

	recuerdos[personaje_id] = lista
	_game_state.call("guardar_recuerdos_sociales", recuerdos)
	recuerdo_registrado.emit(personaje_id, nuevo_recuerdo.duplicate(true))


func obtener_recuerdos(personaje_id: String) -> Array:
	var recuerdos := _obtener_recuerdos()
	var lista_variant: Variant = recuerdos.get(personaje_id, [])
	if lista_variant is Array:
		return (lista_variant as Array).duplicate(true)
	return []



## Devuelve el recuerdo social pendiente más importante sin consumirlo.
## Se marca después de que DialogueSystem haya mostrado la primera línea.
func obtener_recuerdo_pendiente_mencionar(personaje_id: String) -> Dictionary:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return {}
	var recuerdos := _obtener_recuerdos()
	var lista_variant: Variant = recuerdos.get(id, [])
	if not lista_variant is Array:
		return {}
	var lista: Array = lista_variant
	var mejor_indice := -1
	var mejor_importancia := -1.0
	for i in range(lista.size()):
		if not lista[i] is Dictionary:
			continue
		var recuerdo := (lista[i] as Dictionary).duplicate(true)
		var tipo := str(recuerdo.get("tipo", "")).strip_edges()
		if bool(recuerdo.get("mencionado_en_dialogo", false)):
			continue
		if tipo == "regalo":
			if str(recuerdo.get("item_nombre", "")).strip_edges().is_empty():
				continue
		elif tipo == "evento_social" or tipo == "tema_conversacion":
			if float(recuerdo.get("importancia", 0.0)) < 3.0:
				continue
			if tipo == "tema_conversacion" and str(recuerdo.get("frase_jugador", "")).strip_edges().is_empty():
				continue
		else:
			continue
		var importancia := float(recuerdo.get("importancia", 1.0))
		if importancia > mejor_importancia:
			mejor_importancia = importancia
			mejor_indice = i
	if mejor_indice < 0:
		return {}
	var resultado := (lista[mejor_indice] as Dictionary).duplicate(true)
	if str(resultado.get("recuerdo_uid", "")).is_empty():
		resultado["recuerdo_uid"] = "%s:%d:%d" % [
			id,
			Time.get_ticks_usec(),
			mejor_indice
		]
		lista[mejor_indice] = resultado.duplicate(true)
		recuerdos[id] = lista
		_game_state.call("guardar_recuerdos_sociales", recuerdos)
	resultado["_indice_recuerdo"] = mejor_indice
	return resultado


## Marca un recuerdo como mencionado sólo después de mostrar su diálogo.
func marcar_recuerdo_mencionado(
	personaje_id: String,
	indice_respaldo: int,
	recuerdo_uid: String = ""
) -> bool:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return false
	var recuerdos := _obtener_recuerdos()
	var lista_variant: Variant = recuerdos.get(id, [])
	if not lista_variant is Array:
		return false
	var lista: Array = lista_variant
	var indice := -1
	if not recuerdo_uid.is_empty():
		for i in range(lista.size()):
			if not lista[i] is Dictionary:
				continue
			if str((lista[i] as Dictionary).get("recuerdo_uid", "")) == recuerdo_uid:
				indice = i
				break
		if indice < 0:
			return false
	else:
		indice = indice_respaldo
	if indice < 0 or indice >= lista.size() or not lista[indice] is Dictionary:
		return false
	var recuerdo := (lista[indice] as Dictionary).duplicate(true)
	if bool(recuerdo.get("mencionado_en_dialogo", false)):
		return false
	recuerdo["mencionado_en_dialogo"] = true
	lista[indice] = recuerdo
	recuerdos[id] = lista
	_game_state.call("guardar_recuerdos_sociales", recuerdos)
	return true


## Compatibilidad con llamadas antiguas.
## Busca exclusivamente regalos para que un evento social importante no los oculte.
func tomar_regalo_pendiente_mencionar(personaje_id: String) -> Dictionary:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return {}
	var lista := obtener_recuerdos(id)
	var mejor_indice := -1
	var mejor_importancia := -1.0
	for i in range(lista.size()):
		if not lista[i] is Dictionary:
			continue
		var candidato := (lista[i] as Dictionary).duplicate(true)
		if (
			str(candidato.get("tipo", "")) != "regalo"
			or bool(candidato.get("mencionado_en_dialogo", false))
			or str(candidato.get("item_nombre", "")).strip_edges().is_empty()
		):
			continue
		var importancia := float(candidato.get("importancia", 1.0))
		if importancia > mejor_importancia:
			mejor_importancia = importancia
			mejor_indice = i
	if mejor_indice < 0:
		return {}
	var recuerdo := (lista[mejor_indice] as Dictionary).duplicate(true)
	var uid := str(recuerdo.get("recuerdo_uid", ""))
	if not marcar_recuerdo_mencionado(id, mejor_indice, uid):
		return {}
	return recuerdo


func evaluar_regalo(personaje_id: String, item_id: String) -> Dictionary:
	var id_personaje := personaje_id.strip_edges()
	var id_item := item_id.strip_edges()
	if id_personaje.is_empty() or id_item.is_empty():
		return {
			"reaccion": "neutral",
			"amistad": 0.0,
			"confianza": 0.0,
			"respeto": 0.0,
			"afecto": 0.0
		}

	for regalo_variant in _regalos:
		if not regalo_variant is Dictionary:
			continue
		var regalo := regalo_variant as Dictionary
		if str(regalo.get("personaje_game_id", "")).strip_edges() != id_personaje:
			continue
		if str(regalo.get("item_id", "")).strip_edges() != id_item:
			continue
		if not bool(regalo.get("activo", true)):
			continue
		return regalo.duplicate(true)

	return {
		"reaccion": "neutral",
		"amistad": 0.0,
		"confianza": 0.0,
		"respeto": 0.0,
		"afecto": 0.0
	}


## Un objeto se considera conocido cuando existe una reacción específica
## cargada para ese NPC en personaje_regalos_v1.
func conoce_item(personaje_id: String, item_id: String) -> bool:
	var id_personaje := personaje_id.strip_edges()
	var id_item := item_id.strip_edges()
	if id_personaje.is_empty() or id_item.is_empty():
		return false
	for regalo_variant in _regalos:
		if not regalo_variant is Dictionary:
			continue
		var regalo := regalo_variant as Dictionary
		if (
			str(regalo.get("personaje_game_id", "")).strip_edges() == id_personaje
			and str(regalo.get("item_id", "")).strip_edges() == id_item
			and bool(regalo.get("activo", true))
		):
			return true
	return false


func registrar_regalo(personaje_id: String, item_id: String, nombre_item: String = "") -> Dictionary:
	if personaje_id.is_empty() or item_id.is_empty():
		return {}

	var regalo := evaluar_regalo(personaje_id, item_id)
	var cambios := {
		"amistad": float(regalo.get("amistad", 0.0)),
		"confianza": float(regalo.get("confianza", 0.0)),
		"respeto": float(regalo.get("respeto", 0.0)),
		"afecto": float(regalo.get("afecto", 0.0))
	}
	var recuerdo := {
		"tipo": "regalo",
		"item_id": item_id,
		"item_nombre": nombre_item.strip_edges(),
		"reaccion": str(regalo.get("reaccion", "neutral")),
		"importancia": 2.0,
		"momento": Time.get_datetime_string_from_system(true)
	}
	return modificar_relacion(personaje_id, cambios, recuerdo)


func obtener_personalidad(personaje_id: String) -> Dictionary:
	var regla: Variant = _reglas.get(personaje_id, {})
	if regla is Dictionary and not (regla as Dictionary).is_empty():
		return (regla as Dictionary).duplicate(true)
	# Valores neutrales para NPC sin perfil social específico en Supabase.
	return {
		"sociabilidad": 50.0,
		"curiosidad": 50.0,
		"generosidad": 50.0,
		"prudencia": 50.0,
		"agresividad": 50.0
	}


func seleccionar_variante_dialogo(variantes: Array, personaje_id: String) -> Dictionary:
	var relacion := obtener_relacion(personaje_id)
	var mejor: Dictionary = {}
	var mejor_prioridad := -2147483648
	var mejor_especificidad := -1
	var hay_requisitos_sociales := false

	for variante_variant in variantes:
		if not variante_variant is Dictionary:
			continue

		var variante := variante_variant as Dictionary
		var requisito_variant: Variant = variante.get("requisito_social", {})

		if not requisito_variant is Dictionary:
			continue

		var requisito := requisito_variant as Dictionary
		if requisito.is_empty():
			continue

		hay_requisitos_sociales = true

		if not _cumple_requisito_social(requisito, relacion):
			continue

		var prioridad := int(variante.get("prioridad", 0))
		var especificidad := requisito.size()
		if (
			mejor.is_empty()
			or prioridad > mejor_prioridad
			or (
				prioridad == mejor_prioridad
				and (
					especificidad > mejor_especificidad
					or (
						especificidad == mejor_especificidad
						and str(variante.get("clave", "")) < str(mejor.get("clave", ""))
					)
				)
			)
		):
			mejor = variante.duplicate(true)
			mejor_prioridad = prioridad
			mejor_especificidad = especificidad

	if not hay_requisitos_sociales:
		return {}

	return mejor


func _cumple_requisito_social(requisito: Dictionary, relacion: Dictionary) -> bool:
	for clave in ["amistad", "confianza", "respeto", "afecto"]:
		var valor := float(relacion.get(clave, 0.0))
		if requisito.has(clave + "_min") and valor < float(requisito.get(clave + "_min")):
			return false
		if requisito.has(clave + "_max") and valor > float(requisito.get(clave + "_max")):
			return false
	return true



## Evita repetir variantes narrativas que ya se mostraron.
## ciclo distingue una variante única de una que puede reaparecer en otro periodo.
func variante_dialogo_ya_mostrada(
	personaje_id: String,
	clave_variante: String,
	ciclo: String = "unica"
) -> bool:
	var id := personaje_id.strip_edges()
	var clave := clave_variante.strip_edges()
	if id.is_empty() or clave.is_empty():
		return false
	var relacion := obtener_relacion(id)
	var vistas_variant: Variant = relacion.get("_variantes_dialogo_vistas", {})
	if not vistas_variant is Dictionary:
		return false
	var clave_registro := "%s::%s" % [clave, ciclo.strip_edges()]
	return bool((vistas_variant as Dictionary).get(clave_registro, false))


func registrar_variante_dialogo_mostrada(
	personaje_id: String,
	clave_variante: String,
	ciclo: String = "unica"
) -> bool:
	var id := personaje_id.strip_edges()
	var clave := clave_variante.strip_edges()
	if id.is_empty() or clave.is_empty():
		return false
	var relacion := obtener_relacion(id)
	if relacion.is_empty():
		return false
	var vistas_variant: Variant = relacion.get("_variantes_dialogo_vistas", {})
	var vistas: Dictionary = vistas_variant.duplicate(true) if vistas_variant is Dictionary else {}
	var clave_registro := "%s::%s" % [clave, ciclo.strip_edges()]
	if bool(vistas.get(clave_registro, false)):
		return false
	vistas[clave_registro] = true
	# Mantiene acotado el estado auxiliar incluso si se añaden muchas variantes.
	while vistas.size() > 64:
		var claves := vistas.keys()
		if claves.is_empty():
			break
		vistas.erase(claves[0])
	relacion["_variantes_dialogo_vistas"] = vistas
	var relaciones := _obtener_relaciones_guardadas()
	relaciones[id] = relacion.duplicate(true)
	_guardar_relaciones(relaciones)
	return true


## Relaciones entre habitantes. Se guardan aparte de la relación jugador-NPC.
## Resume patrones de comportamiento persistentes hacia un personaje.
## Sólo cuenta eventos sociales registrados y evita deducir intenciones.
func obtener_tendencias_sociales(personaje_id: String) -> Dictionary:
	var relacion := obtener_relacion(personaje_id)
	var tendencias_guardadas: Variant = relacion.get("_tendencias_sociales", {})
	if tendencias_guardadas is Dictionary and not (tendencias_guardadas as Dictionary).is_empty():
		return (tendencias_guardadas as Dictionary).duplicate(true)
	var resultado := {
		"promesas_cumplidas": 0,
		"promesas_rotas": 0,
		"ayudas": 0,
		"apoyos": 0,
		"conocimientos_compartidos": 0,
		"mentiras": 0,
		"traiciones": 0,
		"faltas_respeto": 0
	}
	for recuerdo_variant in obtener_recuerdos(personaje_id):
		if not recuerdo_variant is Dictionary:
			continue
		var recuerdo := recuerdo_variant as Dictionary
		if str(recuerdo.get("tipo", "")) != "evento_social":
			continue
		var evento := str(recuerdo.get("evento", ""))
		match evento:
			"promesa_cumplida":
				resultado["promesas_cumplidas"] = int(resultado["promesas_cumplidas"]) + 1
			"promesa_rota":
				resultado["promesas_rotas"] = int(resultado["promesas_rotas"]) + 1
			"ayudar":
				resultado["ayudas"] = int(resultado["ayudas"]) + 1
			"apoyar":
				resultado["apoyos"] = int(resultado["apoyos"]) + 1
			"compartir_conocimiento":
				resultado["conocimientos_compartidos"] = int(resultado["conocimientos_compartidos"]) + 1
			"mentir":
				resultado["mentiras"] = int(resultado["mentiras"]) + 1
			"traicionar":
				resultado["traiciones"] = int(resultado["traiciones"]) + 1
			"faltar_respeto":
				resultado["faltas_respeto"] = int(resultado["faltas_respeto"]) + 1
	return resultado


func obtener_relacion_entre_npc(personaje_a: String, personaje_b: String) -> Dictionary:
	var clave := _clave_pareja_npc(personaje_a, personaje_b)
	if clave.is_empty():
		return {}
	var datos := _obtener_datos_conversaciones_npc()
	var relaciones_variant: Variant = datos.get("_relaciones_npc", {})
	var relaciones: Dictionary = relaciones_variant if relaciones_variant is Dictionary else {}
	var relacion_variant: Variant = relaciones.get(clave, {})
	var resultado := {
		"amistad": 0.0,
		"confianza": 0.0,
		"respeto": 0.0,
		"afecto": 0.0,
		"tension": 0.0,
		"colaboracion": 0.0,
		"interacciones": 0,
		"historial": []
	}
	if relacion_variant is Dictionary:
		resultado.merge((relacion_variant as Dictionary).duplicate(true), true)
	return resultado


func registrar_interaccion_entre_npc(
	personaje_a: String,
	personaje_b: String,
	cambios: Dictionary = {},
	recuerdo: Dictionary = {}
) -> Dictionary:
	var clave := _clave_pareja_npc(personaje_a, personaje_b)
	if clave.is_empty():
		return {}
	var relacion := obtener_relacion_entre_npc(personaje_a, personaje_b)
	for eje in ["amistad", "confianza", "respeto", "afecto", "colaboracion"]:
		if cambios.has(eje):
			relacion[eje] = clampf(
				float(relacion.get(eje, 0.0)) + float(cambios.get(eje, 0.0)),
				-100.0,
				100.0
			)
	if cambios.has("tension"):
		relacion["tension"] = clampf(
			float(relacion.get("tension", 0.0)) + float(cambios.get("tension", 0.0)),
			0.0,
			100.0
		)
	relacion["interacciones"] = maxi(0, int(relacion.get("interacciones", 0))) + 1
	relacion["ultimo_contacto"] = Time.get_datetime_string_from_system(true)
	if not recuerdo.is_empty():
		var historial_variant: Variant = relacion.get("historial", [])
		var historial: Array = historial_variant.duplicate(true) if historial_variant is Array else []
		historial.append(recuerdo.duplicate(true))
		while historial.size() > 12:
			historial.pop_front()
		relacion["historial"] = historial
	var datos := _obtener_datos_conversaciones_npc()
	var relaciones_variant: Variant = datos.get("_relaciones_npc", {})
	var relaciones: Dictionary = relaciones_variant.duplicate(true) if relaciones_variant is Dictionary else {}
	relaciones[clave] = relacion.duplicate(true)
	datos["_relaciones_npc"] = relaciones
	_guardar_datos_conversaciones_npc(datos)
	return relacion.duplicate(true)


## Registra información conocida por un habitante sin convertir un testimonio
## en un hecho confirmado. La procedencia se conserva al actualizar el registro.
func registrar_conocimiento_npc(personaje_id: String, conocimiento: Dictionary) -> bool:
	var id := personaje_id.strip_edges()
	var clave := str(conocimiento.get("clave", "")).strip_edges()
	if id.is_empty() or clave.is_empty():
		return false
	var datos := _obtener_datos_conversaciones_npc()
	var todos_variant: Variant = datos.get("_conocimientos_npc", {})
	var todos: Dictionary = todos_variant.duplicate(true) if todos_variant is Dictionary else {}
	var lista_variant: Variant = todos.get(id, [])
	var lista: Array = lista_variant.duplicate(true) if lista_variant is Array else []
	var indice := -1
	for i in range(lista.size()):
		if lista[i] is Dictionary and str((lista[i] as Dictionary).get("clave", "")) == clave:
			indice = i
			break
	var registro: Dictionary = lista[indice].duplicate(true) if indice >= 0 and lista[indice] is Dictionary else {}
	var primera_vez := str(registro.get("conocido_desde", ""))
	var fuentes_variant: Variant = registro.get("fuentes", [])
	var fuentes: Array = fuentes_variant.duplicate(true) if fuentes_variant is Array else []
	for campo in conocimiento.keys():
		if campo not in ["fuentes", "cadena_transmision", "conocido_desde"]:
			registro[campo] = conocimiento[campo]
	var fuente := str(conocimiento.get("fuente", "")).strip_edges()
	if not fuente.is_empty() and fuente not in fuentes:
		fuentes.append(fuente)
	registro["clave"] = clave
	registro["fuentes"] = fuentes
	registro["conocido_desde"] = primera_vez if not primera_vez.is_empty() else Time.get_datetime_string_from_system(true)
	registro["ultimo_contacto"] = Time.get_datetime_string_from_system(true)
	if conocimiento.has("cadena_transmision"):
		var cadena_variant: Variant = conocimiento.get("cadena_transmision", [])
		if cadena_variant is Array:
			registro["cadena_transmision"] = cadena_variant.duplicate(true)
	if indice >= 0:
		lista[indice] = registro
	else:
		lista.append(registro)
	while lista.size() > 48:
		lista.pop_front()
	todos[id] = lista
	datos["_conocimientos_npc"] = todos
	_guardar_datos_conversaciones_npc(datos)
	return true


func obtener_conocimientos_npc(personaje_id: String) -> Array:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return []
	var datos := _obtener_datos_conversaciones_npc()
	var todos_variant: Variant = datos.get("_conocimientos_npc", {})
	if not todos_variant is Dictionary:
		return []
	var lista_variant: Variant = (todos_variant as Dictionary).get(id, [])
	return (lista_variant as Array).duplicate(true) if lista_variant is Array else []


## La transmisión sólo ocurre cuando una conversación la autoriza explícitamente.
func transmitir_conocimiento_npc(
	personaje_origen: String,
	personaje_destino: String,
	clave_conocimiento: String,
	contexto: Dictionary = {}
) -> bool:
	var origen := personaje_origen.strip_edges()
	var destino := personaje_destino.strip_edges()
	var clave := clave_conocimiento.strip_edges()
	if origen.is_empty() or destino.is_empty() or origen == destino or clave.is_empty():
		return false
	for conocimiento_variant in obtener_conocimientos_npc(origen):
		if not conocimiento_variant is Dictionary:
			continue
		var conocimiento := (conocimiento_variant as Dictionary).duplicate(true)
		if str(conocimiento.get("clave", "")) != clave:
			continue
		var cadena_variant: Variant = conocimiento.get("cadena_transmision", [])
		var cadena: Array = cadena_variant.duplicate(true) if cadena_variant is Array else []
		cadena.append({
			"de": origen,
			"a": destino,
			"momento": Time.get_datetime_string_from_system(true),
			"contexto": contexto.duplicate(true)
		})
		conocimiento["cadena_transmision"] = cadena
		conocimiento["fuente"] = origen
		conocimiento["transmitido_por"] = origen
		return registrar_conocimiento_npc(destino, conocimiento)
	return false


func _clave_pareja_npc(personaje_a: String, personaje_b: String) -> String:
	var a := personaje_a.strip_edges()
	var b := personaje_b.strip_edges()
	if a.is_empty() or b.is_empty() or a == b:
		return ""
	return a + "|" + b if a < b else b + "|" + a


func _obtener_datos_conversaciones_npc() -> Dictionary:
	if _game_state == null or not is_instance_valid(_game_state) or not _game_state.has_method("obtener_conversaciones_npc"):
		return {}
	var datos_variant: Variant = _game_state.call("obtener_conversaciones_npc")
	return datos_variant.duplicate(true) if datos_variant is Dictionary else {}


func _guardar_datos_conversaciones_npc(datos: Dictionary) -> void:
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method("guardar_conversaciones_npc"):
		_game_state.call("guardar_conversaciones_npc", datos)


func _obtener_relaciones_guardadas() -> Dictionary:
	var variant: Variant = _game_state.call("obtener_relaciones_sociales")
	if variant is Dictionary:
		return (variant as Dictionary).duplicate(true)
	return {}


func _guardar_relaciones(relaciones: Dictionary) -> void:
	_game_state.call("guardar_relaciones_sociales", relaciones)


func _obtener_recuerdos() -> Dictionary:
	var variant: Variant = _game_state.call("obtener_recuerdos_sociales")
	if variant is Dictionary:
		return (variant as Dictionary).duplicate(true)
	return {}
