extends Node2D
class_name WorldTerrain


const CARDINAL_NEIGHBORS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]

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
var _bioma_nombres: PackedStringArray = PackedStringArray()
var _bioma_texturas: PackedStringArray = PackedStringArray()
var _ecosistemas: Array = []

var _ecosistema_indices: Dictionary = {}

var _loaded_chunks: Dictionary = {}
# Caché de datos ya generados. No contiene lógica alternativa: conserva
# exactamente las matrices producidas por este WorldTerrain para evitar
# recalcular ruido/biomas/ecosistemas al volver a una zona reciente.
@export var chunk_cache_max: int = 8
var _chunk_cache: Dictionary = {}
var _chunk_cache_order: Array[Vector2i] = []

var _generation_task: Dictionary = {}
# Una sola tarea puede quedar pausada para ceder el generador al chunk prioritario.
var _paused_generation_task: Dictionary = {}
var _unload_task: Dictionary = {}
var _pending_unload_tasks: Array[Dictionary] = []
var _pintado_desde_flush: int = 0
@export var visual_flush_cells: int = 256

var _ultimo_chunk_generado: Vector2i = Vector2i.ZERO
var _prioridad_generacion_posicion: Vector2 = Vector2.ZERO

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
var _profiler_data_max_ms: float = 0.0
var _profiler_paint_max_ms: float = 0.0
var _profiler_flush_max_ms: float = 0.0
var _profiler_chunk_start_usec: int = 0
var _profiler_first_commit_ms: float = -1.0
var _profiler_visible_25_ms: float = -1.0
var _profiler_visible_50_ms: float = -1.0
var _profiler_visible_100_ms: float = -1.0
var _profiler_visible_cells: int = 0


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
	_bioma_nombres = PackedStringArray()
	_bioma_texturas = PackedStringArray()
	_bioma_nombres.resize(_biomas.size())
	_bioma_texturas.resize(_biomas.size())
	for i in range(_biomas.size()):
		var bioma_nombre_variant: Variant = _biomas[i]
		if bioma_nombre_variant is Dictionary:
			var bioma_datos := bioma_nombre_variant as Dictionary
			_bioma_nombres[i] = str(bioma_datos.get("nombre", ""))
			var generacion_variant: Variant = bioma_datos.get("generacion", {})
			if generacion_variant is Dictionary:
				_bioma_texturas[i] = str((generacion_variant as Dictionary).get("textura", ""))

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
func obtener_contexto_data_at(tile: Vector2i) -> Dictionary:
	var chunk_coord := _tile_to_chunk(tile)
	var datos_variant: Variant = _loaded_chunks.get(chunk_coord, null)
	if datos_variant is Dictionary:
		var datos := datos_variant as Dictionary
		var local := _tile_to_local(tile)
		var size: int = chunk_size_tiles + CHUNK_PADDING * 2
		var indice: int = (local.y + CHUNK_PADDING) * size + local.x + CHUNK_PADDING
		var biomas_variant: Variant = datos.get("biomas", null)
		var ecosistemas_variant: Variant = datos.get("ecosistemas", null)
		var zonas_variant: Variant = datos.get("zonas", null)
		if biomas_variant is PackedInt32Array and ecosistemas_variant is PackedInt32Array and zonas_variant is PackedInt32Array:
			var biomas: PackedInt32Array = biomas_variant
			var ecosistemas: PackedInt32Array = ecosistemas_variant
			var zonas: PackedInt32Array = zonas_variant
			if indice >= 0 and indice < biomas.size() and indice < ecosistemas.size() and indice < zonas.size():
				return _construir_contexto_data(tile, biomas[indice], ecosistemas[indice], zonas[indice])

	var bioma_index: int = _bioma_index_at_tile(tile)
	var ecosistema_index: int = _ecosistema_index_at_tile(tile, bioma_index)
	var zona: int = _zona_base_at_tile(tile, bioma_index, ecosistema_index)
	return _construir_contexto_data(tile, bioma_index, ecosistema_index, zona)

func _construir_contexto_data(
	tile: Vector2i,
	bioma_index: int,
	ecosistema_index: int,
	zona: int
) -> Dictionary:
	var bioma: Dictionary = {}
	var ecosistema: Dictionary = {}
	if bioma_index >= 0 and bioma_index < _biomas.size():
		var bioma_variant: Variant = _biomas[bioma_index]
		if bioma_variant is Dictionary:
			bioma = bioma_variant as Dictionary
	if ecosistema_index >= 0 and ecosistema_index < _ecosistemas.size():
		var ecosistema_variant: Variant = _ecosistemas[ecosistema_index]
		if ecosistema_variant is Dictionary:
			ecosistema = ecosistema_variant as Dictionary
	var habitats: Array = []
	var habitats_variant: Variant = ecosistema.get("habitats", [])
	if habitats_variant is Array:
		habitats = habitats_variant as Array
	return {
		"tile": tile,
		"bioma": bioma,
		"ecosistema": ecosistema,
		"habitats": habitats,
		"zona": zona,
		"walkable": zona != Zone.WATER and zona != Zone.DEEP_WATER and zona != Zone.SHORE and zona != Zone.ICE
	}

func obtener_resumen_chunk(chunk_coord: Vector2i) -> Dictionary:
	# LOD DATA: muestreo determinista pequeño. No genera matrices, no toca
	# TileMap y no crea entidades. Es la base para conocer el mundo más allá
	# del radio visual sin pagar el coste de un chunk completo.
	var muestras: int = 0
	var conteo_biomas: Dictionary = {}
	var conteo_ecosistemas: Dictionary = {}
	var paso: int = maxi(chunk_size_tiles / 4, 1)

	for local_y in range(0, chunk_size_tiles, paso):
		for local_x in range(0, chunk_size_tiles, paso):
			var tile := Vector2i(
				chunk_coord.x * chunk_size_tiles + local_x,
				chunk_coord.y * chunk_size_tiles + local_y
			)
			var bioma_index: int = _bioma_index_at_tile(tile)
			var ecosistema_index: int = _ecosistema_index_at_tile(tile, bioma_index)
			conteo_biomas[bioma_index] = int(conteo_biomas.get(bioma_index, 0)) + 1
			conteo_ecosistemas[ecosistema_index] = int(conteo_ecosistemas.get(ecosistema_index, 0)) + 1
			muestras += 1

	return {
		"chunk": chunk_coord,
		"lod": "DATA",
		"muestras": muestras,
		"biomas": conteo_biomas,
		"ecosistemas": conteo_ecosistemas
	}


func configurar_prioridad_generacion(posicion_mundo: Vector2) -> void:
	_prioridad_generacion_posicion = posicion_mundo


func iniciar_generacion_chunk(
	chunk_coord: Vector2i
) -> void:
	if _loaded_chunks.has(chunk_coord):
		return

	# Reanudar exactamente el estado que fue pausado por prioridad.
	if not _paused_generation_task.is_empty() and _generation_task.is_empty():
		var paused_coord: Vector2i = _paused_generation_task.get("coord", Vector2i.ZERO)
		if paused_coord == chunk_coord:
			_generation_task = _paused_generation_task
			_paused_generation_task.clear()
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
	_profiler_data_max_ms = 0.0
	_profiler_paint_max_ms = 0.0
	_profiler_flush_max_ms = 0.0
	_profiler_chunk_start_usec = Time.get_ticks_usec()
	_profiler_first_commit_ms = -1.0
	_profiler_visible_25_ms = -1.0
	_profiler_visible_50_ms = -1.0
	_profiler_visible_100_ms = -1.0
	_profiler_visible_cells = 0
	if visual != null:
		visual.iniciar_profiler()

	if not _generation_task.is_empty():
		return

	var padded_size: int = (
		chunk_size_tiles
		+ CHUNK_PADDING * 2
	)
	var total_padded_cells: int = padded_size * padded_size

	# Reutilizar datos sólo si las cuatro matrices tienen el tamaño esperado
	# para la configuración actual. Una caché antigua/incompleta (por ejemplo,
	# de un chunk generado con otro tamaño) no puede entrar a PINTADO: sus
	# índices parecen válidos hasta que una celda supera su longitud.
	if _chunk_cache.has(chunk_coord):
		var cache_data: Variant = _chunk_cache[chunk_coord]
		var cache_valida := false
		var datos: Dictionary = {}
		if cache_data is Dictionary:
			datos = cache_data as Dictionary
			var zb: Variant = datos.get("zonas_base", null)
			var z: Variant = datos.get("zonas", null)
			var b: Variant = datos.get("biomas", null)
			var e: Variant = datos.get("ecosistemas", null)
			cache_valida = (
				zb is PackedInt32Array and z is PackedInt32Array
				and b is PackedInt32Array and e is PackedInt32Array
				and zb.size() == total_padded_cells
				and z.size() == total_padded_cells
				and b.size() == total_padded_cells
				and e.size() == total_padded_cells
			)
		if cache_valida:
			var orden_pintado_cache := _crear_orden_generacion(
				chunk_size_tiles,
				chunk_coord,
				false
			)
			_generation_task = {
				"coord": chunk_coord,
				"stage": 1,
				"cursor": 0,
				"cursor_datos": 0,
				"cursor_pintado": 0,
				"orden_pintado": orden_pintado_cache,
				"zonas_base": datos["zonas_base"],
				"zonas": datos["zonas"],
				"biomas": datos["biomas"],
				"ecosistemas": datos["ecosistemas"]
			}
			_chunk_cache.erase(chunk_coord)
			_chunk_cache_order.erase(chunk_coord)
			return
		# Descartar sólo la entrada dañada; regenerar desde los datos canónicos.
		_chunk_cache.erase(chunk_coord)
		_chunk_cache_order.erase(chunk_coord)
	var zonas_base := PackedInt32Array()
	var zonas := PackedInt32Array()
	var biomas := PackedInt32Array()
	var ecosistemas := PackedInt32Array()
	zonas_base.resize(total_padded_cells)
	zonas.resize(total_padded_cells)
	biomas.resize(total_padded_cells)
	ecosistemas.resize(total_padded_cells)
	zonas_base.fill(Zone.GRASS)
	zonas.fill(Zone.GRASS)
	biomas.fill(-1)
	ecosistemas.fill(-1)
	_pintado_desde_flush = 0

	var orden_datos := _crear_orden_generacion(padded_size, chunk_coord, true)
	var orden_pintado := _crear_orden_generacion(chunk_size_tiles, chunk_coord, false)

	var datos_listos := PackedByteArray()
	datos_listos.resize(total_padded_cells)
	datos_listos.fill(0)

	_generation_task = {
		"coord": chunk_coord,
		"stage": 0,
		"cursor": 0,
		"cursor_datos": 0,
		"cursor_pintado": 0,
		"datos_listos": datos_listos,
		"orden_datos": orden_datos,
		"orden_pintado": orden_pintado,
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
		if not _validar_matrices_tarea_generacion():
			return _recuperar_tarea_generacion_invalida()
		return _procesar_datos_chunk(
			cells
		)

	if stage == 1:
		# Las tareas pausadas y la caché deben conservar el contrato de tamaño
		# del chunk. Validarlo justo antes de PINTADO evita que un estado
		# incompleto vuelva a provocar accesos fuera de rango.
		if not _validar_matrices_tarea_generacion():
			return _recuperar_tarea_generacion_invalida()
		return _procesar_pintado_chunk(
			cells
		)

	return _procesar_flush_chunk(
		cells
	)


func _validar_matrices_tarea_generacion() -> bool:
	if _generation_task.is_empty():
		return false

	# Coord forma parte del contrato: usar un fallback a (0, 0) en una tarea
	# corrupta podría borrar accidentalmente el chunk de origen del mundo.
	var coord_variant: Variant = _generation_task.get("coord", null)
	if not coord_variant is Vector2i:
		return false

	var padded_size: int = chunk_size_tiles + CHUNK_PADDING * 2
	var expected_cells: int = padded_size * padded_size
	var expected_chunk_cells: int = chunk_size_tiles * chunk_size_tiles
	var zonas_base: Variant = _generation_task.get("zonas_base", null)
	var zonas: Variant = _generation_task.get("zonas", null)
	var biomas: Variant = _generation_task.get("biomas", null)
	var ecosistemas: Variant = _generation_task.get("ecosistemas", null)
	var orden_pintado: Variant = _generation_task.get("orden_pintado", null)

	if not (
		zonas_base is PackedInt32Array
		and zonas is PackedInt32Array
		and biomas is PackedInt32Array
		and ecosistemas is PackedInt32Array
		and zonas_base.size() == expected_cells
		and zonas.size() == expected_cells
		and biomas.size() == expected_cells
		and ecosistemas.size() == expected_cells
		and _orden_generacion_valido(orden_pintado, expected_chunk_cells)
	):
		return false

	var stage: int = int(_generation_task.get("stage", -1))
	if stage == 0:
		var datos_listos: Variant = _generation_task.get("datos_listos", null)
		var orden_datos: Variant = _generation_task.get("orden_datos", null)
		return (
			datos_listos is PackedByteArray
			and datos_listos.size() == expected_cells
			and _orden_generacion_valido(orden_datos, expected_cells)
		)
	if stage == 1:
		return true
	if stage == 2:
		return true
	return false


func _recuperar_tarea_generacion_invalida() -> bool:
	var coord_variant: Variant = _generation_task.get("coord", null)
	var coord_confiable := coord_variant is Vector2i
	var coord_invalida := Vector2i.ZERO
	if coord_confiable:
		coord_invalida = coord_variant

	push_warning(
		"WorldTerrain: tarea de chunk inconsistente en "
		+ str(coord_variant)
		+ "; se limpiará y volverá a la cola de streaming si su coordenada es válida."
	)

	# Incluso en la etapa DATA ya puede haberse pintado una parte del chunk:
	# el pintado temprano ocurre antes de que DATA termine. Limpiar siempre
	# evita residuos si el índice corrupto aparece a mitad de un lote.
	_generation_task.clear()
	_pintado_desde_flush = 0
	if coord_confiable:
		_chunk_cache.erase(coord_invalida)
		_chunk_cache_order.erase(coord_invalida)
		_programar_limpieza_chunk(coord_invalida, false)

	# Sin una coordenada validada no tocamos ninguna región visual/caché.
	# El streamer tampoco reencolará el sentinel devuelto por el getter.
	return false


func _orden_generacion_valido(orden: Variant, expected_size: int) -> bool:
	if orden is Array or orden is PackedInt32Array:
		return orden.size() == expected_size
	return false


func _copiar_dato_borde_vecino(
	tile: Vector2i,
	local_x: int,
	local_y: int,
	biomas: PackedInt32Array,
	ecosistemas: PackedInt32Array,
	zonas_base: PackedInt32Array
) -> bool:
	if local_x != 0 and local_x != chunk_size_tiles + 1 and local_y != 0 and local_y != chunk_size_tiles + 1:
		return false

	var vecino_coord: Vector2i = _tile_to_chunk(tile)
	var datos_variant: Variant = _loaded_chunks.get(vecino_coord, null)
	if datos_variant == null:
		datos_variant = _chunk_cache.get(vecino_coord, null)
	if not datos_variant is Dictionary:
		return false

	var datos: Dictionary = datos_variant as Dictionary
	var vecino_local: Vector2i = _tile_to_local(tile)
	var size: int = chunk_size_tiles + CHUNK_PADDING * 2
	var vecino_x: int = vecino_local.x + CHUNK_PADDING
	var vecino_y: int = vecino_local.y + CHUNK_PADDING
	var indice_vecino: int = vecino_y * size + vecino_x
	var indice_local: int = local_y * size + local_x

	var vb: Variant = datos.get("biomas", null)
	var ve: Variant = datos.get("ecosistemas", null)
	var vz: Variant = datos.get("zonas_base", null)
	if not vb is PackedInt32Array or not ve is PackedInt32Array or not vz is PackedInt32Array:
		return false

	var vecino_biomas: PackedInt32Array = vb
	var vecino_ecosistemas: PackedInt32Array = ve
	var vecino_zonas: PackedInt32Array = vz
	if indice_vecino < 0 or indice_vecino >= vecino_biomas.size() or indice_vecino >= vecino_ecosistemas.size() or indice_vecino >= vecino_zonas.size():
		return false

	biomas[indice_local] = vecino_biomas[indice_vecino]
	ecosistemas[indice_local] = vecino_ecosistemas[indice_vecino]
	zonas_base[indice_local] = vecino_zonas[indice_vecino]
	return true

func _procesar_datos_chunk(
	cells: int
) -> bool:
	var profiler_start_usec: int = Time.get_ticks_usec()

	var coord: Vector2i = (
		_generation_task["coord"]
	)

	var zonas_base: PackedInt32Array = _generation_task["zonas_base"]

	var biomas: PackedInt32Array = _generation_task["biomas"]

	var ecosistemas: PackedInt32Array = _generation_task["ecosistemas"]

	var size: int = (
		chunk_size_tiles
		+ CHUNK_PADDING * 2
	)

	var total: int = (
		size * size
	)

	var cursor: int = int(_generation_task.get("cursor_datos", _generation_task.get("cursor", 0)))
	var datos_listos: PackedByteArray = _generation_task["datos_listos"]
	var orden: Array = _generation_task["orden_datos"]

	# DATA sólo modifica buffers PackedInt32Array. No hay celdas visuales
	# que bloquear todavía; el lote visual comienza al entrar en PINTADO.
	var cursor_inicio_lote: int = cursor
	var limite: int = mini(
		cursor + cells,
		total
	)

	while cursor < limite:
		if cursor < 0 or cursor >= orden.size():
			return _recuperar_tarea_generacion_invalida()
		var indice: int = int(orden[cursor])
		if indice < 0 or indice >= total:
			return _recuperar_tarea_generacion_invalida()
		var local_y: int = (
			indice / size
		)

		var local_x: int = (
			indice % size
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

		# El borde puede ser una coordenada que ya pertenece al chunk vecino.
		# Reutilizarlo elimina trabajo duplicado sin cambiar ningún resultado.
		var indice_dato := local_y * size + local_x
		if _copiar_dato_borde_vecino(
			tile,
			local_x,
			local_y,
			biomas,
			ecosistemas,
			zonas_base
		):
			datos_listos[indice_dato] = 1
			cursor += 1
			continue

		# Este es el camino caliente del generador. No medir cada llamada a
		# FastNoiseLite: tres get_ticks_usec() por celda añadían miles de
		# llamadas al profiler y contaminaban precisamente el rendimiento que
		# estamos intentando medir. El costo total de DATOS se mide una vez
		# por lote más abajo.
		var bioma_index: int = _bioma_index_at_tile(tile)
		var ecosistema_index: int = _ecosistema_index_at_tile(
			tile,
			bioma_index
		)
		var zona: int = _zona_base_at_tile(
			tile,
			bioma_index,
			ecosistema_index
		)

		biomas[local_y * size + local_x] = (
			bioma_index
		)

		ecosistemas[local_y * size + local_x] = (
			ecosistema_index
		)

		zonas_base[indice_dato] = zona
		datos_listos[indice_dato] = 1

		cursor += 1

	_generation_task["cursor_datos"] = cursor
	_generation_task["cursor"] = cursor

	# Durante DATOS, el diagnóstico debe mostrar el cursor de datos.
	_generation_task["cursor"] = cursor
	_generation_task["datos_listos"] = datos_listos

	var data_ms_this_step := float(Time.get_ticks_usec() - profiler_start_usec) / 1000.0
	_profiler_data_ms += data_ms_this_step
	_profiler_data_max_ms = maxf(_profiler_data_max_ms, data_ms_this_step)
	_profiler_data_calls += 1
	if _render_manager != null:
		_render_manager.call(
			"registrar_trabajo",
			"terrain_data",
			data_ms_this_step,
			maxi(limite - cursor_inicio_lote, 1)
		)

	# Pintar en cuanto las celdas cercanas y sus cuatro vecinos ya tienen
	# datos. Se mide DATOS antes de entrar a pintura/flush para que el
	# RenderManager no aprenda un coste unitario contaminado por trabajo visual.
	_procesar_pintado_chunk(cells, true)
	_generation_task["cursor"] = cursor

	if cursor < total:
		return false

	_generation_task["stage"] = 1
	_generation_task["cursor"] = int(_generation_task.get("cursor_pintado", 0))

	return false


func _procesar_pintado_chunk(
	cells: int,
	solo_datos_listos: bool = false
) -> bool:
	var profiler_start_usec: int = Time.get_ticks_usec()

	var coord: Vector2i = (
		_generation_task["coord"]
	)

	var zonas_base: PackedInt32Array = _generation_task["zonas_base"]
	var zonas: PackedInt32Array = _generation_task["zonas"]
	var biomas: PackedInt32Array = _generation_task["biomas"]
	var ecosistemas: PackedInt32Array = _generation_task["ecosistemas"]

	var total: int = (
		chunk_size_tiles
		* chunk_size_tiles
	)

	var cursor: int = int(_generation_task.get("cursor_pintado", 0))
	var datos_listos: PackedByteArray = _generation_task.get("datos_listos", PackedByteArray())
	var orden: Array = _generation_task["orden_pintado"]
	var cursor_inicio_lote: int = cursor

	var limite: int = mini(
		cursor + cells,
		total
	)

	if visual != null:
		visual.comenzar_lote()

	while cursor < limite:
		if cursor < 0 or cursor >= orden.size():
			if visual != null and not visual.tiene_clear_chunk_activo():
				visual.terminar_lote()
			return _recuperar_tarea_generacion_invalida()
		var indice: int = int(orden[cursor])
		if indice < 0 or indice >= total:
			if visual != null and not visual.tiene_clear_chunk_activo():
				visual.terminar_lote()
			return _recuperar_tarea_generacion_invalida()
		var local_y: int = (
			indice / chunk_size_tiles
		)

		var local_x: int = (
			indice % chunk_size_tiles
		)

		var padded_x: int = (
			local_x + CHUNK_PADDING
		)

		var padded_y: int = (
			local_y + CHUNK_PADDING
		)
		var data_size := chunk_size_tiles + CHUNK_PADDING * 2
		var data_index := padded_y * data_size + padded_x
		if solo_datos_listos:
			# La zona final (agua/orilla) depende de los cuatro vecinos. Si uno
			# aún no se ha calculado, conservamos el orden de cercanía y esperamos.
			if datos_listos.is_empty() or data_index >= datos_listos.size():
				break
			var vecinos_listos := true
			for offset: Vector2i in CARDINAL_NEIGHBORS:
				var neighbor_index := (padded_y + offset.y) * data_size + padded_x + offset.x
				if neighbor_index < 0 or neighbor_index >= datos_listos.size() or datos_listos[neighbor_index] == 0:
					vecinos_listos = false
					break
			if datos_listos[data_index] == 0 or not vecinos_listos:
				break

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
			zonas_base[padded_y * (chunk_size_tiles + CHUNK_PADDING * 2) + padded_x]
		)

		var zona_final: int = (
			_zona_final_desde_array(
				zonas_base,
				padded_x,
				padded_y,
				zona_base,
				chunk_size_tiles + CHUNK_PADDING * 2
			)
		)

		zonas[padded_y * (chunk_size_tiles + CHUNK_PADDING * 2) + padded_x] = (
			zona_final
		)

		_pintar_tile(
			tile,
			zona_final,
			int(biomas[padded_y * (chunk_size_tiles + CHUNK_PADDING * 2) + padded_x])
		)

		cursor += 1

	_generation_task["cursor_pintado"] = cursor
	_generation_task["cursor"] = cursor

	if visual != null:
		visual.terminar_lote()
		visual.marcar_region_generada_dirty(
			coord,
			orden,
			chunk_size_tiles,
			cursor_inicio_lote,
			cursor
		)

	var paint_ms_this_step := float(Time.get_ticks_usec() - profiler_start_usec) / 1000.0
	_profiler_paint_ms += paint_ms_this_step
	_profiler_paint_max_ms = maxf(_profiler_paint_max_ms, paint_ms_this_step)
	_profiler_paint_calls += 1
	if _render_manager != null:
		_render_manager.call(
			"registrar_trabajo",
			"terrain_paint",
			paint_ms_this_step,
			maxi(cursor - cursor_inicio_lote, 1)
		)

	# El commit visual de este lote ocurre en el mismo frame que el pintado.
	# Así la generación deja de tener una barrera artificial entre PINTADO y
	# FLUSH, sin declarar terminado el chunk hasta que todas sus celdas estén
	# realmente compuestas.
	_procesar_flush_incremental()

	if cursor < total or solo_datos_listos:
		return false

	if visual != null:
		visual.marcar_chunk_generado_dirty(
			coord,
			chunk_size_tiles
		)

	_pintado_desde_flush = 0
	_generation_task["stage"] = 2
	_generation_task["cursor"] = 0

	return false


func _procesar_flush_incremental() -> void:
	if visual == null or not visual.tiene_flush_pendiente():
		return

	var flush_cells := mini(_cells_presupuesto_flush_incremental(), visual_flush_cells)
	if flush_cells <= 0:
		return

	var inicio_usec := Time.get_ticks_usec()
	visual.procesar_flush(flush_cells)
	var flush_ms := float(Time.get_ticks_usec() - inicio_usec) / 1000.0
	_profiler_flush_ms += flush_ms
	_profiler_flushes += 1
	if visual != null:
		var visual_profiler: Dictionary = visual.obtener_profiler()
		var visible_cells_now := int(visual_profiler.get("flush_cells", 0))
		if visible_cells_now > _profiler_visible_cells:
			_profiler_visible_cells = visible_cells_now
			var elapsed_ms := float(Time.get_ticks_usec() - _profiler_chunk_start_usec) / 1000.0
			if _profiler_first_commit_ms < 0.0:
				_profiler_first_commit_ms = elapsed_ms
			if _profiler_visible_25_ms < 0.0 and visible_cells_now >= 256:
				_profiler_visible_25_ms = elapsed_ms
			if _profiler_visible_50_ms < 0.0 and visible_cells_now >= 512:
				_profiler_visible_50_ms = elapsed_ms
			if _profiler_visible_100_ms < 0.0 and visible_cells_now >= 1024:
				_profiler_visible_100_ms = elapsed_ms
	if _render_manager != null:
		_render_manager.call(
			"registrar_trabajo",
			"terrain_flush",
			flush_ms,
			maxi(flush_cells, 1)
		)


func _cells_presupuesto_flush_incremental() -> int:
	if _render_manager == null:
		return 8
	return int(_render_manager.call(
		"presupuesto_unidades_terreno",
		"terrain_flush",
		256,
		32,
		visual_flush_cells,
		3.0
	))


func _procesar_flush_chunk(
	cells: int
) -> bool:
	if visual == null:
		_finalizar_chunk()
		return true

	var flush_start_usec: int = Time.get_ticks_usec()
	# TileMapDual no escala linealmente: mantener micro-lotes y dejar que
	# el RenderManager corte el trabajo antes de consumir el frame.
	# El objetivo es reducir la latencia del terreno visible sin quitarle al
	# RenderManager la capacidad de recortar el trabajo cuando el frame está caro.
	var flush_cells: int = mini(cells, visual_flush_cells)
	if _render_manager != null:
		flush_cells = int(_render_manager.call(
			"presupuesto_unidades_terreno",
			"terrain_flush",
			maxi(flush_cells, 32),
			16,
			visual_flush_cells,
			2.0
		))
		flush_cells = mini(flush_cells, visual_flush_cells)
	var terminado: bool = visual.procesar_flush(flush_cells)
	var visual_profiler: Dictionary = visual.obtener_profiler()
	var visible_cells_now := int(visual_profiler.get("flush_cells", 0))
	if visible_cells_now > _profiler_visible_cells:
		_profiler_visible_cells = visible_cells_now
		var elapsed_ms := float(Time.get_ticks_usec() - _profiler_chunk_start_usec) / 1000.0
		if _profiler_first_commit_ms < 0.0:
			_profiler_first_commit_ms = elapsed_ms
		if _profiler_visible_25_ms < 0.0 and visible_cells_now >= 256:
			_profiler_visible_25_ms = elapsed_ms
		if _profiler_visible_50_ms < 0.0 and visible_cells_now >= 512:
			_profiler_visible_50_ms = elapsed_ms
		if _profiler_visible_100_ms < 0.0 and visible_cells_now >= 1024:
			_profiler_visible_100_ms = elapsed_ms
	var flush_ms := float(Time.get_ticks_usec() - flush_start_usec) / 1000.0
	_profiler_flush_ms += flush_ms
	_profiler_flush_max_ms = maxf(_profiler_flush_max_ms, flush_ms)
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
	# Si el chunk venía de caché, mantenerlo como "más reciente" sólo después
	# de que haya terminado de pintarse correctamente.
	_chunk_cache.erase(coord)
	_chunk_cache_order.erase(coord)

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
		" ms total / max_step=",
		"%.2f" % _profiler_data_max_ms,
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
		" ms total / max_step=",
		"%.2f" % _profiler_paint_max_ms,
		" ms (",
		_profiler_paint_calls,
		" pasos) | flush=",
		"%.2f" % _profiler_flush_ms,
		" ms total / max_step=",
		"%.2f" % _profiler_flush_max_ms,
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
		" ms/", int(visual_profile.get("flush_update_calls", 0)), " updates/", int(visual_profile.get("flush_regions", 0)), " regiones/", int(visual_profile.get("flush_cells", 0)), " celdas",
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


func obtener_chunk_en_generacion() -> Vector2i:
	if _generation_task.is_empty():
		return Vector2i(999999, 999999)
	var coord_variant: Variant = _generation_task.get("coord", null)
	if not coord_variant is Vector2i:
		return Vector2i(999999, 999999)
	return coord_variant


func puede_pausar_generacion_actual() -> bool:
	# La preempción de FLUSH queda desactivada deliberadamente.
	# FLUSH es la última barrera que convierte el chunk en cargado; si se
	# interrumpe aquí, el chunk actual nunca entra en _loaded_chunks y el
	# streamer puede encadenar pausas antes de mostrar terreno.
	# La prioridad ya se aplica al ORDEN DE LA COLA antes de iniciar cada
	# chunk. Eso mantiene el camino estable sin sacrificar visibilidad.
	return false


func pausar_generacion_actual() -> bool:
	if not puede_pausar_generacion_actual():
		return false
	_paused_generation_task = _generation_task
	_generation_task = {}
	return true


func tiene_generacion_pausada() -> bool:
	return not _paused_generation_task.is_empty()


func descartar_generacion_pausada_si_distante(
	centro: Vector2i,
	radio_maximo: int
) -> bool:
	if _paused_generation_task.is_empty():
		return false
	var coord: Vector2i = _paused_generation_task.get("coord", Vector2i.ZERO)
	var distancia := maxi(abs(coord.x - centro.x), abs(coord.y - centro.y))
	if distancia <= radio_maximo:
		return false
	_paused_generation_task.clear()
	return true


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
	# La retirada también debe ser diferible: cancelar una generación no
	# puede convertir un frame de streaming en un flush de 1024 celdas.
	if visual != null and not visual.tiene_clear_chunk_activo():
		# No cerrar el lote de una limpieza que ya esté en curso: el clear
		# mantiene bloqueadas las actualizaciones hasta su fase de flush.
		visual.terminar_lote()
	_programar_limpieza_chunk(coord, false)
	_generation_task.clear()
	_pintado_desde_flush = 0
	return true


func chunk_en_generacion(
	chunk_coord: Vector2i
) -> bool:
	if _generation_task.is_empty():
		return false
	return _generation_task.get("coord") == chunk_coord


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


func _programar_limpieza_chunk(
	chunk_coord: Vector2i,
	conservar_datos: bool
) -> void:
	# Un solo clear visual puede avanzar a la vez. Encolar las demás limpiezas
	# evita que una cancelación sobrescriba una descarga ya iniciada.
	if not _unload_task.is_empty() and _unload_task.get("coord") == chunk_coord:
		if conservar_datos:
			_unload_task["conservar_datos"] = true
		return
	for pendiente in _pending_unload_tasks:
		if pendiente.get("coord") == chunk_coord:
			if conservar_datos:
				pendiente["conservar_datos"] = true
			return

	var tarea := {
		"coord": chunk_coord,
		"conservar_datos": conservar_datos
	}
	if _unload_task.is_empty():
		_iniciar_limpieza_chunk(tarea)
	else:
		_pending_unload_tasks.append(tarea)


func _iniciar_limpieza_chunk(tarea: Dictionary) -> void:
	_unload_task = tarea
	if visual != null:
		visual.iniciar_clear_chunk(
			_unload_task["coord"],
			chunk_size_tiles
		)


func descargar_chunk(
	chunk_coord: Vector2i
) -> void:
	if not _loaded_chunks.has(chunk_coord):
		return
	_programar_limpieza_chunk(chunk_coord, true)


func procesar_descargas(cells: int) -> bool:
	if _unload_task.is_empty():
		if not _pending_unload_tasks.is_empty():
			_iniciar_limpieza_chunk(_pending_unload_tasks.pop_front())
		else:
			return true

	if visual != null:
		var terminado: bool = visual.procesar_clear_chunk(cells)
		if not terminado:
			return false

	var coord: Vector2i = _unload_task.get("coord", Vector2i.ZERO)
	var conservar_datos: bool = bool(_unload_task.get("conservar_datos", false))
	var datos_variant: Variant = _loaded_chunks.get(coord, null)
	_loaded_chunks.erase(coord)

	# Una generación cancelada nunca llegó a _loaded_chunks. No insertar un
	# diccionario vacío en caché: sólo guardar datos completos ya finalizados.
	if conservar_datos and datos_variant is Dictionary and chunk_cache_max > 0:
		var datos: Dictionary = datos_variant
		var cache_valida := _datos_chunk_cache_validos(datos)
		if cache_valida:
			_chunk_cache[coord] = datos
			_chunk_cache_order.erase(coord)
			_chunk_cache_order.append(coord)
			while _chunk_cache_order.size() > chunk_cache_max:
				var antiguo: Vector2i = _chunk_cache_order.pop_front()
				_chunk_cache.erase(antiguo)

	_unload_task.clear()
	if not _pending_unload_tasks.is_empty():
		_iniciar_limpieza_chunk(_pending_unload_tasks.pop_front())
	return _pending_unload_tasks.is_empty() and _unload_task.is_empty()


func _datos_chunk_cache_validos(datos: Dictionary) -> bool:
	var padded_size := chunk_size_tiles + CHUNK_PADDING * 2
	var expected_size := padded_size * padded_size
	for key in ["zonas", "zonas_base", "biomas", "ecosistemas"]:
		var matriz: Variant = datos.get(key, null)
		if not matriz is PackedInt32Array or matriz.size() != expected_size:
			return false
	return true


func tiene_descarga_activa() -> bool:
	return not _unload_task.is_empty()
func _crear_orden_generacion(
	size: int,
	chunk_coord: Vector2i,
	con_padding: bool
) -> Array:
	# Agrupar por distancia Chebyshev mantiene primero las celdas cercanas
	# al jugador y evita el sort_custom O(n log n). Los buckets garantizan
	# exactamente una entrada por celda, incluso cuando el objetivo está
	# pegado a un borde del chunk.
	var total: int = size * size
	var indices := PackedInt32Array()
	indices.resize(total)

	var posicion_objetivo_tile := Vector2i(
		floori(_prioridad_generacion_posicion.x / float(tile_size)),
		floori(_prioridad_generacion_posicion.y / float(tile_size))
	)

	var offset: int = CHUNK_PADDING if con_padding else 0
	var origen_tile := Vector2i(
		chunk_coord.x * chunk_size_tiles - offset,
		chunk_coord.y * chunk_size_tiles - offset
	)
	var objetivo_local := posicion_objetivo_tile - origen_tile
	objetivo_local.x = clampi(objetivo_local.x, 0, size - 1)
	objetivo_local.y = clampi(objetivo_local.y, 0, size - 1)

	var radio_maximo: int = maxi(
		maxi(objetivo_local.x, size - 1 - objetivo_local.x),
		maxi(objetivo_local.y, size - 1 - objetivo_local.y)
	)
	var buckets: Array[PackedInt32Array] = []
	buckets.resize(radio_maximo + 1)
	for radio in range(radio_maximo + 1):
		buckets[radio] = PackedInt32Array()

	for y in range(size):
		for x in range(size):
			var dx: int = absi(x - objetivo_local.x)
			var dy: int = absi(y - objetivo_local.y)
			var radio: int = maxi(dx, dy)
			buckets[radio].append(y * size + x)

	var cursor: int = 0
	for radio in range(buckets.size()):
		var bucket: PackedInt32Array = buckets[radio]
		for indice in bucket:
			if cursor >= total:
				break
			indices[cursor] = indice
			cursor += 1

	return indices


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
const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

func _zona_final_desde_array(
	zonas: PackedInt32Array,
	x: int,
	y: int,
	zona_base: int,
	size: int
) -> int:
	if zona_base != Zone.WATER and zona_base != Zone.DEEP_WATER:
		return zona_base

	for direccion: Vector2i in ORTHOGONAL_DIRECTIONS:
		var nx: int = x + direccion.x
		var ny: int = y + direccion.y
		if nx < 0 or nx >= size or ny < 0 or ny >= size:
			continue
		var vecino: int = zonas[ny * size + nx]
		if vecino != Zone.WATER and vecino != Zone.DEEP_WATER:
			return Zone.SHORE

	return zona_base


func _pintar_tile(
	tile: Vector2i,
	zona: int,
	bioma_index: int
) -> void:
	if visual == null:
		return

	var bioma_nombre := ""
	var bioma_textura := ""

	if bioma_index >= 0 and bioma_index < _bioma_nombres.size():
		bioma_nombre = _bioma_nombres[bioma_index]

		if bioma_index < _bioma_texturas.size():
			bioma_textura = _bioma_texturas[bioma_index]

	visual.set_zone(
		tile,
		zona,
		bioma_index,
		bioma_nombre,
		bioma_textura
	)
func get_zona_at(tile: Vector2i) -> int:
	var chunk_coord := _tile_to_chunk(tile)
	var datos: Dictionary = _loaded_chunks.get(chunk_coord, {})
	if datos.is_empty():
		return _zona_directa(tile)
	var zonas_variant: Variant = datos.get("zonas", null)
	if not zonas_variant is PackedInt32Array:
		return _zona_directa(tile)
	var zonas: PackedInt32Array = zonas_variant
	var local := _tile_to_local(tile)
	var size: int = chunk_size_tiles + CHUNK_PADDING * 2
	var indice: int = (local.y + CHUNK_PADDING) * size + local.x + CHUNK_PADDING
	if indice >= 0 and indice < zonas.size():
		return zonas[indice]
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


func cambiar_zona_at(tile: Vector2i, nueva_zona: int) -> bool:
	if nueva_zona < 0 or nueva_zona >= Zone.size():
		return false
	var chunk_coord := _tile_to_chunk(tile)
	if not _loaded_chunks.has(chunk_coord):
		return false
	var datos: Dictionary = _loaded_chunks[chunk_coord]
	var zonas_base_variant: Variant = datos.get("zonas_base", null)
	var zonas_variant: Variant = datos.get("zonas", null)
	if not zonas_base_variant is PackedInt32Array or not zonas_variant is PackedInt32Array:
		return false
	var zonas_base: PackedInt32Array = zonas_base_variant
	var zonas: PackedInt32Array = zonas_variant
	var local := _tile_to_local(tile)
	var size: int = chunk_size_tiles + CHUNK_PADDING * 2
	var indice: int = (local.y + CHUNK_PADDING) * size + local.x + CHUNK_PADDING
	if indice < 0 or indice >= zonas_base.size() or indice >= zonas.size():
		return false
	zonas_base[indice] = nueva_zona
	datos["zonas_base"] = zonas_base
	_loaded_chunks[chunk_coord] = datos
	for celda in [tile, tile + Vector2i.RIGHT, tile + Vector2i.LEFT, tile + Vector2i.UP, tile + Vector2i.DOWN]:
		_actualizar_zona_final_at_tile(celda)
	if visual != null:
		visual.flush()
	return true

func _obtener_zona_base_at_tile(tile: Vector2i) -> int:
	var chunk_coord := _tile_to_chunk(tile)
	var datos: Dictionary = _loaded_chunks.get(chunk_coord, {})
	if not datos.is_empty():
		var zonas_variant: Variant = datos.get("zonas_base", null)
		if zonas_variant is PackedInt32Array:
			var zonas_base: PackedInt32Array = zonas_variant
			var local := _tile_to_local(tile)
			var size: int = chunk_size_tiles + CHUNK_PADDING * 2
			var indice: int = (local.y + CHUNK_PADDING) * size + local.x + CHUNK_PADDING
			if indice >= 0 and indice < zonas_base.size():
				return zonas_base[indice]
	return _zona_directa(tile)

func _actualizar_zona_final_at_tile(tile: Vector2i) -> void:
	var chunk_coord := _tile_to_chunk(tile)
	if not _loaded_chunks.has(chunk_coord):
		return
	var datos: Dictionary = _loaded_chunks[chunk_coord]
	var zonas_variant: Variant = datos.get("zonas", null)
	var zonas_base_variant: Variant = datos.get("zonas_base", null)
	var biomas_variant: Variant = datos.get("biomas", null)
	if not zonas_variant is PackedInt32Array or not zonas_base_variant is PackedInt32Array:
		return
	var zonas: PackedInt32Array = zonas_variant
	var zonas_base: PackedInt32Array = zonas_base_variant
	var local := _tile_to_local(tile)
	var size: int = chunk_size_tiles + CHUNK_PADDING * 2
	var indice: int = (local.y + CHUNK_PADDING) * size + local.x + CHUNK_PADDING
	if indice < 0 or indice >= zonas.size() or indice >= zonas_base.size():
		return
	var zona_base: int = zonas_base[indice]
	var zona_final: int = zona_base
	if zona_base == Zone.WATER or zona_base == Zone.DEEP_WATER:
		for direccion: Vector2i in WorldTerrainAreas.ORTHOGONAL_DIRECTIONS:
			var zona_vecina := _obtener_zona_base_at_tile(tile + direccion)
			if zona_vecina != Zone.WATER and zona_vecina != Zone.DEEP_WATER:
				zona_final = Zone.SHORE
				break
	zonas[indice] = zona_final
	datos["zonas"] = zonas
	_loaded_chunks[chunk_coord] = datos
	var bioma_index := -1
	if biomas_variant is PackedInt32Array:
		var biomas: PackedInt32Array = biomas_variant
		if indice < biomas.size():
			bioma_index = biomas[indice]
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


func get_bioma_at(tile: Vector2i) -> Dictionary:
	var datos: Dictionary = _loaded_chunks.get(_tile_to_chunk(tile), {})
	var valores: Variant = datos.get("biomas", null)
	if valores is PackedInt32Array:
		var local := _tile_to_local(tile)
		var size: int = chunk_size_tiles + CHUNK_PADDING * 2
		var indice: int = (local.y + CHUNK_PADDING) * size + local.x + CHUNK_PADDING
		var biomas: PackedInt32Array = valores
		if indice >= 0 and indice < biomas.size():
			var bioma_index: int = biomas[indice]
			if bioma_index >= 0 and bioma_index < _biomas.size():
				return _biomas[bioma_index]
	var indice_directo: int = _bioma_index_at_tile(tile)
	if indice_directo >= 0 and indice_directo < _biomas.size():
		return _biomas[indice_directo]
	return {}

func get_ecosistema_at(tile: Vector2i) -> Dictionary:
	var datos: Dictionary = _loaded_chunks.get(_tile_to_chunk(tile), {})
	var valores: Variant = datos.get("ecosistemas", null)
	if valores is PackedInt32Array:
		var local := _tile_to_local(tile)
		var size: int = chunk_size_tiles + CHUNK_PADDING * 2
		var indice: int = (local.y + CHUNK_PADDING) * size + local.x + CHUNK_PADDING
		var ecosistemas: PackedInt32Array = valores
		if indice >= 0 and indice < ecosistemas.size():
			var ecosistema_index: int = ecosistemas[indice]
			if ecosistema_index >= 0 and ecosistema_index < _ecosistemas.size():
				return _ecosistemas[ecosistema_index]
	var bioma_index: int = _bioma_index_at_tile(tile)
	var indice_directo: int = _ecosistema_index_at_tile(tile, bioma_index)
	if indice_directo >= 0 and indice_directo < _ecosistemas.size():
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


func obtener_estado_generacion() -> Dictionary:
	if _generation_task.is_empty():
		if not _paused_generation_task.is_empty():
			var etapa_pausada := "DATOS"
			match int(_paused_generation_task.get("stage", 0)):
				1: etapa_pausada = "PINTADO"
				2: etapa_pausada = "FLUSH"
			return {
				"activa": false,
				"pausada": true,
				"etapa": etapa_pausada,
				"cursor": int(_paused_generation_task.get("cursor", 0)),
				"total": chunk_size_tiles * chunk_size_tiles,
				"chunk": _paused_generation_task.get("coord", Vector2i.ZERO),
				"chunks_cargados": _loaded_chunks.size(),
				"biomas": _biomas.size(),
				"ecosistemas": _ecosistemas.size()
			}
		return {"activa": false, "pausada": false, "etapa": "IDLE", "cursor": 0, "total": 0}
	var etapa := "DATOS"
	match int(_generation_task.get("stage", 0)):
		1: etapa = "PINTADO"
		2: etapa = "FLUSH"
	return {
		"activa": true,
		"etapa": etapa,
		"cursor": int(_generation_task.get("cursor", 0)),
		"total": (chunk_size_tiles + CHUNK_PADDING * 2) * (chunk_size_tiles + CHUNK_PADDING * 2) if etapa == "DATOS" else chunk_size_tiles * chunk_size_tiles,
		"chunk": _generation_task.get("coord", Vector2i.ZERO),
		"chunks_cargados": _loaded_chunks.size(),
		"biomas": _biomas.size(),
		"ecosistemas": _ecosistemas.size()
	}

func obtener_diagnostico() -> Dictionary:
	var estado := obtener_estado_generacion()
	estado["visual"] = visual != null
	estado["ultimo_chunk"] = _ultimo_chunk_generado
	estado["descarga_activa"] = tiene_descarga_activa()
	estado["chunk_cache"] = _chunk_cache.size()
	estado["chunk_cache_max"] = chunk_cache_max
	# Diagnóstico explícito del pipeline para que F4 permita localizar el
	# cuello sin depender de los prints de cada chunk.
	estado["profiler_generacion"] = {
		"datos_ms": _profiler_data_ms,
		"datos_max_step_ms": _profiler_data_max_ms,
		"bioma_ms": _profiler_biome_ms,
		"ecosistema_ms": _profiler_ecosystem_ms,
		"zona_ms": _profiler_zone_ms,
		"pintado_ms": _profiler_paint_ms,
		"pintado_max_step_ms": _profiler_paint_max_ms,
		"flush_ms": _profiler_flush_ms,
		"flush_max_step_ms": _profiler_flush_max_ms,
		"datos_llamadas": _profiler_data_calls,
		"pintado_llamadas": _profiler_paint_calls,
		"flush_llamadas": _profiler_flushes,
		"primer_commit_visual_ms": _profiler_first_commit_ms,
		"visible_25_ms": _profiler_visible_25_ms,
		"visible_50_ms": _profiler_visible_50_ms,
		"visible_100_ms": _profiler_visible_100_ms,
		"visible_cells": _profiler_visible_cells
	}
	estado["generacion_pausada"] = tiene_generacion_pausada()
	if tiene_generacion_pausada():
		estado["chunk_pausado"] = _paused_generation_task.get("coord", Vector2i.ZERO)
		estado["etapa_pausada"] = int(_paused_generation_task.get("stage", 0))
		estado["cursor_pausado"] = int(_paused_generation_task.get("cursor", 0))
	if visual != null and visual.has_method("obtener_profiler"):
		estado["visual_profiler"] = visual.obtener_profiler()
	if visual != null and visual.has_method("obtener_estado_flush"):
		estado["flush_estado"] = visual.obtener_estado_flush()
	return estado
