@tool
extends EditorScript
## Rediseña el terreno de Torres con una retícula ampliada y barrios conectados.
## Ejecutar desde el editor con scenes/kingdom/reino_torres.tscn abierto.

const SCENE_PATH := "res://scenes/kingdom/reino_torres.tscn"
const LAYOUT := preload("res://scripts/world/torres_tilemap_layout.gd")


func _run() -> void:
	var root := get_editor_interface().get_edited_scene_root() as Node2D
	if root == null or root.scene_file_path != SCENE_PATH:
		push_error("Abre scenes/kingdom/reino_torres.tscn antes de ejecutar este rediseño.")
		return

	var layers: Dictionary = {}
	for zone: int in LAYOUT.ZONES:
		var layer := root.get_node_or_null("TerrainDual_Zone_%02d" % zone) as TileMapDual
		if layer == null or layer.tile_set == null:
			push_error("Falta una capa TileMapDual válida para la zona %d." % zone)
			return
		var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
		if atlas == null or not atlas.has_tile(LAYOUT.BASE_ATLAS_TILE):
			push_error("La zona %d no contiene el tile base esperado." % zone)
			return
		layers[zone] = layer

	var counts: Dictionary = {0: 0, 1: 0, 8: 0}
	for zone: int in LAYOUT.ZONES:
		var layer: TileMapDual = layers[zone]
		layer.clear()
		layer.position = LAYOUT.ORIGIN
		layer.z_as_relative = false
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for y in range(LAYOUT.ROWS):
		for x in range(LAYOUT.COLUMNS):
			var cell := Vector2i(x, y)
			var point := LAYOUT.ORIGIN + Vector2((float(x) + 0.5) * LAYOUT.TILE_SIZE, (float(y) + 0.5) * LAYOUT.TILE_SIZE)
			var zone: int = LAYOUT.zone_for_point(point, cell)
			var layer: TileMapDual = layers[zone]
			layer.set_cell(cell, 0, LAYOUT.BASE_ATLAS_TILE)
			counts[zone] = int(counts[zone]) + 1

	for zone: int in LAYOUT.ZONES:
		var layer: TileMapDual = layers[zone]
		layer.update_internals()
		layer.owner = root

	if int(counts[0]) + int(counts[1]) + int(counts[8]) != LAYOUT.COLUMNS * LAYOUT.ROWS:
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
	print("Torres rediseñado: %d x %d celdas (%d x %d px)." % [LAYOUT.COLUMNS, LAYOUT.ROWS, LAYOUT.COLUMNS * LAYOUT.TILE_SIZE, LAYOUT.ROWS * LAYOUT.TILE_SIZE])
	print("Pradera: %d | Calles y plaza: %d | Borde arbolado: %d" % [counts[0], counts[1], counts[8]])
	print("Guarda y vuelve a abrir la escena antes de probar el reino.")
