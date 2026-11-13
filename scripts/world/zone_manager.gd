extends Node2D
## ZoneManager — autoridad de las zonas del runtime.
##
## Cada zona puede ser una escena independiente, pero comparte Player, HUD,
## inventario, input y sistemas del Main. Sólo una zona está cargada a la vez.
## El mundo procedural existe únicamente dentro de MundoAbierto.

signal zona_cambiada(tipo: String, zona: Node)

const MUNDO_ABIERTO_PATH := "res://scenes/world/mundo_abierto.tscn"
const EXPEDICION_BOSQUE_PATH := "res://scenes/world/expedicion_bosque.tscn"
const RESERVA_CARMESI_PATH := "res://scenes/world/reserva_carmesi.tscn"
const HOGAR_PATH := "res://scenes/world/hogar.tscn"
const REINO_TORRES_ESCENA_PATH := "res://scenes/kingdom/reino_torres.tscn"

const TIPO_REINO_TORRES := "reino_torres"
const TIPO_MUNDO_ABIERTO := "mundo_abierto"
const TIPO_EXPEDICION_BOSQUE := "expedicion:bosque"
const TIPO_RESERVA_CARMESI := "historia:reserva_carmesi"
const TIPO_HOGAR := "hogar"

var tipo_actual: String = ""
var zona_actual: Node = null
var _transicionando: bool = false
var _salida_reino_pendiente: bool = false
var _debug_registrado: bool = false
var _supabase_client: GarliaSupabaseClient = null


func _ready() -> void:
	add_to_group("zone_manager")
	_registrar_debug()

func _registrar_debug() -> void:
	if _debug_registrado:
		return
	var debug: Node = get_node_or_null("/root/GarliaDebug")
	if debug == null or not debug.has_method("registrar_proveedor"):
		return
	debug.registrar_proveedor(
		"zone_manager",
		"ZoneManager",
		self,
		"Zona activa, transición de escenas y presencia del WorldGenerator."
	)
	_debug_registrado = true

func obtener_diagnostico() -> Dictionary:
	var zona_valida: bool = is_instance_valid(zona_actual)
	var world_generator: Node = null
	if zona_valida:
		world_generator = zona_actual.get_node_or_null("WorldGenerator")
	return {
		"tipo_actual": tipo_actual,
		"zona_activa": zona_valida,
		"zona_path": str(zona_actual.get_path()) if zona_valida else "",
		"zona_nombre": str(zona_actual.name) if zona_valida else "",
		"transicionando": _transicionando,
		"world_generator": is_instance_valid(world_generator),
		"salida_reino_pendiente": _salida_reino_pendiente,
		"expedicion": obtener_estado_expedicion()
	}

func configurar_dependencias(supabase_client: GarliaSupabaseClient) -> void:
	_supabase_client = supabase_client


func iniciar() -> void:
	if _supabase_client == null:
		push_error("ZoneManager: falta SupabaseClient.")
		return

	# Reanudar la última zona guardada. La regla de primera visita solo
	# se usa en partidas antiguas que todavía no tienen zona persistida.
	var zona_guardada := str(GameState.world_state.flags.get("zona_actual_tipo", "")).strip_edges()
	if bool(GameState.world_state.flags.get("historia_iniciar_reserva_carmesi", false)):
		GameState.world_state.flags.erase("historia_iniciar_reserva_carmesi")
		entrar_reserva_carmesi()
	elif zona_guardada == TIPO_RESERVA_CARMESI:
		entrar_reserva_carmesi()
	elif zona_guardada == TIPO_HOGAR:
		if GarliaMultiplayer.es_servidor_dedicado() or GarliaWorldNetwork.es_cliente_en_mundo_global():
			# Una sesión global nunca debe intentar reanudar una parcela local.
			entrar_mundo_abierto()
		else:
			entrar_hogar()
	elif zona_guardada == TIPO_REINO_TORRES:
		entrar_reino("torres")
	elif zona_guardada.begins_with("reino:"):
		entrar_reino(zona_guardada.trim_prefix("reino:"))
	elif zona_guardada == TIPO_MUNDO_ABIERTO:
		entrar_mundo_abierto()
	elif zona_guardada == TIPO_EXPEDICION_BOSQUE:
		entrar_expedicion_bosque()
	elif GameState.debe_iniciar_en_reino_torres():
		entrar_reino("torres")
	else:
		entrar_mundo_abierto()


func entrar_reino_torres(regla: Dictionary = {}) -> void:
	entrar_reino("torres", regla)


func entrar_reino(clave_reino: String, regla: Dictionary = {}) -> void:
	var clave := clave_reino.strip_edges().to_lower()
	if clave.is_empty():
		return

	# Torres es una escena local fija. Su destino nunca debe depender del
	# catálogo remoto: una configuración antigua o incorrecta podía apuntar
	# al Mundo Abierto aunque el jugador hubiera elegido Torres.
	if clave == "torres":
		if esta_en_expedicion():
			salir_expedicion()
			return
		if tipo_actual == TIPO_REINO_TORRES and is_instance_valid(zona_actual):
			return
		print("ZoneManager: viaje a Torres → escena local fija.")
		_cambiar_zona(REINO_TORRES_ESCENA_PATH, TIPO_REINO_TORRES)
		return

	print("ZoneManager: solicitud de viaje → ", clave)
	var regla_canonica := regla
	if regla_canonica.is_empty() and is_instance_valid(_supabase_client):
		regla_canonica = _supabase_client.obtener_reino_game(clave)

	# Torres es una escena fija incluida localmente y el menú la muestra como
	# destino inicial. Si el catálogo remoto todavía está cargando o no responde,
	# no debemos cerrar el menú y dejar al jugador sin viaje.
	if regla_canonica.is_empty() and clave == "torres":
		regla_canonica = {
			"clave": "torres",
			"propiedades": {
				"tipo_zona": "escena_fija",
				"escena": REINO_TORRES_ESCENA_PATH,
				"usa_world_generator": false,
				"generacion_procedural": false,
			},
		}
		push_warning("ZoneManager: catálogo de Torres no disponible; usando escena local de respaldo.")

	if regla_canonica.is_empty():
		if not is_instance_valid(_supabase_client):
			push_error("ZoneManager: falta SupabaseClient para entrar al reino '%s'." % clave)
		else:
			push_warning("ZoneManager: no existe una configuración activa para el reino '%s'." % clave)
		return

	var propiedades_variant: Variant = regla_canonica.get("propiedades", {})
	if not propiedades_variant is Dictionary:
		push_error("ZoneManager: las propiedades del reino '%s' no son un objeto JSON." % clave)
		return
	var propiedades := propiedades_variant as Dictionary
	if str(propiedades.get("tipo_zona", "")) != "escena_fija":
		push_warning("ZoneManager: el reino '%s' todavía no está configurado como escena_fija." % clave)
		return
	if bool(propiedades.get("usa_world_generator", false)) or bool(propiedades.get("generacion_procedural", false)):
		push_warning("ZoneManager: el reino '%s' requiere un WorldGenerator, pero su escena es fija." % clave)
		return

	var escena := str(propiedades.get("escena", "")).strip_edges()
	if escena.is_empty() or not ResourceLoader.exists(escena):
		push_warning("ZoneManager: la escena configurada para el reino '%s' no existe: %s" % [clave, escena])
		return
	var tipo := TIPO_REINO_TORRES if clave == "torres" else "reino:" + clave
	if tipo_actual == TIPO_REINO_TORRES and clave != "torres":
		GameState.marcar_reino_torres_visitado()
	_cambiar_zona(escena, tipo)


## Primera expedición: estado local y retorno a Torres.
## El primer prototipo reutiliza MundoAbierto; P1 añadirá la zona de bosque dedicada.
func iniciar_expedicion(id_expedicion: String = "primera_expedicion") -> bool:
	if _transicionando or not _es_zona_torres():
		push_warning("ZoneManager: se rechazó iniciar la expedición. tipo_actual='%s', zona='%s'." % [tipo_actual, str(zona_actual.name) if is_instance_valid(zona_actual) else "sin zona"])
		return false
	if not _id_expedicion_valido(id_expedicion):
		push_warning("ZoneManager: ID de expedición inválido.")
		return false
	if not ResourceLoader.exists(EXPEDICION_BOSQUE_PATH):
		push_error("ZoneManager: no existe la escena dedicada de la expedición.")
		return false

	var jugador := _obtener_jugador_principal()
	if not is_instance_valid(jugador):
		push_warning("ZoneManager: no se puede iniciar la expedición sin jugador.")
		return false

	var flags: Dictionary = GameState.world_state.flags
	var estado_previo: Variant = flags.get("expedicion_estado", {})
	if estado_previo is Dictionary and bool((estado_previo as Dictionary).get("activa", false)):
		push_warning("ZoneManager: ya existe una expedición activa.")
		return false

	flags["expedicion_estado"] = {
		"id": id_expedicion,
		"activa": true,
		"origen_tipo": TIPO_REINO_TORRES,
		"origen_posicion": {
			"x": _obtener_posicion_retorno_segura(jugador).x,
			"y": _obtener_posicion_retorno_segura(jugador).y
		},
		"retorno_pendiente": false
	}
	GameState.marcar_reino_torres_visitado()
	_salida_reino_pendiente = true
	await _cambiar_zona(EXPEDICION_BOSQUE_PATH, TIPO_EXPEDICION_BOSQUE)
	if tipo_actual != TIPO_EXPEDICION_BOSQUE:
		flags.erase("expedicion_estado")
		_salida_reino_pendiente = false
		return false

	# Es el mismo punto de entrada que Main utiliza al salir de un reino.
	# Colocarlo aquí permite que el guardado inmediato capture coordenadas válidas.
	jugador.global_position = Vector2(560.0, 120.0)
	_guardar_partida_si_disponible()
	return true


func _obtener_posicion_retorno_segura(jugador: Node2D) -> Vector2:
	var posicion := jugador.global_position
	# La entrada queda en el extremo este de Torres. Al regresar, aparecer
	# dentro del Area2D volvería a activar la expedición inmediatamente.
	if posicion.x >= 1000.0 and absf(posicion.y) <= 100.0:
		posicion.x = 900.0
	return posicion


func salir_expedicion() -> bool:
	if _transicionando or tipo_actual != TIPO_EXPEDICION_BOSQUE:
		return false
	var flags: Dictionary = GameState.world_state.flags
	var estado_variant: Variant = flags.get("expedicion_estado", {})
	if not estado_variant is Dictionary:
		return false
	var estado := (estado_variant as Dictionary).duplicate(true)
	if not bool(estado.get("activa", false)):
		return false
	if str(estado.get("origen_tipo", "")) != TIPO_REINO_TORRES:
		push_warning("ZoneManager: el destino de retorno de esta expedición no es compatible.")
		return false
	if not ResourceLoader.exists(REINO_TORRES_ESCENA_PATH):
		push_error("ZoneManager: no existe la escena local de Torres para regresar.")
		return false

	estado["activa"] = false
	estado["retorno_pendiente"] = true
	flags["expedicion_estado"] = estado
	await _cambiar_zona(REINO_TORRES_ESCENA_PATH, TIPO_REINO_TORRES)
	if tipo_actual != TIPO_REINO_TORRES:
		estado["activa"] = true
		estado["retorno_pendiente"] = false
		flags["expedicion_estado"] = estado
		return false

	_guardar_partida_si_disponible()
	return true


## Main consume este dato después de aplicar el spawn normal de la escena fija.
func consumir_retorno_expedicion() -> Dictionary:
	var flags: Dictionary = GameState.world_state.flags
	var estado_variant: Variant = flags.get("expedicion_estado", {})
	if not estado_variant is Dictionary:
		return {}
	var estado := (estado_variant as Dictionary).duplicate(true)
	if not bool(estado.get("retorno_pendiente", false)):
		return {}
	var origen_variant: Variant = estado.get("origen_posicion", {})
	if not origen_variant is Dictionary:
		return {}
	var origen := origen_variant as Dictionary
	var posicion := Vector2(
		float(origen.get("x", 0.0)),
		float(origen.get("y", 0.0))
	)
	estado["retorno_pendiente"] = false
	flags["expedicion_estado"] = estado
	return {"valido": true, "posicion": posicion}


func obtener_estado_expedicion() -> Dictionary:
	var estado_variant: Variant = GameState.world_state.flags.get("expedicion_estado", {})
	if estado_variant is Dictionary:
		return (estado_variant as Dictionary).duplicate(true)
	return {}


func esta_en_expedicion() -> bool:
	var estado := obtener_estado_expedicion()
	return bool(estado.get("activa", false)) and tipo_actual == TIPO_EXPEDICION_BOSQUE


func _obtener_jugador_principal() -> Node2D:
	# El grupo es la referencia estable del jugador durante los cambios de zona.
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(jugador):
		return jugador
	var escena_actual := get_tree().current_scene
	if is_instance_valid(escena_actual):
		return escena_actual.get_node_or_null("Entities/Player") as Node2D
	return null


func _es_zona_torres() -> bool:
	if tipo_actual == TIPO_REINO_TORRES:
		return true
	# La salida física pertenece a la escena fija de Torres. Usar la señal
	# evita que un alias de tipo persistido mande esta salida al Mundo Abierto.
	return is_instance_valid(zona_actual) and zona_actual.has_signal("salida_solicitada")


func _id_expedicion_valido(id_expedicion: String) -> bool:
	var id := id_expedicion.strip_edges()
	if id.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("^[a-z0-9_-]{1,64}$")
	return regex.search(id) != null


func _guardar_partida_si_disponible() -> void:
	if not GameState.active_save_id.is_empty():
		if not GameState.guardar_partida():
			push_warning("ZoneManager: no se pudo guardar el estado después del viaje.")


func entrar_hogar() -> void:
	if _transicionando:
		return
	if GarliaMultiplayer.es_servidor_dedicado() or GarliaWorldNetwork.es_cliente_en_mundo_global():
		push_warning("ZoneManager: Hogar privado no está disponible dentro de una sesión de mundo global.")
		return
	if tipo_actual == TIPO_HOGAR and is_instance_valid(zona_actual):
		return
	_cambiar_zona(HOGAR_PATH, TIPO_HOGAR)


func entrar_mundo_abierto() -> void:
	if tipo_actual == TIPO_REINO_TORRES:
		GameState.marcar_reino_torres_visitado()
	if tipo_actual == TIPO_REINO_TORRES or tipo_actual.begins_with("reino:"):
		_salida_reino_pendiente = true
	_cambiar_zona(MUNDO_ABIERTO_PATH, TIPO_MUNDO_ABIERTO)


func salir_de_reino_torres() -> void:
	salir_de_reino_actual()


func salir_de_reino_actual() -> void:
	if _transicionando:
		return
	if _es_zona_torres():
		# La salida física de Torres siempre conduce a la expedición, nunca al
		# Mundo Abierto genérico. El await permite registrar cualquier fallo.
		print("ZoneManager: salida física de Torres detectada; iniciando expedición. tipo_actual=", tipo_actual)
		var iniciada: bool = await iniciar_expedicion()
		if not iniciada:
			push_error("ZoneManager: no se pudo iniciar la primera expedición desde la salida de Torres.")
		return
	if tipo_actual.begins_with("reino:"):
		_salida_reino_pendiente = true
	entrar_mundo_abierto()


func _al_solicitar_destino_viaje(destino_id: String) -> void:
	match destino_id:
		"torres":
			if tipo_actual != TIPO_REINO_TORRES:
				entrar_reino("torres")
		"mundo_abierto":
			entrar_mundo_abierto()
		"expedicion_bosque":
			if not _primera_expedicion_finalizada():
				var iniciada := await iniciar_expedicion("primera_expedicion")
				if not iniciada:
					push_warning("ZoneManager: no se pudo iniciar la primera expedición.")
		_:
			push_warning("ZoneManager: destino dinámico desconocido '%s'." % destino_id)


func _primera_expedicion_finalizada() -> bool:
	var flags: Dictionary = GameState.world_state.flags
	var ruta_variant: Variant = flags.get("expedicion_ruta", {})
	if not ruta_variant is Dictionary or not bool((ruta_variant as Dictionary).get("completada", false)):
		return false
	var coleccionables_variant: Variant = flags.get("expedicion_coleccionables", {})
	if not coleccionables_variant is Dictionary:
		return false
	var coleccionables := coleccionables_variant as Dictionary
	var requeridos_variant: Variant = coleccionables.get("requeridos", [])
	var recogidos_variant: Variant = coleccionables.get("recogidos", [])
	if not requeridos_variant is Array or not recogidos_variant is Array:
		return false
	var requeridos := requeridos_variant as Array
	var recogidos := recogidos_variant as Array
	if requeridos.is_empty():
		return false
	for id_variant in requeridos:
		if not recogidos.has(id_variant):
			return false
	return true


func registrar_coleccionable_requerido_expedicion(coleccionable_id: String) -> void:
	_registrar_estado_coleccionable_expedicion(coleccionable_id, false)


func registrar_coleccionable_recogido_expedicion(coleccionable_id: String) -> void:
	_registrar_estado_coleccionable_expedicion(coleccionable_id, true)


func _registrar_estado_coleccionable_expedicion(coleccionable_id: String, recogido: bool) -> void:
	var identificador := coleccionable_id.strip_edges()
	if identificador.is_empty():
		return
	var flags: Dictionary = GameState.world_state.flags
	var estado_variant: Variant = flags.get("expedicion_coleccionables", {})
	var estado: Dictionary = (estado_variant as Dictionary).duplicate(true) if estado_variant is Dictionary else {}
	var requeridos_variant: Variant = estado.get("requeridos", [])
	var recogidos_variant: Variant = estado.get("recogidos", [])
	var requeridos: Array = requeridos_variant.duplicate() if requeridos_variant is Array else []
	var recogidos: Array = recogidos_variant.duplicate() if recogidos_variant is Array else []
	if not requeridos.has(identificador):
		requeridos.append(identificador)
	if recogido and not recogidos.has(identificador):
		recogidos.append(identificador)
	estado["requeridos"] = requeridos
	estado["recogidos"] = recogidos
	flags["expedicion_coleccionables"] = estado
	_guardar_partida_si_disponible()


func consumir_salida_reino_pendiente() -> bool:
	var pendiente := _salida_reino_pendiente
	_salida_reino_pendiente = false
	return pendiente


func obtener_tipo_actual() -> String:
	return tipo_actual


func obtener_zona_actual() -> Node:
	return zona_actual


func entrar_expedicion_bosque() -> void:
	_cambiar_zona(EXPEDICION_BOSQUE_PATH, TIPO_EXPEDICION_BOSQUE)


func entrar_reserva_carmesi() -> void:
	_cambiar_zona(RESERVA_CARMESI_PATH, TIPO_RESERVA_CARMESI)


func obtener_world_generator() -> WorldGenerator:
	if tipo_actual != TIPO_MUNDO_ABIERTO and tipo_actual != TIPO_EXPEDICION_BOSQUE:
		return null
	if zona_actual == null or not is_instance_valid(zona_actual):
		return null
	return zona_actual.get_node_or_null("WorldGenerator") as WorldGenerator


func _cambiar_zona(path: String, tipo: String) -> void:
	if _transicionando:
		return
	if tipo_actual == tipo and is_instance_valid(zona_actual):
		return

	_transicionando = true
	# Validar y cargar la escena de destino antes de retirar la zona actual.
	# Si el recurso falta, el jugador no queda atrapado en una escena vacía.
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("ZoneManager: no se pudo cargar la zona '%s'." % path)
		_transicionando = false
		return

	if is_instance_valid(zona_actual):
		if tipo_actual == TIPO_HOGAR and zona_actual.has_method("obtener_estado_guardado"):
			var estado_hogar: Dictionary = zona_actual.call("obtener_estado_guardado")
			var jugador_hogar := _obtener_jugador_principal()
			if is_instance_valid(jugador_hogar):
				estado_hogar["jugador"] = {"x": jugador_hogar.global_position.x, "y": jugador_hogar.global_position.y}
			GameState.world_state.flags["hogar_estado"] = estado_hogar.duplicate(true)
		# El reloj vive dentro de WorldGenerator. Guardamos el calendario antes
		# de descargar Mundo Abierto para que Torres no reinicie día/hora.
		if tipo_actual == TIPO_MUNDO_ABIERTO or tipo_actual == TIPO_EXPEDICION_BOSQUE:
			var atmosfera: WorldAtmosphere = zona_actual.get_node_or_null("WorldGenerator/WorldAtmosphere") as WorldAtmosphere
			if is_instance_valid(atmosfera):
				GameState.world_state.flags["tiempo_mundo"] = atmosfera.obtener_estado_guardado().duplicate(true)
		zona_actual.queue_free()
		await zona_actual.tree_exited

	zona_actual = packed.instantiate()
	zona_actual.name = "ZonaActiva"
	if tipo == TIPO_HOGAR and zona_actual.has_method("cargar_estado_guardado"):
		var estado_hogar_variant: Variant = GameState.world_state.flags.get("hogar_estado", {})
		if not estado_hogar_variant is Dictionary or (estado_hogar_variant as Dictionary).is_empty():
			# En partidas guardadas mientras el jugador estaba dentro de Hogar,
			# GameState conserva la última instantánea genérica de la zona.
			if str(GameState.world_state.flags.get("zona_actual_tipo", "")) == TIPO_HOGAR:
				estado_hogar_variant = GameState.world_state.flags.get("estado_zona_actual", {})
		if estado_hogar_variant is Dictionary:
			zona_actual.call("cargar_estado_guardado", (estado_hogar_variant as Dictionary).duplicate(true))
	add_child(zona_actual)

	if tipo != TIPO_MUNDO_ABIERTO and zona_actual.has_signal("salida_solicitada"):
		var callback := Callable(self, "salir_de_reino_actual")
		if not zona_actual.salida_solicitada.is_connected(callback):
			zona_actual.salida_solicitada.connect(callback)
	if tipo == TIPO_REINO_TORRES and zona_actual.has_signal("destino_viaje_solicitado"):
		var callback_viaje := Callable(self, "_al_solicitar_destino_viaje")
		if not zona_actual.destino_viaje_solicitado.is_connected(callback_viaje):
			zona_actual.destino_viaje_solicitado.connect(callback_viaje)

	tipo_actual = tipo
	_transicionando = false

	print("ZoneManager: zona activa → ", tipo_actual)
	zona_cambiada.emit(tipo_actual, zona_actual)
