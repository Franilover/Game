extends Node2D
class_name SaltusExpedition

const TILE_SIZE: int = 32
const TILE_ATLAS_DEFAULT: Vector2i = Vector2i(2, 1)
const TILESET_TEXTURE_PATH: String = "res://assets/tilesets/Bosque.png"
const MAP_SCENE_PATH: String = "res://scenes/world/saltus_map_v2.tscn"
const TREE_TEXTURE_PATH: String = "res://assets/art/props/Árbol.png"
const LEAF_TEXTURE_PATH: String = "res://assets/art/items/Hojas.png"
const SALTUS_CREATURE_SCRIPT = preload("res://scripts/world/saltus_creature_2d.gd")
const WORLD_GRAPH_SCRIPT = preload("res://scripts/world/saltus_world_graph.gd")
const ROOM_DEFINITION_SCRIPT = preload("res://scripts/world/saltus_room_definition.gd")
const WORLD_CONNECTION_SCRIPT = preload("res://scripts/world/saltus_world_connection.gd")
const WIND_CURRENT_SCRIPT = preload("res://scripts/world/saltus_wind_current.gd")
const BOUNCE_FLORA_SCRIPT = preload("res://scripts/world/saltus_bounce_flora.gd")
const SWITCH_FLOWER_SCRIPT = preload("res://scripts/world/saltus_switch_flower.gd")
const SWITCH_GATE_SCRIPT = preload("res://scripts/world/saltus_switch_gate.gd")
const CHECKPOINT_TEXTURE_PATH: String = "res://assets/art/kingdom/Saltus/2D Section/Flor Checkpoint.png"
const LEVEL_WIDTH_TILES: int = 200

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
var _world_graph
var _ability_flags: Dictionary = {}
var _current_room_id: StringName = &""
var _last_rest_position: Vector2 = Vector2(480.0, 408.0)
var _active_checkpoint: Area2D
var _sector_gate: StaticBody2D


func _ready() -> void:
	_player = get_node_or_null("Player") as SaltusPlayer
	if not is_instance_valid(_player):
		push_error("Saltus: no se encontró el nodo Player.")
		return

	_player.visible = true
	_player.position = Vector2(96.0, 408.0)
	_player.velocity = Vector2.ZERO
	_player.z_as_relative = false
	_player.z_index = 100
	var sprite := _player.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(sprite):
		sprite.visible = true
		sprite.z_as_relative = true
		sprite.z_index = 0
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_crear_relleno_fondo()
	_cargar_mapa_editable()
	_crear_grafo_sector()
	_crear_puntos_sector()
	_crear_fondo_y_parallax()
	_crear_arboleda()
	_crear_criaturas()
	_crear_ambiente()
	_crear_mecanicas_ambientales()
	_configurar_camara()
	print("Saltus V2: mapa vertical conectado | jugador=", _player.global_position)

func _cargar_mapa_editable() -> void:
	var escena := load(MAP_SCENE_PATH) as PackedScene
	if escena == null:
		push_error("Saltus: falta la escena editable %s. Ejecuta tools/editor/build_saltus_editable_map.gd desde Godot." % MAP_SCENE_PATH)
		return
	var mapa := escena.instantiate()
	mapa.name = "MapaSaltus"
	add_child(mapa)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if _player.global_position.y > 1500.0:
		_player.global_position = _last_rest_position
		_player.velocity = Vector2.ZERO
		return
	if is_instance_valid(_world_graph):
		var room: Variant = _world_graph.get_room_at(_player.global_position)
		if room != null and room.room_id != _current_room_id:
			_current_room_id = room.room_id
			_world_graph.discover_room(_current_room_id)


func _crear_relleno_fondo() -> void:
	var relleno := Polygon2D.new()
	relleno.name = "RellenoVerdeFondo"
	relleno.color = Color("#2B5229")
	relleno.polygon = PackedVector2Array([
		Vector2(-512.0, -2800.0),
		Vector2(LEVEL_WIDTH_TILES * TILE_SIZE + 512.0, -2800.0),
		Vector2(LEVEL_WIDTH_TILES * TILE_SIZE + 512.0, 1600.0),
		Vector2(-512.0, 1600.0)
	])
	relleno.z_as_relative = false
	relleno.z_index = -100
	add_child(relleno)

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
	_terrain_layer.name = "TerrenoSaltusV2"
	_terrain_layer.tile_set = tile_set
	_terrain_layer.z_as_relative = false
	_terrain_layer.z_index = 0
	_terrain_layer.rendering_quadrant_size = 16
	_terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain_layer)

	# Pisos independientes: entrada, claro, galerías inferiores y arena final.
	var suelos: Array[Dictionary] = [
		{"x": 0, "y": 14, "w": 24, "d": 6},
		# Tres shafts controlados conectan el nivel superior con las galerías inferiores.
		{"x": 30, "y": 14, "w": 12, "d": 6},
		{"x": 48, "y": 14, "w": 7, "d": 6},
		{"x": 61, "y": 14, "w": 2, "d": 6},
		{"x": 67, "y": 14, "w": 18, "d": 6},
		{"x": 91, "y": 14, "w": 2, "d": 6},
		{"x": 97, "y": 14, "w": 22, "d": 6},
		{"x": 126, "y": 14, "w": 24, "d": 6},
		{"x": 158, "y": 14, "w": 42, "d": 6},
		{"x": 43, "y": 28, "w": 23, "d": 6},
		{"x": 72, "y": 30, "w": 25, "d": 6},
		{"x": 103, "y": 27, "w": 23, "d": 6},
		{"x": 132, "y": 29, "w": 18, "d": 6}
	]
	for suelo in suelos:
		var sx := int(suelo["x"])
		var sy := int(suelo["y"])
		var sw := int(suelo["w"])
		var sd := int(suelo["d"])
		for x in range(sx, sx + sw):
			for y in range(sy, sy + sd):
				_terrain_layer.set_cell(Vector2i(x, y), 0, TILE_ATLAS_DEFAULT)
		_crear_colision_bloque_solido(sx, sy, sw, sd)

	# Rutas de enseñanza: saltos cortos, un hueco de dash y parkour escalonado.
	var plataformas: Array[Dictionary] = [
		{"x": 4, "y": 12, "w": 4}, {"x": 10, "y": 10, "w": 4},
		# Puentes superiores sobre los shafts: dejan pasar por arriba sin tapar la caída inferior.
		{"x": 43, "y": 12, "w": 5}, {"x": 93, "y": 12, "w": 4},
		{"x": 16, "y": 11, "w": 4}, {"x": 23, "y": 12, "w": 4},
		{"x": 27, "y": 12, "w": 4}, {"x": 33, "y": 11, "w": 5},
		{"x": 39, "y": 9, "w": 5}, {"x": 46, "y": 10, "w": 5},
		{"x": 52, "y": 12, "w": 3},
		# Arboleda: ascenso principal y ruta superior de retorno.
		{"x": 63, "y": 12, "w": 5}, {"x": 68, "y": 10, "w": 5},
		{"x": 73, "y": 8, "w": 5}, {"x": 78, "y": 6, "w": 5},
		{"x": 83, "y": 4, "w": 5}, {"x": 88, "y": 2, "w": 5},
		{"x": 93, "y": 0, "w": 6}, {"x": 99, "y": -2, "w": 6},
		{"x": 105, "y": -4, "w": 6}, {"x": 111, "y": -2, "w": 6},
		{"x": 117, "y": 0, "w": 6}, {"x": 123, "y": 2, "w": 6},
		{"x": 129, "y": 4, "w": 6}, {"x": 135, "y": 6, "w": 6},
		# Ruta alta alternativa: cruza por encima de la arboleda y vuelve al claro.
		{"x": 70, "y": 3, "w": 5}, {"x": 76, "y": 1, "w": 5},
		{"x": 82, "y": -1, "w": 5}, {"x": 89, "y": -3, "w": 5},
		{"x": 96, "y": -5, "w": 5}, {"x": 103, "y": -7, "w": 5},
		{"x": 110, "y": -6, "w": 5}, {"x": 117, "y": -4, "w": 5},
		{"x": 124, "y": -2, "w": 5},
		# Copa alta: segundo ascenso, cresta superior y descenso conectado.
		{"x": 107, "y": -9, "w": 5}, {"x": 111, "y": -11, "w": 5},
		{"x": 115, "y": -13, "w": 5}, {"x": 119, "y": -15, "w": 5},
		{"x": 123, "y": -17, "w": 5}, {"x": 127, "y": -15, "w": 5},
		{"x": 131, "y": -13, "w": 5}, {"x": 135, "y": -11, "w": 5},
		{"x": 139, "y": -9, "w": 5}, {"x": 143, "y": -7, "w": 5},
		{"x": 147, "y": -5, "w": 5},
		# Descenso hacia Raíces profundas.
		{"x": 39, "y": 18, "w": 5}, {"x": 44, "y": 21, "w": 5},
		{"x": 49, "y": 24, "w": 5}, {"x": 55, "y": 26, "w": 5},
		{"x": 61, "y": 27, "w": 5}, {"x": 67, "y": 28, "w": 5},
		# Escalera de regreso desde el subsuelo: peldaños alternados y alcanzables.
		{"x": 66, "y": 26, "w": 4}, {"x": 70, "y": 24, "w": 4},
		{"x": 74, "y": 22, "w": 4}, {"x": 78, "y": 20, "w": 4},
		{"x": 82, "y": 18, "w": 4}, {"x": 86, "y": 16, "w": 4},
		{"x": 90, "y": 14, "w": 4},
		# Galerías inferiores: recorrido transversal y dos salidas.
		{"x": 78, "y": 28, "w": 6}, {"x": 86, "y": 26, "w": 6},
		{"x": 94, "y": 24, "w": 6}, {"x": 99, "y": 28, "w": 6},
		{"x": 103, "y": 27, "w": 6}, {"x": 108, "y": 25, "w": 6},
		{"x": 115, "y": 23, "w": 6}, {"x": 122, "y": 21, "w": 6},
		{"x": 126, "y": 29, "w": 6},
		# Retorno desde la galería oriental hasta el suelo de la arena.
		{"x": 132, "y": 27, "w": 5}, {"x": 136, "y": 25, "w": 5},
		{"x": 140, "y": 23, "w": 5}, {"x": 144, "y": 21, "w": 5},
		{"x": 148, "y": 19, "w": 5}, {"x": 152, "y": 17, "w": 5},
		{"x": 156, "y": 15, "w": 5}, {"x": 160, "y": 14, "w": 5},
		# Cruce de copas y conexión con la zona del jefe.
		{"x": 120, "y": 12, "w": 6}, {"x": 140, "y": 10, "w": 5},
		{"x": 146, "y": 7, "w": 5}, {"x": 150, "y": 12, "w": 8},
		{"x": 158, "y": 12, "w": 5},
		{"x": 166, "y": 11, "w": 5}, {"x": 174, "y": 9, "w": 5},
		{"x": 182, "y": 11, "w": 5}, {"x": 190, "y": 12, "w": 5}
	]
	for plataforma in plataformas:
		var px := int(plataforma["x"])
		var py := int(plataforma["y"])
		var pw := int(plataforma["w"])
		for x in range(px, px + pw):
			_terrain_layer.set_cell(Vector2i(x, py), 0, TILE_ATLAS_DEFAULT)
		_crear_colision_plataforma(px, py, pw)
	call_deferred("_actualizar_tiles_dual")

func _crear_colision_bloque_solido(inicio_x: int, fila_y: int, ancho: int, profundidad: int) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Terreno_%d_%d" % [inicio_x, fila_y]
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho * TILE_SIZE, profundidad * TILE_SIZE)
	forma.shape = rect
	forma.position = Vector2((inicio_x + ancho * 0.5) * TILE_SIZE, (fila_y + profundidad * 0.5) * TILE_SIZE)
	cuerpo.add_child(forma)
	add_child(cuerpo)


func _crear_grafo_sector() -> void:
	_world_graph = WORLD_GRAPH_SCRIPT.new()
	var definiciones: Array[Dictionary] = [
		{"id": &"entrada_claro", "region": &"entrada", "bounds": Rect2(0.0, 0.0, 1050.0, 700.0), "tags": ["inicio", "tutorial"]},
		{"id": &"sendero_parkour", "region": &"sendero", "bounds": Rect2(850.0, 0.0, 1100.0, 700.0), "tags": ["salto", "dash", "combate"]},
		{"id": &"arboleda_vertical", "region": &"arboleda", "bounds": Rect2(1850.0, -850.0, 2600.0, 1550.0), "tags": ["vertical", "ramas", "rutas_altas"]},
		{"id": &"raices_profundas", "region": &"raices", "bounds": Rect2(1200.0, 650.0, 3000.0, 700.0), "tags": ["subterraneo", "cavernas", "retorno"]},
		{"id": &"cruce_copas", "region": &"copas", "bounds": Rect2(3600.0, -850.0, 1500.0, 1350.0), "tags": ["altura", "atajos", "detectora"]},
		{"id": &"claro_jefe", "region": &"jefe", "bounds": Rect2(5000.0, 0.0, 1400.0, 700.0), "tags": ["arena", "encuentro"]},
	]
	var rooms: Array = []
	for definicion in definiciones:
		var room: Variant = ROOM_DEFINITION_SCRIPT.new()
		room.room_id = definicion["id"]
		room.region_id = definicion["region"]
		room.bounds = definicion["bounds"]
		room.tags = PackedStringArray(definicion["tags"])
		rooms.append(room)
	_world_graph.rooms = rooms

	var enlaces: Array[Array] = [
		[&"entrada_sendero", &"entrada_claro", &"sendero_parkour"],
		[&"sendero_arboleda", &"sendero_parkour", &"arboleda_vertical"],
		[&"sendero_raices", &"sendero_parkour", &"raices_profundas"],
		[&"arboleda_copas", &"arboleda_vertical", &"cruce_copas"],
		[&"raices_copas", &"raices_profundas", &"cruce_copas"],
		[&"copas_jefe", &"cruce_copas", &"claro_jefe"],
		[&"arboleda_raices", &"arboleda_vertical", &"raices_profundas"],
	]
	var connections: Array = []
	for enlace in enlaces:
		var connection: Variant = WORLD_CONNECTION_SCRIPT.new()
		connection.connection_id = enlace[0]
		connection.room_a = enlace[1]
		connection.room_b = enlace[2]
		connections.append(connection)
	_world_graph.connections = connections
	add_child(_world_graph)
	_world_graph.discover_room(&"entrada_claro")

func _crear_puntos_sector() -> void:
	_crear_punto_descanso(Vector2(96.0, 448.0))
	_crear_punto_descanso(Vector2(1536.0, 448.0))
	_crear_punto_descanso(Vector2(2400.0, 960.0))
	_crear_punto_descanso(Vector2(4480.0, 320.0))
	_crear_punto_descanso(Vector2(5344.0, 448.0))

	# Indicaciones breves integradas en el recorrido para enseñar cada acción.
	_crear_indicacion_tutorial("SALTA", Vector2(320.0, 330.0))
	_crear_indicacion_tutorial("PARKOUR", Vector2(1040.0, 300.0))
	_crear_indicacion_tutorial("DASH", Vector2(1500.0, 300.0))
	_crear_indicacion_tutorial("FLOR DETECTORA", Vector2(1632.0, 365.0))
	_crear_indicacion_tutorial("CRIATURAS", Vector2(2500.0, 300.0))

	# Zona de jefe: arena despejada y delimitada; el encuentro se añadirá después.
	var arena := Node2D.new()
	arena.name = "ZonaPrimerJefe"
	arena.position = Vector2(5600.0, 448.0)
	var marca := Polygon2D.new()
	marca.name = "MarcaArena"
	marca.color = Color(0.72, 0.78, 0.56, 0.14)
	marca.polygon = PackedVector2Array([
		Vector2(-250.0, -8.0), Vector2(250.0, -8.0),
		Vector2(220.0, -190.0), Vector2(-220.0, -190.0)
	])
	arena.add_child(marca)
	add_child(arena)

func _crear_indicacion_tutorial(texto: String, posicion: Vector2) -> void:
	var etiqueta := Label.new()
	etiqueta.name = "Indicacion_" + texto.replace(" ", "_")
	etiqueta.text = texto
	etiqueta.position = posicion
	etiqueta.z_as_relative = false
	etiqueta.z_index = 150
	etiqueta.add_theme_font_size_override("font_size", 14)
	etiqueta.add_theme_color_override("font_color", Color("#F1E8C8"))
	etiqueta.add_theme_color_override("font_outline_color", Color("#263A24"))
	etiqueta.add_theme_constant_override("outline_size", 5)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(etiqueta)


func _crear_punto_descanso(posicion: Vector2) -> void:
	var descanso := Area2D.new()
	descanso.name = "PuntoDescanso"
	descanso.position = posicion
	descanso.collision_layer = 0
	descanso.collision_mask = 2
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 32.0
	forma.shape = circulo
	forma.position.y = -20.0
	descanso.add_child(forma)
	var sprite := Sprite2D.new()
	sprite.name = "FlorCheckpointSprite"
	sprite.texture = load(CHECKPOINT_TEXTURE_PATH) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.0, 2.0)
	if sprite.texture != null:
		sprite.position.y = -sprite.texture.get_height() * sprite.scale.y * 0.5
	descanso.add_child(sprite)
	if sprite.texture == null:
		push_error("Saltus: no se pudo cargar " + CHECKPOINT_TEXTURE_PATH)
	descanso.body_entered.connect(_activar_descanso.bind(posicion, descanso))
	add_child(descanso)


func _activar_descanso(cuerpo: Node2D, posicion: Vector2, checkpoint: Area2D) -> void:
	if cuerpo != _player:
		return
	var nuevo_punto := posicion + Vector2(0.0, -24.0)
	if _last_rest_position.distance_squared_to(nuevo_punto) > 4.0:
		_last_rest_position = nuevo_punto
	if is_instance_valid(_active_checkpoint):
		var anterior := _active_checkpoint.get_node_or_null("FlorCheckpointSprite") as Sprite2D
		if is_instance_valid(anterior):
			anterior.modulate = Color.WHITE
	_active_checkpoint = checkpoint
	var sprite_actual := checkpoint.get_node_or_null("FlorCheckpointSprite") as Sprite2D
	if is_instance_valid(sprite_actual):
		sprite_actual.modulate = Color(0.72, 1.0, 0.68, 1.0)
		_animar_activacion_checkpoint(checkpoint, sprite_actual)
	print("Saltus: checkpoint activado en ", _last_rest_position)


func _al_recoger_nucleo(cuerpo: Node2D, hallazgo: Area2D) -> void:
	if cuerpo != _player:
		return
	_ability_flags["impulso_aereo"] = true
	if is_instance_valid(_player):
		_player.call("unlock_air_dash")
	if is_instance_valid(_world_graph):
		_world_graph.unlock_connection(&"raices_copa_impulso")
	if is_instance_valid(_sector_gate):
		_sector_gate.queue_free()
	if is_instance_valid(hallazgo):
		hallazgo.queue_free()
	print("Saltus: Impulso Aéreo adquirido | segundo dash en el aire habilitado | paso sellado abierto.")

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
	# Colisión de un solo sentido: bloquea al caer desde arriba, permite subir desde abajo.
	forma.one_way_collision = true
	forma.one_way_collision_margin = 8.0
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
	# Primeros Zlish: visibles y espaciados para presentar el combate sin saturar.
	for posicion in [Vector2(1280.0, 400.0), Vector2(1580.0, 400.0), Vector2(2460.0, 400.0), Vector2(3000.0, 920.0)]:
		var zlish := _crear_criatura("Zlish", posicion)
		zlish.patrol_range = 105.0
		zlish.jump_interval_min = 2.0
		zlish.jump_interval_max = 4.0
	# Flaxis aparece después, en las rutas elevadas.
	for posicion in [Vector2(2720.0, -120.0), Vector2(3520.0, -280.0), Vector2(4250.0, -420.0)]:
		var flaxis := _crear_criatura("Flaxis", posicion)
		flaxis.detection_range = 220.0
		flaxis.flight_speed = 100.0
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


func _crear_mecanicas_ambientales() -> void:
	# Detectora: enseña a activar mecanismos y abre un atajo entre dos plataformas.
	var puerta := SWITCH_GATE_SCRIPT.new() as StaticBody2D
	puerta.name = "PuertaFlorDetectora"
	puerta.position = Vector2(1696.0, 248.0)
	puerta.set("gate_size", Vector2(24.0, 420.0))
	add_child(puerta)
	var detectora := SWITCH_FLOWER_SCRIPT.new() as Area2D
	detectora.name = "FlorDetectora_Tutorial"
	detectora.position = Vector2(1632.0, 448.0)
	add_child(detectora)

	# Flores saltarinas colocadas en cruces: ayudan a explorar rutas verticales.
	for posicion in [
		Vector2(1184.0, 448.0),
		Vector2(2080.0, 896.0),
		Vector2(3104.0, 960.0),
		Vector2(4032.0, -128.0),
		Vector2(4704.0, 448.0)
	]:
		var planta := BOUNCE_FLORA_SCRIPT.new() as Area2D
		planta.name = "FloraImpulsora_%d" % int(posicion.x)
		planta.position = posicion
		add_child(planta)

	# Corrientes de aire en la parte alta para conectar las rutas de las copas.
	for configuracion in [
		{"posicion": Vector2(2700.0, -180.0), "direccion": Vector2(-0.15, -1.0), "fuerza": 500.0},
		{"posicion": Vector2(3550.0, -460.0), "direccion": Vector2(0.45, -0.9), "fuerza": 540.0},
		{"posicion": Vector2(4380.0, -520.0), "direccion": Vector2(0.1, -1.0), "fuerza": 570.0}
	]:
		var corriente := WIND_CURRENT_SCRIPT.new() as Area2D
		corriente.name = "CorrienteAerea_%d" % int(configuracion["posicion"].x)
		corriente.position = configuracion["posicion"]
		corriente.set("direction", configuracion["direccion"])
		corriente.set("acceleration", float(configuracion["fuerza"]))
		add_child(corriente)

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
	camara.limit_top = -900
	camara.limit_bottom = 1600
	camara.limit_smoothed = false
	camara.position_smoothing_enabled = true
	camara.position_smoothing_speed = 5.5
	camara.drag_horizontal_enabled = true
	camara.drag_vertical_enabled = true
	camara.drag_top_margin = 0.18
	camara.drag_bottom_margin = 0.18
	print("Saltus V2: cámara vertical activa | límites=", camara.limit_left, ",", camara.limit_top, " -> ", camara.limit_right, ",", camara.limit_bottom)

func _animar_activacion_checkpoint(checkpoint: Area2D, sprite: Sprite2D) -> void:
	var onda := Line2D.new()
	onda.name = "OndaCheckpoint"
	onda.width = 3.5
	onda.default_color = Color(1.0, 0.82, 0.22, 0.95)
	onda.antialiased = true
	for indice in range(49):
		var angulo := TAU * float(indice) / 48.0
		onda.add_point(Vector2(cos(angulo), sin(angulo)))
	checkpoint.add_child(onda)
	onda.position = sprite.position
	onda.scale = Vector2(3.8, 3.8)
	var onda_tween := create_tween()
	onda_tween.set_parallel(true)
	onda_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	onda_tween.tween_property(onda, "scale", Vector2(0.12, 0.12), 0.58)
	onda_tween.tween_property(onda, "modulate:a", 0.0, 0.58)
	onda_tween.chain().tween_callback(onda.queue_free)
	var brillo := create_tween()
	brillo.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	brillo.tween_property(sprite, "modulate", Color(1.0, 0.96, 0.58, 1.0), 0.12)
	brillo.tween_property(sprite, "modulate", Color(0.72, 1.0, 0.68, 1.0), 0.3)
