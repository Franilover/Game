extends RefCounted
class_name CombatFeedback

## Presentación de resultados de combate.
## Esta capa no modifica vida, inventario ni objetivos.

static func impacto(_objetivo: Node, _cantidad: int) -> void:
	pass

static func muerte(_objetivo: Node) -> void:
	pass
