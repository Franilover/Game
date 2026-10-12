extends SceneTree

const VISUAL_SCRIPT = preload("res://scripts/world/world_terrain_visual.gd")
const EXPECTED_ZONE_COUNT := 10


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var visual := VISUAL_SCRIPT.new() as WorldTerrainVisual
	root.add_child(visual)
	visual.configurar(32)

	# TileMapDual's _ready() completes on the next frame. The zone atlases
	# must already exist before the first terrain cell is written.
	await process_frame

	var layer: TileMapDual = visual.tilemap_dual
	if layer == null or layer.tile_set == null:
		_fail("TileMapDual or TileSet was not initialized.")
		return

	if layer.tile_set.get_source_count() != EXPECTED_ZONE_COUNT:
		_fail("Expected exactly %d pre-registered zone atlases, got %d." % [
			EXPECTED_ZONE_COUNT, layer.tile_set.get_source_count()
		])
		return

	if layer.tile_set.get_terrains_count(0) != EXPECTED_ZONE_COUNT + 1:
		_fail("Terrain IDs do not match the 10 zones plus the reserved fallback.")
		return

	# Paint every zone and repeat one zone with a different biome index.
	# Visual terrain identity is zone-based; biome metadata must not append
	# more atlases or terrain rules while the world is streaming.
	for zone in range(EXPECTED_ZONE_COUNT):
		visual.set_zone(Vector2i(zone, 0), zone, 0)
	visual.set_zone(Vector2i(0, 1), 0, EXPECTED_ZONE_COUNT - 1)

	if layer.tile_set.get_source_count() != EXPECTED_ZONE_COUNT:
		_fail("Painting cells dynamically added TileSet sources.")
		return
	if layer.tile_set.get_terrains_count(0) != EXPECTED_ZONE_COUNT + 1:
		_fail("Painting cells dynamically added terrain IDs.")
		return
	if visual._terrain_rules_dirty:
		_fail("Terrain rules were marked dirty during ordinary cell painting.")
		return

	var safety := 0
	while visual.tiene_flush_pendiente() and safety < 64:
		visual.procesar_flush(256)
		safety += 1

	if visual.tiene_flush_pendiente():
		_fail("Dirty terrain cells did not drain in bounded flushes.")
		return

	var diagnostic: Dictionary = layer.obtener_diagnostico()
	if not bool(diagnostic.get("renderer_valid", false)):
		_fail("TileMapDual display renderer is not valid.")
		return
	print("Renderer diagnostic: ", diagnostic)
	print("World cells: ", layer.get_used_cells().size(), " | dirty pending: ", visual.tiene_flush_pendiente())
	print("Terrain neighborhood: ", layer._display.terrain.layers[0].terrain_neighborhood, " | display-to-world: ", layer._display.terrain.layers[0].display_to_world_neighborhood)
	for child in layer._display.get_children():
		if child is DisplayLayer:
			print("DisplayLayer neighborhood: ", (child as DisplayLayer)._terrain.display_to_world_neighborhood)
	if int(diagnostic.get("display_cells", 0)) <= 0:
		_fail("Terrain cells were not composed into the display layer.")
		return

	print("PASS: stable zone atlas count, stable terrain rules, and display composition.")
	quit()


func _fail(message: String) -> void:
	push_error("World terrain visual regression: " + message)
	quit(1)
