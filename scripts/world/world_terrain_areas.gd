extends RefCounted
class_name WorldTerrainAreas

enum BiomeKind {
	OTHER,
	MARINO,
	AGUA_DULCE,
	HUMEDAL,
	DESIERTO,
	MONTANA,
	TUNDRA,
	PRADERA
}

var map_seed: int = 0
var _biomas: Array = []
var _ecosistemas: Array = []
var _ecosistema_indices: Dictionary = {}
var _bioma_kinds: PackedInt32Array = PackedInt32Array()
var _ecosistema_nombres: PackedStringArray = PackedStringArray()
var _bioma_ecosistemas: Array = []
var _biome_noise: FastNoiseLite
var _ecosystem_noise: FastNoiseLite
var _terrain_noise: FastNoiseLite

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

func cargar_datos(biomas: Array, ecosistemas: Array, ecosistema_indices: Dictionary) -> void:
	_biomas = biomas
	_ecosistemas = ecosistemas
	_ecosistema_indices = ecosistema_indices
	_bioma_kinds = PackedInt32Array()
	_ecosistema_nombres = PackedStringArray()
	_bioma_ecosistemas = []

	for ecosistema_variant in _ecosistemas:
		if ecosistema_variant is Dictionary:
			_ecosistema_nombres.append(str(ecosistema_variant.get("nombre", "")).to_lower())
		else:
			_ecosistema_nombres.append("")

	for bioma_variant in _biomas:
		var nombre := ""
		if bioma_variant is Dictionary:
			nombre = str(bioma_variant.get("nombre", "")).to_lower()
		_bioma_kinds.append(_clasificar_bioma(nombre))

		var indices: Array[int] = []
		if bioma_variant is Dictionary:
			var ecosistemas_variant: Variant = bioma_variant.get("ecosistemas", [])
			if ecosistemas_variant is Array:
				for ecosistema_variant in ecosistemas_variant:
					if not ecosistema_variant is Dictionary:
						continue
					var id := str(ecosistema_variant.get("id", ""))
					var indice := int(_ecosistema_indices.get(id, -1))
					if indice >= 0:
						indices.append(indice)
		_bioma_ecosistemas.append(indices)

func bioma_index_at_tile(tile: Vector2i) -> int:
	if _biomas.is_empty() or _biome_noise == null:
		return -1
	var normalizado := (_biome_noise.get_noise_2d(tile.x, tile.y) + 1.0) * 0.5
	return clampi(floori(normalizado * _biomas.size()), 0, _biomas.size() - 1)

func ecosistema_index_at_tile(tile: Vector2i, bioma_index: int) -> int:
	if bioma_index < 0 or bioma_index >= _bioma_ecosistemas.size():
		return -1
	var indices: Array = _bioma_ecosistemas[bioma_index]
	if indices.is_empty() or _ecosystem_noise == null:
		return -1
	var normalizado := (_ecosystem_noise.get_noise_2d(tile.x, tile.y) + 1.0) * 0.5
	var local_index := clampi(floori(normalizado * indices.size()), 0, indices.size() - 1)
	return int(indices[local_index])

func zona_base_at_tile(tile: Vector2i, bioma_index: int, ecosistema_index: int) -> int:
	if _terrain_noise == null:
		return 0

	var terreno := _terrain_noise.get_noise_2d(tile.x, tile.y)
	var kind := BiomeKind.OTHER
	if bioma_index >= 0 and bioma_index < _bioma_kinds.size():
		kind = int(_bioma_kinds[bioma_index])

	var ecosistema_nombre := ""
	if ecosistema_index >= 0 and ecosistema_index < _ecosistema_nombres.size():
		ecosistema_nombre = _ecosistema_nombres[ecosistema_index]

	match kind:
		BiomeKind.MARINO:
			if "profundo" in ecosistema_nombre or terreno < -0.20:
				return 5
			return 4
		BiomeKind.AGUA_DULCE:
			if terreno < -0.35:
				return 5
			return 4
		BiomeKind.HUMEDAL:
			if terreno < -0.30:
				return 4
			if terreno < 0.10:
				return 1
			return 0
		BiomeKind.DESIERTO:
			if terreno > 0.65:
				return 2
			return 3
		BiomeKind.MONTANA:
			if terreno > 0.30:
				return 2
			return 0
		BiomeKind.TUNDRA:
			if terreno > 0.30:
				return 2
			return 7
		BiomeKind.PRADERA:
			if terreno < -0.35:
				return 1
			return 0
		_:
			if terreno > 0.65:
				return 2
			if terreno < -0.45:
				return 1
			return 0

func zona_final_desde_array(zonas: Array, x: int, y: int, zona_base: int) -> int:
	if zona_base != 4 and zona_base != 5:
		return zona_base
	if agua_toca_tierra_en_array(zonas, x, y):
		return 6
	return zona_base

func agua_toca_tierra_en_array(zonas: Array, x: int, y: int) -> bool:
	var direcciones: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	for direccion: Vector2i in direcciones:
		var nx: int = x + direccion.x
		var ny: int = y + direccion.y
		if ny < 0 or ny >= zonas.size() or nx < 0 or nx >= zonas[ny].size():
			continue
		var vecino := int(zonas[ny][nx])
		if vecino != 4 and vecino != 5:
			return true
	return false

func _clasificar_bioma(nombre: String) -> int:
	if "marino" in nombre:
		return BiomeKind.MARINO
	if "agua dulce" in nombre:
		return BiomeKind.AGUA_DULCE
	if "humedal" in nombre:
		return BiomeKind.HUMEDAL
	if "desierto" in nombre:
		return BiomeKind.DESIERTO
	if "montaña" in nombre:
		return BiomeKind.MONTANA
	if "tundra" in nombre:
		return BiomeKind.TUNDRA
	if "pradera" in nombre:
		return BiomeKind.PRADERA
	return BiomeKind.OTHER
