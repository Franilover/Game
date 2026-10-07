extends Node
class_name WorldEntitySpawner


@export_category("Aparición de criaturas")
@export var max_creatures_per_chunk: int = 5

var _terrain: WorldTerrain
var _entity_manager: WorldEntityManager = null
var _entity_factory: WorldEntityFactory = null
var _spawn_rules: WorldSpawnRules = null
var _world_data: WorldDataService = null
var _spawn_queue: Array[Vector2i] = []
var _spawn_queued: Dictionary = {}
var _prop_spawn_queue: Array[Vector2i] = []
var _prop_spawn_queued: Dictionary = {}
var _prop_spawn_tasks: Dictionary = {}
var _render_manager: Node = null

# Diagnóstico universal del pipeline de entidades. No decide el spawn;
# sólo deja visible en F4 dónde se está descartando el trabajo.
var _diag_chunks_iniciados: int = 0
var _diag_prop_intentos: int = 0
var _diag_prop_creados: int = 0
var _diag_prop_sin_datos: int = 0
var _diag_prop_sin_contexto: int = 0
var _diag_prop_sin_candidato: int = 0
var _diag_prop_factory: int = 0
var _diag_prop_registro: int = 0


func configurar(
	terrain: WorldTerrain,
	entity_manager: WorldEntityManager = null,
	entity_factory: WorldEntityFactory = null,
	spawn_rules: WorldSpawnRules = null,
	world_data: WorldDataService = null
) -> void:
	_terrain = terrain
	_entity_manager = entity_manager
	_entity_factory = entity_factory
	_spawn_rules = spawn_rules
	_world_data = world_data

	if _entity_manager == null:
		push_error("WorldEntitySpawner: Entity manager inválido.")
	if _entity_factory == null:
		push_error("WorldEntitySpawner: Entity factory inválido.")
	if _spawn_rules == null:
		push_error("WorldEntitySpawner: Spawn rules inválidas.")
	if _world_data == null:
		push_error("WorldEntitySpawner: WorldDataService inválido.")


func configurar_render_manager(render_manager: Node) -> void:
	_render_manager = render_manager


func obtener_diagnostico() -> Dictionary:
	return {
		"cola_chunks": _spawn_queue.size(),
		"tareas_props": _prop_spawn_tasks.size(),
		"cola_props_chunks": _prop_spawn_queue.size(),
		"chunks_iniciados": _diag_chunks_iniciados,
		"prop_intentos": _diag_prop_intentos,
		"prop_creados": _diag_prop_creados,
		"prop_sin_datos": _diag_prop_sin_datos,
		"prop_sin_contexto": _diag_prop_sin_contexto,
		"prop_sin_candidato": _diag_prop_sin_candidato,
		"prop_factory_fallo": _diag_prop_factory,
		"prop_registro_fallo": _diag_prop_registro
	}


func _ready() -> void:
	var debug: Node = get_node_or_null("/root/GarliaDebug")
	if debug != null and debug.has_method("registrar_proveedor"):
		debug.registrar_proveedor(
			"world_entity_spawner",
			"WorldEntitySpawner",
			self,
			"Spawn de props y criaturas por chunk."
		)


func spawn_chunk(chunk_coord: Vector2i) -> void:
	if _entity_manager == null:
		return
	if _entity_manager.tiene_criaturas_chunk(chunk_coord):
		return
	if _spawn_queued.has(chunk_coord):
		return
	_spawn_queue.append(chunk_coord)
	_spawn_queued[chunk_coord] = true


func spawn_props_chunk(chunk_coord: Vector2i) -> void:
	if _entity_manager == null:
		return
	if _entity_manager.tiene_props_chunk(chunk_coord):
		return
	if _prop_spawn_queued.has(chunk_coord) or _prop_spawn_tasks.has(chunk_coord):
		return
	_prop_spawn_queue.append(chunk_coord)
	_prop_spawn_queued[chunk_coord] = true


func procesar_spawn_queue(max_chunks: int = 1) -> void:
	var limite := maxi(max_chunks, 1)
	var procesados := 0
	while procesados < limite and not _spawn_queue.is_empty():
		var chunk_coord: Vector2i = _spawn_queue.pop_front()
		_spawn_queued.erase(chunk_coord)
		if _entity_manager != null and _entity_manager.tiene_criaturas_chunk(chunk_coord):
			continue
		_iniciar_tarea_spawn(chunk_coord)
		procesados += 1


func procesar_prop_spawn_queue(max_chunks: int = 1) -> void:
	var limite := maxi(max_chunks, 1)
	var procesados := 0
	for chunk_variant in _prop_spawn_tasks.keys():
		if procesados >= limite:
			break
		if chunk_variant is Vector2i:
			_procesar_tarea_prop_spawn(chunk_variant as Vector2i)
			procesados += 1
	while procesados < limite and not _prop_spawn_queue.is_empty():
		var chunk_coord: Vector2i = _prop_spawn_queue.pop_front()
		_prop_spawn_queued.erase(chunk_coord)
		if _entity_manager != null and _entity_manager.tiene_props_chunk(chunk_coord):
			continue
		_iniciar_tarea_prop_spawn(chunk_coord)
		procesados += 1


func cancelar_spawn_chunk(chunk_coord: Vector2i) -> void:
	_spawn_queued.erase(chunk_coord)
	_spawn_queue.erase(chunk_coord)


func cancelar_prop_spawn_chunk(chunk_coord: Vector2i) -> void:
	_prop_spawn_queued.erase(chunk_coord)
	_prop_spawn_queue.erase(chunk_coord)
	_prop_spawn_tasks.erase(chunk_coord)


func _spawn_chunk_interno(
	chunk_coord: Vector2i
) -> void:
	_diag_chunks_iniciados += 1
	if _terrain == null or not is_instance_valid(_terrain):
		push_error("WorldEntitySpawner: Terrain no configurado.")
		return
	if _entity_manager == null or _entity_factory == null or _spawn_rules == null or _world_data == null:
		return
	if _entity_manager.tiene_criaturas_chunk(chunk_coord):
		return

	var rng := RandomNumberGenerator.new()

	rng.seed = abs(
		_terrain.map_seed
		+ chunk_coord.x * 92837111
		+ chunk_coord.y * 689287499
	) + 1

	var creadas: Array = []

	var origin_x: int = (
		chunk_coord.x
		* _terrain.chunk_size_tiles
	)

	var origin_y: int = (
		chunk_coord.y
		* _terrain.chunk_size_tiles
	)

	var limite_chunk := Rect2(
		float(
			origin_x
			* _terrain.tile_size
		),
		float(
			origin_y
			* _terrain.tile_size
		),
		float(
			_terrain.chunk_size_tiles
			* _terrain.tile_size
		),
		float(
			_terrain.chunk_size_tiles
			* _terrain.tile_size
		)
	)

	var especies_creadas: Dictionary = {}

	for intento in range(32):
		if (
			creadas.size()
			>= max_creatures_per_chunk
		):
			break

		var local_x: int = rng.randi_range(
			0,
			_terrain.chunk_size_tiles - 1
		)

		var local_y: int = rng.randi_range(
			0,
			_terrain.chunk_size_tiles - 1
		)

		var tile := Vector2i(
			origin_x + local_x,
			origin_y + local_y
		)

		var bioma: Dictionary = (
			_terrain.get_bioma_at(tile)
		)

		if bioma.is_empty():
			continue

		var ecosistema: Dictionary = (
			_terrain.get_ecosistema_at(tile)
		)

		if ecosistema.is_empty():
			continue

		var candidatos: Array = (
			_spawn_rules.obtener_candidatos(ecosistema)
		)

		if candidatos.is_empty():
			continue

		var validos: Array = []

		for i in range(candidatos.size()):
			var candidato_variant: Variant = (
				candidatos[i]
			)

			if not candidato_variant is Dictionary:
				continue

			var candidato: Dictionary = (
				candidato_variant
			)

			var criatura_variant: Variant = (
				candidato.get(
					"criatura",
					{}
				)
			)

			if not criatura_variant is Dictionary:
				continue

			var criatura_data: Dictionary = (
				criatura_variant
			)

			var criatura_id: String = str(
				criatura_data.get(
					"id",
					""
				)
			)

			if criatura_id.is_empty():
				continue

			if especies_creadas.has(
				criatura_id
			):
				continue

			var habitat_clave: String = str(
				candidato.get(
					"habitat_clave",
					"general"
				)
			)

			var zona: int = (
				_terrain.get_zona_at(tile)
			)

			if not _spawn_rules.ubicacion_valida(bioma, habitat_clave, zona):
				continue

			validos.append(
				candidato
			)

		if validos.is_empty():
			continue

		var elegido: Dictionary = (
			_spawn_rules.elegir_criatura(validos, rng)
		)

		if elegido.is_empty():
			continue

		var criatura_variant: Variant = (
			elegido.get(
				"criatura",
				{}
			)
		)

		if not criatura_variant is Dictionary:
			continue

		var criatura_data: Dictionary = (
			criatura_variant.duplicate(true)
		)
		criatura_data["ecosistema_id"] = str(
			ecosistema.get("id", "")
		)

		var criatura_id_actual := str(criatura_data.get("id", "")).strip_edges()
		var instancia_key := "natural:" + str(creadas.size()) + ":" + criatura_id_actual
		var estado_previo: Dictionary = _entity_manager.obtener_estado_criatura(
			chunk_coord,
			criatura_id_actual,
			instancia_key
		)
		if not estado_previo.is_empty() and not bool(estado_previo.get("is_alive", true)):
			continue

		var criatura: Node = _entity_factory.crear_criatura(criatura_data)

		if criatura == null:
			continue

		criatura.set_meta("runtime_instance_key", instancia_key)

		if _entity_manager != null:
			if not _entity_manager.registrar(criatura, chunk_coord):
				continue

		criatura.global_position = Vector2(
			(float(tile.x) + 0.5)
			* _terrain.tile_size,
			(float(tile.y) + 0.5)
			* _terrain.tile_size
		)

		if not estado_previo.is_empty():
			criatura.global_position = estado_previo.get("position", criatura.global_position)
			criatura.velocity = estado_previo.get("velocity", Vector2.ZERO)
			if criatura is Entity:
				var entidad := criatura as Entity
				entidad.restaurar_estado_vital(
					int(estado_previo.get("health", entidad.health)),
					bool(estado_previo.get("is_alive", true))
				)
				if estado_previo.has("estado"):
					criatura.set_meta("estado_mundo", estado_previo.get("estado", ""))

		if criatura is Creature:
			var creature_node: Creature = criatura
			creature_node.configurar_chunk(
				chunk_coord,
				limite_chunk
			)

			creature_node.configurar_entorno(
				str(
					elegido.get(
						"habitat_clave",
						"general"
					)
				)
			)

		especies_creadas[
			str(
				criatura_data.get(
					"id",
					""
				)
			)
		] = true

		creadas.append(
			criatura
		)

	_spawn_characters_in_chunk(
		chunk_coord,
		limite_chunk,
		rng
	)
	# Props: se continúan en frames posteriores para evitar una ráfaga.
	_spawn_tasks[chunk_coord] = {
		"limite_chunk": limite_chunk,
		"rng": rng,
		"intento": 0,
		"creados": 0,
		"max_props": 6,
		"intentos_maximos": 48
	}
	return

func _iniciar_tarea_spawn(chunk_coord: Vector2i) -> void:
	if _terrain == null or _entity_manager == null or _entity_factory == null:
		return
	if _entity_manager.tiene_criaturas_chunk(chunk_coord):
		return
	_spawn_chunk_interno(chunk_coord)


func _iniciar_tarea_prop_spawn(chunk_coord: Vector2i) -> void:
	if _terrain == null or _entity_manager == null or _entity_factory == null:
		return
	if _entity_manager.tiene_props_chunk(chunk_coord) or _prop_spawn_tasks.has(chunk_coord):
		return

	var origin_x: int = chunk_coord.x * _terrain.chunk_size_tiles
	var origin_y: int = chunk_coord.y * _terrain.chunk_size_tiles
	var limite_chunk := Rect2(
		float(origin_x * _terrain.tile_size),
		float(origin_y * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size)
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(
		_terrain.map_seed
		+ chunk_coord.x * 92837111
		+ chunk_coord.y * 689287499
	) + 1
	_prop_spawn_tasks[chunk_coord] = {
		"limite_chunk": limite_chunk,
		"rng": rng,
		"intento": 0,
		"creados": 0,
		"max_props": 6,
		"intentos_maximos": 48
	}


func _procesar_tarea_prop_spawn(chunk_coord: Vector2i) -> void:
	var tarea_variant: Variant = _prop_spawn_tasks.get(chunk_coord, {})
	if not tarea_variant is Dictionary:
		_prop_spawn_tasks.erase(chunk_coord)
		return
	var tarea := tarea_variant as Dictionary
	if _entity_manager == null or _entity_manager.tiene_props_chunk(chunk_coord):
		_prop_spawn_tasks.erase(chunk_coord)
		return
	var rng_variant: Variant = tarea.get("rng", null)
	if not rng_variant is RandomNumberGenerator:
		_prop_spawn_tasks.erase(chunk_coord)
		return
	var rng := rng_variant as RandomNumberGenerator
	var intento := int(tarea.get("intento", 0))
	var creados := int(tarea.get("creados", 0))
	var max_props := int(tarea.get("max_props", 6))
	var max_intentos := int(tarea.get("intentos_maximos", 48))
	var limite_chunk: Rect2 = tarea.get("limite_chunk", Rect2())
	if creados >= max_props or intento >= max_intentos:
		_prop_spawn_tasks.erase(chunk_coord)
		_entity_manager.activar_props_chunk(chunk_coord)
		return
	var inicio_usec := Time.get_ticks_usec()
	var creado := _intentar_crear_prop(chunk_coord, limite_chunk, rng, creados)
	if _render_manager != null and is_instance_valid(_render_manager):
		_render_manager.call("registrar_trabajo", "prop_spawn", float(Time.get_ticks_usec() - inicio_usec) / 1000.0, 1)
	if creado:
		creados += 1
	tarea["creados"] = creados
	tarea["intento"] = intento + 1
	if creados >= max_props or int(tarea["intento"]) >= max_intentos:
		_prop_spawn_tasks.erase(chunk_coord)
		_entity_manager.activar_props_chunk(chunk_coord)
	else:
		_prop_spawn_tasks[chunk_coord] = tarea


func _intentar_crear_prop(chunk_coord: Vector2i, limite_chunk: Rect2, rng: RandomNumberGenerator, slot: int) -> bool:
	_diag_prop_intentos += 1
	var props := _world_data.obtener_props_game()
	if props.is_empty():
		_diag_prop_sin_datos += 1
		return false
	var tile := Vector2i(chunk_coord.x * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1), chunk_coord.y * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1))
	if not _terrain.is_walkable(tile):
		return false
	var bioma := _terrain.get_bioma_at(tile)
	var ecosistema := _terrain.get_ecosistema_at(tile)
	var habitats := _terrain.get_habitats_at(tile)
	if bioma.is_empty() or ecosistema.is_empty() or habitats.is_empty():
		_diag_prop_sin_contexto += 1
		return false
	var bioma_id := str(bioma.get("id", ""))
	var ecosistema_id := str(ecosistema.get("id", ""))
	if bioma_id.is_empty() or ecosistema_id.is_empty():
		return false
	var habitat_ids: Array[String] = []
	for habitat_variant in habitats:
		if habitat_variant is Dictionary:
			var habitat := habitat_variant as Dictionary
			var habitat_id := str(habitat.get("id", ""))
			if not habitat_id.is_empty() and habitat_id not in habitat_ids:
				habitat_ids.append(habitat_id)
	if habitat_ids.is_empty():
		return false
	var candidatos: Array[Dictionary] = []
	var candidatos_bioma: Array[Dictionary] = []
	for prop_variant in props:
		if not prop_variant is Dictionary:
			continue
		var prop := prop_variant as Dictionary
		if str(prop.get("bioma_id", "")) != bioma_id:
			continue

		# El vínculo por bioma es la regla mínima canónica. Si existe una
		# configuración exacta para ecosistema/hábitat la preferimos; si no,
		# usamos otra configuración del mismo bioma. Así un prop no desaparece
		# sólo porque el chunk use otro ecosistema válido del mismo bioma.
		var coincide_contexto := (
			str(prop.get("ecosistema_id", "")) == ecosistema_id
			and str(prop.get("habitat_id", "")) in habitat_ids
		)
		var nombre := str(prop.get("nombre", "")).strip_edges()
		if nombre.is_empty():
			continue
		var datos_prop := prop.duplicate(true)
		datos_prop["asset_path"] = _spawn_rules.construir_asset_path_prop(datos_prop)
		if str(datos_prop.get("asset_path", "")).is_empty():
			continue
		if coincide_contexto:
			candidatos.append(datos_prop)
		candidatos_bioma.append(datos_prop)

	if candidatos.is_empty():
		candidatos = candidatos_bioma
	if candidatos.is_empty():
		_diag_prop_sin_candidato += 1
		return false
	var elegido := _spawn_rules.elegir_prop(candidatos, rng)
	if elegido.is_empty() or not _entity_factory.has_method("crear_prop"):
		_diag_prop_factory += 1
		return false
	var prop_id := str(elegido.get("id", "")).strip_edges()
	var prop_instance_key := "prop:" + str(slot) + ":" + prop_id
	var estado := _entity_manager.obtener_estado_prop(chunk_coord, prop_instance_key)
	var prop_variant: Variant = _entity_factory.call("crear_prop", elegido)
	if not prop_variant is Node:
		return false
	var prop_node := prop_variant as Node
	prop_node.set_meta("runtime_instance_key", prop_instance_key)
	if not _entity_manager.registrar(prop_node, chunk_coord):
		_diag_prop_registro += 1
		return false
	prop_node.global_position = Vector2((float(tile.x) + 0.5) * _terrain.tile_size, (float(tile.y) + 0.5) * _terrain.tile_size)
	if not estado.is_empty():
		prop_node.global_position = estado.get("position", prop_node.global_position)
	if prop_node.has_method("configurar_chunk"):
		prop_node.call("configurar_chunk", chunk_coord, limite_chunk)
	_diag_prop_creados += 1
	return true

func summon_criatura(
	nombre: String,
	posicion: Vector2
) -> Dictionary:
	var nombre_solicitado: String = nombre.strip_edges()

	if nombre_solicitado.is_empty():
		return {
			"ok": false,
			"mensaje": "Debes indicar una criatura o personaje."
		}

	var personaje_game: Dictionary = (
		_world_data.buscar_personaje_game_por_nombre(
			nombre_solicitado
		)
	)

	var criatura_data: Dictionary = {}
	var nombre_inicial: String = nombre_solicitado

	if not personaje_game.is_empty():
		var criatura_id: String = str(
			personaje_game.get(
				"criatura_id",
				""
			)
		)

		criatura_data = _world_data.obtener_criatura(
			criatura_id
		).duplicate(true)

		if criatura_data.is_empty():
			return {
				"ok": false,
				"mensaje": (
					"El personaje "
					+ str(personaje_game.get("nombre", nombre_solicitado))
					+ " apunta a una criatura que no está en el mundo."
				)
			}

		criatura_data["nombre_individual"] = str(
			personaje_game.get(
				"nombre",
				nombre_solicitado
			)
		)
		var personaje_id := str(
			personaje_game.get(
				"id",
				""
			)
		)

		criatura_data["personaje_game_id"] = personaje_id

		var dialogo_personaje := _world_data.obtener_dialogo_game(
			personaje_id
		)
		if not dialogo_personaje.is_empty():
			criatura_data["dialogo"] = dialogo_personaje
		else:
			criatura_data.erase("dialogo")

		nombre_inicial = str(
			personaje_game.get(
				"nombre",
				nombre_solicitado
			)
		)
	else:
		criatura_data = _world_data.buscar_criatura_por_nombre(
			nombre_solicitado
		)

		if criatura_data.is_empty():
			return {
				"ok": false,
				"mensaje": (
					"No existe una criatura o personaje llamado "
					+ nombre_solicitado
				)
			}

		if str(
			criatura_data.get(
				"nombre",
				""
			)
		).strip_edges().to_lower() == "humano":
			var personajes_humanos: Array[Dictionary] = (
				_world_data.obtener_personajes_game_de_criatura(
					str(
						criatura_data.get(
							"id",
							""
						)
					)
				)
			)

			if not personajes_humanos.is_empty():
				var rng_personaje := RandomNumberGenerator.new()
				rng_personaje.randomize()

				var elegido: Dictionary = personajes_humanos[
					rng_personaje.randi_range(
						0,
						personajes_humanos.size() - 1
					)
				]

				criatura_data = criatura_data.duplicate(true)
				criatura_data["nombre_individual"] = str(
					elegido.get(
						"nombre",
						""
					)
				)
				var personaje_id := str(
					elegido.get(
						"id",
						""
					)
				)

				criatura_data["personaje_game_id"] = personaje_id

				var dialogo_personaje := _world_data.obtener_dialogo_game(
					personaje_id
				)
				if not dialogo_personaje.is_empty():
					criatura_data["dialogo"] = dialogo_personaje
				else:
					criatura_data.erase("dialogo")

				nombre_inicial = str(
					elegido.get(
						"nombre",
						"Humano"
					)
				)

	if _entity_manager == null:
		return {
			"ok": false,
			"mensaje": "Entity manager no configurado."
		}

	var criatura: Node = _entity_factory.crear_criatura(criatura_data)

	if criatura == null:
		return {
			"ok": false,
			"mensaje": (
				"No se pudo crear la escena "
				+ "de la criatura."
			)
		}

	if not _entity_manager.registrar_global(criatura):
		return {"ok": false, "mensaje": "No se pudo registrar la criatura."}

	criatura.global_position = (
		posicion
	)

	if criatura is Creature:
		var creature_node: Creature = (
			criatura
		)

		if _terrain != null:
			var tile_size := maxi(
				_terrain.tile_size,
				1
			)

			var posicion_local := (
				_terrain.to_local(
					posicion
				)
			)

			var tile := Vector2i(
				floori(
					posicion_local.x
					/ float(tile_size)
				),
				floori(
					posicion_local.y
					/ float(tile_size)
				)
			)

			var chunk_coord := Vector2i(
				floori(
					float(tile.x)
					/ float(
						_terrain.chunk_size_tiles
					)
				),
				floori(
					float(tile.y)
					/ float(
						_terrain.chunk_size_tiles
					)
				)
			)

			var origin_x := (
				chunk_coord.x
				* _terrain.chunk_size_tiles
			)

			var origin_y := (
				chunk_coord.y
				* _terrain.chunk_size_tiles
			)

			var limites_chunk := Rect2(
				float(
					origin_x
					* _terrain.tile_size
				),
				float(
					origin_y
					* _terrain.tile_size
				),
				float(
					_terrain.chunk_size_tiles
					* _terrain.tile_size
				),
				float(
					_terrain.chunk_size_tiles
					* _terrain.tile_size
				)
			)

			creature_node.configurar_chunk(
				chunk_coord,
				limites_chunk
			)

			creature_node.configurar_entorno(
				"general"
			)

	return {
		"ok": true,
		"nombre": nombre_inicial,
		"es_personaje_game": not personaje_game.is_empty(),
		"criatura": criatura
	}


func despawn_chunk(chunk_coord: Vector2i) -> void:
	cancelar_spawn_chunk(chunk_coord)
	cancelar_prop_spawn_chunk(chunk_coord)
	if _entity_manager != null:
		_entity_manager.despawn_criaturas_chunk(chunk_coord)
		_entity_manager.despawn_props_chunk(chunk_coord)


func despawn_criaturas_chunk(chunk_coord: Vector2i) -> void:
	cancelar_spawn_chunk(chunk_coord)
	if _entity_manager != null:
		_entity_manager.despawn_criaturas_chunk(chunk_coord)


func despawn_props_chunk(chunk_coord: Vector2i) -> void:
	cancelar_prop_spawn_chunk(chunk_coord)
	if _entity_manager != null:
		_entity_manager.despawn_props_chunk(chunk_coord)


