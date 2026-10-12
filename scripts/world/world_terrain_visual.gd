extends Node2D
class_name WorldTerrainVisual

# Prueba de rendimiento: desactiva temporalmente las capas decorativas de variaciones.
# El terreno base y sus transiciones TileMapDual siguen activos.
const ENABLE_VARIATIONS: bool = false

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

# Cada zona usa un atlas y un ID de terreno estables. Todas las zonas
# comparten un único TileMapDual para resolver transiciones entre ellas.
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
var _shared_terrain_layer: TileMapDual
# Relleno opaco bajo el Dual Grid. Si una regla de esquina no encuentra
# variante exacta, esta capa evita que el fondo gris se vea por transparencias.
var _terrain_underlay: TileMapLayer
var _base_tiles: Dictionary = {}
var _next_source_id_by_zone: Dictionary = {}

var _dirty_cells_by_zone: Dictionary = {}
var _dirty_lookup_by_zone: Dictionary = {}
var _dirty_cursor_by_zone: Dictionary = {}
var _dirty_zone_cursor: int = 0
var _dirty_variations: Dictionary = {}
var _dirty_variation_queue: Array = []
var _dirty_variation_cursor: int = 0

# Celda -> bioma visual que la posee actualmente.
var _cell_bioma: Dictionary = {}
var _cell_zone: Dictionary = {}
var _cell_layer_key: Dictionary = {}
var _variation_layers_by_bioma: Dictionary = {}
var _variation_tilesets_by_bioma: Dictionary = {}
var _batch_active: bool = false
# TileMapDual captura las reglas del TileSet en TerrainDual. Al añadir un
# atlas en runtime, la señal del TileSet sólo marca al watcher como pendiente;
# en juego el watcher no procesa esa señal por frame. Hay que reconstruir las
# reglas una vez que termina el lote que registró atlas/terrenos nuevos.
var _terrain_rules_dirty: bool = false
var _clear_task: Dictionary = {}
var _flush_last_zone: String = ""
var _flush_last_cells: int = 0
var _flush_last_ms: float = 0.0
var _flush_last_convert_ms: float = 0.0
var _flush_last_update_ms: float = 0.0
var _flush_last_frame_cells: int = 0

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

func obtener_estado_flush() -> Dictionary:
	var pendientes_por_zona: Dictionary = {}
	var pendientes_total: int = 0
	for clave_variant in _dirty_cells_by_zone.keys():
		var clave := str(clave_variant)
		var lista_variant: Variant = _dirty_cells_by_zone.get(clave, [])
		var cantidad: int = lista_variant.size() if lista_variant is Array else 0
		pendientes_por_zona[clave] = cantidad
		pendientes_total += cantidad
	return {
		"pendiente": pendientes_total > 0,
		"pendientes_total": pendientes_total,
		"pendientes_por_zona": pendientes_por_zona,
		"zonas": _layers_by_zone.size(),
		"zona_cursor": _dirty_zone_cursor,
		"ultima_zona": _flush_last_zone,
		"ultima_cantidad": _flush_last_cells,
		"ultimo_ms": _flush_last_ms,
		"ultimo_convert_ms": _flush_last_convert_ms,
		"ultimo_update_ms": _flush_last_update_ms,
	}

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
	# El borrado masivo no debe disparar recomposición por cada erase_cell().
	# Mantenemos las actualizaciones diferidas durante toda la fase de limpieza
	# y sólo reactivamos el renderer antes de procesar el dirty resultante.
	comenzar_lote()


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
		terminar_lote()
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
	if is_instance_valid(_terrain_underlay):
		_terrain_underlay.erase_cell(cell)

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

	# Registrar todos los atlas antes de pintar la primera celda. TileMapDual
	# reconstruye su TerrainDual al detectar cambios en el TileSet; añadir
	# atlas de forma perezosa durante el streaming fuerza reconstrucciones
	# completas repetidas del Display y su caché de celdas.
	_preparar_atlas_zonas()


func _preparar_atlas_zonas() -> void:
	if not is_instance_valid(_shared_terrain_layer):
		return

	for zone in range(ZONE_TEXTURES.size()):
		var tile_key := str(zone)
		if _base_tiles.has(tile_key):
			continue
		_crear_base_tile(
			"",
			tile_key,
			0,
			zone,
			_shared_terrain_layer,
			""
		)

	# En la inicialización normal, TileMapDual todavía no ha terminado _ready();
	# su _changed() inicial leerá todos los atlas ya registrados. No necesitamos
	# volver a reconstruir el Display al terminar el primer lote de celdas.
	_terrain_rules_dirty = false


func comenzar_lote() -> void:
	if _batch_active:
		return
	_batch_active = true
	for layer_variant in _layers_by_zone.values():
		var layer := layer_variant as TileMapDual
		if layer != null:
			layer.set_block_signals(true)
			layer.set_deferred_updates_blocked(true)


func terminar_lote() -> void:
	if not _batch_active:
		_reconstruir_reglas_terreno_si_necesario()
		return
	for layer_variant in _layers_by_zone.values():
		var layer := layer_variant as TileMapDual
		if layer != null:
			layer.set_deferred_updates_blocked(false)
			layer.set_block_signals(false)
	_batch_active = false
	_reconstruir_reglas_terreno_si_necesario()


func _reconstruir_reglas_terreno_si_necesario() -> void:
	if not _terrain_rules_dirty:
		return
	if not is_instance_valid(_shared_terrain_layer):
		return
	# Este método relee todos los atlas y sus peering bits, reconstruye el
	# TerrainDual y repinta el Display desde las celdas reales ya registradas.
	_shared_terrain_layer.reconstruir_renderer_dual()
	_terrain_rules_dirty = false


func _crear_capa_terreno(zone: int) -> TileMapDual:
	var clave := str(zone)

	# Los terrenos necesitan estar en la misma capa para que TileMapDual pueda
	# consultar el terrain de los vecinos y escoger bordes/esquinas entre zonas.
	# Los mapas por zona anteriores aislaban precisamente esa información.
	if is_instance_valid(_shared_terrain_layer):
		_layers_by_zone[clave] = _shared_terrain_layer
		if not _next_source_id_by_zone.has(clave):
			_next_source_id_by_zone[clave] = 0
		if not _dirty_cells_by_zone.has(clave):
			_dirty_cells_by_zone[clave] = []
		if not _dirty_lookup_by_zone.has(clave):
			_dirty_lookup_by_zone[clave] = {}
		if not _dirty_cursor_by_zone.has(clave):
			_dirty_cursor_by_zone[clave] = 0
		return _shared_terrain_layer

	var tile_set := _crear_tileset()

	# El relleno usa el mismo atlas, pero dibuja una baldosa completa por celda.
	# Debe quedar detrás del Dual Grid para cubrir huecos transparentes grises.
	var underlay := TileMapLayer.new()
	underlay.name = "TerrainUnderlay"
	underlay.z_as_relative = false
	underlay.z_index = -4097
	underlay.rendering_quadrant_size = 512
	underlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	underlay.tile_set = tile_set
	add_child(underlay)
	_terrain_underlay = underlay

	var layer := TileMapDual.new()
	layer.name = "TerrainDual_AllZones"
	layer.godot_4_3_compatibility = false
	layer.z_as_relative = false
	layer.z_index = -4096
	layer.rendering_quadrant_size = 512
	layer.tile_set = tile_set

	add_child(layer)

	_shared_terrain_layer = layer
	_layers_by_zone[clave] = layer
	_next_source_id_by_zone[clave] = 0
	_dirty_cells_by_zone[clave] = []
	_dirty_lookup_by_zone[clave] = {}
	_dirty_cursor_by_zone[clave] = 0
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
	bioma_index: int,
	bioma_nombre: String = "",
	bioma_textura: String = ""
) -> void:
	if zone < 0 or zone >= ZONE_TEXTURES.size():
		return

	var clave := _normalizar_bioma(bioma_nombre)
	if bioma_index < 0 or bioma_index >= ZONE_TEXTURES.size():
		push_warning("WorldTerrainVisual: bioma_index inválido: " + str(bioma_index))
		return
	var layer_key := str(zone)
	var bioma_key := str(bioma_index)
	# configurar() crea todas las capas antes de pintar. Evitar volver a
	# resolver/validar la misma capa por cada una de las 1.024 celdas.
	var layer := _layers_by_zone[layer_key] as TileMapDual

	# Crear la capa de variaciones una sola vez para los biomas que tienen atlas.
	# Las celdas interiores se actualizan después de registrar su bioma y zona.
	if ENABLE_VARIATIONS and VARIACIONES_POR_BIOMA.has(clave) and not _variation_layers_by_bioma.has(clave):
		_variation_layers_by_bioma[clave] = _crear_capa_variaciones(clave)

	# La textura y el terreno dependen de la zona, no del índice de bioma.
	# El bioma se conserva en _cell_bioma para datos/ecología y variaciones.
	var tile_key := str(zone)

	if not _base_tiles.has(tile_key):
		_crear_base_tile(
			clave,
			tile_key,
			bioma_index,
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
	# Las variaciones se difieren hasta que el chunk esté completo. Durante
	# el streaming no tiene sentido recalcular interior/borde cinco veces por
	# celda: los vecinos todavía pueden no existir.

	var data: Dictionary = _base_tiles[tile_key]

	# No basta con comprobar la capa: todos los biomas comparten TileMapDual.
	# Si cambia el bioma dentro de la misma zona, también hay que cambiar el
	# source_id y la baldosa del relleno, o se conservan píxeles del bioma viejo.
	var source_id := int(data["source_id"])
	var atlas_coords: Vector2i = data["atlas"]
	var debe_actualizar_tile := (
		layer.get_cell_source_id(cell) != source_id
		or layer.get_cell_atlas_coords(cell) != atlas_coords
	)
	if debe_actualizar_tile:
		var set_cell_start_usec := Time.get_ticks_usec()
		layer.set_cell(cell, source_id, atlas_coords)
		_profiler_set_cell_ms += float(Time.get_ticks_usec() - set_cell_start_usec) / 1000.0
		_profiler_set_cell_calls += 1

	# La baldosa de patrón completo es un respaldo opaco. Las partes
	# transparentes de las esquinas de transición muestran el bioma de la celda.
	if is_instance_valid(_terrain_underlay):
		if (
			_terrain_underlay.get_cell_source_id(cell) != source_id
			or _terrain_underlay.get_cell_atlas_coords(cell) != TILE_SEQUENCE[15]
		):
			_terrain_underlay.set_cell(cell, source_id, TILE_SEQUENCE[15])

	# Una sola pasada cubre la celda nueva y la frontera de las capas
	# vecinas. La función deduplica mediante lookup, evitando dos recorridos
	# sobre UPDATE_NEIGHBORS por cada celda del chunk.
	# La invalidación se hace en marcar_region_generada_dirty() en modo lote.
	# Fuera de un lote, mantener la semántica anterior para cambios puntuales.
	if not _batch_active:
		_marcar_frontera_por_celda_nueva(cell)

	_profiler_set_zone_calls += 1
	if not _batch_active:
		_reconstruir_reglas_terreno_si_necesario()


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
	layer.rendering_quadrant_size = 512
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
	bioma_index: int,
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

	# ZONE_TEXTURES define un único material visual por zona. Crear un atlas
	# y un terreno por cada pareja bioma/zona duplicaba las mismas texturas y
	# añadía nuevas reglas al TileSet durante el juego.
	var source_id := zone

	layer.tile_set.add_source(
		atlas,
		source_id
	)

	# Los diez IDs ya están declarados en _crear_tileset() y corresponden
	# directamente a las diez zonas. No añadir terrenos en tiempo de juego.
	var terrain_id := zone + 1

	for index in range(TILE_SEQUENCE.size()):
		var data := atlas.get_tile_data(
			TILE_SEQUENCE[index],
			0
		)

		data.terrain_set = 0

		# Las 15 variantes forman un único atlas de terreno.
		# Todas deben conservar el terrain_id para que TileMapDual
		# pueda resolver y seleccionar correctamente las variantes
		# de transición mediante sus peering bits.
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

	# El addon no vuelve a leer los peering bits de atlas agregados en runtime
	# sólo porque cambie TileSet.changed. Marcamos las reglas para reconstruir
	# el Dual Grid al cerrar este lote, no una vez por cada celda.
	_terrain_rules_dirty = true

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
	# La zona determina el material del suelo. Dentro de una Pradera,
	# por ejemplo, las celdas de zona Tierra deben usar Tierra.png y no
	# repetir la textura de Pradera en todo el bioma.
	var textura_zona := _cargar_textura_zone(zone)
	if _textura_valida(textura_zona):
		return textura_zona

	# Si falta el atlas de la zona, usar la textura canónica del bioma
	# como fallback; nunca sustituir una textura de zona válida por ella.
	if not bioma_textura.strip_edges().is_empty():
		var textura_canonica := load(
			bioma_textura.strip_edges()
		) as Texture2D
		if _textura_valida(textura_canonica):
			return textura_canonica

	var nombre := bioma_nombre.strip_edges()
	if not nombre.is_empty():
		var bioma_path := "res://assets/tilesets/" + nombre + ".png"
		var bioma_texture := load(bioma_path) as Texture2D
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
	if not ENABLE_VARIATIONS:
		return
	# Cuando la celda actual tiene variaciones, sus cuatro vecinos también
	# deben revisarse porque pueden pasar a ser interiores o bordes.
	# En ese caso no hace falta consultar cinco veces el diccionario: sabemos
	# que la celda central es decorativa y añadimos directamente el vecindario.
	if bioma_actual == "Pradera" or bioma_actual == "Bosque":
		for offset: Vector2i in UPDATE_NEIGHBORS:
			_marcar_variacion_dirty(cell + offset)
		return

	# Para los biomas sin atlas decorativo, sólo interesa comprobar los cuatro
	# vecinos: la celda central no puede tener una variación propia.
	for offset: Vector2i in UPDATE_NEIGHBORS:
		if offset == Vector2i.ZERO:
			continue
		var candidata := cell + offset
		var bioma_candidato := str(_cell_bioma.get(candidata, ""))
		if VARIACIONES_POR_BIOMA.has(bioma_candidato):
			_marcar_variacion_dirty(candidata)


func _marcar_variacion_dirty(cell: Vector2i) -> void:
	if not ENABLE_VARIATIONS:
		return
	if _dirty_variations.has(cell):
		return
	_dirty_variations[cell] = true
	_dirty_variation_queue.append(cell)


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

	var clear_diag: Dictionary = {}
	if not _clear_task.is_empty():
		clear_diag = {
			"coord": _clear_task.get("coord", Vector2i.ZERO),
			"cursor": int(_clear_task.get("cursor", 0)),
			"total": int(_clear_task.get("total", 0)),
			"stage": int(_clear_task.get("stage", 0)),
			"progreso": (
				float(int(_clear_task.get("cursor", 0)))
				/ float(maxi(int(_clear_task.get("total", 1)), 1))
			)
		}

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
		"dirty_variaciones_queue": _dirty_variation_queue.size(),
		"dirty_variaciones_cursor": _dirty_variation_cursor,
		"flush_pendiente": tiene_flush_pendiente(),
		"display": display,
		"clear_chunk_activo": not _clear_task.is_empty(),
		"clear_chunk": clear_diag,
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
	if not ENABLE_VARIATIONS:
		return true
	if _batch_active:
		return false
	if _dirty_variations.is_empty():
		return true

	var limite: int = mini(maxi(cells, 1), _dirty_variations.size())
	var inicio_usec := Time.get_ticks_usec()
	var procesadas := 0

	while (
		_dirty_variation_cursor < _dirty_variation_queue.size()
		and procesadas < limite
	):
		var cell_variant: Variant = (
			_dirty_variation_queue[_dirty_variation_cursor]
		)
		_dirty_variation_cursor += 1

		if not _dirty_variations.has(cell_variant):
			continue

		if cell_variant is Vector2i:
			_actualizar_variacion(cell_variant as Vector2i)
			_dirty_variations.erase(cell_variant)
			procesadas += 1
			_profiler_flush_variation_cells += 1

	if _dirty_variation_cursor >= _dirty_variation_queue.size():
		_dirty_variation_queue.clear()
		_dirty_variation_cursor = 0
	elif _dirty_variation_cursor >= 256 and _dirty_variation_cursor * 2 >= _dirty_variation_queue.size():
		var cola_nueva: Array = []
		for pendiente_variant in _dirty_variations.keys():
			cola_nueva.append(pendiente_variant)
		_dirty_variation_queue = cola_nueva
		_dirty_variation_cursor = 0

	_profiler_flush_variation_ms += float(
		Time.get_ticks_usec() - inicio_usec
	) / 1000.0

	return _dirty_variations.is_empty()


func marcar_region_generada_dirty(
	chunk_coord: Vector2i,
	orden: Array,
	chunk_size_tiles: int,
	inicio: int,
	fin: int
) -> void:
	# Cada lote sólo registra las celdas que acaba de pintar. Los vecinos
	# internos pertenecen al mismo chunk y los externos se invalidan una sola
	# vez al finalizarlo. Esto evita hasta cinco recorridos de Dictionary por
	# cada celda generada.
	var total := mini(fin, orden.size())
	var primero := maxi(inicio, 0)
	for indice_cursor in range(primero, total):
		var indice := int(orden[indice_cursor])
		var local_y := indice / chunk_size_tiles
		var local_x := indice % chunk_size_tiles
		var cell := Vector2i(
			chunk_coord.x * chunk_size_tiles + local_x,
			chunk_coord.y * chunk_size_tiles + local_y
		)
		var layer_key := str(_cell_layer_key.get(cell, ""))
		if _layers_by_zone.has(layer_key):
			_marcar_dirty(layer_key, cell)

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
	# Las celdas base ya fueron registradas por lote. Aquí sólo hacemos el
	# trabajo que no puede resolverse hasta que todos los vecinos existan:
	# variaciones decorativas e invalidación del borde externo.
	var x0 := chunk_coord.x * chunk_size_tiles
	var y0 := chunk_coord.y * chunk_size_tiles
	var x1 := x0 + chunk_size_tiles - 1
	var y1 := y0 + chunk_size_tiles - 1

	if ENABLE_VARIATIONS:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var cell := Vector2i(x, y)
				var bioma := str(_cell_bioma.get(cell, ""))
				if bioma == "Pradera" or bioma == "Bosque":
					_marcar_variacion_dirty(cell)

	marcar_borde_chunk_generado_dirty(
		chunk_coord,
		chunk_size_tiles
	)

func tiene_flush_pendiente() -> bool:
	for clave_variant in _layers_by_zone.keys():
		var clave := str(clave_variant)
		var cells_variant: Variant = _dirty_cells_by_zone.get(clave, [])
		if cells_variant is Array and not cells_variant.is_empty():
			return true
	return ENABLE_VARIATIONS and not _dirty_variations.is_empty()


func procesar_flush(cells: int) -> bool:
	if _batch_active:
		return false

	var presupuesto: int = maxi(cells, 1)

	# Time slicing real: una llamada a procesar_flush() ejecuta como máximo
	# UNA actualización de TileMapDual. Antes el round-robin podía atravesar
	# varias zonas dentro de la misma llamada, convirtiendo un presupuesto de
	# celdas en varios costes independientes de DisplayLayer.
	#
	# Mantener una sola zona por llamada permite que WorldTerrain/RenderManager
	# decidan cuándo volver a ceder el control al siguiente frame. Las colas de
	# otras zonas permanecen intactas y el cursor garantiza equidad entre ellas.
	var zonas: Array = _layers_by_zone.keys()
	var cantidad_zonas: int = zonas.size()
	if cantidad_zonas == 0:
		return not tiene_flush_pendiente()

	var indice_zona: int = _dirty_zone_cursor % cantidad_zonas
	var clave_variant: Variant = zonas[indice_zona]
	var clave := str(clave_variant)
	var cells_variant: Variant = _dirty_cells_by_zone.get(clave, [])

	# Buscar la siguiente zona con trabajo, pero sin procesar dos zonas en
	# este mismo frame/call. El cursor sólo avanza cuando encontramos trabajo.
	if not cells_variant is Array or cells_variant.is_empty():
		var encontrada := false
		for desplazamiento in range(1, cantidad_zonas):
			var candidato_indice := (indice_zona + desplazamiento) % cantidad_zonas
			var candidato_clave := str(zonas[candidato_indice])
			var candidato_cells: Variant = _dirty_cells_by_zone.get(candidato_clave, [])
			if candidato_cells is Array and not candidato_cells.is_empty():
				indice_zona = candidato_indice
				clave = candidato_clave
				cells_variant = candidato_cells
				encontrada = true
				break
		if not encontrada:
			return not tiene_flush_pendiente()

	var layer := _layers_by_zone[clave] as TileMapDual
	if layer == null:
		# Reutilizar ambas estructuras evita asignar un Array y un Dictionary
		# nuevos cada vez que termina un flush.
		cells_variant.clear()
		_dirty_lookup_by_zone[clave].clear()
		_dirty_zone_cursor = (indice_zona + 1) % cantidad_zonas
		return not tiene_flush_pendiente()

	var take: int = mini(presupuesto, cells_variant.size())
	var dirty: Array[Vector2i] = []
	var convert_start_usec := Time.get_ticks_usec()

	# Consumir desde el final: las celdas del chunk que acaba de generarse
	# fueron añadidas más recientemente y deben llegar al renderer antes
	# que trabajo visual antiguo de chunks lejanos.
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
		_flush_last_zone = clave
		_flush_last_cells = dirty.size()
		_flush_last_convert_ms = float(Time.get_ticks_usec() - convert_start_usec) / 1000.0
		_flush_last_update_ms = update_ms
		_flush_last_ms = _flush_last_convert_ms + update_ms
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

		# _marcar_dirty() sólo inserta Vector2i. No hace falta reconstruir
		# otra Array antes de cada actualización del Dual Grid.
		var dirty: Array[Vector2i] = cells_variant as Array[Vector2i]
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

	if ENABLE_VARIATIONS and not _dirty_variations.is_empty():
		var variation_start_usec := Time.get_ticks_usec()
		var variaciones := _dirty_variations.keys()
		_profiler_flush_variation_cells += variaciones.size()
		_dirty_variations.clear()
		_dirty_variation_queue.clear()
		_dirty_variation_cursor = 0
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
			if is_instance_valid(_terrain_underlay):
				_terrain_underlay.erase_cell(cell)

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
