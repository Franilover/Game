extends Node
class_name WorldEntitySpawner


const CREATURE_SCENE: PackedScene = preload(
	"res://scenes/creatures/creature.tscn"
)

const CRIATURA_FLAXIS := 1 << 0
const CRIATURA_ZLISH := 1 << 1
const CRIATURA_LIGNIANOS := 1 << 2


@export_category("Aparición de criaturas")

@export var max_creatures_per_chunk: int = 3

@export_flags(
	"Flaxis",
	"Zlish",
	"Lignianos"
)
var criaturas_destacadas: int = (
	CRIATURA_FLAXIS
	| CRIATURA_ZLISH
	| CRIATURA_LIGNIANOS
)

@export_range(
	0.0,
	100.0,
	0.1
)
var peso_normal: float = 1.0

@export_range(
	0.0,
	100.0,
	0.1
)
var peso_destacadas: float = 4.0


var _terrain: WorldTerrain

var _creatures_by_chunk: Dictionary = {}
var _characters_by_chunk: Dictionary = {}
var _spawned_characters: Dictionary = {}
var _props_by_chunk: Dictionary = {}


func configurar(
	terrain: WorldTerrain
) -> void:
	_terrain = terrain


func spawn_chunk(
	chunk_coord: Vector2i
) -> void:
	if _creatures_by_chunk.has(
		chunk_coord
	):
		return

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		return

	var entities: Node = (
		current_scene.get_node_or_null(
			"Entities"
		)
	)

	if entities == null:
		push_warning(
			"WorldEntitySpawner: no existe "
			+ "Main/Entities."
		)
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
			_obtener_candidatos(
				ecosistema
			)
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

			if not _ubicacion_valida(
				bioma,
				habitat_clave,
				zona
			):
				continue

			validos.append(
				candidato
			)

		if validos.is_empty():
			continue

		var elegido: Dictionary = (
			_elegir_candidato_ponderado(
				validos,
				rng
			)
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
			criatura_variant
		)

		var criatura: Node = (
			CREATURE_SCENE.instantiate()
		)

		if criatura == null:
			continue

		entities.add_child(
			criatura
		)

		criatura.global_position = Vector2(
			(float(tile.x) + 0.5)
			* _terrain.tile_size,
			(float(tile.y) + 0.5)
			* _terrain.tile_size
		)

		if criatura is Creature:
			var creature_node: Creature = (
				criatura
			)

			creature_node.configurar(
				criatura_data
			)

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

	_creatures_by_chunk[chunk_coord] = (
		creadas
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
		WorldData.buscar_personaje_game_por_nombre(
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

		criatura_data = WorldData.obtener_criatura(
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

		var dialogo_personaje := WorldData.obtener_dialogo_game(
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
		criatura_data = WorldData.buscar_criatura_por_nombre(
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
				WorldData.obtener_personajes_game_de_criatura(
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

				var dialogo_personaje := WorldData.obtener_dialogo_game(
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

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		return {
			"ok": false,
			"mensaje": "No existe la escena actual."
		}

	var entities: Node = (
		current_scene.get_node_or_null(
			"Entities"
		)
	)

	if entities == null:
		return {
			"ok": false,
			"mensaje": "No existe el nodo Main/Entities."
		}

	var criatura: Node = (
		CREATURE_SCENE.instantiate()
	)

	if criatura == null:
		return {
			"ok": false,
			"mensaje": (
				"No se pudo crear la escena "
				+ "de la criatura."
			)
		}

	entities.add_child(
		criatura
	)

	criatura.global_position = (
		posicion
	)

	if criatura is Creature:
		var creature_node: Creature = (
			criatura
		)

		creature_node.configurar(
			criatura_data
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


func _elegir_candidato_ponderado(
	candidatos: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	var peso_total: float = 0.0

	for i in range(candidatos.size()):
		var candidato_variant: Variant = (
			candidatos[i]
		)

		if not candidato_variant is Dictionary:
			continue

		var candidato: Dictionary = (
			candidato_variant
		)

		var peso: float = (
			_obtener_peso_candidato(
				candidato
			)
		)

		if peso > 0.0:
			peso_total += peso

	if peso_total <= 0.0:
		return {}

	var objetivo: float = (
		rng.randf_range(
			0.0,
			peso_total
		)
	)

	var acumulado: float = 0.0

	for i in range(candidatos.size()):
		var candidato_variant: Variant = (
			candidatos[i]
		)

		if not candidato_variant is Dictionary:
			continue

		var candidato: Dictionary = (
			candidato_variant
		)

		var peso: float = (
			_obtener_peso_candidato(
				candidato
			)
		)

		if peso <= 0.0:
			continue

		acumulado += peso

		if objetivo <= acumulado:
			return candidato

	return candidatos[
		candidatos.size() - 1
	]


func _obtener_peso_candidato(
	candidato: Dictionary
) -> float:
	var criatura_variant: Variant = (
		candidato.get(
			"criatura",
			{}
		)
	)

	if not criatura_variant is Dictionary:
		return peso_normal

	var criatura: Dictionary = (
		criatura_variant
	)

	var nombre: String = str(
		criatura.get(
			"nombre",
			""
		)
	)

	match nombre:
		"Flaxis":
			if (
				criaturas_destacadas
				& CRIATURA_FLAXIS
			) != 0:
				return peso_destacadas

		"Zlish":
			if (
				criaturas_destacadas
				& CRIATURA_ZLISH
			) != 0:
				return peso_destacadas

		"Lignianos":
			if (
				criaturas_destacadas
				& CRIATURA_LIGNIANOS
			) != 0:
				return peso_destacadas

	return peso_normal


func despawn_chunk(
	chunk_coord: Vector2i
) -> void:
	if not _creatures_by_chunk.has(
		chunk_coord
	):
		return

	var criaturas_variant: Variant = (
		_creatures_by_chunk[chunk_coord]
	)

	if criaturas_variant is Array:
		var criaturas: Array = (
			criaturas_variant
		)

		for i in range(criaturas.size()):
			var criatura_variant: Variant = (
				criaturas[i]
			)

			if not criatura_variant is Node:
				continue

			var criatura: Node = (
				criatura_variant
			)

			if is_instance_valid(criatura):
				criatura.queue_free()

	_creatures_by_chunk.erase(
		chunk_coord
	)

	if _characters_by_chunk.has(chunk_coord):
		var personajes_variant: Variant = _characters_by_chunk[chunk_coord]
		if personajes_variant is Array:
			for personaje_variant in personajes_variant:
				if not personaje_variant is Node:
					continue

				var personaje := personaje_variant as Node
				if not is_instance_valid(personaje):
					continue

				var personaje_id := str(personaje.get_meta("personaje_game_id", ""))
				if not personaje_id.is_empty():
					_spawned_characters.erase(personaje_id)
				personaje.queue_free()

	_characters_by_chunk.erase(chunk_coord)

	if _props_by_chunk.has(chunk_coord):
		var props_variant: Variant = _props_by_chunk[chunk_coord]
		if props_variant is Array:
			for prop_variant in props_variant:
				if not prop_variant is Node:
					continue

				var prop := prop_variant as Node
				if is_instance_valid(prop):
					prop.queue_free()

		_props_by_chunk.erase(chunk_coord)


func _spawn_characters_in_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2,
	rng: RandomNumberGenerator
) -> void:
	var personajes := WorldData.obtener_personajes_game()
	if personajes.is_empty():
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var entities: Node = current_scene.get_node_or_null("Entities")
	if entities == null:
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
		if _spawned_characters.has(personaje_id):
			continue
		if not bioma_ids_variant is Array:
			continue

		var bioma_ids := bioma_ids_variant as Array
		if bioma_ids.is_empty():
			continue

		var tile := _buscar_tile_para_personaje(chunk_coord, bioma_ids, rng)
		if tile == Vector2i(2147483647, 2147483647):
			continue

		var criatura_id := str(personaje.get("criatura_id", ""))
		if criatura_id.is_empty():
			continue

		var criatura_data := WorldData.obtener_criatura(criatura_id).duplicate(true)
		if criatura_data.is_empty():
			continue

		criatura_data["nombre_individual"] = str(personaje.get("nombre", ""))
		criatura_data["personaje_game_id"] = personaje_id
		criatura_data["reino_game_id"] = reino_game_id
		criatura_data["reino_nombre"] = str(personaje.get("reino_nombre", ""))

		var dialogo := WorldData.obtener_dialogo_game(personaje_id)
		if not dialogo.is_empty():
			criatura_data["dialogo"] = dialogo
		else:
			criatura_data.erase("dialogo")

		var criatura: Node = CREATURE_SCENE.instantiate()
		if criatura == null:
			continue

		entities.add_child(criatura)
		criatura.global_position = Vector2(
			(float(tile.x) + 0.5) * _terrain.tile_size,
			(float(tile.y) + 0.5) * _terrain.tile_size
		)
		criatura.set_meta("personaje_game_id", personaje_id)

		if criatura is Creature:
			var creature_node := criatura as Creature
			creature_node.configurar(criatura_data)
			creature_node.configurar_chunk(chunk_coord, limite_chunk)
			creature_node.configurar_entorno("general")

		_spawned_characters[personaje_id] = criatura
		creados.append(criatura)

	if not creados.is_empty():
		_characters_by_chunk[chunk_coord] = creados
		print("WorldEntitySpawner: personajes en reino → chunk ", chunk_coord, " → ", creados.size())


func _spawn_props_in_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2,
	rng: RandomNumberGenerator
) -> void:
	var props := WorldData.obtener_props_game()
	if props.is_empty():
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var entities: Node = current_scene.get_node_or_null("Entities")
	if entities == null:
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
			datos_prop["asset_path"] = _construir_asset_path_prop(datos_prop)
			if datos_prop["asset_path"] == "":
				continue

			candidatos.append(datos_prop)

		if candidatos.is_empty():
			continue

		var elegido := _elegir_prop_ponderado(candidatos, rng)
		if elegido.is_empty():
			continue

		var prop_node: Node = preload("res://scenes/wold/world_prop.tscn").instantiate()
		if prop_node == null:
			continue

		entities.add_child(prop_node)
		prop_node.global_position = Vector2(
			(float(tile.x) + 0.5) * _terrain.tile_size,
			(float(tile.y) + 0.5) * _terrain.tile_size
		)

		if prop_node is WorldProp:
			var world_prop := prop_node as WorldProp
			world_prop.configurar_desde_game_data(elegido)
			world_prop.configurar_chunk(chunk_coord, limite_chunk)

		creados.append(prop_node)

	if not creados.is_empty():
		_props_by_chunk[chunk_coord] = creados
		print(
			"WorldEntitySpawner: props canonicos → chunk ",
			chunk_coord,
			" → ",
			creados.size()
		)


func _construir_asset_path_prop(prop: Dictionary) -> String:
	var nombre := str(prop.get("nombre", "")).strip_edges()
	if nombre.is_empty():
		return ""

	return "res://assets/art/props/" + nombre + ".png"


func _elegir_prop_ponderado(
	candidatos: Array[Dictionary],
	rng: RandomNumberGenerator
) -> Dictionary:
	var peso_total := 0.0

	for prop in candidatos:
		peso_total += maxf(float(prop.get("peso", 1.0)), 0.0)

	if peso_total <= 0.0:
		return {}

	var objetivo := rng.randf_range(0.0, peso_total)
	var acumulado := 0.0

	for prop in candidatos:
		acumulado += maxf(float(prop.get("peso", 1.0)), 0.0)
		if objetivo <= acumulado:
			return prop

	return candidatos.back()


func _buscar_tile_para_personaje(
	chunk_coord: Vector2i,
	bioma_ids: Array,
	rng: RandomNumberGenerator
) -> Vector2i:
	var origen_x := chunk_coord.x * _terrain.chunk_size_tiles
	var origen_y := chunk_coord.y * _terrain.chunk_size_tiles
	var candidatos: Array[Vector2i] = []

	for y in range(_terrain.chunk_size_tiles):
		for x in range(_terrain.chunk_size_tiles):
			var tile := Vector2i(origen_x + x, origen_y + y)
			if not _terrain.is_walkable(tile):
				continue

			var bioma := _terrain.get_bioma_at(tile)
			if bioma.is_empty():
				continue

			if str(bioma.get("id", "")) in bioma_ids:
				candidatos.append(tile)

	if candidatos.is_empty():
		return Vector2i(2147483647, 2147483647)

	return candidatos[rng.randi_range(0, candidatos.size() - 1)]


func _obtener_candidatos(
	ecosistema: Dictionary
) -> Array:
	var resultado: Array = []

	var habitats_variant: Variant = (
		ecosistema.get(
			"habitats",
			[]
		)
	)

	if not habitats_variant is Array:
		return resultado

	var habitats: Array = (
		habitats_variant
	)

	var vistos: Dictionary = {}

	for i in range(habitats.size()):
		var habitat_variant: Variant = (
			habitats[i]
		)

		if not habitat_variant is Dictionary:
			continue

		var habitat: Dictionary = (
			habitat_variant
		)

		var tipo_variant: Variant = (
			habitat.get(
				"tipo_habitat",
				{}
			)
		)

		var habitat_clave: String = (
			"general"
		)

		if tipo_variant is Dictionary:
			var tipo: Dictionary = (
				tipo_variant
			)

			habitat_clave = str(
				tipo.get(
					"clave",
					"general"
				)
			).to_lower()

		var criaturas_variant: Variant = (
			habitat.get(
				"criaturas",
				[]
			)
		)

		if not criaturas_variant is Array:
			continue

		var criaturas: Array = (
			criaturas_variant
		)

		for j in range(criaturas.size()):
			var criatura_variant: Variant = (
				criaturas[j]
			)

			if not criatura_variant is Dictionary:
				continue

			var criatura: Dictionary = (
				criatura_variant
			)

			var criatura_id: String = str(
				criatura.get(
					"id",
					""
				)
			)

			if criatura_id.is_empty():
				continue

			if vistos.has(
				criatura_id
			):
				continue

			vistos[criatura_id] = true

			resultado.append({
				"criatura": criatura,
				"habitat_clave": habitat_clave
			})

	return resultado


func _ubicacion_valida(
	bioma: Dictionary,
	habitat_clave: String,
	zona: int
) -> bool:
	var nombre_bioma: String = str(
		bioma.get(
			"nombre",
			""
		)
	).to_lower()

	var acuatico: bool = (
		"marino" in nombre_bioma
		or "agua dulce" in nombre_bioma
	)

	var tierra: bool = (
		zona != WorldTerrain.Zone.WATER
		and zona != WorldTerrain.Zone.DEEP_WATER
	)

	var agua: bool = not tierra

	if acuatico:
		match habitat_clave:
			"pelagico":
				return agua

			"bentonico":
				return agua

			"litoral":
				return agua

			"ribera":
				return tierra

			"aereo":
				return true

			"general":
				return true

			_:
				return agua

	match habitat_clave:
		"pelagico":
			return false

		"bentonico":
			return false

		"litoral":
			return false

		"aereo":
			return true

		_:
			return tierra
