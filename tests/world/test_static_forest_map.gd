extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var bosque := Node2D.new()
	bosque.set_script(load("res://scripts/world/static_forest_map.gd"))
	add_child(bosque)

	# La construcción del bosque y el flush de TileMapDual son asíncronos.
	var renderer: Node = null
	for frame in range(300):
		await get_tree().process_frame
		renderer = bosque.get_node_or_null("TerrainRenderer")
		if renderer != null:
			var capa_base := renderer.get_node_or_null("TerrainDual_Zone_00") as TileMapDual
			if capa_base != null and capa_base.get_used_cells().size() >= 7000 and not bool(renderer.call("tiene_flush_pendiente")):
				break

	if renderer == null:
		_fail("No se creó el renderer estático.")
		return

	var pradera := renderer.get_node_or_null("TerrainDual_Zone_00") as TileMapDual
	var tierra := renderer.get_node_or_null("TerrainDual_Zone_01") as TileMapDual
	var bosque_layer := renderer.get_node_or_null("TerrainDual_Zone_08") as TileMapDual
	if pradera == null or tierra == null or bosque_layer == null:
		_fail("El bosque no está usando las capas TileMapDual de pradera, tierra y bosque.")
		return

	if pradera.get_used_cells().size() < 7000:
		_fail("La capa DualGrid de pradera no cubre el interior del mapa.")
		return
	if bosque_layer.get_used_cells().size() < 1000:
		_fail("La capa DualGrid de bosque no forma el borde.")
		return
	if tierra.get_used_cells().size() < 100:
		_fail("La capa DualGrid de tierra no contiene los senderos.")
		return

	var display: Node = pradera.get_child(0) if pradera.get_child_count() > 0 else null
	if display == null:
		_fail("TileMapDual no creó su Display.")
		return
	var total_display_cells := 0
	var atlas_variants: Dictionary = {}
	for child in display.get_children():
		if child is TileMapLayer:
			var display_layer := child as TileMapLayer
			for cell in display_layer.get_used_cells():
				total_display_cells += 1
				atlas_variants[display_layer.get_cell_atlas_coords(cell)] = true
	if total_display_cells < 7000:
		_fail("TileMapDual no compuso las celdas visuales del suelo.")
		return
	if atlas_variants.size() < 2:
		_fail("El atlas no está resolviendo distintas máscaras de esquina.")
		return

	if bosque.get_node_or_null("LimiteOeste") == null or bosque.get_node_or_null("LimiteEste") == null:
		_fail("Faltan colisiones en los límites laterales.")
		return
	if bosque.get_node_or_null("LimiteNorte") == null or bosque.get_node_or_null("LimiteSur") == null:
		_fail("Faltan colisiones en los límites superior e inferior.")
		return

	var limites: Rect2 = bosque.call("obtener_limites_mapa")
	if not limites.position.is_equal_approx(Vector2.ZERO) or not limites.size.is_equal_approx(Vector2(5120.0, 2048.0)):
		_fail("Los límites declarados no coinciden con el tamaño del bosque.")
		return

	print("StaticForestMapContract: PASS")
	get_tree().quit(0)


func _fail(mensaje: String) -> void:
	push_error("StaticForestMapContract: FAIL: " + mensaje)
	get_tree().quit(1)
