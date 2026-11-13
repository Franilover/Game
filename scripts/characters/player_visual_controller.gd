extends RefCounted
class_name PlayerVisualController

## Presentación visual del jugador.
## No modifica estado de gameplay ni consulta Supabase.

var visual: Node2D = null
var facing_marker: Control = null
var animation_player: AnimationPlayer = null
var sprite: Sprite2D = null

const SPRITE_IDLE_PATH := "res://assets/art/characters/Sprite-0004.png"
const SPRITE_WALK_LEFT_PATH := "res://assets/art/characters/Sprite-0004_Walking_Left.png"
const SPRITE_WALK_BACK_PATH := "res://assets/art/characters/Sprite-0004_Walking_Back.png"

var sprite_idle: Texture2D = null
var sprite_walk_left: Texture2D = null
var sprite_walk_back: Texture2D = null


func configurar(
	nuevo_visual: Node2D,
	nuevo_marker: Control,
	nueva_animacion: AnimationPlayer
) -> void:
	visual = nuevo_visual
	facing_marker = nuevo_marker
	animation_player = nueva_animacion
	sprite = visual.get_node_or_null("Sprite2D") as Sprite2D if is_instance_valid(visual) else null
	# ResourceLoader usa las texturas importadas por Godot y conserva su
	# compatibilidad con exportaciones; Image.load(ruta) lee el PNG crudo.
	sprite_idle = _cargar_textura_importada(SPRITE_IDLE_PATH)
	sprite_walk_left = _cargar_textura_importada(SPRITE_WALK_LEFT_PATH)
	sprite_walk_back = _cargar_textura_importada(SPRITE_WALK_BACK_PATH)


func _cargar_textura_importada(ruta: String) -> Texture2D:
	var textura := ResourceLoader.load(ruta) as Texture2D
	if textura == null:
		push_error("PlayerVisualController: no se pudo cargar la textura importada %s." % ruta)
	return textura


func actualizar_direccion(facing: Vector2) -> void:
	if facing_marker == null:
		return

	var direccion := facing.normalized()
	if direccion == Vector2.ZERO:
		direccion = Vector2.DOWN

	var centro := Vector2(0.0, -24.0)
	facing_marker.position = centro + direccion * 14.0 - Vector2(2.0, 2.0)


func actualizar_estado(estado: int, facing: Vector2) -> void:
	_actualizar_sprite_direccional(estado, facing)

	if animation_player == null:
		return

	var nombre := obtener_nombre_animacion(estado, facing)
	if animation_player.has_animation(nombre):
		animation_player.play(nombre)


func _actualizar_sprite_direccional(estado: int, facing: Vector2) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return

	# Los sprites direccionales disponibles son poses para caminar/correr.
	# Al detenerse, saltar o hacer dash se conserva la skin frontal base.
	if sprite_idle != null:
		sprite.texture = sprite_idle
	sprite.flip_h = false
	if estado != 1 and estado != 2:
		return

	var direccion := _obtener_direccion(facing)
	match direccion:
		"side":
			if sprite_walk_left != null:
				sprite.texture = sprite_walk_left
			# La misma pose lateral sirve para ambos lados mediante espejo.
			sprite.flip_h = facing.x > 0.0
		"up":
			if sprite_walk_back != null:
				sprite.texture = sprite_walk_back


func _obtener_direccion(facing: Vector2) -> String:
	if absf(facing.y) >= absf(facing.x):
		return "down" if facing.y > 0.0 else "up"
	return "side"


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
