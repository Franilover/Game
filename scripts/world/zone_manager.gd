extends Node2D
## ZoneManager — autoridad de las zonas del runtime.
##
## Cada zona puede ser una escena independiente, pero comparte Player, HUD,
## inventario, input y sistemas del Main. Sólo una zona está cargada a la vez.
## El mundo procedural existe únicamente dentro de MundoAbierto.

signal zona_cambiada(tipo: String, zona: Node)

const MUNDO_ABIERTO_PATH := "res://scenes/world/mundo_abierto.tscn"
const REINO_TORRES_ESCENA_PATH := "res://scenes/kingdom/reino_torres.tscn"

const TIPO_REINO_TORRES := "reino_torres"
const TIPO_MUNDO_ABIERTO := "mundo_abierto"

var tipo_actual: String = ""
var zona_actual: Node = null
var _transicionando: bool = false
var _salida_reino_pendiente: bool = false
var _debug_registrado: bool = false
var _supabase_client: GarliaSupabaseClient = null


func _ready() -> void:
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
		"salida_reino_pendiente": _salida_reino_pendiente
	}

func configurar_dependencias(supabase_client: GarliaSupabaseClient) -> void:
	_supabase_client = supabase_client


func iniciar() -> void:
	if _supabase_client == null:
		push_error("ZoneManager: falta SupabaseClient.")
		return

	if GameState.debe_iniciar_en_reino_torres():
		entrar_reino("torres")
	else:
		entrar_mundo_abierto()


func entrar_reino_torres(regla: Dictionary = {}) -> void:
	entrar_reino("torres", regla)


func entrar_reino(clave_reino: String, regla: Dictionary = {}) -> void:
	var clave := clave_reino.strip_edges().to_lower()
	if clave.is_empty():
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
	if tipo_actual == TIPO_REINO_TORRES:
		GameState.marcar_reino_torres_visitado()
	if tipo_actual == TIPO_REINO_TORRES or tipo_actual.begins_with("reino:"):
		_salida_reino_pendiente = true
	entrar_mundo_abierto()


func consumir_salida_reino_pendiente() -> bool:
	var pendiente := _salida_reino_pendiente
	_salida_reino_pendiente = false
	return pendiente


func obtener_tipo_actual() -> String:
	return tipo_actual


func obtener_zona_actual() -> Node:
	return zona_actual


func obtener_world_generator() -> WorldGenerator:
	if tipo_actual != TIPO_MUNDO_ABIERTO:
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
		# El reloj vive dentro de WorldGenerator. Guardamos el calendario antes
		# de descargar Mundo Abierto para que Torres no reinicie día/hora.
		if tipo_actual == TIPO_MUNDO_ABIERTO:
			var atmosfera: WorldAtmosphere = zona_actual.get_node_or_null("WorldGenerator/WorldAtmosphere") as WorldAtmosphere
			if is_instance_valid(atmosfera):
				GameState.world_state.flags["tiempo_mundo"] = atmosfera.obtener_estado_guardado().duplicate(true)
		zona_actual.queue_free()
		await zona_actual.tree_exited

	zona_actual = packed.instantiate()
	zona_actual.name = "ZonaActiva"
	add_child(zona_actual)

	if tipo != TIPO_MUNDO_ABIERTO and zona_actual.has_signal("salida_solicitada"):
		var callback := Callable(self, "salir_de_reino_actual")
		if not zona_actual.salida_solicitada.is_connected(callback):
			zona_actual.salida_solicitada.connect(callback)

	tipo_actual = tipo
	_transicionando = false

	print("ZoneManager: zona activa → ", tipo_actual)
	zona_cambiada.emit(tipo_actual, zona_actual)
