@tool
class_name Display
extends Node2D
##[br] A Node designed to hold and manage up to 2 DisplayLayer children.
##[br] See [DisplayLayer] for details.

## Emitted when the tiles in the map have been edited.
signal world_tiles_changed(changed: Array)

## Every meaningfully different TileSet.tile_shape * TileSet.tile_offset_axis combination.
enum GridShape {
	SQUARE,
	ISO,
	HALF_OFF_HORI,
	HALF_OFF_VERT,
	HEX_HORI,
	HEX_VERT,
}

##[br] How to deal with every available GridShape.
##[br] See [DisplayLayer] for more information about these fields.
const GRIDS: Dictionary[GridShape, Array] = {
	GridShape.SQUARE: [
		{
			# []
			'offset': Vector2(-0.5, -0.5),
		},
	],
	GridShape.ISO: [
		{
			# <>
			'offset': Vector2(0, -0.5),
		},
	],
	GridShape.HALF_OFF_HORI: [
		{
			# v
			'offset': Vector2(0.0, -0.5),
		},
		{
			# ^
			'offset': Vector2(-0.5, -0.5),
		},
	],
	GridShape.HALF_OFF_VERT: [
		{
			# >
			'offset': Vector2(-0.5, 0.0),
		},
		{
			# <
			'offset': Vector2(-0.5, -0.5),
		},
	],
	GridShape.HEX_HORI: [
		{
			# v
			'offset': Vector2(0.0, -3.0 / 8.0),
		},
		{
			# ^
			'offset': Vector2(-0.5, -3.0 / 8.0),
		},
	],
	GridShape.HEX_VERT: [
		{
			# >
			'offset': Vector2(-3.0 / 8.0, 0.0),
		},
		{
			# <
			'offset': Vector2(-3.0 / 8.0, -0.5),
		},
	],
}

## The parent TileMapDual to base the terrains off of.
@export var world: TileMapDual

## See [TerrainDual]
var terrain: TerrainDual
## The TileCache computed from the last time update() was called.
var cached_cells := TileCache.new()
## See [TileSetWatcher]
var _tileset_watcher: TileSetWatcher
var _last_synced_world_properties: Dictionary = {}

# Perfilado por lote para separar cache de terreno y recomposición visual.
var _diag_update_calls: int = 0
var _diag_update_ms: float = 0.0
var _diag_cache_ms: float = 0.0
var _diag_renderer_ms: float = 0.0
var _diag_update_ms_max: float = 0.0


# TODO: phase out GridShape and simply transpose everything when the offset axis is vertical
##[br] Returns what kind of grid a TileSet is.
##[br] Will default to SQUARE if Godot decides to add a new TileShape.
static func tileset_gridshape(tile_set: TileSet) -> GridShape:
	var hori: bool = tile_set.tile_offset_axis == TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	match tile_set.tile_shape:
		TileSet.TileShape.TILE_SHAPE_SQUARE:
			return GridShape.SQUARE
		TileSet.TileShape.TILE_SHAPE_ISOMETRIC:
			return GridShape.ISO
		TileSet.TileShape.TILE_SHAPE_HALF_OFFSET_SQUARE:
			return GridShape.HALF_OFF_HORI if hori else GridShape.HALF_OFF_VERT
		TileSet.TileShape.TILE_SHAPE_HEXAGON:
			return GridShape.HEX_HORI if hori else GridShape.HEX_VERT
		_:
			return GridShape.SQUARE


## Creates a new Display that updates when the TileSet updates.
func _init(world: TileMapDual = null, tileset_watcher: TileSetWatcher = null) -> void:
	# Una versión anterior del constructor pudo serializar este nodo dentro
	# de la escena. En ese caso Godot lo reconstruye con _init() sin argumentos;
	# TileMapDual lo inicializará desde su propio _ready().
	if world != null and tileset_watcher != null:
		inicializar(world, tileset_watcher)


func inicializar(world_node: TileMapDual, watcher: TileSetWatcher) -> void:
	world = world_node
	_tileset_watcher = watcher
	terrain = TerrainDual.new(watcher)
	if not terrain.changed.is_connected(_terrain_changed):
		terrain.changed.connect(_terrain_changed, 1)
	if not world_tiles_changed.is_connected(_world_tiles_changed):
		world_tiles_changed.connect(_world_tiles_changed, 1)
	# El Display es el renderer real de TileMapDual. Debe conservar el Z
	# absoluto del TileMapDual que lo contiene.
	z_as_relative = false
	z_index = world.z_index
	use_parent_material = false
	y_sort_enabled = true


## Updates the display based on the cells changed in the world TileMapDual.
func update(updated: Array) -> void:
	if _tileset_watcher.tile_set == null:
		return
	_sync_properties_if_changed()
	if not updated.is_empty():
		var update_started_usec: int = Time.get_ticks_usec()
		var cache_started_usec: int = update_started_usec
		cached_cells.update(world, updated)
		var cache_elapsed_ms: float = float(Time.get_ticks_usec() - cache_started_usec) / 1000.0
		_diag_cache_ms += cache_elapsed_ms
		var renderer_started_usec: int = Time.get_ticks_usec()
		world_tiles_changed.emit(updated)
		_diag_renderer_ms += float(Time.get_ticks_usec() - renderer_started_usec) / 1000.0
		var update_elapsed_ms: float = float(Time.get_ticks_usec() - update_started_usec) / 1000.0
		_diag_update_calls += 1
		_diag_update_ms += update_elapsed_ms
		_diag_update_ms_max = maxf(_diag_update_ms_max, update_elapsed_ms)


## Activates when the TerrainDual changes.
func _terrain_changed() -> void:
	cached_cells.update(world)
	_delete_layers()
	if _tileset_watcher.tile_set != null:
		_create_layers()


func _world_tiles_changed(changed: Array) -> void:
	#print('SIGNAL EMITTED: world_tiles_changed(%s)' % {'changed': changed})
	for child in get_children(true):
		child.update_tiles(cached_cells, changed)


## Initializes and configures new DisplayLayers according to the grid shape.
func _create_layers() -> void:
	#print('GRID SHAPE: %s' % _tileset_watcher.grid_shape)
	var grid: Array = GRIDS[_tileset_watcher.grid_shape]
	for i: int in grid.size():
		var layer_config: Dictionary = grid[i]
		#print('layer_config: %s' % layer_config)
		var layer := DisplayLayer.new(world, _tileset_watcher, layer_config, terrain.layers[i])
		add_child(layer)
		layer.fijar_origen_shader()
		layer.update_tiles_all(cached_cells)


## Deletes all of the DisplayLayers.
func _delete_layers() -> void:
	for child in get_children(true):
		child.queue_free()


## Activates when the properties of the parent TileMapDual have been edited.
func obtener_diagnostico() -> Dictionary:
	var out: Dictionary = {
		"layers": get_child_count(),
		"update_calls": 0,
		"world_cells": 0,
		"display_candidates": 0,
		"rule_evaluations": 0,
		"redundant_tiles": 0,
		"cached_rule_skips": 0,
		"set_cells": 0,
		"flush_calls": 0,
		"flush_ms_total": 0.0,
		"flush_ms_max": 0.0,
		"sample_count": 0,
		"sample_path_ms": 0.0,
		"sample_rule_ms": 0.0,
		"sample_write_ms": 0.0,
	}
	for child in get_children():
		if child is DisplayLayer:
			var diag: Dictionary = child.obtener_diagnostico()
			for key in ["update_calls", "world_cells", "display_candidates", "rule_evaluations", "redundant_tiles", "cached_rule_skips", "set_cells", "flush_calls", "sample_count"]:
				out[key] = int(out[key]) + int(diag.get(key, 0))
			for key in ["flush_ms_total", "sample_path_ms", "sample_rule_ms", "sample_write_ms"]:
				out[key] = float(out[key]) + float(diag.get(key, 0.0))
			out["flush_ms_max"] = maxf(float(out["flush_ms_max"]), float(diag.get("flush_ms_max", 0.0)))
	out["update_calls"] = _diag_update_calls
	out["update_ms_total"] = _diag_update_ms
	out["update_ms_max"] = _diag_update_ms_max
	out["cache_ms_total"] = _diag_cache_ms
	out["renderer_ms_total"] = _diag_renderer_ms
	out["cache"] = cached_cells.obtener_diagnostico()
	return out


func _sync_properties_if_changed() -> void:
	var state := {
		"z_index": world.z_index,
		"z_as_relative": world.z_as_relative,
		"light_mask": world.light_mask,
		"visibility_layer": world.visibility_layer,
		"y_sort_enabled": world.y_sort_enabled,
		"modulate": world.modulate,
		"self_modulate": world.self_modulate,
		"show_behind_parent": world.show_behind_parent,
		"top_level": world.top_level,
		"y_sort_origin": world.y_sort_origin,
		"x_draw_order_reversed": world.x_draw_order_reversed,
		"rendering_quadrant_size": world.rendering_quadrant_size,
		"collision_enabled": world.collision_enabled,
		"use_kinematic_bodies": world.use_kinematic_bodies,
		"collision_visibility_mode": world.collision_visibility_mode,
		"navigation_enabled": world.navigation_enabled,
		"navigation_visibility_mode": world.navigation_visibility_mode,
		"use_parent_material": world.use_parent_material,
		"display_material": world.display_material,
	}
	if state == _last_synced_world_properties:
		return
	_update_properties()
	_last_synced_world_properties = state


func _update_properties() -> void:
	# TileMapDual puede cambiar su Z después de crear Display.
	# Mantener el renderer real sincronizado evita que el addon vuelva
	# a colocar el terreno en el Z por defecto.
	self.z_as_relative = false
	self.z_index = world.z_index
	for child in get_children(true):
		child.update_properties(world)
		child.fijar_origen_shader()
