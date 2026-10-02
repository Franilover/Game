extends Node
## GameState — estado de la partida y guardado local.
##
## Las partidas NO se guardan en Supabase.
## Cada partida corresponde a un JSON independiente en user://partidas/.

const SAVE_DIRECTORY := "user://partidas"
const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 5.0

var player_health: int = 100
var player_mana: int = 100
var player_position: Vector2 = Vector2.ZERO
var player_stamina: float = 100.0
var player_facing: Vector2 = Vector2.DOWN
var player_position_valida: bool = false

var current_scene: String = ""
var elapsed_time: float = 0.0

var flags: Dictionary = {}

var active_save_id: String = ""
var active_save_name: String = ""

var _autosave_timer: float = 0.0
var _partida_aplicada_en_escena: bool = false
var _menu_interceptado: bool = false
var _guardado_en_curso: bool = false

signal enciclopedia_actualizada(criatura_id: String)
signal mapa_exploracion_actualizada


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SAVE_DIRECTORY)
	)

	get_tree().scene_changed.connect(
		_al_cambiar_escena
	)


func _process(delta: float) -> void:
	elapsed_time += delta
	_autosave_timer += delta

	_supervisar_menu_aventura()
	_supervisar_partida_activa()

	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		guardar_partida()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar_partida()


# ============================================================
# MENÚ DE AVENTURA
# ============================================================

func _supervisar_menu_aventura() -> void:
	var escena := get_tree().current_scene

	if escena == null:
		return

	if escena.name != "StartMenu":
		_menu_interceptado = false
		return

	var boton := escena.get_node_or_null(
		"Center/StartButton"
	)

	if not boton is Button:
		return

	var button := boton as Button

	if _menu_interceptado:
		return

	var original := Callable(
		escena,
		"_iniciar_partida"
	)

	if button.pressed.is_connected(original):
		button.pressed.disconnect(original)

	if not button.pressed.is_connected(
		_al_pulsar_aventura
	):
		button.pressed.connect(
			_al_pulsar_aventura
		)

	_menu_interceptado = true


func _al_pulsar_aventura() -> void:
	if not WorldData.esta_cargado():
		return

	abrir_selector_partidas()


func abrir_selector_partidas() -> void:
	var escena := get_tree().current_scene

	if escena == null:
		return

	if escena.get_node_or_null(
		"LocalSaveSelector"
	) != null:
		return

	var selector_scene: PackedScene = load(
		"res://scenes/ui/save_selector.tscn"
	) as PackedScene

	if selector_scene == null:
		push_error(
			"GameState: no se pudo cargar save_selector.tscn."
		)
		return

	var selector: Node = selector_scene.instantiate()
	selector.name = "LocalSaveSelector"
	escena.add_child(selector)

	print(
		"GameState: selector de partidas abierto."
	)


# ============================================================
# PARTIDAS
# ============================================================

func obtener_partidas() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var directorio := DirAccess.open(SAVE_DIRECTORY)

	if directorio == null:
		return resultado

	directorio.list_dir_begin()

	while true:
		var nombre_archivo := directorio.get_next()

		if nombre_archivo.is_empty():
			break

		if directorio.current_is_dir():
			continue

		if not nombre_archivo.ends_with(
			".json"
		):
			continue

		var id := nombre_archivo.trim_suffix(
			".json"
		)

		var datos := _leer_archivo_partida(id)

		if datos.is_empty():
			continue

		resultado.append(
			_extraer_metadata_partida(datos)
		)

	directorio.list_dir_end()

	resultado.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("actualizado_en", "")) > str(
				b.get("actualizado_en", "")
			)
	)

	return resultado


func crear_partida(nombre: String) -> String:
	var nombre_limpio := nombre.strip_edges()

	if nombre_limpio.is_empty():
		nombre_limpio = _nombre_partida_por_defecto()

	var ahora := Time.get_datetime_string_from_system(
		true
	)

	var id := "save_" + str(
		Time.get_unix_time_from_system()
	).replace(".", "_") + "_" + str(
		randi_range(1000, 9999)
	)

	var datos := _estado_base_partida(
		id,
		nombre_limpio,
		ahora,
		ahora
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

	current_scene = "res://scenes/wold/main.tscn"
	_partida_aplicada_en_escena = false
	_autosave_timer = 0.0

	_abrir_escena_principal()

	return true


func eliminar_partida(id: String) -> bool:
	if id.is_empty():
		return false

	var ruta := _ruta_partida(id)

	if not FileAccess.file_exists(ruta):
		return false

	var error := DirAccess.remove_absolute(
		ProjectSettings.globalize_path(ruta)
	)

	if error != OK:
		print(
			"GameState: no se pudo eliminar partida → ",
			id,
			" error=",
			error
		)
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

	var jugador := get_tree().get_first_node_in_group(
		"player"
	)

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

	var player_flags_variant: Variant = jugador.get(
		"_proceso_ium_equipado"
	)

	if player_flags_variant is Dictionary:
		flags["proceso_ium_equipado"] = (
			player_flags_variant as Dictionary
		).duplicate(true)

	var inventario := get_tree().get_first_node_in_group(
		"inventory"
	)

	if inventario != null and is_instance_valid(inventario):
		var inventory_items: Array = []
		var items_variant: Variant = inventario.get("items")

		if items_variant is Array:
			for item_variant in items_variant as Array:
				if item_variant is Dictionary:
					inventory_items.append(
						(item_variant as Dictionary).duplicate(true)
					)
				else:
					inventory_items.append({})

		var hotbar: Array = []
		var hotbar_variant: Variant = inventario.get(
			"hotbar_indices"
		)

		if hotbar_variant is Array:
			for indice_variant in hotbar_variant as Array:
				hotbar.append(int(indice_variant))

		var equipment_state: Dictionary = {}
		var equipment_variant: Variant = inventario.get("equipo")

		if equipment_variant is Dictionary:
			equipment_state = (
				equipment_variant as Dictionary
			).duplicate(true)

		flags["inventario_estado"] = {
			"items": inventory_items,
			"hotbar_indices": hotbar,
			"indice_hotbar_activo": int(
				inventario.get("indice_hotbar_activo")
			),
			"equipo": equipment_state
		}


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
	actualizado_en: String
) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"id": id,
		"nombre": nombre,
		"creado_en": creado_en,
		"actualizado_en": actualizado_en,
		"mundo_version": _obtener_version_mundo(),
		"estado": {
			"player": {
				"health": 100,
				"mana": 100,
				"position_valid": false,
				"position": {
					"x": 0.0,
					"y": 0.0
				},
				"stamina": 100.0,
				"facing": {
					"x": 0.0,
					"y": 1.0
				}
			},
			"elapsed_time": 0.0,
			"flags": {},
			"scene": "res://scenes/wold/main.tscn"
		}
	}


func _aplicar_estado_memoria(
	estado: Dictionary
) -> void:
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
		{}
	)

	var registros: Dictionary = {}

	if registros_variant is Dictionary:
		registros = (registros_variant as Dictionary).duplicate(true)

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

func _supervisar_partida_activa() -> void:
	if active_save_id.is_empty():
		return

	var escena := get_tree().current_scene

	if escena == null:
		return

	var world_gen := escena.get_node_or_null(
		"World/WorldGenerator"
	)

	if world_gen == null:
		return

	if not _partida_aplicada_en_escena:
		if world_gen.has_method("is_world_ready"):
			if not bool(world_gen.call("is_world_ready")):
				return

		_aplicar_estado_al_juego()
		return

	
func _aplicar_estado_al_juego() -> void:
	var jugador := get_tree().get_first_node_in_group(
		"player"
	)

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

	var inventario := get_tree().get_first_node_in_group(
		"inventory"
	)

	if inventario != null and is_instance_valid(inventario):
		_cargar_inventario_al_juego(
			inventario
		)

	var proceso_variant: Variant = flags.get(
		"proceso_ium_equipado",
		{}
	)

	if proceso_variant is Dictionary and not (
		proceso_variant as Dictionary
	).is_empty():
		if jugador.has_method("equipar_proceso_ium"):
			jugador.call(
				"equipar_proceso_ium",
				(proceso_variant as Dictionary).duplicate(true)
			)

	_partida_aplicada_en_escena = true

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
	var items_variant: Variant = estado.get(
		"items",
		[]
	)

	var nuevos_items: Array[Dictionary] = []

	if items_variant is Array:
		for item_variant in items_variant as Array:
			if item_variant is Dictionary:
				nuevos_items.append(
					(item_variant as Dictionary).duplicate(true)
				)
			else:
				nuevos_items.append({})

	var slot_count := int(inventario.get("slot_count"))

	if slot_count > 0:
		while nuevos_items.size() < slot_count:
			nuevos_items.append({})

		if nuevos_items.size() > slot_count:
			nuevos_items.resize(slot_count)

	inventario.set(
		"items",
		nuevos_items
	)

	var equipo_variant: Variant = estado.get(
		"equipo",
		{}
	)

	if equipo_variant is Dictionary:
		if inventario.has_method("establecer_equipo"):
			inventario.call(
				"establecer_equipo",
				(equipo_variant as Dictionary).duplicate(true)
			)

	var hotbar_variant: Variant = estado.get(
		"hotbar_indices",
		[]
	)

	var nuevos_hotbar: Array[int] = []

	if hotbar_variant is Array:
		for indice_variant in hotbar_variant as Array:
			nuevos_hotbar.append(
				int(indice_variant)
			)

	var hotbar_count := 8

	while nuevos_hotbar.size() < hotbar_count:
		nuevos_hotbar.append(
			nuevos_hotbar.size() if nuevos_hotbar.size() < slot_count else -1
		)

	if nuevos_hotbar.size() > hotbar_count:
		nuevos_hotbar.resize(hotbar_count)

	inventario.set(
		"hotbar_indices",
		nuevos_hotbar
	)

	var indice_activo := clampi(
		int(estado.get("indice_hotbar_activo", 0)),
		0,
		hotbar_count - 1
	)

	inventario.set(
		"indice_hotbar_activo",
		indice_activo
	)

	if inventario.has_method("actualizar"):
		inventario.call("actualizar")

	if inventario.has_signal("inventory_changed"):
		inventario.inventory_changed.emit()

	if inventario.has_method("_emitir_objeto_activo"):
		inventario.call("_emitir_objeto_activo")


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
	current_scene = str(
		get_tree().current_scene.scene_file_path
	)


# ============================================================
# ARCHIVOS
# ============================================================

func _ruta_partida(id: String) -> String:
	return SAVE_DIRECTORY + "/" + id + ".json"


func _leer_archivo_partida(id: String) -> Dictionary:
	if id.is_empty():
		return {}

	var ruta := _ruta_partida(id)

	if not FileAccess.file_exists(ruta):
		return {}

	var archivo := FileAccess.open(
		ruta,
		FileAccess.READ
	)

	if archivo == null:
		return {}

	var texto := archivo.get_as_text()
	archivo.close()

	var datos = JSON.parse_string(texto)

	if not datos is Dictionary:
		return {}

	return (datos as Dictionary).duplicate(true)


func _escribir_archivo_partida(
	id: String,
	datos: Dictionary
) -> bool:
	if id.is_empty():
		return false

	var ruta := _ruta_partida(id)
	var archivo := FileAccess.open(
		ruta,
		FileAccess.WRITE
	)

	if archivo == null:
		print(
			"GameState: no se pudo abrir guardado → ",
			ruta
		)
		return false

	archivo.store_string(
		JSON.stringify(datos)
	)
	archivo.close()

	return true


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
