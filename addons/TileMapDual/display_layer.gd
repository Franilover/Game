@tool
class_name DisplayLayer
extends TileMapLayer
##[br] A single TileMapLayer whose purpose is to display tiles to maintain the Dual Grid illusion.
##[br] Its contents are automatically computed and updated based on:
##[br] - the contents of the parent TileMapDual
##[br] - the rules set in its assigned TerrainLayer

##[br] How much to offset this DisplayLayer relative to the main TileMapDual grid.
##[br] This is independent of tile size.
var offset: Vector2
## See [TileSetWatcher]
var _tileset_watcher: TileSetWatcher
## See [TerrainDual]
var _terrain: TerrainLayer
# Paths invertidos cacheados: el Dual-Grid los usa en cada actualización.
# Evita reconstruir Arrays con map(Util.reverse_neighbor) para cada flush.
var _reverse_display_paths: Array[Array] = []
# Buffer reutilizable: update_tile() se ejecuta miles de veces durante un flush.
# Evita crear un Array temporal por cada celda recompuesta.
var _terrain_neighbors_scratch: Array = []
# Reutilizado entre flushes para evitar crear un Dictionary por actualización.
var _already_updated: Dictionary = {}
# Cache de vecindad por celda dual. Si los terrenos vecinos no cambian y el
# tile actual sigue presente, no hace falta volver a recorrer las reglas.
var _terrain_signature_by_cell: Dictionary = {}

# Diagnóstico acumulado del camino caliente del Dual Grid.
var _diag_update_calls: int = 0
var _diag_world_cells: int = 0
var _diag_display_candidates: int = 0
var _diag_rule_evaluations: int = 0
var _diag_redundant_tiles: int = 0
var _diag_cached_rule_skips: int = 0
var _diag_set_cells: int = 0
# Tiempos acumulados: flush completo y muestreo ligero de fases internas.
var _diag_flush_calls: int = 0
var _diag_flush_ms: float = 0.0
var _diag_flush_ms_max: float = 0.0
var _diag_sample_count: int = 0
var _diag_sample_path_ms: float = 0.0
var _diag_sample_rule_ms: float = 0.0
var _diag_sample_write_ms: float = 0.0
var _diag_reverse_path_samples: int = 0
var _diag_reverse_path_calls: int = 0
var _diag_sample_reverse_path_ms: float = 0.0


func _init(
		world: TileMapDual = null,
		tileset_watcher: TileSetWatcher = null,
		fields: Dictionary = {},
		layer: TerrainLayer = null,
) -> void:
	# Compatibilidad con DisplayLayer que pudo quedar serializado dentro de
	# una escena antigua. El Display padre lo reemplazará al reconstruir capas.
	if world != null and tileset_watcher != null and layer != null:
		inicializar(world, tileset_watcher, fields, layer)


func inicializar(
		world: TileMapDual,
		tileset_watcher: TileSetWatcher,
		fields: Dictionary,
		layer: TerrainLayer,
) -> void:
	update_properties(world)
	offset = fields.get("offset", Vector2.ZERO)
	_tileset_watcher = tileset_watcher
	_terrain = layer
	_reverse_display_paths.clear()
	for path: Array in _terrain.display_to_world_neighborhood:
		var reverse_path: Array = []
		for neighbor: TileSet.CellNeighbor in path:
			reverse_path.append(Util.reverse_neighbor(neighbor))
		_reverse_display_paths.append(reverse_path)
	tile_set = tileset_watcher.tile_set
	if not tileset_watcher.tileset_resized.is_connected(reposition):
		tileset_watcher.tileset_resized.connect(reposition, 1)
	reposition()


## Adjusts the position of this DisplayLayer based on the tile set's tile_size
func reposition() -> void:
	position = offset * Vector2(_tileset_watcher.tile_size)


## Copies properties from parent TileMapDual to child display tilemap
func update_properties(parent: TileMapDual) -> void:
	# Both tilemaps must be the same, so we copy all relevant properties
	# Tilemap
	# already covered by parent._tileset_watcher
	# Rendering
	self.y_sort_origin = parent.y_sort_origin
	self.x_draw_order_reversed = parent.x_draw_order_reversed
	self.rendering_quadrant_size = parent.rendering_quadrant_size
	# DisplayLayer solo recompone la imagen Dual Grid. La colisión y la
	# navegación pertenecen exclusivamente al TileMapDual fuente: duplicarlas
	# aquí desplaza las formas medio tile y crea superficies fantasma.
	self.collision_enabled = false
	self.navigation_enabled = false
	# Canvas item properties
	self.show_behind_parent = parent.show_behind_parent
	self.top_level = parent.top_level
	# DisplayLayer es quien realmente dibuja los tiles. No confiar en la
	# herencia implícita de Z: TileMapDual puede usar z_as_relative=false.
	# Copiamos la capa Z efectiva para que el display respete exactamente
	# el orden del TileMapDual que lo contiene.
	self.z_as_relative = false
	self.z_index = parent.z_index
	self.light_mask = parent.light_mask
	self.visibility_layer = parent.visibility_layer
	self.y_sort_enabled = parent.y_sort_enabled
	self.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	self.modulate = parent.modulate
	self.self_modulate = parent.self_modulate
	# NOTE: parent material takes priority over the current shaders,
	# causing the world tiles to show up
	self.use_parent_material = parent.use_parent_material

	# Save any manually introduced Material change:
	self.material = parent.display_material


## Updates all display tiles to reflect the current changes.
func update_tiles_all(cache: TileCache) -> void:
	# Una reconstrucción completa debe volver a evaluar todas las reglas.
	_terrain_signature_by_cell.clear()
	update_tiles(cache, cache.cells.keys())


## Update all display tiles affected by the world cells
func update_tiles(cache: TileCache, updated_world_cells: Array) -> void:
	# Restaurar la semántica original del addon: cada DisplayLayer calcula
	# la celda dual afectada siguiendo la ruta inversa exacta. La optimización
	# por offsets precomputados puede alterar la semántica de las esquinas.
	var flush_start_usec: int = Time.get_ticks_usec()
	_already_updated.clear()
	for reverse_path: Array in _reverse_display_paths:
		for world_cell: Vector2i in updated_world_cells:
			var sample_reverse_path: bool = (_diag_reverse_path_calls % 64) == 0
			var reverse_path_started_usec: int = Time.get_ticks_usec() if sample_reverse_path else 0
			var display_cell: Vector2i = follow_path(world_cell, reverse_path)
			if sample_reverse_path:
				_diag_sample_reverse_path_ms += float(Time.get_ticks_usec() - reverse_path_started_usec) / 1000.0
				_diag_reverse_path_samples += 1
			_diag_reverse_path_calls += 1
			if not _already_updated.has(display_cell):
				_already_updated[display_cell] = true
				_diag_display_candidates += 1
				update_tile(cache, display_cell)
	var flush_ms: float = float(Time.get_ticks_usec() - flush_start_usec) / 1000.0
	_diag_flush_calls += 1
	_diag_flush_ms += flush_ms
	_diag_flush_ms_max = maxf(_diag_flush_ms_max, flush_ms)


## Updates a specific world cell.
func update_tile(cache: TileCache, cell: Vector2i) -> void:
	var sample: bool = (_diag_update_calls % 64) == 0
	var sample_start_usec: int = Time.get_ticks_usec() if sample else 0
	_terrain_neighbors_scratch.clear()
	for path: Array in _terrain.display_to_world_neighborhood:
		_terrain_neighbors_scratch.append(
			cache.get_terrain_at(follow_path(cell, path))
		)
	if sample:
		_diag_sample_path_ms += float(Time.get_ticks_usec() - sample_start_usec) / 1000.0
		sample_start_usec = Time.get_ticks_usec()

	var cached_variant: Variant = _terrain_signature_by_cell.get(cell, null)
	if cached_variant is Dictionary:
		var cached := cached_variant as Dictionary
		var vecinos_variant: Variant = cached.get("neighbors", [])
		if vecinos_variant is Array and _coincide_vecindad(vecinos_variant as Array):
			var cached_sid := int(cached.get("sid", -1))
			var cached_tile: Vector2i = cached.get("tile", Vector2i(-1, -1))
			var current_sid := get_cell_source_id(cell)
			if current_sid == cached_sid and (cached_sid == -1 or get_cell_atlas_coords(cell) == cached_tile):
				_diag_cached_rule_skips += 1
				return

	_diag_update_calls += 1
	_diag_world_cells += 1
	_diag_rule_evaluations += 1
	var mapping: Dictionary = _terrain.apply_rule(_terrain_neighbors_scratch, cell)
	if sample:
		_diag_sample_rule_ms += float(Time.get_ticks_usec() - sample_start_usec) / 1000.0
		_diag_sample_count += 1
		sample_start_usec = Time.get_ticks_usec()
	var sid: int = int(mapping.get("sid", -1))
	var tile: Vector2i = mapping.get("tile", Vector2i(-1, -1))
	_terrain_signature_by_cell[cell] = {
		"neighbors": _terrain_neighbors_scratch.duplicate(),
		"sid": sid,
		"tile": tile,
	}

	var current_sid: int = get_cell_source_id(cell)
	if current_sid == sid:
		if sid == -1 or get_cell_atlas_coords(cell) == tile:
			_diag_redundant_tiles += 1
			return

	_diag_set_cells += 1
	set_cell(cell, sid, tile)
	if sample:
		_diag_sample_write_ms += float(Time.get_ticks_usec() - sample_start_usec) / 1000.0


func _coincide_vecindad(cached_neighbors: Array) -> bool:
	if cached_neighbors.size() != _terrain_neighbors_scratch.size():
		return false
	for index in range(cached_neighbors.size()):
		if int(cached_neighbors[index]) != int(_terrain_neighbors_scratch[index]):
			return false
	return true


func follow_path(cell: Vector2i, path: Array) -> Vector2i:
	for neighbor: TileSet.CellNeighbor in path:
		cell = get_neighbor_cell(cell, neighbor)
	return cell


func obtener_diagnostico() -> Dictionary:
	var candidates: int = _diag_display_candidates
	var redundant: int = _diag_redundant_tiles
	var writes: int = _diag_set_cells
	return {
		"update_calls": _diag_update_calls,
		"world_cells": _diag_world_cells,
		"display_candidates": candidates,
		"rule_evaluations": _diag_rule_evaluations,
		"redundant_tiles": redundant,
		"cached_rule_skips": _diag_cached_rule_skips,
		"set_cells": writes,
		"candidate_per_world_cell": (
			float(candidates) / float(maxi(_diag_world_cells, 1))
		),
		"redundant_ratio": (
			float(redundant) / float(maxi(_diag_rule_evaluations, 1))
		),
		"write_ratio": (
			float(writes) / float(maxi(_diag_rule_evaluations, 1))
		),
		"flush_calls": _diag_flush_calls,
		"flush_ms_total": _diag_flush_ms,
		"flush_ms_max": _diag_flush_ms_max,
		"sample_count": _diag_sample_count,
		"sample_path_ms": _diag_sample_path_ms,
		"sample_rule_ms": _diag_sample_rule_ms,
		"sample_write_ms": _diag_sample_write_ms,
		"reverse_path_calls": _diag_reverse_path_calls,
		"reverse_path_samples": _diag_reverse_path_samples,
		"sample_reverse_path_ms": _diag_sample_reverse_path_ms,
	}


# Fija el origen del patrón procedural en coordenadas del mundo al crear
# cada DisplayLayer. Así no depende de la cámara ni de cambios de streaming.
func fijar_origen_shader() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null or shader_material.shader == null:
		return

	var tiene_origen := false
	for uniforme: Dictionary in shader_material.shader.get_shader_uniform_list():
		if str(uniforme.get("name", "")) == "origen_mundo":
			tiene_origen = true
			break
	if not tiene_origen:
		return

	# Cada DisplayLayer necesita su propia copia: sus offsets dual-grid
	# son distintos y no deben sobrescribirse entre sí.
	var material_local := shader_material.duplicate() as ShaderMaterial
	material_local.set_shader_parameter("origen_mundo", global_position)
	material = material_local
