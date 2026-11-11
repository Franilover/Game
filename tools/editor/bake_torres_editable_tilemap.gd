@tool
extends EditorScript
## Convierte el terreno actual de Reino Torres en capas TileMapDual editables.
## Ejecutar desde el editor con scenes/kingdom/reino_torres.tscn abierto.

const SCENE_PATH := "res://scenes/kingdom/reino_torres.tscn"
const TILE_SIZE := 32
const ORIGIN := Vector2(-1200.0, -704.0)
const COLUMNS := 75
const ROWS := 44
const ZONES := [0, 1, 8]
const ZONE_TEXTURES := {
	0: "res://assets/tilesets/Pradera.png",
	1: "res://assets/tilesets/Tierra.png",
	8: "res://assets/tilesets/Bosque.png",
}
const ZONE_NAMES := {
	0: "Pradera",
	1: "Tierra",
	8: "Bosque",
}
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
const ROAD_NODES := [
	"NorthPath", "MainStreet", "WestStreet", "EastStreet", "SouthPath",
	"NorthRingRoad", "SouthRingRoad", "WestRingRoad", "EastRingRoad",
	"NorthCrossStreet", "SouthCrossStreet", "WestCrossStreet", "EastCrossStreet",
	"NorthAvenue", "SouthAvenue", "WestAvenue", "EastAvenue",
	"RoadToAdventure",
]


func _run() -> void:
	var root := get_editor_interface().get_edited_scene_root() as Node2D
	if root == null or root.scene_file_path != SCENE_PATH:
		push_error("Abre scenes/kingdom/reino_torres.tscn antes de ejecutar este script.")
		return

	for zone in ZONES:
		if root.get_node_or_null("TerrainDual_Zone_%02d" % zone) != null:
			push_error("La escena ya contiene capas TileMapDual. No se modificó para evitar duplicarlas.")
			return

	var roads: Array[PackedVector2Array] = []
	for road_name in ROAD_NODES:
		var road := root.get_node_or_null(NodePath(road_name)) as Polygon2D
		if road == null or road.polygon.size() < 3:
			push_error("Falta el polígono de camino requerido: " + road_name)
			return
		roads.append(road.polygon)

	var cells_by_zone: Dictionary = {0: [], 1: [], 8: []}
	for y in range(ROWS):
		for x in range(COLUMNS):
			var cell := Vector2i(x, y)
			var center := ORIGIN + Vector2(
				(float(x) + 0.5) * TILE_SIZE,
				(float(y) + 0.5) * TILE_SIZE
			)
			var zone := 0
			if _point_in_roads(center, roads):
				zone = 1
			elif x < 3 or x >= COLUMNS - 3 or y < 3 or y >= ROWS - 3:
				zone = 8
			cells_by_zone[zone].append(cell)

	for zone in ZONES:
		var layer := TileMapDual.new()
		layer.name = "TerrainDual_Zone_%02d" % zone
		layer.position = ORIGIN
		layer.z_as_relative = false
		layer.z_index = -4094 if zone == 0 else -4095
		layer.rendering_quadrant_size = 16
		layer.godot_4_3_compatibility = false
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.tile_set = _build_tileset(zone)
		for cell: Vector2i in cells_by_zone[zone]:
			# El TileMapDual conserva su propia máscara de terreno y genera
			# la pieza visual correcta según las celdas vecinas.
			layer.set_cell(cell, 0, TILE_SEQUENCE[15])
		root.add_child(layer)
		layer.owner = root

	var ground := root.get_node_or_null("Ground") as Polygon2D
	if ground != null:
		ground.visible = false
	for road_name in ROAD_NODES:
		var road := root.get_node_or_null(NodePath(road_name)) as Polygon2D
		if road != null:
			# Se conservan como guías geométricas ocultas hasta validar el mapa.
			road.visible = false

	var total := 0
	for zone in ZONES:
		total += cells_by_zone[zone].size()
	if total != COLUMNS * ROWS:
		push_error("La conversión no produjo las 3.300 celdas esperadas.")
		return

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		push_error("No se pudo empaquetar Reino Torres: " + error_string(pack_error))
		return
	var save_error := ResourceSaver.save(packed, SCENE_PATH)
	if save_error != OK:
		push_error("No se pudo guardar la escena de Torres: " + error_string(save_error))
		return

	get_editor_interface().get_resource_filesystem().scan()
	print("Reino Torres convertido a TileMapDual editable: %d celdas." % total)
	for zone in ZONES:
		print("%s: %d celdas." % [ZONE_NAMES[zone], cells_by_zone[zone].size()])
	print("Guarda/cierra y vuelve a abrir la escena. Pinta cada capa con su terreno en el panel TileMap.")
	print("Las capas ocultas de polígonos se conservan como guías hasta validar el resultado.")


func _point_in_roads(point: Vector2, roads: Array[PackedVector2Array]) -> bool:
	for polygon in roads:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _build_tileset(zone: int) -> TileSet:
	var texture := load(str(ZONE_TEXTURES[zone])) as Texture2D
	if texture == null:
		push_error("No se pudo cargar el atlas: " + str(ZONE_TEXTURES[zone]))
		return null

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_terrain_set()
	tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 0, "<any>")
	tile_set.add_terrain(0)
	tile_set.set_terrain_name(0, 1, str(ZONE_NAMES[zone]))

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
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
	return tile_set
