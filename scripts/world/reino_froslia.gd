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
	{"name": "Centro de Expediciones", "path": "res://assets/art/kingdom/Froslia/Centro de Expediciones.png", "position": Vector2(-320.0, -240.0), "target_size": Vector2(136.0, 120.0)},
	{"name": "Escuela", "path": "res://assets/art/kingdom/Froslia/Escuela.png", "position": Vector2(0.0, -400.0), "target_size": Vector2(132.0, 112.0)},
	{"name": "Cuartel de la Guardia", "path": "res://assets/art/kingdom/Froslia/Cuartel_de_la_Guardia.png", "position": Vector2(320.0, -240.0), "target_size": Vector2(132.0, 112.0)},
]

var _terrain_layers: Array[TileMapDual] = []


func _ready() -> void:
	_crear_terreno()
	_crear_edificios()


func _crear_terreno() -> void:
	# Cada terreno usa su propio TileMapDual, igual que Pradera/Tierra en el mundo.
	# La capa inferior aporta el suelo y la superior compone sus bordes transparentes.
	var nieve_cells: Array[Vector2i] = []
	var tierra_cells: Array[Vector2i] = []
	var tierra_lookup: Dictionary = {}
	for y in range(-18, 18):
		for x in range(-26, 26):
			nieve_cells.append(Vector2i(x, y))
	for y in range(-18, 18):
		for x in [-1, 0, 1]:
			_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, y))
	for x in range(-26, 26):
		for y in [-1, 0, 1]:
			_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, y))
	for y in range(-4, 5):
		for x in range(-6, 7):
			_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, y))
	for x in range(-10, -1):
		_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, -8))
	for y in range(-12, -1):
		_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(0, y))
	for x in range(1, 11):
		_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, -8))

	var capa_tierra := _crear_capa_dual("TerrenoTierraNevada", "res://assets/tilesets/Tierra Nevada.png", -4095)
	var capa_nieve := _crear_capa_dual("TerrenoNieve", "res://assets/tilesets/Nieve.png", -4094)
	await _preparar_capa_dual(capa_tierra, tierra_cells)
	await _preparar_capa_dual(capa_nieve, nieve_cells)


func _agregar_celda_unica(celdas: Array[Vector2i], lookup: Dictionary, celda: Vector2i) -> void:
	if lookup.has(celda):
		return
	lookup[celda] = true
	celdas.append(celda)


func _crear_capa_dual(nombre: String, ruta_textura: String, z: int) -> TileMapDual:
	var capa := TILE_MAP_DUAL_SCRIPT.new() as TileMapDual
	capa.name = nombre
	capa.z_index = z
	capa.z_as_relative = false
	capa.rendering_quadrant_size = 16
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.material = GHOST_MATERIAL
	capa.godot_4_3_compatibility = false
	capa.tile_set = _crear_tileset_dual(ruta_textura)
	add_child(capa)
	_terrain_layers.append(capa)
	return capa


func _preparar_capa_dual(capa: TileMapDual, celdas: Array[Vector2i]) -> void:
	if not is_instance_valid(capa) or celdas.is_empty():
		return
	await get_tree().process_frame
	capa.reconstruir_renderer_dual()
	for celda in celdas:
		capa.set_cell(celda, 0, Vector2i(2, 1))
	capa._update_cells(celdas, false)


func _crear_tileset_dual(ruta_textura: String) -> TileSet:
	var textura := load(ruta_textura) as Texture2D
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "<any>")
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 1, "Terreno")
	if textura == null:
		push_error("ReinoFroslia: no se pudo cargar el atlas: " + ruta_textura)
		return tile_set
	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coordenada in TILE_SEQUENCE:
		atlas.create_tile(coordenada)
	for indice in range(TILE_SEQUENCE.size()):
		var datos := atlas.get_tile_data(TILE_SEQUENCE[indice], 0)
		datos.terrain_set = 0
		datos.terrain = 1
		var bits := indice
		for vecino in NEIGHBORS:
			datos.set_terrain_peering_bit(vecino, 1 if (bits & 1) != 0 else 0)
			bits >>= 1
	tile_set.add_source(atlas, 0)
	return tile_set

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
		sprite.position = Vector2(0.0, -42.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 2
		var tamano_objetivo: Vector2 = edificio.get("target_size", Vector2(132.0, 112.0))
		var tamano_textura := textura.get_size()
		if tamano_textura.x > 0.0 and tamano_textura.y > 0.0:
			var escala := minf(tamano_objetivo.x / tamano_textura.x, tamano_objetivo.y / tamano_textura.y)
			sprite.scale = Vector2.ONE * escala
		cuerpo.add_child(sprite)
