extends RefCounted
class_name PlayerExplorationController

## Detecta cambios de terreno y obtiene el descubrimiento asociado.
## No conoce GameState, guardado ni UI.

signal terreno_descubierto(tile: Vector2i, descubrimiento: Dictionary)

var ultima_tile: Vector2i = Vector2i(2147483647, 2147483647)

func revisar(posicion: Vector2, world_context: Node) -> bool:
	if world_context == null or not is_instance_valid(world_context):
		return false
	if not world_context.has_method("get_tile_at"):
		return false

	var tile_variant: Variant = world_context.call("get_tile_at", posicion)
	if not tile_variant is Vector2i:
		return false

	var tile := tile_variant as Vector2i
	if tile == ultima_tile:
		return false

	ultima_tile = tile

	var descubrimiento := obtener_descubrimiento(world_context, tile)
	terreno_descubierto.emit(tile, descubrimiento)
	return true

func reiniciar() -> void:
	ultima_tile = Vector2i(2147483647, 2147483647)

func obtener_descubrimiento(world_context: Node, tile: Vector2i) -> Dictionary:
	var resultado := {
		"bioma": {},
		"ecosistema": {},
		"habitats": [],
		"criaturas": []
	}

	if world_context == null or not is_instance_valid(world_context):
		return resultado

	if world_context.has_method("get_bioma_at"):
		var bioma: Variant = world_context.call("get_bioma_at", tile)
		if bioma is Dictionary:
			resultado["bioma"] = (bioma as Dictionary).duplicate(true)

	if world_context.has_method("get_ecosistema_at"):
		var ecosistema: Variant = world_context.call("get_ecosistema_at", tile)
		if ecosistema is Dictionary:
			resultado["ecosistema"] = (ecosistema as Dictionary).duplicate(true)

	if world_context.has_method("get_habitats_at"):
		var habitats: Variant = world_context.call("get_habitats_at", tile)
		if habitats is Array:
			resultado["habitats"] = (habitats as Array).duplicate(true)

	if world_context.has_method("get_criaturas_at"):
		var criaturas: Variant = world_context.call("get_criaturas_at", tile)
		if criaturas is Array:
			resultado["criaturas"] = (criaturas as Array).duplicate(true)

	return resultado
