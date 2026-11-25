extends Node2D
class_name SaltusExpedition

const TILE_SIZE: int = 32
const TILE_ATLAS_DEFAULT: Vector2i = Vector2i(2, 1)
const TILESET_TEXTURE_PATH: String = "res://assets/tilesets/Bosque.png"
const TREE_TEXTURE_PATH: String = "res://assets/art/props/Árbol.png"
const LEAF_TEXTURE_PATH: String = "res://assets/art/items/Hojas.png"
const SALTUS_CREATURE_SCRIPT = preload("res://scripts/world/saltus_creature_2d.gd")
const LEVEL_WIDTH_TILES: int = 120

@export_enum("despejado", "nublado", "lluvia", "tormenta", "niebla", "nieve") var clima_escena: String = "despejado"
@export var iluminacion_escena: Color = Color("#FFFDF2")
const GROUND_TOP: int = 14
const TILE_SEQUENCE: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(3, 3),
	Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 0), Vector2i(3, 2),
	Vector2i(2, 3), Vector2i(3, 1),
	Vector2i(1, 3), Vector2i(0, 1),
	Vector2i(1, 0), Vector2i(2, 2),
	Vector2i(3, 0), Vector2i(2, 0),
	Vector2i(1, 1), Vector2i(2, 1),
]
const CORNER_NEIGHBORS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]

var _terrain_layer: TileMapDual
var _player: SaltusPlayer
var _platforms: Array[Dictionary] = []
var _fondo_cielo: Sprite2D


func _ready() -> void:
	_player = get_node_or_null("Player") as SaltusPlayer
	if not is_instance_valid(_player):
		push_error("Saltus: no se encontró el nodo Player.")
		return

	_player.visible = true
	_player.position = Vector2(96.0, float(GROUND_TOP * TILE_SIZE - 40))
	_player.velocity = Vector2.ZERO
	_player.z_as_relative = false
	_player.z_index = 100
	var sprite := _player.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(sprite):
		sprite.visible = true
		sprite.z_as_relative = true
		sprite.z_index = 0
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_crear_terreno()
	_crear_fondo_y_parallax()
	_crear_arboleda()
	_crear_criaturas()
	_crear_ambiente()
	_configurar_camara()
	print("Saltus: inicializado | terreno=", is_instance_valid(_terrain_layer), " | celdas=", _terrain_layer.get_used_cells().size() if is_instance_valid(_terrain_layer) else 0, " | jugador=", _player.global_position)


func _process(_delta: float) -> void:
	if is_instance_valid(_player) and _player.global_position.y > 900.0:
		_player.global_position = Vector2(96.0, float(GROUND_TOP * TILE_SIZE - 40))
		_player.velocity = Vector2.ZERO


func _crear_terreno() -> void:
	var textura := load(TILESET_TEXTURE_PATH) as Texture2D
	if textura == null or textura.get_width() < TILE_SIZE * 4 or textura.get_height() < TILE_SIZE * 4:
		push_error("Saltus: Bosque.png no contiene el atlas 4x4 esperado.")
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "<any>")
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 1, "Bosque")

	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coords in TILE_SEQUENCE:
		atlas.create_tile(coords)
	tile_set.add_source(atlas, 0)
	for index in range(TILE_SEQUENCE.size()):
		var data := atlas.get_tile_data(TILE_SEQUENCE[index], 0)
		data.terrain_set = 0
		data.terrain = 1
		var bits := index
		for neighbor in CORNER_NEIGHBORS:
			data.set_terrain_peering_bit(neighbor, 1 if (bits & 1) != 0 else 0)
			bits >>= 1

	_terrain_layer = TileMapDual.new()
	_terrain_layer.name = "TerrenoBosque"
	_terrain_layer.tile_set = tile_set
	_terrain_layer.z_as_relative = false
	_terrain_layer.z_index = 0
	_terrain_layer.rendering_quadrant_size = 16
	_terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain_layer)

	# El suelo tiene dos cortes que obligan a elegir rutas elevadas o saltar.
	var tramos_suelo: Array[Vector2i] = [Vector2i(0, 25), Vector2i(30, 62), Vector2i(67, LEVEL_WIDTH_TILES)]
	for tramo in tramos_suelo:
		for x in range(tramo.x, tramo.y):
			for y in range(GROUND_TOP, GROUND_TOP + 6):
				_terrain_layer.set_cell(Vector2i(x, y), 0, TILE_ATLAS_DEFAULT)
		_crear_colision_suelo(tramo.x, tramo.y - tramo.x)

	# Plataformas visuales del mismo atlas original, con colisión unidireccional.
	for datos in [
		# Ruta inicial: ascenso por plataformas escalonadas.
		{"x": 7, "y": 12, "w": 4}, {"x": 13, "y": 10, "w": 4},
		{"x": 19, "y": 8, "w": 5}, {"x": 25, "y": 11, "w": 4},
		# Primer corte: puente bajo y ruta superior alternativa.
		{"x": 25, "y": 12, "w": 5}, {"x": 29, "y": 10, "w": 4},
		{"x": 35, "y": 8, "w": 5}, {"x": 42, "y": 10, "w": 4},
		{"x": 48, "y": 12, "w": 5}, {"x": 54, "y": 9, "w": 5},
		# Zona central: plataformas en zigzag y mirador elevado.
		{"x": 61, "y": 12, "w": 6}, {"x": 68, "y": 10, "w": 4},
		{"x": 73, "y": 8, "w": 5}, {"x": 80, "y": 6, "w": 5},
		{"x": 87, "y": 9, "w": 5}, {"x": 94, "y": 11, "w": 4},
		# Último tramo: rutas paralelas y descenso hacia la salida.
		{"x": 100, "y": 8, "w": 5}, {"x": 107, "y": 10, "w": 5},
		{"x": 113, "y": 12, "w": 5},
	]:
		var inicio_x := int(datos["x"])
		var fila_y := int(datos["y"])
		var ancho := int(datos["w"])
		for x in range(inicio_x, inicio_x + ancho):
			_terrain_layer.set_cell(Vector2i(x, fila_y), 0, TILE_ATLAS_DEFAULT)
		_crear_colision_plataforma(inicio_x, fila_y, ancho)

	call_deferred("_actualizar_tiles_dual")


func _crear_colision_suelo(inicio_x: int, ancho: int) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "ColisionSuelo"
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho * TILE_SIZE, 6.0 * TILE_SIZE)
	forma.shape = rect
	forma.position = Vector2((inicio_x + ancho * 0.5) * TILE_SIZE, (GROUND_TOP + 3.0) * TILE_SIZE)
	cuerpo.add_child(forma)
	add_child(cuerpo)


func _crear_colision_plataforma(inicio_x: int, fila_y: int, ancho: int) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Plataforma_%d_%d" % [inicio_x, fila_y]
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho * TILE_SIZE, 16.0)
	forma.shape = rect
	forma.position = Vector2((inicio_x + ancho * 0.5) * TILE_SIZE, fila_y * TILE_SIZE + 8.0)
	cuerpo.add_child(forma)
	add_child(cuerpo)


func _actualizar_tiles_dual() -> void:
	if not is_instance_valid(_terrain_layer):
		return
	await get_tree().process_frame
	_terrain_layer.reconstruir_renderer_dual()
	print("Saltus: TileMapDual bosque | celdas=", _terrain_layer.get_used_cells().size(), " atlas=", TILESET_TEXTURE_PATH)


func _finalizar_renderer_terreno() -> void:
	await get_tree().process_frame
	if is_instance_valid(_terrain_layer):
		_terrain_layer.reconstruir_renderer_dual()


func _crear_fondo_y_parallax() -> void:
	# El cielo y las montañas usan los fondos dibujados para Saltus.
	_fondo_cielo = _crear_capa_parallax(
		"Cielo", "res://assets/art/kingdom/Saltus/2D Section/Cielo.png",
		0.06, -30, false
	)
	_crear_capa_parallax(
		"Montanas", "res://assets/art/kingdom/Saltus/2D Section/Montaña.png",
		0.12, -24, true
	)


func _crear_arboleda() -> void:
	# Cada bosque es una capa independiente; se conserva su tamaño original.
	_crear_capa_parallax(
		"BosqueLejano", "res://assets/art/kingdom/Saltus/2D Section/Bosque lejano.png",
		0.22, -22, true
	)
	_crear_capa_parallax(
		"BosqueMedio", "res://assets/art/kingdom/Saltus/2D Section/BOSQUE medio.png",
		0.48, -12, true
	)
	_crear_capa_parallax(
		"BosqueCercano", "res://assets/art/kingdom/Saltus/2D Section/Bosque cerca.png",
		0.78, -4, true
	)


func _crear_capa_parallax(
	nombre: String,
	ruta_textura: String,
	velocidad: float,
	profundidad: int,
	alinear_suelo: bool
) -> Sprite2D:
	var textura := load(ruta_textura) as Texture2D
	if textura == null:
		push_error("Saltus: no se pudo cargar la capa de fondo: " + ruta_textura)
		return null

	var capa := Parallax2D.new()
	capa.name = "Parallax" + nombre
	capa.scroll_scale = Vector2(velocidad, 1.0)
	capa.repeat_size = Vector2(textura.get_width(), 0.0)
	capa.z_as_relative = false
	capa.z_index = profundidad
	add_child(capa)

	var sprite := Sprite2D.new()
	sprite.name = nombre
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var x_centro := textura.get_width() * 0.5
	var y_centro := (
		float(GROUND_TOP * TILE_SIZE) - textura.get_height() * 0.5
		if alinear_suelo
		else textura.get_height() * 0.5
	)
	sprite.position = Vector2(x_centro, y_centro)
	# El sprite debe heredar la profundidad negativa del Parallax2D.
	# Con z_as_relative=false quedaba en z=0 y perdía el orden de capas.
	sprite.z_as_relative = true
	sprite.z_index = 0
	capa.add_child(sprite)
	print(
		"Saltus: fondo cargado | ", nombre,
		" | tamaño=", textura.get_width(), "x", textura.get_height(),
		" | posición=", sprite.position,
		" | z=", capa.z_index
	)
	return sprite


func _crear_criaturas() -> void:
	# Zlish recorre tramos de suelo y plataformas, saltando de forma periódica.
	for posicion in [Vector2(620.0, 400.0), Vector2(1460.0, 336.0), Vector2(2480.0, 400.0)]:
		var zlish := _crear_criatura("Zlish", posicion)
		zlish.patrol_range = 145.0
		zlish.jump_interval_min = 1.8
		zlish.jump_interval_max = 3.8
	# Flaxis patrulla en altura y detecta al jugador para lanzarse en picada.
	for posicion in [Vector2(1040.0, 220.0), Vector2(2180.0, 190.0), Vector2(3300.0, 240.0)]:
		var flaxis := _crear_criatura("Flaxis", posicion)
		flaxis.detection_range = 235.0
		flaxis.flight_speed = 105.0
		flaxis.attack_damage = 8


func _crear_criatura(especie: String, posicion: Vector2) -> SaltusCreature2D:
	var criatura := SALTUS_CREATURE_SCRIPT.new() as SaltusCreature2D
	criatura.name = "%s_%d" % [especie, int(posicion.x)]
	criatura.especie = especie
	criatura.position = posicion
	criatura.z_as_relative = false
	criatura.z_index = 110
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if especie == "Zlish":
		sprite.texture = load("res://assets/art/creatures/Zlish/Zlish_Idle.png") as Texture2D
		sprite.hframes = 11
		sprite.position = Vector2(0.0, -17.0)
	else:
		sprite.texture = load("res://assets/art/creatures/Flaxis/Flaxis.png") as Texture2D
		sprite.position = Vector2.ZERO
	criatura.add_child(sprite)
	var colision := CollisionShape2D.new()
	var forma := CapsuleShape2D.new()
	forma.radius = 9.0 if especie == "Zlish" else 8.0
	forma.height = 22.0 if especie == "Zlish" else 18.0
	colision.shape = forma
	colision.position = Vector2(0.0, -10.0) if especie == "Zlish" else Vector2.ZERO
	criatura.add_child(colision)
	add_child(criatura)
	return criatura


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
	camara.global_position = _player.global_position + Vector2(0.0, -48.0)
	camara.zoom = Vector2(1.35, 1.35)
	camara.make_current()
	camara.reset_smoothing()
	camara.limit_left = 0
	camara.limit_right = LEVEL_WIDTH_TILES * TILE_SIZE
	camara.limit_top = -120
	camara.limit_bottom = 820
	camara.position_smoothing_enabled = true
	camara.position_smoothing_speed = 5.5
	camara.drag_horizontal_enabled = true
	camara.drag_vertical_enabled = false
	print("Saltus: cámara activa=", camara.is_current(), " jugador=", _player.global_position, " tiles=", _terrain_layer.get_used_cells().size() if is_instance_valid(_terrain_layer) else 0)
