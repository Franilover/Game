extends RefCounted
class_name WorldTerrainAreas


var map_seed: int = 0
var _biomas: Array = []
var _ecosistemas: Array = []
var _ecosistema_indices: Dictionary = {}
var _bioma_ecosistemas: Array = []
var _biome_noise: FastNoiseLite
var _ecosystem_noise: FastNoiseLite
var _terrain_noise: FastNoiseLite


const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]


# Supabase define los nombres canónicos. Godot sólo traduce esos nombres
# a los índices visuales que entiende el TileMapDual.
const TERRENO_A_ZONA: Dictionary = {
	"grass": 0,
	"dirt": 1,
	"stone": 2,
	"sand": 3,
	"water": 4,
	"deep_water": 5,
	"shore": 6,
	"ice": 7,
	"forest": 8,
	"desert": 9,
}


func configurar(nuevo_seed: int) -> void:
	map_seed = nuevo_seed

	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = map_seed + 1001
	_biome_noise.frequency = 0.006

	_ecosystem_noise = FastNoiseLite.new()
	_ecosystem_noise.seed = map_seed + 2002
	_ecosystem_noise.frequency = 0.020

	_terrain_noise = FastNoiseLite.new()
	_terrain_noise.seed = map_seed + 3003
	_terrain_noise.frequency = 0.045


func cargar_datos(
	biomas: Array,
	ecosistemas: Array,
	ecosistema_indices: Dictionary
) -> void:
	_biomas = biomas
	_ecosistemas = ecosistemas
	_ecosistema_indices = ecosistema_indices
	_bioma_ecosistemas = []

	for bioma_variant in _biomas:
		var indices: Array[int] = []

		if bioma_variant is Dictionary:
			var ecosistemas_variant: Variant = (
				bioma_variant.get("ecosistemas", [])
			)

			if ecosistemas_variant is Array:
				for ecosistema_variant in ecosistemas_variant:
					if not ecosistema_variant is Dictionary:
						continue

					var id := str(
						(ecosistema_variant as Dictionary).get(
							"id",
							""
						)
					)

					var indice := int(
						_ecosistema_indices.get(id, -1)
					)

					if indice >= 0:
						indices.append(indice)

		_bioma_ecosistemas.append(indices)


func bioma_index_at_tile(tile: Vector2i) -> int:
	if _biomas.is_empty() or _biome_noise == null:
		return -1

	var valor := (
		_biome_noise.get_noise_2d(tile.x, tile.y)
		+ 1.0
	) * 0.5

	var pesos: Array[float] = []
	var total_peso := 0.0

	for bioma_variant in _biomas:
		var peso := 0.0

		if bioma_variant is Dictionary:
			var generacion_variant: Variant = (
				(bioma_variant as Dictionary).get(
					"generacion",
					{}
				)
			)

			if generacion_variant is Dictionary:
				peso = maxf(
					float(
						(generacion_variant as Dictionary).get(
							"peso",
							0.0
						)
					),
					0.0
				)

		pesos.append(peso)
		total_peso += peso

	if total_peso <= 0.0:
		return 0

	var acumulado := 0.0

	for indice in range(pesos.size()):
		var peso_normalizado := (
			pesos[indice] / total_peso
		)

		acumulado += peso_normalizado

		if valor < acumulado:
			return indice

	return pesos.size() - 1


func ecosistema_index_at_tile(
	tile: Vector2i,
	bioma_index: int
) -> int:
	if (
		bioma_index < 0
		or bioma_index >= _bioma_ecosistemas.size()
	):
		return -1

	var indices: Array = _bioma_ecosistemas[bioma_index]

	if indices.is_empty() or _ecosystem_noise == null:
		return -1

	var normalizado := (
		_ecosystem_noise.get_noise_2d(tile.x, tile.y)
		+ 1.0
	) * 0.5

	var local_index := clampi(
		floori(normalizado * indices.size()),
		0,
		indices.size() - 1
	)

	return int(indices[local_index])


func zona_base_at_tile(
	tile: Vector2i,
	bioma_index: int,
	ecosistema_index: int
) -> int:
	if _terrain_noise == null:
		return 0

	var terreno_ruido := _terrain_noise.get_noise_2d(
		tile.x,
		tile.y
	)

	# Primero manda el ecosistema si tiene una configuración propia.
	# Si no, manda la configuración del bioma.
	var generacion := _obtener_generacion_ecosistema(
		ecosistema_index
	)

	if generacion.is_empty():
		generacion = _obtener_generacion_bioma(
			bioma_index
		)

	return _zona_desde_generacion(
		generacion,
		terreno_ruido
	)


func _obtener_generacion_bioma(
	bioma_index: int
) -> Dictionary:
	if (
		bioma_index < 0
		or bioma_index >= _biomas.size()
	):
		return {}

	var bioma_variant: Variant = _biomas[bioma_index]

	if not bioma_variant is Dictionary:
		return {}

	var generacion_variant: Variant = (
		(bioma_variant as Dictionary).get(
			"generacion",
			{}
		)
	)

	if generacion_variant is Dictionary:
		return generacion_variant as Dictionary

	return {}


func _obtener_generacion_ecosistema(
	ecosistema_index: int
) -> Dictionary:
	if (
		ecosistema_index < 0
		or ecosistema_index >= _ecosistemas.size()
	):
		return {}

	var ecosistema_variant: Variant = (
		_ecosistemas[ecosistema_index]
	)

	if not ecosistema_variant is Dictionary:
		return {}

	var generacion_variant: Variant = (
		(ecosistema_variant as Dictionary).get(
			"generacion",
			{}
		)
	)

	if not generacion_variant is Dictionary:
		return {}

	var generacion := (
		generacion_variant as Dictionary
	)

	var zonas_variant: Variant = generacion.get(
		"zonas",
		[]
	)

	if zonas_variant is Array and not zonas_variant.is_empty():
		return generacion

	return {}


func _zona_desde_generacion(
	generacion: Dictionary,
	valor_ruido: float
) -> int:
	var zonas_variant: Variant = generacion.get(
		"zonas",
		[]
	)

	if not zonas_variant is Array:
		return 0

	for zona_variant in zonas_variant:
		if not zona_variant is Dictionary:
			continue

		var zona_config := (
			zona_variant as Dictionary
		)

		var hasta := float(
			zona_config.get(
				"hasta",
				1.0
			)
		)

		if valor_ruido <= hasta:
			var terreno := str(
				zona_config.get(
					"terreno",
					"grass"
				)
			).to_lower()

			return int(
				TERRENO_A_ZONA.get(
					terreno,
					0
				)
			)

	return 0


func zona_final_desde_array(
	zonas: Array,
	x: int,
	y: int,
	zona_base: int
) -> int:
	if zona_base != 4 and zona_base != 5:
		return zona_base

	if agua_toca_tierra_en_array(
		zonas,
		x,
		y
	):
		return 6

	return zona_base


func agua_toca_tierra_en_array(
	zonas: Array,
	x: int,
	y: int
) -> bool:
	for direccion: Vector2i in ORTHOGONAL_DIRECTIONS:
		var nx: int = x + direccion.x
		var ny: int = y + direccion.y

		if (
			ny < 0
			or ny >= zonas.size()
			or nx < 0
			or nx >= zonas[ny].size()
		):
			continue

		var vecino := int(
			zonas[ny][nx]
		)

		if vecino != 4 and vecino != 5:
			return true

	return false
