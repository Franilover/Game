extends RefCounted
class_name CombatDefense

## Resuelve defensa desde el estado de equipamiento recibido.
## No conoce InventoryController, UI ni nodos.

static func obtener_defensa(equipo: Dictionary) -> float:
	var defensa := 0.0
	for slot_variant in equipo.keys():
		# Sólo las tres ranuras de armadura contribuyen a la defensa.
		# Entradas antiguas de armas/manos no deben convertirse en blindaje.
		if str(slot_variant) not in ["cabeza", "torso", "pies"]:
			continue
		var item_variant: Variant = equipo.get(slot_variant, {})
		if not item_variant is Dictionary:
			continue
		defensa += _obtener_defensa_objeto(item_variant as Dictionary)
	return defensa


static func _obtener_defensa_objeto(item: Dictionary) -> float:
	var estadisticas_variant: Variant = item.get("estadisticas", {})
	if estadisticas_variant is Dictionary:
		var estadisticas := estadisticas_variant as Dictionary
		if estadisticas.has("defensa"):
			return maxf(_numero_no_negativo(estadisticas.get("defensa")), 0.0)

	var propiedades_variant: Variant = item.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		if propiedades.has("defensa"):
			return maxf(_numero_no_negativo(propiedades.get("defensa")), 0.0)
		var estadisticas_propiedades: Variant = propiedades.get("estadisticas", {})
		if estadisticas_propiedades is Dictionary:
			var internas := estadisticas_propiedades as Dictionary
			if internas.has("defensa"):
				return maxf(_numero_no_negativo(internas.get("defensa")), 0.0)

	return maxf(_numero_no_negativo(item.get("defensa", 0.0)), 0.0)


static func _numero_no_negativo(valor: Variant) -> float:
	if valor is int or valor is float:
		return maxf(float(valor), 0.0)
	return 0.0

static func aplicar(dano: int, defensa: float) -> int:
	var dano_base := maxi(dano, 0)
	if dano_base <= 0:
		return 0

	var defensa_real := maxf(defensa, 0.0)
	return maxi(0, ceili(float(dano_base) - defensa_real))
