extends Node2D
class_name StaticForestMap

const TILE_SIZE := 32
const MAP_LEFT := 0
const MAP_RIGHT := 160
const MAP_TOP := -32
const MAP_BOTTOM := 32
const FULL_TILE := Vector2i(2, 1)
const GRASS_TEXTURE := "res://assets/tilesets/Pradera.png"
const FOREST_TEXTURE := "res://assets/tilesets/Bosque.png"
const DIRT_TEXTURE := "res://assets/tilesets/Tierra.png"

var ground_layer: TileMapLayer
var forest_layer: TileMapLayer
var path_layer: TileMapLayer


func _ready() -> void:
	_construir_mapa()
	_crear_limites()


func _construir_mapa() -> void:
	ground_layer = _crear_capa("Ground", GRASS_TEXTURE, -20)
	forest_layer = _crear_capa("ForestEdge", FOREST_TEXTURE, -19)
	path_layer = _crear_capa("DirtPaths", DIRT_TEXTURE, -18)

	# Suelo fijo: toda la superficie se define una sola vez al entrar.
	for y in range(MAP_TOP, MAP_BOTTOM):
		for x in range(MAP_LEFT, MAP_RIGHT):
			ground_layer.set_cell(Vector2i(x, y), 0, FULL_TILE)

	# Franja profunda de bosque en los cuatro lados. El borde visual y las
	# colisiones coinciden para que el jugador nunca camine fuera del mapa.
	for y in range(MAP_TOP, MAP_BOTTOM):
		for x in range(MAP_LEFT, MAP_RIGHT):
			if x < 5 or x >= MAP_RIGHT - 5 or y < MAP_TOP + 5 or y >= MAP_BOTTOM - 5:
				forest_layer.set_cell(Vector2i(x, y), 0, FULL_TILE)

	_pintar_sendero([
		Vector2(560, 120),
		Vector2(820, 120),
		Vector2(1080, 120),
		Vector2(1360, 40),
		Vector2(1600, -80),
		Vector2(1800, -160),
		Vector2(2080, -80),
		Vector2(2380, 20),
		Vector2(2680, 120),
		Vector2(3100, 120),
		Vector2(3600, 120),
		Vector2(4040, 120),
		Vector2(4480, 120)
	], 2)

	# Desvío opcional hacia un pequeño claro escondido al norte.
	_pintar_sendero([
		Vector2(1800, -160),
		Vector2(1880, -300),
		Vector2(1980, -560)
	], 1)


func _crear_capa(nombre: String, textura_path: String, z: int) -> TileMapLayer:
	var textura := load(textura_path) as Texture2D
	if textura == null:
		push_error("StaticForestMap: no se pudo cargar " + textura_path)
		return null

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for y in range(4):
		for x in range(4):
			atlas.create_tile(Vector2i(x, y))
	tile_set.add_source(atlas, 0)

	var layer := TileMapLayer.new()
	layer.name = nombre
	layer.tile_set = tile_set
	layer.z_index = z
	layer.y_sort_enabled = false
	layer.rendering_quadrant_size = 16
	add_child(layer)
	return layer


func _pintar_sendero(puntos: Array[Vector2], ancho: int) -> void:
	if path_layer == null or puntos.size() < 2:
		return
	for i in range(puntos.size() - 1):
		var inicio := puntos[i]
		var fin := puntos[i + 1]
		var pasos := maxi(1, int(ceil(inicio.distance_to(fin) / float(TILE_SIZE * 0.45))))
		for paso in range(pasos + 1):
			var posicion := inicio.lerp(fin, float(paso) / float(pasos))
			var centro := Vector2i(roundi(posicion.x / TILE_SIZE), roundi(posicion.y / TILE_SIZE))
			for y in range(-ancho, ancho + 1):
				for x in range(-ancho, ancho + 1):
					if Vector2(x, y).length() > float(ancho) + 0.35:
						continue
					var celda := centro + Vector2i(x, y)
					if celda.x >= MAP_LEFT + 5 and celda.x < MAP_RIGHT - 5 and celda.y >= MAP_TOP + 5 and celda.y < MAP_BOTTOM - 5:
						path_layer.set_cell(celda, 0, FULL_TILE)


func _crear_limites() -> void:
	var izquierda := float(MAP_LEFT * TILE_SIZE)
	var derecha := float(MAP_RIGHT * TILE_SIZE)
	var arriba := float(MAP_TOP * TILE_SIZE)
	var abajo := float(MAP_BOTTOM * TILE_SIZE)
	_crear_muro("LimiteOeste", Vector2(izquierda, (arriba + abajo) * 0.5), Vector2(64, abajo - arriba))
	_crear_muro("LimiteEste", Vector2(derecha, (arriba + abajo) * 0.5), Vector2(64, abajo - arriba))
	_crear_muro("LimiteNorte", Vector2((izquierda + derecha) * 0.5, arriba), Vector2(derecha - izquierda, 64))
	_crear_muro("LimiteSur", Vector2((izquierda + derecha) * 0.5, abajo), Vector2(derecha - izquierda, 64))


func _crear_muro(nombre: String, posicion: Vector2, tamano: Vector2) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = nombre
	cuerpo.position = posicion
	var colision := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano
	colision.shape = rectangulo
	cuerpo.add_child(colision)
	add_child(cuerpo)


func obtener_limites_mapa() -> Rect2:
	return Rect2(
		Vector2(MAP_LEFT * TILE_SIZE, MAP_TOP * TILE_SIZE),
		Vector2((MAP_RIGHT - MAP_LEFT) * TILE_SIZE, (MAP_BOTTOM - MAP_TOP) * TILE_SIZE)
	)
