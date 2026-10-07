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
var _reversed_display_offsets: Array[Vector2i] = []
var _terrain_world_offsets: Array[Vector2i] = []
# Buffer reutilizable: update_tile() se ejecuta miles de veces durante un flush.
# Evita crear un Array temporal por cada celda recompuesta.
var _terrain_neighbors_scratch: Array = []
# Reutilizado entre flushes para evitar crear un Dictionary por actualización.
var _already_updated: Dictionary = {}

# Diagnóstico acumulado del camino caliente del Dual Grid.
var _diag_update_calls: int = 0
var _diag_world_cells: int = 0
var _diag_display_candidates: int = 0
var _diag_rule_evaluations: int = 0
var _diag_redundant_tiles: int = 0
var _diag_set_cells: int = 0
var _diag_atlas_tiles: Dictionary = {}


func _init(
		world: TileMapDual,
		tileset_watcher: TileSetWatcher,
		fields: Dictionary,
		layer: TerrainLayer,
) -> void:
	#print('initializing Layer...')
	update_properties(world)
	offset = fields.offset
	_tileset_watcher = tileset_watcher
	_terrain = layer
	tile_set = tileset_watcher.tile_set
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
	# Physics
	self.collision_enabled = parent.collision_enabled
	self.use_kinematic_bodies = parent.use_kinematic_bodies
	self.collision_visibility_mode = parent.collision_visibility_mode
	# Navigation
	self.navigation_enabled = parent.navigation_enabled
	self.navigation_visibility_mode = parent.navigation_visibility_mode
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
	update_tiles(cache, cache.cells.keys())


## Update all display tiles affected by the world cells
func update_tiles(cache: TileCache, updated_world_cells: Array) -> void:
	# Restaurar la semántica original del addon: cada DisplayLayer calcula
	# la celda dual afectada siguiendo la ruta inversa exacta. La optimización
	# por offsets precomputados puede alterar la semántica de las esquinas.
	var already_updated: Dictionary = {}
	for path: Array in _terrain.display_to_world_neighborhood:
		var reverse_path: Array = path.map(Util.reverse_neighbor)
		for world_cell: Vector2i in updated_world_cells:
			var display_cell: Vector2i = follow_path(world_cell, reverse_path)
			if not already_updated.has(display_cell):
				already_updated[display_cell] = true
				_diag_display_candidates += 1
				update_tile(cache, display_cell)


## Updates a specific world cell.
func update_tile(cache: TileCache, cell: Vector2i) -> void:
	var terrain_neighbors: Array = []
	for path: Array in _terrain.display_to_world_neighborhood:
		terrain_neighbors.append(
			cache.get_terrain_at(follow_path(cell, path))
		)

	_diag_update_calls += 1
	_diag_world_cells += 1
	_diag_rule_evaluations += 1
	var mapping: Dictionary = _terrain.apply_rule(terrain_neighbors, cell)
	var sid: int = int(mapping.get("sid", -1))
	var tile: Vector2i = mapping.get("tile", Vector2i(-1, -1))

	if sid != -1:
		var atlas_key := str(tile)
		_diag_atlas_tiles[atlas_key] = int(_diag_atlas_tiles.get(atlas_key, 0)) + 1

	var current_sid: int = get_cell_source_id(cell)
	if current_sid == sid:
		if sid == -1 or get_cell_atlas_coords(cell) == tile:
			_diag_redundant_tiles += 1
			return

	_diag_set_cells += 1
	set_cell(cell, sid, tile)


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
		"atlas_tiles": _diag_atlas_tiles,
	}
