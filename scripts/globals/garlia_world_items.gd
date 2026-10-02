extends Node


const WORLD_ITEM_SCRIPT: Script = preload(
	"res://scripts/world/world_item.gd"
)

const MAX_OBJECTOS_EN_MUNDO: int = 3


signal catalogo_cargado(items: Array)
signal carga_fallida(mensaje: String)
signal objeto_recogido(datos: Dictionary)
signal drops_generados(drops: Array)


var _request: HTTPRequest
var _request_drops: HTTPRequest

var _cargando: bool = false
var _cargando_drops: bool = false

var catalogo: Array[Dictionary] = []

var _escena_actual: Node = null
var _objetos_generados_en_escena: bool = false

var _posicion_drops_pendiente: Vector2 = Vector2.ZERO


func _ready() -> void:
	_request = HTTPRequest.new()
	add_child(_request)

	_request.request_completed.connect(
		_al_recibir_catalogo
	)

	_request_drops = HTTPRequest.new()
	add_child(_request_drops)

	_request_drops.request_completed.connect(
		_al_recibir_drops
	)

	call_deferred(
		"cargar_catalogo"
	)


func _process(_delta: float) -> void:
	var escena := get_tree().current_scene

	if escena != _escena_actual:
		_escena_actual = escena
		_objetos_generados_en_escena = false

	if catalogo.is_empty():
		return

	if _objetos_generados_en_escena:
		return

	var jugador := get_tree().get_first_node_in_group(
		"player"
	)

	if not jugador is Node2D:
		return

	_generar_objetos_en_mundo(
		jugador as Node2D
	)


func cargar_catalogo() -> void:
	if _cargando:
		return

	_cargando = true

	var url := (
		str(GarliaAuth.SUPABASE_URL)
		+ "/rest/v1/items_game"
		+ "?select=item_id,tipo,max_stack,propiedades,"
		+ "item:items!inner("
		+ "id,nombre,descripcion,origen,"
		+ "propiedades_fisicas,estado_fisico,"
		+ "geometria_fisica,material_id,creador_id"
		+ ")"
		+ "&order=nombre.asc"
	)

	var headers := PackedStringArray([
		"apikey: "
			+ GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Accept: application/json"
	])

	var resultado := _request.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		_cargando = false

		var mensaje := (
			"Error iniciando consulta de items_game: "
			+ str(resultado)
		)

		print(
			"GarliaWorldItems: ",
			mensaje
		)

		carga_fallida.emit(
			mensaje
		)


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

		print(
			"GarliaWorldItems: ",
			mensaje
		)

		carga_fallida.emit(
			mensaje
		)

		return

	var texto := body.get_string_from_utf8()

	if response_code < 200 or response_code >= 300:
		var mensaje := (
			"Supabase respondió HTTP "
			+ str(response_code)
			+ ": "
			+ texto
		)

		print(
			"GarliaWorldItems: ",
			mensaje
		)

		carga_fallida.emit(
			mensaje
		)

		return

	var datos = JSON.parse_string(
		texto
	)

	if not datos is Array:
		var mensaje := (
			"Supabase devolvió una respuesta inválida."
		)

		print(
			"GarliaWorldItems: ",
			mensaje
		)

		carga_fallida.emit(
			mensaje
		)

		return

	catalogo.clear()

	for fila in datos:
		if not fila is Dictionary:
			continue

		var fila_game := fila as Dictionary

		var item_variant: Variant = (
			fila_game.get(
				"item",
				null
			)
		)

		if not item_variant is Dictionary:
			continue

		var item := (
			item_variant as Dictionary
		).duplicate(true)

		item["item_id"] = str(
			fila_game.get(
				"item_id",
				item.get(
					"id",
					""
				)
			)
		)

		item["tipo"] = str(
			fila_game.get(
				"tipo",
				""
			)
		)

		item["max_stack"] = maxi(
			1,
			int(
				fila_game.get(
					"max_stack",
					1
				)
			)
		)

		var propiedades: Variant = (
			fila_game.get(
				"propiedades",
				{}
			)
		)

		if propiedades is Dictionary:
			item["propiedades_game"] = (
				propiedades as Dictionary
			).duplicate(true)
		else:
			item["propiedades_game"] = {}

		catalogo.append(
			item
		)

	print(
		"GarliaWorldItems: catálogo público cargado → ",
		catalogo.size(),
		" items."
	)

	catalogo_cargado.emit(
		catalogo.duplicate(true)
	)


func generar_drops_criatura(
	criatura_id: String,
	posicion: Vector2
) -> void:
	if criatura_id.is_empty():
		return

	if _cargando_drops:
		print(
			"GarliaWorldItems: ya hay una consulta de drops en curso."
		)

		return

	_cargando_drops = true
	_posicion_drops_pendiente = posicion

	var url := (
		str(GarliaAuth.SUPABASE_URL)
		+ "/rest/v1/criatura_drops"
		+ "?select="
		+ "item_id,probabilidad,"
		+ "item:items!inner("
		+ "id,nombre,descripcion,origen,"
		+ "propiedades_fisicas,estado_fisico,"
		+ "geometria_fisica,material_id,creador_id,"
		+ "items_game!inner("
		+ "item_id,tipo,max_stack,propiedades"
		+ ")"
		+ ")"
		+ "&criatura_id=eq."
		+ criatura_id
	)

	print(
		"GarliaWorldItems: consultando drops públicos → ",
		criatura_id
	)

	var headers := PackedStringArray([
		"apikey: "
			+ GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Accept: application/json"
	])

	var resultado := _request_drops.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		_cargando_drops = false

		print(
			"GarliaWorldItems: error iniciando drops → ",
			resultado
		)


func _al_recibir_drops(
	resultado: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_cargando_drops = false

	if resultado != HTTPRequest.RESULT_SUCCESS:
		print(
			"GarliaWorldItems: falló consulta de drops → ",
			resultado
		)

		return

	var texto := body.get_string_from_utf8()

	if response_code < 200 or response_code >= 300:
		print(
			"GarliaWorldItems: HTTP ",
			response_code,
			" al consultar drops → ",
			texto
		)

		return

	var datos = JSON.parse_string(
		texto
	)

	if not datos is Array:
		print(
			"GarliaWorldItems: respuesta de drops inválida → ",
			texto
		)

		return

	var resultado_drops: Array = []

	for fila in datos:
		if not fila is Dictionary:
			continue

		var drop := fila as Dictionary

		var probabilidad := clampf(
			float(
				drop.get(
					"probabilidad",
					100.0
				)
			),
			0.0,
			100.0
		)

		var tirada := randf() * 100.0

		if tirada >= probabilidad:
			continue

		var item_variant: Variant = (
			drop.get(
				"item",
				null
			)
		)

		if not item_variant is Dictionary:
			continue

		var item := (
			item_variant as Dictionary
		).duplicate(true)

		var item_game_variant: Variant = (
			item.get(
				"items_game",
				null
			)
		)

		var item_game: Dictionary = {}

		if item_game_variant is Dictionary:
			item_game = (
				item_game_variant as Dictionary
			)

		elif item_game_variant is Array:
			var items_game := (
				item_game_variant as Array
			)

			if items_game.is_empty():
				continue

			var primero: Variant = (
				items_game[0]
			)

			if not primero is Dictionary:
				continue

			item_game = (
				primero as Dictionary
			)

		else:
			continue

		item["item_id"] = str(
			drop.get(
				"item_id",
				item.get(
					"id",
					""
				)
			)
		)

		item["tipo"] = str(
			item_game.get(
				"tipo",
				""
			)
		)

		item["max_stack"] = maxi(
			1,
			int(
				item_game.get(
					"max_stack",
					1
				)
			)
		)

		var propiedades: Variant = (
			item_game.get(
				"propiedades",
				{}
			)
		)

		if propiedades is Dictionary:
			item["propiedades_game"] = (
				propiedades as Dictionary
			).duplicate(true)
		else:
			item["propiedades_game"] = {}

		item["cantidad"] = 1

		resultado_drops.append(
			item
		)

		print(
			"GarliaWorldItems: drop obtenido → ",
			str(
				item.get(
					"nombre",
					"Objeto"
				)
			),
			" | ",
			str(
				item.get(
					"tipo",
					""
				)
			),
			" | probabilidad=",
			probabilidad,
			" | tirada=",
			tirada
		)

	print(
		"GarliaWorldItems: drops generados → ",
		resultado_drops.size()
	)

	for item in resultado_drops:
		_generar_world_item(
			item,
			_posicion_drops_pendiente
		)

	drops_generados.emit(
		resultado_drops.duplicate(true)
	)


func _generar_world_item(
	datos: Dictionary,
	posicion: Vector2
) -> void:
	var escena := get_tree().current_scene

	if not is_instance_valid(escena):
		print(
			"GarliaWorldItems: no existe escena actual para crear WorldItem."
		)

		return

	var objeto := Node2D.new()

	objeto.set_script(
		WORLD_ITEM_SCRIPT
	)

	escena.add_child(
		objeto
	)

	objeto.global_position = (
		posicion
		+ Vector2(
			randf_range(
				-10.0,
				10.0
			),
			randf_range(
				-10.0,
				10.0
			)
		)
	)

	objeto.call(
		"configurar",
		datos.duplicate(true)
	)

	print(
		"GarliaWorldItems: WorldItem creado → ",
		str(
			datos.get(
				"nombre",
				"Objeto"
			)
		),
		" en ",
		objeto.global_position
	)


func _generar_objetos_en_mundo(
	jugador: Node2D
) -> void:
	if not is_instance_valid(jugador):
		return

	var escena := get_tree().current_scene

	if not is_instance_valid(escena):
		return

	_eliminar_objetos_del_mundo()

	var contenedor := Node2D.new()
	contenedor.name = "WorldItems"

	escena.add_child(
		contenedor
	)

	var cantidad := mini(
		MAX_OBJECTOS_EN_MUNDO,
		catalogo.size()
	)

	var posiciones := [
		Vector2(120.0, 0.0),
		Vector2(-100.0, 60.0),
		Vector2(70.0, 120.0)
	]

	for i in range(cantidad):
		var datos := (
			catalogo[i].duplicate(true)
		)

		var objeto := Node2D.new()

		objeto.set_script(
			WORLD_ITEM_SCRIPT
		)

		contenedor.add_child(
			objeto
		)

		objeto.global_position = (
			jugador.global_position
			+ posiciones[i]
		)

		objeto.call(
			"configurar",
			datos
		)

	_objetos_generados_en_escena = true


func intentar_recoger() -> void:
	var jugador := get_tree().get_first_node_in_group(
		"player"
	)

	if not jugador is Node2D:
		return

	var inventario := get_tree().get_first_node_in_group(
		"inventory"
	)

	if inventario == null:
		print(
			"GarliaWorldItems: no se encontró el inventario."
		)

		return

	var jugador_2d := jugador as Node2D

	var objeto_cercano: Node2D = null
	var distancia_menor := INF

	for nodo in get_tree().get_nodes_in_group(
		"world_item"
	):
		if not nodo is Node2D:
			continue

		var objeto := nodo as Node2D

		if not objeto.has_method(
			"esta_cerca"
		):
			continue

		if not objeto.call(
			"esta_cerca",
			jugador_2d
		):
			continue

		var distancia := (
			objeto.global_position.distance_to(
				jugador_2d.global_position
			)
		)

		if distancia < distancia_menor:
			distancia_menor = distancia
			objeto_cercano = objeto

	if objeto_cercano == null:
		return

	var datos = objeto_cercano.call(
		"obtener_datos"
	)

	if not datos is Dictionary:
		return

	var datos_objeto := (
		datos as Dictionary
	).duplicate(true)

	if not datos_objeto.has(
		"cantidad"
	):
		datos_objeto["cantidad"] = 1

	var agregado: bool = inventario.call(
		"agregar_objeto",
		datos_objeto
	)

	if not agregado:
		return

	objeto_recogido.emit(
		datos_objeto.duplicate(true)
	)

	objeto_cercano.queue_free()


func _eliminar_objetos_del_mundo() -> void:
	if not is_instance_valid(
		_escena_actual
	):
		return

	var contenedor := _escena_actual.get_node_or_null(
		"WorldItems"
	)

	if contenedor:
		contenedor.queue_free()
