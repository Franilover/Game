extends Node

const WORLD_ITEM_SCRIPT: Script = preload(
	"res://scripts/world/world_item.gd"
)

const MAX_OBJECTOS_EN_MUNDO: int = 3

signal catalogo_cargado(items: Array)
signal carga_fallida(mensaje: String)
signal objeto_recogido(datos: Dictionary)

var _request: HTTPRequest
var _cargando: bool = false

var catalogo: Array[Dictionary] = []

var _escena_actual: Node = null
var _objetos_generados_en_escena: bool = false


func _ready() -> void:
	_request = HTTPRequest.new()
	add_child(_request)

	_request.request_completed.connect(
		_al_recibir_catalogo
	)

	if GarliaAuth.has_signal("login_succeeded"):
		GarliaAuth.login_succeeded.connect(
			_al_autenticarse
		)

	if GarliaAuth.has_signal("session_restored"):
		GarliaAuth.session_restored.connect(
			_al_autenticarse
		)

	if GarliaAuth.has_signal("logged_out"):
		GarliaAuth.logged_out.connect(
			_al_cerrar_sesion
		)

	call_deferred("_inicializar")


func _process(_delta: float) -> void:
	var escena := get_tree().current_scene

	if escena != _escena_actual:
		_escena_actual = escena
		_objetos_generados_en_escena = false

	if catalogo.is_empty():
		return

	if _objetos_generados_en_escena:
		return

	var jugador := get_tree().get_first_node_in_group("player")

	if not jugador is Node2D:
		return

	_generar_objetos_en_mundo(
		jugador as Node2D
	)


func _inicializar() -> void:
	if not GarliaAuth.esta_autenticado():
		return

	cargar_catalogo()


func _al_autenticarse(_perfil: Dictionary = {}) -> void:
	cargar_catalogo()


func _al_cerrar_sesion() -> void:
	catalogo.clear()

	_eliminar_objetos_del_mundo()

	_objetos_generados_en_escena = false


func cargar_catalogo() -> void:
	if _cargando:
		return

	if not GarliaAuth.esta_autenticado():
		return

	if GarliaAuth.access_token.is_empty():
		return

	_cargando = true

	var url: String = (
		str(GarliaAuth.SUPABASE_URL)
		+ "/rest/v1/items"
		+ "?select=id,nombre,categoria,descripcion,"
		+ "origen,es_arma,dado_dano,es_armadura,es_escudo,"
		+ "propiedades_fisicas,estado_fisico,geometria_fisica,"
		+ "material_id,creador_id"
		+ "&publicado=eq.true"
		+ "&order=nombre.asc"
		+ "&limit=24"
	)

	var headers := PackedStringArray()

	headers.append(
		"apikey: "
		+ GarliaAuth.SUPABASE_PUBLISHABLE_KEY
	)

	headers.append(
		"Authorization: Bearer "
		+ GarliaAuth.access_token
	)

	headers.append(
		"Accept: application/json"
	)

	var resultado := _request.request(
		url,
		headers,
		HTTPClient.METHOD_GET
	)

	if resultado != OK:
		_cargando = false

		var mensaje := (
			"Error iniciando consulta de objetos: "
			+ str(resultado)
		)

		print("GarliaWorldItems: ", mensaje)
		carga_fallida.emit(mensaje)


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
		carga_fallida.emit(mensaje)
		return

	if response_code < 200 or response_code >= 300:
		var mensaje := (
			"Supabase respondió HTTP "
			+ str(response_code)
		)

		print("GarliaWorldItems: ", mensaje)
		carga_fallida.emit(mensaje)
		return

	var texto := body.get_string_from_utf8()
	var datos = JSON.parse_string(texto)

	if not datos is Array:
		var mensaje := (
			"Supabase devolvió una respuesta de objetos inválida."
		)

		print("GarliaWorldItems: ", mensaje)
		carga_fallida.emit(mensaje)
		return

	catalogo.clear()

	for fila in datos:
		if not fila is Dictionary:
			continue

		catalogo.append(
			(fila as Dictionary).duplicate(true)
		)

	print(
		"GarliaWorldItems: catálogo cargado → ",
		catalogo.size(),
		" objetos publicados."
	)

	catalogo_cargado.emit(
		catalogo.duplicate(true)
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

	escena.add_child(contenedor)

	var cantidad := mini(
		MAX_OBJECTOS_EN_MUNDO,
		catalogo.size()
	)

	var posiciones := [
		Vector2(120.0, 0.0),
		Vector2(-100.0, 60.0),
		Vector2(70.0, 120.0),
	]

	for i in range(cantidad):
		var datos := catalogo[i].duplicate(true)

		var objeto := Node2D.new()
		objeto.set_script(WORLD_ITEM_SCRIPT)

		contenedor.add_child(objeto)

		objeto.global_position = (
			jugador.global_position
			+ posiciones[i]
		)

		objeto.call(
			"configurar",
			datos
		)

		print(
			"GarliaWorldItems: objeto generado → ",
			str(datos.get("nombre", "Objeto")),
			" @ ",
			str(objeto.global_position)
		)

	_objetos_generados_en_escena = true


func intentar_recoger() -> void:
	var jugador := get_tree().get_first_node_in_group("player")

	if not jugador is Node2D:
		return

	var inventario := get_tree().get_first_node_in_group(
		"inventory"
	)

	if not inventario:
		print(
			"GarliaWorldItems: no se encontró el inventario."
		)
		return

	var jugador_2d := jugador as Node2D

	var objeto_cercano: Node2D = null
	var distancia_menor := INF

	for nodo in get_tree().get_nodes_in_group("world_item"):
		if not nodo is Node2D:
			continue

		var objeto := nodo as Node2D

		if not objeto.has_method("esta_cerca"):
			continue

		if not objeto.call(
			"esta_cerca",
			jugador_2d
		):
			continue

		var distancia := objeto.global_position.distance_to(
			jugador_2d.global_position
		)

		if distancia < distancia_menor:
			distancia_menor = distancia
			objeto_cercano = objeto

	if not objeto_cercano:
		print(
			"GarliaWorldItems: no hay ningún objeto cerca."
		)
		return

	var datos = objeto_cercano.call(
		"obtener_datos"
	)

	if not datos is Dictionary:
		return

	var datos_objeto := (
		datos as Dictionary
	).duplicate(true)

	if not datos_objeto.has("cantidad"):
		datos_objeto["cantidad"] = 1

	var agregado: bool = inventario.call(
		"agregar_objeto",
		datos_objeto
	)

	if not agregado:
		print(
			"GarliaWorldItems: no se pudo recoger → ",
			str(datos_objeto.get("nombre", "Objeto"))
		)
		return

	print(
		"GarliaWorldItems: recogido → ",
		str(datos_objeto.get("nombre", "Objeto"))
	)

	objeto_recogido.emit(
		datos_objeto.duplicate(true)
	)

	objeto_cercano.queue_free()




func _eliminar_objetos_del_mundo() -> void:
	if not is_instance_valid(_escena_actual):
		return

	var contenedor := _escena_actual.get_node_or_null(
		"WorldItems"
	)

	if contenedor:
		contenedor.queue_free()
