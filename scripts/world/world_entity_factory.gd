extends Node
class_name WorldEntityFactory

const CREATURE_SCENE: PackedScene = preload("res://scenes/creatures/creature.tscn")
const WORLD_PROP_SCENE: PackedScene = preload("res://scenes/world/world_prop.tscn")


func crear_criatura(data: Dictionary) -> Creature:
	var node := CREATURE_SCENE.instantiate() as Creature
	if node == null:
		push_error("WorldEntityFactory: no se pudo crear Creature.")
		return null
	return node


func crear_personaje(
	data: Dictionary,
	dialogo: Array = []
) -> Creature:
	var criatura_data := data.duplicate(true)
	if not dialogo.is_empty():
		criatura_data["dialogo"] = dialogo
	else:
		criatura_data.erase("dialogo")

	return crear_criatura(criatura_data)


func crear_prop(data: Dictionary) -> WorldProp:
	var node := WORLD_PROP_SCENE.instantiate() as WorldProp
	if node == null:
		push_error("WorldEntityFactory: no se pudo crear WorldProp.")
		return null
	return node
