extends Node
class_name GarliaWorldItems


const WORLD_ITEM_SCENE: PackedScene = preload("res://scenes/world/world_item.tscn")


const MAX_OBJECTOS_EN_MUNDO: int = 3
const CATALOG_CACHE_PATH: String = "user://cache/items_game.json"
const RECIPES_CACHE_PATH: String = "user://cache/recetas_game.json"
const MAX_RECIPES_RETRIES: int = 3
const INTERVALO_REINTENTO_OFFLINE: float = 30.0
const INTERVALO_ACTUALIZACION_CATALOGOS: float = 300.0
const HTTP_TIMEOUT: float = 15.0
const MAX_CATALOG_RETRIES: int = 3
const CATALOG_RETRY_DELAY: float = 1.5
const DROP_RETRY_DELAY: float = 2.0
const MAX_DROP_RETRIES: int = 3


signal catalogo_cargado(items: Array)
signal recetas_cargadas(recetas: Array)
signal carga_fallida(mensaje: String)
signal objeto_recogido(datos: Dictionary)
signal drops_generados(drops: Array)


var _request: HTTPRequest
var _request_drops: HTTPRequest
var _request_recetas: HTTPRequest
var _timer_actualizacion_catalogos: Timer

var _cargando: bool = false
var _intentos_catalogo: int = 0
var _intentos_recetas: int = 0
var _cargando_recetas: bool = false
var _cargando_drops: bool = false
var _solicitud_drop_actual: Dictionary = {}
var _reintentos_drop_actual: int = 0
var _cola_drops: Array[Dictionary] = []

var catalogo: Array[Dictionary] = []
var catalogo_disponible: bool = false
var origen_catalogo: String = ""
var recetas: Array[Dictionary] = []
var recetas_disponibles: bool = false
var origen_recetas: String = ""
var _items_por_id: Dictionary = {}
var _items_por_nombre: Dictionary = {}
var _items_por_prop_id: Dictionary = {}

var _objetos_generados_en_escena: bool = false
var _generacion_habilitada: bool = true

var _posicion_drops_pendiente: Vector2 = Vector2.ZERO
var _player: Player = null
var _inventory: GarliaInventory = null
var _entities_root: Node = null
var _entity_manager: WorldEntityManager = null
var _world_context: WorldContext = null
var _mission_manager: MissionManagerService = null
var _world_items: Array[Node2D] = []


func configurar_dependencias(jugador: Player, inventario: GarliaInventory, entities_root: Node, entity_manager: WorldEntityManager, world_context: WorldContext, mission_manager: MissionManagerService) -> void:
	var root_cambio := _entities_root != entities_root
	_player = jugador
	_inventory = inventario
	_entities_root = entities_root
	_entity_manager = entity_manager
	_world_context = world_context
	_mission_manager = mission_manager
	if root_cambio:
		_objetos_generados_en_escena = false
		_world_items.clear()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_request = HTTPRequest.new()
	_request.timeout = HTTP_TIMEOUT
	add_child(_request)
	_request.request_completed.connect(_al_recibir_catalogo)
	catalogo_cargado.connect(_al_catalogo_disponible_para_drops)

	_request_drops = HTTPRequest.new()
	_request_drops.timeout = HTTP_TIMEOUT
	add_child(_request_drops)
	_request_drops.request_completed.connect(_al_recibir_drops)

	_request_recetas = HTTPRequest.new()
	_request_recetas.timeout = HTTP_TIMEOUT
	add_child(_request_recetas)
	_request_recetas.request_completed.connect(_al_recibir_recetas)

	_cargar_catalogo_local()
	_cargar_recetas_local()
	call_deferred("cargar_catalogo")
	call_deferred("cargar_recetas")
	_timer_actualizacion_catalogos = Timer.new()
	_timer_actualizacion_catalogos.one_shot = true
	_timer_actualizacion_catalogos.wait_time = INTERVALO_ACTUALIZACION_CATALOGOS
	add_child(_timer_actualizacion_catalogos)
	_timer_actualizacion_catalogos.timeout.connect(_actualizar_catalogos_periodicamente)
	_timer_actualizacion_catalogos.start()


func establecer_generacion_habilitada(habilitada: bool) -> void:
	_generacion_habilitada = habilitada
	if not habilitada:
		_objetos_generados_en_escena = true
	else:
		_objetos_generados_en_escena = false


func _process(_delta: float) -> void:
	if not _generacion_habilitada:
		return
	if catalogo.is_empty() or _objetos_generados_en_escena:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if _entities_root == null or not is_instance_valid(_entities_root):
		return
	_generar_objetos_en_mundo(_player)


func cargar_catalogo() -> void:
	if _cargando:
		return

	_cargando = true
	_intentos_catalogo += 1

	var url := (
		str(GarliaAuth.SUPABASE_URL)
		+ "/rest/v1/items_game"
		+ "?select=item_id,tipo,max_stack,propiedades,"
		+ "categoria:categorias_items_game!items_game_categoria_clave_fkey(clave,nombre,descripcion,orden),"
		+ "item:items!inner("
		+ "id,nombre,descripcion,origen,"
		+ "propiedades_fisicas,estado_fisico,"
		+ "geometria_fisica,material_id,creador_id,"
		+ "tipo_objeto:worldbuilder_tipos_objeto!items_tipo_objeto_id_fkey("
		+ "id,clave,nombre_humano,categoria_canonica,plantilla_id,"
		+ "plantilla:plantillas_geometricas!worldbuilder_tipos_objeto_plantilla_id_fkey(categoria)"
		+ ")"
		+ ")"
	)

	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Accept: application/json"
	])

	print("GarliaWorldItems: cargando catálogo público...")

	var resultado := _request.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		_cargando = false
		var mensaje := "Error iniciando consulta de items_game: " + str(resultado)
		print("GarliaWorldItems: ", mensaje)
		_cargar_catalogo_reintentando(mensaje)


func _cargar_catalogo_reintentando(mensaje: String) -> void:
	if _intentos_catalogo >= MAX_CATALOG_RETRIES:
		carga_fallida.emit(mensaje)
		print("GarliaWorldItems: sincronización de objetos pausada; nuevo intento en ", INTERVALO_REINTENTO_OFFLINE, "s.")
		await get_tree().create_timer(INTERVALO_REINTENTO_OFFLINE).timeout
		if is_inside_tree() and not _cargando:
			_intentos_catalogo = 0
			cargar_catalogo()
		return

	print("GarliaWorldItems: reintentando catálogo → intento ", str(_intentos_catalogo + 1), "/", str(MAX_CATALOG_RETRIES), " en ", str(CATALOG_RETRY_DELAY), "s")
	await get_tree().create_timer(CATALOG_RETRY_DELAY).timeout
	if is_inside_tree() and not _cargando:
		cargar_catalogo()


func _al_recibir_catalogo(
	resultado: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_cargando = false

	if resultado != HTTPRequest.RESULT_SUCCESS:
		var mensaje := (
			"Falló la conexión con Supabase. Resultado: "
			+ str(resultado)
		)
		print("GarliaWorldItems: ", mensaje)
		_cargar_catalogo_reintentando(mensaje)
		return

	var texto := body.get_string_from_utf8()

	if response_code < 200 or response_code >= 300:
		var mensaje := (
			"Supabase respondió HTTP "
			+ str(response_code)
		)
		print("GarliaWorldItems: ", mensaje, " → ", texto)
		_cargar_catalogo_reintentando(mensaje)
		return

	var datos: Variant = JSON.parse_string(texto)

	if not datos is Array:
		var mensaje := "Supabase devolvió una respuesta de catálogo inválida."
		print("GarliaWorldItems: ", mensaje, " → ", texto)
		_cargar_catalogo_reintentando(mensaje)
		return

	if datos.is_empty() and not catalogo.is_empty():
		_intentos_catalogo = 0
		print("GarliaWorldItems: Supabase devolvió un catálogo vacío; se conserva la copia local.")
		return

	_intentos_catalogo = 0
	_procesar_catalogo(datos, "Supabase", true)


func _cargar_catalogo_local() -> void:
	var datos := _leer_cache_catalogo(CATALOG_CACHE_PATH)
	if datos.is_empty():
		print("GarliaWorldItems: no existe caché local válida de objetos.")
		return
	_procesar_catalogo(datos, "caché local", false)


func _procesar_catalogo(datos: Array, origen: String, guardar_cache: bool) -> void:
	var catalogo_nuevo: Array[Dictionary] = []

	for fila in datos:
		if not fila is Dictionary:
			continue

		var fila_game := fila as Dictionary
		var item_variant: Variant = fila_game.get("item", null)
		if not item_variant is Dictionary:
			continue

		var item := (item_variant as Dictionary).duplicate(true)
		item["item_id"] = str(fila_game.get("item_id", item.get("id", "")))
		var tipo_objeto_variant: Variant = fila_game.get("tipo_objeto", item.get("tipo_objeto", null))
		if tipo_objeto_variant is Dictionary:
			item["tipo_objeto"] = (tipo_objeto_variant as Dictionary).duplicate(true)
		else:
			item["tipo_objeto"] = {}
		item["tipo"] = str(fila_game.get("tipo", ""))
		item["max_stack"] = maxi(1, int(fila_game.get("max_stack", 1)))

		var propiedades: Variant = fila_game.get("propiedades", {})
		item["propiedades_game"] = (propiedades as Dictionary).duplicate(true) if propiedades is Dictionary else {}

		var categoria_variant: Variant = fila_game.get("categoria", null)
		if categoria_variant is Dictionary:
			item["categoria"] = (categoria_variant as Dictionary).duplicate(true)
			item["categoria_clave"] = str((categoria_variant as Dictionary).get("clave", ""))
		else:
			item["categoria"] = {}
			item["categoria_clave"] = ""

		catalogo_nuevo.append(item)

	if catalogo_nuevo.is_empty():
		print("GarliaWorldItems: ", origen, " no contiene objetos interpretables; se conserva el catálogo anterior.")
		return

	catalogo = catalogo_nuevo
	_items_por_id.clear()
	_items_por_nombre.clear()
	_items_por_prop_id.clear()
	for item in catalogo:
		var id := str(item.get("item_id", item.get("id", ""))).strip_edges()
		var nombre := str(item.get("nombre", "")).strip_edges().to_lower()
		if not id.is_empty():
			_items_por_id[id] = item
		if not nombre.is_empty():
			_items_por_nombre[nombre] = item
		var propiedades_variant: Variant = item.get("propiedades_game", {})
		if propiedades_variant is Dictionary:
			var prop_id := str((propiedades_variant as Dictionary).get("prop_id", "")).strip_edges()
			if not prop_id.is_empty():
				_items_por_prop_id[prop_id] = item
	catalogo_disponible = true
	origen_catalogo = origen

	if guardar_cache:
		_guardar_cache_catalogo(CATALOG_CACHE_PATH, datos, "objetos")

	print("GarliaWorldItems: catálogo cargado desde ", origen, " → ", catalogo.size(), " items.")
	catalogo_cargado.emit(catalogo.duplicate(true))


func _guardar_cache_catalogo(ruta: String, datos: Array, etiqueta: String) -> void:
	var directorio := ProjectSettings.globalize_path("user://cache")
	var error_directorio := DirAccess.make_dir_recursive_absolute(directorio)
	if error_directorio != OK:
		push_warning("GarliaWorldItems: no se pudo crear la carpeta de caché (%s)." % str(error_directorio))
		return
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_warning("GarliaWorldItems: no se pudo guardar caché de %s (%s)." % [etiqueta, str(FileAccess.get_open_error())])
		return
	archivo.store_string(JSON.stringify({
		"version": 1,
		"actualizado_en": Time.get_datetime_string_from_system(true),
		"datos": datos
	}))
	archivo.close()
	print("GarliaWorldItems: caché de %s actualizada." % etiqueta)


func _leer_cache_catalogo(ruta: String) -> Array:
	if not FileAccess.file_exists(ruta):
		return []
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		push_warning("GarliaWorldItems: no se pudo abrir caché %s." % ruta)
		return []
	var texto := archivo.get_as_text()
	archivo.close()
	var datos: Variant = JSON.parse_string(texto)
	if datos is Array:
		return datos
	if datos is Dictionary:
		var contenido: Variant = (datos as Dictionary).get("datos", [])
		if contenido is Array:
			return contenido
	push_warning("GarliaWorldItems: caché inválida en %s." % ruta)
	return []


func cargar_recetas() -> void:
	if _cargando_recetas:
		return
	_cargando_recetas = true
	_intentos_recetas += 1
	var url := str(GarliaAuth.SUPABASE_URL) + "/rest/v1/recetas_game?select=id,nombre,descripcion,categoria,ingredientes,resultado,propiedades&order=nombre.asc"
	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Accept: application/json"
	])
	var access_token: String = GarliaAuth.access_token
	if not access_token.is_empty():
		headers.append("Authorization: Bearer " + access_token)
	var resultado := _request_recetas.request(url, headers, HTTPClient.METHOD_GET)
	if resultado != OK:
		_cargando_recetas = false
		_reintentar_recetas("no se pudo iniciar solicitud: " + str(resultado))


func _cargar_recetas_local() -> void:
	var datos := _leer_cache_catalogo(RECIPES_CACHE_PATH)
	if datos.is_empty():
		print("GarliaWorldItems: no existe caché local de recetas.")
		return
	_procesar_recetas(datos, "caché local", false)


func _al_recibir_recetas(resultado: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_cargando_recetas = false
	var texto := body.get_string_from_utf8()
	if resultado != HTTPRequest.RESULT_SUCCESS:
		_reintentar_recetas("falló conexión: " + str(resultado))
		return
	if response_code < 200 or response_code >= 300:
		_reintentar_recetas("HTTP " + str(response_code) + ": " + texto.left(400))
		return
	var datos: Variant = JSON.parse_string(texto)
	if not datos is Array:
		_reintentar_recetas("respuesta JSON de recetas inválida")
		return
	if (datos as Array).is_empty() and not recetas.is_empty():
		_intentos_recetas = 0
		print("GarliaWorldItems: Supabase devolvió recetas vacías; se conserva la caché.")
		return
	_procesar_recetas(datos as Array, "Supabase", true)


func _procesar_recetas(datos: Array, origen: String, guardar_cache: bool) -> void:
	var nuevas: Array[Dictionary] = []
	for fila in datos:
		if fila is Dictionary:
			nuevas.append((fila as Dictionary).duplicate(true))
	if nuevas.is_empty():
		print("GarliaWorldItems: no hay recetas interpretables desde ", origen, ".")
		return
	recetas = nuevas
	recetas_disponibles = true
	origen_recetas = origen
	if guardar_cache:
		_guardar_cache_catalogo(RECIPES_CACHE_PATH, datos, "recetas")
	_intentos_recetas = 0
	print("GarliaWorldItems: recetas cargadas desde ", origen, " → ", recetas.size())
	recetas_cargadas.emit(obtener_recetas())


func _reintentar_recetas(mensaje: String) -> void:
	print("GarliaWorldItems: ", mensaje)
	if _intentos_recetas >= MAX_RECIPES_RETRIES:
		print("GarliaWorldItems: se conserva la caché de recetas; nuevo intento en ", INTERVALO_REINTENTO_OFFLINE, "s.")
		await get_tree().create_timer(INTERVALO_REINTENTO_OFFLINE).timeout
		if is_inside_tree() and not _cargando_recetas:
			_intentos_recetas = 0
			cargar_recetas()
		return
	await get_tree().create_timer(CATALOG_RETRY_DELAY * float(_intentos_recetas)).timeout
	if is_inside_tree() and not _cargando_recetas:
		cargar_recetas()


func obtener_recetas() -> Array[Dictionary]:
	return recetas.duplicate(true)


func obtener_catalogo() -> Array[Dictionary]:
	return catalogo.duplicate(true)


func buscar_item_por_id(item_id: String) -> Dictionary:
	var buscado := item_id.strip_edges()
	if buscado.is_empty():
		return {}
	var item: Variant = _items_por_id.get(buscado, {})
	return (item as Dictionary).duplicate(true) if item is Dictionary else {}


func buscar_item_por_nombre(nombre: String) -> Dictionary:
	var buscado := nombre.strip_edges().to_lower()
	if buscado.is_empty():
		return {}
	var item: Variant = _items_por_nombre.get(buscado, {})
	return (item as Dictionary).duplicate(true) if item is Dictionary else {}


func buscar_item_por_prop_id(prop_id: String) -> Dictionary:
	var buscado := prop_id.strip_edges()
	if buscado.is_empty():
		return {}
	var item: Variant = _items_por_prop_id.get(buscado, {})
	return (item as Dictionary).duplicate(true) if item is Dictionary else {}


func _actualizar_catalogos_periodicamente() -> void:
	if not is_inside_tree():
		return
	cargar_catalogo()
	cargar_recetas()
	_timer_actualizacion_catalogos.start()


func _al_catalogo_disponible_para_drops(_items: Array) -> void:
	_procesar_siguiente_drop()




func generar_drops_criatura(
	criatura_id: String,
	posicion: Vector2
) -> void:
	if criatura_id.is_empty():
		return

	_cola_drops.append({
		"criatura_id": criatura_id,
		"posicion": posicion
	})

	print(
		"GarliaWorldItems: drop en cola → ",
		criatura_id,
		" | cola=",
		_cola_drops.size()
	)

	_procesar_siguiente_drop()


func _procesar_siguiente_drop() -> void:
	if _cargando_drops:
		return

	if _cola_drops.is_empty():
		return
	# No consumir la cola hasta disponer de los metadatos canónicos del item.
	if not catalogo_disponible:
		return

	var solicitud_variant: Variant = _cola_drops.pop_front()
	if not solicitud_variant is Dictionary:
		_procesar_siguiente_drop()
		return

	var solicitud: Dictionary = solicitud_variant as Dictionary
	_solicitud_drop_actual = solicitud.duplicate(true)
	var criatura_id: String = str(solicitud.get("criatura_id", ""))
	_posicion_drops_pendiente = solicitud.get("posicion", Vector2.ZERO) as Vector2

	if criatura_id.is_empty():
		_procesar_siguiente_drop()
		return

	_cargando_drops = true

	# Los drops sólo descargan su regla. Los datos del objeto se resuelven
	# desde el catálogo compartido para evitar repetir joins y metadatos.
	var url := (
		str(GarliaAuth.SUPABASE_URL)
		+ "/rest/v1/criatura_drops"
		+ "?select=item_id,probabilidad"
		+ "&criatura_id=eq."
		+ criatura_id
	)

	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Accept: application/json"
	])

	print(
		"GarliaWorldItems: consultando drops públicos → ",
		criatura_id
	)

	var resultado := _request_drops.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		_cargando_drops = false
		_reintentar_drop_actual("error iniciando consulta: " + str(resultado))


func _al_recibir_drops(
	resultado: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_cargando_drops = false

	var texto := body.get_string_from_utf8()

	if resultado != HTTPRequest.RESULT_SUCCESS:
		_reintentar_drop_actual("falló conexión: " + str(resultado))
		return

	if response_code < 200 or response_code >= 300:
		_reintentar_drop_actual("HTTP " + str(response_code) + ": " + texto)
		return

	var datos: Variant = JSON.parse_string(texto)

	if not datos is Array:
		_reintentar_drop_actual("respuesta JSON inválida: " + texto)
		return

	var resultado_drops: Array = []

	for fila in datos:
		if not fila is Dictionary:
			continue

		var drop := fila as Dictionary
		var probabilidad := clampf(float(drop.get("probabilidad", 100.0)), 0.0, 100.0)
		var tirada := randf() * 100.0

		if tirada >= probabilidad:
			continue

		var item_id := str(drop.get("item_id", "")).strip_edges()
		var item := buscar_item_por_id(item_id)
		if item.is_empty():
			push_warning("GarliaWorldItems: drop referencia un item que no está en el catálogo compartido: " + item_id)
			continue
		item["cantidad"] = 1
		resultado_drops.append(item)

		print(
			"GarliaWorldItems: drop obtenido → ",
			str(item.get("nombre", "Objeto")),
			" | ",
			str(item.get("tipo", "")),
			" | probabilidad=",
			probabilidad,
			" | tirada=",
			tirada
		)

	_reintentos_drop_actual = 0
	_solicitud_drop_actual.clear()
	print("GarliaWorldItems: drops generados → ", resultado_drops.size())

	for item in resultado_drops:
		_generar_world_item(item, _posicion_drops_pendiente)

	drops_generados.emit(resultado_drops.duplicate(true))
	_procesar_siguiente_drop()


func _reintentar_drop_actual(mensaje: String) -> void:
	print("GarliaWorldItems: ", mensaje)
	if _solicitud_drop_actual.is_empty():
		_procesar_siguiente_drop()
		return
	if _reintentos_drop_actual >= MAX_DROP_RETRIES:
		print("GarliaWorldItems: solicitud de drop conservada para recuperación manual → ", _solicitud_drop_actual)
		_cola_drops.push_front(_solicitud_drop_actual.duplicate(true))
		_solicitud_drop_actual.clear()
		_reintentos_drop_actual = 0
		return
	_reintentos_drop_actual += 1
	var espera := DROP_RETRY_DELAY * float(_reintentos_drop_actual)
	print("GarliaWorldItems: reintento de drop ", _reintentos_drop_actual, "/", MAX_DROP_RETRIES, " en ", espera, "s")
	await get_tree().create_timer(espera).timeout
	if not is_inside_tree():
		return
	_cola_drops.push_front(_solicitud_drop_actual.duplicate(true))
	_solicitud_drop_actual.clear()
	_procesar_siguiente_drop()


func obtener_prop_por_id(prop_id: String) -> Dictionary:
	var buscado := prop_id.strip_edges()
	if buscado.is_empty():
		return {}

	for prop in WorldData.obtener_props_game():
		if str(prop.get("id", "")).strip_edges() == buscado:
			return prop.duplicate(true)

	return {}


func es_objeto_colocable(datos: Dictionary) -> bool:
	if datos.is_empty():
		return false

	var propiedades_variant: Variant = datos.get("propiedades_game", {})
	if not propiedades_variant is Dictionary:
		return false

	var propiedades := propiedades_variant as Dictionary
	var prop_id := str(propiedades.get("prop_id", "")).strip_edges()
	return bool(propiedades.get("colocable", false)) and not prop_id.is_empty()


func colocar_objeto(datos: Dictionary, posicion: Vector2) -> bool:
	if not es_objeto_colocable(datos):
		return false

	var propiedades := datos.get("propiedades_game", {}) as Dictionary
	var prop_id := str(propiedades.get("prop_id", "")).strip_edges()
	var prop := obtener_prop_por_id(prop_id)

	if prop.is_empty():
		print("GarliaWorldItems: no existe el prop canónico → ", prop_id)
		return false

	var entities := _entities_root
	if entities == null or not is_instance_valid(entities):
		return false

	var prop_node := preload("res://scenes/world/world_prop.tscn").instantiate() as WorldProp
	if prop_node == null:
		return false

	var datos_prop := prop.duplicate(true)
	var clave_prop := str(prop.get("clave", "")).strip_edges()
	if clave_prop == "flor_verde" or clave_prop.begins_with("flor_verde_"):
		datos_prop["asset_path"] = "res://assets/art/props/Flor Verdel.png"
	else:
		datos_prop["asset_path"] = "res://assets/art/props/" + str(prop.get("nombre", "")) + ".png"
	datos_prop["item_id"] = str(datos.get("item_id", datos.get("id", "")))
	datos_prop["colocado_por_jugador"] = true

	prop_node.configurar_dependencias(_world_context, _inventory, self)
	prop_node.configurar_desde_game_data(datos_prop)
	if _entity_manager == null or not is_instance_valid(_entity_manager):
		return false
	if not _entity_manager.registrar_global(prop_node):
		return false
	prop_node.global_position = posicion

	print(
		"GarliaWorldItems: prop colocado → ",
		str(prop.get("nombre", "Prop")),
		" | posición=",
		posicion
	)

	return true


func soltar_objeto_al_mundo(
	datos: Dictionary,
	posicion: Vector2
) -> bool:
	if datos.is_empty():
		return false

	return _generar_world_item(datos.duplicate(true), posicion)


func _generar_world_item(
	datos: Dictionary,
	posicion: Vector2
) -> bool:
	if not ItemIconResolver.tiene_icono(datos):
		print("GarliaWorldItems: objeto no implementado todavía; falta su sprite → ", str(datos.get("nombre", "Objeto")))
		return false

	var entities := _entities_root
	if entities == null or not is_instance_valid(entities):
		print("GarliaWorldItems: no se configuró el root de entidades.")
		return false

	if _entity_manager == null or not is_instance_valid(_entity_manager):
		print("GarliaWorldItems: no se configuró WorldEntityManager.")
		return false

	var objeto := WORLD_ITEM_SCENE.instantiate() as WorldItem
	if objeto == null:
		push_error("GarliaWorldItems: no se pudo instanciar la escena WorldItem.")
		return false
	objeto.configurar_dependencias(_player, _inventory, _mission_manager)
	if not _entity_manager.registrar_global(objeto):
		objeto.free()
		print("GarliaWorldItems: WorldEntityManager rechazó el WorldItem.")
		return false
	_world_items.append(objeto)

	objeto.global_position = posicion + Vector2(
		randf_range(-10.0, 10.0),
		randf_range(-10.0, 10.0)
	)

	objeto.configurar(datos.duplicate(true))

	print(
		"GarliaWorldItems: WorldItem creado → ",
		str(datos.get("nombre", "Objeto")),
		" en ",
		objeto.global_position
	)
	return true


func _generar_objetos_en_mundo(_jugador: Node2D) -> void:
	# El catálogo de items no es una lista de colocación inicial.
	# Los objetos del mundo deben aparecer por generación explícita de props
	# o por drops solicitados; nunca junto al jugador al iniciar una zona.
	_objetos_generados_en_escena = true


func intentar_recoger() -> void:
	var jugador_2d := _player
	if jugador_2d == null or not is_instance_valid(jugador_2d):
		return
	var inventario := _inventory
	if inventario == null or not is_instance_valid(inventario):
		return
	var objeto_cercano: Node2D = null
	var distancia_menor := INF

	for nodo_variant in _world_items:
		var nodo: Node = nodo_variant
		if not nodo is Node2D:
			continue

		var objeto := nodo as Node2D
		if not objeto.has_method("esta_cerca"):
			continue

		if not objeto.call("esta_cerca", jugador_2d):
			continue

		var distancia := objeto.global_position.distance_to(jugador_2d.global_position)
		if distancia < distancia_menor:
			distancia_menor = distancia
			objeto_cercano = objeto

	if objeto_cercano == null:
		return

	var datos: Dictionary = (objeto_cercano as WorldItem).obtener_datos()
	if not datos is Dictionary:
		return

	var datos_objeto := (datos as Dictionary).duplicate(true)
	if not datos_objeto.has("cantidad"):
		datos_objeto["cantidad"] = 1

	var agregado: bool = inventario.agregar_objeto(datos_objeto)
	if not agregado:
		return

	objeto_recogido.emit(datos_objeto.duplicate(true))
	objeto_cercano.queue_free()


func _eliminar_objetos_del_mundo() -> void:
	for item in _world_items:
		if is_instance_valid(item):
			item.queue_free()
	_world_items.clear()
