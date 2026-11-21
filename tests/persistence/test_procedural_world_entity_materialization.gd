extends Node

const WORLD_SCENE: PackedScene = preload("res://scenes/world/mundo_abierto.tscn")
const CHUNK := Vector2i.ZERO


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

	generator.configurar_dependencias(WorldData, GameState)
	generator.configurar_entidades(entities_root, player)
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
	var spawner := generator.entity_spawner

	# Generación DATA auténtica: el spawner elige especies y posiciones a
	# partir del ecosistema, bioma y semilla del chunk. No se inyectan
	# criaturas ni registros runtime de prueba.
	await spawner.preparar_datos_criaturas_chunk(CHUNK)
	var datos_generados := manager.obtener_datos_chunk(CHUNK, "criaturas")
	var datos_criatura: Dictionary = {}
	for dato_variant in datos_generados:
		if not dato_variant is Dictionary:
			continue
		var dato := dato_variant as Dictionary
		if str(dato.get("categoria_entidad", "criatura")).to_lower() == "garumi":
			continue
		if str(dato.get("criatura_id", "")).strip_edges().is_empty():
			continue
		datos_criatura = dato.duplicate(true)
		break
	if datos_criatura.is_empty():
		_fail(["La semilla fija no produjo una criatura natural en el chunk de prueba; no se puede verificar la persistencia sin fixture."])
		return

	var criatura_id := str(datos_criatura.get("criatura_id", ""))
	var runtime_key := str(datos_criatura.get("runtime_instance_key", ""))
	if runtime_key.is_empty():
		_fail(["El spawn natural no recibió una clave de instancia estable."])
		return
	if not spawner.materializar_criaturas_datos_chunk(CHUNK):
		_fail(["El spawner real no materializó los datos naturales del chunk."])
		return

	var criatura := _buscar_criatura(manager.obtener_por_chunk(CHUNK), runtime_key)
	if not is_instance_valid(criatura):
		_fail(["La criatura natural no quedó registrada tras materializar DATA."])
		return

	# Preparar también props desde el catálogo/bioma real. La prueba los
	# verifica cuando el chunk tiene candidatos válidos; no inyecta datos.
	await spawner.preparar_datos_props_chunk(CHUNK)
	var datos_props := manager.obtener_datos_chunk(CHUNK, "props")
	var prop_runtime_key := ""
	var prop_posicion_modificada := Vector2.ZERO
	var prop_materializado: WorldProp = null
	if not datos_props.is_empty():
		for dato_prop_variant in datos_props:
			if not dato_prop_variant is Dictionary:
				continue
			var dato_prop := dato_prop_variant as Dictionary
			prop_runtime_key = str(dato_prop.get("runtime_instance_key", "")).strip_edges()
			if not prop_runtime_key.is_empty():
				break
		if not prop_runtime_key.is_empty() and spawner.materializar_props_datos_chunk(CHUNK):
			for entidad_variant in manager.obtener_por_chunk(CHUNK):
				if entidad_variant is WorldProp and is_instance_valid(entidad_variant):
					var prop_candidato := entidad_variant as WorldProp
					if str(prop_candidato.get_meta("runtime_instance_key", "")) == prop_runtime_key:
						prop_materializado = prop_candidato
						break
		if is_instance_valid(prop_materializado):
				prop_posicion_modificada = prop_materializado.global_position + Vector2(-21.5, 13.75)
				prop_materializado.global_position = prop_posicion_modificada

	# Simula cambios runtime del juego sobre las instancias naturales y captura
	# el snapshot usando el mismo contrato que GameState utiliza al guardar.
	var posicion_modificada := criatura.global_position + Vector2(37.5, -19.25)
	var velocidad_modificada := Vector2(2.25, -1.5)
	criatura.global_position = posicion_modificada
	criatura.velocity = velocidad_modificada
	var snapshot := manager.capturar_estado_persistente_mundo()
	var clave_estado := "0:0:" + runtime_key
	var estado_criatura: Dictionary = (snapshot.get("criaturas", {}) as Dictionary).get(clave_estado, {}) as Dictionary
	if estado_criatura.is_empty():
		_fail(["El manager no capturó el estado de la criatura generada naturalmente."])
		return
	if estado_criatura.get("position") != posicion_modificada or estado_criatura.get("velocity") != velocidad_modificada:
		_fail(["El snapshot no conservó la posición y velocidad runtime de la criatura."])
		return
	if is_instance_valid(prop_materializado):
		var clave_prop_estado := "0:0:" + prop_runtime_key
		var estado_prop: Dictionary = (snapshot.get("props", {}) as Dictionary).get(clave_prop_estado, {}) as Dictionary
		if estado_prop.is_empty() or estado_prop.get("position") != prop_posicion_modificada:
			_fail(["El snapshot no conservó la posición del prop natural."])
			return

	# Simula descarga y reentrada al chunk: las instancias se eliminan, pero
	# el estado guardado debe aplicarse a las mismas apariciones deterministas.
	manager.despawn_criaturas_chunk(CHUNK)
	if is_instance_valid(prop_materializado):
		manager.despawn_props_chunk(CHUNK)
	manager.restaurar_estado_persistente_mundo(snapshot)
	if not spawner.materializar_criaturas_datos_chunk(CHUNK):
		_fail(["No se pudo rematerializar el spawn natural después de restaurar el snapshot."])
		return

	var restaurada := _buscar_criatura(manager.obtener_por_chunk(CHUNK), runtime_key)
	if not is_instance_valid(restaurada):
		_fail(["La criatura natural no reapareció tras restaurar el estado."])
		return
	if restaurada.global_position != posicion_modificada:
		errors.append("La posición runtime no sobrevivió a descarga y rematerialización.")
	if restaurada.velocity != velocidad_modificada:
		errors.append("La velocidad runtime no sobrevivió a descarga y rematerialización.")
	if is_instance_valid(prop_materializado):
		if not spawner.materializar_props_datos_chunk(CHUNK):
			errors.append("No se pudo rematerializar el prop natural después de restaurar el snapshot.")
		else:
			var prop_restaurado: WorldProp = null
			for entidad_variant in manager.obtener_por_chunk(CHUNK):
				if entidad_variant is WorldProp and is_instance_valid(entidad_variant):
					var candidato := entidad_variant as WorldProp
					if str(candidato.get_meta("runtime_instance_key", "")) == prop_runtime_key:
						prop_restaurado = candidato
						break
			if not is_instance_valid(prop_restaurado):
				errors.append("El prop natural no reapareció tras restaurar el estado.")
			elif prop_restaurado.global_position != prop_posicion_modificada:
				errors.append("La posición runtime del prop no sobrevivió a la rematerialización.")
	if manager.obtener_por_chunk(CHUNK).filter(func(entidad: Variant) -> bool:
		return entidad is Creature and str((entidad as Creature).get_meta("runtime_instance_key", "")) == runtime_key
	).size() != 1:
		errors.append("La rematerialización duplicó la criatura del mismo spawn.")

	if not errors.is_empty():
		_fail(errors)
		return
	print("ProceduralWorldEntityMaterialization: PASS seed=%d chunk=%s creature=%s runtime=%s props=%d" % [generator.map_seed, str(CHUNK), criatura_id, runtime_key, datos_props.size()])
	world_instance.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _buscar_criatura(entidades: Array, runtime_key: String) -> Creature:
	for entidad_variant in entidades:
		if entidad_variant is Creature and is_instance_valid(entidad_variant):
			var criatura := entidad_variant as Creature
			if str(criatura.get_meta("runtime_instance_key", "")) == runtime_key:
				return criatura
	return null


func _fail(errors: Array[String]) -> void:
	for error in errors:
		push_error("ProceduralWorldEntityMaterialization: FAIL: " + error)
	get_tree().quit(1)
