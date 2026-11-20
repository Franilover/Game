extends Node

const WORLD_SCENE: PackedScene = preload("res://scenes/world/mundo_abierto.tscn")
const CHUNK := Vector2i.ZERO
const RUNTIME_KEY := "persistence_probe"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var frames := 0
	while not WorldData.esta_cargado() and frames < 300:
		await get_tree().process_frame
		frames += 1
	if not WorldData.esta_cargado():
		_fail(["WorldData no cargó el catálogo local; el contrato necesita datos reales para crear una criatura."])
		return

	var catalogo: Array[Dictionary] = WorldData.obtener_criaturas()
	if catalogo.is_empty():
		_fail(["El catálogo local no contiene criaturas para probar el spawner real."])
		return
	var criatura_id := str(catalogo[0].get("id", catalogo[0].get("criatura_id", ""))).strip_edges()
	if criatura_id.is_empty():
		_fail(["La primera criatura del catálogo no tiene ID utilizable."])
		return

	var world_instance := WORLD_SCENE.instantiate() as Node2D
	if world_instance == null:
		_fail(["No se pudo instanciar scenes/world/mundo_abierto.tscn."])
		return
	get_tree().root.add_child(world_instance)
	var generator := world_instance.get_node_or_null("WorldGenerator") as WorldGenerator
	if generator == null:
		_fail(["MundoAbierto no contiene un WorldGenerator real."])
		return

	generator.usar_semilla_fija = true
	generator.map_seed = 7348293
	generator.load_radius_chunks = 0
	generator.generation_cells_per_frame = 512
	var entities_root := Node2D.new()
	entities_root.name = "TestEntities"
	world_instance.add_child(entities_root)
	var player := Node2D.new()
	player.name = "TestPlayer"
	player.global_position = Vector2(512.0, 512.0)
	entities_root.add_child(player)

	generator.configurar_entidades(entities_root, player)
	generator.configurar_dependencias(WorldData, GameState)
	frames = 0
	while not generator.is_world_ready() and frames < 300:
		await get_tree().process_frame
		frames += 1
	if not generator.is_world_ready():
		_fail(["WorldGenerator no alcanzó el estado listo con el catálogo local."])
		return

	generator.registrar_jugador(player)
	frames = 0
	while not generator.terrain.chunk_cargado(CHUNK) and frames < 900:
		await get_tree().process_frame
		frames += 1
	if not generator.terrain.chunk_cargado(CHUNK):
		_fail(["WorldStreamer no terminó de materializar el chunk inicial. Diagnóstico: %s" % str(generator.streamer.obtener_diagnostico())])
		return

	var manager := generator.entity_manager
	var estado_guardado := {
		"criaturas": {
			"0:0:" + RUNTIME_KEY: {
				"criatura_id": criatura_id,
				"runtime_instance_key": RUNTIME_KEY,
				"position": Vector2(384.5, 448.25),
				"velocity": Vector2(2.25, -1.5),
				"health": 7,
				"is_alive": true,
				"necesidades_runtime": {"hambre": 0.73}
			}
		},
		"props": {}
	}
	manager.restaurar_estado_persistente_mundo(estado_guardado)
	var data := {
		"criatura_id": criatura_id,
		"runtime_instance_key": RUNTIME_KEY,
		"position": Vector2(320.0, 320.0),
		"habitat_clave": "general"
	}
	manager.guardar_dato_chunk(CHUNK, "criaturas", data)
	if not generator.entity_spawner.materializar_criaturas_datos_chunk(CHUNK):
		_fail(["El spawner real no materializó la criatura de prueba en el chunk cargado."])
		return

	var entidades := manager.obtener_por_chunk(CHUNK)
	var encontrada: Creature = null
	for entidad_variant in entidades:
		if entidad_variant is Creature and str((entidad_variant as Creature).get_meta("runtime_instance_key", "")) == RUNTIME_KEY:
			encontrada = entidad_variant as Creature
			break
	if not is_instance_valid(encontrada):
		errors.append("La criatura materializada no quedó registrada en el chunk.")
	else:
		if encontrada.global_position != Vector2(384.5, 448.25):
			errors.append("El spawner no aplicó la posición guardada.")
		if encontrada.velocity != Vector2(2.25, -1.5):
			errors.append("El spawner no aplicó la velocidad guardada.")
		if encontrada.health != mini(7, encontrada.max_health):
			errors.append("El spawner no aplicó la salud guardada.")
		var necesidades: Variant = encontrada.datos.get("necesidades_runtime", {})
		if not necesidades is Dictionary or not is_equal_approx(float((necesidades as Dictionary).get("hambre", 0.0)), 0.73):
			errors.append("El spawner no transfirió las necesidades runtime al Creature.")

	if not errors.is_empty():
		_fail(errors)
		return
	print("ProceduralWorldEntityMaterialization: PASS seed=%d chunk=%s creature=%s" % [generator.map_seed, str(CHUNK), criatura_id])
	world_instance.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(errors: Array[String]) -> void:
	for error in errors:
		push_error("ProceduralWorldEntityMaterialization: FAIL: " + error)
	get_tree().quit(1)
