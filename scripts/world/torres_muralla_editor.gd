@tool
extends Node


const WORLD_TERRAIN_SCRIPT := preload("res://scripts/world/world_terrain_visual.gd")
const TORRES_TILEMAP_LAYOUT := preload("res://scripts/world/torres_tilemap_layout.gd")
const WALL_POSITION := Vector2(-1664, -1088)
const TILE_SIZE := 32
const EXPECTED_TERRAIN_CELLS := TORRES_TILEMAP_LAYOUT.COLUMNS * TORRES_TILEMAP_LAYOUT.ROWS
const MIN_VALID_TERRAIN_CELLS := 7000
const EXPECTED_WALL_CELLS := 260


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_inicializar_terreno_editor")


func _inicializar_terreno_editor() -> void:
	var scene_root := get_tree().edited_scene_root
	if not is_instance_valid(scene_root):
		return

	# Esperar a que TileMapDual cree sus renderers de editor.
	await get_tree().process_frame
	await get_tree().process_frame

	_generar_terreno_reino_si_incompleto(scene_root)

	# Dejar que Godot procese las celdas antes de preparar la muralla.
	await get_tree().process_frame
	await _generar_muralla_editable(scene_root)


func _generar_terreno_reino_si_incompleto(scene_root: Node) -> void:
	var capas_por_zona: Dictionary = {}
	var posiciones_guardadas: Dictionary = {}

	for zona: int in TORRES_TILEMAP_LAYOUT.ZONES:
		var nombre := "TerrainDual_Zone_%02d" % zona
		var capa := scene_root.get_node_or_null(nombre) as TileMapDual
		if not is_instance_valid(capa):
			push_error("Torres editor: falta la capa editable %s." % nombre)
			return

		capas_por_zona[zona] = capa
		for celda: Vector2i in capa.get_used_cells():
			posiciones_guardadas[celda] = true

	# No volver a generar un mapa completo: así los cambios manuales del
	# usuario se conservan al volver a abrir la escena.
	if posiciones_guardadas.size() >= MIN_VALID_TERRAIN_CELLS:
		print(
			"Torres editor: terreno guardado completo (%d/%d posiciones)."
			% [posiciones_guardadas.size(), EXPECTED_TERRAIN_CELLS]
		)
		return

	print(
		"Torres editor: terreno incompleto (%d/%d posiciones); reconstruyendo distribución en la escena."
		% [posiciones_guardadas.size(), EXPECTED_TERRAIN_CELLS]
	)

	# La misma distribución que utilizaba el juego antes de retirar la
	# reconstrucción runtime. La escena queda como única fuente de verdad.
	for zona: int in TORRES_TILEMAP_LAYOUT.ZONES:
		var capa: TileMapDual = capas_por_zona[zona]
		capa.set_block_signals(true)
		capa.clear()
		capa.position = TORRES_TILEMAP_LAYOUT.ORIGIN
		capa.godot_4_3_compatibility = false

	for y in range(TORRES_TILEMAP_LAYOUT.ROWS):
		for x in range(TORRES_TILEMAP_LAYOUT.COLUMNS):
			var celda := Vector2i(x, y)
			var punto := TORRES_TILEMAP_LAYOUT.ORIGIN + Vector2(
				(float(x) + 0.5) * TORRES_TILEMAP_LAYOUT.TILE_SIZE,
				(float(y) + 0.5) * TORRES_TILEMAP_LAYOUT.TILE_SIZE
			)
			var zona: int = TORRES_TILEMAP_LAYOUT.zone_for_point(punto, celda)
			var capa: TileMapDual = capas_por_zona[zona]
			capa.set_cell(celda, 0, TORRES_TILEMAP_LAYOUT.BASE_ATLAS_TILE)

	for zona: int in TORRES_TILEMAP_LAYOUT.ZONES:
		var capa: TileMapDual = capas_por_zona[zona]
		capa.set_block_signals(false)
		capa.update_internals()
		# Reconstruir una sola vez después de completar las celdas guardadas.
		capa.reconstruir_renderer_dual()

	EditorInterface.mark_scene_as_unsaved()
	print(
		"Torres editor: terreno completo generado en la escena (%d x %d = %d celdas). Guarda reino_torres.tscn."
		% [
			TORRES_TILEMAP_LAYOUT.COLUMNS,
			TORRES_TILEMAP_LAYOUT.ROWS,
			EXPECTED_TERRAIN_CELLS
		]
	)


func _generar_muralla_editable(scene_root: Node) -> void:
	var existente := scene_root.get_node_or_null("TerrenoMurallaMontana")
	if is_instance_valid(existente):
		var capa_existente := existente.get_node_or_null("TerrainDual_Zone_02") as TileMapDual
		if is_instance_valid(capa_existente) and capa_existente.get_used_cells().size() >= EXPECTED_WALL_CELLS:
			return
		# Reparar nodos creados en intentos anteriores que quedaron vacíos.
		scene_root.remove_child(existente)
		existente.free()

	var terreno: WorldTerrainVisual = WORLD_TERRAIN_SCRIPT.new() as WorldTerrainVisual
	terreno.name = "TerrenoMurallaMontana"
	terreno.position = WALL_POSITION
	scene_root.add_child(terreno)
	terreno.owner = scene_root

	# Reutilizar exactamente el compositor y el atlas de Montaña del juego.
	terreno.configurar(TILE_SIZE)
	await get_tree().process_frame
	await get_tree().process_frame
	terreno.finalizar_preparacion_renderer()

	# Anillo de una celda alrededor del reino; la abertura oriental conserva
	# el acceso de la puerta.
	for x in range(TORRES_TILEMAP_LAYOUT.COLUMNS):
		terreno.set_zone(Vector2i(x, 0), 2, 2, "Montaña")
		terreno.set_zone(Vector2i(x, TORRES_TILEMAP_LAYOUT.ROWS - 1), 2, 2, "Montaña")
	for y in range(1, TORRES_TILEMAP_LAYOUT.ROWS - 1):
		terreno.set_zone(Vector2i(0, y), 2, 2, "Montaña")
	for y in range(1, 30):
		terreno.set_zone(Vector2i(TORRES_TILEMAP_LAYOUT.COLUMNS - 1, y), 2, 2, "Montaña")
	for y in range(38, TORRES_TILEMAP_LAYOUT.ROWS - 1):
		terreno.set_zone(Vector2i(TORRES_TILEMAP_LAYOUT.COLUMNS - 1, y), 2, 2, "Montaña")

	terreno.flush()

	# Guardar los TileMapDual de origen como parte de la escena. Display y
	# DisplayLayer son cachés del addon y se regeneran al abrirla.
	for capa in terreno.get_children():
		if capa is TileMapDual:
			capa.owner = scene_root

	EditorInterface.mark_scene_as_unsaved()
	print("Torres editor: muralla editable generada (%d celdas). Guarda reino_torres.tscn." % EXPECTED_WALL_CELLS)
