extends Node2D
## Primera versión explorable de Froslia: terreno nevado y tres edificios.

const TILE_SIZE := 32
const TILE_MAP_DUAL_SCRIPT: Script = preload("res://addons/TileMapDual/tile_map_dual.gd")
const GHOST_MATERIAL: Material = preload("res://addons/TileMapDual/ghost_material.tres")
const TILE_SEQUENCE: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1),
	Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2),
	Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1),
]
const NEIGHBORS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]
const BUILDINGS: Array[Dictionary] = [
	{
		"name": "Centro de Expediciones",
		"path": "res://assets/art/kingdom/Froslia/Centro de Expediciones.png",
		"position": Vector2(-320.0, -240.0),
	},
	{
		"name": "Escuela",
		"path": "res://assets/art/kingdom/Froslia/Escuela.png",
		"position": Vector2(0.0, -400.0),
	},
	{
		"name": "Cuartel de la Guardia",
		"path": "res://assets/art/kingdom/Froslia/Cuartel_de_la_Guardia.png",
		"position": Vector2(320.0, -240.0),
	},
]

var _tilemap: TileMapDual


func _ready() -> void:
	_crear_terreno()
	_crear_edificios()


func _crear_terreno() -> void:
	_tilemap = TILE_MAP_DUAL_SCRIPT.new() as TileMapDual
	_tilemap.name = "TerrenoNevado"
	_tilemap.material = GHOST_MATERIAL
	_tilemap.tile_set = _crear_tileset_dual()
	_tilemap.godot_4_3_compatibility = false
	add_child(_tilemap)

	# El addon inicializa sus capas de visualización en _ready().
	await get_tree().process_frame
	_tilemap.reconstruir_renderer_dual()

	var celdas: Array[Vector2i] = []
	for y in range(-18, 18):
		for x in range(-26, 26):
			var celda := Vector2i(x, y)
			_tilemap.set_cell(celda, 1, Vector2i(2, 1))
			celdas.append(celda)

	# Caminos y plaza: Tierra Nevada cumple el mismo papel que Tierra
	# sobre Pradera en el TileMap Dual de referencia.
	for y in range(-18, 18):
		for x in [-1, 0, 1]:
			_tilemap.set_cell(Vector2i(x, y), 2, Vector2i(2, 1))
	for x in range(-26, 26):
		for y in [-1, 0, 1]:
			_tilemap.draw_cell(Vector2i(x, y), 2)
	for y in range(-4, 5):
		for x in range(-6, 7):
			_tilemap.draw_cell(Vector2i(x, y), 2)

	# Accesos desde el eje central a los tres edificios.
	for x in range(-10, -1):
		_tilemap.draw_cell(Vector2i(x, -8), 2)
	for y in range(-12, -1):
		_tilemap.draw_cell(Vector2i(0, y), 2)
	for x in range(1, 11):
		_tilemap.draw_cell(Vector2i(x, -8), 2)

	_tilemap._update_cells(celdas, false)


func _crear_tileset_dual() -> TileSet:
	var nieve := load("res://assets/tilesets/Nieve.png") as Texture2D
	var tierra_nevada := load("res://assets/tilesets/Tierra Nevada.png") as Texture2D
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for nombre in ["<any>", "Nieve", "Tierra Nevada"]:
		if nombre == "<any>":
			tile_set.add_terrain(0)
			tile_set.set_terrain_name(0, 0, nombre)
		elif nombre == "Nieve":
			tile_set.add_terrain(0)
			tile_set.set_terrain_name(0, 1, nombre)
		else:
			tile_set.add_terrain(0)
			tile_set.set_terrain_name(0, 2, nombre)

	if nieve == null or tierra_nevada == null:
		push_error("ReinoFroslia: faltan Nieve.png o Tierra Nevada.png.")
		return tile_set

	_agregar_atlas_terreno(tile_set, nieve, 1)
	_agregar_atlas_terreno(tile_set, tierra_nevada, 2)
	return tile_set


func _agregar_atlas_terreno(tile_set: TileSet, textura: Texture2D, terreno: int) -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coordenada in TILE_SEQUENCE:
		atlas.create_tile(coordenada)
	for indice in range(TILE_SEQUENCE.size()):
		var datos := atlas.get_tile_data(TILE_SEQUENCE[indice], 0)
		datos.terrain_set = 0
		datos.terrain = terreno
		var bits := indice
		for vecino in NEIGHBORS:
			datos.set_terrain_peering_bit(vecino, terreno if (bits & 1) != 0 else 0)
			bits >>= 1
	tile_set.add_source(atlas, terreno)


func _crear_edificios() -> void:
	for edificio in BUILDINGS:
		var ruta := str(edificio.get("path", ""))
		var textura := load(ruta) as Texture2D
		if textura == null:
			push_error("ReinoFroslia: no se pudo cargar el edificio: " + ruta)
			continue

		var cuerpo := StaticBody2D.new()
		cuerpo.name = str(edificio.get("name", "Edificio")).replace(" ", "")
		cuerpo.position = edificio.get("position", Vector2.ZERO)
		cuerpo.collision_layer = 1
		cuerpo.collision_mask = 0
		add_child(cuerpo)

		var colision := CollisionShape2D.new()
		var forma := RectangleShape2D.new()
		forma.size = Vector2(112.0, 64.0)
		colision.shape = forma
		colision.position = Vector2(0.0, 12.0)
		cuerpo.add_child(colision)

		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = textura
		sprite.position = Vector2(0.0, -28.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 2
		cuerpo.add_child(sprite)
