extends Node

const CONTRACT_DIR := "user://contracts/natural_entity_restart"
const MANIFEST := CONTRACT_DIR + "/save_id.txt"
const WORLD_SCENE: PackedScene = preload("res://scenes/world/mundo_abierto.tscn")
const CHUNK := Vector2i.ZERO
const SEED := 7348293


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and args[0] == "write":
		await _worker_write()
	elif args.size() == 1 and args[0] == "read":
		await _worker_read()
	else:
		await _run_parent()


func _run_parent() -> void:
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTRACT_DIR))
	if err != OK and err != ERR_ALREADY_EXISTS:
		_fail("No se pudo crear el directorio del contrato.")
		return
	var output: Array = []
	var code := _run_child("write", output)
	if code != 0 or not _contains(output, "NaturalEntityRestart: WRITE PASS"):
		_fail("Falló el escritor: %s" % "\n".join(output))
		return
	output.clear()
	code = _run_child("read", output)
	if code != 0 or not _contains(output, "NaturalEntityRestart: READ PASS"):
		_fail("Falló el lector: %s" % "\n".join(output))
		return
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file != null:
		var save_id := file.get_as_text().strip_edges()
		file.close()
		if not save_id.is_empty():
			var repository: Variant = GameState.get("save_repository")
			repository.call("eliminar_partida", save_id)
	if FileAccess.file_exists(MANIFEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST))
	print("NaturalEntityRestart: PASS (spawn natural + GameState JSON + proceso independiente)")
	get_tree().quit(0)


func _run_child(mode: String, output: Array) -> int:
	return OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/persistence/test_natural_entity_process_restart.tscn",
		"--", mode
	], output, true)


func _esperar_catalogo() -> bool:
	var frames := 0
	while not WorldData.esta_cargado() and frames < 300:
		await get_tree().process_frame
		frames += 1
	return WorldData.esta_cargado()


func _crear_mundo() -> Dictionary:
	var world := WORLD_SCENE.instantiate() as Node2D
	if world == null:
		return {}
	get_tree().root.add_child(world)
	var generator := world.get_node_or_null("WorldGenerator") as WorldGenerator
	if generator == null:
		world.queue_free()
		return {}
	generator.usar_semilla_fija = true
	generator.map_seed = SEED
	generator.load_radius_chunks = 0
	generator.generation_cells_per_frame = 512
	var entities := Node2D.new()
	entities.name = "TestEntities"
	world.add_child(entities)
	var player := Node2D.new()
	player.name = "TestPlayer"
	player.global_position = Vector2(512, 512)
	entities.add_child(player)
	generator.configurar_dependencias(WorldData, GameState)
	generator.configurar_entidades(entities, player)
	var frames := 0
	while not generator.is_world_ready() and frames < 300:
		await get_tree().process_frame
		frames += 1
	if not generator.is_world_ready():
		world.queue_free()
		return {}
	generator.registrar_jugador(player)
	frames = 0
	while not generator.terrain.chunk_cargado(CHUNK) and frames < 900:
		await get_tree().process_frame
		frames += 1
	if not generator.terrain.chunk_cargado(CHUNK):
		world.queue_free()
		return {}
	return {"world": world, "generator": generator, "manager": generator.entity_manager, "spawner": generator.entity_spawner}


func _generar_criatura_natural(parts: Dictionary, snapshot: Dictionary = {}) -> Dictionary:
	var manager: Node = parts.manager
	var spawner: Node = parts.spawner
	spawner.preparar_datos_criaturas_chunk(CHUNK)
	var generated: Array = manager.obtener_datos_chunk(CHUNK, "criaturas")
	var selected: Dictionary = {}
	for item in generated:
		if not item is Dictionary:
			continue
		var data := item as Dictionary
		if str(data.get("categoria_entidad", "criatura")).to_lower() == "garumi":
			continue
		if str(data.get("criatura_id", "")).strip_edges().is_empty():
			continue
		selected = data.duplicate(true)
		break
	if selected.is_empty():
		return {}
	var key := str(selected.get("runtime_instance_key", "")).strip_edges()
	if key.is_empty():
		return {}
	if not snapshot.is_empty():
		manager.restaurar_estado_persistente_mundo(snapshot)
	if not spawner.materializar_criaturas_datos_chunk(CHUNK):
		return {}
	for entity in manager.obtener_por_chunk(CHUNK):
		if entity is Creature and str((entity as Creature).get_meta("runtime_instance_key", "")) == key:
			return {"creature": entity, "key": key, "id": str(selected.get("criatura_id", ""))}
	return {}


func _worker_write() -> void:
	if not await _esperar_catalogo():
		_fail("No hay catálogo local para generar una criatura natural.")
		return
	var parts := await _crear_mundo()
	if parts.is_empty():
		_fail("No se pudo iniciar el mundo procedural real.")
		return
	var natural := _generar_criatura_natural(parts)
	if natural.is_empty():
		_fail("La semilla fija no generó una criatura natural en el chunk.")
		return
	var creature := natural.creature as Creature
	var changed_position := creature.global_position + Vector2(41.25, -23.5)
	var changed_velocity := Vector2(2.75, -1.25)
	var restart_metadata := {"position": {"x": changed_position.x, "y": changed_position.y}, "velocity": {"x": changed_velocity.x, "y": changed_velocity.y}, "runtime_key": str(natural.key), "creature_id": str(natural.id)}
	var flags_variant: Variant = GameState.get("world_state").get("flags")
	var flags: Dictionary = flags_variant as Dictionary
	flags["natural_entity_restart_probe"] = restart_metadata
	GameState.get("world_state").set("flags", flags)
	creature.global_position = changed_position
	creature.velocity = changed_velocity
	if not GameState.capturar_estado_entidades_mundo_local("mundo_abierto", parts.manager):
		_fail("GameState no capturó el estado del manager real.")
		return
	var save_id := str(GameState.crear_partida("Natural creature restart", str(SEED), {"nombre": "Persistence probe", "especie": "Humano"}))
	if save_id.is_empty():
		_fail("No se pudo crear el save.")
		return
	var repository: Variant = GameState.get("save_repository")
	var data := repository.call("leer_partida", save_id) as Dictionary
	data["estado"] = GameState.call("_serializar_estado")
	if not repository.call("escribir_partida", save_id, data):
		_fail("No se pudo persistir el snapshot de criatura.")
		return
	var manifest := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if manifest == null:
		_fail("No se pudo escribir el manifiesto.")
		return
	manifest.store_string(save_id)
	manifest.close()
	print("NaturalEntityRestart: WRITE PASS id=%s creature=%s key=%s" % [save_id, natural.id, natural.key])
	get_tree().quit(0)


func _worker_read() -> void:
	var manifest := FileAccess.open(MANIFEST, FileAccess.READ)
	if manifest == null:
		_fail("El proceso lector no encontró el manifiesto.")
		return
	var save_id := manifest.get_as_text().strip_edges()
	manifest.close()
	var repository: Variant = GameState.get("save_repository")
	var data := repository.call("leer_partida", save_id) as Dictionary
	if data.is_empty() or not GameState.call("_datos_partida_cargables", save_id, data):
		_fail("El proceso lector no pudo validar el save.")
		return
	var state: Dictionary = data.get("estado", {}) as Dictionary
	GameState.call("_aplicar_estado_memoria", state)
	if not await _esperar_catalogo():
		_fail("El catálogo local no se cargó en el segundo proceso.")
		return
	var parts := await _crear_mundo()
	if parts.is_empty():
		_fail("No se pudo reconstruir el mismo mundo procedural.")
		return
	var restored := GameState.obtener_estado_entidades_mundo_local("mundo_abierto")
	if restored.is_empty():
		_fail("El snapshot de entidades no sobrevivió al JSON.")
		return
	var expected: Dictionary = (state.get("flags", {}) as Dictionary).get("natural_entity_restart_probe", {}) as Dictionary
	var expected_position: Dictionary = expected.get("position", {}) as Dictionary
	var expected_velocity: Dictionary = expected.get("velocity", {}) as Dictionary
	var expected_key := str(expected.get("runtime_key", ""))
	var natural := _generar_criatura_natural(parts, restored)
	if natural.is_empty():
		_fail("El spawn natural no se rematerializó tras el reinicio.")
		return
	var creature := natural.creature as Creature
	var errors: Array[String] = []
	var expected_position_vector := Vector2(float(expected_position.get("x", 0.0)), float(expected_position.get("y", 0.0)))
	var expected_velocity_vector := Vector2(float(expected_velocity.get("x", 0.0)), float(expected_velocity.get("y", 0.0)))
	if expected_key.is_empty() or str(natural.key) != expected_key:
		errors.append("El generador no recreó la misma clave de instancia natural.")
	if creature.global_position != expected_position_vector:
		errors.append("La posición runtime no sobrevivió al reinicio: %s" % str(creature.global_position))
	if creature.velocity != expected_velocity_vector:
		errors.append("La velocidad runtime no sobrevivió al reinicio: %s" % str(creature.velocity))
	var matches := 0
	for entity in (parts.manager as Node).obtener_por_chunk(CHUNK):
		if entity is Creature and str((entity as Creature).get_meta("runtime_instance_key", "")) == str(natural.key):
			matches += 1
	if matches != 1:
		errors.append("Se esperaba exactamente una instancia natural; se encontraron %d." % matches)
	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	print("NaturalEntityRestart: READ PASS creature=%s key=%s pid=%d" % [natural.id, natural.key, OS.get_process_id()])
	get_tree().quit(0)


func _contains(output: Array, needle: String) -> bool:
	return "\n".join(output).contains(needle)


func _fail(message: String) -> void:
	push_error("NaturalEntityRestart: FAIL: " + message)
	get_tree().quit(1)
