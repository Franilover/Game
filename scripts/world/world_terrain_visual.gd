extends Node2D
class_name WorldTerrainVisual

const TILE_SEQUENCE: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(3, 3),
	Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 0), Vector2i(3, 2),
	Vector2i(2, 3), Vector2i(3, 1),
	Vector2i(1, 3), Vector2i(0, 1),
	Vector2i(1, 0), Vector2i(2, 2),
	Vector2i(3, 0), Vector2i(2, 0),
	Vector2i(1, 1), Vector2i(2, 1),
]

const CORNER_NEIGHBORS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]

const ZONE_TEXTURES: Dictionary = {
	0: "res://assets/tilesets/Grass.png",
	1: "res://assets/tilesets/Dirt.png",
	2: "res://assets/tilesets/Mountain.png",
	3: "res://assets/tilesets/Desert.png",
	4: "res://assets/tilesets/Water.png",
	5: "res://assets/tilesets/Water.png",
	6: "res://assets/tilesets/Water.png",
	7: "res://assets/tilesets/BASE.png",
	8: "res://assets/tilesets/Forest.png",
	9: "res://assets/tilesets/Desert.png",
}

const TERRAIN_NAMES: PackedStringArray = [
	"Grass", "Dirt", "Stone", "Sand",
	"Water", "Deep Water", "Shore", "Ice",
	"Forest", "Desert",
]

var tile_size: int = 32
var tilemap_dual: TileMapDual
var _base_tiles: Dictionary = {}
var _dirty_cells: Array[Vector2i] = []
var _dirty_lookup: Dictionary = {}

func configurar(nuevo_tile_size: int) -> void:
	tile_size = nuevo_tile_size
	_crear_tilemap()
	tilemap_dual.tile_set = _crear_tileset()
	tilemap_dual.z_index = -1
	tilemap_dual.rendering_quadrant_size = 32
	tilemap_dual._changed()

func _crear_tilemap() -> void:
	if tilemap_dual != null:
		return
	tilemap_dual = TileMapDual.new()
	tilemap_dual.name = "TerrainDual"
	tilemap_dual.godot_4_3_compatibility = false
	add_child(tilemap_dual)

func _crear_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)

	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "<any>")

	for terrain_id in range(1, 9):
		tile_set.add_terrain(0)
		tile_set.set_terrain_name(
			0,
			terrain_id,
			TERRAIN_NAMES[terrain_id - 1]
		)

	var next_source_id := 0

	for zone in range(ZONE_TEXTURES.size()):
		var texture := _cargar_textura_zone(zone)
		if texture == null:
			push_error(
				"WorldTerrainVisual: no se pudo cargar textura para zona "
				+ str(zone)
			)
			continue

		var atlas := TileSetAtlasSource.new()
		atlas.texture = texture
		atlas.texture_region_size = Vector2i(tile_size, tile_size)

		for sequence_pos in TILE_SEQUENCE:
			atlas.create_tile(sequence_pos)

		tile_set.add_source(atlas, next_source_id)

		var terrain_id := zone + 1

		for index in range(TILE_SEQUENCE.size()):
			var data := atlas.get_tile_data(
				TILE_SEQUENCE[index],
				0
			)
			data.terrain_set = 0

			var bits := index
			for neighbor in CORNER_NEIGHBORS:
				var neighbor_terrain := (
					terrain_id if (bits & 1) != 0 else 0
				)
				data.set_terrain_peering_bit(
					neighbor,
					neighbor_terrain
				)
				bits >>= 1

		atlas.get_tile_data(
			TILE_SEQUENCE[15],
			0
		).terrain = terrain_id

		_base_tiles[zone] = {
			"source_id": next_source_id,
			"atlas": TILE_SEQUENCE[15],
		}

		next_source_id += 1

	return tile_set

func _cargar_textura_zone(zone: int) -> Texture2D:
	var path := str(
		ZONE_TEXTURES.get(
			zone,
			"res://assets/tilesets/world_tileset.png"
		)
	)

	var texture := load(path) as Texture2D

	if (
		texture != null
		and texture.get_width() >= tile_size * 4
		and texture.get_height() >= tile_size * 4
	):
		return texture

	var fallback := load(
		"res://assets/tilesets/world_tileset.png"
	) as Texture2D

	if (
		fallback != null
		and fallback.get_width() >= tile_size * 4
		and fallback.get_height() >= tile_size * 4
	):
		return fallback

	return null

func set_zone(cell: Vector2i, zone: int) -> void:
	if not _base_tiles.has(zone):
		return

	var data: Dictionary = _base_tiles[zone]

	tilemap_dual.set_cell(
		cell,
		int(data["source_id"]),
		data["atlas"]
	)

	if not _dirty_lookup.has(cell):
		_dirty_lookup[cell] = true
		_dirty_cells.append(cell)

func flush() -> void:
	if _dirty_cells.is_empty():
		return

	tilemap_dual._update_cells(
		_dirty_cells,
		false
	)

	_dirty_cells.clear()
	_dirty_lookup.clear()

func clear_chunk(
	chunk_coord: Vector2i,
	chunk_size_tiles: int
) -> void:
	var cells: Array[Vector2i] = []

	var origin := Vector2i(
		chunk_coord.x * chunk_size_tiles,
		chunk_coord.y * chunk_size_tiles
	)

	for y in range(chunk_size_tiles):
		for x in range(chunk_size_tiles):
			var cell := Vector2i(
				origin.x + x,
				origin.y + y
			)
			tilemap_dual.erase_cell(cell)
			cells.append(cell)

	if not cells.is_empty():
		tilemap_dual._update_cells(
			cells,
			false
		)
