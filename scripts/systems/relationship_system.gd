extends Node
## Relaciones sociales de la partida.
##
## Supabase define la personalidad y los valores iniciales.
## GameState conserva el estado que cambia durante la partida.

signal relacion_cambiada(personaje_id: String, relacion: Dictionary)
signal recuerdo_registrado(personaje_id: String, recuerdo: Dictionary)

const FLAGS_KEY := "relaciones_sociales"
const RECUERDOS_KEY := "recuerdos_sociales"

var _reglas: Dictionary = {}
var _regalos: Array = []
var _cargado: bool = false


func _ready() -> void:
	add_to_group("relationship_system")
	if not SupabaseClient.personaje_social_cargado.is_connected(_al_reglas_cargadas):
		SupabaseClient.personaje_social_cargado.connect(_al_reglas_cargadas)
	if not SupabaseClient.personaje_regalos_cargados.is_connected(_al_regalos_cargados):
		SupabaseClient.personaje_regalos_cargados.connect(_al_regalos_cargados)
	call_deferred("_cargar_reglas_disponibles")


func _cargar_reglas_disponibles() -> void:
	_regalos = SupabaseClient.obtener_personaje_regalos()
	if _regalos.is_empty():
		SupabaseClient.cargar_personaje_regalos()
	var reglas := SupabaseClient.obtener_personaje_social()
	if not reglas.is_empty():
		_al_reglas_cargadas(reglas)
	else:
		SupabaseClient.cargar_personaje_social()


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


func esta_cargado() -> bool:
	return _cargado


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


func registrar_dialogo(personaje_id: String, clave: String) -> Dictionary:
	if personaje_id.is_empty():
		return {}

	var recuerdo := {
		"tipo": "dialogo",
		"clave": clave,
		"importancia": 1.0,
		"momento": Time.get_datetime_string_from_system(true)
	}
	return modificar_relacion(personaje_id, {"amistad": 0.5}, recuerdo)


func registrar_recuerdo(personaje_id: String, recuerdo: Dictionary) -> void:
	if personaje_id.is_empty():
		return

	var recuerdos := _obtener_recuerdos()
	var lista: Array = recuerdos.get(personaje_id, [])
	lista.append(recuerdo.duplicate(true))

	if lista.size() > 32:
		lista = lista.slice(maxi(lista.size() - 32, 0))

	recuerdos[personaje_id] = lista
	GameState.flags[RECUERDOS_KEY] = recuerdos
	recuerdo_registrado.emit(personaje_id, recuerdo.duplicate(true))


func obtener_recuerdos(personaje_id: String) -> Array:
	var recuerdos := _obtener_recuerdos()
	var lista_variant: Variant = recuerdos.get(personaje_id, [])
	if lista_variant is Array:
		return (lista_variant as Array).duplicate(true)
	return []


func evaluar_regalo(personaje_id: String, item_id: String) -> Dictionary:
	for regalo_variant in _regalos:
		if not regalo_variant is Dictionary:
			continue
		var regalo := regalo_variant as Dictionary
		if str(regalo.get("personaje_game_id", "")) != personaje_id:
			continue
		if str(regalo.get("item_id", "")) != item_id:
			continue
		return regalo.duplicate(true)

	return {
		"reaccion": "neutral",
		"amistad": 0.0,
		"confianza": 0.0,
		"respeto": 0.0,
		"afecto": 0.0
	}


func registrar_regalo(personaje_id: String, item_id: String) -> Dictionary:
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

	for variante_variant in variantes:
		if not variante_variant is Dictionary:
			continue

		var variante := variante_variant as Dictionary
		var requisito_variant: Variant = variante.get("requisito_social", {})
		if requisito_variant is Dictionary:
			if not _cumple_requisito_social(requisito_variant as Dictionary, relacion):
				continue

		var prioridad := int(variante.get("prioridad", 0))
		if mejor.is_empty() or prioridad > mejor_prioridad:
			mejor = variante.duplicate(true)
			mejor_prioridad = prioridad

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
	var variant: Variant = GameState.flags.get(FLAGS_KEY, {})
	if variant is Dictionary:
		return (variant as Dictionary).duplicate(true)
	return {}


func _guardar_relaciones(relaciones: Dictionary) -> void:
	GameState.flags[FLAGS_KEY] = relaciones.duplicate(true)


func _obtener_recuerdos() -> Dictionary:
	var variant: Variant = GameState.flags.get(RECUERDOS_KEY, {})
	if variant is Dictionary:
		return (variant as Dictionary).duplicate(true)
	return {}
