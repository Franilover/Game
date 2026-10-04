extends RefCounted
class_name DiscoveryState

var creatures: Dictionary = {}
var biomes: Dictionary = {}
var ecosystems: Dictionary = {}
var habitats: Dictionary = {}
var explored_tiles: Dictionary = {}

func registrar_criatura(id: String) -> bool:
	if id.is_empty() or creatures.has(id):
		return false
	creatures[id] = true
	return true

func registrar_bioma(id: String) -> bool:
	if id.is_empty() or biomes.has(id):
		return false
	biomes[id] = true
	return true

func registrar_ecosistema(id: String) -> bool:
	if id.is_empty() or ecosystems.has(id):
		return false
	ecosystems[id] = true
	return true

func registrar_habitat(id: String) -> bool:
	if id.is_empty() or habitats.has(id):
		return false
	habitats[id] = true
	return true

func explorar(tile: Vector2i) -> bool:
	var key := str(tile.x) + "," + str(tile.y)
	if explored_tiles.has(key):
		return false
	explored_tiles[key] = true
	return true

func to_dictionary() -> Dictionary:
	return {
		"criaturas": creatures.duplicate(true),
		"biomas": biomes.duplicate(true),
		"ecosistemas": ecosystems.duplicate(true),
		"habitats": habitats.duplicate(true),
		"mapa_terreno_explorado": explored_tiles.duplicate(true)
	}

func from_dictionary(data: Dictionary) -> void:
	creatures = _copy_dictionary(data.get("criaturas", {}))
	biomes = _copy_dictionary(data.get("biomas", {}))
	ecosystems = _copy_dictionary(data.get("ecosistemas", {}))
	habitats = _copy_dictionary(data.get("habitats", {}))
	explored_tiles = _copy_dictionary(data.get("mapa_terreno_explorado", {}))

func _copy_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
