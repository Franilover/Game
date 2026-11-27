extends RefCounted
class_name PlayerVisualController

## Presentación compartida del jugador para el mundo libre y las expediciones.
## El perfil adapta la orientación; las capas, el equipo y los ataques se reutilizan.

const EQUIPMENT_ANIMATOR_SCRIPT: Script = preload("res://scripts/characters/player_equipment_animation_controller.gd")
const ITEM_ICON_RESOLVER_SCRIPT: Script = preload("res://scripts/ui/item_icon_resolver.gd")
const CHARACTER_APPEARANCE_SCRIPT: Script = preload("res://scripts/characters/character_appearance.gd")
const SHARED_ASSET_LIBRARY: Script = preload("res://scripts/shared/assets/shared_asset_library.gd")

var visual: Node2D = null
var facing_marker: Control = null
var animation_player: AnimationPlayer = null
var sprite: Sprite2D = null
var sprite_idle: Texture2D = null
var _sprite_idle_catalogo: Texture2D = null
var sprite_walk_left: Texture2D = null
var sprite_walk_back: Texture2D = null
var perfil_renderizado: String = "top_down"

var _equipment_animator = null
var _equipo_sprites: Dictionary = {}
var _equipo_datos: Dictionary = {}
var _equipo_oculto: bool = false
var _equipo_restore_tween: Tween = null
var _tween_comida: Tween = null
var _sprite_comida: Sprite2D = null
var facing: Vector2 = Vector2.DOWN


func configurar(
	nuevo_visual: Node2D,
	nuevo_marker: Control,
	nueva_animacion: AnimationPlayer,
	nuevo_perfil: String = "top_down"
) -> void:
	visual = nuevo_visual
	facing_marker = nuevo_marker
	animation_player = nueva_animacion
	perfil_renderizado = nuevo_perfil
	sprite = visual.get_node_or_null("Sprite2D") as Sprite2D if is_instance_valid(visual) else null
	_equipment_animator = EQUIPMENT_ANIMATOR_SCRIPT.new()
	_equipment_animator.configurar(visual, sprite)
	sprite_idle = CHARACTER_APPEARANCE_SCRIPT.obtener_textura_sprite("idle_front")
	_sprite_idle_catalogo = sprite_idle
	sprite_walk_left = CHARACTER_APPEARANCE_SCRIPT.obtener_textura_sprite("walk_left")
	sprite_walk_back = CHARACTER_APPEARANCE_SCRIPT.obtener_textura_sprite("walk_back")
	if is_instance_valid(sprite):
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if sprite.texture == null:
			sprite.texture = sprite_idle
	CHARACTER_APPEARANCE_SCRIPT.sincronizar_capas(visual)


func aplicar_apariencia(apariencia: Dictionary, skin_path: String = "") -> void:
	if not is_instance_valid(visual):
		return
	var textura_personaje: Texture2D = SHARED_ASSET_LIBRARY.textura(skin_path) if not skin_path.strip_edges().is_empty() else null
	sprite_idle = textura_personaje if textura_personaje != null else _sprite_idle_catalogo
	if is_instance_valid(sprite):
		sprite.texture = sprite_idle
	CHARACTER_APPEARANCE_SCRIPT.aplicar_capas(visual, apariencia)
	CHARACTER_APPEARANCE_SCRIPT.actualizar_cabello_direccion(visual, facing)
	CHARACTER_APPEARANCE_SCRIPT.sincronizar_capas(visual)


func actualizar_direccion(nueva_direccion: Vector2) -> void:
	facing = _normalizar_direccion(nueva_direccion)
	if is_instance_valid(facing_marker):
		var centro := Vector2(0.0, -24.0)
		facing_marker.position = centro + facing * 14.0 - Vector2(2.0, 2.0)
	_actualizar_posicion_equipo_visual(_obtener_direccion_equipo_render())


func actualizar_estado(estado: int, nueva_direccion: Vector2) -> void:
	facing = _normalizar_direccion(nueva_direccion)
	_actualizar_sprite_direccional(estado, facing)
	if is_instance_valid(animation_player):
		var nombre := obtener_nombre_animacion(estado, facing)
		if animation_player.has_animation(nombre):
			animation_player.play(nombre)
	_actualizar_posicion_equipo_visual(_obtener_direccion_equipo_render())


func _actualizar_sprite_direccional(estado: int, direccion: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.texture = sprite_idle
	sprite.flip_h = false
	if estado == 1 or estado == 2:
		var orientacion := _obtener_direccion(direccion)
		match orientacion:
			"side":
				if sprite_walk_left != null:
					sprite.texture = sprite_walk_left
				sprite.flip_h = direccion.x > 0.0
			"up":
				if sprite_walk_back != null:
					sprite.texture = sprite_walk_back
	CHARACTER_APPEARANCE_SCRIPT.actualizar_cabello_direccion(visual, direccion)
	CHARACTER_APPEARANCE_SCRIPT.sincronizar_capas(visual)


## Perfil lateral usado por Saltus. Solo cambia la pose y el espejo:
## la misma skin, prendas y equipo siguen siendo los del personaje principal.
func actualizar_presentacion_plataforma(direccion_horizontal: float, en_movimiento: bool) -> void:
	if not is_instance_valid(sprite):
		return
	if absf(direccion_horizontal) > 0.05:
		facing = Vector2(signf(direccion_horizontal), 0.0)
	elif absf(facing.x) < 0.5:
		facing = Vector2.RIGHT
	sprite.texture = sprite_walk_left if en_movimiento and sprite_walk_left != null else sprite_idle
	sprite.flip_h = facing.x > 0.0
	CHARACTER_APPEARANCE_SCRIPT.actualizar_cabello_direccion(visual, facing)
	CHARACTER_APPEARANCE_SCRIPT.sincronizar_capas(visual)
	_actualizar_posicion_equipo_visual(_obtener_direccion_equipo_render())


func configurar_equipo_visual(izquierda: Dictionary, derecha: Dictionary) -> void:
	_actualizar_sprite_equipado("izquierda", izquierda)
	_actualizar_sprite_equipado("derecha", derecha)
	_actualizar_posicion_equipo_visual(facing)


func _actualizar_sprite_equipado(mano: String, objeto: Dictionary) -> void:
	var sprite_equipo := _equipo_sprites.get(mano) as Sprite2D
	var datos_previos: Dictionary = _equipo_datos.get(mano, {})
	if datos_previos == objeto and is_instance_valid(sprite_equipo):
		sprite_equipo.visible = not _equipo_oculto and sprite_equipo.texture != null
		return
	_equipo_datos[mano] = objeto.duplicate(true)
	if objeto.is_empty():
		if is_instance_valid(sprite_equipo):
			sprite_equipo.texture = null
			sprite_equipo.visible = false
		return

	var textura: Texture2D = _obtener_textura_equipo(objeto)
	if textura == null:
		var icono_variant: Variant = objeto.get("icono", null)
		if icono_variant is Texture2D:
			textura = icono_variant as Texture2D
	if textura == null:
		var tipo: String = EQUIPMENT_ANIMATOR_SCRIPT.obtener_tipo_animacion(objeto)
		textura = EQUIPMENT_ANIMATOR_SCRIPT.obtener_textura_respaldo(tipo)
	if textura == null:
		if is_instance_valid(sprite_equipo):
			sprite_equipo.texture = null
			sprite_equipo.visible = false
		return

	if not is_instance_valid(sprite_equipo):
		sprite_equipo = Sprite2D.new()
		sprite_equipo.name = "EquipoVisual_" + mano
		sprite_equipo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_equipo.centered = true
		sprite_equipo.z_index = 8
		visual.add_child(sprite_equipo)
		_equipo_sprites[mano] = sprite_equipo
	sprite_equipo.texture = textura
	sprite_equipo.scale = Vector2(0.62, 0.62)
	sprite_equipo.visible = not _equipo_oculto


func _obtener_textura_equipo(objeto: Dictionary) -> Texture2D:
	# Acepta sprites/texturas directos y rutas explícitas del catálogo,
	# además de los iconos resueltos por nombre. Así cualquier objeto puede
	# representarse en la mano, aunque no tenga una animación de herramienta.
	for clave in ["sprite", "textura", "texture", "imagen", "icono"]:
		var valor: Variant = objeto.get(clave, null)
		if valor is Texture2D:
			return valor as Texture2D

	for clave_ruta in [
		"sprite_ruta", "ruta_sprite", "sprite_path",
		"textura_ruta", "ruta_textura", "texture_path",
		"imagen_ruta", "ruta_imagen", "icono_ruta"
	]:
		var ruta := str(objeto.get(clave_ruta, "")).strip_edges()
		if ruta.is_empty():
			continue
		var textura_ruta: Texture2D = SHARED_ASSET_LIBRARY.textura(ruta)
		if textura_ruta != null:
			return textura_ruta

	var datos_sprite := objeto.duplicate(true)
	datos_sprite.erase("icono")
	return ITEM_ICON_RESOLVER_SCRIPT.obtener_icono(datos_sprite)


func _obtener_direccion_equipo_render() -> Vector2:
	# La pose idle vuelve a mostrar al personaje de frente; el equipo debe
	# acompañar esa pose aunque la última dirección de movimiento fuera lateral.
	if is_instance_valid(sprite) and sprite.texture == sprite_idle:
		return Vector2.DOWN
	return facing


func _actualizar_posicion_equipo_visual(direccion: Vector2) -> void:
	if not is_instance_valid(visual):
		return
	var origen := sprite.position if is_instance_valid(sprite) else Vector2(0.0, -22.0)
	var orientacion := _obtener_direccion(direccion)
	var vista_frontal := orientacion == "down"
	var vista_trasera := orientacion == "up"
	var mirando_derecha := direccion.x > 0.0
	# En perfil se muestra la mano opuesta a la dirección de mirada:
	# izquierda -> objeto de la mano derecha; derecha -> objeto de la mano izquierda.
	var mano_visible := "izquierda" if mirando_derecha else "derecha"
	for mano in ["izquierda", "derecha"]:
		var sprite_equipo := _equipo_sprites.get(mano) as Sprite2D
		if not is_instance_valid(sprite_equipo):
			continue
		sprite_equipo.visible = (
			not _equipo_oculto
			and not vista_trasera
			and (vista_frontal or mano == mano_visible)
			and sprite_equipo.texture != null
		)
		# La mano derecha frontal define la referencia: +8 px y +0.38 rad.
		# La izquierda frontal conserva el mismo ángulo, espejado hacia el lado opuesto.
		var lado := -1.0 if mano == "izquierda" else 1.0
		var rotacion_mano := -0.38 if mano == "izquierda" else 0.38
		var invertir_sprite: bool = mano == "izquierda" and vista_frontal
		if not vista_frontal:
			# Al caminar a la derecha, la mano izquierda ocupa exactamente
			# la posición, rotación y orientación visual de la mano derecha frontal.
			lado = 1.0
			rotacion_mano = 0.38
			invertir_sprite = false
			if not mirando_derecha:
				lado = -1.0
				rotacion_mano = -0.38
				invertir_sprite = true
		var separacion_frontal := 20.0 if vista_frontal else 8.0
		sprite_equipo.position = origen + Vector2(lado * separacion_frontal, 6.0)
		sprite_equipo.flip_h = invertir_sprite
		sprite_equipo.rotation = rotacion_mano
		sprite_equipo.z_index = 5 if direccion.y < -0.45 else 8

func reproducir_animacion_herramienta(objeto: Dictionary, direccion: Vector2) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(_equipment_animator) or objeto.is_empty():
		return
	facing = _normalizar_direccion(direccion)
	_actualizar_posicion_equipo_visual(facing)
	_equipo_oculto = true
	for sprite_variant in _equipo_sprites.values():
		var sprite_equipo := sprite_variant as Sprite2D
		if is_instance_valid(sprite_equipo):
			sprite_equipo.visible = false
	if is_instance_valid(_equipo_restore_tween) and _equipo_restore_tween.is_running():
		_equipo_restore_tween.kill()
	_equipment_animator.reproducir(objeto, facing)
	var perfil: Dictionary = EQUIPMENT_ANIMATOR_SCRIPT.obtener_perfil(objeto)
	var duracion := float(perfil.get("duracion", 0.44)) + 0.12
	_equipo_restore_tween = visual.create_tween()
	_equipo_restore_tween.tween_interval(duracion)
	_equipo_restore_tween.tween_callback(_restaurar_equipo_visual)


func _restaurar_equipo_visual() -> void:
	_equipo_oculto = false
	_actualizar_posicion_equipo_visual(facing)
	_equipo_restore_tween = null


func reproducir_animacion_ataque(objeto: Dictionary, direccion: Vector2) -> void:
	reproducir_animacion_herramienta(objeto, direccion)


func reproducir_animacion_comer(objeto: Dictionary) -> void:
	if not is_instance_valid(visual):
		return
	if is_instance_valid(_tween_comida) and _tween_comida.is_running():
		_tween_comida.kill()
	if is_instance_valid(_sprite_comida):
		_sprite_comida.queue_free()
		_sprite_comida = null

	var textura: Texture2D = ITEM_ICON_RESOLVER_SCRIPT.obtener_icono(objeto)
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


func _obtener_direccion(direccion: Vector2) -> String:
	if absf(direccion.y) >= absf(direccion.x):
		return "down" if direccion.y > 0.0 else "up"
	return "side"


func _normalizar_direccion(direccion: Vector2) -> Vector2:
	if direccion.length_squared() <= 0.01:
		return facing if facing.length_squared() > 0.01 else Vector2.DOWN
	return direccion.normalized()


func obtener_nombre_animacion(estado: int, direccion: Vector2) -> String:
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

	var orientacion := "side"
	if absf(direccion.y) >= absf(direccion.x):
		orientacion = "down" if direccion.y > 0.0 else "up"
	return prefijo + "_" + orientacion
