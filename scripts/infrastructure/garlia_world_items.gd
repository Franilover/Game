extends Node
class_name GarliaWorldItems


const MAX_OBJECTOS_EN_MUNDO: int = 3
const HTTP_TIMEOUT: float = 15.0
const MAX_CATALOG_RETRIES: int = 3
const CATALOG_RETRY_DELAY: float = 1.5


signal catalogo_cargado(items: Array)
signal carga_fallida(mensaje: String)
signal objeto_recogido(datos: Dictionary)
signal drops_generados(drops: Array)


var _request: HTTPRequest
var _request_drops: HTTPRequest

var _cargando: bool = false
var _intentos_catalogo: int = 0
var _cargando_drops: bool = false
var _cola_drops: Array[Dictionary] = []

var catalogo: Array[Dictionary] = []

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

	_request_drops = HTTPRequest.new()
	_request_drops.timeout = HTTP_TIMEOUT
	add_child(_request_drops)
	_request_drops.request_completed.connect(_al_recibir_drops)

	call_deferred("cargar_catalogo")


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
		return

	print("GarliaWorldItems: reintentando catálogo → intento ", str(_intentos_catalogo + 1), "/", str(MAX_CATALOG_RETRIES), " en ", str(CATALOG_RETRY_DELAY), "s")
	await get_tree().create_timer(CATALOG_RETRY_DELAY).timeout
	if not _cargando and catalogo.is_empty():
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
		carga_fallida.emit(mensaje)
		return

	var datos: Variant = JSON.parse_string(texto)

	if not datos is Array:
		var mensaje := "Supabase devolvió una respuesta de catálogo inválida."
		print("GarliaWorldItems: ", mensaje, " → ", texto)
		carga_fallida.emit(mensaje)
		return

	_intentos_catalogo = 0
	catalogo.clear()

	for fila in datos:
		if not fila is Dictionary:
			continue

		var fila_game := fila as Dictionary
		var item_variant: Variant = fila_game.get("item", null)

		if not item_variant is Dictionary:
			continue

		var item := (item_variant as Dictionary).duplicate(true)

		item["item_id"] = str(fila_game.get("item_id", item.get("id", "")))
		var tipo_objeto_variant: Variant = item.get("tipo_objeto", null)
		if tipo_objeto_variant is Dictionary:
			item["tipo_objeto"] = (tipo_objeto_variant as Dictionary).duplicate(true)
		else:
			item["tipo_objeto"] = {}
		item["tipo"] = str(fila_game.get("tipo", ""))
		item["max_stack"] = maxi(1, int(fila_game.get("max_stack", 1)))

		var propiedades: Variant = fila_game.get("propiedades", {})
		if propiedades is Dictionary:
			item["propiedades_game"] = (propiedades as Dictionary).duplicate(true)
		else:
			item["propiedades_game"] = {}

		catalogo.append(item)

	print("GarliaWorldItems: catálogo público cargado → ", catalogo.size(), " items.")
	catalogo_cargado.emit(catalogo.duplicate(true))


func obtener_catalogo() -> Array[Dictionary]:
	return catalogo.duplicate(true)


func buscar_item_por_id(
	item_id: String
) -> Dictionary:
	var buscado: String = item_id.strip_edges()

	if buscado.is_empty():
		return {}

	for item in catalogo:
		var actual_id: String = str(
			item.get(
				"item_id",
				item.get("id", "")
			)
		).strip_edges()

		if actual_id == buscado:
			return item.duplicate(true)

	return {}


func buscar_item_por_nombre(
	nombre: String
) -> Dictionary:
	var buscado: String = nombre.strip_edges().to_lower()

	if buscado.is_empty():
		return {}

	for item in catalogo:
		var nombre_item: String = str(
			item.get(
				"nombre",
				""
			)
		).strip_edges()

		if nombre_item.to_lower() == buscado:
			return item.duplicate(true)

	return {}


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

	var solicitud_variant: Variant = _cola_drops.pop_front()
	if not solicitud_variant is Dictionary:
		_procesar_siguiente_drop()
		return

	var solicitud: Dictionary = solicitud_variant as Dictionary
	var criatura_id: String = str(solicitud.get("criatura_id", ""))
	_posicion_drops_pendiente = solicitud.get("posicion", Vector2.ZERO) as Vector2

	if criatura_id.is_empty():
		_procesar_siguiente_drop()
		return

	_cargando_drops = true

	var url := (
		str(GarliaAuth.SUPABASE_URL)
		+ "/rest/v1/criatura_drops"
		+ "?select="
		+ "item_id,probabilidad,"
		+ "item:items!inner("
		+ "id,nombre,descripcion,origen,"
		+ "propiedades_fisicas,estado_fisico,"
		+ "geometria_fisica,material_id,creador_id,"
		+ "tipo_objeto:worldbuilder_tipos_objeto!items_tipo_objeto_id_fkey("
		+ "id,clave,nombre_humano,categoria_canonica,plantilla_id,"
		+ "plantilla:plantillas_geometricas!worldbuilder_tipos_objeto_plantilla_id_fkey(categoria)"
		+ " ),"
		+ "items_game!inner("
		+ "item_id,tipo,max_stack,propiedades"
		+ ")"
		+ ")"
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
		print("GarliaWorldItems: error iniciando drops → ", resultado)
		_procesar_siguiente_drop()


func _al_recibir_drops(
	resultado: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_cargando_drops = false

	var texto := body.get_string_from_utf8()

	if resultado != HTTPRequest.RESULT_SUCCESS:
		print(
			"GarliaWorldItems: falló consulta de drops → ",
			resultado
		)
		_procesar_siguiente_drop()
		return

	if response_code < 200 or response_code >= 300:
		print(
			"GarliaWorldItems: HTTP ",
			response_code,
			" al consultar drops → ",
			texto
		)
		_procesar_siguiente_drop()
		return

	var datos: Variant = JSON.parse_string(texto)

	if not datos is Array:
		print("GarliaWorldItems: respuesta de drops inválida → ", texto)
		_procesar_siguiente_drop()
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

		var item_variant: Variant = drop.get("item", null)
		if not item_variant is Dictionary:
			continue

		var item := (item_variant as Dictionary).duplicate(true)
		var item_game_variant: Variant = item.get("items_game", null)
		var item_game: Dictionary = {}

		if item_game_variant is Dictionary:
			item_game = (item_game_variant as Dictionary)
		elif item_game_variant is Array:
			var items_game := item_game_variant as Array
			if items_game.is_empty() or not items_game[0] is Dictionary:
				continue
			item_game = items_game[0] as Dictionary
		else:
			continue

		item["item_id"] = str(drop.get("item_id", item.get("id", "")))
		var tipo_objeto_variant: Variant = item.get("tipo_objeto", null)
		if tipo_objeto_variant is Dictionary:
			item["tipo_objeto"] = (tipo_objeto_variant as Dictionary).duplicate(true)
		else:
			item["tipo_objeto"] = {}
		item["tipo"] = str(item_game.get("tipo", ""))
		item["max_stack"] = maxi(1, int(item_game.get("max_stack", 1)))

		var propiedades: Variant = item_game.get("propiedades", {})
		if propiedades is Dictionary:
			item["propiedades_game"] = (propiedades as Dictionary).duplicate(true)
		else:
			item["propiedades_game"] = {}

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

	print("GarliaWorldItems: drops generados → ", resultado_drops.size())

	for item in resultado_drops:
		_generar_world_item(item, _posicion_drops_pendiente)

	drops_generados.emit(resultado_drops.duplicate(true))
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
) -> void:
	if datos.is_empty():
		return

	_generar_world_item(datos.duplicate(true), posicion)


func _generar_world_item(
	datos: Dictionary,
	posicion: Vector2
) -> void:
	var entities := _entities_root
	if entities == null or not is_instance_valid(entities):
		print("GarliaWorldItems: no se configuró el root de entidades.")
		return

	var objeto := WorldItem.new()
	objeto.configurar_dependencias(_player, _inventory, _mission_manager)
	if _entity_manager == null or not is_instance_valid(_entity_manager):
		return
	if not _entity_manager.registrar_global(objeto):
		return
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


func _generar_objetos_en_mundo(jugador: Node2D) -> void:
	if not is_instance_valid(jugador):
		return

	var entities := _entities_root
	if entities == null or not is_instance_valid(entities):
		return

	_eliminar_objetos_del_mundo()

	var cantidad := mini(MAX_OBJECTOS_EN_MUNDO, catalogo.size())
	var posiciones := [
		Vector2(120.0, 0.0),
		Vector2(-100.0, 60.0),
		Vector2(70.0, 120.0)
	]

	for i in range(cantidad):
		var datos := catalogo[i].duplicate(true)
		_generar_world_item(
			datos,
			jugador.global_position + posiciones[i]
		)

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
