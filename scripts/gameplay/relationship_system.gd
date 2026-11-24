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
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return {}

	var guardada := _obtener_relacion_guardada(id)
	if not guardada.is_empty():
		return guardada

	var personaje: Dictionary = WorldData.obtener_personaje_game_por_id(personaje_id)
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

	_guardar_relacion_guardada(personaje_id, nueva)
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

	_guardar_relacion_guardada(personaje_id, relacion)

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
				and str(recuerdo_existente.get("evento", "")).strip_edges().to_lower() == clave_evento
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
		_guardar_relacion_guardada(id, resultado)
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


## Registra un descubrimiento que puede revelar la historia de cualquier NPC.
## La clave es global para que el hallazgo pueda venir de otro personaje o evento.
func registrar_descubrimiento_social(clave: String, contexto: Dictionary = {}) -> bool:
	var id := clave.strip_edges()
	if id.is_empty() or _game_state == null or not is_instance_valid(_game_state):
		return false
	var flags_variant: Variant = _game_state.world_state.flags.get("descubrimientos_sociales", {})
	var descubrimientos: Dictionary = flags_variant.duplicate(true) if flags_variant is Dictionary else {}
	if descubrimientos.has(id):
		return false
	descubrimientos[id] = {
		"momento": Time.get_datetime_string_from_system(true),
		"contexto": contexto.duplicate(true)
	}
	_game_state.world_state.flags["descubrimientos_sociales"] = descubrimientos
	if _game_state.has_method("guardar_partida"):
		_game_state.call_deferred("guardar_partida")
	return true


func existe_descubrimiento_social(clave: String) -> bool:
	var id := clave.strip_edges()
	if id.is_empty() or _game_state == null or not is_instance_valid(_game_state):
		return false
	var flags_variant: Variant = _game_state.world_state.flags.get("descubrimientos_sociales", {})
	if not flags_variant is Dictionary:
		return false
	return (flags_variant as Dictionary).has(id)


## Las preguntas personales deben declarar hito=1..4 en dialogos_game.
## Las preguntas antiguas sin hito quedan ocultas hasta ser clasificadas.
func esta_hito_pregunta_desbloqueado(personaje_id: String, tema: Dictionary) -> bool:
	var hito := int(tema.get("hito", tema.get("hito_id", 0)))
	if hito < 1 or hito > 4:
		return false
	var relacion := obtener_relacion(personaje_id)
	if relacion.is_empty():
		return false
	var desbloqueados_variant: Variant = relacion.get("_hitos_preguntas_desbloqueados", {})
	var desbloqueados: Dictionary = desbloqueados_variant.duplicate(true) if desbloqueados_variant is Dictionary else {}
	var clave_hito := str(hito)
	if bool(desbloqueados.get(clave_hito, false)):
		return true

	var desbloqueo_variant: Variant = tema.get("desbloqueo", {})
	var desbloqueo: Dictionary = desbloqueo_variant.duplicate(true) if desbloqueo_variant is Dictionary else {}
	var tipo := str(desbloqueo.get("tipo", "")).strip_edges().to_lower()
	var cumple := false

	match hito:
		1:
			var minimo := float(desbloqueo.get("amistad_min", 100.0))
			cumple = float(relacion.get("amistad", 0.0)) >= minimo
		2:
			var descubrimiento := str(desbloqueo.get("descubrimiento", "")).strip_edges()
			cumple = not descubrimiento.is_empty() and existe_descubrimiento_social(descubrimiento)
		3:
			var item_id := str(desbloqueo.get("item_id", "")).strip_edges()
			var recuerdos := obtener_recuerdos(personaje_id)
			if not item_id.is_empty():
				for recuerdo_variant in recuerdos:
					if not recuerdo_variant is Dictionary:
						continue
					var recuerdo := recuerdo_variant as Dictionary
					var tipo_recuerdo := str(recuerdo.get("tipo", "")).strip_edges().to_lower()
					if tipo_recuerdo in ["regalo", "objeto_devuelto", "devolucion"] and str(recuerdo.get("item_id", "")).strip_edges() == item_id:
						cumple = true
						break
		4:
			var requisitos_variant: Variant = desbloqueo.get("requiere_hitos", [1, 2, 3])
			var requisitos: Array = requisitos_variant if requisitos_variant is Array else [1, 2, 3]
			cumple = not requisitos.is_empty()
			for requisito_variant in requisitos:
				var requisito := str(int(requisito_variant))
				if not bool(desbloqueados.get(requisito, false)):
					cumple = false
					break

	if not cumple:
		return false
	desbloqueados[clave_hito] = true
	relacion["_hitos_preguntas_desbloqueados"] = desbloqueados
	_guardar_relacion_guardada(personaje_id, relacion)
	return true


## Permite que una devolución importante use el mismo hito que un regalo especial.
func registrar_devolucion_importante(personaje_id: String, item_id: String, nombre_item: String = "") -> bool:
	if personaje_id.strip_edges().is_empty() or item_id.strip_edges().is_empty():
		return false
	registrar_recuerdo(personaje_id, {
		"tipo": "objeto_devuelto",
		"item_id": item_id.strip_edges(),
		"item_nombre": nombre_item.strip_edges(),
		"importancia": 5.0,
		"momento": Time.get_datetime_string_from_system(true)
	})
	return true


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
	_guardar_relacion_guardada(id, relacion_actualizada)
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

	var lista := _obtener_recuerdos_personaje(personaje_id)
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

	_guardar_recuerdos_personaje(personaje_id, lista)
	recuerdo_registrado.emit(personaje_id, nuevo_recuerdo.duplicate(true))


func obtener_recuerdos(personaje_id: String) -> Array:
	return _obtener_recuerdos_personaje(personaje_id)



## Devuelve el recuerdo social pendiente más importante sin consumirlo.
## Se marca después de que DialogueSystem haya mostrado la primera línea.
func obtener_recuerdo_pendiente_mencionar(personaje_id: String) -> Dictionary:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return {}
	var lista := _obtener_recuerdos_personaje(id)
	if lista.is_empty():
		return {}
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
		_guardar_recuerdos_personaje(id, lista)
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
	var lista := _obtener_recuerdos_personaje(id)
	if lista.is_empty():
		return false
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
	_guardar_recuerdos_personaje(id, lista)
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
	_guardar_relacion_guardada(id, relacion)
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
	var relacion_variant: Variant = {}
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method("obtener_relacion_npc_entre"):
		relacion_variant = _game_state.call("obtener_relacion_npc_entre", clave)
	else:
		var datos := _obtener_datos_conversaciones_npc()
		var relaciones_variant: Variant = datos.get("_relaciones_npc", {})
		var relaciones: Dictionary = relaciones_variant if relaciones_variant is Dictionary else {}
		relacion_variant = relaciones.get(clave, {})
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
	_guardar_relacion_npc(clave, relacion)
	return relacion.duplicate(true)


## Registra información conocida por un habitante sin convertir un testimonio
## en un hecho confirmado. La procedencia se conserva al actualizar el registro.
func registrar_conocimiento_npc(personaje_id: String, conocimiento: Dictionary) -> bool:
	var id := personaje_id.strip_edges()
	var clave := str(conocimiento.get("clave", "")).strip_edges()
	if id.is_empty() or clave.is_empty():
		return false
	var lista := obtener_conocimientos_npc(id)
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
	# Los testimonios y rumores declarados por los diálogos empiezan como
	# sospechas; no se promueven a hechos por el mero hecho de recibirlos.
	var verificacion := str(registro.get("verificacion", "")).strip_edges().to_lower()
	if verificacion in ["testimonio_no_verificado", "rumor_no_verificado"] and not registro.has("evidencias"):
		var tipo_evidencia := "testimonio" if verificacion == "testimonio_no_verificado" else "rumor"
		var fuente_evidencia := str(registro.get("fuente", "")).strip_edges()
		if not fuente_evidencia.is_empty():
			var evidencia_inicial := {
				"fuente_id": fuente_evidencia,
				"tipo": tipo_evidencia,
				"direccion": "apoya",
				"peso": 0.1 if tipo_evidencia == "testimonio" else 0.08,
				"momento": str(registro.get("conocido_desde", ""))
			}
			registro["evidencias"] = [evidencia_inicial]
			var evaluacion_inicial := evaluar_creencia_conocimiento_npc(registro)
			registro["confianza_creencia"] = float(evaluacion_inicial.get("confianza", 0.5))
			registro["estado_epistemico"] = str(evaluacion_inicial.get("estado", "sospecha"))
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
	_guardar_conocimientos_npc(id, lista)
	return true


func obtener_conocimientos_npc(personaje_id: String) -> Array:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return []
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method("obtener_conocimientos_npc"):
		var lista_variant: Variant = _game_state.call("obtener_conocimientos_npc", id)
		return lista_variant if lista_variant is Array else []
	var datos := _obtener_datos_conversaciones_npc()
	var todos_variant: Variant = datos.get("_conocimientos_npc", {})
	if not todos_variant is Dictionary:
		return []
	var lista_fallback: Variant = (todos_variant as Dictionary).get(id, [])
	return (lista_fallback as Array).duplicate(true) if lista_fallback is Array else []


## Registra un acontecimiento comunitario que el habitante presencia directamente.
## La observación sólo se atribuye a quien participa en la rutina del evento.
func registrar_observacion_evento_npc(
	personaje_id: String,
	evento: Dictionary,
	momento: String = ""
) -> bool:
	var id := personaje_id.strip_edges()
	var clave_evento := str(evento.get("clave", "")).strip_edges().to_lower()
	var evento_id := str(evento.get("evento_id", "")).strip_edges()
	if id.is_empty() or clave_evento.is_empty() or evento_id.is_empty():
		return false
	var clave_conocimiento := "evento_comunitario:%s" % evento_id
	var conocimiento_existente := obtener_conocimiento_npc(id, clave_conocimiento)
	if not conocimiento_existente.is_empty():
		var evidencias_variant: Variant = conocimiento_existente.get("evidencias", [])
		if evidencias_variant is Array:
			for evidencia_variant in evidencias_variant:
				if not evidencia_variant is Dictionary:
					continue
				var evidencia_existente := evidencia_variant as Dictionary
				if (
					str(evidencia_existente.get("fuente_id", "")) == "observacion:%s:%s" % [evento_id, id]
					and str(evidencia_existente.get("direccion", "apoya")) == "apoya"
				):
					return false
	var momento_registro := momento if not momento.strip_edges().is_empty() else Time.get_datetime_string_from_system(true)
	var titulo := str(evento.get("nombre", clave_evento.replace("_", " "))).strip_edges()
	var detalle := str(evento.get("aviso", evento.get("detalle", titulo))).strip_edges()
	if not registrar_conocimiento_npc(id, {
		"clave": clave_conocimiento,
		"tema": clave_evento,
		"titulo": titulo,
		"detalle": detalle,
		"tipo": "evento_comunitario",
		"verificacion": "observacion_directa",
		"fuente": evento_id,
		"compartible": true,
		"privacidad": "publico",
		"momento": momento_registro
	}):
		return false
	return registrar_evidencia_conocimiento_npc(id, clave_conocimiento, {
		"fuente_id": "observacion:%s:%s" % [evento_id, id],
		"tipo": "observacion",
		"direccion": "apoya",
		"detalle": detalle,
		"momento": momento_registro
	})


## Registra evidencia para la creencia de un NPC sin convertirla en verdad
## global. Cada personaje mantiene su propia evaluación del mismo hecho.
func registrar_evidencia_conocimiento_npc(
	personaje_id: String,
	clave_conocimiento: String,
	evidencia: Dictionary
) -> bool:
	var id := personaje_id.strip_edges()
	var clave := clave_conocimiento.strip_edges()
	var fuente := str(evidencia.get("fuente_id", evidencia.get("fuente", ""))).strip_edges()
	var tipo := str(evidencia.get("tipo", "testimonio")).strip_edges().to_lower()
	var direccion := str(evidencia.get("direccion", "apoya")).strip_edges().to_lower()
	if id.is_empty() or clave.is_empty() or fuente.is_empty():
		return false
	if direccion not in ["apoya", "contradice"]:
		return false
	var conocimiento := obtener_conocimiento_npc(id, clave)
	if conocimiento.is_empty():
		return false
	var evidencias_variant: Variant = conocimiento.get("evidencias", [])
	var evidencias: Array = evidencias_variant.duplicate(true) if evidencias_variant is Array else []
	# Una misma fuente no aumenta su credibilidad por repetir el mismo relato.
	for existente_variant in evidencias:
		if not existente_variant is Dictionary:
			continue
		var existente := existente_variant as Dictionary
		if (
			str(existente.get("fuente_id", "")) == fuente
			and str(existente.get("direccion", "apoya")) == direccion
		):
			return false
	var pesos := {
		"rumor": 0.08,
		"testimonio": 0.1,
		"observacion": 0.38,
		"prueba": 0.62
	}
	var peso := clampf(float(evidencia.get("peso", pesos.get(tipo, 0.12))), 0.0, 0.75)
	evidencias.append({
		"fuente_id": fuente,
		"tipo": tipo,
		"direccion": direccion,
		"peso": peso,
		"momento": str(evidencia.get("momento", Time.get_datetime_string_from_system(true))),
		"detalle": str(evidencia.get("detalle", ""))
	})
	while evidencias.size() > 24:
		evidencias.pop_front()
	conocimiento["evidencias"] = evidencias
	var evaluacion := evaluar_creencia_conocimiento_npc(conocimiento)
	conocimiento["confianza_creencia"] = float(evaluacion.get("confianza", 0.5))
	conocimiento["estado_epistemico"] = str(evaluacion.get("estado", "sospecha"))
	return registrar_conocimiento_npc(id, conocimiento)


## Calcula la confianza con fuentes independientes. Repetir una fuente no
## añade peso; evidencia contraria reduce la confianza sin borrar el recuerdo.
func evaluar_creencia_conocimiento_npc(conocimiento: Dictionary) -> Dictionary:
	var evidencias_variant: Variant = conocimiento.get("evidencias", [])
	var evidencias: Array = evidencias_variant if evidencias_variant is Array else []
	var apoyo := 0.0
	var contradiccion := 0.0
	var fuentes_apoyo: Dictionary = {}
	var fuentes_contrarias: Dictionary = {}
	for evidencia_variant in evidencias:
		if not evidencia_variant is Dictionary:
			continue
		var evidencia := evidencia_variant as Dictionary
		var fuente := str(evidencia.get("fuente_id", "")).strip_edges()
		if fuente.is_empty():
			continue
		var peso := clampf(float(evidencia.get("peso", 0.0)), 0.0, 0.75)
		if str(evidencia.get("direccion", "apoya")) == "contradice":
			fuentes_contrarias[fuente] = maxf(float(fuentes_contrarias.get(fuente, 0.0)), peso)
		else:
			fuentes_apoyo[fuente] = maxf(float(fuentes_apoyo.get(fuente, 0.0)), peso)
	for fuente in fuentes_apoyo:
		apoyo += float(fuentes_apoyo[fuente])
	for fuente in fuentes_contrarias:
		contradiccion += float(fuentes_contrarias[fuente])
	var confianza := clampf(0.5 + apoyo - contradiccion, 0.0, 1.0)
	var estado := "sospecha"
	if confianza >= 0.82:
		estado = "conocimiento_sostenido"
	elif confianza >= 0.62:
		estado = "creencia_firme"
	elif confianza <= 0.25:
		estado = "creencia_refutada"
	return {
		"confianza": confianza,
		"estado": estado,
		"fuentes_apoyo": fuentes_apoyo.size(),
		"fuentes_contrarias": fuentes_contrarias.size()
	}


func obtener_evaluacion_creencia_npc(personaje_id: String, clave_conocimiento: String) -> Dictionary:
	var conocimiento := obtener_conocimiento_npc(personaje_id, clave_conocimiento)
	if conocimiento.is_empty():
		return {}
	var evaluacion := evaluar_creencia_conocimiento_npc(conocimiento)
	evaluacion["clave"] = clave_conocimiento
	evaluacion["tema"] = str(conocimiento.get("tema", ""))
	return evaluacion


## Registra el tema tratado con una persona concreta, no como un rasgo
## general del NPC. Así recuerda de qué hablar con cada interlocutor.
func registrar_tema_conversacion_npc(
	personaje_id: String,
	con_personaje: String,
	tema: String,
	momento: String = ""
) -> void:
	var id := personaje_id.strip_edges()
	var otro := con_personaje.strip_edges()
	var tema_limpio := tema.strip_edges()
	if id.is_empty() or otro.is_empty() or id == otro or tema_limpio.is_empty():
		return
	var clave := "tema:%s:%s" % [otro.to_lower(), tema_limpio.to_lower()]
	registrar_recuerdo(id, {
		"tipo": "tema_conversacion",
		"clave": clave,
		"con_personaje": otro,
		"tema": tema_limpio,
		"momento": momento if not momento.is_empty() else Time.get_datetime_string_from_system(true),
		"importancia": 1.0
	})


func obtener_ultimo_tema_conversacion_npc(personaje_id: String, con_personaje: String) -> Dictionary:
	var id := personaje_id.strip_edges()
	var otro := con_personaje.strip_edges()
	if id.is_empty() or otro.is_empty():
		return {}
	var recuerdos := obtener_recuerdos(id)
	for indice in range(recuerdos.size() - 1, -1, -1):
		if not recuerdos[indice] is Dictionary:
			continue
		var recuerdo := recuerdos[indice] as Dictionary
		if (
			str(recuerdo.get("tipo", "")) == "tema_conversacion"
			and str(recuerdo.get("con_personaje", "")).to_lower() == otro.to_lower()
		):
			return recuerdo.duplicate(true)
	return {}


## Registra un asunto concreto que un habitante quiere resolver con otra persona.
## Los campos de contexto son datos del juego; este servicio no inventa narración.
func registrar_asunto_pendiente_npc(personaje_id: String, asunto: Dictionary) -> String:
	var id := personaje_id.strip_edges()
	var clave := str(asunto.get("clave", "")).strip_edges()
	if id.is_empty() or clave.is_empty():
		return ""
	var todos := _obtener_lista_conversaciones_npc("_asuntos_pendientes_npc", "obtener_asuntos_pendientes_npc")
	var id_solicitado := str(asunto.get("id", "")).strip_edges()
	for existente_variant in todos:
		if not existente_variant is Dictionary:
			continue
		var existente := existente_variant as Dictionary
		if not id_solicitado.is_empty() and str(existente.get("id", "")) == id_solicitado:
			return id_solicitado
		if (
			str(existente.get("personaje_id", "")) == id
			and str(existente.get("clave", "")) == clave
			and str(existente.get("estado", "pendiente")) == "pendiente"
		):
			return str(existente.get("id", ""))
	var nuevo := asunto.duplicate(true)
	nuevo["id"] = str(nuevo.get("id", "%s:%s:%d" % [id, clave, Time.get_ticks_usec()]))
	nuevo["personaje_id"] = id
	nuevo["estado"] = "pendiente"
	nuevo["creado"] = Time.get_datetime_string_from_system(true)
	todos.append(nuevo)
	while todos.size() > 64:
		todos.pop_front()
	_guardar_lista_conversaciones_npc("_asuntos_pendientes_npc", "guardar_asuntos_pendientes_npc", todos)
	return str(nuevo["id"])


func obtener_asuntos_pendientes_npc(personaje_id: String, con_personaje: String = "") -> Array:
	var id := personaje_id.strip_edges()
	var otro := con_personaje.strip_edges()
	if id.is_empty():
		return []
	var todos_variant: Variant = []
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method("obtener_asuntos_pendientes_npc"):
		todos_variant = _game_state.call("obtener_asuntos_pendientes_npc")
	else:
		var datos := _obtener_datos_conversaciones_npc()
		todos_variant = datos.get("_asuntos_pendientes_npc", [])
	if not todos_variant is Array:
		return []
	var resultado: Array = []
	for asunto_variant in todos_variant:
		if not asunto_variant is Dictionary:
			continue
		var asunto := (asunto_variant as Dictionary).duplicate(true)
		if str(asunto.get("personaje_id", "")) != id or str(asunto.get("estado", "pendiente")) != "pendiente":
			continue
		var relacionado := str(asunto.get("personaje_relacionado", ""))
		if not otro.is_empty() and relacionado != otro:
			continue
		resultado.append(asunto)
	return resultado


func resolver_asunto_pendiente_npc(asunto_id: String, resuelto: bool = true) -> bool:
	var clave := asunto_id.strip_edges()
	if clave.is_empty():
		return false
	var todos := _obtener_lista_conversaciones_npc("_asuntos_pendientes_npc", "obtener_asuntos_pendientes_npc")
	for i in range(todos.size()):
		if not todos[i] is Dictionary:
			continue
		var asunto := (todos[i] as Dictionary).duplicate(true)
		if str(asunto.get("id", "")) != clave or str(asunto.get("estado", "pendiente")) != "pendiente":
			continue
		asunto["estado"] = "resuelto" if resuelto else "aplazado"
		asunto["resuelto"] = Time.get_datetime_string_from_system(true)
		todos[i] = asunto
		_guardar_lista_conversaciones_npc("_asuntos_pendientes_npc", "guardar_asuntos_pendientes_npc", todos)
		return true
	return false


## Una promesa tiene emisor y destinatario explícitos y permanece pendiente
## hasta que se cumple o se rompe; no depende de que ambos NPC estén cargados.
func registrar_promesa_entre_npc(personaje_promitente: String, personaje_destino: String, promesa: Dictionary) -> String:
	var origen := personaje_promitente.strip_edges()
	var destino := personaje_destino.strip_edges()
	var clave := str(promesa.get("clave", promesa.get("descripcion", ""))).strip_edges()
	if origen.is_empty() or destino.is_empty() or origen == destino or clave.is_empty():
		return ""
	var todas := _obtener_lista_conversaciones_npc("_promesas_npc", "obtener_promesas_npc")
	var id_solicitado := str(promesa.get("id", "")).strip_edges()
	for existente_variant in todas:
		if not existente_variant is Dictionary:
			continue
		var existente := existente_variant as Dictionary
		if not id_solicitado.is_empty() and str(existente.get("id", "")) == id_solicitado:
			return id_solicitado
		if (
			str(existente.get("promitente", "")) == origen
			and str(existente.get("destinatario", "")) == destino
			and str(existente.get("clave", "")) == clave
			and str(existente.get("estado", "pendiente")) == "pendiente"
		):
			return str(existente.get("id", ""))
	var nueva := promesa.duplicate(true)
	nueva["id"] = str(nueva.get("id", "promesa:%s:%s:%d" % [origen, destino, Time.get_ticks_usec()]))
	nueva["promitente"] = origen
	nueva["destinatario"] = destino
	nueva["clave"] = clave
	nueva["estado"] = "pendiente"
	nueva["creada"] = Time.get_datetime_string_from_system(true)
	todas.append(nueva)
	while todas.size() > 64:
		todas.pop_front()
	_guardar_lista_conversaciones_npc("_promesas_npc", "guardar_promesas_npc", todas)
	return str(nueva["id"])


func obtener_promesas_pendientes_npc(personaje_id: String, con_personaje: String = "") -> Array:
	var id := personaje_id.strip_edges()
	var otro := con_personaje.strip_edges()
	if id.is_empty():
		return []
	var todas_variant: Variant = []
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method("obtener_promesas_npc"):
		todas_variant = _game_state.call("obtener_promesas_npc")
	else:
		var datos := _obtener_datos_conversaciones_npc()
		todas_variant = datos.get("_promesas_npc", [])
	if not todas_variant is Array:
		return []
	var resultado: Array = []
	for promesa_variant in todas_variant:
		if not promesa_variant is Dictionary:
			continue
		var promesa := (promesa_variant as Dictionary).duplicate(true)
		if str(promesa.get("promitente", "")) != id or str(promesa.get("estado", "pendiente")) != "pendiente":
			continue
		if not otro.is_empty() and str(promesa.get("destinatario", "")) != otro:
			continue
		resultado.append(promesa)
	return resultado


func resolver_promesa_entre_npc(promesa_id: String, cumplida: bool = true) -> bool:
	var clave := promesa_id.strip_edges()
	if clave.is_empty():
		return false
	var todas := _obtener_lista_conversaciones_npc("_promesas_npc", "obtener_promesas_npc")
	for i in range(todas.size()):
		if not todas[i] is Dictionary:
			continue
		var promesa := (todas[i] as Dictionary).duplicate(true)
		if str(promesa.get("id", "")) != clave or str(promesa.get("estado", "pendiente")) != "pendiente":
			continue
		promesa["estado"] = "cumplida" if cumplida else "rota"
		promesa["resuelta"] = Time.get_datetime_string_from_system(true)
		todas[i] = promesa
		_guardar_lista_conversaciones_npc("_promesas_npc", "guardar_promesas_npc", todas)
		var promitente := str(promesa.get("promitente", ""))
		var destinatario := str(promesa.get("destinatario", ""))
		if cumplida:
			registrar_interaccion_entre_npc(promitente, destinatario, {"confianza": 1.5, "amistad": 0.5}, {"tipo": "promesa_cumplida", "promesa_id": clave})
		else:
			registrar_interaccion_entre_npc(promitente, destinatario, {"confianza": -3.0, "amistad": -1.0, "tension": 1.5}, {"tipo": "promesa_rota", "promesa_id": clave})
		var evento := "promesa_cumplida" if cumplida else "promesa_rota"
		var importancia := 3.0 if cumplida else 4.0
		registrar_recuerdo(promitente, {
			"tipo": "evento_social",
			"evento": evento,
			"evento_id": clave,
			"con_personaje": destinatario,
			"importancia": importancia,
			"momento": Time.get_datetime_string_from_system(true)
		})
		registrar_recuerdo(destinatario, {
			"tipo": "evento_social",
			"evento": evento,
			"evento_id": clave,
			"con_personaje": promitente,
			"importancia": importancia,
			"momento": Time.get_datetime_string_from_system(true)
		})
		return true
	return false


func obtener_conocimiento_npc(personaje_id: String, clave: String) -> Dictionary:
	var buscada := clave.strip_edges()
	if buscada.is_empty():
		return {}
	for conocimiento_variant in obtener_conocimientos_npc(personaje_id):
		if conocimiento_variant is Dictionary and str((conocimiento_variant as Dictionary).get("clave", "")) == buscada:
			return (conocimiento_variant as Dictionary).duplicate(true)
	return {}


func conoce_conocimiento_npc(personaje_id: String, clave: String) -> bool:
	return not obtener_conocimiento_npc(personaje_id, clave).is_empty()


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
		if not puede_compartir_conocimiento_npc(origen, destino, conocimiento):
			return false
		var conocimiento_previo := obtener_conocimiento_npc(destino, clave)
		var momento_transmision := Time.get_datetime_string_from_system(true)
		var enlace := {
			"de": origen,
			"a": destino,
			"momento": momento_transmision,
			"contexto": contexto.duplicate(true)
		}
		# Un conocimiento puede llegar por varias personas. No se debe borrar
		# la ruta que el receptor ya conocía al recibir una segunda versión.
		var rutas_origen: Array = []
		var rutas_origen_variant: Variant = conocimiento.get("rutas_transmision", [])
		if rutas_origen_variant is Array:
			for ruta_variant in rutas_origen_variant:
				if ruta_variant is Array:
					rutas_origen.append(ruta_variant.duplicate(true))
		if rutas_origen.is_empty():
			var cadena_origen_variant: Variant = conocimiento.get("cadena_transmision", [])
			if cadena_origen_variant is Array and not (cadena_origen_variant as Array).is_empty():
				rutas_origen.append((cadena_origen_variant as Array).duplicate(true))
		if rutas_origen.is_empty():
			rutas_origen.append([])
		var rutas_nuevas: Array = []
		for ruta_variant in rutas_origen:
			if not ruta_variant is Array:
				continue
			var ruta_nueva: Array = (ruta_variant as Array).duplicate(true)
			ruta_nueva.append(enlace.duplicate(true))
			rutas_nuevas.append(ruta_nueva)
		var rutas_destino: Array = []
		var rutas_destino_variant: Variant = conocimiento_previo.get("rutas_transmision", [])
		if rutas_destino_variant is Array:
			for ruta_variant in rutas_destino_variant:
				if ruta_variant is Array:
					rutas_destino.append((ruta_variant as Array).duplicate(true))
		if rutas_destino.is_empty():
			var cadena_destino_variant: Variant = conocimiento_previo.get("cadena_transmision", [])
			if cadena_destino_variant is Array and not (cadena_destino_variant as Array).is_empty():
				rutas_destino.append((cadena_destino_variant as Array).duplicate(true))
		for ruta_nueva in rutas_nuevas:
			var firma_nueva := _firma_ruta_transmision(ruta_nueva)
			var repetida := false
			for ruta_existente in rutas_destino:
				if _firma_ruta_transmision(ruta_existente) == firma_nueva:
					repetida = true
					break
			if not repetida:
				rutas_destino.append(ruta_nueva)
		while rutas_destino.size() > 12:
			rutas_destino.pop_front()
		var cadena: Array = rutas_destino.back().duplicate(true) if not rutas_destino.is_empty() else [enlace.duplicate(true)]
		conocimiento["rutas_transmision"] = rutas_destino
		conocimiento["cadena_transmision"] = cadena
		# El receptor no hereda como propia la observación del emisor:
		# recibe un testimonio atribuible a esa persona.
		var evidencias_previas_variant: Variant = conocimiento_previo.get("evidencias", [])
		var evidencias_previas: Array = evidencias_previas_variant.duplicate(true) if evidencias_previas_variant is Array else []
		conocimiento["cadena_transmision"] = cadena
		conocimiento["fuente"] = origen
		conocimiento["transmitido_por"] = origen
		conocimiento["verificacion"] = "testimonio_no_verificado"
		conocimiento.erase("confianza_creencia")
		conocimiento.erase("estado_epistemico")
		if evidencias_previas.is_empty():
			conocimiento.erase("evidencias")
		else:
			conocimiento["evidencias"] = evidencias_previas
		if not registrar_conocimiento_npc(destino, conocimiento):
			return false
		if evidencias_previas.is_empty():
			return true
		registrar_evidencia_conocimiento_npc(destino, clave, {
			"fuente_id": origen,
			"tipo": "testimonio",
			"direccion": "apoya",
			"detalle": "Información transmitida por %s" % origen
		})
		# La noticia se entregó aunque la evidencia del emisor ya estuviera registrada.
		return true
	return false


func _firma_ruta_transmision(ruta: Array) -> String:
	var firma := ""
	for tramo_variant in ruta:
		if not tramo_variant is Dictionary:
			continue
		var tramo := tramo_variant as Dictionary
		if not firma.is_empty():
			firma += "|"
		firma += "%s>%s" % [
			str(tramo.get("de", "")).strip_edges(),
			str(tramo.get("a", "")).strip_edges()
		]
	return firma


## Los testimonios públicos se pueden repetir. La información privada requiere
## permiso explícito y un vínculo de confianza suficiente; lo confidencial no
## se retransmite automáticamente aunque el receptor lo conozca.
func _conocimiento_compartible_con_confianza(conocimiento: Dictionary, confianza: float) -> bool:
	var tipo := str(conocimiento.get("tipo", "")).strip_edges().to_lower()
	var tipo_publico := tipo in ["noticia", "evento_publico", "conocimiento_compartible", "evento_comunitario"]
	if not bool(conocimiento.get("compartible", tipo_publico)):
		return false
	var privacidad := str(conocimiento.get("privacidad", "publica")).strip_edges().to_lower()
	if privacidad in ["publica", "publico", "rumor_publico"]:
		return true
	if privacidad == "confidencial":
		return false
	if privacidad in ["personal", "reservada", "privada"]:
		return bool(conocimiento.get("permiso_transmision", false)) and confianza >= 30.0
	return false


func puede_compartir_conocimiento_npc(
	personaje_origen: String,
	personaje_destino: String,
	conocimiento: Dictionary
) -> bool:
	var origen := personaje_origen.strip_edges()
	var destino := personaje_destino.strip_edges()
	if origen.is_empty() or destino.is_empty() or origen == destino:
		return false
	var privacidad := str(conocimiento.get("privacidad", "publica")).strip_edges().to_lower()
	var confianza := 0.0
	if (
		privacidad in ["personal", "reservada", "privada"]
		and bool(conocimiento.get("permiso_transmision", false))
	):
		var relacion := obtener_relacion_entre_npc(origen, destino)
		confianza = float(relacion.get("confianza", 0.0))
	return _conocimiento_compartible_con_confianza(conocimiento, confianza)


## Devuelve sólo información que este NPC puede repetir a esa persona.
func obtener_conocimientos_compartibles_npc(personaje_origen: String, personaje_destino: String) -> Array:
	var resultado: Array = []
	for conocimiento_variant in obtener_conocimientos_npc(personaje_origen):
		if not conocimiento_variant is Dictionary:
			continue
		var conocimiento := conocimiento_variant as Dictionary
		if puede_compartir_conocimiento_npc(personaje_origen, personaje_destino, conocimiento):
			resultado.append(conocimiento.duplicate(true))
	return resultado


## Comprueba si hay información nueva que el origen pueda compartir con el destino.
## Obtiene cada inventario de conocimientos una sola vez porque sólo necesita saber si existe.
func tiene_conocimiento_compartible_nuevo_npc(personaje_origen: String, personaje_destino: String) -> bool:
	var origen := personaje_origen.strip_edges()
	var destino := personaje_destino.strip_edges()
	if origen.is_empty() or destino.is_empty() or origen == destino:
		return false
	var conocimientos_origen := obtener_conocimientos_npc(origen)
	var conocimientos_destino := obtener_conocimientos_npc(destino)
	var confianza := 0.0
	var confianza_consultada := false
	var claves_destino: Dictionary = {}
	for conocimiento_variant in conocimientos_destino:
		if not conocimiento_variant is Dictionary:
			continue
		var clave_destino := str((conocimiento_variant as Dictionary).get("clave", ""))
		if not clave_destino.is_empty():
			claves_destino[clave_destino] = true
	for conocimiento_variant in conocimientos_origen:
		if not conocimiento_variant is Dictionary:
			continue
		var conocimiento := conocimiento_variant as Dictionary
		var clave_origen := str(conocimiento.get("clave", "")).strip_edges()
		if clave_origen.is_empty() or bool(claves_destino.get(clave_origen, false)):
			continue
		var privacidad := str(conocimiento.get("privacidad", "publica")).strip_edges().to_lower()
		if (
			privacidad in ["personal", "reservada", "privada"]
			and bool(conocimiento.get("permiso_transmision", false))
			and not confianza_consultada
		):
			var relacion := obtener_relacion_entre_npc(origen, destino)
			confianza = float(relacion.get("confianza", 0.0))
			confianza_consultada = true
		if _conocimiento_compartible_con_confianza(conocimiento, confianza):
			return true
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


func _guardar_relacion_npc(clave: String, relacion: Dictionary) -> void:
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method("guardar_relacion_npc_entre"):
		_game_state.call("guardar_relacion_npc_entre", clave, relacion)
		return
	var datos := _obtener_datos_conversaciones_npc()
	var relaciones_variant: Variant = datos.get("_relaciones_npc", {})
	var relaciones: Dictionary = relaciones_variant if relaciones_variant is Dictionary else {}
	var actualizadas := relaciones.duplicate(true)
	actualizadas[clave] = relacion.duplicate(true)
	datos["_relaciones_npc"] = actualizadas
	_guardar_datos_conversaciones_npc(datos)


func _guardar_conocimientos_npc(personaje_id: String, conocimientos: Array) -> void:
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method("guardar_conocimientos_npc"):
		_game_state.call("guardar_conocimientos_npc", personaje_id, conocimientos)
		return
	var datos := _obtener_datos_conversaciones_npc()
	var todos_variant: Variant = datos.get("_conocimientos_npc", {})
	var todos: Dictionary = todos_variant if todos_variant is Dictionary else {}
	var actualizados := todos.duplicate(true)
	actualizados[personaje_id] = conocimientos.duplicate(true)
	datos["_conocimientos_npc"] = actualizados
	_guardar_datos_conversaciones_npc(datos)


func _obtener_lista_conversaciones_npc(clave: String, metodo: String) -> Array:
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method(metodo):
		var resultado: Variant = _game_state.call(metodo)
		return resultado if resultado is Array else []
	var datos := _obtener_datos_conversaciones_npc()
	var lista_variant: Variant = datos.get(clave, [])
	return (lista_variant as Array).duplicate(true) if lista_variant is Array else []


func _guardar_lista_conversaciones_npc(clave: String, metodo: String, lista: Array) -> void:
	if _game_state != null and is_instance_valid(_game_state) and _game_state.has_method(metodo):
		_game_state.call(metodo, lista)
		return
	var datos := _obtener_datos_conversaciones_npc()
	datos[clave] = lista.duplicate(true)
	_guardar_datos_conversaciones_npc(datos)


func _obtener_relacion_guardada(personaje_id: String) -> Dictionary:
	if _game_state == null or not is_instance_valid(_game_state):
		return {}
	if _game_state.has_method("obtener_relacion_social_jugador_npc"):
		var resultado: Variant = _game_state.call("obtener_relacion_social_jugador_npc", personaje_id)
		return resultado if resultado is Dictionary else {}
	if not _game_state.has_method("obtener_relaciones_sociales"):
		return {}
	var todas_variant: Variant = _game_state.call("obtener_relaciones_sociales")
	if not todas_variant is Dictionary:
		return {}
	var relacion_variant: Variant = (todas_variant as Dictionary).get(personaje_id, {})
	return (relacion_variant as Dictionary).duplicate(true) if relacion_variant is Dictionary else {}


func _guardar_relacion_guardada(personaje_id: String, relacion: Dictionary) -> void:
	if _game_state == null or not is_instance_valid(_game_state):
		return
	if _game_state.has_method("guardar_relacion_social_jugador_npc"):
		_game_state.call("guardar_relacion_social_jugador_npc", personaje_id, relacion)
		return
	if not _game_state.has_method("obtener_relaciones_sociales") or not _game_state.has_method("guardar_relaciones_sociales"):
		return
	var todas_variant: Variant = _game_state.call("obtener_relaciones_sociales")
	var todas: Dictionary = todas_variant if todas_variant is Dictionary else {}
	var actualizadas := todas.duplicate(true)
	actualizadas[personaje_id] = relacion.duplicate(true)
	_game_state.call("guardar_relaciones_sociales", actualizadas)


func _obtener_recuerdos_personaje(personaje_id: String) -> Array:
	if _game_state == null or not is_instance_valid(_game_state):
		return []
	if _game_state.has_method("obtener_recuerdos_sociales_npc"):
		var resultado: Variant = _game_state.call("obtener_recuerdos_sociales_npc", personaje_id)
		return resultado if resultado is Array else []
	if not _game_state.has_method("obtener_recuerdos_sociales"):
		return []
	var todos_variant: Variant = _game_state.call("obtener_recuerdos_sociales")
	if not todos_variant is Dictionary:
		return []
	var lista_variant: Variant = (todos_variant as Dictionary).get(personaje_id, [])
	return (lista_variant as Array).duplicate(true) if lista_variant is Array else []


func _guardar_recuerdos_personaje(personaje_id: String, recuerdos: Array) -> void:
	if _game_state == null or not is_instance_valid(_game_state):
		return
	if _game_state.has_method("guardar_recuerdos_sociales_npc"):
		_game_state.call("guardar_recuerdos_sociales_npc", personaje_id, recuerdos)
		return
	if not _game_state.has_method("obtener_recuerdos_sociales") or not _game_state.has_method("guardar_recuerdos_sociales"):
		return
	var todos_variant: Variant = _game_state.call("obtener_recuerdos_sociales")
	var todos: Dictionary = todos_variant if todos_variant is Dictionary else {}
	var actualizados := todos.duplicate(true)
	actualizados[personaje_id] = recuerdos.duplicate(true)
	_game_state.call("guardar_recuerdos_sociales", actualizados)
