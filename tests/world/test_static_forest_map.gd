extends Node

const FOREST_SCRIPT = preload("res://scripts/world/static_forest_map.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var bosque := FOREST_SCRIPT.new() as Node2D
	add_child(bosque)
	await get_tree().process_frame

	var suelo := bosque.get_node_or_null("Ground") as TileMapLayer
	var borde := bosque.get_node_or_null("ForestEdge") as TileMapLayer
	var sendero := bosque.get_node_or_null("DirtPaths") as TileMapLayer
	if suelo == null or borde == null or sendero == null:
		_fail("No se crearon las tres capas TileMap estáticas.")
		return
	if suelo.get_used_cells().size() < 9000:
		_fail("El suelo fijo no cubre la superficie completa.")
		return
	if borde.get_used_cells().size() < 1000:
		_fail("El borde de bosque no se pintó con tiles.")
		return
	if sendero.get_used_cells().size() < 100:
		_fail("El sendero de tierra no se construyó con tiles.")
		return
	if bosque.get_node_or_null("LimiteOeste") == null or bosque.get_node_or_null("LimiteEste") == null:
		_fail("Faltan colisiones en los límites laterales.")
		return
	if bosque.get_node_or_null("LimiteNorte") == null or bosque.get_node_or_null("LimiteSur") == null:
		_fail("Faltan colisiones en los límites superior e inferior.")
		return

	var limites: Rect2 = bosque.obtener_limites_mapa()
	if not limites.position.is_equal_approx(Vector2.ZERO) or not limites.size.is_equal_approx(Vector2(5120.0, 2048.0)):
		_fail("Los límites declarados no coinciden con el tamaño del bosque.")
		return

	print("StaticForestMapContract: PASS")
	get_tree().quit(0)


func _fail(mensaje: String) -> void:
	push_error("StaticForestMapContract: FAIL: " + mensaje)
	get_tree().quit(1)
