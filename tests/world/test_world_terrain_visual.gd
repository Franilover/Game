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
	if visual._terrain_underlay == null or visual._terrain_underlay.tile_set == null:
		_fail("Opaque underlay was not initialized.")
		return
	if visual._terrain_underlay.tile_set.get_source_count() != EXPECTED_ZONE_COUNT:
		_fail("Underlay must pre-register one atlas for each of the 10 zones.")
		return

	for zone in range(EXPECTED_ZONE_COUNT):
		var layer := visual._layers_by_zone[str(zone)] as TileMapDual
		if layer == null or layer.tile_set == null:
			_fail("Missing TileMapDual for zone %d." % zone)
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

	print("PASS: 10 binary terrain layers, stable atlases, bounded flushes, display composition, and cross-zone erase invalidation.")
	quit()


func _fail(message: String) -> void:
	push_error("World terrain visual regression: " + message)
	quit(1)
