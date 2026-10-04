extends Node
class_name GameplayInputGate

## Compatibilidad para sistemas antiguos.
## La autoridad real vive en el autoload GameplayInputRouter.
## Este nodo NO mantiene estado ni decide qué sistema recibe input.

func esta_bloqueado() -> bool:
	return GameplayInputRouterSingleton.esta_bloqueado(get_tree())


static func esta_entrada_bloqueada(arbol: SceneTree) -> bool:
	var router := arbol.root.get_node_or_null("GameplayInputRouter")
	if router == null:
		return true
	return bool(router.call("esta_entrada_bloqueada", arbol))
