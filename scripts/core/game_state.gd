extends Node
## GameState — estado de la partida y guardado local.
##
## Las partidas NO se guardan en Supabase.
## Cada partida corresponde a un JSON independiente en user://partidas/.

const SAVE_DIRECTORY := "user://partidas"
const SAVE_VERSION: int = 3
const AUTOSAVE_INTERVAL: float = 10.0

var player_health: int = 100
var player_mana: int = 100
var player_position: Vector2 = Vector2.ZERO
var player_stamina: float = 100.0
var player_facing: Vector2 = Vector2.DOWN
var player_position_valida: bool = false
var player_tile: Vector2i = Vector2i.ZERO
var player_tile_valido: bool = false

var current_scene: String = ""
var elapsed_time: float = 0.0

var flags: Dictionary = {}

var active_save_id: String = ""
var active_save_name: String = ""

var world_seed: int = 0
var world_seed_valida: bool = false

var save_repository := SaveFileRepository.new()

var _autosave_timer: float = 0.0
var _partida_aplicada_en_escena: bool = false
var _guardado_en_curso: bool = false
var _guardado_rapido_conectado: bool = false
var _guardado_rapido_pendiente: bool = false
var _inventory: Node = null
var _player: Node = null
var _world_generator: Node = null
var _world_atmosphere: Node = null

signal enciclopedia_actualizada(criatura_id: String)
signal mapa_exploracion_actualizada
signal descubrimientos_mundo_actualizados
signal descubrimiento_mundo(nivel: String, id: String)


func configurar_dependencias(
	inventory: Node = null,
	player: Node = null,
	world_generator: Node = null,
	world_atmosphere: Node = null
) -> void:
	_inventory = inventory
	_player = player
	_world_generator = world_generator
	_world_atmosphere = world_atmosphere

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
	elapsed_time += delta
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

	world_seed_valida = false
	world_seed = 0

	var mundo_variant: Variant = datos.get(
		"mundo",
		{}
	)

	if mundo_variant is Dictionary:
		var mundo: Dictionary = mundo_variant as Dictionary
		if mundo.has("semilla"):
			world_seed = int(mundo.get("semilla", 0))
			world_seed_valida = true

	if not world_seed_valida:
		# Migración de partidas creadas antes del sistema de semillas.
		# La semilla se crea una sola vez y se persiste inmediatamente.
		world_seed = _generar_semilla_mundo()
		world_seed_valida = true
		datos["mundo"] = {
			"semilla": world_seed,
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

	current_scene = "res://scenes/world/main.tscn"
	_partida_aplicada_en_escena = false
	_autosave_timer = 0.0

	_abrir_escena_principal()

	return true


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


# ============================================================
# GUARDADO
# ============================================================

func guardar_partida() -> bool:
	if _guardado_en_curso:
		return false

	if active_save_id.is_empty():
		return false

	var jugador: Node = _player

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

	var datos := _leer_archivo_partida(active_save_id)

	if datos.is_empty():
		_guardado_en_curso = false
		return false

	datos["version"] = SAVE_VERSION
	datos["nombre"] = active_save_name
	datos["actualizado_en"] = _ahora()
	datos["mundo"] = {
		"semilla": world_seed,
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


func capturar_estado_desde_juego(jugador: Node) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return

	player_health = int(
		jugador.get("health")
	)

	player_mana = int(
		jugador.get("mana")
	)

	player_position = jugador.global_position
	player_position_valida = true
	player_tile_valido = false

	var world_gen: Node = _world_generator

	if world_gen != null and world_gen.has_method("get_tile_at"):
		var tile_variant: Variant = world_gen.call(
			"get_tile_at",
			player_position
		)

		if tile_variant is Vector2i:
			player_tile = tile_variant as Vector2i
			player_tile_valido = true

	var stamina_variant: Variant = jugador.get(
		"stamina"
	)

	if stamina_variant != null:
		player_stamina = float(stamina_variant)

	var facing_variant: Variant = jugador.get(
		"facing"
	)

	if facing_variant is Vector2:
		player_facing = facing_variant as Vector2

	if jugador.has_method("obtener_estado_ium"):
		var player_flags_variant: Variant = jugador.call("obtener_estado_ium")
		if player_flags_variant is Dictionary:
			flags["proceso_ium_equipado"] = (
				player_flags_variant as Dictionary
			).duplicate(true)


	var atmosphere: Node = _world_atmosphere
	if atmosphere != null and atmosphere.has_method(
		"obtener_estado_guardado"
	):
			var tiempo_variant: Variant = atmosphere.call(
				"obtener_estado_guardado"
			)

			if tiempo_variant is Dictionary:
				flags["tiempo_mundo"] = (
					tiempo_variant as Dictionary
				).duplicate(true)

	var inventario: Node = _inventory

	if inventario != null and is_instance_valid(inventario):
		var estado_inventario: Dictionary = {}
		if inventario.has_method("serializar_estado_partida"):
			var estado_variant: Variant = inventario.call("serializar_estado_partida")
			if estado_variant is Dictionary:
				estado_inventario = (estado_variant as Dictionary).duplicate(true)

		var rol_partida := "explorador"
		var admin_variant: Variant = flags.get("personaje_admin", {})
		if admin_variant is Dictionary:
			rol_partida = str(
				(admin_variant as Dictionary).get("rol", "explorador")
			).to_lower()

		estado_inventario["rol_partida"] = rol_partida
		flags["inventario_estado"] = estado_inventario

	_capturar_estado_misiones()


func _capturar_estado_misiones() -> void:
	if not is_instance_valid(MissionManager):
		return
	if not MissionManager.has_method("serializar_estado_partida"):
		return
	flags["misiones_estado"] = MissionManager.call(
		"serializar_estado_partida"
	)


func _aplicar_estado_misiones() -> void:
	if not is_instance_valid(MissionManager):
		return
	if not MissionManager.has_method("cargar_estado_partida"):
		return

	var datos_variant: Variant = flags.get("misiones_estado", {})
	if datos_variant is Dictionary:
		MissionManager.call(
			"cargar_estado_partida",
			(datos_variant as Dictionary).duplicate(true)
	)


func _conectar_guardado_rapido() -> void:
	if _guardado_rapido_conectado or active_save_id.is_empty():
		return

	var inventario: Node = _inventory
	if inventario != null and inventario.has_signal("inventory_changed"):
		var inventario_callback := Callable(self, "_al_cambio_guardable")
		if not inventario.inventory_changed.is_connected(inventario_callback):
			inventario.inventory_changed.connect(inventario_callback)

	for nombre in ["mision_aceptada", "progreso_actualizado", "mision_completada"]:
		if not MissionManager.has_signal(nombre):
			continue
		var callback := Callable(self, "_al_cambio_guardable")
		var senal: Signal = MissionManager.get(nombre)
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
	return {
		"player": {
			"health": player_health,
			"mana": player_mana,
			"position_valid": player_position_valida,
			"position": {
				"x": player_position.x,
				"y": player_position.y
			},
			"tile_valid": player_tile_valido,
			"tile": {
				"x": player_tile.x,
				"y": player_tile.y
			},
			"stamina": player_stamina,
			"facing": {
				"x": player_facing.x,
				"y": player_facing.y
			}
		},
		"elapsed_time": elapsed_time,
		"flags": flags.duplicate(true),
		"scene": current_scene
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
			"player": {
				"health": 100,
				"mana": 100,
				"position_valid": false,
				"position": {
					"x": 0.0,
					"y": 0.0
				},
				"tile_valid": false,
				"tile": {
					"x": 0,
					"y": 0
				},
				"stamina": 100.0,
				"facing": {
					"x": 0.0,
					"y": 1.0
				}
			},
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
	player_tile_valido = false
	player_tile = Vector2i.ZERO

	var player_variant: Variant = estado.get(
		"player",
		{}
	)

	if player_variant is Dictionary:
		var datos_player := player_variant as Dictionary

		player_health = int(
			datos_player.get("health", 100)
		)

		player_mana = int(
			datos_player.get("mana", 100)
		)

		player_stamina = float(
			datos_player.get("stamina", 100.0)
		)

		player_position_valida = bool(
			datos_player.get("position_valid", false)
		)

		var posicion_variant: Variant = datos_player.get(
			"position",
			{}
		)

		if posicion_variant is Dictionary and player_position_valida:
			var posicion := posicion_variant as Dictionary
			player_position = Vector2(
				float(posicion.get("x", 0.0)),
				float(posicion.get("y", 0.0))
			)

		player_tile_valido = bool(
			datos_player.get("tile_valid", false)
		)

		var tile_variant: Variant = datos_player.get(
			"tile",
			{}
		)

		if tile_variant is Dictionary and player_tile_valido:
			var tile_datos := tile_variant as Dictionary
			player_tile = Vector2i(
				int(tile_datos.get("x", 0)),
				int(tile_datos.get("y", 0))
			)

		var facing_variant: Variant = datos_player.get(
			"facing",
			{}
		)

		if facing_variant is Dictionary:
			var facing := facing_variant as Dictionary
			player_facing = Vector2(
				float(facing.get("x", 0.0)),
				float(facing.get("y", 1.0))
			)

	elapsed_time = float(
		estado.get(
			"elapsed_time",
			0.0
		)
	)

	var flags_variant: Variant = estado.get(
		"flags",
		{}
	)

	if flags_variant is Dictionary:
		flags = (
			flags_variant as Dictionary
		).duplicate(true)
	else:
		flags = {}


# ============================================================
# ENCICLOPEDIA
# ============================================================

func registrar_criatura_derrotada(criatura: Node) -> bool:
	if criatura == null or not is_instance_valid(criatura):
		return false

	if not criatura.is_in_group("creatures"):
		return false

	var criatura_id := str(criatura.get("criatura_id"))
	if criatura_id.is_empty() and criatura.has_method("get_id"):
		criatura_id = str(criatura.call("get_id"))

	if criatura_id.is_empty():
		return false

	var registros_variant: Variant = flags.get(
		"enciclopedia_criaturas",
		{}
	)

	var registros: Dictionary = {}
	if registros_variant is Dictionary:
		registros = (registros_variant as Dictionary).duplicate(true)

	var derrotas := int(registros.get(criatura_id, 0)) + 1
	registros[criatura_id] = derrotas
	flags["enciclopedia_criaturas"] = registros

	enciclopedia_actualizada.emit(criatura_id)

	print(
		"GameState: criatura descubierta → ",
		criatura_id,
		" | derrotas = ",
		derrotas
	)

	return true


func obtener_criaturas_descubiertas() -> Dictionary:
	var registros_variant: Variant = flags.get(
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
	var registros_variant: Variant = flags.get(
		"mapa_terreno_explorado",
		null
	)

	var registros: Dictionary
	if registros_variant is Dictionary:
		registros = registros_variant as Dictionary
	else:
		registros = {}
		flags["mapa_terreno_explorado"] = registros

	var nuevo: bool = false
	var radio_efectivo: int = maxi(radio, 0)

	for dy in range(-radio_efectivo, radio_efectivo + 1):
		for dx in range(-radio_efectivo, radio_efectivo + 1):
			if (dx * dx + dy * dy) > (
				radio_efectivo * radio_efectivo
			):
				continue

			var explorado: Vector2i = (
				tile + Vector2i(dx, dy)
			)

			var clave: String = (
				str(explorado.x) + "," + str(explorado.y)
			)

			if registros.has(clave):
				continue

			registros[clave] = true
			nuevo = true

	if not nuevo:
		return false

	flags["mapa_terreno_explorado"] = registros
	mapa_exploracion_actualizada.emit()

	return true



func registrar_descubrimiento_mundo(
	bioma: Dictionary,
	ecosistema: Dictionary,
	habitats: Array,
	criaturas: Array
) -> bool:
	var descubrimientos_variant: Variant = flags.get("descubrimientos_mundo", null)
	var descubrimientos: Dictionary
	if descubrimientos_variant is Dictionary:
		descubrimientos = descubrimientos_variant as Dictionary
	else:
		descubrimientos = {}
		flags["descubrimientos_mundo"] = descubrimientos

	var nuevos: Array[Dictionary] = []

	var bioma_id := str(bioma.get("id", ""))
	if not bioma_id.is_empty():
		var biomas_variant: Variant = descubrimientos.get("biomas", {})
		var biomas: Dictionary
		if biomas_variant is Dictionary:
			biomas = biomas_variant as Dictionary
		else:
			biomas = {}
		if not biomas.has(bioma_id):
			biomas[bioma_id] = true
			nuevos.append({"nivel": "bioma", "id": bioma_id})
		descubrimientos["biomas"] = biomas

	var ecosistema_id := str(ecosistema.get("id", ""))
	if not ecosistema_id.is_empty():
		var ecosistemas_variant: Variant = descubrimientos.get("ecosistemas", {})
		var ecosistemas: Dictionary
		if ecosistemas_variant is Dictionary:
			ecosistemas = ecosistemas_variant as Dictionary
		else:
			ecosistemas = {}
		if not ecosistemas.has(ecosistema_id):
			ecosistemas[ecosistema_id] = true
			nuevos.append({"nivel": "ecosistema", "id": ecosistema_id})
		descubrimientos["ecosistemas"] = ecosistemas

	var habitats_variant: Variant = descubrimientos.get("habitats", {})
	var habitats_descubiertos: Dictionary
	if habitats_variant is Dictionary:
		habitats_descubiertos = habitats_variant as Dictionary
	else:
		habitats_descubiertos = {}

	for habitat_variant in habitats:
		if not habitat_variant is Dictionary:
			continue
		var habitat: Dictionary = habitat_variant
		var habitat_id := str(habitat.get("id", ""))
		if habitat_id.is_empty() or habitats_descubiertos.has(habitat_id):
			continue
		habitats_descubiertos[habitat_id] = true
		nuevos.append({"nivel": "habitat", "id": habitat_id})

	descubrimientos["habitats"] = habitats_descubiertos

	var criaturas_variant: Variant = descubrimientos.get("criaturas", {})
	var criaturas_descubiertas: Dictionary
	if criaturas_variant is Dictionary:
		criaturas_descubiertas = criaturas_variant as Dictionary
	else:
		criaturas_descubiertas = {}

	for criatura_variant in criaturas:
		if not criatura_variant is Dictionary:
			continue
		var criatura: Dictionary = criatura_variant
		var criatura_id := str(criatura.get("id", ""))
		if criatura_id.is_empty() or criaturas_descubiertas.has(criatura_id):
			continue
		criaturas_descubiertas[criatura_id] = true
		nuevos.append({"nivel": "criatura", "id": criatura_id})

	descubrimientos["criaturas"] = criaturas_descubiertas

	if nuevos.is_empty():
		return false

	flags["descubrimientos_mundo"] = descubrimientos

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
func obtener_descubrimientos_mundo() -> Dictionary:
	var registros_variant: Variant = flags.get(
		"descubrimientos_mundo",
		{}
	)

	if registros_variant is Dictionary:
		return (
			registros_variant as Dictionary
		).duplicate(true)

	return {}


func obtener_terreno_explorado() -> Dictionary:
	var registros_variant: Variant = flags.get(
		"mapa_terreno_explorado",
		{}
	)

	if registros_variant is Dictionary:
		return (registros_variant as Dictionary).duplicate(true)

	return {}


func esta_explorado(tile: Vector2i) -> bool:
	var registros_variant: Variant = flags.get(
		"mapa_terreno_explorado",
		{}
	)

	if not registros_variant is Dictionary:
		return false

	var clave: String = (
		str(tile.x) + "," + str(tile.y)
	)

	return (registros_variant as Dictionary).has(clave)



# ============================================================
# APLICAR A LA ESCENA
# ============================================================

func _revisar_escena_actual() -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return

	if active_save_id.is_empty() or _partida_aplicada_en_escena:
		return

	var world_gen: Node = _world_generator
	if world_gen == null or not is_instance_valid(world_gen):
		return

	if world_gen.has_method("is_world_ready"):
		if not bool(world_gen.call("is_world_ready")):
			var callback := Callable(
				self,
				"_al_mundo_generado_para_aplicar"
			)
			if world_gen.has_signal("mundo_generado") and not world_gen.is_connected(
				"mundo_generado",
				callback
			):
				world_gen.connect(
					"mundo_generado",
					callback,
					CONNECT_ONE_SHOT
				)
			return

	_aplicar_estado_al_juego()


func _al_mundo_generado_para_aplicar() -> void:
	call_deferred("_revisar_escena_actual")


func _aplicar_estado_al_juego() -> void:
	var jugador: Node = _player

	if jugador == null or not is_instance_valid(jugador):
		return

	if jugador is Node2D and player_position_valida:
		(jugador as Node2D).global_position = player_position

	jugador.set("health", clampi(
		player_health,
		0,
		int(jugador.get("max_health"))
	))

	jugador.set("mana", clampi(
		player_mana,
		0,
		int(jugador.get("max_mana"))
	))

	jugador.set("is_alive", true)

	if jugador.get("stamina") != null:
		jugador.set("stamina", clampf(
			player_stamina,
			0.0,
			float(jugador.get("max_stamina"))
		))

	if jugador.get("facing") is Vector2:
		jugador.set("facing", player_facing)

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

	var proceso_variant: Variant = flags.get(
		"proceso_ium_equipado",
		{}
	)

	if proceso_variant is Dictionary and not (
		proceso_variant as Dictionary
	).is_empty():
		if jugador.has_method("cargar_estado_ium"):
			jugador.call(
				"cargar_estado_ium",
				(proceso_variant as Dictionary).duplicate(true)
			)

	var atmosphere: Node = _world_atmosphere
	var tiempo_variant: Variant = flags.get(
		"tiempo_mundo",
		{}
	)

	if atmosphere != null and tiempo_variant is Dictionary:
		if atmosphere.has_method(
			"establecer_estado_guardado"
		):
			atmosphere.call(
				"establecer_estado_guardado",
				(tiempo_variant as Dictionary).duplicate(true)
			)

	_partida_aplicada_en_escena = true
	_guardado_rapido_conectado = false
	_conectar_guardado_rapido()

	print(
		"GameState: partida cargada → ",
		active_save_name
	)


func _cargar_inventario_al_juego(
	inventario: Node
) -> void:
	var estado_variant: Variant = flags.get(
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
		var admin_actual: Variant = flags.get("personaje_admin", {})
		if admin_actual is Dictionary:
			admin_guardado = (admin_actual as Dictionary).duplicate(true)
		admin_guardado["rol"] = rol_guardado
		if rol_guardado == "explorador":
			admin_guardado["capacidades"] = []
		flags["personaje_admin"] = admin_guardado

	if inventario.has_method("cargar_estado_partida"):
		inventario.call(
			"cargar_estado_partida",
			estado.duplicate(true)
		)


func _abrir_escena_principal() -> void:
	var error := get_tree().change_scene_to_file(
		current_scene
	)

	if error != OK:
		print(
			"GameState: error abriendo Aventura → ",
			error
		)


func _al_cambiar_escena() -> void:
	_partida_aplicada_en_escena = false
	var escena := get_tree().current_scene
	if escena != null:
		current_scene = str(escena.scene_file_path)
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
	return world_seed_valida


func obtener_semilla_mundo() -> int:
	return world_seed


func establecer_semilla_mundo(semilla: int) -> void:
	world_seed = semilla
	world_seed_valida = true


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
	var mundo := WorldData.mundo
	return int(
		mundo.get("version", 0)
	)


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
