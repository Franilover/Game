@tool
extends Node


const WORLD_TERRAIN_SCRIPT := preload("res://scripts/world/world_terrain_visual.gd")
const WALL_POSITION := Vector2(-1664, -1088)
const TILE_SIZE := 32


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_inicializar_terreno_editor")


func _inicializar_terreno_editor() -> void:
	var scene_root := get_tree().edited_scene_root
	if not is_instance_valid(scene_root):
		return

	# Las capas base ya contienen las celdas guardadas de pradera, caminos
	# y tierra. En el editor debemos reconstruir su renderer igual que hace
	# ReinoTorres al iniciar el gameplay, sin regenerar ni modificar celdas.
	await get_tree().process_frame
	await get_tree().process_frame
	for zona in [0, 1, 8]:
		var nombre := "TerrainDual_Zone_%02d" % zona
		var capa := scene_root.get_node_or_null(nombre) as TileMapDual
		if not is_instance_valid(capa):
			push_warning("Torres editor: no se encontró %s." % nombre)
			continue
		var celdas: Array[Vector2i] = capa.get_used_cells()
		if celdas.is_empty():
			push_warning("Torres editor: %s no contiene celdas guardadas." % nombre)
			continue
		capa.reconstruir_renderer_dual()
		capa._update_cells(celdas, false)

	# La muralla se genera como un nodo editable aparte.
	await get_tree().process_frame
	await _generar_muralla_editable()


func _generar_muralla_editable() -> void:
	var scene_root := get_tree().edited_scene_root
	if not is_instance_valid(scene_root):
		return
	if scene_root.get_node_or_null("TerrenoMurallaMontana") != null:
		return

	var terreno: WorldTerrainVisual = WORLD_TERRAIN_SCRIPT.new() as WorldTerrainVisual
	terreno.name = "TerrenoMurallaMontana"
	terreno.position = WALL_POSITION
	scene_root.add_child(terreno)
	terreno.owner = scene_root

	# Reutilizar exactamente el compositor y el atlas que usa el gameplay.
	terreno.configurar(TILE_SIZE)
	await get_tree().process_frame
	await get_tree().process_frame
	terreno.finalizar_preparacion_renderer()

	# Anillo de una celda alrededor del reino; la abertura oriental
	# conserva el acceso de la puerta.
	for x in range(104):
		terreno.set_zone(Vector2i(x, 0), 2, 2, "Montaña")
		terreno.set_zone(Vector2i(x, 67), 2, 2, "Montaña")
	for y in range(1, 67):
		terreno.set_zone(Vector2i(0, y), 2, 2, "Montaña")
	for y in range(1, 30):
		terreno.set_zone(Vector2i(103, y), 2, 2, "Montaña")
	for y in range(38, 67):
		terreno.set_zone(Vector2i(103, y), 2, 2, "Montaña")

	terreno.flush()
	# Hacer que los nodos generados pertenezcan a la escena y puedan
	# guardarse, seleccionarse y editarse desde el árbol de Godot.
	# Sólo guardar el WorldTerrainVisual y sus TileMapDual de origen.
	# Display/DisplayLayer son cachés regeneradas por TileMapDual._ready();
	# serializarlas provocaría duplicados al volver a abrir la escena.
	for capa in terreno.get_children():
		capa.owner = scene_root
	EditorInterface.mark_scene_as_unsaved()
	print("ReinoTorres: muralla editable generada. Guarda reino_torres.tscn para persistirla.")
