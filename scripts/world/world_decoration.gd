extends Node2D

const PROP_SCENE = preload("res://scenes/wold/world_prop.tscn")

@export var radio_generacion: float = 720.0
@export var radio_limpieza: float = 850.0
@export var tamano_celda: float = 72.0
@export var probabilidad_base: float = 0.78
@export var maximo_props: int = 180

var player = null
var world_generator = null

var celdas = {}
var ultima_celda_jugador = Vector2i(999999, 999999)
var contador_actualizacion = 0.0

func _ready() -> void:
	call_deferred("_inicializar")

func _inicializar() -> void:
	_buscar_referencias()

	if player != null:
		_generar_alrededor_del_jugador()

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_buscar_referencias()

	if player == null or not is_instance_valid(player):
		return

	contador_actualizacion += delta

	if contador_actualizacion < 0.35:
		return

	contador_actualizacion = 0.0

	var celda_actual = _obtener_celda(player.global_position)

	if celda_actual != ultima_celda_jugador:
		ultima_celda_jugador = celda_actual
		_generar_alrededor_del_jugador()
		_limpiar_lejos()

func _buscar_referencias() -> void:
	var encontrado_player = get_tree().get_first_node_in_group("player")

	if encontrado_player != null:
		player = encontrado_player

	var mundo = get_tree().current_scene

	if not is_instance_valid(mundo):
		return

	var encontrado_generador = mundo.find_child("WorldGenerator", true, false)

	if encontrado_generador != null:
		world_generator = encontrado_generador

func _generar_alrededor_del_jugador() -> void:
	if not is_instance_valid(player):
		return

	if not is_instance_valid(world_generator):
		_buscar_referencias()

	if not is_instance_valid(world_generator):
		return

	var centro = _obtener_celda(player.global_position)
	var cantidad_celdas = ceili(radio_generacion / tamano_celda)

	for y in range(-cantidad_celdas, cantidad_celdas + 1):
		for x in range(-cantidad_celdas, cantidad_celdas + 1):
			if celdas.size() >= maximo_props:
				return

			var celda = centro + Vector2i(x, y)

			if celdas.has(celda):
				continue

			var posicion = _posicion_celda(celda)

			if posicion.distance_to(player.global_position) > radio_generacion:
				continue

			var roll = float(abs(hash(str(celda.x) + ":" + str(celda.y) + ":densidad")) % 1000) / 1000.0

			if roll > probabilidad_base:
				celdas[celda] = null
				continue

			var prop_creado = _crear_prop_en(posicion, celda)
			celdas[celda] = prop_creado

	_asegurar_especiales(centro)

func _asegurar_especiales(centro: Vector2i) -> void:
	if celdas.size() >= maximo_props:
		return

	var candidatos = [
		centro + Vector2i(4, 1),
		centro + Vector2i(-4, 2),
		centro + Vector2i(3, -4),
		centro + Vector2i(-3, -3),
		centro + Vector2i(6, 0),
		centro + Vector2i(-6, 1),
		centro + Vector2i(1, 6),
		centro + Vector2i(-1, -6)
	]

	var cueva_creada = false
	var estructura_creada = false

	for celda in candidatos:
		if cueva_creada and estructura_creada:
			break

		if celdas.has(celda):
			continue

		var posicion = _posicion_celda(celda)

		if not _es_posicion_valida(posicion):
			celdas[celda] = null
			continue

		var bioma = _obtener_bioma(posicion)

		if bioma.is_empty():
			continue

		if bioma == "Agua dulce" or bioma == "Marino":
			continue

		var tipo_especial = ""

		if not cueva_creada and not _hay_tipo_cerca(posicion, "cueva", 320.0):
			tipo_especial = "cueva"
		elif not estructura_creada and not _hay_tipo_cerca(posicion, "estructura", 260.0):
			tipo_especial = "estructura"

		if tipo_especial.is_empty():
			continue

		var prop = PROP_SCENE.instantiate()
		add_child(prop)
		prop.global_position = posicion

		var variante = abs(hash(str(celda.x) + ":" + str(celda.y) + ":especial")) % 6
		var semilla = hash(str(celda.x) + ":" + str(celda.y) + ":" + bioma + ":especial")

		prop.configurar(tipo_especial, bioma, variante, semilla, {
			"tipo": tipo_especial,
			"bioma": bioma,
			"posicion": posicion,
			"celda": celda
		})

		celdas[celda] = prop

		if tipo_especial == "cueva":
			cueva_creada = true
		else:
			estructura_creada = true

func _crear_prop_en(posicion: Vector2, celda: Vector2i):
	if not _es_posicion_valida(posicion):
		return null

	var bioma = _obtener_bioma(posicion)

	if bioma.is_empty():
		return null

	var tipo = _elegir_tipo(bioma, posicion, celda)

	if tipo.is_empty():
		return null

	var prop = PROP_SCENE.instantiate()
	add_child(prop)
	prop.global_position = posicion

	var variante = abs(hash(str(celda.x) + ":" + str(celda.y))) % 6
	var semilla = hash(str(celda.x) + ":" + str(celda.y) + ":" + bioma)

	prop.configurar(tipo, bioma, variante, semilla, {
		"tipo": tipo,
		"bioma": bioma,
		"posicion": posicion,
		"celda": celda
	})

	return prop

func _es_posicion_valida(posicion: Vector2) -> bool:
	if not is_instance_valid(world_generator):
		return false

	if world_generator.has_method("is_walkable"):
		return bool(world_generator.call("is_walkable", posicion))

	return true

func _obtener_bioma(posicion: Vector2) -> String:
	if not is_instance_valid(world_generator):
		return ""

	if not world_generator.has_method("get_bioma_at"):
		return ""

	return _extraer_nombre(world_generator.call("get_bioma_at", posicion))

func _extraer_nombre(valor) -> String:
	if valor == null:
		return ""

	if valor is String:
		return valor

	if valor is Dictionary:
		if valor.has("nombre"):
			return str(valor["nombre"])
		if valor.has("name"):
			return str(valor["name"])

	return str(valor)

func _elegir_tipo(bioma: String, posicion: Vector2, celda: Vector2i) -> String:
	var r = abs(hash(str(celda.x) + ":" + str(celda.y) + ":tipo"))
	var roll = float(r % 1000) / 1000.0

	var estructura_cerca = _hay_tipo_cerca(posicion, "estructura", 190.0)
	var cueva_cerca = _hay_tipo_cerca(posicion, "cueva", 250.0)

	match bioma:
		"Bosque":
			if roll < 0.46:
				return "arbol"
			if roll < 0.67:
				return "flor"
			if roll < 0.83:
				return "planta"
			if roll < 0.89:
				return "recurso"
			if roll < 0.895 and not cueva_cerca:
				return "cueva"
			if roll < 0.905 and not estructura_cerca:
				return "estructura"

		"Pradera":
			if roll < 0.12:
				return "arbol"
			if roll < 0.48:
				return "flor"
			if roll < 0.79:
				return "planta"
			if roll < 0.88:
				return "recurso"
			if roll < 0.885 and not estructura_cerca:
				return "estructura"

		"Desierto":
			if roll < 0.43:
				return "planta"
			if roll < 0.62:
				return "recurso"
			if roll < 0.66:
				return "flor"
			if roll < 0.675 and not cueva_cerca:
				return "cueva"
			if roll < 0.685 and not estructura_cerca:
				return "estructura"

		"Montaña":
			if roll < 0.10:
				return "arbol"
			if roll < 0.23:
				return "planta"
			if roll < 0.58:
				return "recurso"
			if roll < 0.60 and not cueva_cerca:
				return "cueva"
			if roll < 0.615 and not estructura_cerca:
				return "estructura"

		"Tundra":
			if roll < 0.16:
				return "arbol"
			if roll < 0.31:
				return "planta"
			if roll < 0.48:
				return "flor"
			if roll < 0.73:
				return "recurso"
			if roll < 0.75 and not cueva_cerca:
				return "cueva"
			if roll < 0.758 and not estructura_cerca:
				return "estructura"

		"Humedal":
			if roll < 0.10:
				return "arbol"
			if roll < 0.33:
				return "flor"
			if roll < 0.71:
				return "planta"
			if roll < 0.84:
				return "recurso"
			if roll < 0.845 and not estructura_cerca:
				return "estructura"

		"Agua dulce", "Marino":
			if roll < 0.68:
				return "recurso"
			if roll < 0.90:
				return "planta"

		_:
			if roll < 0.25:
				return "arbol"
			if roll < 0.55:
				return "planta"
			if roll < 0.78:
				return "flor"
			return "recurso"

	return ""

func _hay_tipo_cerca(posicion: Vector2, tipo: String, distancia: float) -> bool:
	for celda in celdas:
		var nodo = celdas[celda]

		if nodo == null or not is_instance_valid(nodo):
			continue

		if not nodo.has_method("obtener_tipo"):
			continue

		if nodo.obtener_tipo() != tipo:
			continue

		if nodo.global_position.distance_to(posicion) <= distancia:
			return true

	return false

func _limpiar_lejos() -> void:
	if not is_instance_valid(player):
		return

	var celdas_a_borrar = []

	for celda in celdas:
		var nodo = celdas[celda]
		var posicion = _posicion_celda(celda)

		if posicion.distance_to(player.global_position) <= radio_limpieza:
			continue

		if nodo != null and is_instance_valid(nodo):
			nodo.queue_free()

		celdas_a_borrar.append(celda)

	for celda in celdas_a_borrar:
		celdas.erase(celda)

func _obtener_celda(posicion: Vector2) -> Vector2i:
	return Vector2i(
		floori(posicion.x / tamano_celda),
		floori(posicion.y / tamano_celda)
	)

func _posicion_celda(celda: Vector2i) -> Vector2:
	var base = Vector2(
		(float(celda.x) + 0.5) * tamano_celda,
		(float(celda.y) + 0.5) * tamano_celda
	)

	var desplazamiento_x = _valor_celda(celda, 17) * (tamano_celda * 0.34)
	var desplazamiento_y = _valor_celda(celda, 41) * (tamano_celda * 0.34)

	return base + Vector2(desplazamiento_x, desplazamiento_y)

func _valor_celda(celda: Vector2i, extra: int) -> float:
	var valor = abs(hash(str(celda.x) + ":" + str(celda.y) + ":" + str(extra)))
	return float(valor % 1000) / 500.0 - 1.0
