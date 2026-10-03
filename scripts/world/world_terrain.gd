extends Node2D
class_name WorldTerrain


const TILESET_TEXTURE_PATH: String = (
	"res://assets/tilesets/world_tileset.png"
)

const CHUNK_PADDING: int = 1


const T_GRASS: Vector2i = Vector2i(0, 0)
const T_DIRT: Vector2i = Vector2i(1, 0)
const T_STONE: Vector2i = Vector2i(2, 0)
const T_SAND: Vector2i = Vector2i(3, 0)
const T_WATER: Vector2i = Vector2i(4, 0)
const T_DEEP_WATER: Vector2i = Vector2i(5, 0)
const T_WATER_SHORE: Vector2i = Vector2i(6, 0)
const T_ICE: Vector2i = Vector2i(7, 0)


enum Zone {
	GRASS,
	DIRT,
	STONE,
	SAND,
	WATER,
	DEEP_WATER,
	SHORE,
	ICE
}


var map_seed: int = 0
var tile_size: int = 32
var chunk_size_tiles: int = 32


var tilemap_ground: TileMapLayer
var tilemap_detail: TileMapLayer
var tilemap_dual_grass: TileMapDual
var tilemap_dual_dirt: TileMapDual


var _biomas: Array = []
var _ecosistemas: Array = []

var _ecosistema_indices: Dictionary = {}

var _loaded_chunks: Dictionary = {}

var _generation_task: Dictionary = {}

var _ultimo_chunk_generado: Vector2i = Vector2i.ZERO


var _biome_noise: FastNoiseLite
var _ecosystem_noise: FastNoiseLite
var _terrain_noise: FastNoiseLite
var _detail_noise: FastNoiseLite


func configurar(
	nuevo_seed: int,
	nuevo_tile_size: int,
	nuevo_chunk_size: int
) -> void:
	map_seed = nuevo_seed
	tile_size = nuevo_tile_size
	chunk_size_tiles = nuevo_chunk_size

	_crear_capas()
	_crear_tileset()
	_crear_noises()


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

	print(
		"WorldTerrain: biomas = ",
		_biomas.size()
	)

	print(
		"WorldTerrain: ecosistemas = ",
		_ecosistemas.size()
	)


func _crear_capas() -> void:
	if tilemap_ground == null:
		tilemap_ground = TileMapLayer.new()
		tilemap_ground.name = "GroundLegacy"
		add_child(tilemap_ground)

	if tilemap_detail == null:
		tilemap_detail = TileMapLayer.new()
		tilemap_detail.name = "Detail"
		add_child(tilemap_detail)

	if tilemap_dual_grass == null:
		tilemap_dual_grass = TileMapDual.new()
		tilemap_dual_grass.name = "TileMapDual_Grass"
		tilemap_dual_grass.godot_4_3_compatibility = false
		add_child(tilemap_dual_grass)

	if tilemap_dual_dirt == null:
		tilemap_dual_dirt = TileMapDual.new()
		tilemap_dual_dirt.name = "TileMapDual_Dirt"
		tilemap_dual_dirt.godot_4_3_compatibility = false
		add_child(tilemap_dual_dirt)

	# El terreno siempre queda detrás de personajes, criaturas y entidades.
	# Las capas Dual reemplazan visualmente al GroundLegacy para los terrenos
	# que ya tienen sprites de transición.
	tilemap_ground.z_index = -2
	tilemap_dual_grass.z_index = -1
	tilemap_dual_dirt.z_index = -1
	tilemap_detail.z_index = 0


func _crear_tileset() -> void:
	var texture: Texture2D = load(
		TILESET_TEXTURE_PATH
	) as Texture2D

	if texture == null:
		push_error(
			"WorldTerrain: no se pudo cargar "
			+ TILESET_TEXTURE_PATH
		)
		return

	var tileset := TileSet.new()

	tileset.tile_size = Vector2i(
		tile_size,
		tile_size
	)

	var atlas := TileSetAtlasSource.new()

	atlas.texture = texture

	atlas.texture_region_size = Vector2i(
		tile_size,
		tile_size
	)

	var tiles_x: int = (
		texture.get_width() / tile_size
	)

	var tiles_y: int = (
		texture.get_height() / tile_size
	)

	for y in range(tiles_y):
		for x in range(tiles_x):
			atlas.create_tile(
				Vector2i(x, y)
			)

	tileset.add_source(
		atlas,
		0
	)

	tilemap_ground.tile_set = tileset
	tilemap_detail.tile_set = tileset

	var grass_tileset := _crear_tileset_dual(
		"res://assets/tilesets/Grass.png"
	)
	var dirt_tileset := _crear_tileset_dual(
		"res://assets/tilesets/Dirt.png"
	)

	if tilemap_dual_grass != null:
		tilemap_dual_grass.tile_set = grass_tileset

	if tilemap_dual_dirt != null:
		tilemap_dual_dirt.tile_set = dirt_tileset


func _crear_noises() -> void:
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = map_seed + 1001
	_biome_noise.frequency = 0.006

	_ecosystem_noise = FastNoiseLite.new()
	_ecosystem_noise.seed = map_seed + 2002
	_ecosystem_noise.frequency = 0.020

	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.seed = map_seed + 3003
	_terrain_noise.frequency = 0.045

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = map_seed + 4004
	_detail_noise.frequency = 0.12


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
			zona_final
		)

		_pintar_detalle(
			tile,
			zona_final
		)

		cursor += 1

	_generation_task["cursor"] = cursor

	if cursor < total:
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
		"biomas": _generation_task["biomas"],
		"ecosistemas": _generation_task["ecosistemas"]
	}

	_ultimo_chunk_generado = coord

	# TileMapDual solo recalcula las celdas de su propio terreno.
	# Antes actualizábamos Grass + Dirt con las 1024 celdas completas
	# del chunk, duplicando el trabajo del addon.
	var zonas_finales: Array = _generation_task["zonas"]
	var celdas_grass: Array[Vector2i] = _celdas_dual_del_chunk(
		coord,
		zonas_finales,
		Zone.GRASS
	)
	var celdas_dirt: Array[Vector2i] = _celdas_dual_del_chunk(
		coord,
		zonas_finales,
		Zone.DIRT
	)
	_refrescar_dual(celdas_grass, celdas_dirt)
	_promover_chunk_a_dual(
		coord,
		zonas_finales
	)

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

	var origin_x: int = (
		chunk_coord.x
		* chunk_size_tiles
	)

	var origin_y: int = (
		chunk_coord.y
		* chunk_size_tiles
	)

	for y in range(chunk_size_tiles):
		for x in range(chunk_size_tiles):
			var cell := Vector2i(
				origin_x + x,
				origin_y + y
			)

			tilemap_ground.erase_cell(
				cell
			)

			tilemap_detail.erase_cell(
				cell
			)

			if tilemap_dual_grass != null:
				tilemap_dual_grass.erase_cell(cell)

			if tilemap_dual_dirt != null:
				tilemap_dual_dirt.erase_cell(cell)

	_loaded_chunks.erase(
		chunk_coord
	)

	# Al descargar, solo recalculamos la frontera del chunk.
	# Esto permite que los vecinos pierdan correctamente las transiciones.
	var celdas_frontera: Array[Vector2i] = _celdas_frontera_chunk(
		chunk_coord
	)
	_refrescar_dual(celdas_frontera, celdas_frontera)


func _bioma_index_at_tile(
	tile: Vector2i
) -> int:
	if _biomas.is_empty():
		return -1

	if _biome_noise == null:
		return -1

	var valor: float = _biome_noise.get_noise_2d(
		tile.x,
		tile.y
	)

	# FastNoiseLite produce valores en [-1, 1] con
	# distribución aproximadamente uniforme a baja
	# frecuencia. Normalizamos directamente sin
	# redistribución para que cada bioma ocupe una
	# franja igual del rango y ninguno domine el mapa.
	var normalizado: float = (
		valor + 1.0
	) * 0.5

	var indice: int = floori(
		normalizado * _biomas.size()
	)

	return clampi(
		indice,
		0,
		_biomas.size() - 1
	)

func _ecosistema_index_at_tile(
	tile: Vector2i,
	bioma_index: int
) -> int:
	if (
		bioma_index < 0
		or bioma_index >= _biomas.size()
	):
		return -1

	var bioma_variant: Variant = (
		_biomas[bioma_index]
	)

	if not bioma_variant is Dictionary:
		return -1

	var bioma: Dictionary = (
		bioma_variant
	)

	var ecosistemas_variant: Variant = (
		bioma.get(
			"ecosistemas",
			[]
		)
	)

	if not ecosistemas_variant is Array:
		return -1

	var ecosistemas: Array = (
		ecosistemas_variant
	)

	if ecosistemas.is_empty():
		return -1

	if _ecosystem_noise == null:
		return -1

	var valor: float = (
		_ecosystem_noise.get_noise_2d(
			tile.x,
			tile.y
		)
	)

	var normalizado: float = (
		(valor + 1.0) * 0.5
	)

	var local_index: int = floori(
		normalizado
		* ecosistemas.size()
	)

	local_index = clampi(
		local_index,
		0,
		ecosistemas.size() - 1
	)

	var ecosistema_variant: Variant = (
		ecosistemas[local_index]
	)

	if not ecosistema_variant is Dictionary:
		return -1

	var ecosistema: Dictionary = (
		ecosistema_variant
	)

	var id: String = str(
		ecosistema.get(
			"id",
			""
		)
	)

	if id.is_empty():
		return -1

	return int(
		_ecosistema_indices.get(
			id,
			-1
		)
	)


func _zona_base_at_tile(
	tile: Vector2i,
	bioma_index: int,
	ecosistema_index: int
) -> int:
	var bioma_nombre: String = ""
	var ecosistema_nombre: String = ""

	if (
		bioma_index >= 0
		and bioma_index < _biomas.size()
	):
		var bioma_variant: Variant = (
			_biomas[bioma_index]
		)

		if bioma_variant is Dictionary:
			var bioma: Dictionary = (
				bioma_variant
			)

			bioma_nombre = str(
				bioma.get(
					"nombre",
					""
				)
			).to_lower()

	if (
		ecosistema_index >= 0
		and ecosistema_index < _ecosistemas.size()
	):
		var ecosistema_variant: Variant = (
			_ecosistemas[ecosistema_index]
		)

		if ecosistema_variant is Dictionary:
			var ecosistema: Dictionary = (
				ecosistema_variant
			)

			ecosistema_nombre = str(
				ecosistema.get(
					"nombre",
					""
				)
			).to_lower()

	if _terrain_noise == null:
		return Zone.GRASS

	var terreno: float = (
		_terrain_noise.get_noise_2d(
			tile.x,
			tile.y
		)
	)

	if "marino" in bioma_nombre:
		if "profundo" in ecosistema_nombre:
			return Zone.DEEP_WATER

		if terreno < -0.20:
			return Zone.DEEP_WATER

		return Zone.WATER

	if "agua dulce" in bioma_nombre:
		if terreno < -0.35:
			return Zone.DEEP_WATER

		return Zone.WATER

	if "humedal" in bioma_nombre:
		if terreno < -0.30:
			return Zone.WATER

		if terreno < 0.10:
			return Zone.DIRT

		return Zone.GRASS

	if "desierto" in bioma_nombre:
		if terreno > 0.65:
			return Zone.STONE

		return Zone.SAND

	if "montaña" in bioma_nombre:
		if terreno > 0.30:
			return Zone.STONE

		return Zone.GRASS

	if "tundra" in bioma_nombre:
		if terreno > 0.30:
			return Zone.STONE

		return Zone.ICE

	if "pradera" in bioma_nombre:
		if terreno < -0.35:
			return Zone.DIRT

		return Zone.GRASS

	if terreno > 0.65:
		return Zone.STONE

	if terreno < -0.45:
		return Zone.DIRT

	return Zone.GRASS


func _zona_final_desde_array(
	zonas: Array,
	x: int,
	y: int,
	zona_base: int
) -> int:
	if (
		zona_base != Zone.WATER
		and zona_base != Zone.DEEP_WATER
	):
		return zona_base

	if _agua_toca_tierra_en_array(
		zonas,
		x,
		y
	):
		return Zone.SHORE

	return zona_base


func _agua_toca_tierra_en_array(
	zonas: Array,
	x: int,
	y: int
) -> bool:
	var direcciones := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for i in range(direcciones.size()):
		var direccion: Vector2i = (
			direcciones[i]
		)

		var nx: int = x + direccion.x
		var ny: int = y + direccion.y

		if ny < 0:
			continue

		if ny >= zonas.size():
			continue

		if nx < 0:
			continue

		if nx >= zonas[ny].size():
			continue

		var vecino: int = int(
			zonas[ny][nx]
		)

		if (
			vecino != Zone.WATER
			and vecino != Zone.DEEP_WATER
		):
			return true

	return false


func _pintar_tile(
	tile: Vector2i,
	zona: int
) -> void:
	match zona:
		Zone.GRASS:
			# Mostrar inmediatamente el terreno base mientras TileMapDual
			# termina de calcular sus transiciones. Esto evita que el mundo
			# quede vacío durante la generación de los chunks.
			tilemap_ground.set_cell(
				tile,
				0,
				T_GRASS
			)
			if tilemap_dual_dirt != null:
				tilemap_dual_dirt.erase_cell(tile)

		Zone.DIRT:
			# Igual que Grass: primero aparece el tile base y después
			# TileMapDual lo reemplaza visualmente por la transición correcta.
			tilemap_ground.set_cell(
				tile,
				0,
				T_DIRT
			)
			if tilemap_dual_grass != null:
				tilemap_dual_grass.erase_cell(tile)

		_:
			if tilemap_dual_grass != null:
				tilemap_dual_grass.erase_cell(tile)
			if tilemap_dual_dirt != null:
				tilemap_dual_dirt.erase_cell(tile)

			var atlas_coord: Vector2i = _tile_for_zone(zona)
			tilemap_ground.set_cell(tile, 0, atlas_coord)


func _crear_tileset_dual(
	texture_path: String
) -> TileSet:
	var texture: Texture2D = load(texture_path) as Texture2D

	if texture == null:
		push_error(
			"WorldTerrain: no se pudo cargar " + texture_path
		)
		return TileSet.new()

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(tile_size, tile_size)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(tile_size, tile_size)

	var tiles_x: int = texture.get_width() / tile_size
	var tiles_y: int = texture.get_height() / tile_size

	for y in range(tiles_y):
		for x in range(tiles_x):
			atlas.create_tile(Vector2i(x, y))

	tile_set.add_source(atlas, 0)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(
		0,
		TileSet.TERRAIN_MODE_MATCH_CORNERS
	)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "<any>")
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 1, "Terrain")

	var sequence: Array[Vector2i] = [
		Vector2i(0, 3), Vector2i(3, 3),
		Vector2i(0, 2), Vector2i(1, 2),
		Vector2i(0, 0), Vector2i(3, 2),
		Vector2i(2, 3), Vector2i(3, 1),
		Vector2i(1, 3), Vector2i(0, 1),
		Vector2i(1, 0), Vector2i(2, 2),
		Vector2i(3, 0), Vector2i(2, 0),
		Vector2i(1, 1), Vector2i(2, 1),
	]

	var neighbors: Array[TileSet.CellNeighbor] = [
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	]

	for index in range(sequence.size()):
		var data: TileData = atlas.get_tile_data(sequence[index], 0)
		data.terrain_set = 0
		var bits: int = index
		for neighbor_index in range(neighbors.size()):
			var terrain: int = 1 if (bits & 1) != 0 else 0
			data.set_terrain_peering_bit(
				neighbors[neighbor_index],
				terrain
			)
			bits >>= 1

	atlas.get_tile_data(Vector2i(0, 3), 0).terrain = 0
	atlas.get_tile_data(Vector2i(2, 1), 0).terrain = 1

	return tile_set


func _refrescar_dual(
	celdas_grass: Array[Vector2i],
	celdas_dirt: Array[Vector2i]
) -> void:
	if tilemap_dual_grass != null and not celdas_grass.is_empty():
		tilemap_dual_grass._update_cells(celdas_grass, false)

	if tilemap_dual_dirt != null and not celdas_dirt.is_empty():
		tilemap_dual_dirt._update_cells(celdas_dirt, false)


func _promover_chunk_a_dual(
	coord: Vector2i,
	zonas: Array
) -> void:
	# El GroundLegacy ya cumplió su función de placeholder inmediato.
	# Una vez calculado TileMapDual, retiramos únicamente los tiles base
	# que pertenecen a este chunk.
	for y in range(chunk_size_tiles):
		for x in range(chunk_size_tiles):
			var padded_x: int = x + CHUNK_PADDING
			var padded_y: int = y + CHUNK_PADDING
			var zona: int = int(zonas[padded_y][padded_x])

			if zona != Zone.GRASS and zona != Zone.DIRT:
				continue

			var cell := Vector2i(
				coord.x * chunk_size_tiles + x,
				coord.y * chunk_size_tiles + y
			)

			tilemap_ground.erase_cell(cell)


func _celdas_dual_del_chunk(
	coord: Vector2i,
	zonas: Array,
	terreno: int
) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	var vistos: Dictionary = {}

	for y in range(chunk_size_tiles):
		for x in range(chunk_size_tiles):
			var padded_x: int = x + CHUNK_PADDING
			var padded_y: int = y + CHUNK_PADDING

			if int(zonas[padded_y][padded_x]) != terreno:
				continue

			var cell := Vector2i(
				coord.x * chunk_size_tiles + x,
				coord.y * chunk_size_tiles + y
			)
			_agregar_celda_dual_unica(resultado, vistos, cell)

			# Solo añadimos vecinos fuera del chunk. Los cambios internos
			# ya están cubiertos por las propias celdas modificadas.
			if x == 0:
				_agregar_celda_dual_unica(
					resultado, vistos, cell + Vector2i(-1, 0)
				)
			if x == chunk_size_tiles - 1:
				_agregar_celda_dual_unica(
					resultado, vistos, cell + Vector2i(1, 0)
				)
			if y == 0:
				_agregar_celda_dual_unica(
					resultado, vistos, cell + Vector2i(0, -1)
				)
			if y == chunk_size_tiles - 1:
				_agregar_celda_dual_unica(
					resultado, vistos, cell + Vector2i(0, 1)
				)

	return resultado


func _celdas_frontera_chunk(
	chunk_coord: Vector2i
) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	var vistos: Dictionary = {}

	var ox: int = chunk_coord.x * chunk_size_tiles
	var oy: int = chunk_coord.y * chunk_size_tiles

	for i in range(chunk_size_tiles):
		var c1 := Vector2i(ox + i, oy)
		var c2 := Vector2i(
			ox + i,
			oy + chunk_size_tiles - 1
		)
		var c3 := Vector2i(ox, oy + i)
		var c4 := Vector2i(
			ox + chunk_size_tiles - 1,
			oy + i
		)

		_agregar_celda_dual_unica(resultado, vistos, c1)
		_agregar_celda_dual_unica(resultado, vistos, c2)
		_agregar_celda_dual_unica(resultado, vistos, c3)
		_agregar_celda_dual_unica(resultado, vistos, c4)

	return resultado


func _agregar_celda_dual_unica(
	resultado: Array[Vector2i],
	vistos: Dictionary,
	cell: Vector2i
) -> void:
	if vistos.has(cell):
		return

	vistos[cell] = true
	resultado.append(cell)


func _tile_for_zone(
	zona: int
) -> Vector2i:
	match zona:
		Zone.GRASS:
			return T_GRASS

		Zone.DIRT:
			return T_DIRT

		Zone.STONE:
			return T_STONE

		Zone.SAND:
			return T_SAND

		Zone.WATER:
			return T_WATER

		Zone.DEEP_WATER:
			return T_DEEP_WATER

		Zone.SHORE:
			return T_WATER_SHORE

		Zone.ICE:
			return T_ICE

		_:
			return T_GRASS


func _pintar_detalle(
	tile: Vector2i,
	zona: int
) -> void:
	tilemap_detail.erase_cell(
		tile
	)

	if zona != Zone.GRASS:
		return

	if _detail_noise == null:
		return

	var valor: float = (
		_detail_noise.get_noise_2d(
			tile.x,
			tile.y
		)
	)

	if valor < 0.72:
		return


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
