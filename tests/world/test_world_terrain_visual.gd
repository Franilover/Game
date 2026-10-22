extends SceneTree

const VISUAL_SCRIPT = preload("res://scripts/world/world_terrain_visual.gd")
const EXPECTED_ZONE_COUNT := 10


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var visual := VISUAL_SCRIPT.new() as WorldTerrainVisual
	root.add_child(visual)
	visual.configurar(32)

	# Each TileMapDual needs its own binary terrain atlas. Wait until all
	# TileMapDual nodes have completed _ready(), then rebuild rules once.
	await process_frame
	visual.finalizar_preparacion_renderer()
	await process_frame

	if visual._layers_by_zone.size() != EXPECTED_ZONE_COUNT:
		_fail("Expected one TileMapDual per zone.")
		return
	# Regression: mask bits must follow this vendored addon's actual
	# TerrainDual.NEIGHBORHOOD_LAYERS.SQUARE order: TL, TR, BL, BR.
	# A swapped order makes the renderer choose the wrong art at corners.
	var expected_bit_order: Array[TileSet.CellNeighbor] = [
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	]
	if VISUAL_SCRIPT.CORNER_NEIGHBORS != expected_bit_order:
		_fail("TileMapDual mask bit order differs from the upstream square preset.")
		return

	# Transition composition must not have an opaque full-cell underlay.
	# Such a tile fills transparent corners and hides the neighboring biome.

	for zone in range(EXPECTED_ZONE_COUNT):
		var layer := visual._layers_by_zone[str(zone)] as TileMapDual
		if layer == null or layer.tile_set == null:
			_fail("Missing TileMapDual for zone %d." % zone)
			return
		# Regression: Pradera has authored opaque overhang pixels outside
		# some mask quadrants, so it must draw after Tierra. Keep all other
		# zone priorities unchanged; this is a draw-order rule, not an atlas crop.
		var expected_z := -4095 + zone
		if zone == 0:
			expected_z = -4094
		elif zone == 1:
			expected_z = -4095
		if layer.z_index != expected_z:
			_fail(
				"Unexpected draw order for zone %d: expected z_index %d, got %d."
				% [zone, expected_z, layer.z_index]
			)
			return
		if layer.tile_set.get_source_count() != 1:
			_fail("Zone %d must have exactly one atlas source." % zone)
			return
		if layer.tile_set.get_terrains_count(0) != 2:
			_fail("Zone %d must use the binary empty/own-terrain model." % zone)
			return
		if not bool(layer.obtener_diagnostico().get("renderer_valid", false)):
			_fail("TileMapDual renderer is invalid for zone %d." % zone)
			return

		# El renderer debe conservar el atlas original. No exigimos que cada
		# cuadrante de la imagen fuente sea transparente: los bordes dibujados
		# pueden atravesar esos límites y el recorte borraba parte del arte.
		var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
		if atlas == null:
			_fail("Zone %d has no atlas source." % zone)
			return
		var expected_texture := str(VISUAL_SCRIPT.ZONE_TEXTURES[zone])
		if atlas.texture.resource_path != expected_texture:
			_fail(
				"Zone %d did not preserve its source atlas: expected %s, got %s"
				% [zone, expected_texture, atlas.texture.resource_path]
			)
			return
		if atlas.texture_region_size != Vector2i(32, 32):
			_fail("Zone %d atlas region size changed unexpectedly." % zone)
			return

		# Verify every authored atlas coordinate is registered with the mask
		# represented by its TILE_SEQUENCE index, not just that 16 tiles exist.
		for mask_index in range(VISUAL_SCRIPT.TILE_SEQUENCE.size()):
			var coords: Vector2i = VISUAL_SCRIPT.TILE_SEQUENCE[mask_index]
			var tile_data := atlas.get_tile_data(coords, 0)
			if tile_data == null:
				_fail("Zone %d is missing mask tile %s." % [zone, coords])
				return
			for bit_index in range(expected_bit_order.size()):
				var expected_terrain := 1 if (mask_index & (1 << bit_index)) != 0 else 0
				var actual_terrain := tile_data.get_terrain_peering_bit(expected_bit_order[bit_index])
				if actual_terrain != expected_terrain:
					_fail(
						"Zone %d mask %d has wrong corner bit %d at %s."
						% [zone, mask_index, bit_index, coords]
					)
					return

	# Preserve DisplayLayer identities across ordinary cell painting. A
	# TileSet/rule rebuild during streaming would replace these nodes.
	var display_ids_by_zone: Dictionary = {}
	for zone in range(EXPECTED_ZONE_COUNT):
		var layer := visual._layers_by_zone[str(zone)] as TileMapDual
		var display_ids: Array[int] = []
		for child in layer._display.get_children():
			if child is DisplayLayer:
				display_ids.append(child.get_instance_id())
		display_ids_by_zone[zone] = display_ids

	# Adjacent cells of different zones exercise cross-layer boundaries.
	for zone in range(EXPECTED_ZONE_COUNT):
		visual.set_zone(Vector2i(zone, 0), zone, 0)
	# There is intentionally no opaque underlay; adjacent zones must compose
	# through the TileMapDual corner rules instead of full-cell fallback tiles.
	# Repainting the same zone with another biome must not add sources/rules.
	visual.set_zone(Vector2i(0, 1), 0, EXPECTED_ZONE_COUNT - 1)
	if visual._terrain_rules_dirty:
		_fail("Ordinary cell painting dirtied the static terrain rules.")
		return

	for zone in range(EXPECTED_ZONE_COUNT):
		var layer := visual._layers_by_zone[str(zone)] as TileMapDual
		if layer.tile_set.get_source_count() != 1:
			_fail("Painting dynamically added atlas sources for zone %d." % zone)
			return
		if layer.tile_set.get_terrains_count(0) != 2:
			_fail("Painting dynamically added terrain IDs for zone %d." % zone)
			return
		if layer.get_used_cells().is_empty():
			_fail("Zone %d did not retain its logical world cell." % zone)
			return

	var safety := 0
	while visual.tiene_flush_pendiente() and safety < 128:
		visual.procesar_flush(64)
		safety += 1
	if visual.tiene_flush_pendiente():
		_fail("Dirty terrain queues did not drain in bounded flushes.")
		return

	await process_frame
	var total_display_cells := 0
	for zone in range(EXPECTED_ZONE_COUNT):
		var layer := visual._layers_by_zone[str(zone)] as TileMapDual
		var current_display_ids: Array[int] = []
		for child in layer._display.get_children():
			if child is DisplayLayer:
				current_display_ids.append(child.get_instance_id())
		if current_display_ids != display_ids_by_zone[zone]:
			_fail("DisplayLayer nodes were rebuilt during ordinary painting in zone %d." % zone)
			return
		var diagnostic: Dictionary = layer.obtener_diagnostico()
		if int(diagnostic.get("display_cells", 0)) <= 0:
			_fail("Zone %d has no composed display cells." % zone)
			return
		total_display_cells += int(diagnostic.get("display_cells", 0))

	if total_display_cells <= 0:
		_fail("No terrain was composed into TileMapDual display layers.")
		return

	# Corner-matched terrain depends on diagonals as well as cardinal cells.
	if VISUAL_SCRIPT.UPDATE_NEIGHBORS.size() != 9:
		_fail("Terrain invalidation must include the center and all eight neighbors.")
		return

	# Build a diagonal cross-zone neighbor, drain prior invalidations, then move
	# the origin cell to another layer to verify both renderers are refreshed.
	visual.set_zone(Vector2i(10, 0), 0, 0)
	visual.set_zone(Vector2i(11, 1), 1, 0)
	safety = 0
	while visual.tiene_flush_pendiente() and safety < 128:
		visual.procesar_flush(64)
		safety += 1
	if visual.tiene_flush_pendiente():
		_fail("Dirty queues did not drain before zone-change regression.")
		return
	await process_frame

	visual.set_zone(Vector2i(10, 0), 2, 0)
	if not visual._dirty_lookup_by_zone["0"].has(Vector2i(10, 0)):
		_fail("Changing zones did not invalidate the removed cell in its old layer.")
		return
	if not visual._dirty_lookup_by_zone["1"].has(Vector2i(11, 1)):
		_fail("Changing zones did not invalidate a diagonal neighbor in its own layer.")
		return
	safety = 0
	while visual.tiene_flush_pendiente() and safety < 128:
		visual.procesar_flush(64)
		safety += 1
	if visual.tiene_flush_pendiente():
		_fail("Dirty queues did not drain after changing a cell's zone.")
		return
	await process_frame
	var previous_zone_layer := visual._layers_by_zone["0"] as TileMapDual
	if previous_zone_layer._display.cached_cells.cells.has(Vector2i(10, 0)):
		_fail("Zone change left a stale visual cell in the previous layer's display cache.")
		return

	# Removing one cell must refresh the old layer and the actual neighboring
	# zone layer. Otherwise streamed chunk unloads leave stale edge tiles.
	visual._limpiar_celda_chunk(Vector2i(0, 0), true)
	var adjacent_layer := visual._layers_by_zone["1"] as TileMapDual
	if not visual._dirty_lookup_by_zone["1"].has(Vector2i(1, 0)):
		_fail("Removing a zone-0 cell did not invalidate the adjacent zone-1 cell.")
		return
	safety = 0
	while visual.tiene_flush_pendiente() and safety < 128:
		visual.procesar_flush(64)
		safety += 1
	if visual.tiene_flush_pendiente():
		_fail("Dirty queues did not drain after removing a terrain cell.")
		return
	await process_frame
	var removed_layer := visual._layers_by_zone["0"] as TileMapDual
	if removed_layer._display.cached_cells.cells.has(Vector2i(0, 0)):
		_fail("Removed world cell remains in TileMapDual's logical display cache.")
		return
	if adjacent_layer.get_used_cells().is_empty():
		_fail("Adjacent zone was incorrectly erased while refreshing its boundary.")
		return

	# The incremental chunk-unload path passes marcar_dirty=false. Even then,
	# every erased interior cell must be queued so its old Display tile vanishes.
	visual._limpiar_celda_chunk(Vector2i(0, 1), false)
	if not visual._dirty_lookup_by_zone["0"].has(Vector2i(0, 1)):
		_fail("Incremental unload did not queue the erased interior cell.")
		return
	safety = 0
	while visual.tiene_flush_pendiente() and safety < 128:
		visual.procesar_flush(64)
		safety += 1
	if visual.tiene_flush_pendiente():
		_fail("Dirty queues did not drain after incremental unload.")
		return
	await process_frame
	if removed_layer._display.cached_cells.cells.has(Vector2i(0, 1)):
		_fail("Incrementally unloaded cell remains in TileMapDual's cache.")
		return

	print("PASS: 10 binary terrain layers, stable atlases, bounded flushes, display composition, cross-zone invalidation, and unload cache cleanup.")
	quit()



func _fail(message: String) -> void:
	push_error("World terrain visual regression: " + message)
	quit(1)
