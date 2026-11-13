extends Node2D
class_name ReservaCarmesiMap

const TILE_SIZE := 32
const MAP_LEFT := -20
const MAP_RIGHT := 200
const MAP_TOP := -55
const MAP_BOTTOM := 55

const ZONE_GRASS := 0
const ZONE_DIRT := 1
const ZONE_WATER := 4
const ZONE_FOREST := 8
const TERRAIN_VISUAL_SCRIPT := preload("res://scripts/world/world_terrain_visual.gd")

signal mapa_construido

var terrain_renderer: Node
var mapa_listo: bool = false


func _ready() -> void:
	construir_mapa()
	crear_limites()


func construir_mapa() -> void:
	terrain_renderer = TERRAIN_VISUAL_SCRIPT.new()
	terrain_renderer.name = "TerrainRenderer"
	add_child(terrain_renderer)
	terrain_renderer.call("configurar", TILE_SIZE)
	await get_tree().process_frame
	terrain_renderer.call("finalizar_preparacion_renderer")

	# Agrupar todas las escrituras evita recomponer el TileMapDual por cada celda.
	terrain_renderer.call("comenzar_lote")

	# Base continua de pradera: cada sector se pinta de forma explícita abajo.
	for y in range(MAP_TOP, MAP_BOTTOM):
		for x in range(MAP_LEFT, MAP_RIGHT):
			pintar(Vector2i(x, y), ZONE_GRASS, "Pradera")

	# Bosques densos al norte y oeste, dejando corredores entre las masas.
	pintar_elipse(Vector2i(18, -30), Vector2i(27, 18), ZONE_FOREST, "Bosque")
	pintar_elipse(Vector2i(68, -35), Vector2i(22, 16), ZONE_FOREST, "Bosque")
	pintar_elipse(Vector2i(112, -28), Vector2i(28, 19), ZONE_FOREST, "Bosque")
	pintar_elipse(Vector2i(-8, 2), Vector2i(13, 35), ZONE_FOREST, "Bosque")
	pintar_elipse(Vector2i(46, 29), Vector2i(25, 17), ZONE_FOREST, "Bosque")
	pintar_elipse(Vector2i(145, 31), Vector2i(34, 17), ZONE_FOREST, "Bosque")

	# Río sinuoso que atraviesa el sector oriental y separa rutas de cacería.
	pintar_trazo([
		Vector2i(168, -55), Vector2i(160, -34), Vector2i(169, -16),
		Vector2i(153, 2), Vector2i(160, 20), Vector2i(145, 39),
		Vector2i(151, 55)
	], ZONE_WATER, 3, "Marino")

	# Caminos de tierra hechos a mano: llegada, pradera central y pabellones.
	pintar_trazo([
		Vector2i(8, 15), Vector2i(20, 10), Vector2i(37, 4),
		Vector2i(55, 1), Vector2i(73, 4), Vector2i(91, 0),
		Vector2i(108, -7), Vector2i(126, -3), Vector2i(145, 2)
	], ZONE_DIRT, 2, "Tierra")
	pintar_trazo([
		Vector2i(55, 1), Vector2i(52, -13), Vector2i(58, -27),
		Vector2i(68, -39)
	], ZONE_DIRT, 1, "Tierra")
	pintar_trazo([
		Vector2i(91, 0), Vector2i(100, 15), Vector2i(119, 27),
		Vector2i(139, 34)
	], ZONE_DIRT, 1, "Tierra")
	pintar_trazo([
		Vector2i(20, 10), Vector2i(16, 25), Vector2i(25, 39)
	], ZONE_DIRT, 1, "Tierra")

	terrain_renderer.call("terminar_lote")
	while bool(terrain_renderer.call("tiene_flush_pendiente")):
		terrain_renderer.call("procesar_flush", 512)
		await get_tree().process_frame

	mapa_listo = true
	mapa_construido.emit()


func pintar(celda: Vector2i, zona: int, bioma: String) -> void:
	terrain_renderer.call("set_zone", celda, zona, zona, bioma)


func pintar_elipse(centro: Vector2i, radio: Vector2i, zona: int, bioma: String) -> void:
	for y in range(centro.y - radio.y, centro.y + radio.y + 1):
		for x in range(centro.x - radio.x, centro.x + radio.x + 1):
			var dx := float(x - centro.x) / maxf(float(radio.x), 1.0)
			var dy := float(y - centro.y) / maxf(float(radio.y), 1.0)
			if dx * dx + dy * dy <= 1.0:
				pintar(Vector2i(x, y), zona, bioma)


func pintar_trazo(puntos: Array[Vector2i], zona: int, ancho: int, bioma: String) -> void:
	for indice in range(puntos.size() - 1):
		var inicio := puntos[indice]
		var fin := puntos[indice + 1]
		var pasos := maxi(1, int(ceil(Vector2(inicio).distance_to(Vector2(fin)) * 1.5)))
		for paso in range(pasos + 1):
			var posicion := Vector2(inicio).lerp(Vector2(fin), float(paso) / float(pasos))
			var centro := Vector2i(roundi(posicion.x), roundi(posicion.y))
			for y in range(-ancho, ancho + 1):
				for x in range(-ancho, ancho + 1):
					if Vector2(x, y).length() <= float(ancho) + 0.35:
						pintar(centro + Vector2i(x, y), zona, bioma)


func crear_limites() -> void:
	var izquierda := float(MAP_LEFT * TILE_SIZE)
	var derecha := float(MAP_RIGHT * TILE_SIZE)
	var arriba := float(MAP_TOP * TILE_SIZE)
	var abajo := float(MAP_BOTTOM * TILE_SIZE)
	crear_muro("LimiteOeste", Vector2(izquierda, (arriba + abajo) * 0.5), Vector2(64, abajo - arriba))
	crear_muro("LimiteEste", Vector2(derecha, (arriba + abajo) * 0.5), Vector2(64, abajo - arriba))
	crear_muro("LimiteNorte", Vector2((izquierda + derecha) * 0.5, arriba), Vector2(derecha - izquierda, 64))
	crear_muro("LimiteSur", Vector2((izquierda + derecha) * 0.5, abajo), Vector2(derecha - izquierda, 64))


func crear_muro(nombre: String, posicion: Vector2, tamano: Vector2) -> void:
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
	return Rect2(Vector2(MAP_LEFT * TILE_SIZE, MAP_TOP * TILE_SIZE), Vector2((MAP_RIGHT - MAP_LEFT) * TILE_SIZE, (MAP_BOTTOM - MAP_TOP) * TILE_SIZE))
