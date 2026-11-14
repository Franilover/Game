extends Node
class_name MissionManagerService


signal misiones_cargadas
signal mision_aceptada(mision: Dictionary)
signal mision_solicitada(mision: Dictionary)
signal progreso_actualizado(mision_id: String, objetivo_id: String, progreso: int, requerido: int)
signal mision_completada(mision: Dictionary)
signal recompensa_disponible(mision: Dictionary, recompensas: Array[Dictionary])


var _misiones: Array[Dictionary] = []
var _misiones_por_id: Dictionary = {}
var _progreso: Dictionary = {}
var _estado: Dictionary = {}
var _origen_misiones: Dictionary = {}
var _recompensas_reclamadas: Dictionary = {}
var _entity_manager: WorldEntityManager = null
var _world_data: WorldDataService = null


func configurar_dependencias(entity_manager: WorldEntityManager = null, world_data: WorldDataService = null) -> void:
	_entity_manager = entity_manager
	_world_data = world_data

	if _world_data == null:
		push_error("MissionManager: WorldDataService no configurado.")
		return

	if not _world_data.mundo_listo.is_connected(_al_mundo_listo):
		_world_data.mundo_listo.connect(_al_mundo_listo)
	if not _world_data.mundo_actualizado.is_connected(_al_mundo_actualizado):
		_world_data.mundo_actualizado.connect(_al_mundo_actualizado)

	if _world_data.esta_cargado():
		_cargar_desde_world_data()


func _al_mundo_listo() -> void:
	_cargar_desde_world_data()


func _al_mundo_actualizado() -> void:
	# Las definiciones pueden cambiar entre sesiones/versiones.
	# El progreso actual permanece en Godot mientras esta partida siga activa.
	_cargar_desde_world_data()


func _cargar_desde_world_data() -> void:
	_misiones.clear()
	_misiones_por_id.clear()

	for mision_variant in _world_data.obtener_misiones_game():
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


func cumple_requisito_dialogo(requisito: Dictionary) -> bool:
	var mision_clave := str(requisito.get("mision_clave", "")).strip_edges()
	if mision_clave.is_empty():
		return false

	var mision := buscar_mision_por_clave(mision_clave)
	if mision.is_empty():
		return false

	var mision_id := str(mision.get("id", "")).strip_edges()
	if mision_id.is_empty():
		return false

	var estado_requerido := str(requisito.get("estado", "")).strip_edges().to_lower()
	if not estado_requerido.is_empty() and str(_estado.get(mision_id, "disponible")) != estado_requerido:
		return false

	var objetivo_clave := str(requisito.get("objetivo_clave", "")).strip_edges()
	if not objetivo_clave.is_empty():
		var objetivo := _buscar_objetivo_por_clave(mision, objetivo_clave)
		if objetivo.is_empty():
			return false
		var objetivo_id := str(objetivo.get("id", "")).strip_edges()
		var progreso_minimo := maxi(
			1,
			int(requisito.get("progreso_objetivo_min", objetivo.get("cantidad_requerida", 1)))
		)
		if obtener_progreso(mision_id, objetivo_id) < progreso_minimo:
			return false

	return true


func _buscar_objetivo_por_clave(mision: Dictionary, clave: String) -> Dictionary:
	var objetivos_variant: Variant = mision.get("objetivos", [])
	if not objetivos_variant is Array:
		return {}
	for objetivo_variant in objetivos_variant as Array:
		if not objetivo_variant is Dictionary:
			continue
		var objetivo := objetivo_variant as Dictionary
		if str(objetivo.get("clave", "")).strip_edges() == clave:
			return objetivo.duplicate(true)
	return {}


func _objetivo_habilitado_por_dependencias(
	mision_id: String,
	objetivo: Dictionary
) -> bool:
	var datos_variant: Variant = objetivo.get("datos", {})
	if not datos_variant is Dictionary:
		return true
	var datos := datos_variant as Dictionary
	var requisito_clave := str(datos.get("requiere_objetivo_clave", "")).strip_edges()
	if requisito_clave.is_empty():
		return true

	var mision := obtener_mision(mision_id)
	var requisito := _buscar_objetivo_por_clave(mision, requisito_clave)
	if requisito.is_empty():
		return false

	var requisito_id := str(requisito.get("id", "")).strip_edges()
	var cantidad_requerida := maxi(1, int(requisito.get("cantidad_requerida", 1)))
	return obtener_progreso(mision_id, requisito_id) >= cantidad_requerida


func solicitar_aceptacion(identificador: String) -> bool:
	var mision := obtener_mision(identificador)
	if mision.is_empty():
		mision = buscar_mision_por_clave(identificador)
	if mision.is_empty():
		return false

	var mision_id := str(mision.get("id", ""))
	if mision_id.is_empty():
		return false

	if str(_estado.get(mision_id, "disponible")) != "disponible":
		return false

	mision_solicitada.emit(mision)
	return true


func aceptar_mision(identificador: String, personaje_origen_id: String = "") -> bool:
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
		if not personaje_origen_id.strip_edges().is_empty():
			_origen_misiones[mision_id] = personaje_origen_id.strip_edges()
		return true

	if estado == "completada" or estado == "reclamada":
		return false

	_estado[mision_id] = "activa"
	if not personaje_origen_id.strip_edges().is_empty():
		_origen_misiones[mision_id] = personaje_origen_id.strip_edges()

	if not _progreso.has(mision_id):
		_progreso[mision_id] = {}

	var datos_emision := mision.duplicate(true)
	if not personaje_origen_id.strip_edges().is_empty():
		datos_emision["npc_origen_personaje_game_id"] = personaje_origen_id.strip_edges()
	mision_aceptada.emit(datos_emision)

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

	if _entity_manager == null:
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

			for criatura_variant in _entity_manager.obtener_entidades_activas():
				if not criatura_variant is Creature:
					continue

				var criatura := criatura_variant as Creature
				if not is_instance_valid(criatura):
					continue

				if str(criatura.get_personaje_game_id()).strip_edges() != personaje_entregado_id:
					continue

				if not criatura.esta_siguiendo_jugador():
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

			if not _objetivo_habilitado_por_dependencias(mision_id, objetivo):
				continue

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


func serializar_estado_partida() -> Dictionary:
	return {
		"estado": _estado.duplicate(true),
		"origen_misiones": _origen_misiones.duplicate(true),
		"progreso": _progreso.duplicate(true),
		"recompensas_reclamadas": _recompensas_reclamadas.duplicate(true)
	}


func cargar_estado_partida(datos: Dictionary) -> void:
	_estado.clear()
	_origen_misiones.clear()
	_progreso.clear()
	_recompensas_reclamadas.clear()

	var estado_variant: Variant = datos.get("estado", {})
	if estado_variant is Dictionary:
		_estado = (estado_variant as Dictionary).duplicate(true)
	var origenes_variant: Variant = datos.get("origen_misiones", {})
	if origenes_variant is Dictionary:
		_origen_misiones = (origenes_variant as Dictionary).duplicate(true)

	var progreso_variant: Variant = datos.get("progreso", {})
	if progreso_variant is Dictionary:
		_progreso = (progreso_variant as Dictionary).duplicate(true)
	var reclamadas_variant: Variant = datos.get("recompensas_reclamadas", {})
	if reclamadas_variant is Dictionary:
		_recompensas_reclamadas = (reclamadas_variant as Dictionary).duplicate(true)

	# El save puede sobrevivir a cambios del catálogo. Solo se conserva el
	# estado conocido y se reconstruye el progreso contra objetivos actuales.
	for mision in _misiones:
		var mision_id := str(mision.get("id", "")).strip_edges()
		if mision_id.is_empty():
			continue

		var estado_guardado := str(
			_estado.get(mision_id, "disponible")
		).strip_edges().to_lower()
		if estado_guardado not in ["disponible", "activa", "completada", "reclamada"]:
			estado_guardado = "disponible"
		_estado[mision_id] = estado_guardado

		var progreso_guardado_variant: Variant = _progreso.get(mision_id, {})
		var progreso_guardado: Dictionary = (
			progreso_guardado_variant as Dictionary
			if progreso_guardado_variant is Dictionary
			else {}
		)
		var progreso_validado: Dictionary = {}
		var objetivos_variant: Variant = mision.get("objetivos", [])
		if objetivos_variant is Array:
			for objetivo_variant in objetivos_variant as Array:
				if not objetivo_variant is Dictionary:
					continue
				var objetivo := objetivo_variant as Dictionary
				var objetivo_id := str(objetivo.get("id", "")).strip_edges()
				if objetivo_id.is_empty():
					continue
				var requerido := maxi(
					1,
					int(objetivo.get("cantidad_requerida", 1))
				)
				var valor_variant: Variant = progreso_guardado.get(objetivo_id, 0)
				var valor := 0
				if valor_variant is int or valor_variant is float:
					valor = clampi(int(valor_variant), 0, requerido)
				progreso_validado[objetivo_id] = valor
		_progreso[mision_id] = progreso_validado



## Entrega las recompensas de una misión de forma idempotente.
## Las recompensas de objeto deben incluir datos.item_data (definición de runtime)
## o los campos equivalentes dentro de datos. El inventario confirma cada inserción.
func entregar_recompensas(mision_id: String, inventario: GarliaInventory) -> bool:
	if inventario == null or not is_instance_valid(inventario):
		return false
	var estado_actual := str(_estado.get(mision_id, ""))
	if bool(_recompensas_reclamadas.get(mision_id, false)):
		return true
	if estado_actual != "completada":
		return false
	var mision := obtener_mision(mision_id)
	if mision.is_empty():
		return false
	var recompensas_variant: Variant = mision.get("recompensas", [])
	var recompensas: Array = recompensas_variant as Array if recompensas_variant is Array else []
	var inventario_anterior := inventario.serializar_estado_partida()
	var cantidad_entregada := 0
	for recompensa_variant in recompensas:
		if not recompensa_variant is Dictionary:
			inventario.cargar_estado_partida(inventario_anterior)
			return false
		var recompensa := recompensa_variant as Dictionary
		var tipo := str(recompensa.get("tipo", "")).strip_edges().to_lower()
		if tipo != "item":
			inventario.cargar_estado_partida(inventario_anterior)
			return false
		var objeto := _construir_objeto_recompensa(recompensa)
		if objeto.is_empty() or not inventario.agregar_objeto_desde_ui(objeto):
			inventario.cargar_estado_partida(inventario_anterior)
			return false
		cantidad_entregada += 1
	_recompensas_reclamadas[mision_id] = true
	if cantidad_entregada > 0:
		Events.notification_pushed.emit("Recompensas recibidas: " + str(mision.get("nombre", "Misión")))
	return true


## Reintenta entregas que quedaron pendientes cuando el inventario vuelve a tener espacio.
func reintentar_recompensas_pendientes(inventario: GarliaInventory) -> void:
	if inventario == null or not is_instance_valid(inventario):
		return
	for mision in _misiones:
		var mision_id := str(mision.get("id", "")).strip_edges()
		if mision_id.is_empty():
			continue
		if str(_estado.get(mision_id, "")) != "completada":
			continue
		if bool(_recompensas_reclamadas.get(mision_id, false)):
			continue
		entregar_recompensas(mision_id, inventario)


func _construir_objeto_recompensa(recompensa: Dictionary) -> Dictionary:
	var datos_variant: Variant = recompensa.get("datos", {})
	var datos: Dictionary = datos_variant as Dictionary if datos_variant is Dictionary else {}
	var objeto_variant: Variant = datos.get("item_data", datos.get("objeto", {}))
	var objeto: Dictionary = objeto_variant.duplicate(true) if objeto_variant is Dictionary else {}
	if objeto.is_empty():
		var item_id := str(recompensa.get("item_id", datos.get("item_id", ""))).strip_edges()
		var nombre := str(datos.get("nombre", "")).strip_edges()
		if item_id.is_empty() or nombre.is_empty():
			return {}
		objeto = {
			"id": item_id,
			"item_id": item_id,
			"nombre": nombre,
			"descripcion": str(datos.get("descripcion", "")),
			"tipo": str(datos.get("tipo", "recurso")),
			"max_stack": maxi(1, int(datos.get("max_stack", 1))),
			"propiedades_game": (datos.get("propiedades_game", {}) as Dictionary).duplicate(true) if datos.get("propiedades_game", {}) is Dictionary else {}
		}
	var cantidad := maxi(1, int(recompensa.get("cantidad", 1)))
	objeto["cantidad"] = cantidad
	if not objeto.has("id") and objeto.has("item_id"):
		objeto["id"] = objeto["item_id"]
	if not objeto.has("max_stack"):
		objeto["max_stack"] = 1
	return objeto


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
	resultado["npc_origen_personaje_game_id"] = str(
		_origen_misiones.get(
			mision_id,
			mision.get("npc_origen_personaje_game_id", mision.get("personaje_origen_id", ""))
		)
	)

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
