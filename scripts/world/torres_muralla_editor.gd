@tool
extends Node


const WORLD_TERRAIN_SCRIPT := preload("res://scripts/world/world_terrain_visual.gd")
const WALL_POSITION := Vector2(-1664, -1088)
const TILE_SIZE := 32


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_generar_muralla_editable")


func _generar_muralla_editable() -> void:
	var scene_root := get_tree().edited_scene_root
	if not is_instance_valid(scene_root):
		return
	if scene_root.get_node_or_null("TerrenoMurallaMontana") != null:
		return

	var terreno := WORLD_TERRAIN_SCRIPT.new()
	terreno.name = "TerrenoMurallaMontana"
	terreno.position = WALL_POSITION
	scene_root.add_child(terreno)

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
	_asignar_owner_recursivo(terreno, scene_root)
	print("ReinoTorres: muralla editable generada en el editor.")


func _asignar_owner_recursivo(nodo: Node, scene_root: Node) -> void:
	for hijo in nodo.get_children():
		hijo.owner = scene_root
		_asignar_owner_recursivo(hijo, scene_root)
