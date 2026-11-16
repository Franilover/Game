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
var _tween_comida: Tween = null
var _sprite_comida: Sprite2D = null


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


func reproducir_animacion_comer(objeto: Dictionary) -> void:
	if not is_instance_valid(visual):
		return
	if is_instance_valid(_tween_comida) and _tween_comida.is_running():
		_tween_comida.kill()
	if is_instance_valid(_sprite_comida):
		_sprite_comida.queue_free()
		_sprite_comida = null

	var textura := ItemIconResolver.obtener_icono(objeto)
	if textura == null:
		_reproducir_saltito_comiendo()
		return

	_sprite_comida = Sprite2D.new()
	_sprite_comida.name = "AlimentoAnimado"
	_sprite_comida.texture = textura
	_sprite_comida.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_comida.scale = Vector2(0.62, 0.62)
	_sprite_comida.z_index = 8
	var posicion_boca := sprite.position + Vector2(0.0, -5.0) if is_instance_valid(sprite) else Vector2(0.0, -26.0)
	_sprite_comida.position = posicion_boca + Vector2(13.0, 17.0)
	visual.add_child(_sprite_comida)

	_tween_comida = visual.create_tween()
	_tween_comida.set_trans(Tween.TRANS_SINE)
	_tween_comida.set_ease(Tween.EASE_OUT)
	_tween_comida.tween_property(_sprite_comida, "position", posicion_boca + Vector2(0.0, -25.0), 0.22)
	_tween_comida.tween_interval(0.08)
	_tween_comida.tween_callback(_reproducir_saltito_comiendo)
	_tween_comida.set_trans(Tween.TRANS_QUAD)
	_tween_comida.set_ease(Tween.EASE_IN)
	_tween_comida.tween_property(_sprite_comida, "position", posicion_boca, 0.18)
	_tween_comida.parallel().tween_property(_sprite_comida, "scale", Vector2(0.18, 0.18), 0.18)
	_tween_comida.parallel().tween_property(_sprite_comida, "modulate:a", 0.0, 0.18)
	_tween_comida.tween_callback(_limpiar_sprite_comida)


func _reproducir_saltito_comiendo() -> void:
	if not is_instance_valid(visual):
		return
	var posicion_inicial := visual.position
	var salto := visual.create_tween()
	salto.set_trans(Tween.TRANS_SINE)
	salto.set_ease(Tween.EASE_OUT)
	salto.tween_property(visual, "position", posicion_inicial + Vector2(0.0, -6.0), 0.12)
	salto.set_ease(Tween.EASE_IN)
	salto.tween_property(visual, "position", posicion_inicial, 0.14)


func _limpiar_sprite_comida() -> void:
	if is_instance_valid(_sprite_comida):
		_sprite_comida.queue_free()
	_sprite_comida = null
	_tween_comida = null


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
