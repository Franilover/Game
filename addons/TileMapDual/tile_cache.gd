@tool
class_name TileCache
extends Resource

var cells: Dictionary[Vector2i, Dictionary] = { }

# Coste del mantenimiento del cache por lote (no por celda).
var _diag_update_calls: int = 0
var _diag_cells_processed: int = 0
var _diag_elapsed_ms: float = 0.0
var _diag_elapsed_ms_max: float = 0.0


func _init() -> void:
	pass


func update(world: TileMapLayer, edited: Array[Vector2i] = cells.keys()) -> void:
	var tile_set: TileSet = world.tile_set
	if tile_set == null:
		push_error("Attempted to update TileCache while tile set was null")
		return

	var started_usec: int = Time.get_ticks_usec()
	_diag_update_calls += 1
	_diag_cells_processed += edited.size()
	for cell: Vector2i in edited:
		var sid: int = world.get_cell_source_id(cell)
		if sid == -1:
			cells.erase(cell)
			continue
		if not tile_set.has_source(sid):
			continue

		var src: TileSetSource = tile_set.get_source(sid)
		var tile: Vector2i = world.get_cell_atlas_coords(cell)
		if not src.has_tile(tile):
			continue

		var data: TileData = world.get_cell_tile_data(cell)
		if data == null:
			continue

		# Corregir celdas inválidas usando su valor previamente cacheado.
		if data.terrain == -1 or data.terrain_set != 0:
			if cell not in cells:
				world.erase_cell(cell)
				continue

			var cached: Dictionary = cells[cell]
			sid = int(cached["sid"])
			tile = cached["tile"] as Vector2i
			world.set_cell(cell, sid, tile)
			data = world.get_cell_tile_data(cell)
			if data == null:
				continue

		# IMPORTANTE: las celdas válidas también deben entrar al cache.
		# Antes esta asignación estaba dentro del bloque de celdas inválidas,
		# dejando el Display de TileMapDual sin información para renderizar.
		cells[cell] = {
			"sid": sid,
			"tile": tile,
			"terrain": data.terrain,
		}
	var elapsed_ms: float = float(Time.get_ticks_usec() - started_usec) / 1000.0
	_diag_elapsed_ms += elapsed_ms
	_diag_elapsed_ms_max = maxf(_diag_elapsed_ms_max, elapsed_ms)


func obtener_diagnostico() -> Dictionary:
	return {
		"update_calls": _diag_update_calls,
		"cells_processed": _diag_cells_processed,
		"elapsed_ms_total": _diag_elapsed_ms,
		"elapsed_ms_max": _diag_elapsed_ms_max,
	}


func xor(other: TileCache) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in cells:
		if key not in other.cells or cells[key].terrain != other.cells[key].terrain:
			out.push_back(key)
	for key in other.cells:
		if key not in cells:
			out.push_back(key)
	return out


func get_terrain_at(cell: Vector2i) -> int:
	if cell not in cells:
		return -1
	return cells[cell].terrain
