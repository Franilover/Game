extends RefCounted
class_name CombatDefense

## Resuelve defensa desde el estado de equipamiento recibido.
## No conoce InventoryController, UI ni nodos.

static func obtener_defensa(equipo: Dictionary) -> float:
	var defensa := 0.0

	for item_variant in equipo.values():
		if not item_variant is Dictionary:
			continue

		var item := item_variant as Dictionary
		var estadisticas_variant: Variant = item.get("estadisticas", {})
		if estadisticas_variant is Dictionary:
			defensa += maxf(float((estadisticas_variant as Dictionary).get("defensa", 0.0)), 0.0)
			continue

		defensa += maxf(float(item.get("defensa", 0.0)), 0.0)

	return defensa

static func aplicar(dano: int, defensa: float) -> int:
	var dano_base := maxi(dano, 0)
	if dano_base <= 0:
		return 0

	var defensa_real := maxf(defensa, 0.0)
	return maxi(0, ceili(float(dano_base) - defensa_real))
