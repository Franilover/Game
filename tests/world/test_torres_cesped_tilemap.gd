extends SceneTree

const TORRES_SCENE: PackedScene = preload("res://scenes/kingdom/reino_torres.tscn")
const GRASS_ATLAS_PATH := "res://assets/tilesets/Torres_Cesped.png"
const GRASS_CELL_COUNT := 75 * 44
const CORNERS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var torres := TORRES_SCENE.instantiate() as Node2D
	if torres == null:
		_fail("No se pudo instanciar la escena de Torres.")
		return
	root.add_child(torres)

	# TileMapDual crea su Display en _ready y termina la composición en el
	# siguiente frame; esperar dos ciclos antes de consultar el renderer.
	await process_frame
	await process_frame

	var cesped := torres.get_node_or_null("TorresCespedDual") as TileMapDual
	if cesped == null:
		_fail("Torres no creó el TileMapDual del césped.")
		return
	if cesped.tile_set == null or cesped.tile_set.tile_size != Vector2i(32, 32):
		_fail("El césped debe usar tiles de 32x32.")
		return
	if cesped.get_used_cells().size() != GRASS_CELL_COUNT:
		_fail("Se esperaba una alfombra de 75x44 celdas de césped.")
		return
	if cesped.tile_set.get_source_count() != 1:
		_fail("El césped debe tener un solo atlas.")
		return

	var atlas := cesped.tile_set.get_source(0) as TileSetAtlasSource
	if atlas == null:
		_fail("La fuente del césped no es un TileSetAtlasSource.")
		return
	if atlas.texture == null or atlas.texture.resource_path != GRASS_ATLAS_PATH:
		_fail("El TileMapDual no usa el atlas editable de césped de Torres.")
		return
	if atlas.texture_region_size != Vector2i(32, 32) or atlas.get_tiles_count() != 16:
		_fail("El atlas debe contener las 16 máscaras de 32x32.")
		return

	for mask in range(16):
		var coords := Vector2i(mask % 4, int(mask / 4))
		if not atlas.has_tile(coords):
			_fail("Falta la máscara %d en el atlas." % mask)
			return
		var data := atlas.get_tile_data(coords, 0)
		if data == null or data.terrain_set != 0 or data.terrain != 1:
			_fail("La máscara %d no tiene el terreno de césped." % mask)
			return
		for bit_index in range(CORNERS.size()):
			var expected := 1 if (mask & (1 << bit_index)) != 0 else 0
			if data.get_terrain_peering_bit(CORNERS[bit_index]) != expected:
				_fail("La máscara %d tiene mal configurada la esquina %d." % [mask, bit_index])
				return

	var ground := torres.get_node_or_null("Ground") as Polygon2D
	if ground == null or not ground.visible:
		_fail("Debe conservarse el suelo base bajo las esquinas transparentes.")
		return
	if torres.get_node_or_null("Pixel_Ground") != null:
		_fail("El césped no debe volver a rasterizarse como una textura gigante.")
		return
	if not bool(cesped.obtener_diagnostico().get("renderer_valid", false)):
		_fail("El renderer interno de TileMapDual no está inicializado.")
		return

	print("PASS: Torres uses its editable 16-mask grass atlas through TileMapDual.")
	torres.queue_free()
	quit()


func _fail(message: String) -> void:
	push_error("Torres grass TileMapDual regression: " + message)
	quit(1)
