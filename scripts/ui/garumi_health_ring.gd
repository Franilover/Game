@tool
extends Control
class_name GarumiHealthRing

@export_range(0.0, 1.0, 0.01) var health_ratio: float = 1.0:
	set(value):
		health_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var occupied: bool = false:
	set(value):
		occupied = value
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	if radius <= 0.0:
		return
	draw_circle(center, radius - 1.5, Color(0.075, 0.05, 0.035, 0.98))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.29, 0.19, 0.12, 1.0), 3.0, true)
	if occupied:
		var progreso := clampf(health_ratio, 0.0, 1.0)
		if progreso > 0.0:
			draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progreso, 48, Color(0.48, 0.73, 0.96, 1.0), 3.0, true)
