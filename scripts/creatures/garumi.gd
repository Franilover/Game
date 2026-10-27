extends Creature
class_name Garumi


## Categoría de entidad independiente. La forma física y el comportamiento
## específico de cada linaje se resuelven en datos/recursos propios.
## Esta base comparte únicamente movimiento y presentación con Creature.
## Los Garumis no son criaturas ecológicas normales ni mueren por daño común.
func _ready() -> void:
	super._ready()
	_normalizar_grupos_garumi()


func configurar(datos_garumi: Dictionary) -> void:
	var datos_separados := datos_garumi.duplicate(true)
	datos_separados["categoria_entidad"] = "garumi"
	if not datos_separados.has("asset_key"):
		datos_separados["asset_key"] = str(datos_separados.get("nombre", ""))
	super.configurar(datos_separados)


func activar_como_proxy() -> void:
	super.activar_como_proxy()
	_normalizar_grupos_garumi()


func _normalizar_grupos_garumi() -> void:
	remove_from_group("creatures")
	remove_from_group("damageable")
	add_to_group("garumis")


## El daño normal no puede matar a un Garumi. El sistema específico de
## absorción por Necromancers deberá usar una operación explícita separada.
func take_damage(_cantidad: int, _origen: String = "desconocido") -> void:
	return


func es_garumi() -> bool:
	return true
