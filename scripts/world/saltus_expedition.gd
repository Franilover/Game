extends Node2D
class_name SaltusExpedition

const TILE_SIZE: int = 32
const TILE_ATLAS_DEFAULT: Vector2i = Vector2i(2, 1)
const TILESET_TEXTURE_PATH: String = "res://assets/tilesets/Bosque.png"
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
const LEVEL_WIDTH_TILES: int = 160

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

	_crear_relleno_fondo()
	_crear_terreno()
	_crear_grafo_sector()
	_crear_puntos_sector()
	_crear_fondo_y_parallax()
	_crear_arboleda()
	_crear_criaturas()
	_crear_ambiente()
	_crear_mecanicas_ambientales()
	_configurar_camara()
	print("Saltus: inicializado | terreno=", is_instance_valid(_terrain_layer), " | celdas=", _terrain_layer.get_used_cells().size() if is_instance_valid(_terrain_layer) else 0, " | jugador=", _player.global_position)


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
	# Relleno sólido detrás del terreno y de todas las capas visuales.
	var relleno := Polygon2D.new()
	relleno.name = "RellenoVerdeFondo"
	relleno.color = Color("#2B5229")
	relleno.polygon = PackedVector2Array([
		Vector2(-512.0, -512.0),
		Vector2(LEVEL_WIDTH_TILES * TILE_SIZE + 512.0, -512.0),
		Vector2(LEVEL_WIDTH_TILES * TILE_SIZE + 512.0, 1536.0),
		Vector2(-512.0, 1536.0)
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
	_terrain_layer.name = "TerrenoSaltus"
	_terrain_layer.tile_set = tile_set
	_terrain_layer.z_as_relative = false
	_terrain_layer.z_index = 0
	_terrain_layer.rendering_quadrant_size = 16
	_terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain_layer)

	# Claro central y dos descensos hacia las galerías de Raíces.
	var suelos: Array[Dictionary] = [
		{"x": 0, "y": 14, "w": 28, "d": 6},
		{"x": 34, "y": 14, "w": 22, "d": 6},
		{"x": 60, "y": 14, "w": 26, "d": 6},
		{"x": 94, "y": 14, "w": 66, "d": 6},
		{"x": 28, "y": 29, "w": 18, "d": 6},
		{"x": 50, "y": 27, "w": 16, "d": 6},
		{"x": 70, "y": 30, "w": 18, "d": 6},
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

	# Arboleda: rutas ascendentes, cruces altos y descensos conectados.
	var plataformas: Array[Dictionary] = [
		{"x": 7, "y": 12, "w": 5}, {"x": 14, "y": 10, "w": 5},
		{"x": 21, "y": 8, "w": 6}, {"x": 29, "y": 6, "w": 6},
		{"x": 37, "y": 4, "w": 7}, {"x": 46, "y": 6, "w": 6},
		{"x": 53, "y": 9, "w": 6}, {"x": 63, "y": 12, "w": 7},
		{"x": 71, "y": 10, "w": 6}, {"x": 78, "y": 7, "w": 7},
		{"x": 87, "y": 5, "w": 7}, {"x": 97, "y": 3, "w": 7},
		{"x": 106, "y": 6, "w": 7}, {"x": 112, "y": 4, "w": 7},
		{"x": 118, "y": 2, "w": 7}, {"x": 124, "y": 0, "w": 7},
		{"x": 130, "y": -2, "w": 7}, {"x": 136, "y": -4, "w": 7},
		{"x": 142, "y": -6, "w": 7}, {"x": 148, "y": -8, "w": 7},
		{"x": 154, "y": -10, "w": 6},
		{"x": 29, "y": 19, "w": 7}, {"x": 38, "y": 22, "w": 8},
		# Escalera de retorno: permite salir de Raíces sin depender del Impulso Aéreo.
		{"x": 70, "y": 28, "w": 5}, {"x": 74, "y": 26, "w": 5},
		{"x": 81, "y": 22, "w": 5},
		{"x": 84, "y": 20, "w": 5}, {"x": 87, "y": 18, "w": 5},
		{"x": 90, "y": 16, "w": 5},
		{"x": 48, "y": 19, "w": 8}, {"x": 57, "y": 23, "w": 8},
		{"x": 67, "y": 20, "w": 8}, {"x": 78, "y": 24, "w": 8},
		{"x": 90, "y": 20, "w": 8},
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
	var claro: Variant = ROOM_DEFINITION_SCRIPT.new()
	claro.room_id = &"claro_central"
	claro.region_id = &"claro"
	claro.bounds = Rect2(0.0, 300.0, 3000.0, 420.0)
	claro.tags = PackedStringArray(["inicio", "descanso", "cruce"])
	var arboleda: Variant = ROOM_DEFINITION_SCRIPT.new()
	arboleda.room_id = &"arboleda_vertical"
	arboleda.region_id = &"arboleda"
	arboleda.bounds = Rect2(180.0, -1700.0, 4940.0, 2200.0)
	arboleda.tags = PackedStringArray(["vertical", "copas", "atajos"])
	var raices: Variant = ROOM_DEFINITION_SCRIPT.new()
	raices.room_id = &"raices_profundas"
	raices.region_id = &"raices"
	raices.bounds = Rect2(650.0, 650.0, 2300.0, 900.0)
	raices.tags = PackedStringArray(["subterraneo", "cavernas", "mineral"])
	var copa: Variant = ROOM_DEFINITION_SCRIPT.new()
	copa.room_id = &"copa_oriental"
	copa.region_id = &"copa"
	copa.bounds = Rect2(3000.0, 300.0, 2200.0, 500.0)
	copa.tags = PackedStringArray(["elevado", "bosque", "paso_bloqueado"])
	_world_graph.rooms = [claro, arboleda, raices, copa]
	var a: Variant = WORLD_CONNECTION_SCRIPT.new()
	a.connection_id = &"claro_arboleda"
	a.room_a = &"claro_central"
	a.room_b = &"arboleda_vertical"
	var b: Variant = WORLD_CONNECTION_SCRIPT.new()
	b.connection_id = &"claro_raices"
	b.room_a = &"claro_central"
	b.room_b = &"raices_profundas"
	var c: Variant = WORLD_CONNECTION_SCRIPT.new()
	c.connection_id = &"raices_copa_impulso"
	c.room_a = &"raices_profundas"
	c.room_b = &"copa_oriental"
	c.requirement_type = WORLD_CONNECTION_SCRIPT.RequirementType.ABILITY
	c.requirement_key = &"impulso_aereo"
	_world_graph.connections = [a, b, c]
	add_child(_world_graph)
	_world_graph.discover_room(&"claro_central")


func _crear_puntos_sector() -> void:
	_crear_punto_descanso(Vector2(480.0, 448.0))
	# Descanso en el suelo principal de Raíces profundas.
	_crear_punto_descanso(Vector2(2480.0, 960.0))
	var hallazgo := Area2D.new()
	hallazgo.name = "NucleoDeImpulso"
	hallazgo.position = Vector2(2600.0, 190.0)
	hallazgo.collision_layer = 0
	hallazgo.collision_mask = 2
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 24.0
	forma.shape = circulo
	hallazgo.add_child(forma)
	var visual := Polygon2D.new()
	visual.color = Color("#B9D7A5")
	visual.polygon = PackedVector2Array([Vector2(0, -22), Vector2(13, -5), Vector2(8, 18), Vector2(-8, 18), Vector2(-13, -5)])
	hallazgo.add_child(visual)
	hallazgo.body_entered.connect(_al_recoger_nucleo.bind(hallazgo))
	add_child(hallazgo)
	_sector_gate = StaticBody2D.new()
	_sector_gate.name = "AtajoSellado"
	_sector_gate.position = Vector2(2880.0, 600.0)
	_sector_gate.collision_layer = 1
	_sector_gate.collision_mask = 0
	var gate_shape := CollisionShape2D.new()
	var gate_rect := RectangleShape2D.new()
	gate_rect.size = Vector2(20.0, 1100.0)
	gate_shape.shape = gate_rect
	_sector_gate.add_child(gate_shape)
	var gate_visual := Polygon2D.new()
	gate_visual.color = Color("#596B4B")
	gate_visual.polygon = PackedVector2Array([Vector2(-10, -550), Vector2(10, -550), Vector2(10, 550), Vector2(-10, 550)])
	_sector_gate.add_child(gate_visual)
	add_child(_sector_gate)


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
	if _last_rest_position.distance_squared_to(nuevo_punto) <= 4.0:
		return

	_last_rest_position = nuevo_punto
	if is_instance_valid(_active_checkpoint):
		var anterior := _active_checkpoint.get_node_or_null("FlorCheckpointSprite") as Sprite2D
		if is_instance_valid(anterior):
			anterior.modulate = Color.WHITE
	_active_checkpoint = checkpoint
	var sprite_actual := checkpoint.get_node_or_null("FlorCheckpointSprite") as Sprite2D
	if is_instance_valid(sprite_actual):
		sprite_actual.modulate = Color(0.72, 1.0, 0.68, 1.0)
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


func _crear_mecanicas_ambientales() -> void:
	# Barrera del claro oriental: la flor detectora abre este paso al tocarla.
	var puerta := SWITCH_GATE_SCRIPT.new() as StaticBody2D
	puerta.name = "PuertaFlorDetectora"
	puerta.position = Vector2(1776.0, 250.0)
	puerta.set("gate_size", Vector2(28.0, 1100.0))
	add_child(puerta)

	var interruptor := SWITCH_FLOWER_SCRIPT.new() as Area2D
	interruptor.name = "FlorDetectora_1712"
	interruptor.position = Vector2(1712.0, 448.0)
	add_child(interruptor)

	# Corrientes ascendentes que ayudan a recorrer las rutas altas de Arboleda.
	for configuracion in [
		{"posicion": Vector2(1680.0, 180.0), "direccion": Vector2(-0.12, -1.0), "fuerza": 560.0},
		{"posicion": Vector2(3020.0, 40.0), "direccion": Vector2(0.55, -0.85), "fuerza": 490.0},
		{"posicion": Vector2(4380.0, -170.0), "direccion": Vector2(0.1, -1.0), "fuerza": 620.0}
	]:
		var corriente := WIND_CURRENT_SCRIPT.new() as Area2D
		corriente.name = "CorrienteAerea_%d" % int(configuracion["posicion"].x)
		corriente.position = configuracion["posicion"]
		corriente.set("direction", configuracion["direccion"])
		corriente.set("acceleration", float(configuracion["fuerza"]))
		add_child(corriente)

	# Hongos elásticos: permiten ganar altura y enlazar plataformas alternativas.
	for posicion in [
		Vector2(1240.0, 448.0),
		Vector2(2520.0, 448.0),
		Vector2(3900.0, 448.0)
	]:
		var planta := BOUNCE_FLORA_SCRIPT.new() as Area2D
		planta.name = "FloraImpulsora_%d" % int(posicion.x)
		planta.position = posicion
		add_child(planta)


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
	# La cámara queda contenida en el rectángulo del mapa y el terreno.
	camara.limit_left = 0
	camara.limit_right = LEVEL_WIDTH_TILES * TILE_SIZE
	camara.limit_top = -1900
	camara.limit_bottom = 1500
	camara.limit_smoothed = false
	camara.position_smoothing_enabled = true
	camara.position_smoothing_speed = 5.5
	camara.drag_horizontal_enabled = true
	camara.drag_vertical_enabled = false
	print("Saltus: cámara activa=", camara.is_current(), " jugador=", _player.global_position, " tiles=", _terrain_layer.get_used_cells().size() if is_instance_valid(_terrain_layer) else 0)
