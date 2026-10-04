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

# Cada familia visual tiene su propia textura base. La capa de bioma
# se encarga de aislarla de los atlas de los demás biomas.
const ZONE_TEXTURES: Dictionary = {
	# Fallbacks usando únicamente atlas que existen actualmente en el repo.
	0: "res://assets/tilesets/Pradera.png",
	1: "res://assets/tilesets/Tierra.png",
	2: "res://assets/tilesets/Montaña.png",
	3: "res://assets/tilesets/Desierto.png",
	4: "res://assets/tilesets/Marino.png",
	5: "res://assets/tilesets/Marino.png",
	6: "res://assets/tilesets/Marino.png",
	7: "res://assets/tilesets/Montaña.png",
	8: "res://assets/tilesets/Bosque.png",
	9: "res://assets/tilesets/Desierto.png",
}

const VARIACIONES_POR_BIOMA: Dictionary = {
	"Pradera": {
		"texture": "res://assets/tilesets/Pradera_Variaciones.png",
		"zone": 0,
		"count": 16,
	},
	"Bosque": {
		"texture": "res://assets/tilesets/Bosque_Variaciones.png",
		"zone": 8,
		"count": 16,
	},
}

const TERRAIN_NAMES: PackedStringArray = [
	"Grass", "Dirt", "Stone", "Sand",
	"Water", "Deep Water", "Shore", "Ice",
	"Forest", "Desert",
]

const UPDATE_NEIGHBORS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var tile_size: int = 32

# Compatibilidad con código que pueda inspeccionar la capa principal.
var tilemap_dual: TileMapDual

# Una TileMapDual por bioma evita que TileMapDual mezcle atlas de biomas
# distintos al resolver una transición. Dentro de cada capa, cada zona
# tiene su propio terrain id.
var _layers_by_bioma: Dictionary = {}
var _base_tiles: Dictionary = {}
var _next_source_id_by_bioma: Dictionary = {}

var _dirty_cells_by_bioma: Dictionary = {}
var _dirty_lookup_by_bioma: Dictionary = {}

# Celda -> bioma visual que la posee actualmente.
var _cell_bioma: Dictionary = {}
var _cell_zone: Dictionary = {}
var _variation_layers_by_bioma: Dictionary = {}
var _variation_tilesets_by_bioma: Dictionary = {}


func configurar(nuevo_tile_size: int) -> void:
	tile_size = nuevo_tile_size


func _crear_capa_bioma(bioma_nombre: String) -> TileMapDual:
	var clave := _normalizar_bioma(bioma_nombre)

	if _layers_by_bioma.has(clave):
		return _layers_by_bioma[clave] as TileMapDual

	var layer := TileMapDual.new()
	layer.name = (
		"TerrainDual_"
		+ ("General" if clave.is_empty() else clave)
	)
	layer.godot_4_3_compatibility = false
	layer.z_as_relative = false
	layer.z_index = -4096
	layer.rendering_quadrant_size = 32
	layer.tile_set = _crear_tileset()



	add_child(layer)

	_layers_by_bioma[clave] = layer
	_next_source_id_by_bioma[clave] = 0
	_dirty_cells_by_bioma[clave] = []
	_dirty_lookup_by_bioma[clave] = {}
	_variation_layers_by_bioma[clave] = _crear_capa_variaciones(clave)

	if tilemap_dual == null:
		tilemap_dual = layer

	return layer


func _crear_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(
		0,
		TileSet.TERRAIN_MODE_MATCH_CORNERS
	)

	# Terrain 0 representa el vacío / cualquier cosa.
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "<any>")

	# Cada zona tiene un terrain id estable dentro de la capa del bioma.
	for terrain_id in range(1, ZONE_TEXTURES.size() + 1):
		tile_set.add_terrain(0)
		tile_set.set_terrain_name(
			0,
			terrain_id,
			TERRAIN_NAMES[terrain_id - 1]
		)

	return tile_set


func set_zone(
	cell: Vector2i,
	zone: int,
	bioma_nombre: String = "",
	bioma_textura: String = ""
) -> void:
	if zone < 0 or zone >= ZONE_TEXTURES.size():
		return

	var clave := _normalizar_bioma(bioma_nombre)
	var layer := _crear_capa_bioma(clave)
	var tile_key := clave + "::" + str(zone)

	if not _base_tiles.has(tile_key):
		_crear_base_tile(
			clave,
			tile_key,
			zone,
			layer,
			bioma_textura
		)

	if not _base_tiles.has(tile_key):
		return

	# Si la celda antes pertenecía a otro bioma visual, se elimina de
	# aquella TileMapDual. Esto evita restos al regenerar/reemplazar chunks.
	var bioma_anterior := str(_cell_bioma.get(cell, ""))
	if bioma_anterior != clave:
		if _layers_by_bioma.has(bioma_anterior):
			var capa_anterior := (
				_layers_by_bioma[bioma_anterior] as TileMapDual
			)
			capa_anterior.erase_cell(cell)
			_marcar_dirty(
				bioma_anterior,
				cell
			)

			for offset: Vector2i in UPDATE_NEIGHBORS:
				_marcar_dirty(
					bioma_anterior,
					cell + offset
				)

		_cell_bioma[cell] = clave

	_cell_zone[cell] = zone
	_actualizar_variacion(cell)
	for offset: Vector2i in UPDATE_NEIGHBORS:
		if offset != Vector2i.ZERO:
			_actualizar_variacion(cell + offset)

	var data: Dictionary = _base_tiles[tile_key]

	# Una celda sólo puede existir una vez en su capa.
	layer.erase_cell(cell)
	layer.set_cell(
		cell,
		int(data["source_id"]),
		data["atlas"]
	)

	_marcar_dirty(clave, cell)

	for offset: Vector2i in UPDATE_NEIGHBORS:
		_marcar_dirty(
			clave,
			cell + offset
		)


func _crear_capa_variaciones(bioma_nombre: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "TerrainVariaciones_" + ("General" if bioma_nombre.is_empty() else bioma_nombre)
	layer.z_as_relative = false
	layer.z_index = -4096
	layer.y_sort_enabled = false
	layer.tile_set = _crear_tileset_variaciones(bioma_nombre)
	add_child(layer)
	return layer


func _crear_tileset_variaciones(bioma_nombre: String) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)

	var config: Dictionary = VARIACIONES_POR_BIOMA.get(bioma_nombre, {})
	var texture := load(str(config.get("texture", ""))) as Texture2D
	if not _textura_valida(texture):
		return tile_set

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(tile_size, tile_size)

	for y in range(4):
		for x in range(4):
			atlas.create_tile(Vector2i(x, y))

	tile_set.add_source(atlas, 0)
	_variation_tilesets_by_bioma[bioma_nombre] = tile_set
	return tile_set


func _actualizar_variacion(cell: Vector2i) -> void:
	if not _cell_bioma.has(cell):
		return

	var bioma := str(_cell_bioma[cell])
	if not _variation_layers_by_bioma.has(bioma):
		return

	var layer := _variation_layers_by_bioma[bioma] as TileMapLayer
	if layer == null:
		return

	var config: Dictionary = VARIACIONES_POR_BIOMA.get(bioma, {})
	if config.is_empty():
		layer.erase_cell(cell)
		return

	var zone := int(config.get("zone", -1))

	# Las variaciones sólo aparecen en interiores completos del bioma.
	# Si una celda toca otro bioma/zona, TileMapDual conserva la transición.
	if _cell_zone.get(cell, -1) != zone or not _es_interior_bioma(cell, zone):
		layer.erase_cell(cell)
		return

	var indice := _indice_variacion(cell)
	var atlas := Vector2i(indice % 4, indice / 4)
	layer.set_cell(cell, 0, atlas, 0)


func _es_interior_bioma(cell: Vector2i, zone: int) -> bool:
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var vecino: Vector2i = cell + offset
		if _cell_bioma.get(vecino, "") != _cell_bioma.get(cell, ""):
			return false
		if _cell_zone.get(vecino, -1) != zone:
			return false
	return true


func _indice_variacion(cell: Vector2i) -> int:
	# Selección determinista: el mismo mundo produce siempre la misma textura.
	var valor := absi(cell.x * 928371 + cell.y * 689287)
	valor = (valor ^ (valor >> 13)) * 1274126177
	var bioma := str(_cell_bioma.get(cell, ""))
	var config: Dictionary = VARIACIONES_POR_BIOMA.get(bioma, {})
	var count := int(config.get("count", 1))
	return absi(valor) % count


func _crear_base_tile(
	bioma_nombre: String,
	tile_key: String,
	zone: int,
	layer: TileMapDual,
	bioma_textura: String = ""
) -> void:
	var texture := _cargar_textura_bioma(
		bioma_nombre,
		zone,
		bioma_textura
	)

	if texture == null:
		push_error(
			"WorldTerrainVisual: no se pudo cargar textura para bioma "
			+ bioma_nombre
			+ " y zona "
			+ str(zone)
		)
		return

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(
		tile_size,
		tile_size
	)

	for sequence_pos in TILE_SEQUENCE:
		atlas.create_tile(sequence_pos)

	var source_id := int(
		_next_source_id_by_bioma.get(
			bioma_nombre,
			0
		)
	)

	layer.tile_set.add_source(
		atlas,
		source_id
	)

	# Los terrain ids son locales a esta capa. Como cada bioma tiene
	# su propio TileMapDual, un atlas de Bosque jamás puede ser elegido
	# por una celda de Pradera, Marino, etc.
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
				terrain_id
				if (bits & 1) != 0
				else 0
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

	_base_tiles[tile_key] = {
		"source_id": source_id,
		"atlas": TILE_SEQUENCE[15],
	}

	_next_source_id_by_bioma[bioma_nombre] = source_id + 1


func _cargar_textura_bioma(
	bioma_nombre: String,
	zone: int,
	bioma_textura: String = ""
) -> Texture2D:
	# La zona manda sobre el aspecto visual. Supabase determina si
	# la celda es grass, dirt, stone, etc.; cada zona tiene su atlas.
	var textura_zona := _cargar_textura_zone(zone)
	if textura_zona != null:
		return textura_zona

	# Compatibilidad para datos antiguos o zonas sin atlas propio.
	if not bioma_textura.strip_edges().is_empty():
		var textura_canonica := load(
			bioma_textura.strip_edges()
		) as Texture2D

		if _textura_valida(textura_canonica):
			return textura_canonica

	var nombre := bioma_nombre.strip_edges()

	if not nombre.is_empty():
		var bioma_path := (
			"res://assets/tilesets/"
			+ nombre
			+ ".png"
		)

		var bioma_texture := (
			load(bioma_path) as Texture2D
		)

		if _textura_valida(bioma_texture):
			return bioma_texture

	return null

func _cargar_textura_zone(zone: int) -> Texture2D:
	var path := str(
		ZONE_TEXTURES.get(
			zone,
			"res://assets/tilesets/world_tileset.png"
		)
	)

	var texture := load(path) as Texture2D

	if _textura_valida(texture):
		return texture

	var fallback := load(
		"res://assets/tilesets/Pradera.png"
	) as Texture2D

	if _textura_valida(fallback):
		return fallback

	return null


func _textura_valida(texture: Texture2D) -> bool:
	return (
		texture != null
		and texture.get_width() >= tile_size * 4
		and texture.get_height() >= tile_size * 4
	)


func _normalizar_bioma(nombre: String) -> String:
	return nombre.strip_edges()


func _marcar_dirty(
	bioma_nombre: String,
	cell: Vector2i
) -> void:
	var clave := _normalizar_bioma(bioma_nombre)

	if not _dirty_cells_by_bioma.has(clave):
		_dirty_cells_by_bioma[clave] = []

	if not _dirty_lookup_by_bioma.has(clave):
		_dirty_lookup_by_bioma[clave] = {}

	var lookup: Dictionary = _dirty_lookup_by_bioma[clave]
	if lookup.has(cell):
		return

	lookup[cell] = true

	var cells: Array = _dirty_cells_by_bioma[clave]
	cells.append(cell)
	_dirty_cells_by_bioma[clave] = cells


func flush() -> void:
	for clave_variant in _layers_by_bioma.keys():
		var clave := str(clave_variant)

		var cells_variant: Variant = (
			_dirty_cells_by_bioma.get(
				clave,
				[]
			)
		)

		if not cells_variant is Array:
			continue

		var layer := _layers_by_bioma[clave] as TileMapDual
		if layer == null:
			continue

		# TileMapDual expone draw_cell() como API pública. Usamos esa API
		# en lugar de llamar a _update_cells(), cuya firma tipada interna
		# rechaza Arrays que llegan desde Dictionary como Variant.
		for cell_variant in cells_variant:
			if not cell_variant is Vector2i:
				continue

			var cell := cell_variant as Vector2i
			if layer.get_cell_source_id(cell) == -1:
				continue

			var terreno := layer.get_cell(cell)
			layer.draw_cell(cell, terreno)

		_dirty_cells_by_bioma[clave] = []
		_dirty_lookup_by_bioma[clave] = {}


func clear_chunk(
	chunk_coord: Vector2i,
	chunk_size_tiles: int
) -> void:
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

			var bioma := str(
				_cell_bioma.get(cell, "")
			)

			if not _layers_by_bioma.has(bioma):
				continue

			var layer := (
				_layers_by_bioma[bioma] as TileMapDual
			)

			if layer == null:
				continue

			layer.erase_cell(cell)
			_cell_bioma.erase(cell)

			_marcar_dirty(
				bioma,
				cell
			)

			for offset: Vector2i in UPDATE_NEIGHBORS:
				_marcar_dirty(
					bioma,
					cell + offset
				)
			_actualizar_variacion_pradera(cell)
			for offset: Vector2i in UPDATE_NEIGHBORS:
				if offset != Vector2i.ZERO:
					_actualizar_variacion_pradera(cell + offset)

	if not _dirty_cells_by_bioma.is_empty():
		flush()
