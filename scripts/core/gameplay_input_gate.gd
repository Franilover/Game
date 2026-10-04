extends Node
class_name GameplayInputGate

## Compatibilidad para sistemas antiguos.
## La autoridad real vive en el autoload GameplayInputRouter.
## Este nodo NO mantiene estado ni decide qué sistema recibe input.

func _obtener_router() -> GameplayInputRouter:
	return get_tree().get_first_node_in_group("gameplay_input_router") as GameplayInputRouter


func esta_bloqueado() -> bool:
	var router := _obtener_router()
	if router == null or not is_instance_valid(router):
		return true
	return router.esta_bloqueado()


static func esta_entrada_bloqueada(arbol: SceneTree) -> bool:
	if arbol == null:
		return true
	var router := arbol.get_first_node_in_group("gameplay_input_router") as GameplayInputRouter
	if router == null or not is_instance_valid(router):
		return true
	return router.esta_entrada_bloqueada(arbol)
