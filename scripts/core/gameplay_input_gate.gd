extends Node
class_name GameplayInputGate

## Compatibilidad para sistemas antiguos.
## La autoridad real vive en GameplayInputRouter.
## Este nodo NO mantiene estado ni decide qué sistema recibe input.

func esta_bloqueado() -> bool:
	return GameplayInputRouter.esta_entrada_bloqueada(get_tree())


static func esta_entrada_bloqueada(arbol: SceneTree) -> bool:
	return GameplayInputRouter.esta_entrada_bloqueada(arbol)
