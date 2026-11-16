@tool
extends EditorScript
## Rediseña el terreno de Torres con una retícula ampliada y barrios conectados.
## Ejecutar desde el editor con scenes/kingdom/reino_torres.tscn abierto.

const SCENE_PATH := "res://scenes/kingdom/reino_torres.tscn"
const TILE_SIZE := 32
const ORIGIN := Vector2(-1440.0, -896.0)
const COLUMNS := 90
const ROWS := 56
const ZONES := [0, 1, 8]
const BASE_ATLAS_TILE := Vector2i(2, 1)


func _run() -> void:
	var root := get_editor_interface().get_edited_scene_root() as Node2D
	if root == null or root.scene_file_path != SCENE_PATH:
		push_error("Abre scenes/kingdom/reino_torres.tscn antes de ejecutar este rediseño.")
		return

	var layers: Dictionary = {}
	for zone: int in ZONES:
		var layer := root.get_node_or_null("TerrainDual_Zone_%02d" % zone) as TileMapDual
		if layer == null:
			push_error("Falta la capa editable TerrainDual_Zone_%02d." % zone)
			return
		if layer.tile_set == null:
			push_error("La capa TerrainDual_Zone_%02d no tiene TileSet." % zone)
			return
		var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
		if atlas == null or not atlas.has_tile(BASE_ATLAS_TILE):
			push_error("La capa TerrainDual_Zone_%02d no contiene el tile base esperado." % zone)
			return
		layers[zone] = layer

	var counts: Dictionary = {0: 0, 1: 0, 8: 0}
	for zone: int in ZONES:
		var layer: TileMapDual = layers[zone]
		layer.clear()
		layer.position = ORIGIN
		layer.z_as_relative = false
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for y in range(ROWS):
		for x in range(COLUMNS):
			var cell := Vector2i(x, y)
			var point := ORIGIN + Vector2((float(x) + 0.5) * TILE_SIZE, (float(y) + 0.5) * TILE_SIZE)
			var zone := _zone_for_point(point, cell)
			var layer: TileMapDual = layers[zone]
			layer.set_cell(cell, 0, BASE_ATLAS_TILE)
			counts[zone] = int(counts[zone]) + 1

	for zone: int in ZONES:
		var layer: TileMapDual = layers[zone]
		layer.update_internals()
		layer.owner = root

	if int(counts[0]) + int(counts[1]) + int(counts[8]) != COLUMNS * ROWS:
		push_error("El rediseño no cubrió todas las celdas del terreno.")
		return

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		push_error("No se pudo empaquetar Torres: " + error_string(pack_error))
		return
	var save_error := ResourceSaver.save(packed, SCENE_PATH)
	if save_error != OK:
		push_error("No se pudo guardar el terreno de Torres: " + error_string(save_error))
		return

	get_editor_interface().get_resource_filesystem().scan()
	print("Torres rediseñado: %d x %d celdas (%d x %d px)." % [COLUMNS, ROWS, COLUMNS * TILE_SIZE, ROWS * TILE_SIZE])
	print("Pradera: %d | Calles y plaza: %d | Borde arbolado: %d" % [counts[0], counts[1], counts[8]])
	print("Guarda y vuelve a abrir la escena antes de probar el reino.")


func _zone_for_point(point: Vector2, cell: Vector2i) -> int:
	if _is_road(point):
		return 1
	if _is_forest_border(point, cell):
		return 8
	return 0


func _is_road(point: Vector2) -> bool:
	# Ejes principales: conectan las dos puertas y los barrios con la plaza.
	if _near_segment(point, Vector2(-1440.0, 0.0), Vector2(1440.0, 0.0), 46.0):
		return true
	if _near_segment(point, Vector2(0.0, -896.0), Vector2(0.0, 896.0), 46.0):
		return true

	# Plaza central amplia, con esquinas suavizadas y espacio para reunirse.
	if absf(point.x) <= 350.0 and absf(point.y) <= 245.0:
		return true
	if absf(point.x) <= 390.0 and absf(point.y) <= 190.0:
		return true

	# Calles de barrio: trazados sencillos, conectados y no excesivamente anchos.
	if _near_segment(point, Vector2(-1024.0, -760.0), Vector2(-1024.0, 760.0), 27.0):
		return true
	if _near_segment(point, Vector2(1024.0, -760.0), Vector2(1024.0, 760.0), 27.0):
		return true
	if _near_segment(point, Vector2(-1280.0, -480.0), Vector2(-760.0, -480.0), 25.0):
		return true
	if _near_segment(point, Vector2(760.0, -480.0), Vector2(1280.0, -480.0), 25.0):
		return true
	if _near_segment(point, Vector2(-1280.0, 190.0), Vector2(-760.0, 190.0), 25.0):
		return true
	if _near_segment(point, Vector2(760.0, 190.0), Vector2(1280.0, 190.0), 25.0):
		return true

	# Conexiones orgánicas entre plaza, talleres, laboratorio y zonas agrícolas.
	if _near_segment(point, Vector2(-330.0, -10.0), Vector2(-650.0, 70.0), 29.0):
		return true
	if _near_segment(point, Vector2(-650.0, 70.0), Vector2(-700.0, -420.0), 25.0):
		return true
	if _near_segment(point, Vector2(330.0, -10.0), Vector2(650.0, 65.0), 29.0):
		return true
	if _near_segment(point, Vector2(650.0, 65.0), Vector2(790.0, -420.0), 25.0):
		return true
	if _near_segment(point, Vector2(-900.0, 520.0), Vector2(900.0, 520.0), 27.0):
		return true
	if _near_segment(point, Vector2(-700.0, 190.0), Vector2(-700.0, 520.0), 25.0):
		return true
	if _near_segment(point, Vector2(650.0, 190.0), Vector2(650.0, 520.0), 25.0):
		return true
	return false


func _is_forest_border(point: Vector2, cell: Vector2i) -> bool:
	if cell.y <= 1 or cell.y >= ROWS - 2:
		return true
	# Se dejan libres los pasos oeste y este para las dos salidas del reino.
	if cell.x <= 1 and absf(point.y) > 112.0:
		return true
	if cell.x >= COLUMNS - 2 and absf(point.y) > 144.0:
		return true
	return false


func _near_segment(point: Vector2, start: Vector2, finish: Vector2, width: float) -> bool:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start) <= width
	var weight := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * weight) <= width
