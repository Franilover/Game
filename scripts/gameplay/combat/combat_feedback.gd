extends RefCounted
class_name CombatFeedback

## Presentación de resultados de combate.
## Esta capa no modifica vida, inventario ni objetivos.

static func impacto(objetivo: Node, _cantidad: int) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	if not objetivo is CanvasItem:
		return

	var objetivo_visual := objetivo as CanvasItem
	var modulate_original: Color = objetivo_visual.modulate
	var tween := objetivo_visual.create_tween()
	tween.tween_property(
		objetivo_visual,
		"modulate",
		Color(1.0, 0.45, 0.45, modulate_original.a),
		0.04
	)
	tween.tween_property(
		objetivo_visual,
		"modulate",
		modulate_original,
		0.08
	)

static func muerte(_objetivo: Node) -> void:
	pass
