extends RefCounted
class_name WorldTerrainAreas


var map_seed: int = 0
var _biomas: Array = []
var _ecosistemas: Array = []
var _ecosistema_indices: Dictionary = {}
var _bioma_ecosistemas: Array = []
var _biome_noises: Array[FastNoiseLite] = []
var _ecosystem_noises: Array[FastNoiseLite] = []
var _terrain_noise: FastNoiseLite
var _biome_bias: PackedFloat32Array = PackedFloat32Array()
var _ecosystem_bias: PackedFloat32Array = PackedFloat32Array()
var _biome_generation: Array[Dictionary] = []
var _ecosystem_generation: Array[Dictionary] = []
var _biome_enabled: PackedByteArray = PackedByteArray()
var _ecosystem_enabled: PackedByteArray = PackedByteArray()
var _biome_zone_thresholds: Array[PackedFloat32Array] = []
var _biome_zone_values: Array[PackedInt32Array] = []
var _biome_zone_fallbacks: PackedInt32Array = PackedInt32Array()
var _ecosystem_zone_thresholds: Array[PackedFloat32Array] = []
var _ecosystem_zone_values: Array[PackedInt32Array] = []
var _ecosystem_zone_fallbacks: PackedInt32Array = PackedInt32Array()


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

	_biome_noises.clear()
	_ecosystem_noises.clear()
	_biome_bias = PackedFloat32Array()
	_ecosystem_bias = PackedFloat32Array()
	_biome_generation.clear()
	_ecosystem_generation.clear()
	_biome_enabled = PackedByteArray()
	_ecosystem_enabled = PackedByteArray()
	_biome_zone_thresholds.clear()
	_biome_zone_values.clear()
	_biome_zone_fallbacks = PackedInt32Array()
	_ecosystem_zone_thresholds.clear()
	_ecosystem_zone_values.clear()
	_ecosystem_zone_fallbacks = PackedInt32Array()
	for indice in range(_biomas.size()):
		var generacion := _obtener_generacion_bioma(indice)
		var biome_noise := FastNoiseLite.new()
		biome_noise.seed = map_seed + 1001 + indice * 7919
		biome_noise.frequency = _frecuencia_ruido(generacion, 0.006)
		_biome_noises.append(biome_noise)
		_biome_generation.append(generacion)
		var peso := _peso_bioma(indice)
		_biome_enabled.append(1 if peso > 0.0 else 0)
		_biome_bias.append(log(maxf(peso, 0.000001)) * 0.35)
		var zonas_compiladas := _compilar_zonas(generacion)
		_biome_zone_thresholds.append(zonas_compiladas["thresholds"])
		_biome_zone_values.append(zonas_compiladas["values"])
		_biome_zone_fallbacks.append(int(zonas_compiladas["fallback"]))

	for indice in range(_ecosistemas.size()):
		var generacion := _obtener_generacion_ecosistema(indice)
		var ecosystem_noise := FastNoiseLite.new()
		ecosystem_noise.seed = map_seed + 2002 + indice * 6151
		ecosystem_noise.frequency = _frecuencia_ruido(generacion, 0.014)
		_ecosystem_noises.append(ecosystem_noise)
		_ecosystem_generation.append(generacion)
		var peso := _peso_ecosistema(indice)
		_ecosystem_enabled.append(1 if peso > 0.0 else 0)
		_ecosystem_bias.append(log(maxf(peso, 0.000001)) * 0.35)
		var zonas_compiladas := _compilar_zonas(generacion)
		_ecosystem_zone_thresholds.append(zonas_compiladas["thresholds"])
		_ecosystem_zone_values.append(zonas_compiladas["values"])
		_ecosystem_zone_fallbacks.append(int(zonas_compiladas["fallback"]))

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
	if _biomas.is_empty() or _biome_noises.size() != _biomas.size():
		return -1

	# Cada bioma tiene su propio campo de ruido. Elegir el máximo
	# ponderado evita el error anterior: usar un único ruido con
	# umbrales acumulados convertía los pesos en anillos concéntricos.
	var mejor_indice := 0
	var mejor_puntuacion := -INF

	for indice in range(_biomas.size()):
		if _biome_enabled[indice] == 0:
			continue

		var ruido := (
			_biome_noises[indice].get_noise_2d(
				tile.x,
				tile.y
			)
			+ 1.0
		) * 0.5

		# El peso de Supabase actúa como sesgo de selección, mientras
		# que el ruido independiente mantiene regiones espaciales suaves.
		var puntuacion := ruido + _biome_bias[indice]

		if puntuacion > mejor_puntuacion:
			mejor_puntuacion = puntuacion
			mejor_indice = indice

	return mejor_indice


func _frecuencia_ruido(generacion: Dictionary, fallback: float) -> float:
	var ruido_variant: Variant = generacion.get("ruido", {})
	if not ruido_variant is Dictionary:
		return fallback

	var frecuencia := float((ruido_variant as Dictionary).get("frecuencia", fallback))
	if frecuencia <= 0.0:
		return fallback

	return frecuencia


func _peso_bioma(indice: int) -> float:
	if indice < 0 or indice >= _biomas.size():
		return 0.0

	var bioma_variant: Variant = _biomas[indice]
	if not bioma_variant is Dictionary:
		return 0.0

	var generacion_variant: Variant = (
		(bioma_variant as Dictionary).get(
			"generacion",
			{}
		)
	)

	# Los snapshots antiguos pueden no incluir todavía la configuración
	# de generación. En ese caso los biomas siguen participando por igual;
	# sólo un peso explícito de cero desactiva un bioma.
	if not generacion_variant is Dictionary:
		return 1.0

	var generacion := generacion_variant as Dictionary
	if not generacion.has("peso"):
		return 1.0

	return maxf(float(generacion.get("peso", 1.0)), 0.0)


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
	if indices.is_empty():
		return -1

	# Cada ecosistema tiene su propio campo espacial. Un único ruido
	# dividido por índices producía bandas que dependían del orden
	# de los registros en Supabase, no de sus identidades.
	var mejor_indice := -1
	var mejor_puntuacion := -INF

	for indice_variant in indices:
		var indice := int(indice_variant)
		if indice < 0 or indice >= _ecosistemas.size():
			continue
		if indice >= _ecosystem_noises.size():
			continue

		if _ecosystem_enabled[indice] == 0:
			continue

		var ruido := (
			_ecosystem_noises[indice].get_noise_2d(
				tile.x,
				tile.y
			)
			+ 1.0
		) * 0.5
		var puntuacion := ruido + _ecosystem_bias[indice]

		if puntuacion > mejor_puntuacion:
			mejor_puntuacion = puntuacion
			mejor_indice = indice

	return mejor_indice


func _peso_ecosistema(indice: int) -> float:
	if indice < 0 or indice >= _ecosistemas.size():
		return 0.0

	var ecosistema_variant: Variant = _ecosistemas[indice]
	if not ecosistema_variant is Dictionary:
		return 0.0

	var generacion_variant: Variant = (
		(ecosistema_variant as Dictionary).get(
			"generacion",
			{}
		)
	)
	if not generacion_variant is Dictionary:
		return 1.0

	var generacion := generacion_variant as Dictionary
	if not generacion.has("peso"):
		return 1.0

	return maxf(float(generacion.get("peso", 1.0)), 0.0)


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
	if ecosistema_index >= 0 and ecosistema_index < _ecosystem_zone_thresholds.size():
		if not _ecosystem_zone_thresholds[ecosistema_index].is_empty():
			return _zona_desde_compilacion(
				_ecosystem_zone_thresholds[ecosistema_index],
				_ecosystem_zone_values[ecosistema_index],
				_ecosystem_zone_fallbacks[ecosistema_index],
				terreno_ruido
			)

	if bioma_index >= 0 and bioma_index < _biome_zone_thresholds.size():
		return _zona_desde_compilacion(
			_biome_zone_thresholds[bioma_index],
			_biome_zone_values[bioma_index],
			_biome_zone_fallbacks[bioma_index],
			terreno_ruido
		)

	return 0


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


func _compilar_zonas(generacion: Dictionary) -> Dictionary:
	var thresholds := PackedFloat32Array()
	var values := PackedInt32Array()
	var fallback_hasta := -INF
	var fallback_zona := 0

	var zonas_variant: Variant = generacion.get("zonas", [])
	if not zonas_variant is Array:
		return {
			"thresholds": thresholds,
			"values": values,
			"fallback": fallback_zona
		}

	for zona_variant in zonas_variant:
		if not zona_variant is Dictionary:
			continue

		var zona_config := zona_variant as Dictionary
		var hasta := clampf(
			float(zona_config.get("hasta", 1.0)),
			-1.0,
			1.0
		)
		var terreno := str(
			zona_config.get("terreno", "grass")
		).to_lower()
		var zona := int(TERRENO_A_ZONA.get(terreno, 0))

		thresholds.append(hasta)
		values.append(zona)

		if hasta > fallback_hasta:
			fallback_hasta = hasta
			fallback_zona = zona

	return {
		"thresholds": thresholds,
		"values": values,
		"fallback": fallback_zona
	}


func _zona_desde_compilacion(
	thresholds: PackedFloat32Array,
	values: PackedInt32Array,
	fallback_zona: int,
	valor_ruido: float
) -> int:
	var mejor_hasta := INF
	var mejor_zona := 0

	for indice in range(thresholds.size()):
		var hasta := thresholds[indice]
		if hasta >= valor_ruido and hasta < mejor_hasta:
			mejor_hasta = hasta
			mejor_zona = values[indice]

	if mejor_hasta == INF:
		return fallback_zona

	return mejor_zona


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

	var mejor_config: Dictionary = {}
	var mejor_hasta := INF
	var config_mayor: Dictionary = {}
	var umbral_mayor := -INF

	for zona_variant in zonas_variant:
		if not zona_variant is Dictionary:
			continue

		var zona_config := zona_variant as Dictionary
		var hasta := clampf(
			float(zona_config.get("hasta", 1.0)),
			-1.0,
			1.0
		)

		if hasta > umbral_mayor:
			umbral_mayor = hasta
			config_mayor = zona_config

		# No dependemos del orden en que Supabase devuelva los registros:
		# se escoge el primer límite que cubre el valor de ruido.
		if hasta >= valor_ruido and hasta < mejor_hasta:
			mejor_hasta = hasta
			mejor_config = zona_config

	if mejor_config.is_empty():
		mejor_config = config_mayor
	if mejor_config.is_empty():
		return 0

	var terreno := str(
		mejor_config.get("terreno", "grass")
	).to_lower()

	return int(TERRENO_A_ZONA.get(terreno, 0))


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
