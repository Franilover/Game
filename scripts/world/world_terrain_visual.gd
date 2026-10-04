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

# Cada zona usa su propio atlas y su propia capa de composición.
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

# Una capa por zona permite que la misma zona continúe entre biomas.
# Así un cambio de bioma no se interpreta como un borde de terreno.
var _layers_by_zone: Dictionary = {}
var _base_tiles: Dictionary = {}
var _next_source_id_by_zone: Dictionary = {}

var _dirty_cells_by_zone: Dictionary = {}
var _dirty_lookup_by_zone: Dictionary = {}
var _dirty_variations: Dictionary = {}

# Celda -> bioma visual que la posee actualmente.
var _cell_bioma: Dictionary = {}
var _cell_zone: Dictionary = {}
var _cell_layer_key: Dictionary = {}
var _variation_layers_by_bioma: Dictionary = {}
var _variation_tilesets_by_bioma: Dictionary = {}
var _batch_active: bool = false

var _profiler_set_zone_ms: float = 0.0
var _profiler_set_zone_calls: int = 0
var _profiler_set_cell_ms: float = 0.0
var _profiler_variation_ms: float = 0.0
var _profiler_dirty_ms: float = 0.0
var _profiler_flush_convert_ms: float = 0.0
var _profiler_flush_update_ms: float = 0.0
var _profiler_flush_variation_ms: float = 0.0
var _profiler_flush_update_calls: int = 0
var _profiler_flush_cells: int = 0
var _profiler_flush_variation_cells: int = 0
var _profiler_set_cell_calls: int = 0

func iniciar_profiler() -> void:
	_profiler_set_zone_ms = 0.0
	_profiler_set_zone_calls = 0
	_profiler_set_cell_ms = 0.0
	_profiler_variation_ms = 0.0
	_profiler_dirty_ms = 0.0
	_profiler_flush_convert_ms = 0.0
	_profiler_flush_update_ms = 0.0
	_profiler_flush_variation_ms = 0.0
	_profiler_flush_update_calls = 0
	_profiler_flush_cells = 0
	_profiler_flush_variation_cells = 0
	_profiler_set_cell_calls = 0

func obtener_profiler() -> Dictionary:
	return {
		"set_zone_ms": _profiler_set_zone_ms,
		"set_zone_calls": _profiler_set_zone_calls,
		"set_cell_ms": _profiler_set_cell_ms,
		"variation_ms": _profiler_variation_ms,
		"dirty_ms": _profiler_dirty_ms,
		"flush_convert_ms": _profiler_flush_convert_ms,
		"flush_update_ms": _profiler_flush_update_ms,
		"flush_variation_ms": _profiler_flush_variation_ms,
		"flush_update_calls": _profiler_flush_update_calls,
		"flush_cells": _profiler_flush_cells,
		"flush_variation_cells": _profiler_flush_variation_cells,
		"set_cell_calls": _profiler_set_cell_calls,
	}


func configurar(nuevo_tile_size: int) -> void:
	tile_size = nuevo_tile_size

	# Las capas TileMapDual necesitan ejecutar _ready() antes de recibir
	# celdas. Se crean todas por adelantado porque el primer chunk se pinta
	# justo después de que WorldGenerator les da un frame de inicialización.
	# Si se crean durante el pintado del chunk, sus Display internos todavía
	# pueden no existir y sólo las capas de detalles terminan visibles.
	for zone in range(ZONE_TEXTURES.size()):
		_crear_capa_terreno(zone)


func comenzar_lote() -> void:
	if _batch_active:
		return
	_batch_active = true
	for layer_variant in _layers_by_zone.values():
		var layer := layer_variant as TileMapDual
		if layer != null:
			layer.set_block_signals(true)


func terminar_lote() -> void:
	if not _batch_active:
		return
	for layer_variant in _layers_by_zone.values():
		var layer := layer_variant as TileMapDual
		if layer != null:
			layer.set_block_signals(false)
	_batch_active = false


func _crear_capa_terreno(zone: int) -> TileMapDual:
	var clave := str(zone)

	if _layers_by_zone.has(clave):
		return _layers_by_zone[clave] as TileMapDual

	var layer := TileMapDual.new()
	layer.name = "TerrainDual_Zone_" + clave
	layer.godot_4_3_compatibility = false
	layer.z_as_relative = false
	layer.z_index = -4096 + (ZONE_TEXTURES.size() - zone)
	layer.rendering_quadrant_size = 128
	layer.tile_set = _crear_tileset()

	add_child(layer)

	_layers_by_zone[clave] = layer
	_next_source_id_by_zone[clave] = 0
	_dirty_cells_by_zone[clave] = []
	_dirty_lookup_by_zone[clave] = {}

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

	# Cada capa contiene un único terreno activo; el ID 1 representa esa zona.
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
	var profiler_start_usec := Time.get_ticks_usec()
	if zone < 0 or zone >= ZONE_TEXTURES.size():
		return

	var clave := _normalizar_bioma(bioma_nombre)
	var layer_key := str(zone)
	# configurar() crea todas las capas antes de pintar. Evitar volver a
	# resolver/validar la misma capa por cada una de las 1.024 celdas.
	var layer := _layers_by_zone[layer_key] as TileMapDual

	# Crear la capa de variaciones una sola vez para los biomas que tienen atlas.
	# Las celdas interiores se actualizan después de registrar su bioma y zona.
	if VARIACIONES_POR_BIOMA.has(clave) and not _variation_layers_by_bioma.has(clave):
		_variation_layers_by_bioma[clave] = _crear_capa_variaciones(clave)

	var tile_key := layer_key

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

	# Si la celda cambia de zona, se elimina de la capa anterior para evitar
	# restos visuales al regenerar o reemplazar chunks.
	var layer_anterior := str(_cell_layer_key.get(cell, ""))
	if layer_anterior != layer_key:
		if _layers_by_zone.has(layer_anterior):
			var capa_anterior := (
				_layers_by_zone[layer_anterior] as TileMapDual
			)
			capa_anterior.erase_cell(cell)
			for offset: Vector2i in UPDATE_NEIGHBORS:
				_marcar_dirty(
					layer_anterior,
					cell + offset
				)

		_cell_layer_key[cell] = layer_key

	# Si cambió el bioma pero no la zona, retirar su variante anterior.
	var bioma_anterior := str(_cell_bioma.get(cell, ""))
	if bioma_anterior != clave and _variation_layers_by_bioma.has(bioma_anterior):
		var capa_variacion_anterior := (
			_variation_layers_by_bioma[bioma_anterior] as TileMapLayer
		)
		if capa_variacion_anterior != null:
			capa_variacion_anterior.erase_cell(cell)

	# El bioma puede cambiar sin que cambie la zona visual.
	_cell_bioma[cell] = clave
	_cell_zone[cell] = zone
	var variation_start_usec := Time.get_ticks_usec()
	_marcar_variaciones_dirty(cell)
	_profiler_variation_ms += float(Time.get_ticks_usec() - variation_start_usec) / 1000.0

	var data: Dictionary = _base_tiles[tile_key]

	# Evitar erase_cell + set_cell cuando la celda ya pertenece a esta capa.
	if layer_anterior != layer_key:
		var set_cell_start_usec := Time.get_ticks_usec()
		layer.set_cell(
			cell,
			int(data["source_id"]),
			data["atlas"]
		)
		_profiler_set_cell_ms += float(Time.get_ticks_usec() - set_cell_start_usec) / 1000.0
		_profiler_set_cell_calls += 1

	var dirty_start_usec := Time.get_ticks_usec()
	# UPDATE_NEIGHBORS ya incluye ZERO; no marcar la celda central dos veces.
	for offset: Vector2i in UPDATE_NEIGHBORS:
		_marcar_dirty(
			layer_key,
			cell + offset
		)
	_profiler_dirty_ms += float(Time.get_ticks_usec() - dirty_start_usec) / 1000.0
	_profiler_set_zone_ms += float(Time.get_ticks_usec() - profiler_start_usec) / 1000.0
	_profiler_set_zone_calls += 1


func _crear_capa_variaciones(bioma_nombre: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "TerrainVariaciones_" + ("General" if bioma_nombre.is_empty() else bioma_nombre)
	layer.z_as_relative = false
	# Las variantes son una capa decorativa del suelo: deben quedar por
	# encima de los terrenos base para que se vean, pero muy por debajo
	# de las entidades/jugador.
	# Debe quedar sobre Pradera (zona 0 = -4087) y sobre cualquier otra base.\n\tlayer.z_index = -4086
	layer.y_sort_enabled = false
	layer.rendering_quadrant_size = 128
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
		_borrar_variacion_si_existe(layer, cell)
		return

	var zone := int(config.get("zone", -1))

	# Las variaciones sólo aparecen en interiores completos del bioma.
	# Si una celda toca otro bioma/zona, TileMapDual conserva la transición.
	if _cell_zone.get(cell, -1) != zone or not _es_interior_bioma(cell, zone):
		_borrar_variacion_si_existe(layer, cell)
		return

	var indice := _indice_variacion(cell)
	var atlas := Vector2i(indice % 4, indice / 4)
	layer.set_cell(cell, 0, atlas, 0)


func _es_interior_bioma(cell: Vector2i, zone: int) -> bool:
	for offset: Vector2i in UPDATE_NEIGHBORS:
		if offset == Vector2i.ZERO:
			continue
		var vecino: Vector2i = cell + offset
		if _cell_bioma.get(vecino, "") != _cell_bioma.get(cell, ""):
			return false
		if _cell_zone.get(vecino, -1) != zone:
			return false
	return true


func _borrar_variacion_si_existe(layer: TileMapLayer, cell: Vector2i) -> void:
	# erase_cell() también se invocaba en miles de celdas que nunca tuvieron
	# decoración. Consultar primero evita trabajo innecesario del TileMapLayer.
	if layer.get_cell_source_id(cell) != -1:
		layer.erase_cell(cell)


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
		_next_source_id_by_zone.get(
			tile_key,
			0
		)
	)

	layer.tile_set.add_source(
		atlas,
		source_id
	)

	# Cada capa contiene una sola zona visual, así que el terreno activo
	# siempre es el terrain 1 y 0 representa el exterior/vacío.
	var terrain_id := 1

	for index in range(TILE_SEQUENCE.size()):
		var data := atlas.get_tile_data(
			TILE_SEQUENCE[index],
			0
		)

		data.terrain_set = 0
		data.terrain = terrain_id

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


	_base_tiles[tile_key] = {
		"source_id": source_id,
		"atlas": TILE_SEQUENCE[15],
	}

	_next_source_id_by_zone[tile_key] = source_id + 1


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


func _marcar_variaciones_dirty(cell: Vector2i) -> void:
	for offset: Vector2i in UPDATE_NEIGHBORS:
		_dirty_variations[cell + offset] = true


func _marcar_dirty(
	layer_key: String,
	cell: Vector2i
) -> void:
	# Las estructuras se crean para todas las zonas al configurar las capas.
	# No comprobamos ni reasignamos el Array en cada llamada caliente.
	var lookup: Dictionary = _dirty_lookup_by_zone[layer_key]
	if lookup.has(cell):
		return

	lookup[cell] = true

	var cells: Array = _dirty_cells_by_zone[layer_key]
	cells.append(cell)


func flush() -> void:
	if _batch_active:
		return

	for clave_variant in _layers_by_zone.keys():
		var clave := str(clave_variant)

		var cells_variant: Variant = _dirty_cells_by_zone.get(clave, [])
		if not cells_variant is Array:
			continue

		var layer := _layers_by_zone[clave] as TileMapDual
		if layer == null:
			continue

		var convert_start_usec := Time.get_ticks_usec()
		var dirty: Array[Vector2i] = []
		for cell_variant in cells_variant:
			if cell_variant is Vector2i:
				dirty.append(cell_variant as Vector2i)
		_profiler_flush_convert_ms += float(Time.get_ticks_usec() - convert_start_usec) / 1000.0

		if not dirty.is_empty():
			var update_start_usec := Time.get_ticks_usec()
			layer._update_cells(dirty, false)
			_profiler_flush_update_ms += float(Time.get_ticks_usec() - update_start_usec) / 1000.0
			_profiler_flush_update_calls += 1
			_profiler_flush_cells += dirty.size()

		_dirty_cells_by_zone[clave] = []
		_dirty_lookup_by_zone[clave] = {}

	if not _dirty_variations.is_empty():
		var variation_start_usec := Time.get_ticks_usec()
		var variaciones := _dirty_variations.keys()
		_profiler_flush_variation_cells += variaciones.size()
		_dirty_variations.clear()
		for cell_variant in variaciones:
			if cell_variant is Vector2i:
				_actualizar_variacion(cell_variant as Vector2i)
		_profiler_flush_variation_ms += float(Time.get_ticks_usec() - variation_start_usec) / 1000.0


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

			var layer_key := str(
				_cell_layer_key.get(cell, "")
			)

			if not _layers_by_zone.has(layer_key):
				continue

			var layer := (
				_layers_by_zone[layer_key] as TileMapDual
			)

			if layer == null:
				continue

			layer.erase_cell(cell)

			# Las variantes no forman parte de TileMapDual; hay que retirarlas
			# explícitamente antes de borrar la información de la celda.
			var bioma_celda := str(_cell_bioma.get(cell, ""))
			if _variation_layers_by_bioma.has(bioma_celda):
				var capa_variacion := (
					_variation_layers_by_bioma[bioma_celda] as TileMapLayer
				)
				if capa_variacion != null:
					capa_variacion.erase_cell(cell)

			_cell_bioma.erase(cell)
			_cell_zone.erase(cell)
			_cell_layer_key.erase(cell)

			_marcar_dirty(
				layer_key,
				cell
			)

			for offset: Vector2i in UPDATE_NEIGHBORS:
				_marcar_dirty(
					layer_key,
					cell + offset
				)
			_marcar_variaciones_dirty(cell)

	if not _dirty_cells_by_zone.is_empty():
		flush()
