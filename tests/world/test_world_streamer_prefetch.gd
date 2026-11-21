extends Node

const WorldStreamerScript = preload("res://scripts/world/world_streamer.gd")
const WorldTerrainScript = preload("res://scripts/world/world_terrain.gd")

var _terrain: WorldTerrain
var _streamer: WorldStreamer
var _player: CharacterBody2D


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_terrain = WorldTerrainScript.new()
	_terrain.chunk_size_tiles = 32
	_terrain.tile_size = 32

	_streamer = WorldStreamerScript.new()
	add_child(_streamer)
	_player = CharacterBody2D.new()
	add_child(_player)

	_streamer._terrain = _terrain
	_streamer._player = _player
	_streamer._player_chunk = Vector2i.ZERO
	_streamer._queue = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.RIGHT,
		Vector2i.LEFT,
	]

	# Simula un dash hacia la derecha dentro del mismo chunk. El prefetch
	# debe actualizarse sin esperar a cruzar la frontera.
	_player.global_position = Vector2(8.0 * 32.0 + 16.0, 16.0 * 32.0 + 16.0)
	_player.velocity = Vector2.RIGHT * 500.0
	_streamer._actualizar_direccion_jugador()
	_streamer._actualizar_prioridad_cola()

	if not _streamer._prefetch_activo or _streamer._prefetch_chunk != Vector2i.RIGHT:
		push_error("WorldStreamerPrefetch: no anticipó el chunk derecho dentro del chunk actual.")
		_terminar(1)
		return
	if _streamer._queue[0] != Vector2i.RIGHT:
		push_error("WorldStreamerPrefetch: la cola no priorizó el chunk derecho.")
		_terminar(1)
		return

	# Cambia la velocidad a un dash hacia abajo, todavía sin cambiar de chunk.
	_player.global_position = Vector2(16.0 * 32.0 + 16.0, 8.0 * 32.0 + 16.0)
	_player.velocity = Vector2.DOWN * 500.0
	_streamer._actualizar_direccion_jugador()
	_streamer._actualizar_prioridad_cola()

	if not _streamer._prefetch_activo or _streamer._prefetch_chunk != Vector2i.DOWN:
		push_error("WorldStreamerPrefetch: no actualizó el prefetch al cambiar la dirección.")
		_terminar(1)
		return
	if _streamer._queue[0] != Vector2i.DOWN:
		push_error("WorldStreamerPrefetch: la cola conservó una prioridad direccional obsoleta.")
		_terminar(1)
		return

	var sorts := int(_streamer.obtener_diagnostico().get("priority_queue_sorts", 0))
	if sorts < 2:
		push_error("WorldStreamerPrefetch: no reordenó la cola en ambos cambios de dirección.")
		_terminar(1)
		return

	print("WorldStreamerPrefetch: PASS sorts=%d" % sorts)
	_terminar(0)


func _terminar(codigo: int) -> void:
	if is_instance_valid(_streamer):
		_streamer.free()
	if is_instance_valid(_player):
		_player.free()
	if is_instance_valid(_terrain):
		_terrain.free()
	get_tree().quit(codigo)
