extends Node
class_name WorldEntitySpawner


@export_category("Aparición de criaturas")
@export var max_creatures_per_chunk: int = 5

var _terrain: WorldTerrain
var _entity_manager: WorldEntityManager = null
var _entity_factory: WorldEntityFactory = null
var _spawn_rules: WorldSpawnRules = null
var _world_data: WorldDataService = null


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


func spawn_chunk(
	chunk_coord: Vector2i
) -> void:
	if _terrain == null or not is_instance_valid(_terrain):
		push_error("WorldEntitySpawner: Terrain no configurado.")
		return
	if _entity_manager == null or _entity_factory == null or _spawn_rules == null or _world_data == null:
		return
	if _entity_manager.tiene_chunk(chunk_coord):
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

		var criatura: Node = _entity_factory.crear_criatura(criatura_data)

		if criatura == null:
			continue

		if _entity_manager != null:
			if not _entity_manager.registrar(criatura, chunk_coord):
				continue

		criatura.global_position = Vector2(
			(float(tile.x) + 0.5)
			* _terrain.tile_size,
			(float(tile.y) + 0.5)
			* _terrain.tile_size
		)

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
	_spawn_props_in_chunk(
		chunk_coord,
		limite_chunk,
		rng
	)

	# El chunk se marca activo solo después de terminar todo el proceso
	# de aparición. Así un fallo parcial no bloquea futuros reintentos.
	_entity_manager.activar_chunk(chunk_coord)

	if not creadas.is_empty():
		print(
			"WorldEntitySpawner: chunk ",
			chunk_coord,
			" → ",
			creadas.size(),
			" criaturas"
		)


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
	if _entity_manager != null:
		_entity_manager.despawn_chunk(chunk_coord)


func _spawn_characters_in_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2,
	rng: RandomNumberGenerator
) -> void:
	var personajes := _world_data.obtener_personajes_game()
	if personajes.is_empty():
		return

	var creados: Array = []

	for personaje_variant in personajes:
		if not personaje_variant is Dictionary:
			continue

		var personaje := personaje_variant as Dictionary
		var personaje_id := str(personaje.get("id", ""))
		var reino_game_id := str(personaje.get("reino_game_id", ""))
		var bioma_ids_variant: Variant = personaje.get("bioma_ids", [])

		if personaje_id.is_empty() or reino_game_id.is_empty():
			continue
		if _entity_manager != null and _entity_manager.existe_persistente(personaje_id):
			continue
		if not bioma_ids_variant is Array:
			continue

		var bioma_ids := bioma_ids_variant as Array
		if bioma_ids.is_empty():
			continue

		var tile := _spawn_rules.buscar_tile_para_personaje(chunk_coord, bioma_ids, rng)
		if tile == Vector2i(2147483647, 2147483647):
			continue

		var criatura_id := str(personaje.get("criatura_id", ""))
		if criatura_id.is_empty():
			continue

		var criatura_data := _world_data.obtener_criatura(criatura_id).duplicate(true)
		if criatura_data.is_empty():
			continue

		criatura_data["nombre_individual"] = str(personaje.get("nombre", ""))
		criatura_data["personaje_game_id"] = personaje_id
		criatura_data["reino_game_id"] = reino_game_id
		criatura_data["reino_nombre"] = str(personaje.get("reino_nombre", ""))

		var dialogo := _world_data.obtener_dialogo_game(personaje_id)
		if not dialogo.is_empty():
			criatura_data["dialogo"] = dialogo
		else:
			criatura_data.erase("dialogo")

		var criatura: Node = _entity_factory.crear_criatura(criatura_data)
		if criatura == null:
			continue

		if not _entity_manager.registrar(criatura, chunk_coord, personaje_id):
			continue
		criatura.global_position = Vector2(
			(float(tile.x) + 0.5) * _terrain.tile_size,
			(float(tile.y) + 0.5) * _terrain.tile_size
		)
		criatura.set_meta("personaje_game_id", personaje_id)

		if criatura is Creature:
			var creature_node := criatura as Creature
			creature_node.configurar_chunk(chunk_coord, limite_chunk)
			creature_node.configurar_entorno("general")

		creados.append(criatura)

	if not creados.is_empty():
		print("WorldEntitySpawner: personajes en reino → chunk ", chunk_coord, " → ", creados.size())


func _spawn_props_in_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2,
	rng: RandomNumberGenerator
) -> void:
	var props := _world_data.obtener_props_game()
	if props.is_empty():
		return

	var creados: Array = []
	var max_props := 6
	var intentos := 48

	for _intento in range(intentos):
		if creados.size() >= max_props:
			break

		var tile := Vector2i(
			chunk_coord.x * _terrain.chunk_size_tiles
			+ rng.randi_range(0, _terrain.chunk_size_tiles - 1),
			chunk_coord.y * _terrain.chunk_size_tiles
			+ rng.randi_range(0, _terrain.chunk_size_tiles - 1)
		)

		if not _terrain.is_walkable(tile):
			continue

		var bioma := _terrain.get_bioma_at(tile)
		var ecosistema := _terrain.get_ecosistema_at(tile)
		var habitats := _terrain.get_habitats_at(tile)

		if bioma.is_empty() or ecosistema.is_empty() or habitats.is_empty():
			continue

		var bioma_id := str(bioma.get("id", ""))
		var ecosistema_id := str(ecosistema.get("id", ""))
		if bioma_id.is_empty() or ecosistema_id.is_empty():
			continue

		var habitat_ids: Array[String] = []
		for habitat_variant in habitats:
			if not habitat_variant is Dictionary:
				continue

			var habitat := habitat_variant as Dictionary
			var habitat_id := str(habitat.get("id", ""))
			if not habitat_id.is_empty() and habitat_id not in habitat_ids:
				habitat_ids.append(habitat_id)

		if habitat_ids.is_empty():
			continue

		var candidatos: Array[Dictionary] = []
		for prop_variant in props:
			if not prop_variant is Dictionary:
				continue

			var prop := prop_variant as Dictionary
			if str(prop.get("bioma_id", "")) != bioma_id:
				continue
			if str(prop.get("ecosistema_id", "")) != ecosistema_id:
				continue
			if str(prop.get("habitat_id", "")) not in habitat_ids:
				continue

			var nombre := str(prop.get("nombre", "")).strip_edges()
			if nombre.is_empty():
				continue

			var datos_prop := prop.duplicate(true)
			datos_prop["asset_path"] = _spawn_rules.construir_asset_path_prop(datos_prop)
			if datos_prop["asset_path"] == "":
				continue

			candidatos.append(datos_prop)

		if candidatos.is_empty():
			continue

		var elegido := _spawn_rules.elegir_prop(candidatos, rng)
		if elegido.is_empty():
			continue

		if not _entity_factory.has_method("crear_prop"):
			push_error("WorldEntitySpawner: WorldEntityFactory no expone crear_prop().")
			continue

		var prop_node_variant: Variant = _entity_factory.call("crear_prop", elegido)
		if not prop_node_variant is Node:
			continue
		var prop_node: Node = prop_node_variant as Node
		if prop_node == null:
			continue

		if _entity_manager != null:
			if not _entity_manager.registrar(prop_node, chunk_coord):
				continue
		prop_node.global_position = Vector2(
			(float(tile.x) + 0.5) * _terrain.tile_size,
			(float(tile.y) + 0.5) * _terrain.tile_size
		)

		if prop_node.has_method("configurar_chunk"):
			prop_node.call("configurar_chunk", chunk_coord, limite_chunk)

		creados.append(prop_node)

	if not creados.is_empty():
		print(
			"WorldEntitySpawner: props canonicos → chunk ",
			chunk_coord,
			" → ",
			creados.size()
		)
