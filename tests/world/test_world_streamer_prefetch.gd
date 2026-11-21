extends Node

const WorldStreamerScript = preload("res://scripts/world/world_streamer.gd")
const WorldTerrainScript = preload("res://scripts/world/world_terrain.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var terrain := WorldTerrainScript.new()
	terrain.chunk_size_tiles = 32
	terrain.tile_size = 32

	var streamer := WorldStreamerScript.new()
	add_child(streamer)
	var player := CharacterBody2D.new()
	add_child(player)

	streamer._terrain = terrain
	streamer._player = player
	streamer._player_chunk = Vector2i.ZERO
	streamer._queue = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.RIGHT,
		Vector2i.LEFT,
	]

	# Simula un dash hacia la derecha dentro del mismo chunk. El prefetch
	# debe actualizarse sin esperar a cruzar la frontera.
	player.global_position = Vector2(8.0 * 32.0 + 16.0, 16.0 * 32.0 + 16.0)
	player.velocity = Vector2.RIGHT * 500.0
	streamer._actualizar_direccion_jugador()
	streamer._actualizar_prioridad_cola()

	if not streamer._prefetch_activo or streamer._prefetch_chunk != Vector2i.RIGHT:
		push_error("WorldStreamerPrefetch: no anticipó el chunk derecho dentro del chunk actual.")
		get_tree().quit(1)
		return
	if streamer._queue[0] != Vector2i.RIGHT:
		push_error("WorldStreamerPrefetch: la cola no priorizó el chunk derecho.")
		quit(1)
		return

	# Cambia la velocidad a un dash hacia abajo, todavía sin cambiar de chunk.
	player.global_position = Vector2(16.0 * 32.0 + 16.0, 8.0 * 32.0 + 16.0)
	player.velocity = Vector2.DOWN * 500.0
	streamer._actualizar_direccion_jugador()
	streamer._actualizar_prioridad_cola()

	if not streamer._prefetch_activo or streamer._prefetch_chunk != Vector2i.DOWN:
		push_error("WorldStreamerPrefetch: no actualizó el prefetch al cambiar la dirección.")
		quit(1)
		return
	if streamer._queue[0] != Vector2i.DOWN:
		push_error("WorldStreamerPrefetch: la cola conservó una prioridad direccional obsoleta.")
		quit(1)
		return

	var sorts := int(streamer.obtener_diagnostico().get("priority_queue_sorts", 0))
	if sorts < 2:
		push_error("WorldStreamerPrefetch: no reordenó la cola en ambos cambios de dirección.")
		quit(1)
		return

	print("WorldStreamerPrefetch: PASS sorts=%d" % sorts)
	get_tree().quit(0)
