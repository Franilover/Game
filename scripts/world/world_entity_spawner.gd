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

	if not creadas.is_empty():
		print(
			"WorldEntitySpawner: chunk ",
			chunk_coord,
			" → ",
			creadas.size(),
			" criaturas"
		)


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
