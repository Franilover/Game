extends RefCounted
class_name PlayerVisualController

## Presentación visual del jugador.
## No modifica estado de gameplay ni consulta Supabase.

var visual: Node2D = null
var facing_marker: Control = null
var animation_player: AnimationPlayer = null


func configurar(
	nuevo_visual: Node2D,
	nuevo_marker: Control,
	nueva_animacion: AnimationPlayer
) -> void:
	visual = nuevo_visual
	facing_marker = nuevo_marker
	animation_player = nueva_animacion


func actualizar_direccion(facing: Vector2) -> void:
	if facing_marker == null:
		return

	var direccion := facing.normalized()
	if direccion == Vector2.ZERO:
		direccion = Vector2.DOWN

	var centro := Vector2(0.0, -24.0)
	facing_marker.position = centro + direccion * 14.0 - Vector2(2.0, 2.0)


func actualizar_estado(estado: int, facing: Vector2) -> void:
	if animation_player == null:
		return

	var nombre := obtener_nombre_animacion(estado, facing)
	if animation_player.has_animation(nombre):
		animation_player.play(nombre)


func obtener_nombre_animacion(estado: int, facing: Vector2) -> String:
	var prefijo := "idle"
	match estado:
		1:
			prefijo = "walk"
		2:
			prefijo = "run"
		3:
			prefijo = "jump"
		4:
			prefijo = "dash"

	var direccion := "side"
	if absf(facing.y) >= absf(facing.x):
		direccion = "down" if facing.y > 0.0 else "up"
	return prefijo + "_" + direccion
