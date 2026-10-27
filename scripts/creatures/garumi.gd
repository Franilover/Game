extends Creature
class_name Garumi


## Categoría de entidad independiente. La forma física y el comportamiento
## específico de cada linaje se resuelven en datos/recursos propios.
## Esta base comparte únicamente movimiento, salud y presentación con Creature.
func configurar(datos_garumi: Dictionary) -> void:
	var datos_separados := datos_garumi.duplicate(true)
	datos_separados["categoria_entidad"] = "garumi"
	if not datos_separados.has("asset_key"):
		datos_separados["asset_key"] = str(datos_separados.get("nombre", ""))
	super.configurar(datos_separados)


func es_garumi() -> bool:
	return true
