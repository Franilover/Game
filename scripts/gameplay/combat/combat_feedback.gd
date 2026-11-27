extends RefCounted
class_name CombatFeedback

## Presentación de resultados de combate.
## Esta capa no modifica vida, inventario ni objetivos.

static func impacto(objetivo: Node, _cantidad: int) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	if not objetivo is CanvasItem:
		return

	var objetivo_visual: CanvasItem = objetivo as CanvasItem
	# En criaturas, aplicar el destello al sprite garantiza que sea visible
	# aunque el nodo raíz tenga otros efectos de estado o transparencias.
	var sprite := objetivo.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(sprite):
		objetivo_visual = sprite
	var modulate_original: Color = objetivo_visual.modulate
	var tween := objetivo_visual.create_tween()
	tween.tween_property(
		objetivo_visual,
		"modulate",
		Color(1.0, 0.22, 0.22, modulate_original.a),
		0.07
	)
	tween.tween_property(
		objetivo_visual,
		"modulate",
		modulate_original,
		0.15
	)

static func muerte(_objetivo: Node) -> void:
	pass
