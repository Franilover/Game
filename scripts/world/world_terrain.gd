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


var _biomas: Array = []
var _ecosistemas: Array = []

var _ecosistema_indices: Dictionary = {}

var _loaded_chunks: Dictionary = {}

var _generation_task: Dictionary = {}
var _pintado_desde_flush: int = 0
@export var visual_flush_cells: int = 256

var _ultimo_chunk_generado: Vector2i = Vector2i.ZERO


func configurar(
	nuevo_seed: int,
	nuevo_tile_size: int,
	nuevo_chunk_size: int
) -> void:
	# WorldTerrain es una capa puramente visual de suelo. Nunca debe
	# quedar por encima de entidades aunque el padre tenga otro z_index.
	z_as_relative = false
	z_index = -4096

	map_seed = nuevo_seed
	tile_size = nuevo_tile_size
	chunk_size_tiles = nuevo_chunk_size

	areas = WorldTerrainAreas.new()
	areas.configurar(map_seed)

	_crear_capas()
	visual.configurar(tile_size)
func cargar_datos_mundo() -> void:
	_biomas.clear()
	_ecosistemas.clear()
	_ecosistema_indices.clear()

	_biomas = WorldData.obtener_biomas()

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
		WorldData.obtener_ecosistemas_sin_bioma()
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
	if visual != null:
		return

	visual = WorldTerrainVisual.new()
	visual.name = "WorldTerrainVisual"
	add_child(visual)
func iniciar_generacion_chunk(
	chunk_coord: Vector2i
) -> void:
	if _loaded_chunks.has(chunk_coord):
		return

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

	return _procesar_pintado_chunk(
		cells
	)


func _procesar_datos_chunk(
	cells: int
) -> bool:
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

		var bioma_index: int = (
			_bioma_index_at_tile(tile)
		)

		var ecosistema_index: int = (
			_ecosistema_index_at_tile(
				tile,
				bioma_index
			)
		)

		var zona: int = (
			_zona_base_at_tile(
				tile,
				bioma_index,
				ecosistema_index
			)
		)

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

	if cursor < total:
		return false

	_generation_task["stage"] = 1
	_generation_task["cursor"] = 0

	return false


func _procesar_pintado_chunk(
	cells: int
) -> bool:
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

		_pintado_desde_flush += 1
		var lote := maxi(visual_flush_cells, 1)
		if _pintado_desde_flush >= lote:
			if visual != null:
				visual.flush()
			_pintado_desde_flush = 0

		cursor += 1

	_generation_task["cursor"] = cursor

	if cursor < total:
		return false

	if visual != null:
		# Publicar cualquier celda restante del lote final.
		visual.flush()

	_pintado_desde_flush = 0
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
		"biomas": _generation_task["biomas"],
		"ecosistemas": _generation_task["ecosistemas"]
	}

	_ultimo_chunk_generado = coord
	_generation_task.clear()
func tiene_generacion_activa() -> bool:
	return not _generation_task.is_empty()


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
	if not _loaded_chunks.has(
		chunk_coord
	):
		return

	if visual != null:
		visual.clear_chunk(
			chunk_coord,
			chunk_size_tiles
		)

	_loaded_chunks.erase(
		chunk_coord
	)
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
	if bioma_index >= 0 and bioma_index < _biomas.size():
		var bioma_variant: Variant = _biomas[bioma_index]
		if bioma_variant is Dictionary:
			bioma_nombre = str(
				(bioma_variant as Dictionary).get("nombre", "")
			)

	visual.set_zone(
		tile,
		zona,
		bioma_nombre
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
