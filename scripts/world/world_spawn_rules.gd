extends Node
class_name WorldSpawnRules

## Reglas puras de selección de entidades.
## No instancia nodos y no administra su ciclo de vida.

const CRIATURA_FLAXIS := 1 << 0
const CRIATURA_ZLISH := 1 << 1
const CRIATURA_LIGNIANOS := 1 << 2

var _terrain: WorldTerrain
var criaturas_destacadas: int = CRIATURA_FLAXIS | CRIATURA_ZLISH | CRIATURA_LIGNIANOS
var peso_normal: float = 1.0
var peso_destacadas: float = 4.0


func configurar(terrain: WorldTerrain) -> void:
	_terrain = terrain


func elegir_criatura(
	candidatos: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	var validos: Array = []
	for candidato_variant in candidatos:
		if not candidato_variant is Dictionary:
			continue
		var candidato := candidato_variant as Dictionary
		var criatura_variant: Variant = candidato.get("criatura", {})
		if not criatura_variant is Dictionary:
			continue
		var criatura := criatura_variant as Dictionary
		if str(criatura.get("id", "")).is_empty():
			continue
		validos.append(candidato)

	if validos.is_empty():
		return {}

	var peso_total := 0.0
	for candidato in validos:
		peso_total += maxf(obtener_peso_criatura(candidato), 0.0)

	if peso_total <= 0.0:
		return {}

	var objetivo := rng.randf_range(0.0, peso_total)
	var acumulado := 0.0
	for candidato in validos:
		var peso := maxf(obtener_peso_criatura(candidato), 0.0)
		acumulado += peso
		if objetivo <= acumulado:
			return candidato

	return validos.back()


func obtener_peso_criatura(candidato: Dictionary) -> float:
	var criatura_variant: Variant = candidato.get("criatura", {})
	if not criatura_variant is Dictionary:
		return peso_normal

	var nombre := str((criatura_variant as Dictionary).get("nombre", ""))
	match nombre:
		"Flaxis":
			if (criaturas_destacadas & CRIATURA_FLAXIS) != 0:
				return peso_destacadas
		"Zlish":
			if (criaturas_destacadas & CRIATURA_ZLISH) != 0:
				return peso_destacadas
		"Lignianos":
			if (criaturas_destacadas & CRIATURA_LIGNIANOS) != 0:
				return peso_destacadas

	return peso_normal


func obtener_candidatos(ecosistema: Dictionary) -> Array:
	var resultado: Array = []
	var habitats_variant: Variant = ecosistema.get("habitats", [])
	if not habitats_variant is Array:
		return resultado

	var vistos: Dictionary = {}
	for habitat_variant in habitats_variant:
		if not habitat_variant is Dictionary:
			continue

		var habitat := habitat_variant as Dictionary
		var tipo_variant: Variant = habitat.get("tipo_habitat", {})
		var habitat_clave := "general"
		if tipo_variant is Dictionary:
			habitat_clave = str((tipo_variant as Dictionary).get("clave", "general")).to_lower()

		var criaturas_variant: Variant = habitat.get("criaturas", [])
		if not criaturas_variant is Array:
			continue

		for criatura_variant in criaturas_variant:
			if not criatura_variant is Dictionary:
				continue
			var criatura := criatura_variant as Dictionary
			var criatura_id := str(criatura.get("id", ""))
			if criatura_id.is_empty() or vistos.has(criatura_id):
				continue
			vistos[criatura_id] = true
			resultado.append({
				"criatura": criatura,
				"habitat_clave": habitat_clave
			})

	return resultado


func ubicacion_valida(
	bioma: Dictionary,
	habitat_clave: String,
	zona: int
) -> bool:
	var nombre_bioma := str(bioma.get("nombre", "")).to_lower()
	var acuatico := "marino" in nombre_bioma or "agua dulce" in nombre_bioma
	var tierra := zona != WorldTerrain.Zone.WATER and zona != WorldTerrain.Zone.DEEP_WATER
	var agua := not tierra

	if acuatico:
		match habitat_clave:
			"pelagico", "bentonico", "litoral":
				return agua
			"ribera":
				return tierra
			"aereo", "general":
				return true
			_:
				return agua

	match habitat_clave:
		"pelagico", "bentonico", "litoral":
			return false
		"aereo":
			return true
		_:
			return tierra


func buscar_tile_para_personaje(
	chunk_coord: Vector2i,
	bioma_ids: Array,
	rng: RandomNumberGenerator
) -> Vector2i:
	if _terrain == null:
		return Vector2i(2147483647, 2147483647)

	var origen_x := chunk_coord.x * _terrain.chunk_size_tiles
	var origen_y := chunk_coord.y * _terrain.chunk_size_tiles
	var candidatos: Array[Vector2i] = []

	for y in range(_terrain.chunk_size_tiles):
		for x in range(_terrain.chunk_size_tiles):
			var tile := Vector2i(origen_x + x, origen_y + y)
			if not _terrain.is_walkable(tile):
				continue
			var bioma := _terrain.get_bioma_at(tile)
			if not bioma.is_empty() and str(bioma.get("id", "")) in bioma_ids:
				candidatos.append(tile)

	if candidatos.is_empty():
		return Vector2i(2147483647, 2147483647)

	return candidatos[rng.randi_range(0, candidatos.size() - 1)]


func elegir_prop(candidatos: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if candidatos.is_empty():
		return {}

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


func construir_asset_path_prop(prop: Dictionary) -> String:
	var nombre := str(prop.get("nombre", "")).strip_edges()
	if nombre.is_empty():
		return ""

	var candidatos: Array[String] = [
		"res://assets/art/props/" + nombre + ".png",
		"res://assets/art/props/" + quitar_acentos(nombre) + ".png"
	]

	var clave := str(prop.get("clave", "")).strip_edges()
	if not clave.is_empty():
		var clave_visual := clave.capitalize()
		candidatos.append("res://assets/art/props/" + clave_visual + ".png")
		candidatos.append("res://assets/art/props/" + quitar_acentos(clave_visual) + ".png")

	for ruta in candidatos:
		if FileAccess.file_exists(ruta):
			return ruta

	return ""


func quitar_acentos(texto: String) -> String:
	var resultado := texto
	resultado = resultado.replace("á", "a").replace("Á", "A")
	resultado = resultado.replace("é", "e").replace("É", "E")
	resultado = resultado.replace("í", "i").replace("Í", "I")
	resultado = resultado.replace("ó", "o").replace("Ó", "O")
	resultado = resultado.replace("ú", "u").replace("Ú", "U")
	return resultado.replace("ñ", "n").replace("Ñ", "N")
