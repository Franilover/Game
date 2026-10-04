extends RefCounted
class_name PlayerState

## Estado persistible del jugador.
## No contiene nodos ni reglas de presentación.

var health: int = 100
var mana: int = 100
var stamina: float = 100.0
var position: Vector2 = Vector2.ZERO
var position_valida: bool = false
var tile: Vector2i = Vector2i.ZERO
var tile_valido: bool = false
var facing: Vector2 = Vector2.DOWN

func to_dictionary() -> Dictionary:
	return {
		"health": health,
		"mana": mana,
		"stamina": stamina,
		"position_valid": position_valida,
		"position": {"x": position.x, "y": position.y},
		"tile_valid": tile_valido,
		"tile": {"x": tile.x, "y": tile.y},
		"facing": {"x": facing.x, "y": facing.y}
	}

func from_dictionary(data: Dictionary) -> void:
	health = int(data.get("health", 100))
	mana = int(data.get("mana", 100))
	stamina = float(data.get("stamina", 100.0))
	position_valida = bool(data.get("position_valid", false))
	tile_valido = bool(data.get("tile_valid", false))

	var position_data: Variant = data.get("position", {})
	if position_data is Dictionary:
		position = Vector2(
			float((position_data as Dictionary).get("x", 0.0)),
			float((position_data as Dictionary).get("y", 0.0))
		)

	var tile_data: Variant = data.get("tile", {})
	if tile_data is Dictionary:
		tile = Vector2i(
			int((tile_data as Dictionary).get("x", 0)),
			int((tile_data as Dictionary).get("y", 0))
		)

	var facing_data: Variant = data.get("facing", {})
	if facing_data is Dictionary:
		facing = Vector2(
			float((facing_data as Dictionary).get("x", 0.0)),
			float((facing_data as Dictionary).get("y", 1.0))
		)
