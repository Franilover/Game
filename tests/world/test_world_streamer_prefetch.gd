extends Node

const WorldStreamerScript = preload("res://scripts/world/world_streamer.gd")
const WorldTerrainScript = preload("res://scripts/world/world_terrain.gd")
const WorldTerrainVisualScript = preload("res://scripts/world/world_terrain_visual.gd")
const WorldEntityManagerScript = preload("res://scripts/world/world_entity_manager.gd")
const WorldEntitySpawnerScript = preload("res://scripts/world/world_entity_spawner.gd")

var _terrain: WorldTerrain
var _visual: WorldTerrainVisual
var _streamer: WorldStreamer
var _player: CharacterBody2D


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_terrain = WorldTerrainScript.new()
	_terrain.chunk_size_tiles = 32
	_terrain.tile_size = 32
	_visual = WorldTerrainVisualScript.new()
	add_child(_visual)
	_terrain.visual = _visual

	# Un unload no puede mezclarse con pintura mientras mantiene bloqueado
	# el lote visual, pero sí debe permitir generación cuando ya está en FLUSH.
	_visual._clear_task = {"coord": Vector2i.ZERO, "stage": 0}
	_terrain._unload_task = {"coord": Vector2i.ZERO}
	if _terrain.puede_iniciar_generacion_durante_descarga():
		push_error("WorldStreamerPrefetch: permitió generación durante clear/batch.")
		_terminar(1)
		return
	_visual._clear_task["stage"] = 1
	if not _terrain.puede_iniciar_generacion_durante_descarga():
		push_error("WorldStreamerPrefetch: bloqueó generación durante flush del unload.")
		_terminar(1)
		return
	_visual._clear_task.clear()
	_terrain._unload_task.clear()

	_streamer = WorldStreamerScript.new()
	add_child(_streamer)
	_player = CharacterBody2D.new()
	add_child(_player)

	_streamer._terrain = _terrain
	_streamer._player = _player
	_streamer._player_chunk = Vector2i.ZERO

	# La activación de entidades se prepara como cola y pone primero el chunk
	# actual; no debe materializar todo el anillo en el frame de transición.
	_streamer._ordenar_cola_activacion_entidades(
		[Vector2i.RIGHT, Vector2i.ZERO, Vector2i.DOWN],
		Vector2i.ZERO
	)
	if _streamer._entity_activation_queue.size() != 3:
		push_error("WorldStreamerPrefetch: perdió chunks en la cola de activación.")
		_terminar(1)
		return
	if _streamer._entity_activation_queue[0] != Vector2i.ZERO:
		push_error("WorldStreamerPrefetch: no priorizó el chunk actual para activar entidades.")
		_terminar(1)
		return

	# Una materialización puede ceder el frame. Una segunda llamada diferida
	# no debe consumir otro chunk mientras la primera activación siga activa.
	_streamer._entity_activation_active = true
	_streamer.call("_procesar_siguiente_chunk_entidades")
	if _streamer._entity_activation_queue.size() != 3:
		push_error("WorldStreamerPrefetch: inició otra activación durante una tarea activa.")
		_terminar(1)
		return
	_streamer._entity_activation_active = false

	# Con el manager conectado, sólo se encolan chunks cuyo estado activo no
	# coincide con su LOD; los chunks ya estabilizados no consumen turnos.
	var manager := WorldEntityManagerScript.new()
	var spawner := WorldEntitySpawnerScript.new()
	add_child(manager)
	add_child(spawner)
	spawner._entity_manager = manager
	_streamer._entity_spawner = spawner
	_streamer._chunk_lod = {
		Vector2i.ZERO: WorldStreamerScript.LOD_FULL,
		Vector2i.RIGHT: WorldStreamerScript.LOD_FULL,
		Vector2i.DOWN: WorldStreamerScript.LOD_TERRAIN,
	}
	manager.activar_props_chunk(Vector2i.ZERO)
	manager.activar_criaturas_chunk(Vector2i.ZERO)
	manager.activar_props_chunk(Vector2i.RIGHT)
	_streamer._ordenar_cola_activacion_entidades(
		[Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN],
		Vector2i.ZERO
	)
	if _streamer._entity_activation_queue.size() != 2:
		push_error("WorldStreamerPrefetch: no filtró chunks cuyo LOD ya estaba satisfecho.")
		_terminar(1)
		return
	if Vector2i.ZERO in _streamer._entity_activation_queue:
		push_error("WorldStreamerPrefetch: volvió a encolar un chunk ya activo.")
		_terminar(1)
		return
	_streamer._entity_spawner = null

	# WorldTerrain sólo admite un clear visual activo. El streamer debe
	# conservar los demás chunks lejanos sin duplicarlos y cancelar los que
	# vuelven al radio antes de que empiece su descarga.
	_terrain._loaded_chunks = {
		Vector2i(-3, 0): {},
		Vector2i(3, 0): {},
		Vector2i.ZERO: {},
	}
	_streamer._unload_radius = 2
	_streamer._descargar_lejanos(Vector2i.ZERO)
	if _streamer._pending_unload_chunks.size() != 2:
		push_error("WorldStreamerPrefetch: no encoló todos los chunks lejanos.")
		_terminar(1)
		return
	_streamer._descargar_lejanos(Vector2i.ZERO)
	if _streamer._pending_unload_chunks.size() != 2:
		push_error("WorldStreamerPrefetch: duplicó chunks en la cola de descarga.")
		_terminar(1)
		return
	_streamer._descargar_lejanos(Vector2i(3, 0))
	if _streamer._pending_unload_chunks.size() != 1 or _streamer._pending_unload_chunks[0] != Vector2i(-3, 0):
		push_error("WorldStreamerPrefetch: no canceló una descarga que volvió al radio.")
		_terminar(1)
		return
	_terrain._loaded_chunks[Vector2i(-4, 0)] = {}
	_streamer._descargar_lejanos(Vector2i(3, 0))
	if _streamer._pending_unload_chunks.size() != 2:
		push_error("WorldStreamerPrefetch: no conservó la segunda descarga pendiente.")
		_terminar(1)
		return
	# Sin renderer, descargar_chunk completa el clear inmediatamente. Una
	# llamada al servicio debe iniciar/terminar sólo un chunk de la cola.
	_terrain.visual = null
	_streamer._procesar_descarga_si_hay_presupuesto()
	_terrain.visual = _visual
	if _streamer._pending_unload_chunks.size() != 1:
		push_error("WorldStreamerPrefetch: procesó más de una descarga en un mismo turno.")
		_terminar(1)
		return

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

	# La generación puede cederse antes de pintar, pero no durante una
	# pintura parcial ni durante el flush final.
	_terrain._generation_task = {"coord": Vector2i(3, 0), "stage": 0}
	if not _terrain.puede_pausar_generacion_actual():
		push_error("WorldStreamerPrefetch: DATA debería permitir preempción segura.")
		_terminar(1)
		return
	if not _terrain.pausar_generacion_actual():
		push_error("WorldStreamerPrefetch: no pudo pausar la etapa DATA.")
		_terminar(1)
		return
	if _terrain.tiene_generacion_activa() or not _terrain.tiene_generacion_pausada():
		push_error("WorldStreamerPrefetch: la tarea DATA no quedó preservada.")
		_terminar(1)
		return
	if _terrain.puede_pausar_generacion_actual():
		push_error("WorldStreamerPrefetch: permitió una segunda tarea pausada.")
		_terminar(1)
		return

	_terrain._paused_generation_task.clear()
	_terrain._generation_task = {
		"coord": Vector2i(4, 0),
		"stage": 1,
		"cursor_pintado": 0,
	}
	if not _terrain.puede_pausar_generacion_actual():
		push_error("WorldStreamerPrefetch: PINTADO sin celdas debería ser pausible.")
		_terminar(1)
		return
	_terrain._generation_task["cursor_pintado"] = 1
	if _terrain.puede_pausar_generacion_actual():
		push_error("WorldStreamerPrefetch: permitió interrumpir pintura parcial.")
		_terminar(1)
		return
	_terrain._generation_task["stage"] = 2
	if _terrain.puede_pausar_generacion_actual():
		push_error("WorldStreamerPrefetch: permitió interrumpir FLUSH.")
		_terminar(1)
		return
	_terrain._generation_task.clear()

	print("WorldStreamerPrefetch: PASS sorts=%d" % sorts)
	_terminar(0)


func _terminar(codigo: int) -> void:
	if is_instance_valid(_streamer):
		_streamer.free()
	if is_instance_valid(_player):
		_player.free()
	if is_instance_valid(_terrain):
		_terrain.free()
	if is_instance_valid(_visual):
		_visual.free()
	get_tree().quit(codigo)
