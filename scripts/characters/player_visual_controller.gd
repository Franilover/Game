extends RefCounted
class_name PlayerVisualController

## Presentación visual del jugador.
## No modifica estado de gameplay ni consulta Supabase.

var visual: Node2D = null
var body_visual: CanvasItem = null
var head_visual: CanvasItem = null
var facing_marker: CanvasItem = null
var animation_player: AnimationPlayer = null

func configurar(
	nuevo_visual: Node2D,
	nuevo_body: CanvasItem,
	nuevo_head: CanvasItem,
	nuevo_marker: CanvasItem,
	nueva_animacion: AnimationPlayer
) -> void:
	visual = nuevo_visual
	body_visual = nuevo_body
	head_visual = nuevo_head
	facing_marker = nuevo_marker
	animation_player = nueva_animacion

func actualizar_direccion(facing: Vector2) -> void:
	if facing_marker == null:
		return

	var direccion := facing.normalized()
	if direccion == Vector2.ZERO:
		direccion = Vector2.DOWN

	facing_marker.position = direccion * 6.0

func actualizar_estado(estado: int) -> void:
	if animation_player == null:
		return

	var nombre := "idle"
	match estado:
		1:
			nombre = "walk"
		2:
			nombre = "run"
		3:
			nombre = "jump"
		4:
			nombre = "dash"

	if animation_player.has_animation(nombre):
		animation_player.play(nombre)
