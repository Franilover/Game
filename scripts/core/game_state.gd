extends Node
class_name GameStateService
## GameState — estado de la partida y guardado local.
##
## Las partidas NO se guardan en Supabase.
## Cada partida corresponde a un JSON independiente en user://partidas/.

const SAVE_DIRECTORY := "user://partidas"
const SAVE_VERSION: int = 3
const AUTOSAVE_INTERVAL: float = 10.0
const MAIN_SCENE_PATH: String = "res://scenes/world/main.tscn"

var player_state := PlayerState.new()
var world_state := WorldState.new()
var discovery_state := DiscoveryState.new()

var active_save_id: String = ""
var active_save_name: String = ""

var save_repository := SaveFileRepository.new()

var _autosave_timer: float = 0.0
var _partida_aplicada_en_escena: bool = false
var _guardado_en_curso: bool = false
var _guardado_rapido_conectado: bool = false
var _guardado_rapido_pendiente: bool = false
var _inventory: GarliaInventory = null
var _player: Player = null
var _world_context: WorldContext = null
var _world_atmosphere: WorldAtmosphere = null
var _mission_manager: MissionManagerService = null
var _world_data: WorldDataService = null

signal enciclopedia_actualizada(criatura_id: String)
signal mapa_exploracion_actualizada
signal descubrimientos_mundo_actualizados
signal descubrimiento_mundo(nivel: String, id: String)
signal garumis_vinculados_actualizados
signal garumis_amigos_actualizados


func configurar_dependencias(
	inventory: GarliaInventory = null,
	player: Player = null,
	world_context: WorldContext = null,
	world_atmosphere: WorldAtmosphere = null,
	mission_manager: MissionManagerService = null,
	world_data: WorldDataService = null
) -> void:
	_inventory = inventory
	_player = player
	_world_context = world_context
	_world_atmosphere = world_atmosphere
	_mission_manager = mission_manager
	_world_data = world_data

	if active_save_id.is_empty():
		return

	_guardado_rapido_conectado = false
	_conectar_guardado_rapido()
	call_deferred("_revisar_escena_actual")


func _ready() -> void:
	save_repository.configurar(SAVE_DIRECTORY)
	save_repository.asegurar_directorio()

	get_tree().scene_changed.connect(
		_al_cambiar_escena
	)

	call_deferred("_revisar_escena_actual")



func _process(delta: float) -> void:
	world_state.elapsed_time += delta
	_autosave_timer += delta

	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		guardar_partida()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_WM_GO_BACK_REQUEST
	):
		guardar_partida()


# ============================================================
# PARTIDAS
# ============================================================

func obtener_partidas() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for id in save_repository.listar_ids_partidas():
		var datos := _leer_archivo_partida(id)
		if datos.is_empty():
			continue
		resultado.append(_extraer_metadata_partida(datos))

	resultado.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("actualizado_en", "")) > str(
				b.get("actualizado_en", "")
			)
	)
	return resultado


func crear_partida(
	nombre: String,
	semilla_texto: String = "",
	personaje: Dictionary = {}
) -> String:
	var nombre_limpio := nombre.strip_edges()

	if nombre_limpio.is_empty():
		nombre_limpio = _nombre_partida_por_defecto()

	var ahora := Time.get_datetime_string_from_system(
		true
	)

	var semilla: int
	if semilla_texto.strip_edges().is_empty():
		semilla = _generar_semilla_mundo()
	else:
		if not _texto_es_semilla_valida(semilla_texto):
			print(
				"GameState: semilla inválida → ",
				semilla_texto
			)
			return ""
		semilla = int(semilla_texto.strip_edges())

	var id := "save_" + str(
		Time.get_unix_time_from_system()
	).replace(".", "_") + "_" + str(
		randi_range(1000, 9999)
	)

	var datos := _estado_base_partida(
		id,
		nombre_limpio,
		ahora,
		ahora,
		semilla,
		personaje
	)

	if not _escribir_archivo_partida(id, datos):
		return ""

	print(
		"GameState: partida creada → ",
		nombre_limpio,
		" [",
		id,
		"]"
	)

	return id


func iniciar_partida(id: String) -> bool:
	var datos := _leer_archivo_partida(id)

	if datos.is_empty():
		print(
			"GameState: partida no encontrada → ",
			id
		)
		return false

	var metadata := _extraer_metadata_partida(datos)

	world_state.world_seed_valida = false
	world_state.world_seed = 0

	var mundo_variant: Variant = datos.get(
		"mundo",
		{}
	)

	if mundo_variant is Dictionary:
		var mundo: Dictionary = mundo_variant as Dictionary
		if mundo.has("semilla"):
			world_state.world_seed = int(mundo.get("semilla", 0))
			world_state.world_seed_valida = true

	if not world_state.world_seed_valida:
		# Migración de partidas creadas antes del sistema de semillas.
		# La semilla se crea una sola vez y se persiste inmediatamente.
		world_state.world_seed = _generar_semilla_mundo()
		world_state.world_seed_valida = true
		datos["mundo"] = {
			"semilla": world_state.world_seed,
			"generador_version": 1
		}
		datos["version"] = SAVE_VERSION
		_escribir_archivo_partida(
			id,
			datos
		)

	active_save_id = id
	active_save_name = str(
		metadata.get(
			"nombre",
			"Partida"
		)
	)

	var estado_variant: Variant = datos.get(
		"estado",
		{}
	)

	if estado_variant is Dictionary:
		_aplicar_estado_memoria(
			estado_variant as Dictionary
		)

	world_state.current_scene = MAIN_SCENE_PATH
	_partida_aplicada_en_escena = false
	_autosave_timer = 0.0

	_abrir_escena_principal()

	return true


## Sincroniza únicamente la zona de entrada del mundo global en el save local.
## El estado de personaje, inventario y progreso privado permanece local.
func establecer_zona_mundo_global(id: String, tipo_zona: String) -> bool:
	var tipo := tipo_zona.strip_edges()
	if id.is_empty() or tipo.is_empty():
		return false
	var datos := _leer_archivo_partida(id)
	if datos.is_empty():
		return false
	var estado_variant: Variant = datos.get("estado", {})
	var estado: Dictionary = estado_variant as Dictionary if estado_variant is Dictionary else {}
	var flags_variant: Variant = estado.get("flags", {})
	var flags: Dictionary = (flags_variant as Dictionary).duplicate(true) if flags_variant is Dictionary else {}
	flags["zona_actual_tipo"] = tipo
	estado["flags"] = flags
	datos["estado"] = estado
	datos["actualizado_en"] = _ahora()
	return _escribir_archivo_partida(id, datos)


func eliminar_partida(id: String) -> bool:
	if not save_repository.eliminar_partida(id):
		return false

	if active_save_id == id:
		active_save_id = ""
		active_save_name = ""

	return true


func renombrar_partida(
	id: String,
	nuevo_nombre: String
) -> bool:
	var datos := _leer_archivo_partida(id)

	if datos.is_empty():
		return false

	var nombre_limpio := nuevo_nombre.strip_edges()

	if nombre_limpio.is_empty():
		return false

	datos["nombre"] = nombre_limpio
	datos["actualizado_en"] = _ahora()

	return _escribir_archivo_partida(
		id,
		datos
	)


func obtener_datos_edicion_partida(id: String) -> Dictionary:
	var datos := _leer_archivo_partida(id)
	if datos.is_empty():
		return {}
	var estado: Dictionary = {}
	var estado_variant: Variant = datos.get("estado", {})
	if estado_variant is Dictionary:
		estado = estado_variant as Dictionary
	var flags: Dictionary = {}
	var flags_variant: Variant = estado.get("flags", {})
	if flags_variant is Dictionary:
		flags = flags_variant as Dictionary
	var personaje: Dictionary = {}
	var personaje_variant: Variant = flags.get("personaje", {})
	if personaje_variant is Dictionary:
		personaje = (personaje_variant as Dictionary).duplicate(true)
	var mundo: Dictionary = {}
	var mundo_variant: Variant = datos.get("mundo", {})
	if mundo_variant is Dictionary:
		mundo = mundo_variant as Dictionary
	return {
		"id": id,
		"nombre_mundo": str(datos.get("nombre", "Partida")),
		"semilla": str(mundo.get("semilla", "—")),
		"personaje": personaje
	}


func actualizar_personaje_partida(
	id: String,
	nuevo_nombre_mundo: String,
	nombre_personaje: String,
	genero: String,
	skin_path: String
) -> bool:
	var datos := _leer_archivo_partida(id)
	if datos.is_empty():
		return false
	var mundo_limpio := nuevo_nombre_mundo.strip_edges()
	var personaje_limpio := nombre_personaje.strip_edges()
	if mundo_limpio.is_empty() or personaje_limpio.is_empty():
		return false

	var estado: Dictionary = {}
	var estado_variant: Variant = datos.get("estado", {})
	if estado_variant is Dictionary:
		estado = (estado_variant as Dictionary).duplicate(true)
	var flags: Dictionary = {}
	var flags_variant: Variant = estado.get("flags", {})
	if flags_variant is Dictionary:
		flags = (flags_variant as Dictionary).duplicate(true)
	var personaje: Dictionary = {}
	var personaje_variant: Variant = flags.get("personaje", {})
	if personaje_variant is Dictionary:
		personaje = (personaje_variant as Dictionary).duplicate(true)
	if personaje.is_empty():
		return false

	# La especie y la semilla nunca se toman desde el formulario: se conserva
	# la información existente y solo se modifican los campos permitidos.
	personaje["nombre"] = personaje_limpio
	personaje["genero"] = genero.strip_edges()
	if not skin_path.strip_edges().is_empty():
		personaje["skin"] = skin_path
		personaje["skin_nombre"] = skin_path.get_file().get_basename()
	flags["personaje"] = personaje
	estado["flags"] = flags
	datos["estado"] = estado
	datos["nombre"] = mundo_limpio
	datos["actualizado_en"] = _ahora()
	if not _escribir_archivo_partida(id, datos):
		return false
	if active_save_id == id:
		active_save_name = mundo_limpio
		world_state.flags["personaje"] = personaje.duplicate(true)
	return true


# ============================================================
# GUARDADO
# ============================================================

func guardar_partida() -> bool:
	if _guardado_en_curso:
		return false

	if active_save_id.is_empty():
		return false

	var jugador: Player = _player

	if jugador == null or not is_instance_valid(jugador):
		return false

	# Una muerte todavía no es un estado guardable.
	# Esperamos a que el jugador reaparezca para persistir el estado.
	if jugador.get("is_alive") == false:
		return false

	if get_tree().current_scene == null:
		return false

	_guardado_en_curso = true

	capturar_estado_desde_juego(jugador)
	_sincronizar_garumis_vinculados_desde_escena()

	var datos := _leer_archivo_partida(active_save_id)

	if datos.is_empty():
		_guardado_en_curso = false
		return false

	datos["version"] = SAVE_VERSION
	datos["nombre"] = active_save_name
	datos["actualizado_en"] = _ahora()
	datos["mundo"] = {
		"semilla": world_state.world_seed,
		"generador_version": 1
	}
	datos["estado"] = _serializar_estado()

	var resultado := _escribir_archivo_partida(
		active_save_id,
		datos
	)

	_guardado_en_curso = false

	if resultado:
		print(
			"GameState: partida guardada → ",
			active_save_name
		)

	return resultado


func capturar_estado_desde_juego(jugador: Player) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return

	player_state.health = int(
		jugador.get("health")
	)

	player_state.mana = int(
		jugador.get("mana")
	)

	player_state.position = jugador.global_position
	player_state.position_valida = true
	player_state.tile_valido = false

	# Persistir también la zona activa y el estado del interior, no solo
	# las coordenadas globales del jugador.
	var escena_actual := get_tree().current_scene
	if is_instance_valid(escena_actual):
		var zone_manager := escena_actual.get_node_or_null("World/ZoneManager")
		if is_instance_valid(zone_manager):
			world_state.flags["zona_actual_tipo"] = str(zone_manager.call("obtener_tipo_actual"))
			var zona := zone_manager.call("obtener_zona_actual") as Node
			if is_instance_valid(zona) and zona.has_method("obtener_estado_guardado"):
				world_state.flags["estado_zona_actual"] = zona.call("obtener_estado_guardado").duplicate(true)
			else:
				world_state.flags.erase("estado_zona_actual")

	var world_context: WorldContext = _world_context

	if world_context != null:
		player_state.tile = world_context.get_tile_at(player_state.position)
		player_state.tile_valido = true

	var stamina_variant: Variant = jugador.get(
		"stamina"
	)

	if stamina_variant != null:
		player_state.stamina = float(stamina_variant)

	var facing_variant: Variant = jugador.get(
		"facing"
	)

	if facing_variant is Vector2:
		player_state.facing = facing_variant as Vector2

	var player_flags: Dictionary = jugador.obtener_estado_ium()
	world_state.flags["proceso_ium_equipado"] = player_flags.duplicate(true)


	var atmosphere: WorldAtmosphere = _world_atmosphere
	if atmosphere != null:
		world_state.flags["tiempo_mundo"] = atmosphere.obtener_estado_guardado().duplicate(true)

	var inventario: GarliaInventory = _inventory

	if inventario != null and is_instance_valid(inventario):
		var estado_inventario: Dictionary = {}
		estado_inventario = inventario.serializar_estado_partida().duplicate(true)

		var rol_partida := "explorador"
		var admin_variant: Variant = world_state.flags.get("personaje_admin", {})
		if admin_variant is Dictionary:
			rol_partida = str(
				(admin_variant as Dictionary).get("rol", "explorador")
			).to_lower()

		estado_inventario["rol_partida"] = rol_partida
		world_state.flags["inventario_estado"] = estado_inventario

	_capturar_estado_misiones()


func _capturar_estado_misiones() -> void:
	if _mission_manager == null or not is_instance_valid(_mission_manager):
		return
	world_state.flags["misiones_estado"] = _mission_manager.serializar_estado_partida()


func _aplicar_estado_misiones() -> void:
	if _mission_manager == null or not is_instance_valid(_mission_manager):
		return
	var datos_variant: Variant = world_state.flags.get("misiones_estado", {})
	if datos_variant is Dictionary:
		_mission_manager.cargar_estado_partida((datos_variant as Dictionary).duplicate(true))


func _conectar_guardado_rapido() -> void:
	if _guardado_rapido_conectado or active_save_id.is_empty():
		return

	var inventario: GarliaInventory = _inventory
	if inventario != null and inventario.has_signal("inventory_changed"):
		var inventario_callback := Callable(self, "_al_cambio_guardable")
		if not inventario.inventory_changed.is_connected(inventario_callback):
			inventario.inventory_changed.connect(inventario_callback)

	for nombre in ["mision_aceptada", "progreso_actualizado", "mision_completada"]:
		if _mission_manager == null or not _mission_manager.has_signal(nombre):
			continue
		var callback := Callable(self, "_al_cambio_guardable")
		var senal: Signal = _mission_manager.get(nombre)
		if not senal.is_connected(callback):
			senal.connect(callback)

	if not enciclopedia_actualizada.is_connected(_al_cambio_guardable):
		enciclopedia_actualizada.connect(_al_cambio_guardable)
	if not descubrimientos_mundo_actualizados.is_connected(_al_cambio_guardable):
		descubrimientos_mundo_actualizados.connect(_al_cambio_guardable)

	_guardado_rapido_conectado = true


func _al_cambio_guardable(_a = null, _b = null, _c = null, _d = null) -> void:
	if active_save_id.is_empty():
		return
	if _guardado_rapido_pendiente:
		return
	_guardado_rapido_pendiente = true
	call_deferred("_ejecutar_guardado_rapido")


func _ejecutar_guardado_rapido() -> void:
	_guardado_rapido_pendiente = false
	if active_save_id.is_empty():
		return
	guardar_partida()


func _serializar_estado() -> Dictionary:
	_sincronizar_descubrimientos()
	return {
		"player": player_state.to_dictionary(),
		"elapsed_time": world_state.elapsed_time,
		"flags": world_state.flags.duplicate(true),
		"scene": world_state.current_scene
	}

func _estado_base_partida(
	id: String,
	nombre: String,
	creado_en: String,
	actualizado_en: String,
	semilla: int,
	personaje: Dictionary = {}
) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"id": id,
		"nombre": nombre,
		"creado_en": creado_en,
		"actualizado_en": actualizado_en,
		"mundo_version": _obtener_version_mundo(),
		"mundo": {
			"semilla": semilla,
			"generador_version": 1
		},
		"estado": {
			"player": PlayerState.new().to_dictionary(),
			"elapsed_time": 0.0,
			"flags": {
				"personaje": personaje.duplicate(true)
			} if not personaje.is_empty() else {},
			"scene": "res://scenes/world/main.tscn"
		}
	}


func _aplicar_estado_memoria(
	estado: Dictionary
) -> void:
	var player_variant: Variant = estado.get("player", {})
	if player_variant is Dictionary:
		player_state.from_dictionary(player_variant as Dictionary)
	else:
		player_state = PlayerState.new()

	world_state.elapsed_time = float(
		estado.get("elapsed_time", 0.0)
	)

	var flags_variant: Variant = estado.get("flags", {})
	if flags_variant is Dictionary:
		world_state.flags = (
			flags_variant as Dictionary
		).duplicate(true)
	else:
		world_state.flags = {}

	discovery_state.from_dictionary(world_state.flags)


# ============================================================
# ENCICLOPEDIA
# ============================================================

func registrar_criatura_derrotada(criatura: Node) -> bool:
	if criatura == null or not is_instance_valid(criatura):
		return false

	if not criatura.is_in_group("creatures"):
		return false

	var criatura_id := str(criatura.get("criatura_id"))
	if criatura_id.is_empty() and criatura is Creature:
		criatura_id = (criatura as Creature).get_id()

	if criatura_id.is_empty():
		return false

	var registros_variant: Variant = world_state.flags.get(
		"enciclopedia_criaturas",
		{}
	)

	var registros: Dictionary = {}
	if registros_variant is Dictionary:
		registros = (registros_variant as Dictionary).duplicate(true)

	var derrotas := int(registros.get(criatura_id, 0)) + 1
	registros[criatura_id] = derrotas
	world_state.flags["enciclopedia_criaturas"] = registros

	enciclopedia_actualizada.emit(criatura_id)

	print(
		"GameState: criatura descubierta → ",
		criatura_id,
		" | derrotas = ",
		derrotas
	)

	return true


func registrar_garumi_descubierto(garumi_id: String) -> bool:
	var id := garumi_id.strip_edges()
	if id.is_empty():
		return false
	var registros_variant: Variant = world_state.flags.get("enciclopedia_garumis", {})
	var registros: Dictionary = {}
	if registros_variant is Dictionary:
		registros = (registros_variant as Dictionary).duplicate(true)
	if registros.has(id):
		return false
	registros[id] = true
	world_state.flags["enciclopedia_garumis"] = registros
	enciclopedia_actualizada.emit(id)
	print("GameState: Garumi descubierto → ", id)
	return true


func obtener_garumis_descubiertos() -> Dictionary:
	var registros_variant: Variant = world_state.flags.get("enciclopedia_garumis", {})
	if registros_variant is Dictionary:
		return (registros_variant as Dictionary).duplicate(true)
	return {}


func obtener_criaturas_descubiertas() -> Dictionary:
	var registros_variant: Variant = world_state.flags.get(
		"enciclopedia_criaturas",
		{}
	)

	if registros_variant is Dictionary:
		return (registros_variant as Dictionary).duplicate(true)

	return {}

# ============================================================
# MAPA / EXPLORACION
# ============================================================

func registrar_terreno_explorado(
	tile: Vector2i,
	radio: int = 6
) -> bool:
	var nuevo := false
	var radio_efectivo := maxi(radio, 0)

	for dy in range(-radio_efectivo, radio_efectivo + 1):
		for dx in range(-radio_efectivo, radio_efectivo + 1):
			if (dx * dx + dy * dy) > (
				radio_efectivo * radio_efectivo
			):
				continue

			if discovery_state.explorar(
				tile + Vector2i(dx, dy)
			):
				nuevo = true

	if not nuevo:
		return false

	_sincronizar_descubrimientos()
	mapa_exploracion_actualizada.emit()
	return true


func registrar_descubrimiento_mundo(
	bioma: Dictionary,
	ecosistema: Dictionary,
	habitats: Array,
	criaturas: Array
) -> bool:
	var nuevos: Array[Dictionary] = []

	var bioma_id := str(bioma.get("id", ""))
	if discovery_state.registrar_bioma(bioma_id):
		nuevos.append({"nivel": "bioma", "id": bioma_id})

	var ecosistema_id := str(ecosistema.get("id", ""))
	if discovery_state.registrar_ecosistema(ecosistema_id):
		nuevos.append({"nivel": "ecosistema", "id": ecosistema_id})

	for habitat_variant in habitats:
		if not habitat_variant is Dictionary:
			continue
		var habitat_id := str(
			(habitat_variant as Dictionary).get("id", "")
		)
		if discovery_state.registrar_habitat(habitat_id):
			nuevos.append({"nivel": "habitat", "id": habitat_id})

	for criatura_variant in criaturas:
		if not criatura_variant is Dictionary:
			continue
		var criatura_id := str(
			(criatura_variant as Dictionary).get("id", "")
		)
		if discovery_state.registrar_criatura(criatura_id):
			nuevos.append({"nivel": "criatura", "id": criatura_id})

	if nuevos.is_empty():
		return false

	_sincronizar_descubrimientos()

	for descubrimiento_variant in nuevos:
		if not descubrimiento_variant is Dictionary:
			continue
		var descubrimiento: Dictionary = descubrimiento_variant
		descubrimiento_mundo.emit(
			str(descubrimiento.get("nivel", "")),
			str(descubrimiento.get("id", ""))
		)

	descubrimientos_mundo_actualizados.emit()
	return true


func debe_iniciar_en_reino_torres() -> bool:
	return not bool(world_state.flags.get("reino_torres_visitado", false))


func marcar_reino_torres_visitado() -> void:
	world_state.flags["reino_torres_visitado"] = true
	desbloquear_reino("torres")


## Reinos desbloqueados por esta partida. Torres siempre está disponible.
func obtener_reinos_desbloqueados() -> Dictionary:
	var resultado: Dictionary = {"torres": true}
	var variante: Variant = world_state.flags.get("reinos_desbloqueados", {})
	if variante is Dictionary:
		for clave_variant in (variante as Dictionary).keys():
			var clave := str(clave_variant).strip_edges().to_lower()
			if not clave.is_empty() and bool((variante as Dictionary).get(clave_variant, false)):
				resultado[clave] = true
	return resultado


## Registra el descubrimiento en el guardado local sin modificar el canon de Supabase.
func desbloquear_reino(clave_reino: String) -> bool:
	var clave := clave_reino.strip_edges().to_lower()
	if clave.is_empty():
		return false
	var desbloqueados := obtener_reinos_desbloqueados()
	if bool(desbloqueados.get(clave, false)):
		return false
	desbloqueados[clave] = true
	world_state.flags["reinos_desbloqueados"] = desbloqueados
	print("GameState: reino descubierto → ", clave)
	if not active_save_id.is_empty():
		call_deferred("guardar_partida")
	return true


func obtener_configuracion_personaje() -> Dictionary:
	var personaje_variant: Variant = world_state.flags.get("personaje", {})
	if personaje_variant is Dictionary:
		return (personaje_variant as Dictionary).duplicate(true)
	return {}


func obtener_configuracion_personaje_admin() -> Dictionary:
	var admin_variant: Variant = world_state.flags.get("personaje_admin", {})
	if admin_variant is Dictionary:
		return (admin_variant as Dictionary).duplicate(true)
	return {}


func establecer_configuracion_personaje(personaje: Dictionary) -> void:
	world_state.flags["personaje"] = personaje.duplicate(true)


func establecer_configuracion_personaje_admin(configuracion: Dictionary) -> void:
	world_state.flags["personaje_admin"] = configuracion.duplicate(true)


func obtener_relaciones_sociales() -> Dictionary:
	var relaciones_variant: Variant = world_state.flags.get("relaciones_sociales", {})
	if relaciones_variant is Dictionary:
		return (relaciones_variant as Dictionary).duplicate(true)
	return {}


func guardar_relaciones_sociales(relaciones: Dictionary) -> void:
	world_state.flags["relaciones_sociales"] = relaciones.duplicate(true)


func _sincronizar_garumis_vinculados_desde_escena() -> void:
	var por_id: Dictionary = {}
	for registro in obtener_garumis_vinculados():
		var id_existente := str(registro.get("garumi_instancia_id", "")).strip_edges()
		if not id_existente.is_empty():
			por_id[id_existente] = registro
	for nodo in get_tree().get_nodes_in_group("garumis"):
		if not is_instance_valid(nodo) or not nodo.has_method("obtener_datos_persistencia_vinculo"):
			continue
		var registro_variant: Variant = nodo.call("obtener_datos_persistencia_vinculo")
		if not registro_variant is Dictionary:
			continue
		var registro := registro_variant as Dictionary
		var id_instancia := str(registro.get("garumi_instancia_id", "")).strip_edges()
		if not id_instancia.is_empty():
			por_id[id_instancia] = registro
	var resultado: Array[Dictionary] = []
	for registro_variant in por_id.values():
		if registro_variant is Dictionary:
			resultado.append((registro_variant as Dictionary).duplicate(true))
	world_state.flags["garumis_vinculados"] = resultado


## Registro persistente de Garumis vinculados a esta partida.
## Se almacena dentro de flags para mantener compatibilidad con el formato JSON actual.
func obtener_garumis_amigos() -> Array[Dictionary]:
	var amigos: Array[Dictionary] = []
	var variant: Variant = world_state.flags.get("garumis_amigos", [])
	if not variant is Array:
		return amigos
	for item in variant as Array:
		if item is Dictionary:
			amigos.append((item as Dictionary).duplicate(true))
	return amigos


func es_garumi_amigo(id_instancia: String) -> bool:
	var id_limpio := id_instancia.strip_edges()
	if id_limpio.is_empty():
		return false
	for amigo in obtener_garumis_amigos():
		if str(amigo.get("garumi_instancia_id", "")) == id_limpio:
			return true
	return false


func guardar_garumi_amigo(datos_garumi: Dictionary) -> bool:
	var id_instancia := str(datos_garumi.get("garumi_instancia_id", "")).strip_edges()
	if id_instancia.is_empty():
		return false
	var lista := obtener_garumis_amigos()
	for i in range(lista.size()):
		if str(lista[i].get("garumi_instancia_id", "")) == id_instancia:
			lista[i] = datos_garumi.duplicate(true)
			world_state.flags["garumis_amigos"] = lista
			garumis_amigos_actualizados.emit()
			_al_cambio_guardable()
			return true
	lista.append(datos_garumi.duplicate(true))
	world_state.flags["garumis_amigos"] = lista
	garumis_amigos_actualizados.emit()
	_al_cambio_guardable()
	return true


func eliminar_garumi_amigo(id_instancia: String) -> bool:
	var id_limpio := id_instancia.strip_edges()
	if id_limpio.is_empty():
		return false
	var nueva_lista: Array[Dictionary] = []
	var eliminado := false
	for amigo in obtener_garumis_amigos():
		if str(amigo.get("garumi_instancia_id", "")) == id_limpio:
			eliminado = true
		else:
			nueva_lista.append(amigo)
	if eliminado:
		world_state.flags["garumis_amigos"] = nueva_lista
		garumis_amigos_actualizados.emit()
		_al_cambio_guardable()
	return eliminado


func obtener_garumis_vinculados() -> Array[Dictionary]:
	var guardados: Array[Dictionary] = []
	var variant: Variant = world_state.flags.get("garumis_vinculados", [])
	if not variant is Array:
		return guardados
	for item in variant as Array:
		if item is Dictionary:
			guardados.append((item as Dictionary).duplicate(true))
	return guardados


func contar_garumis_vinculados() -> int:
	return obtener_garumis_vinculados().size()


func puede_vincular_garumi() -> bool:
	return contar_garumis_vinculados() < 3


func guardar_garumi_vinculado(datos_garumi: Dictionary) -> bool:
	var id_instancia := str(datos_garumi.get("garumi_instancia_id", "")).strip_edges()
	if id_instancia.is_empty():
		push_warning("GameState: no se guardó un Garumi vinculado sin garumi_instancia_id.")
		return false
	var lista := obtener_garumis_vinculados()
	for i in range(lista.size()):
		if str(lista[i].get("garumi_instancia_id", "")) == id_instancia:
			lista[i] = datos_garumi.duplicate(true)
			world_state.flags["garumis_vinculados"] = lista
			garumis_vinculados_actualizados.emit()
			_al_cambio_guardable()
			return true
	if lista.size() >= 3:
		push_warning("GameState: límite de 3 Garumis vinculados alcanzado; rompe un vínculo antes de añadir otro.")
		return false
	lista.append(datos_garumi.duplicate(true))
	world_state.flags["garumis_vinculados"] = lista
	garumis_vinculados_actualizados.emit()
	_al_cambio_guardable()
	return true


func eliminar_garumi_vinculado(id_instancia: String) -> bool:
	var id_limpio := id_instancia.strip_edges()
	if id_limpio.is_empty():
		return false
	var lista := obtener_garumis_vinculados()
	var nueva_lista: Array[Dictionary] = []
	var eliminado := false
	for registro in lista:
		if str(registro.get("garumi_instancia_id", "")) == id_limpio:
			eliminado = true
			continue
		nueva_lista.append(registro)
	if eliminado:
		world_state.flags["garumis_vinculados"] = nueva_lista
		garumis_vinculados_actualizados.emit()
		_al_cambio_guardable()
	return eliminado


func obtener_recuerdos_sociales() -> Dictionary:
	var recuerdos_variant: Variant = world_state.flags.get("recuerdos_sociales", {})
	if recuerdos_variant is Dictionary:
		return (recuerdos_variant as Dictionary).duplicate(true)
	return {}


func guardar_recuerdos_sociales(recuerdos: Dictionary) -> void:
	world_state.flags["recuerdos_sociales"] = recuerdos.duplicate(true)


func establecer_proceso_ium_equipado(proceso: Dictionary) -> void:
	world_state.flags["proceso_ium_equipado"] = proceso.duplicate(true)


func obtener_descubrimientos_mundo() -> Dictionary:
	return {
		"biomas": discovery_state.biomes.duplicate(true),
		"ecosistemas": discovery_state.ecosystems.duplicate(true),
		"habitats": discovery_state.habitats.duplicate(true),
		"criaturas": discovery_state.creatures.duplicate(true)
	}


func obtener_terreno_explorado() -> Dictionary:
	return discovery_state.explored_tiles.duplicate(true)


func esta_explorado(tile: Vector2i) -> bool:
	var clave := str(tile.x) + "," + str(tile.y)
	return discovery_state.explored_tiles.has(clave)


func _sincronizar_descubrimientos() -> void:
	var datos := discovery_state.to_dictionary()
	world_state.flags["descubrimientos_mundo"] = {
		"biomas": datos.get("biomas", {}),
		"ecosistemas": datos.get("ecosistemas", {}),
		"habitats": datos.get("habitats", {}),
		"criaturas": datos.get("criaturas", {})
	}
	world_state.flags["mapa_terreno_explorado"] = datos.get(
		"mapa_terreno_explorado",
		{}
	)


# ============================================================
# APLICAR A LA ESCENA
# ============================================================

func _revisar_escena_actual() -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return

	if active_save_id.is_empty() or _partida_aplicada_en_escena:
		return

	# GameState no depende del generador de mundo.
	# Main configura esta dependencia después de que el mundo está listo.
	_aplicar_estado_al_juego()


func _al_mundo_generado_para_aplicar() -> void:
	call_deferred("_revisar_escena_actual")


func _aplicar_estado_al_juego() -> void:
	var jugador: Player = _player

	if jugador == null or not is_instance_valid(jugador):
		return

	if jugador is Node2D and player_state.position_valida:
		(jugador as Node2D).global_position = player_state.position

	# Reconstruir la habitación después de posicionar al jugador.
	var escena_actual := get_tree().current_scene
	if is_instance_valid(escena_actual):
		var zone_manager := escena_actual.get_node_or_null("World/ZoneManager")
		if is_instance_valid(zone_manager):
			var zona := zone_manager.call("obtener_zona_actual") as Node
			var estado_zona: Variant = world_state.flags.get("estado_zona_actual", {})
			if is_instance_valid(zona) and zona.has_method("restaurar_estado_guardado") and estado_zona is Dictionary:
				zona.call("restaurar_estado_guardado", (estado_zona as Dictionary).duplicate(true))

	jugador.set("health", clampi(
		player_state.health,
		0,
		int(jugador.get("max_health"))
	))

	jugador.set("mana", clampi(
		player_state.mana,
		0,
		int(jugador.get("max_mana"))
	))

	jugador.set("is_alive", true)

	if jugador.get("stamina") != null:
		var stamina_guardada := clampf(
			player_state.stamina,
			0.0,
			float(jugador.get("max_stamina"))
		)
		var stamina_controller: Variant = jugador.get("stamina_controller")
		if stamina_controller != null and stamina_controller.has_method("establecer_actual"):
			# El controlador es la fuente de verdad; su señal sincroniza Player.stamina y el HUD.
			stamina_controller.call("establecer_actual", stamina_guardada)
		else:
			jugador.set("stamina", stamina_guardada)

	if jugador.get("facing") is Vector2:
		jugador.set("facing", player_state.facing)

	if jugador.has_signal("health_changed"):
		jugador.health_changed.emit(
			int(jugador.get("health")),
			int(jugador.get("max_health"))
		)

	if jugador.has_signal("mana_changed"):
		jugador.mana_changed.emit(
			int(jugador.get("mana")),
			int(jugador.get("max_mana"))
		)

	if jugador.has_signal("stamina_changed"):
		jugador.stamina_changed.emit(
			float(jugador.get("stamina")),
			float(jugador.get("max_stamina"))
		)

	var inventario: Node = _inventory

	if inventario != null and is_instance_valid(inventario):
		_cargar_inventario_al_juego(
			inventario
		)

	_aplicar_estado_misiones()

	var proceso_variant: Variant = world_state.flags.get(
		"proceso_ium_equipado",
		{}
	)

	if proceso_variant is Dictionary and not (
		proceso_variant as Dictionary
	).is_empty():
		jugador.cargar_estado_ium((proceso_variant as Dictionary).duplicate(true))

	var atmosphere: WorldAtmosphere = _world_atmosphere
	var tiempo_variant: Variant = world_state.flags.get(
		"tiempo_mundo",
		{}
	)

	if atmosphere != null and tiempo_variant is Dictionary:
		atmosphere.establecer_estado_guardado((tiempo_variant as Dictionary).duplicate(true))

	_partida_aplicada_en_escena = true
	_guardado_rapido_conectado = false
	_conectar_guardado_rapido()

	print(
		"GameState: partida cargada → ",
		active_save_name
	)


func _cargar_inventario_al_juego(
	inventario: GarliaInventory
) -> void:
	var estado_variant: Variant = world_state.flags.get(
		"inventario_estado",
		{}
	)

	if not estado_variant is Dictionary:
		return

	var estado := estado_variant as Dictionary

	var rol_guardado := str(
		estado.get("rol_partida", "")
	).to_lower()
	if rol_guardado == "admin" or rol_guardado == "explorador":
		var admin_guardado: Dictionary = {}
		var admin_actual: Variant = world_state.flags.get("personaje_admin", {})
		if admin_actual is Dictionary:
			admin_guardado = (admin_actual as Dictionary).duplicate(true)
		admin_guardado["rol"] = rol_guardado
		if rol_guardado == "explorador":
			admin_guardado["capacidades"] = []
		world_state.flags["personaje_admin"] = admin_guardado

	inventario.cargar_estado_partida(estado.duplicate(true))


func _abrir_escena_principal() -> void:
	# La partida entra al runtime canónico. Reino Torres es una zona
	# inicial del mismo runtime, no una escena paralela.
	print("GameState: entrando al runtime canónico.")
	SceneManager.go_to(MAIN_SCENE_PATH)


func _al_cambiar_escena() -> void:
	_partida_aplicada_en_escena = false
	var escena := get_tree().current_scene
	if escena != null:
		world_state.current_scene = str(escena.scene_file_path)
	call_deferred("_revisar_escena_actual")


# ============================================================
# ARCHIVOS
# ============================================================


func _leer_archivo_partida(id: String) -> Dictionary:
	return save_repository.leer_partida(id)


func _escribir_archivo_partida(
	id: String,
	datos: Dictionary
) -> bool:
	return save_repository.escribir_partida(id, datos)


func _extraer_metadata_partida(
	datos: Dictionary
) -> Dictionary:
	return {
		"id": str(datos.get("id", "")),
		"nombre": str(
			datos.get("nombre", "Partida")
		),
		"creado_en": str(
			datos.get("creado_en", "")
		),
		"actualizado_en": str(
			datos.get("actualizado_en", "")
		),
		"semilla": int(
			datos.get("mundo", {}).get(
				"semilla",
				0
			)
		),
		"mundo_version": int(
			datos.get("mundo_version", 0)
		),
		"play_time": float(
			datos.get("estado", {}).get(
				"elapsed_time",
				0.0
			)
		)
	}




func tiene_semilla_mundo() -> bool:
	return world_state.world_seed_valida


func obtener_semilla_mundo() -> int:
	return world_state.world_seed


func establecer_semilla_mundo(semilla: int) -> void:
	world_state.world_seed = semilla
	world_state.world_seed_valida = true


func _generar_semilla_mundo() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()


func _texto_es_semilla_valida(texto: String) -> bool:
	var limpio := texto.strip_edges()
	if limpio.is_empty():
		return false

	var regex := RegEx.new()
	regex.compile("^-?\\d+$")
	return regex.search(limpio) != null


func _obtener_version_mundo() -> int:
	if _world_data == null:
		return 0
	return int(_world_data.mundo.get("version", 0))


func _ahora() -> String:
	return Time.get_datetime_string_from_system(
		true
	)


func _nombre_partida_por_defecto() -> String:
	var existentes := obtener_partidas()
	var numero := existentes.size() + 1

	while true:
		var candidato := "Partida " + str(numero)
		var encontrado := false

		for partida in existentes:
			if str(partida.get("nombre", "")) == candidato:
				encontrado = true
				break

		if not encontrado:
			return candidato

		numero += 1

	return "Partida " + str(numero)
