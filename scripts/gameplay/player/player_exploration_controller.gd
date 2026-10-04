extends RefCounted
class_name PlayerExplorationController

## Coordina el descubrimiento del mundo desde la posición del jugador.
## El generador sigue siendo la fuente de información del terreno.

var ultima_tile: Vector2i = Vector2i(2147483647, 2147483647)

func revisar(posicion: Vector2, world_generator: Node) -> bool:
	if world_generator == null or not is_instance_valid(world_generator):
		return false
	if not world_generator.has_method("get_tile_at"):
		return false

	var tile_variant: Variant = world_generator.call("get_tile_at", posicion)
	if not tile_variant is Vector2i:
		return false

	var tile := tile_variant as Vector2i
	if tile == ultima_tile:
		return false

	ultima_tile = tile
	return true

func registrar_en_game_state(tile: Vector2i) -> void:
	GameState.registrar_terreno_explorado(tile)

func obtener_descubrimiento(world_generator: Node, tile: Vector2i) -> Dictionary:
	var resultado := {
		"bioma": {},
		"ecosistema": {},
		"habitats": [],
		"criaturas": []
	}

	if world_generator == null or not is_instance_valid(world_generator):
		return resultado

	if world_generator.has_method("get_bioma_at"):
		var bioma: Variant = world_generator.call("get_bioma_at", tile)
		if bioma is Dictionary:
			resultado["bioma"] = (bioma as Dictionary).duplicate(true)

	if world_generator.has_method("get_ecosistema_at"):
		var ecosistema: Variant = world_generator.call("get_ecosistema_at", tile)
		if ecosistema is Dictionary:
			resultado["ecosistema"] = (ecosistema as Dictionary).duplicate(true)

	if world_generator.has_method("get_habitats_at"):
		var habitats: Variant = world_generator.call("get_habitats_at", tile)
		if habitats is Array:
			resultado["habitats"] = (habitats as Array).duplicate(true)

	if world_generator.has_method("get_criaturas_at"):
		var criaturas: Variant = world_generator.call("get_criaturas_at", tile)
		if criaturas is Array:
			resultado["criaturas"] = (criaturas as Array).duplicate(true)

	return resultado
