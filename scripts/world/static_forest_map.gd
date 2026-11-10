extends Node2D
class_name StaticForestMap

const TILE_SIZE := 32
const MAP_LEFT := 0
const MAP_RIGHT := 160
const MAP_TOP := -32
const MAP_BOTTOM := 32

const ZONE_GRASS := 0
const ZONE_DIRT := 1
const ZONE_FOREST := 8

const TERRAIN_VISUAL_SCRIPT := preload("res://scripts/world/world_terrain_visual.gd")

var terrain_renderer: Node


func _ready() -> void:
	_construir_mapa()
	_crear_limites()


func _construir_mapa() -> void:
	# Reutilizar el renderer canónico del mundo: crea TileMapDual, registra
	# los 16 patrones de esquina de cada atlas y compone los bordes mediante
	# el addon. No pintar TileMapLayer con un atlas_coords fijo.
	terrain_renderer = TERRAIN_VISUAL_SCRIPT.new()
	terrain_renderer.name = "TerrainRenderer"
	add_child(terrain_renderer)
	terrain_renderer.call("configurar", TILE_SIZE)

	# TileMapDual crea sus nodos Display durante _ready().
	await get_tree().process_frame
	terrain_renderer.call("finalizar_preparacion_renderer")

	# Base de pradera y anillo de bosque. Cada celda pertenece a un terreno;
	# TileMapDual resuelve automáticamente sus cuatro esquinas.
	for y in range(MAP_TOP, MAP_BOTTOM):
		for x in range(MAP_LEFT, MAP_RIGHT):
			var cell := Vector2i(x, y)
			if _es_borde_bosque(cell):
				_establecer_terreno(cell, ZONE_FOREST, "Bosque")
			else:
				_establecer_terreno(cell, ZONE_GRASS, "Pradera")

	# Sendero principal: se pinta como zona Tierra dentro del terreno de
	# pradera; las uniones se resuelven por el mismo DualGrid.
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
	], 1)

	# Desvío opcional hacia el claro escondido.
	_pintar_sendero([
		Vector2(1800, -160),
		Vector2(1880, -300),
		Vector2(1980, -560)
	], 0)

	# set_zone registra las celdas y las fronteras dirty. Procesar el Display
	# por tandas entre frames evita un único flush gigante al entrar.
	while bool(terrain_renderer.call("tiene_flush_pendiente")):
		terrain_renderer.call("procesar_flush", 512)
		await get_tree().process_frame


func _establecer_terreno(cell: Vector2i, zone: int, bioma: String) -> void:
	terrain_renderer.call("set_zone", cell, zone, zone, bioma)


func _es_borde_bosque(cell: Vector2i) -> bool:
	return (
		cell.x < MAP_LEFT + 5
		or cell.x >= MAP_RIGHT - 5
		or cell.y < MAP_TOP + 5
		or cell.y >= MAP_BOTTOM - 5
	)


func _pintar_sendero(puntos: Array[Vector2], ancho: int) -> void:
	if puntos.size() < 2:
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
					var cell := centro + Vector2i(x, y)
					if (
						cell.x >= MAP_LEFT + 5
						and cell.x < MAP_RIGHT - 5
						and cell.y >= MAP_TOP + 5
						and cell.y < MAP_BOTTOM - 5
				):
						_establecer_terreno(cell, ZONE_DIRT, "Tierra")


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
