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
	_cargado = not _reglas.is_empty()
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

	var regla_variant: Variant = _reglas.get(personaje_id, {})
	if not regla_variant is Dictionary:
		return {}

	var regla := regla_variant as Dictionary
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
	return modificar_relacion(id, cambios, recuerdo)


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
		"despedida_amable": {"cambios": {"amistad": 0.4, "afecto": 0.5}, "rasgo": "sociabilidad", "importancia": 1.0},
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
	if str(nuevo_recuerdo.get("recuerdo_uid", "")).is_empty():
		nuevo_recuerdo["recuerdo_uid"] = "%s:%d:%d" % [
			personaje_id,
			Time.get_ticks_usec(),
			lista.size()
		]
	lista.append(nuevo_recuerdo)

	if lista.size() > 32:
		lista = lista.slice(maxi(lista.size() - 32, 0))

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
		elif tipo == "evento_social":
			if float(recuerdo.get("importancia", 0.0)) < 3.0:
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
func tomar_regalo_pendiente_mencionar(personaje_id: String) -> Dictionary:
	var recuerdo := obtener_recuerdo_pendiente_mencionar(personaje_id)
	if str(recuerdo.get("tipo", "")) != "regalo":
		return {}
	var indice := int(recuerdo.get("_indice_recuerdo", -1))
	var uid := str(recuerdo.get("recuerdo_uid", ""))
	if not marcar_recuerdo_mencionado(personaje_id, indice, uid):
		return {}
	recuerdo.erase("_indice_recuerdo")
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
	if regla is Dictionary:
		return (regla as Dictionary).duplicate(true)
	return {}


func seleccionar_variante_dialogo(variantes: Array, personaje_id: String) -> Dictionary:
	var relacion := obtener_relacion(personaje_id)
	var mejor: Dictionary = {}
	var mejor_prioridad := -2147483648
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
		if mejor.is_empty() or prioridad > mejor_prioridad:
			mejor = variante.duplicate(true)
			mejor_prioridad = prioridad

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
