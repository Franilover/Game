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

# Identificadores técnicos de presentación. La semántica de la zona
# proviene de Supabase; estos nombres sólo etiquetan el TileSet generado.
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

const CARDINAL_NEIGHBORS: Array[Vector2i] = [
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
var _dirty_cursor_by_zone: Dictionary = {}
var _dirty_zone_cursor: int = 0
var _dirty_variations: Dictionary = {}

# Celda -> bioma visual que la posee actualmente.
var _cell_bioma: Dictionary = {}
var _cell_zone: Dictionary = {}
var _cell_layer_key: Dictionary = {}
var _variation_layers_by_bioma: Dictionary = {}
var _variation_tilesets_by_bioma: Dictionary = {}
var _batch_active: bool = false
var _clear_task: Dictionary = {}

var _profiler_set_zone_ms: float = 0.0
var _profiler_set_zone_calls: int = 0
var _profiler_set_zone_max_ms: float = 0.0
var _profiler_set_cell_ms: float = 0.0
var _profiler_variation_ms: float = 0.0
var _profiler_dirty_ms: float = 0.0
var _profiler_flush_convert_ms: float = 0.0
var _profiler_flush_update_ms: float = 0.0
var _profiler_flush_variation_ms: float = 0.0
var _profiler_flush_update_calls: int = 0
var _profiler_flush_regions: int = 0
var _profiler_flush_cells: int = 0
var _profiler_flush_variation_cells: int = 0
var _profiler_flush_max_ms: float = 0.0
var _profiler_flush_update_max_ms: float = 0.0
var _profiler_variation_max_ms: float = 0.0
var _profiler_set_cell_calls: int = 0

func iniciar_profiler() -> void:
	_profiler_set_zone_ms = 0.0
	_profiler_set_zone_calls = 0
	_profiler_set_zone_max_ms = 0.0
	_profiler_set_cell_ms = 0.0
	_profiler_variation_ms = 0.0
	_profiler_dirty_ms = 0.0
	_profiler_flush_convert_ms = 0.0
	_profiler_flush_update_ms = 0.0
	_profiler_flush_variation_ms = 0.0
	_profiler_flush_update_calls = 0
	_profiler_flush_regions = 0
	_profiler_flush_cells = 0
	_profiler_flush_variation_cells = 0
	_profiler_flush_max_ms = 0.0
	_profiler_flush_update_max_ms = 0.0
	_profiler_variation_max_ms = 0.0
	_profiler_set_cell_calls = 0

func obtener_profiler() -> Dictionary:
	return {
		"set_zone_ms": _profiler_set_zone_ms,
		"set_zone_calls": _profiler_set_zone_calls,
		"set_zone_max_ms": _profiler_set_zone_max_ms,
		"set_cell_ms": _profiler_set_cell_ms,
		"variation_ms": _profiler_variation_ms,
		"dirty_ms": _profiler_dirty_ms,
		"flush_convert_ms": _profiler_flush_convert_ms,
		"flush_update_ms": _profiler_flush_update_ms,
		"flush_variation_ms": _profiler_flush_variation_ms,
		"flush_update_calls": _profiler_flush_update_calls,
		"flush_regions": _profiler_flush_regions,
		"flush_cells": _profiler_flush_cells,
		"flush_variation_cells": _profiler_flush_variation_cells,
		"flush_max_ms": _profiler_flush_max_ms,
		"flush_update_max_ms": _profiler_flush_update_max_ms,
		"variation_max_ms": _profiler_variation_max_ms,
		"set_cell_calls": _profiler_set_cell_calls,
	}


func iniciar_clear_chunk(chunk_coord: Vector2i, chunk_size_tiles: int) -> void:
	if not _clear_task.is_empty():
		return
	_clear_task = {
		"coord": chunk_coord,
		"size": chunk_size_tiles,
		"cursor": 0,
		"total": chunk_size_tiles * chunk_size_tiles,
		"stage": 0,
	}


func tiene_clear_chunk_activo() -> bool:
	return not _clear_task.is_empty()


func procesar_clear_chunk(cells: int) -> bool:
	if _clear_task.is_empty():
		return true

	var coord: Vector2i = _clear_task["coord"]
	var size: int = int(_clear_task["size"])
	var cursor: int = int(_clear_task["cursor"])
	var total: int = int(_clear_task["total"])
	var stage: int = int(_clear_task.get("stage", 0))

	if stage == 0:
		var limite: int = mini(cursor + maxi(cells, 1), total)
		while cursor < limite:
			var local_y: int = cursor / size
			var local_x: int = cursor % size
			var cell := Vector2i(
				coord.x * size + local_x,
				coord.y * size + local_y
			)
			_limpiar_celda_chunk(cell, false)
			cursor += 1

		_clear_task["cursor"] = cursor
		if cursor < total:
			# Limpiar primero; la composición se procesa gradualmente en
			# la siguiente fase para no convertir el unload en un flush gigante.
			return false
		_marcar_borde_chunk_dirty(coord, size)
		_clear_task["stage"] = 1

	# Fase 1: resolver únicamente una parte de las regiones dirty generadas
	# por erase_cell(). Nunca llamar flush() aquí: flush() vacía toda la cola.
	var flush_cells: int = mini(maxi(cells, 1), 32)
	var terminado_flush := procesar_flush(flush_cells)
	if not terminado_flush:
		return false

	_clear_task.clear()
	return true


func _limpiar_celda_chunk(cell: Vector2i, marcar_dirty: bool = true) -> void:
	var layer_key := str(_cell_layer_key.get(cell, ""))
	if not _layers_by_zone.has(layer_key):
		return
	var layer := _layers_by_zone[layer_key] as TileMapDual
	if layer == null:
		return
	layer.erase_cell(cell)

	var bioma_celda := str(_cell_bioma.get(cell, ""))
	if _variation_layers_by_bioma.has(bioma_celda):
		var capa_variacion := _variation_layers_by_bioma[bioma_celda] as TileMapLayer
		if capa_variacion != null and capa_variacion.get_cell_source_id(cell) != -1:
			capa_variacion.erase_cell(cell)

	_cell_bioma.erase(cell)
	_cell_zone.erase(cell)
	_cell_layer_key.erase(cell)
	if marcar_dirty:
		_marcar_dirty(layer_key, cell)
		for offset: Vector2i in UPDATE_NEIGHBORS:
			_marcar_dirty(layer_key, cell + offset)
		_marcar_variaciones_dirty(cell, "")


func _marcar_borde_chunk_dirty(coord: Vector2i, size: int) -> void:
	# Al descargar un bloque completo, las celdas interiores ya no pueden
	# afectar a ninguna celda que siga visible. Sólo el borde del chunk y
	# sus vecinos externos necesitan recomposición.
	var x0 := coord.x * size
	var y0 := coord.y * size
	var x1 := x0 + size - 1
	var y1 := y0 + size - 1
	for x in range(x0, x1 + 1):
		_marcar_dirty_si_existe(Vector2i(x, y0))
		_marcar_dirty_si_existe(Vector2i(x, y1))
		_marcar_dirty_vecinos_externos(Vector2i(x, y0))
		_marcar_dirty_vecinos_externos(Vector2i(x, y1))
	for y in range(y0 + 1, y1):
		_marcar_dirty_si_existe(Vector2i(x0, y))
		_marcar_dirty_si_existe(Vector2i(x1, y))
		_marcar_dirty_vecinos_externos(Vector2i(x0, y))
		_marcar_dirty_vecinos_externos(Vector2i(x1, y))

func _marcar_dirty_si_existe(cell: Vector2i) -> void:
	var layer_key := str(_cell_layer_key.get(cell, ""))
	if _layers_by_zone.has(layer_key) and _cell_layer_key.has(cell):
		_marcar_dirty(layer_key, cell)

func _marcar_dirty_vecinos_externos(cell: Vector2i) -> void:
	for offset: Vector2i in UPDATE_NEIGHBORS:
		if offset == Vector2i.ZERO:
			continue
		var vecino := cell + offset
		if _cell_layer_key.has(vecino):
			var layer_key := str(_cell_layer_key[vecino])
			_marcar_dirty(layer_key, vecino)
			_marcar_variaciones_dirty(vecino, str(_cell_bioma.get(vecino, "")))


func _marcar_frontera_por_celda_nueva(cell: Vector2i) -> void:
	# Una celda nueva puede cambiar la regla de TileMapDual de un vecino
	# aunque ese vecino pertenezca a otra capa/zona. Por eso la invalidación
	# debe seguir la capa de cada vecino, no sólo la capa de la celda nueva.
	var layer_key := str(_cell_layer_key.get(cell, ""))
	if _layers_by_zone.has(layer_key):
		_marcar_dirty(layer_key, cell)
		_marcar_variaciones_dirty(cell, str(_cell_bioma.get(cell, "")))

	for offset: Vector2i in UPDATE_NEIGHBORS:
		if offset == Vector2i.ZERO:
			continue
		var vecino := cell + offset
		if not _cell_layer_key.has(vecino):
			continue
		var vecino_layer_key := str(_cell_layer_key[vecino])
		_marcar_dirty(vecino_layer_key, vecino)
		_marcar_variaciones_dirty(vecino, str(_cell_bioma.get(vecino, "")))


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
	_dirty_cursor_by_zone[clave] = 0

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
	# Durante el pintado de un chunk no invalidamos vecinos celda por celda.
	# El lote ya conoce exactamente qué bloque acaba de cambiar y hará una
	# única invalidación conjunta al terminar. Esto evita ~5 operaciones de
	# Dictionary por cada una de las 1.024 celdas.
	if not _batch_active:
		var variation_start_usec := Time.get_ticks_usec()
		_marcar_variaciones_dirty(cell, clave)
		var variation_ms := float(Time.get_ticks_usec() - variation_start_usec) / 1000.0
		_profiler_variation_ms += variation_ms
		_profiler_variation_max_ms = maxf(_profiler_variation_max_ms, variation_ms)

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

	# Una sola pasada cubre la celda nueva y la frontera de las capas
	# vecinas. La función deduplica mediante lookup, evitando dos recorridos
	# sobre UPDATE_NEIGHBORS por cada celda del chunk.
	if not _batch_active:
		var dirty_start_usec := Time.get_ticks_usec()
		_marcar_frontera_por_celda_nueva(cell)
		_profiler_dirty_ms += float(Time.get_ticks_usec() - dirty_start_usec) / 1000.0

	var set_zone_ms := float(Time.get_ticks_usec() - profiler_start_usec) / 1000.0
	_profiler_set_zone_ms += set_zone_ms
	_profiler_set_zone_max_ms = maxf(_profiler_set_zone_max_ms, set_zone_ms)
	_profiler_set_zone_calls += 1


func _crear_capa_variaciones(bioma_nombre: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "TerrainVariaciones_" + ("General" if bioma_nombre.is_empty() else bioma_nombre)
	layer.z_as_relative = false
	# Las variantes son una capa decorativa del suelo: deben quedar por
	# encima de los terrenos base para que se vean, pero muy por debajo
	# de las entidades/jugador.
	# Debe quedar sobre Pradera (zona 0 = -4087) y sobre cualquier otra base.
	layer.z_index = -4086
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
	# Reconstruir el renderer sólo cuando el atlas y todos sus peering bits
	# ya están completos. Así Display/TerrainDual lee una configuración final.
	layer.reconstruir_renderer_dual()


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


func _marcar_variaciones_dirty(
	cell: Vector2i,
	bioma_actual: String
) -> void:
	# Cuando la celda actual tiene variaciones, sus cuatro vecinos también
	# deben revisarse porque pueden pasar a ser interiores o bordes.
	# En ese caso no hace falta consultar cinco veces el diccionario: sabemos
	# que la celda central es decorativa y añadimos directamente el vecindario.
	if bioma_actual == "Pradera" or bioma_actual == "Bosque":
		for offset: Vector2i in UPDATE_NEIGHBORS:
			_dirty_variations[cell + offset] = true
		return

	# Para los biomas sin atlas decorativo, sólo interesa comprobar los cuatro
	# vecinos: la celda central no puede tener una variación propia.
	for offset: Vector2i in UPDATE_NEIGHBORS:
		if offset == Vector2i.ZERO:
			continue
		var candidata := cell + offset
		var bioma_candidato := str(_cell_bioma.get(candidata, ""))
		if VARIACIONES_POR_BIOMA.has(bioma_candidato):
			_dirty_variations[candidata] = true


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


func _registrar_debug() -> void:
	var debug: Node = get_node_or_null("/root/GarliaDebug")
	if debug == null or not debug.has_method("registrar_proveedor"):
		return
	debug.registrar_proveedor("world_terrain_visual", "WorldTerrainVisual", self, "Composición TileMapDual, variaciones, dirty queue y flush visual.")


func obtener_diagnostico() -> Dictionary:
	var dirty_cells: int = 0
	var dirty_zones: int = 0
	for clave_variant in _dirty_cells_by_zone.keys():
		var cells_variant: Variant = _dirty_cells_by_zone[clave_variant]
		if cells_variant is Array and not (cells_variant as Array).is_empty():
			dirty_zones += 1
			dirty_cells += (cells_variant as Array).size()

	var capas: Array[String] = []
	for clave_variant in _layers_by_zone.keys():
		var terrain_layer: TileMapDual = _layers_by_zone[clave_variant] as TileMapDual
		if terrain_layer != null:
			capas.append("%s:%d" % [str(clave_variant), terrain_layer.get_used_cells().size()])

	var display: Dictionary = {}
	for clave_variant in _layers_by_zone.keys():
		var terrain_layer: TileMapDual = _layers_by_zone[clave_variant] as TileMapDual
		if terrain_layer == null:
			continue
		var display_node: Node = terrain_layer.get_node_or_null("Display")
		var display_layers: Array[String] = []
		var display_cells: int = 0
		var renderer_diag: Dictionary = {}
		if terrain_layer.has_method("obtener_diagnostico"):
			renderer_diag = terrain_layer.call("obtener_diagnostico") as Dictionary
		if display_node != null:
			for child in display_node.get_children():
				if child is TileMapLayer:
					var display_layer: TileMapLayer = child as TileMapLayer
					display_layers.append("%s:%d" % [display_layer.name, display_layer.get_used_cells().size()])
					display_cells += display_layer.get_used_cells().size()
		display[str(clave_variant)] = {"dual_cells": terrain_layer.get_used_cells().size(), "display_exists": display_node != null, "display_layers": display_layers, "display_cells": display_cells, "renderer": renderer_diag}

	var variaciones: Dictionary = {}
	for bioma_variant in _variation_layers_by_bioma.keys():
		var variation_layer: TileMapLayer = _variation_layers_by_bioma[bioma_variant] as TileMapLayer
		if variation_layer != null:
			variaciones[str(bioma_variant)] = variation_layer.get_used_cells().size()

	return {
		"configurado": not _layers_by_zone.is_empty(),
		"tile_size": tile_size,
		"capas": capas,
		"base_tiles": _base_tiles.size(),
		"celdas_registradas": _cell_layer_key.size(),
		"biomas_registrados": _cell_bioma.size(),
		"dirty_zonas": dirty_zones,
		"dirty_celdas": dirty_cells,
		"dirty_cursor_zona": _dirty_zone_cursor,
		"dirty_variaciones": _dirty_variations.size(),
		"flush_pendiente": tiene_flush_pendiente(),
		"display": display,
		"clear_chunk_activo": not _clear_task.is_empty(),
		"profiler": obtener_profiler()
	}


func _ready() -> void:
	_registrar_debug()


func _tiene_flush_base_pendiente() -> bool:
	for clave_variant in _layers_by_zone.keys():
		var clave := str(clave_variant)
		var cells_variant: Variant = _dirty_cells_by_zone.get(clave, [])
		if cells_variant is Array and not (cells_variant as Array).is_empty():
			return true
	return false


func procesar_variaciones(cells: int = 4) -> bool:
	# Trabajo visual secundario: nunca debe retener el chunk base.
	if _batch_active:
		return false
	if _dirty_variations.is_empty():
		return true

	var limite: int = mini(maxi(cells, 1), _dirty_variations.size())
	var variaciones: Array = _dirty_variations.keys()
	var inicio_usec := Time.get_ticks_usec()

	for i in range(limite):
		var cell_variant: Variant = variaciones[i]
		if cell_variant is Vector2i:
			_actualizar_variacion(cell_variant as Vector2i)
			_dirty_variations.erase(cell_variant)
		_profiler_flush_variation_cells += 1

	_profiler_flush_variation_ms += float(
		Time.get_ticks_usec() - inicio_usec
	) / 1000.0

	return _dirty_variations.is_empty()


func marcar_region_generada_dirty(
	chunk_coord: Vector2i,
	orden: Array,
	inicio: int,
	fin: int
) -> void:
	# Marca únicamente las celdas que ya fueron pintadas en este lote.
	# Los vecinos que ya existen también se invalidan para mantener las
	# transiciones correctas mientras el chunk se completa progresivamente.
	var total := mini(fin, orden.size())
	var primero := maxi(inicio, 0)
	for indice_cursor in range(primero, total):
		var indice := int(orden[indice_cursor])
		var local_y := indice / 32
		var local_x := indice % 32
		var cell := Vector2i(
			chunk_coord.x * 32 + local_x,
			chunk_coord.y * 32 + local_y
		)
		var layer_key := str(_cell_layer_key.get(cell, ""))
		if _layers_by_zone.has(layer_key):
			_marcar_dirty(layer_key, cell)
			for offset: Vector2i in UPDATE_NEIGHBORS:
				var vecino := cell + offset
				if _cell_layer_key.has(vecino):
					_marcar_dirty(
						str(_cell_layer_key[vecino]),
						vecino
					)
		var bioma := str(_cell_bioma.get(cell, ""))
			if bioma == "Pradera" or bioma == "Bosque":
				_marcar_variaciones_dirty(cell, bioma)


func marcar_borde_chunk_generado_dirty(
	chunk_coord: Vector2i,
	chunk_size_tiles: int
) -> void:
	# Sólo el borde externo necesita invalidar celdas de chunks vecinos.
	var x0 := chunk_coord.x * chunk_size_tiles
	var y0 := chunk_coord.y * chunk_size_tiles
	var x1 := x0 + chunk_size_tiles - 1
	var y1 := y0 + chunk_size_tiles - 1
	for x in range(x0, x1 + 1):
		_marcar_dirty_vecinos_externos(Vector2i(x, y0))
		_marcar_dirty_vecinos_externos(Vector2i(x, y1))
	for y in range(y0 + 1, y1):
		_marcar_dirty_vecinos_externos(Vector2i(x0, y))
		_marcar_dirty_vecinos_externos(Vector2i(x1, y))


func marcar_chunk_generado_dirty(chunk_coord: Vector2i, chunk_size_tiles: int) -> void:
	# Durante la generación no invalidamos 5 vecinos por cada celda.
	# Todas las celdas del chunk ya fueron pintadas, así que basta con una
	# invalidación conjunta del bloque y su borde. Esto reduce miles de
	# operaciones Dictionary por chunk.
	var x0 := chunk_coord.x * chunk_size_tiles
	var y0 := chunk_coord.y * chunk_size_tiles
	var x1 := x0 + chunk_size_tiles - 1
	var y1 := y0 + chunk_size_tiles - 1

	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var cell := Vector2i(x, y)
			var layer_key := str(_cell_layer_key.get(cell, ""))
			if _layers_by_zone.has(layer_key):
				_marcar_dirty(layer_key, cell)
			var bioma := str(_cell_bioma.get(cell, ""))
			if bioma == "Pradera" or bioma == "Bosque":
				_marcar_variaciones_dirty(cell, bioma)

	# Sólo el borde necesita invalidar vecinos externos del chunk.
	for x in range(x0, x1 + 1):
		_marcar_dirty_vecinos_externos(Vector2i(x, y0))
		_marcar_dirty_vecinos_externos(Vector2i(x, y1))
	for y in range(y0 + 1, y1):
		_marcar_dirty_vecinos_externos(Vector2i(x0, y))
		_marcar_dirty_vecinos_externos(Vector2i(x1, y))


func tiene_flush_pendiente() -> bool:
	for clave_variant in _layers_by_zone.keys():
		var clave := str(clave_variant)
		var cells_variant: Variant = _dirty_cells_by_zone.get(clave, [])
		if cells_variant is Array and not cells_variant.is_empty():
			return true
	return not _dirty_variations.is_empty()


func procesar_flush(cells: int) -> bool:
	if _batch_active:
		return false

	var presupuesto: int = maxi(cells, 1)

	# Round-robin entre zonas: una capa con una cola grande no puede
	# monopolizar todos los lotes y dejar otra frontera pendiente durante
	# varios frames. El cursor se conserva entre llamadas.
	var zonas: Array = _layers_by_zone.keys()
	var cantidad_zonas: int = zonas.size()
	if cantidad_zonas == 0:
		return not tiene_flush_pendiente()

	var zonas_revisadas := 0
	while zonas_revisadas < cantidad_zonas and presupuesto > 0:
		var indice_zona: int = (_dirty_zone_cursor + zonas_revisadas) % cantidad_zonas
		var clave_variant: Variant = zonas[indice_zona]
		var clave := str(clave_variant)
		zonas_revisadas += 1
		var cells_variant: Variant = _dirty_cells_by_zone.get(clave, [])
		if not cells_variant is Array or cells_variant.is_empty():
			continue

		var layer := _layers_by_zone[clave] as TileMapDual
		if layer == null:
			_dirty_cells_by_zone[clave] = []
			_dirty_lookup_by_zone[clave] = {}
			continue

		var take: int = mini(presupuesto, cells_variant.size())
		var dirty: Array[Vector2i] = []
		var convert_start_usec := Time.get_ticks_usec()

		# Consumir desde el final: las celdas del chunk que acaba de generarse
		# fueron añadidas más recientemente y deben llegar al renderer antes
		# que trabajo visual antiguo de chunks lejanos. Esto hace que el chunk
		# que el jugador está viendo aparezca primero sin ordenar toda la cola.
		var lookup: Dictionary = _dirty_lookup_by_zone[clave]
		while not cells_variant.is_empty() and dirty.size() < take:
			var cell_variant: Variant = cells_variant.pop_back()
			if cell_variant is Vector2i and lookup.has(cell_variant):
				dirty.append(cell_variant as Vector2i)
				lookup.erase(cell_variant)

		_dirty_cursor_by_zone[clave] = 0

		_profiler_flush_convert_ms += float(
			Time.get_ticks_usec() - convert_start_usec
		) / 1000.0

		if not dirty.is_empty():
			var update_start_usec := Time.get_ticks_usec()
			layer._update_cells(dirty, false)
			var update_ms := float(
				Time.get_ticks_usec() - update_start_usec
			) / 1000.0
			_profiler_flush_update_ms += update_ms
			_profiler_flush_update_max_ms = maxf(
				_profiler_flush_update_max_ms,
				update_ms
			)
			_profiler_flush_update_calls += 1
			_profiler_flush_regions += 1
			_profiler_flush_cells += dirty.size()

		if cells_variant.is_empty():
			_dirty_cells_by_zone[clave] = []
			_dirty_lookup_by_zone[clave] = {}
			_dirty_cursor_by_zone[clave] = 0
		presupuesto -= dirty.size()
		_dirty_zone_cursor = (indice_zona + 1) % cantidad_zonas

	# Las variaciones NO bloquean la finalización del chunk.
	# TileMapLayer.set_cell() para decoración puede ser mucho más caro que
	# la composición base; dejarlo dentro de la barrera de FLUSH hacía que
	# un chunk quedara "generando" aunque sus tiles base ya fueran visibles.
	# Las variaciones se procesan aparte y de forma diferida por el streamer.
	return not _tiene_flush_base_pendiente()


func flush() -> void:
	var flush_total_start_usec := Time.get_ticks_usec()
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
			var update_ms := float(Time.get_ticks_usec() - update_start_usec) / 1000.0
			_profiler_flush_update_ms += update_ms
			_profiler_flush_update_max_ms = maxf(_profiler_flush_update_max_ms, update_ms)
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
		var variation_flush_ms := float(Time.get_ticks_usec() - variation_start_usec) / 1000.0
		_profiler_flush_variation_ms += variation_flush_ms
		_profiler_variation_max_ms = maxf(_profiler_variation_max_ms, variation_flush_ms)


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
			_marcar_variaciones_dirty(cell, "")

	if not _dirty_cells_by_zone.is_empty():
		flush()
