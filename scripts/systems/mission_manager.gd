extends Node


signal misiones_cargadas
signal mision_aceptada(mision: Dictionary)
signal progreso_actualizado(mision_id: String, objetivo_id: String, progreso: int, requerido: int)
signal mision_completada(mision: Dictionary)
signal recompensa_disponible(mision: Dictionary, recompensas: Array[Dictionary])


var _misiones: Array[Dictionary] = []
var _misiones_por_id: Dictionary = {}
var _progreso: Dictionary = {}
var _estado: Dictionary = {}


func _ready() -> void:
	if not WorldData.mundo_listo.is_connected(_al_mundo_listo):
		WorldData.mundo_listo.connect(_al_mundo_listo)

	if not WorldData.mundo_actualizado.is_connected(_al_mundo_actualizado):
		WorldData.mundo_actualizado.connect(_al_mundo_actualizado)

	if WorldData.esta_cargado():
		call_deferred("_cargar_desde_world_data")


func _al_mundo_listo() -> void:
	_cargar_desde_world_data()


func _al_mundo_actualizado() -> void:
	# Las definiciones pueden cambiar entre sesiones/versiones.
	# El progreso actual permanece en Godot mientras esta partida siga activa.
	_cargar_desde_world_data()


func _cargar_desde_world_data() -> void:
	_misiones.clear()
	_misiones_por_id.clear()

	for mision_variant in WorldData.obtener_misiones_game():
		if not mision_variant is Dictionary:
			continue

		var mision := (mision_variant as Dictionary).duplicate(true)
		var mision_id := str(mision.get("id", "")).strip_edges()

		if mision_id.is_empty():
			continue

		_misiones.append(mision)
		_misiones_por_id[mision_id] = mision

		if not _estado.has(mision_id):
			_estado[mision_id] = "disponible"

		if bool(mision.get("auto_aceptar", false)):
			aceptar_mision(mision_id)

	misiones_cargadas.emit()

	print(
		"MissionManager: ",
		_misiones.size(),
		" misiones cargadas."
	)


func obtener_misiones() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for mision in _misiones:
		resultado.append(mision.duplicate(true))

	return resultado


func obtener_mision(mision_id: String) -> Dictionary:
	var mision_variant: Variant = _misiones_por_id.get(
		mision_id,
		{}
	)

	if mision_variant is Dictionary:
		return (mision_variant as Dictionary).duplicate(true)

	return {}


func buscar_mision_por_clave(clave: String) -> Dictionary:
	var buscada := clave.strip_edges().to_lower()

	if buscada.is_empty():
		return {}

	for mision in _misiones:
		if str(mision.get("clave", "")).to_lower() == buscada:
			return mision.duplicate(true)

	return {}


func aceptar_mision(identificador: String) -> bool:
	var mision := obtener_mision(identificador)

	if mision.is_empty():
		mision = buscar_mision_por_clave(identificador)

	if mision.is_empty():
		return false

	var mision_id := str(mision.get("id", ""))

	if mision_id.is_empty():
		return false

	var estado := str(_estado.get(mision_id, "disponible"))

	if estado == "activa":
		return true

	if estado == "completada" or estado == "reclamada":
		return false

	_estado[mision_id] = "activa"

	if not _progreso.has(mision_id):
		_progreso[mision_id] = {}

	mision_aceptada.emit(mision)

	print(
		"MissionManager: misión aceptada → ",
		str(mision.get("nombre", mision_id))
	)

	return true


func registrar_dialogo(
	personaje_id: String,
	clave: String = "principal"
) -> void:
	if personaje_id.is_empty():
		return

	_registrar_evento(
		"hablar_personaje",
		personaje_id,
		1,
		clave
	)


func registrar_dialogo_desde_fuente(
	personaje_id: String,
	clave: String,
	fuente: Node
) -> void:
	if personaje_id.is_empty():
		return

	if _registrar_entrega_personaje(personaje_id, fuente):
		return

	registrar_dialogo(personaje_id, clave)


func _registrar_entrega_personaje(
	destino_personaje_id: String,
	destino: Node
) -> bool:
	if destino == null or not is_instance_valid(destino):
		return false

	var jugador := get_tree().get_first_node_in_group("player")
	if jugador == null:
		return false

	for mision in _misiones:
		var mision_id := str(mision.get("id", ""))
		if str(_estado.get(mision_id, "disponible")) != "activa":
			continue

		var objetivos_variant: Variant = mision.get("objetivos", [])
		if not objetivos_variant is Array:
			continue

		for objetivo_variant in objetivos_variant as Array:
			if not objetivo_variant is Dictionary:
				continue

			var objetivo := objetivo_variant as Dictionary
			if str(objetivo.get("tipo", "")).strip_edges().to_lower() != "entregar_personaje":
				continue

			if str(objetivo.get("personaje_id", "")).strip_edges() != destino_personaje_id:
				continue

			var datos_variant: Variant = objetivo.get("datos", {})
			if not datos_variant is Dictionary:
				continue

			var datos := datos_variant as Dictionary
			var personaje_entregado_id := str(datos.get("personaje_entregado_id", "")).strip_edges()
			if personaje_entregado_id.is_empty():
				continue

			for criatura_variant in get_tree().get_nodes_in_group("creatures"):
				if not criatura_variant is Node:
					continue

				var criatura := criatura_variant as Node
				if not is_instance_valid(criatura):
					continue

				if not criatura.has_method("get_personaje_game_id"):
					continue

				if str(criatura.call("get_personaje_game_id")).strip_edges() != personaje_entregado_id:
					continue

				if not criatura.has_method("esta_siguiendo_jugador"):
					continue

				if not bool(criatura.call("esta_siguiendo_jugador")):
					continue

				if criatura.global_position.distance_to(destino.global_position) > 56.0:
					continue

				_registrar_evento(
					"entregar_personaje",
					destino_personaje_id,
					1
				)
				return true

	return false


func registrar_recoleccion(
	item_id: String,
	cantidad: int = 1
) -> void:
	if item_id.is_empty() or cantidad <= 0:
		return

	_registrar_evento(
		"recoger_item",
		item_id,
		cantidad
	)


func registrar_muerte(
	criatura_id: String,
	cantidad: int = 1
) -> void:
	if criatura_id.is_empty() or cantidad <= 0:
		return

	_registrar_evento(
		"derrotar_criatura",
		criatura_id,
		cantidad
	)


func registrar_objetivo(
	tipo: String,
	objetivo_id: String,
	cantidad: int = 1,
	clave: String = ""
) -> void:
	if tipo.strip_edges().is_empty() or objetivo_id.is_empty():
		return

	_registrar_evento(
		tipo.strip_edges().to_lower(),
		objetivo_id,
		cantidad,
		clave
	)


func _registrar_evento(
	tipo: String,
	objetivo_id: String,
	cantidad: int,
	clave: String = ""
) -> void:
	if cantidad <= 0:
		return

	for mision in _misiones:
		var mision_id := str(mision.get("id", ""))

		if str(_estado.get(mision_id, "disponible")) != "activa":
			continue

		var objetivos_variant: Variant = mision.get("objetivos", [])
		if not objetivos_variant is Array:
			continue

		for objetivo_variant in objetivos_variant as Array:
			if not objetivo_variant is Dictionary:
				continue

			var objetivo := objetivo_variant as Dictionary

			if str(objetivo.get("tipo", "")).strip_edges().to_lower() != tipo:
				continue

			if not _objetivo_coincide(objetivo, objetivo_id, clave):
				continue

			var id_objetivo := str(objetivo.get("id", ""))
			if id_objetivo.is_empty():
				continue

			var progreso_mision: Dictionary = _progreso.get(
				mision_id,
				{}
			)

			var actual := int(progreso_mision.get(id_objetivo, 0))
			var requerido := maxi(
				1,
				int(objetivo.get("cantidad_requerida", 1))
			)

			if actual >= requerido:
				continue

			var nuevo := mini(
				requerido,
				actual + cantidad
			)

			progreso_mision[id_objetivo] = nuevo
			_progreso[mision_id] = progreso_mision

			progreso_actualizado.emit(
				mision_id,
				id_objetivo,
				nuevo,
				requerido
			)

			print(
				"MissionManager: ",
				str(mision.get("nombre", mision_id)),
				" → ",
				str(objetivo.get("descripcion", tipo)),
				" [",
				nuevo,
				"/",
				requerido,
				"]"
			)

			if _mision_esta_completa(mision):
				_completar_mision(mision)


func _objetivo_coincide(
	objetivo: Dictionary,
	objetivo_id: String,
	clave: String
) -> bool:
	var personaje_id := str(objetivo.get("personaje_id", "")).strip_edges()
	var item_id := str(objetivo.get("item_id", "")).strip_edges()
	var criatura_id := str(objetivo.get("criatura_id", "")).strip_edges()
	var objetivo_clave := str(objetivo.get("clave", "")).strip_edges()

	if not personaje_id.is_empty():
		return personaje_id == objetivo_id and (
			clave.is_empty()
			or objetivo_clave.is_empty()
			or objetivo_clave == clave
		)

	if not item_id.is_empty():
		return item_id == objetivo_id

	if not criatura_id.is_empty():
		return criatura_id == objetivo_id

	var datos_variant: Variant = objetivo.get("datos", {})
	if datos_variant is Dictionary:
		var datos := datos_variant as Dictionary
		var target_id := str(datos.get("target_id", "")).strip_edges()

		if not target_id.is_empty():
			return target_id == objetivo_id

	return true


func _mision_esta_completa(mision: Dictionary) -> bool:
	var mision_id := str(mision.get("id", ""))
	var objetivos_variant: Variant = mision.get("objetivos", [])

	if not objetivos_variant is Array or (objetivos_variant as Array).is_empty():
		return false

	var progreso_mision: Dictionary = _progreso.get(
		mision_id,
		{}
	)

	for objetivo_variant in objetivos_variant as Array:
		if not objetivo_variant is Dictionary:
			return false

		var objetivo := objetivo_variant as Dictionary
		var objetivo_id := str(objetivo.get("id", ""))
		var requerido := maxi(
			1,
			int(objetivo.get("cantidad_requerida", 1))
		)

		if int(progreso_mision.get(objetivo_id, 0)) < requerido:
			return false

	return true


func _completar_mision(mision: Dictionary) -> void:
	var mision_id := str(mision.get("id", ""))

	if str(_estado.get(mision_id, "")) != "activa":
		return

	_estado[mision_id] = "completada"

	var recompensas_resultado: Array[Dictionary] = []
	var recompensas_variant: Variant = mision.get("recompensas", [])

	if recompensas_variant is Array:
		for recompensa_variant in recompensas_variant as Array:
			if recompensa_variant is Dictionary:
				recompensas_resultado.append(
					(recompensa_variant as Dictionary).duplicate(true)
				)

	mision_completada.emit(mision)
	recompensa_disponible.emit(
		mision,
		recompensas_resultado
	)

	Events.notification_pushed.emit(
		"Misión completada: "
		+ str(mision.get("nombre", "Misión"))
	)

	print(
		"MissionManager: MISIÓN COMPLETADA → ",
		str(mision.get("nombre", mision_id))
	)


func obtener_estado_mision(mision_id: String) -> Dictionary:
	var mision := obtener_mision(mision_id)

	if mision.is_empty():
		return {}

	var progreso_resultado: Array[Dictionary] = []
	var progreso_mision: Dictionary = _progreso.get(
		mision_id,
		{}
	)

	var objetivos_variant: Variant = mision.get("objetivos", [])

	if objetivos_variant is Array:
		for objetivo_variant in objetivos_variant as Array:
			if not objetivo_variant is Dictionary:
				continue

			var objetivo := (
				objetivo_variant as Dictionary
			).duplicate(true)

			var objetivo_id := str(objetivo.get("id", ""))

			objetivo["progreso"] = int(
				progreso_mision.get(objetivo_id, 0)
			)

			objetivo["completado"] = (
				int(objetivo["progreso"])
				>= maxi(
					1,
					int(objetivo.get("cantidad_requerida", 1))
				)
			)

			progreso_resultado.append(objetivo)

	var resultado := mision.duplicate(true)
	resultado["estado"] = str(
		_estado.get(
			mision_id,
			"disponible"
		)
	)
	resultado["objetivos"] = progreso_resultado

	return resultado


func obtener_misiones_activas() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for mision in _misiones:
		var mision_id := str(mision.get("id", ""))

		if str(_estado.get(mision_id, "disponible")) != "activa":
			continue

		resultado.append(
			obtener_estado_mision(mision_id)
		)

	return resultado


func obtener_progreso(
	mision_id: String,
	objetivo_id: String
) -> int:
	var progreso_mision: Dictionary = _progreso.get(
		mision_id,
		{}
	)

	return int(
		progreso_mision.get(
			objetivo_id,
			0
		)
	)


func esta_completada(mision_id: String) -> bool:
	return str(_estado.get(mision_id, "")) == "completada"
