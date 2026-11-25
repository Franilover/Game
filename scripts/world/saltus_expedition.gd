extends Node2D
class_name SaltusExpedition

const TILE_SIZE: int = 32
const TILE_ATLAS_COORDS: Vector2i = Vector2i(2, 1)
const TILESET_TEXTURE_PATH: String = "res://assets/tilesets/Bosque.png"
const LEAF_TEXTURE_PATH: String = "res://assets/art/items/Hojas.png"
const LEVEL_WIDTH_TILES: int = 90
const GROUND_TOP: int = 14

var _terrain_layer: TileMapLayer
var _platform_layer: TileMapLayer
var _player: SaltusPlayer


func _ready() -> void:
	_player = get_node_or_null("Player") as SaltusPlayer
	if is_instance_valid(_player):
		_player.visible = true
		_player.z_index = 3
		var sprite: Sprite2D = _player.get_node_or_null("Sprite2D") as Sprite2D
		if is_instance_valid(sprite):
			sprite.visible = true
			sprite.z_index = 0
	_crear_terreno()
	_crear_ambiente()
	_configurar_camara()
	queue_redraw()


func _process(_delta: float) -> void:
	if is_instance_valid(_player) and _player.global_position.y > 900.0:
		_player.global_position = Vector2(96.0, float(GROUND_TOP * TILE_SIZE - 40))
		_player.velocity = Vector2.ZERO


func _crear_terreno() -> void:
	var tile_set: TileSet = _crear_tileset_bosque(false)
	var platform_tile_set: TileSet = _crear_tileset_bosque(true)
	if tile_set == null or platform_tile_set == null:
		push_error("Saltus: no se pudieron preparar los TileSet del terreno.")
		return

	_terrain_layer = TileMapLayer.new()
	_terrain_layer.name = "Terreno"
	_terrain_layer.tile_set = tile_set
	_terrain_layer.z_index = 0
	add_child(_terrain_layer)

	_platform_layer = TileMapLayer.new()
	_platform_layer.name = "Plataformas"
	_platform_layer.tile_set = platform_tile_set
	_platform_layer.z_index = 1
	add_child(_platform_layer)

	for x in range(LEVEL_WIDTH_TILES):
		for y in range(GROUND_TOP, GROUND_TOP + 6):
			_terrain_layer.set_cell(Vector2i(x, y), 0, TILE_ATLAS_COORDS)

	# Plataformas escalonadas: dejan varias rutas de salto y descansos.
	_pintar_plataforma(9, 12, 5)
	_pintar_plataforma(17, 10, 5)
	_pintar_plataforma(25, 12, 4)
	_pintar_plataforma(32, 10, 5)
	_pintar_plataforma(41, 11, 5)
	_pintar_plataforma(50, 9, 5)
	_pintar_plataforma(59, 12, 5)
	_pintar_plataforma(68, 10, 5)
	_pintar_plataforma(78, 12, 6)
	_pintar_plataforma(84, 10, 4)


func _crear_tileset_bosque(one_way: bool) -> TileSet:
	var textura: Texture2D = load(TILESET_TEXTURE_PATH) as Texture2D
	if textura == null:
		push_error("Saltus: no se pudo cargar el atlas Bosque.png.")
		return null

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas.create_tile(TILE_ATLAS_COORDS)
	tile_set.add_source(atlas, 0)

	# El TileData debe configurarse después de añadir su atlas al TileSet,
	# para que ya disponga de la capa física 0.
	var tile_data: TileData = atlas.get_tile_data(TILE_ATLAS_COORDS, 0)
	if tile_data == null:
		push_error("Saltus: no se pudo preparar el tile sólido del atlas de bosque.")
		return null

	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_one_way(0, 0, one_way)
	tile_data.set_collision_polygon_one_way_margin(0, 0, 2.0)
	tile_data.set_collision_polygon_points(
		0,
		0,
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(32.0, 0.0),
			Vector2(32.0, 32.0),
			Vector2(0.0, 32.0)
		])
	)
	return tile_set


func _pintar_plataforma(inicio_x: int, fila_y: int, ancho: int) -> void:
	for x in range(inicio_x, inicio_x + ancho):
		_platform_layer.set_cell(Vector2i(x, fila_y), 0, TILE_ATLAS_COORDS)


func _crear_ambiente() -> void:
	var textura_hojas: Texture2D = load(LEAF_TEXTURE_PATH) as Texture2D
	if textura_hojas == null:
		return

	for centro_x in [420.0, 1120.0, 1840.0, 2540.0]:
		var hojas: CPUParticles2D = CPUParticles2D.new()
		hojas.name = "HojasEnElAire"
		hojas.z_index = 2
		hojas.position = Vector2(centro_x, 150.0)
		hojas.texture = textura_hojas
		hojas.amount = 9
		hojas.lifetime = 7.0
		hojas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		hojas.emission_rect_extents = Vector2(230.0, 105.0)
		hojas.direction = Vector2(-0.25, 1.0)
		hojas.spread = 24.0
		hojas.gravity = Vector2(16.0, 24.0)
		hojas.initial_velocity_min = 8.0
		hojas.initial_velocity_max = 22.0
		hojas.angular_velocity_min = -35.0
		hojas.angular_velocity_max = 35.0
		hojas.scale_amount_min = 0.25
		hojas.scale_amount_max = 0.55
		hojas.modulate = Color(0.86, 0.94, 0.72, 0.82)
		add_child(hojas)


func _configurar_camara() -> void:
	if not is_instance_valid(_player):
		return
	var camara: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if camara == null:
		return
	camara.enabled = true
	camara.global_position = _player.global_position + Vector2(0.0, -35.0)
	camara.make_current()
	camara.reset_smoothing()
	camara.limit_left = 0
	camara.limit_right = LEVEL_WIDTH_TILES * TILE_SIZE
	camara.limit_top = -120
	camara.limit_bottom = 720
	camara.position_smoothing_enabled = true
	camara.position_smoothing_speed = 5.5
	camara.drag_horizontal_enabled = true
	camara.drag_vertical_enabled = false
	print("Saltus: cámara activa=", camara.is_current(), " jugador=", _player.global_position, " tiles=", _terrain_layer.get_used_cells().size() if is_instance_valid(_terrain_layer) else 0)


func _draw() -> void:
	# Fondo en capas: la profundidad se consigue con siluetas de distinto tono.
	draw_rect(Rect2(Vector2(-200.0, -500.0), Vector2(LEVEL_WIDTH_TILES * TILE_SIZE + 400.0, 1500.0)), Color("#b7c9a0"))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-200.0, 360.0), Vector2(250.0, 210.0), Vector2(720.0, 340.0),
			Vector2(1180.0, 190.0), Vector2(1660.0, 330.0), Vector2(2200.0, 205.0),
			Vector2(3100.0, 350.0), Vector2(3100.0, 520.0), Vector2(-200.0, 520.0)
		]),
		Color("#819b79")
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-200.0, 420.0), Vector2(380.0, 300.0), Vector2(920.0, 405.0),
			Vector2(1450.0, 285.0), Vector2(2050.0, 410.0), Vector2(2650.0, 300.0),
			Vector2(3100.0, 420.0), Vector2(3100.0, 540.0), Vector2(-200.0, 540.0)
		]),
		Color("#526f55")
	)

	# Troncos y copas de fondo, con separación irregular para evitar un patrón repetido.
	for index in range(24):
		var x: float = -70.0 + float(index) * 138.0
		var alto: float = 95.0 + float((index * 37) % 75)
		var ancho: float = 28.0 + float((index * 13) % 22)
		var base_y: float = 445.0 + float((index * 19) % 28)
		var tono: Color = Color("#344f42") if index % 2 == 0 else Color("#3d5c49")
		draw_rect(Rect2(Vector2(x, base_y - alto * 0.35), Vector2(ancho * 0.28, alto)), Color("#5b4938"))
		draw_circle(Vector2(x + ancho * 0.14, base_y - alto), ancho * 0.8, tono)
		draw_circle(Vector2(x - ancho * 0.25, base_y - alto * 0.72), ancho * 0.58, tono.lightened(0.08))
		draw_circle(Vector2(x + ancho * 0.52, base_y - alto * 0.68), ancho * 0.62, tono.darkened(0.06))

	# Pequeños puntos de luz entre los árboles.
	for index in range(18):
		var x: float = 90.0 + float((index * 173) % 2700)
		var y: float = 125.0 + float((index * 61) % 245)
		draw_circle(Vector2(x, y), 2.0, Color(0.93, 0.91, 0.58, 0.52))
