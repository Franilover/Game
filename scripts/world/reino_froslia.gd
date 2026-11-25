extends Node2D
## Primera versión explorable de Froslia: terreno nevado y tres edificios.

signal centro_expediciones_interactuado

const CONTEXTUAL_ACTION_TARGET_SCRIPT: Script = preload("res://scripts/gameplay/interaction/contextual_action_target.gd")
const BUILDING_SERVICE_UI_SCRIPT: Script = preload("res://scripts/ui/building_service_ui.gd")

const TILE_SIZE := 32
const TILE_MAP_DUAL_SCRIPT: Script = preload("res://addons/TileMapDual/tile_map_dual.gd")
const GHOST_MATERIAL: Material = preload("res://addons/TileMapDual/ghost_material.tres")
const TILE_SEQUENCE: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1),
	Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2),
	Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1),
]
const NEIGHBORS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]
const BUILDINGS: Array[Dictionary] = [
	{"name": "Centro de Expediciones", "path": "res://assets/art/kingdom/Froslia/Edificios/Centro de Expediciones.png", "position": Vector2(-320.0, -240.0), "target_size": Vector2(136.0, 120.0)},
	{"name": "Escuela", "path": "res://assets/art/kingdom/Froslia/Edificios/Escuela.png", "position": Vector2(0.0, -400.0), "target_size": Vector2(132.0, 112.0)},
	{"name": "Cuartel de la Guardia", "path": "res://assets/art/kingdom/Froslia/Edificios/Cuartel_de_la_Guardia.png", "position": Vector2(320.0, -240.0), "target_size": Vector2(132.0, 112.0)},
]

var _terrain_layers: Array[TileMapDual] = []


func _ready() -> void:
	_crear_terreno()
	_crear_edificios()
	_crear_interaccion_centro_expediciones()
	_crear_limites()


func _crear_terreno() -> void:
	# Cada terreno usa su propio TileMapDual, igual que Pradera/Tierra en el mundo.
	# La capa inferior aporta el suelo y la superior compone sus bordes transparentes.
	var nieve_cells: Array[Vector2i] = []
	var tierra_cells: Array[Vector2i] = []
	var tierra_lookup: Dictionary = {}
	for y in range(-18, 18):
		for x in [-1, 0, 1]:
			_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, y))
	for x in range(-26, 26):
		for y in [-1, 0, 1]:
			_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, y))
	for y in range(-4, 5):
		for x in range(-6, 7):
			_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, y))
	for x in range(-10, -1):
		_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, -8))
	for y in range(-12, -1):
		_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(0, y))
	for x in range(1, 11):
		_agregar_celda_unica(tierra_cells, tierra_lookup, Vector2i(x, -8))

	# Las capas son excluyentes: la nieve no debe dibujarse encima de los caminos.
	for y in range(-18, 18):
		for x in range(-26, 26):
			var celda := Vector2i(x, y)
			if not tierra_lookup.has(celda):
				nieve_cells.append(celda)

	var capa_tierra := _crear_capa_dual("TerrenoTierraNevada", "res://assets/tilesets/Tierra Nevada.png", -4095)
	var capa_nieve := _crear_capa_dual("TerrenoNieve", "res://assets/tilesets/Nieve.png", -4094)
	await _preparar_capa_dual(capa_tierra, tierra_cells)
	await _preparar_capa_dual(capa_nieve, nieve_cells)


func _agregar_celda_unica(celdas: Array[Vector2i], lookup: Dictionary, celda: Vector2i) -> void:
	if lookup.has(celda):
		return
	lookup[celda] = true
	celdas.append(celda)


func _crear_capa_dual(nombre: String, ruta_textura: String, z: int) -> TileMapDual:
	var capa := TILE_MAP_DUAL_SCRIPT.new() as TileMapDual
	capa.name = nombre
	capa.z_index = z
	capa.z_as_relative = false
	capa.rendering_quadrant_size = 16
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.material = GHOST_MATERIAL
	capa.godot_4_3_compatibility = false
	capa.tile_set = _crear_tileset_dual(ruta_textura)
	add_child(capa)
	_terrain_layers.append(capa)
	return capa


func _preparar_capa_dual(capa: TileMapDual, celdas: Array[Vector2i]) -> void:
	if not is_instance_valid(capa) or celdas.is_empty():
		return
	await get_tree().process_frame
	capa.reconstruir_renderer_dual()
	for celda in celdas:
		capa.set_cell(celda, 0, Vector2i(2, 1))
	capa._update_cells(celdas, false)


func _crear_tileset_dual(ruta_textura: String) -> TileSet:
	var textura := load(ruta_textura) as Texture2D
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "<any>")
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 1, "Terreno")
	if textura == null:
		push_error("ReinoFroslia: no se pudo cargar el atlas: " + ruta_textura)
		return tile_set
	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coordenada in TILE_SEQUENCE:
		atlas.create_tile(coordenada)
	for indice in range(TILE_SEQUENCE.size()):
		var datos := atlas.get_tile_data(TILE_SEQUENCE[indice], 0)
		datos.terrain_set = 0
		datos.terrain = 1
		var bits := indice
		for vecino in NEIGHBORS:
			datos.set_terrain_peering_bit(vecino, 1 if (bits & 1) != 0 else 0)
			bits >>= 1
	tile_set.add_source(atlas, 0)
	return tile_set

func _crear_limites() -> void:
	# El terreno ocupa 52 x 36 celdas, desde (-26, -18) hasta (26, 18).
	# Los cuatro cuerpos cierran el perímetro sin añadir capas visuales.
	var izquierda := -26.0 * TILE_SIZE
	var derecha := 26.0 * TILE_SIZE
	var arriba := -18.0 * TILE_SIZE
	var abajo := 18.0 * TILE_SIZE
	var ancho := derecha - izquierda
	var alto := abajo - arriba
	_crear_muro_limite("LimiteOeste", Vector2(izquierda, (arriba + abajo) * 0.5), Vector2(64.0, alto))
	_crear_muro_limite("LimiteEste", Vector2(derecha, (arriba + abajo) * 0.5), Vector2(64.0, alto))
	_crear_muro_limite("LimiteNorte", Vector2((izquierda + derecha) * 0.5, arriba), Vector2(ancho, 64.0))
	_crear_muro_limite("LimiteSur", Vector2((izquierda + derecha) * 0.5, abajo), Vector2(ancho, 64.0))


func _crear_muro_limite(nombre: String, posicion: Vector2, tamano: Vector2) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = nombre
	cuerpo.position = posicion
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	var colision := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano
	colision.shape = rectangulo
	cuerpo.add_child(colision)
	add_child(cuerpo)


func _crear_edificios() -> void:
	for edificio in BUILDINGS:
		var ruta := str(edificio.get("path", ""))
		var textura := load(ruta) as Texture2D
		if textura == null:
			push_error("ReinoFroslia: no se pudo cargar el edificio: " + ruta)
			continue

		var cuerpo := StaticBody2D.new()
		cuerpo.name = str(edificio.get("name", "Edificio")).replace(" ", "")
		cuerpo.position = edificio.get("position", Vector2.ZERO)
		cuerpo.collision_layer = 1
		cuerpo.collision_mask = 0
		add_child(cuerpo)

		var colision := CollisionShape2D.new()
		var forma := RectangleShape2D.new()
		forma.size = Vector2(112.0, 64.0)
		colision.shape = forma
		colision.position = Vector2(0.0, 12.0)
		cuerpo.add_child(colision)

		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = textura
		sprite.position = Vector2(0.0, -42.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 2
		var tamano_objetivo: Vector2 = edificio.get("target_size", Vector2(132.0, 112.0))
		var tamano_textura := textura.get_size()
		if tamano_textura.x > 0.0 and tamano_textura.y > 0.0:
			var escala := minf(tamano_objetivo.x / tamano_textura.x, tamano_objetivo.y / tamano_textura.y)
			sprite.scale = Vector2.ONE * escala
		cuerpo.add_child(sprite)



func _crear_interaccion_centro_expediciones() -> void:
	# Los tres edificios usan el mismo servicio que sus equivalentes en Torres.
	_crear_objetivo_edificio("centro_expediciones", "Centro de Expediciones", Vector2(-320.0, -144.0))
	_crear_objetivo_edificio("escuela", "Escuela", Vector2(0.0, -304.0))
	_crear_objetivo_edificio("cuartel", "Cuartel de la Guardia", Vector2(320.0, -144.0))


func _crear_objetivo_edificio(tipo: String, nombre: String, posicion: Vector2) -> void:
	var objetivo := CONTEXTUAL_ACTION_TARGET_SCRIPT.new() as Node2D
	if not is_instance_valid(objetivo):
		push_error("ReinoFroslia: no se pudo crear la interacción de %s." % nombre)
		return
	objetivo.name = "Servicio_" + tipo
	objetivo.position = posicion
	objetivo.call(
		"configurar",
		"Interactuar · " + nombre,
		84.0,
		Callable(self, "_puede_interactuar_edificio"),
		Callable(self, "_abrir_menu_servicio_edificio").bind(tipo)
	)
	add_child(objetivo)


func _puede_interactuar_edificio(jugador: Node) -> bool:
	return is_instance_valid(jugador) and jugador.is_in_group("player")


func _abrir_menu_servicio_edificio(tipo: String, _jugador: Node) -> void:
	if get_tree().get_first_node_in_group("building_service_ui") != null:
		return
	var sistema := get_tree().get_first_node_in_group("interaction_system")
	if not is_instance_valid(sistema):
		Events.notification_pushed.emit("No se pudo acceder al sistema de interacción.")
		return
	var inventario := sistema.get("inventory") as InventoryController
	var world_items := sistema.get("world_items") as GarliaWorldItems
	if not is_instance_valid(inventario):
		Events.notification_pushed.emit("No se pudo acceder al inventario.")
		return
	var interfaz := BUILDING_SERVICE_UI_SCRIPT.new() as CanvasLayer
	if not is_instance_valid(interfaz):
		return
	interfaz.add_to_group("building_service_ui")
	if interfaz.has_signal("solicitar_selector_expediciones"):
		interfaz.connect("solicitar_selector_expediciones", Callable(self, "_abrir_selector_viajes_desde_servicio"))
	if interfaz.has_signal("solicitar_expedicion_saltus"):
		interfaz.connect("solicitar_expedicion_saltus", Callable(self, "_iniciar_expedicion_saltus"))
	get_tree().root.add_child(interfaz)
	interfaz.call("configurar", tipo, inventario, world_items, get_tree().get_first_node_in_group("player"))


func _abrir_selector_viajes_desde_servicio() -> void:
	var main := get_tree().root.find_child("Main", true, false)
	if is_instance_valid(main) and main.has_method("_abrir_menu_viaje_reinos"):
		main.call("_abrir_menu_viaje_reinos")


func _iniciar_expedicion_saltus() -> void:
	var gestor := get_tree().get_first_node_in_group("zone_manager")
	if is_instance_valid(gestor) and gestor.has_method("iniciar_expedicion_saltus"):
		gestor.call("iniciar_expedicion_saltus")
	else:
		Events.notification_pushed.emit("No se pudo iniciar la expedición Saltus.")
