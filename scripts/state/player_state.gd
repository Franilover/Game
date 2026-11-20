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
	var stamina_guardada := float(data.get("stamina", 3.0))
	# Compatibilidad con partidas antiguas que guardaban stamina en escala 0..100.
	if stamina_guardada > 3.0:
		stamina = clampf(stamina_guardada / 100.0 * 3.0, 0.0, 3.0)
	else:
		stamina = clampf(stamina_guardada, 0.0, 3.0)
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

## Limita las reservas a las capacidades runtime.
## En fisiología compartida conserva la menor reserva para no conceder
## salud o Eterium extra cuando un save antiguo/corrupto contiene valores distintos.
func normalizar_reservas_vitales(
	max_health: int,
	max_mana: int,
	vida_eterium_compartidos: bool
) -> Dictionary:
	var vida_segura := clampi(health, 0, maxi(max_health, 0))
	var mana_seguro := clampi(mana, 0, maxi(max_mana, 0))
	if vida_eterium_compartidos:
		var reserva_compartida := mini(vida_segura, mana_seguro)
		vida_segura = reserva_compartida
		mana_seguro = reserva_compartida
	return {"health": vida_segura, "mana": mana_seguro}
