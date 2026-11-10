extends SceneTree

const TORRES_SCENE: PackedScene = preload("res://scenes/kingdom/reino_torres.tscn")
const EXPECTED_CELL_COUNT := 75 * 44
const EXPECTED_ATLASES := {
	0: "res://assets/tilesets/Pradera.png",
	1: "res://assets/tilesets/Tierra.png",
	8: "res://assets/tilesets/Bosque.png",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var torres := TORRES_SCENE.instantiate() as Node2D
	if torres == null:
		_fail("No se pudo instanciar la escena de Torres.")
		return
	root.add_child(torres)

	# El mapa fijo se compone por tandas; esperar a que termine el _ready()
	# asíncrono y se vacíe el flush del renderer compartido.
	var espera := 0
	while not bool(torres.get("_terreno_dual_listo")) and espera < 120:
		await process_frame
		espera += 1
	if not bool(torres.get("_terreno_dual_listo")):
		_fail("Torres no terminó de componer su terreno TileMapDual.")
		return

	var renderer := torres.get_node_or_null("TerrainRenderer")
	if renderer == null:
		_fail("Torres no creó el renderer común de terrenos.")
		return
	if bool(renderer.call("tiene_flush_pendiente")):
		_fail("El renderer terminó con celdas pendientes de composición.")
		return

	var total_cells := 0
	for zone in EXPECTED_ATLASES.keys():
		var layer := renderer.get_node_or_null("TerrainDual_Zone_%02d" % int(zone)) as TileMapDual
		if layer == null:
			_fail("Falta la capa TileMapDual de la zona %d." % int(zone))
			return
		var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
		if atlas == null or atlas.texture == null:
			_fail("La zona %d no tiene un atlas válido." % int(zone))
			return
		if atlas.texture.resource_path != str(EXPECTED_ATLASES[zone]):
			_fail("La zona %d no usa el atlas común esperado." % int(zone))
			return
		if atlas.texture_region_size != Vector2i(32, 32) or atlas.get_tiles_count() != 16:
			_fail("La zona %d no conserva las 16 máscaras de 32x32." % int(zone))
			return
		var cells := layer.get_used_cells().size()
		if cells <= 0:
			_fail("La zona %d no recibió celdas." % int(zone))
			return
		total_cells += cells

	if total_cells != EXPECTED_CELL_COUNT:
		_fail("Se esperaban 3.300 celdas repartidas entre pradera, tierra y bosque.")
		return

	var suelo := torres.get_node_or_null("Ground") as Polygon2D
	if suelo == null or suelo.visible:
		_fail("El suelo plano antiguo debe quedar oculto bajo el terreno DualGrid.")
		return
	for nombre in ["NorthPath", "MainStreet", "WestStreet", "EastStreet", "SouthPath", "RoadToWorld"]:
		var camino := torres.get_node_or_null(nombre) as Polygon2D
		if camino != null and camino.visible:
			_fail("El camino %s sigue dibujándose como polígono separado." % nombre)
			return

	print("PASS: Torres usa el renderer compartido TileMapDual con pradera, bosque y caminos de tierra.")
	torres.queue_free()
	quit()


func _fail(message: String) -> void:
	push_error("Torres shared terrain regression: " + message)
	quit(1)
