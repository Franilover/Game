extends RefCounted
## Construye las capas y parcelas del vivero de Torres.
## La escena y los interiores siguen siendo responsabilidad de ReinoTorres.

const WATERING_INTERACTABLE_SCRIPT: Script = preload("res://scripts/gameplay/watering_interactable.gd")
const TILE_SIZE := 32
const ATLAS_COORDINATES: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1),
	Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2),
	Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)
]
const TERRAIN_NEIGHBORS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
]


static func crear_tilemap_tierra(padre: Node) -> TileMapDual:
	var textura := load("res://assets/tilesets/Tierra.png") as Texture2D
	if textura == null:
		push_error("TorresViveroBuilder: no se pudo cargar assets/tilesets/Tierra.png")
		return null

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_terrain_set()
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, 0, "<any>")
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, 1, "Tierra de cultivo")

	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coordenada in ATLAS_COORDINATES:
		atlas.create_tile(coordenada)
	for indice in range(ATLAS_COORDINATES.size()):
		var datos := atlas.get_tile_data(ATLAS_COORDINATES[indice], 0)
		datos.terrain_set = 0
		datos.terrain = 1
		var bits := indice
		for vecino in TERRAIN_NEIGHBORS:
			datos.set_terrain_peering_bit(vecino, 1 if (bits & 1) != 0 else 0)
			bits >>= 1
	tileset.add_source(atlas, 1)

	var tilemap := TileMapDual.new()
	tilemap.name = "TierraCultivableDual"
	tilemap.tile_set = tileset
	tilemap.godot_4_3_compatibility = false
	tilemap.z_index = -1
	tilemap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	padre.add_child(tilemap)
	return tilemap


static func crear_capa_tierra_mojada(padre: Node) -> TileMapLayer:
	var textura := load("res://assets/tilesets/Tierra Mojada.png") as Texture2D
	if textura == null:
		push_error("TorresViveroBuilder: no se pudo cargar assets/tilesets/Tierra Mojada.png")
		return null

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coordenada in ATLAS_COORDINATES:
		atlas.create_tile(coordenada)
	tileset.add_source(atlas, 0)

	var capa := TileMapLayer.new()
	capa.name = "TierraMojadaVivero"
	capa.tile_set = tileset
	capa.z_index = 0
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	padre.add_child(capa)
	return capa


static func agregar_parcela(
	padre: Node,
	tilemap: TileMapDual,
	capa_humedad: TileMapLayer,
	nombre: String,
	posicion: Vector2,
	dimensiones: Vector2i
) -> void:
	if not is_instance_valid(tilemap):
		push_error("TorresViveroBuilder: no se pudo crear el TileMapDual de tierra del vivero.")
		return

	var celdas: Array[Vector2i] = []
	for y in range(dimensiones.y):
		for x in range(dimensiones.x):
			var desplazamiento := Vector2(
				(float(x) - float(dimensiones.x - 1) / 2.0) * float(TILE_SIZE),
				(float(y) - float(dimensiones.y - 1) / 2.0) * float(TILE_SIZE)
			)
			var celda := tilemap.local_to_map(posicion + desplazamiento)
			if celda in celdas:
				continue
			celdas.append(celda)
			tilemap.draw_cell(celda, 1)

			var parcela := Node2D.new()
			parcela.name = "%s_%d_%d" % [nombre, celda.x, celda.y]
			parcela.position = tilemap.map_to_local(celda)
			parcela.z_index = 0
			parcela.set_script(WATERING_INTERACTABLE_SCRIPT)
			padre.add_child(parcela)
			var es_celda_central := x == int(dimensiones.x / 2) and y == int(dimensiones.y / 2)
			parcela.call("configurar_parcela", parcela.name, nombre if es_celda_central else "", capa_humedad, celda)

	tilemap.call_deferred("_update_cells", celdas, false)
