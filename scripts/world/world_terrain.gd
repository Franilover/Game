extends Node2D
class_name WorldTerrain


const CHUNK_PADDING: int = 1


enum Zone {
	GRASS,
	DIRT,
	STONE,
	SAND,
	WATER,
	DEEP_WATER,
	SHORE,
	ICE,
	FOREST,
	DESERT
}


var map_seed: int = 0
var tile_size: int = 32
var chunk_size_tiles: int = 32


var visual: WorldTerrainVisual
var areas: WorldTerrainAreas


var _world_data: WorldDataService = null
var _render_manager: Node = null
var _biomas: Array = []
var _ecosistemas: Array = []

var _ecosistema_indices: Dictionary = {}

var _loaded_chunks: Dictionary = {}

var _generation_task: Dictionary = {}
var _unload_task: Dictionary = {}
var _pintado_desde_flush: int = 0
@export var visual_flush_cells: int = 512

var _ultimo_chunk_generado: Vector2i = Vector2i.ZERO

# Perfilador interno del pipeline de generación.
var _profiler_data_ms: float = 0.0
var _profiler_paint_ms: float = 0.0
var _profiler_flush_ms: float = 0.0
var _profiler_data_calls: int = 0
var _profiler_paint_calls: int = 0
var _profiler_flushes: int = 0
var _profiler_biome_ms: float = 0.0
var _profiler_ecosystem_ms: float = 0.0
var _profiler_zone_ms: float = 0.0


func configurar(
	nuevo_seed: int,
	nuevo_tile_size: int,
	nuevo_chunk_size: int,
	nuevo_world_data: WorldDataService = null
) -> void:
	# WorldTerrain es una capa puramente visual de suelo. Nunca debe
	# quedar por encima de entidades aunque el padre tenga otro z_index.
	z_as_relative = false
	z_index = -4096

	_world_data = nuevo_world_data
	if _world_data == null:
		push_error("WorldTerrain: WorldDataService inválido.")
		return

	map_seed = nuevo_seed
	tile_size = nuevo_tile_size
	chunk_size_tiles = nuevo_chunk_size

	areas = WorldTerrainAreas.new()
	areas.configurar(map_seed)

	_crear_capas()
	visual.configurar(tile_size)
func configurar_render_manager(render_manager: Node) -> void:
	_render_manager = render_manager


func cargar_datos_mundo() -> void:
	_biomas.clear()
	_ecosistemas.clear()
	_ecosistema_indices.clear()

	if _world_data == null:
		push_error("WorldTerrain: WorldDataService no configurado.")
		return

	_biomas = _world_data.obtener_biomas()

	for i in range(_biomas.size()):
		var bioma_variant: Variant = _biomas[i]

		if not bioma_variant is Dictionary:
			continue

		var bioma: Dictionary = bioma_variant

		var ecosistemas_variant: Variant = (
			bioma.get("ecosistemas", [])
		)

		if not ecosistemas_variant is Array:
			continue

		var ecosistemas: Array = ecosistemas_variant

		for j in range(ecosistemas.size()):
			var ecosistema_variant: Variant = (
				ecosistemas[j]
			)

			if not ecosistema_variant is Dictionary:
				continue

			var ecosistema: Dictionary = ecosistema_variant

			var ecosistema_id: String = str(
				ecosistema.get("id", "")
			)

			if ecosistema_id.is_empty():
				continue

			if _ecosistema_indices.has(
				ecosistema_id
			):
				continue

			_ecosistema_indices[ecosistema_id] = (
				_ecosistemas.size()
			)

			_ecosistemas.append(
				ecosistema
			)

	var sin_bioma: Array = (
		_world_data.obtener_ecosistemas_sin_bioma()
	)

	for i in range(sin_bioma.size()):
		var ecosistema_variant: Variant = (
			sin_bioma[i]
		)

		if not ecosistema_variant is Dictionary:
			continue

		var ecosistema: Dictionary = ecosistema_variant

		var ecosistema_id: String = str(
			ecosistema.get("id", "")
		)

		if ecosistema_id.is_empty():
			continue

		if _ecosistema_indices.has(
			ecosistema_id
		):
			continue

		_ecosistema_indices[ecosistema_id] = (
			_ecosistemas.size()
		)

		_ecosistemas.append(
			ecosistema
		)

	areas.cargar_datos(
		_biomas,
		_ecosistemas,
		_ecosistema_indices
	)

	print(
		"WorldTerrain: biomas = ",
		_biomas.size()
	)

	print(
		"WorldTerrain: ecosistemas = ",
		_ecosistemas.size()
	)


func _crear_capas() -> void:
	visual = get_node_or_null("WorldTerrainVisual") as WorldTerrainVisual
	if visual == null:
		push_error("WorldTerrain: falta el nodo WorldTerrainVisual en la escena.")
func iniciar_generacion_chunk(
	chunk_coord: Vector2i
) -> void:
	if _loaded_chunks.has(chunk_coord):
		return

	_profiler_data_ms = 0.0
	_profiler_paint_ms = 0.0
	_profiler_flush_ms = 0.0
	_profiler_data_calls = 0
	_profiler_paint_calls = 0
	_profiler_flushes = 0
	_profiler_biome_ms = 0.0
	_profiler_ecosystem_ms = 0.0
	_profiler_zone_ms = 0.0
	if visual != null:
		visual.iniciar_profiler()

	if not _generation_task.is_empty():
		return

	var padded_size: int = (
		chunk_size_tiles
		+ CHUNK_PADDING * 2
	)

	var zonas_base: Array = []
	var zonas: Array = []
	var biomas: Array = []
	var ecosistemas: Array = []

	for y in range(padded_size):
		var fila_zonas_base: Array = []
		var fila_zonas: Array = []
		var fila_biomas: Array = []
		var fila_ecosistemas: Array = []

		for x in range(padded_size):
			fila_zonas_base.append(Zone.GRASS)
			fila_zonas.append(Zone.GRASS)
			fila_biomas.append(-1)
			fila_ecosistemas.append(-1)

		zonas_base.append(fila_zonas_base)
		zonas.append(fila_zonas)
		biomas.append(fila_biomas)
		ecosistemas.append(fila_ecosistemas)

	_pintado_desde_flush = 0

	_generation_task = {
		"coord": chunk_coord,
		"stage": 0,
		"cursor": 0,
		"zonas_base": zonas_base,
		"zonas": zonas,
		"biomas": biomas,
		"ecosistemas": ecosistemas
	}


func procesar_generacion(
	cells: int
) -> bool:
	if _generation_task.is_empty():
		return false

	var stage: int = int(
		_generation_task["stage"]
	)

	if stage == 0:
		return _procesar_datos_chunk(
			cells
		)

	if stage == 1:
		return _procesar_pintado_chunk(
			cells
		)

	return _procesar_flush_chunk(
		cells
	)


func _procesar_datos_chunk(
	cells: int
) -> bool:
	var profiler_start_usec: int = Time.get_ticks_usec()

	var coord: Vector2i = (
		_generation_task["coord"]
	)

	var zonas_base: Array = (
		_generation_task["zonas_base"]
	)

	var biomas: Array = (
		_generation_task["biomas"]
	)

	var ecosistemas: Array = (
		_generation_task["ecosistemas"]
	)

	var size: int = (
		chunk_size_tiles
		+ CHUNK_PADDING * 2
	)

	var total: int = (
		size * size
	)

	var cursor: int = int(
		_generation_task["cursor"]
	)

	if cursor == 0 and visual != null:
		visual.comenzar_lote()

	var limite: int = mini(
		cursor + cells,
		total
	)

	while cursor < limite:
		var local_y: int = (
			cursor / size
		)

		var local_x: int = (
			cursor % size
		)

		var global_x: int = (
			coord.x
			* chunk_size_tiles
			+ local_x
			- CHUNK_PADDING
		)

		var global_y: int = (
			coord.y
			* chunk_size_tiles
			+ local_y
			- CHUNK_PADDING
		)

		var tile := Vector2i(
			global_x,
			global_y
		)

		var stage_start_usec: int = Time.get_ticks_usec()
		var bioma_index: int = _bioma_index_at_tile(tile)
		_profiler_biome_ms += float(Time.get_ticks_usec() - stage_start_usec) / 1000.0

		stage_start_usec = Time.get_ticks_usec()
		var ecosistema_index: int = _ecosistema_index_at_tile(
			tile,
			bioma_index
		)
		_profiler_ecosystem_ms += float(Time.get_ticks_usec() - stage_start_usec) / 1000.0

		stage_start_usec = Time.get_ticks_usec()
		var zona: int = _zona_base_at_tile(
			tile,
			bioma_index,
			ecosistema_index
		)
		_profiler_zone_ms += float(Time.get_ticks_usec() - stage_start_usec) / 1000.0

		biomas[local_y][local_x] = (
			bioma_index
		)

		ecosistemas[local_y][local_x] = (
			ecosistema_index
		)

		zonas_base[local_y][local_x] = (
			zona
		)

		cursor += 1

	_generation_task["cursor"] = cursor

	_profiler_data_ms += float(
		Time.get_ticks_usec() - profiler_start_usec
	) / 1000.0
	_profiler_data_calls += 1

	if cursor < total:
		return false

	_generation_task["stage"] = 1
	_generation_task["cursor"] = 0

	return false


func _procesar_pintado_chunk(
	cells: int
) -> bool:
	var profiler_start_usec: int = Time.get_ticks_usec()

	var coord: Vector2i = (
		_generation_task["coord"]
	)

	var zonas_base: Array = (
		_generation_task["zonas_base"]
	)

	var zonas: Array = (
		_generation_task["zonas"]
	)

	var biomas: Array = (
		_generation_task["biomas"]
	)

	var ecosistemas: Array = (
		_generation_task["ecosistemas"]
	)

	var total: int = (
		chunk_size_tiles
		* chunk_size_tiles
	)

	var cursor: int = int(
		_generation_task["cursor"]
	)

	var limite: int = mini(
		cursor + cells,
		total
	)

	while cursor < limite:
		var local_y: int = (
			cursor / chunk_size_tiles
		)

		var local_x: int = (
			cursor % chunk_size_tiles
		)

		var padded_x: int = (
			local_x + CHUNK_PADDING
		)

		var padded_y: int = (
			local_y + CHUNK_PADDING
		)

		var global_x: int = (
			coord.x
			* chunk_size_tiles
			+ local_x
		)

		var global_y: int = (
			coord.y
			* chunk_size_tiles
			+ local_y
		)

		var tile := Vector2i(
			global_x,
			global_y
		)

		var zona_base: int = int(
			zonas_base[padded_y][padded_x]
		)

		var zona_final: int = (
			_zona_final_desde_array(
				zonas_base,
				padded_x,
				padded_y,
				zona_base
			)
		)

		zonas[padded_y][padded_x] = (
			zona_final
		)

		_pintar_tile(
			tile,
			zona_final,
			int(biomas[padded_y][padded_x])
		)

		cursor += 1

	_generation_task["cursor"] = cursor

	_profiler_paint_ms += float(
		Time.get_ticks_usec() - profiler_start_usec
	) / 1000.0
	_profiler_paint_calls += 1

	if cursor < total:
		return false

	if visual != null:
		visual.terminar_lote()

	_pintado_desde_flush = 0
	_generation_task["stage"] = 2
	_generation_task["cursor"] = 0

	return false


func _procesar_flush_chunk(
	cells: int
) -> bool:
	if visual == null:
		_finalizar_chunk()
		return true

	var flush_start_usec: int = Time.get_ticks_usec()
	# TileMapDual no escala linealmente: mantener micro-lotes y dejar que
	# el RenderManager corte el trabajo antes de consumir el frame.
	var flush_cells: int = mini(cells, 32)
	if _render_manager != null:
		flush_cells = int(_render_manager.call(
			"presupuesto_unidades_adaptativo",
			"terrain_flush",
			flush_cells,
			4,
			32,
			0.75
		))
		if flush_cells <= 0:
			return false
	var terminado: bool = visual.procesar_flush(flush_cells)
	var flush_ms := float(Time.get_ticks_usec() - flush_start_usec) / 1000.0
	_profiler_flush_ms += flush_ms
	_profiler_flushes += 1
	if _render_manager != null:
		_render_manager.call("registrar_trabajo", "terrain_flush", flush_ms, max(flush_cells, 1))

	if not terminado:
		return false

	_finalizar_chunk()
	return true


func generar_chunk_completo(
	chunk_coord: Vector2i
) -> void:
	iniciar_generacion_chunk(
		chunk_coord
	)

	while not _generation_task.is_empty():
		procesar_generacion(
			100000
		)


func _finalizar_chunk() -> void:
	var coord: Vector2i = (
		_generation_task["coord"]
	)

	_loaded_chunks[coord] = {
		"zonas": _generation_task["zonas"],
		"zonas_base": _generation_task["zonas_base"],
		"biomas": _generation_task["biomas"],
		"ecosistemas": _generation_task["ecosistemas"]
	}

	_ultimo_chunk_generado = coord

	var total_ms: float = _profiler_data_ms + _profiler_paint_ms
	var visual_profile: Dictionary = visual.obtener_profiler() if visual != null else {}
	print(
		"World Profiler | chunk ",
		coord,
		" | total=",
		"%.2f" % total_ms,
		" ms | datos=",
		"%.2f" % _profiler_data_ms,
		" ms (",
		_profiler_data_calls,
		" pasos) | bioma=",
		"%.2f" % _profiler_biome_ms,
		" ms | ecosistema=",
		"%.2f" % _profiler_ecosystem_ms,
		" ms | zona=",
		"%.2f" % _profiler_zone_ms,
		" ms | pintura=",
		"%.2f" % _profiler_paint_ms,
		" ms (",
		_profiler_paint_calls,
		" pasos) | flush=",
		"%.2f" % _profiler_flush_ms,
		" ms / ",
		_profiler_flushes,
		" | visual_set_zone=",
		"%.2f" % float(visual_profile.get("set_zone_ms", 0.0)),
		" ms/", int(visual_profile.get("set_zone_calls", 0)), " llamadas",
		" | visual_set_cell=",
		"%.2f" % float(visual_profile.get("set_cell_ms", 0.0)),
		" ms/", int(visual_profile.get("set_cell_calls", 0)), " llamadas",
		" | visual_variaciones_dirty=",
		"%.2f" % float(visual_profile.get("variation_ms", 0.0)),
		" ms | visual_dirty=",
		"%.2f" % float(visual_profile.get("dirty_ms", 0.0)),
		" ms | flush_convert=",
		"%.2f" % float(visual_profile.get("flush_convert_ms", 0.0)),
		" ms | flush_update=",
		"%.2f" % float(visual_profile.get("flush_update_ms", 0.0)),
		" ms/", int(visual_profile.get("flush_update_calls", 0)), " updates/", int(visual_profile.get("flush_cells", 0)), " celdas",
		" | flush_variaciones=",
		"%.2f" % float(visual_profile.get("flush_variation_ms", 0.0)),
		" ms/", int(visual_profile.get("flush_variation_cells", 0)), " celdas",
		" | MAX set_zone=", "%.2f" % float(visual_profile.get("set_zone_max_ms", 0.0)),
		" ms | MAX flush=", "%.2f" % float(visual_profile.get("flush_max_ms", 0.0)),
		" ms | MAX flush_update=", "%.2f" % float(visual_profile.get("flush_update_max_ms", 0.0)),
		" ms | MAX variaciones=", "%.2f" % float(visual_profile.get("variation_max_ms", 0.0)),
		" ms",
	)

	_generation_task.clear()
func tiene_generacion_activa() -> bool:
	return not _generation_task.is_empty()


func cancelar_generacion_si_distante(
	centro: Vector2i,
	radio_maximo: int
) -> bool:
	if _generation_task.is_empty():
		return false

	var coord: Vector2i = _generation_task.get(
		"coord",
		Vector2i.ZERO
	)
	var distancia := maxi(
		abs(coord.x - centro.x),
		abs(coord.y - centro.y)
	)
	if distancia <= radio_maximo:
		return false

	# La generación puede haber pintado parte del chunk antes de que
	# el jugador se alejara. Retirar esas celdas evita terreno fantasma.
	if visual != null:
		visual.terminar_lote()
		visual.clear_chunk(coord, chunk_size_tiles)
	_generation_task.clear()
	_pintado_desde_flush = 0
	return true


func chunk_en_generacion(
	chunk_coord: Vector2i
) -> bool:
	if _generation_task.is_empty():
		return false

	return (
		_generation_task["coord"]
		== chunk_coord
	)


func chunk_cargado(
	chunk_coord: Vector2i
) -> bool:
	return _loaded_chunks.has(
		chunk_coord
	)


func chunks_cargados() -> Array:
	return _loaded_chunks.keys()


func ultimo_chunk_generado() -> Vector2i:
	return _ultimo_chunk_generado


func descargar_chunk(
	chunk_coord: Vector2i
) -> void:
	if not _loaded_chunks.has(chunk_coord):
		return
	if not _unload_task.is_empty():
		return

	_unload_task = {
		"coord": chunk_coord,
	}
	if visual != null:
		visual.iniciar_clear_chunk(chunk_coord, chunk_size_tiles)


func procesar_descargas(cells: int) -> bool:
	if _unload_task.is_empty():
		return true

	if visual == null:
		_loaded_chunks.erase(_unload_task["coord"])
		_unload_task.clear()
		return true

	var terminado: bool = visual.procesar_clear_chunk(cells)
	if not terminado:
		return false

	_loaded_chunks.erase(_unload_task["coord"])
	_unload_task.clear()
	return true


func tiene_descarga_activa() -> bool:
	return not _unload_task.is_empty()
func _bioma_index_at_tile(tile: Vector2i) -> int:
	if areas == null:
		return -1
	return areas.bioma_index_at_tile(tile)
func _ecosistema_index_at_tile(
	tile: Vector2i,
	bioma_index: int
) -> int:
	if areas == null:
		return -1
	return areas.ecosistema_index_at_tile(
		tile,
		bioma_index
	)
func _zona_base_at_tile(
	tile: Vector2i,
	bioma_index: int,
	ecosistema_index: int
) -> int:
	if areas == null:
		return Zone.GRASS
	return areas.zona_base_at_tile(
		tile,
		bioma_index,
		ecosistema_index
	)
func _zona_final_desde_array(
	zonas: Array,
	x: int,
	y: int,
	zona_base: int
) -> int:
	if areas == null:
		return zona_base
	return areas.zona_final_desde_array(
		zonas,
		x,
		y,
		zona_base
	)
func _agua_toca_tierra_en_array(
	zonas: Array,
	x: int,
	y: int
) -> bool:
	if areas == null:
		return false
	return areas.agua_toca_tierra_en_array(
		zonas,
		x,
		y
	)
func _pintar_tile(
	tile: Vector2i,
	zona: int,
	bioma_index: int
) -> void:
	if visual == null:
		return

	var bioma_nombre := ""
	var bioma_textura := ""

	if bioma_index >= 0 and bioma_index < _biomas.size():
		var bioma_variant: Variant = _biomas[bioma_index]

		if bioma_variant is Dictionary:
			var bioma := bioma_variant as Dictionary

			bioma_nombre = str(
				bioma.get("nombre", "")
			)

			var generacion_variant: Variant = (
				bioma.get(
					"generacion",
					{}
				)
			)

			if generacion_variant is Dictionary:
				bioma_textura = str(
					(generacion_variant as Dictionary).get(
						"textura",
						""
					)
				)

	visual.set_zone(
		tile,
		zona,
		bioma_nombre,
		bioma_textura
	)
func get_zona_at(
	tile: Vector2i
) -> int:
	var chunk_coord: Vector2i = (
		_tile_to_chunk(tile)
	)

	var datos: Dictionary = (
		_loaded_chunks.get(
			chunk_coord,
			{}
		)
	)

	if not datos.is_empty():
		var zonas: Array = (
			datos.get(
				"zonas",
				[]
			)
		)

		var local := _tile_to_local(tile)

		var x: int = (
			local.x + CHUNK_PADDING
		)

		var y: int = (
			local.y + CHUNK_PADDING
		)

		if (
			y >= 0
			and y < zonas.size()
			and x >= 0
			and x < zonas[y].size()
		):
			return int(
				zonas[y][x]
			)

	return _zona_directa(tile)


func _zona_directa(
	tile: Vector2i
) -> int:
	var bioma_index: int = (
		_bioma_index_at_tile(tile)
	)

	var ecosistema_index: int = (
		_ecosistema_index_at_tile(
			tile,
			bioma_index
		)
	)

	return _zona_base_at_tile(
		tile,
		bioma_index,
		ecosistema_index
	)


func cambiar_zona_at(
	tile: Vector2i,
	nueva_zona: int
) -> bool:
	if nueva_zona < 0 or nueva_zona >= Zone.size():
		return false

	var chunk_coord := _tile_to_chunk(tile)
	if not _loaded_chunks.has(chunk_coord):
		return false

	var datos: Dictionary = _loaded_chunks[chunk_coord]
	var zonas_base_variant: Variant = datos.get("zonas_base", [])
	if not zonas_base_variant is Array:
		return false

	var zonas_base: Array = zonas_base_variant as Array
	var local := _tile_to_local(tile)
	var x := local.x + CHUNK_PADDING
	var y := local.y + CHUNK_PADDING
	if y < 0 or y >= zonas_base.size():
		return false
	if not zonas_base[y] is Array or x < 0 or x >= (zonas_base[y] as Array).size():
		return false

	(zonas_base[y] as Array)[x] = nueva_zona
	datos["zonas_base"] = zonas_base
	_loaded_chunks[chunk_coord] = datos

	# Al cambiar una celda también pueden cambiar las costas de sus vecinos.
	# Recalcular desde el terreno base evita acumular "shore" antiguo.
	var afectadas: Array[Vector2i] = [
		tile,
		tile + Vector2i.RIGHT,
		tile + Vector2i.LEFT,
		tile + Vector2i.UP,
		tile + Vector2i.DOWN,
	]
	for celda in afectadas:
		_actualizar_zona_final_at_tile(celda)

	if visual != null:
		visual.flush()
	return true


func _obtener_zona_base_at_tile(tile: Vector2i) -> int:
	var chunk_coord := _tile_to_chunk(tile)
	var datos: Dictionary = _loaded_chunks.get(chunk_coord, {})
	if not datos.is_empty():
		var zonas_base_variant: Variant = datos.get("zonas_base", [])
		if zonas_base_variant is Array:
			var zonas_base: Array = zonas_base_variant as Array
			var local := _tile_to_local(tile)
			var x := local.x + CHUNK_PADDING
			var y := local.y + CHUNK_PADDING
			if y >= 0 and y < zonas_base.size():
				if zonas_base[y] is Array and x >= 0 and x < (zonas_base[y] as Array).size():
					return int((zonas_base[y] as Array)[x])

	return _zona_directa(tile)


func _actualizar_zona_final_at_tile(tile: Vector2i) -> void:
	var chunk_coord := _tile_to_chunk(tile)
	if not _loaded_chunks.has(chunk_coord):
		return

	var datos: Dictionary = _loaded_chunks[chunk_coord]
	var zonas_variant: Variant = datos.get("zonas", [])
	var zonas_base_variant: Variant = datos.get("zonas_base", [])
	var biomas_variant: Variant = datos.get("biomas", [])
	if not zonas_variant is Array or not zonas_base_variant is Array:
		return

	var zonas: Array = zonas_variant as Array
	var zonas_base: Array = zonas_base_variant as Array
	var local := _tile_to_local(tile)
	var x := local.x + CHUNK_PADDING
	var y := local.y + CHUNK_PADDING
	if y < 0 or y >= zonas.size() or y >= zonas_base.size():
		return
	if not zonas[y] is Array or not zonas_base[y] is Array:
		return
	if x < 0 or x >= (zonas[y] as Array).size() or x >= (zonas_base[y] as Array).size():
		return

	var zona_base := _obtener_zona_base_at_tile(tile)
	var zona_final := zona_base
	if zona_base == Zone.WATER or zona_base == Zone.DEEP_WATER:
		for direccion: Vector2i in WorldTerrainAreas.ORTHOGONAL_DIRECTIONS:
			var zona_vecina := _obtener_zona_base_at_tile(tile + direccion)
			if zona_vecina != Zone.WATER and zona_vecina != Zone.DEEP_WATER:
				zona_final = Zone.SHORE
				break

	(zonas[y] as Array)[x] = zona_final
	datos["zonas"] = zonas
	_loaded_chunks[chunk_coord] = datos

	var bioma_index := -1
	if biomas_variant is Array:
		var biomas: Array = biomas_variant as Array
		if y < biomas.size() and biomas[y] is Array and x < (biomas[y] as Array).size():
			bioma_index = int((biomas[y] as Array)[x])

	_pintar_tile(tile, zona_final, bioma_index)


func is_walkable(
	tile: Vector2i
) -> bool:
	var zona: int = (
		get_zona_at(tile)
	)

	match zona:
		Zone.WATER:
			return false

		Zone.DEEP_WATER:
			return false

		Zone.SHORE:
			return false

		Zone.ICE:
			return false

		_:
			return true


func get_bioma_at(
	tile: Vector2i
) -> Dictionary:
	var chunk_coord: Vector2i = (
		_tile_to_chunk(tile)
	)

	var datos: Dictionary = (
		_loaded_chunks.get(
			chunk_coord,
			{}
		)
	)

	if not datos.is_empty():
		var biomas: Array = (
			datos.get(
				"biomas",
				[]
			)
		)

		var local := _tile_to_local(tile)

		var x: int = (
			local.x + CHUNK_PADDING
		)

		var y: int = (
			local.y + CHUNK_PADDING
		)

		if (
			y >= 0
			and y < biomas.size()
			and x >= 0
			and x < biomas[y].size()
		):
			var indice: int = int(
				biomas[y][x]
			)

			if (
				indice >= 0
				and indice < _biomas.size()
			):
				return _biomas[indice]

	var indice_directo: int = (
		_bioma_index_at_tile(tile)
	)

	if (
		indice_directo >= 0
		and indice_directo < _biomas.size()
	):
		return _biomas[indice_directo]

	return {}


func get_ecosistema_at(
	tile: Vector2i
) -> Dictionary:
	var chunk_coord: Vector2i = (
		_tile_to_chunk(tile)
	)

	var datos: Dictionary = (
		_loaded_chunks.get(
			chunk_coord,
			{}
		)
	)

	if not datos.is_empty():
		var ecosistemas: Array = (
			datos.get(
				"ecosistemas",
				[]
			)
		)

		var local := _tile_to_local(tile)

		var x: int = (
			local.x + CHUNK_PADDING
		)

		var y: int = (
			local.y + CHUNK_PADDING
		)

		if (
			y >= 0
			and y < ecosistemas.size()
			and x >= 0
			and x < ecosistemas[y].size()
		):
			var indice: int = int(
				ecosistemas[y][x]
			)

			if (
				indice >= 0
				and indice < _ecosistemas.size()
			):
				return _ecosistemas[indice]

	var bioma_index: int = (
		_bioma_index_at_tile(tile)
	)

	var indice_directo: int = (
		_ecosistema_index_at_tile(
			tile,
			bioma_index
		)
	)

	if (
		indice_directo >= 0
		and indice_directo < _ecosistemas.size()
	):
		return _ecosistemas[indice_directo]

	return {}


func get_habitats_at(
	tile: Vector2i
) -> Array:
	var ecosistema: Dictionary = (
		get_ecosistema_at(tile)
	)

	if ecosistema.is_empty():
		return []

	var habitats_variant: Variant = (
		ecosistema.get(
			"habitats",
			[]
		)
	)

	if habitats_variant is Array:
		return habitats_variant

	return []


func get_criaturas_at(
	tile: Vector2i
) -> Array:
	var resultado: Array = []

	var habitats: Array = (
		get_habitats_at(tile)
	)

	for i in range(habitats.size()):
		var habitat_variant: Variant = (
			habitats[i]
		)

		if not habitat_variant is Dictionary:
			continue

		var habitat: Dictionary = (
			habitat_variant
		)

		var criaturas_variant: Variant = (
			habitat.get(
				"criaturas",
				[]
			)
		)

		if not criaturas_variant is Array:
			continue

		var criaturas: Array = (
			criaturas_variant
		)

		for j in range(criaturas.size()):
			var criatura_variant: Variant = (
				criaturas[j]
			)

			if criatura_variant is Dictionary:
				resultado.append(
					criatura_variant
				)

	return resultado


func get_spawn_position() -> Vector2:
	var centro := Vector2i(
		chunk_size_tiles / 2,
		chunk_size_tiles / 2
	)

	for radio in range(1, 12):
		for dy in range(-radio, radio + 1):
			for dx in range(-radio, radio + 1):
				var tile := Vector2i(
					centro.x + dx,
					centro.y + dy
				)

				if is_walkable(tile):
					return Vector2(
						(float(tile.x) + 0.5)
						* tile_size,
						(float(tile.y) + 0.5)
						* tile_size
					)

	return Vector2(
		float(tile_size * 2),
		float(tile_size * 2)
	)


func _tile_to_chunk(
	tile: Vector2i
) -> Vector2i:
	return Vector2i(
		floori(
			float(tile.x)
			/ chunk_size_tiles
		),
		floori(
			float(tile.y)
			/ chunk_size_tiles
		)
	)


func _tile_to_local(
	tile: Vector2i
) -> Vector2i:
	var chunk := _tile_to_chunk(tile)

	return Vector2i(
		tile.x
		- chunk.x * chunk_size_tiles,
		tile.y
		- chunk.y * chunk_size_tiles
	)
