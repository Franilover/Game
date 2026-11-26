extends Entity
class_name SaltusPlayer

const IDLE_TEXTURE_PATH: String = "res://assets/art/kingdom/Torres/Personajes/Sprite-0004.png"
const WALK_TEXTURE_PATH: String = "res://assets/art/kingdom/Torres/Personajes/Sprite-0004_Walking_Left.png"
const PLAYER_VISUAL_CONTROLLER_SCRIPT = preload("res://scripts/characters/player_visual_controller.gd")
const ITEM_ICON_RESOLVER_SCRIPT = preload("res://scripts/ui/item_icon_resolver.gd")
const EQUIPMENT_ANIMATOR_SCRIPT = preload("res://scripts/characters/player_equipment_animation_controller.gd")

@export var move_speed: float = 190.0
@export var run_multiplier: float = 1.35
@export var jump_velocity: float = -420.0
@export var gravity: float = 1100.0
@export var acceleration: float = 1500.0
@export var friction: float = 1900.0
@export var dash_distance: float = 64.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 0.8
@export var wall_climb_speed: float = 72.0
@export var wall_grab_probe_distance: float = 13.0
@export var wall_jump_speed: float = 260.0
@export var wall_jump_duration: float = 0.24

@onready var sprite: Sprite2D = $Sprite2D

var _jump_requested: bool = false
var _dash_requested: bool = false
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _air_dash_unlocked: bool = true
var _air_dash_available: bool = true
var _elapsed: float = 0.0
var _dash_ghost_timer: float = 0.0
var _wall_grabbed: bool = false
var _wall_normal: Vector2 = Vector2.ZERO
var _wall_jump_remaining: float = 0.0
var _wall_jump_total: float = 0.0
var _idle_texture: Texture2D
var _walk_texture: Texture2D
var facing: Vector2 = Vector2.DOWN
var _visual_controller: PlayerVisualController = PLAYER_VISUAL_CONTROLLER_SCRIPT.new()
var _sprites_equipo: Dictionary = {}
var _equipo_oculto_por_animacion: bool = false
var _equipo_animacion_restore_tween: Tween = null


func _ready() -> void:
	# El TileSet de Saltus usa la capa física 1 para el terreno.
	# El cuerpo del personaje escucha esa capa; su Hurtbox de Entity conserva
	# la capa 2 para que los ataques sigan detectándolo.
	collision_layer = 2
	collision_mask = 1
	super._ready()
	add_to_group("saltus_player")
	if sprite != null:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_idle_texture = load(IDLE_TEXTURE_PATH) as Texture2D
		_walk_texture = load(WALK_TEXTURE_PATH) as Texture2D
		if _idle_texture != null:
			sprite.texture = _idle_texture
	_visual_controller.configurar(self, null, null)


## La UI y el personaje de Saltus leen el mismo equipamiento del InventoryController.
## Este método solo refleja los objetos recibidos; no mantiene un inventario local.
func configurar_equipo_visual(izquierda: Dictionary, derecha: Dictionary) -> void:
	_actualizar_sprite_equipado("izquierda", izquierda)
	_actualizar_sprite_equipado("derecha", derecha)
	_actualizar_posicion_equipo_visual()


func _actualizar_sprite_equipado(mano: String, objeto: Dictionary) -> void:
	var sprite_equipo := _sprites_equipo.get(mano) as Sprite2D
	if objeto.is_empty():
		if is_instance_valid(sprite_equipo):
			sprite_equipo.texture = null
			sprite_equipo.visible = false
		return

	var datos_sprite := objeto.duplicate(true)
	datos_sprite.erase("icono")
	var textura: Texture2D = ITEM_ICON_RESOLVER_SCRIPT.obtener_icono(datos_sprite)
	if textura == null:
		var icono_variant: Variant = objeto.get("icono", null)
		if icono_variant is Texture2D:
			textura = icono_variant as Texture2D
	if textura == null:
		var tipo := EQUIPMENT_ANIMATOR_SCRIPT.obtener_tipo_animacion(objeto)
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
		sprite_equipo.z_index = 6
		add_child(sprite_equipo)
		_sprites_equipo[mano] = sprite_equipo
	sprite_equipo.texture = textura
	sprite_equipo.scale = Vector2(0.62, 0.62)
	sprite_equipo.visible = not _equipo_oculto_por_animacion


func _actualizar_posicion_equipo_visual() -> void:
	for mano_variant in _sprites_equipo.keys():
		var mano := str(mano_variant)
		var sprite_equipo := _sprites_equipo[mano_variant] as Sprite2D
		if not is_instance_valid(sprite_equipo):
			continue
		var lado := -1.0 if mano == "izquierda" else 1.0
		if facing.x > 0.0:
			lado *= -1.0
		var origen := sprite.position if is_instance_valid(sprite) else Vector2(0.0, -22.0)
		sprite_equipo.position = origen + Vector2(lado * 8.0, 6.0)
		sprite_equipo.flip_h = facing.x > 0.0


func _ocultar_equipo_durante_animacion(objeto: Dictionary) -> void:
	_equipo_oculto_por_animacion = true
	for sprite_variant in _sprites_equipo.values():
		var sprite_equipo := sprite_variant as Sprite2D
		if is_instance_valid(sprite_equipo):
			sprite_equipo.visible = false
	if is_instance_valid(_equipo_animacion_restore_tween) and _equipo_animacion_restore_tween.is_running():
		_equipo_animacion_restore_tween.kill()
	var perfil := EQUIPMENT_ANIMATOR_SCRIPT.obtener_perfil(objeto)
	var duracion := float(perfil.get("duracion", 0.44)) + 0.12
	_equipo_animacion_restore_tween = create_tween()
	_equipo_animacion_restore_tween.tween_interval(duracion)
	_equipo_animacion_restore_tween.tween_callback(_restaurar_equipo_visual)


func _restaurar_equipo_visual() -> void:
	_equipo_oculto_por_animacion = false
	for sprite_variant in _sprites_equipo.values():
		var sprite_equipo := sprite_variant as Sprite2D
		if is_instance_valid(sprite_equipo):
			sprite_equipo.visible = sprite_equipo.texture != null
	_equipo_animacion_restore_tween = null


func reproducir_animacion_herramienta(objeto: Dictionary, objetivo_global: Vector2) -> void:
	var direccion := global_position.direction_to(objetivo_global)
	if direccion.length_squared() > 0.01:
		facing = direccion.normalized()
		if absf(facing.x) > 0.01 and sprite != null:
			sprite.flip_h = facing.x > 0.0
	_actualizar_posicion_equipo_visual()
	_ocultar_equipo_durante_animacion(objeto)
	if is_instance_valid(_visual_controller):
		_visual_controller.reproducir_animacion_herramienta(objeto, facing)


func restaurar_tras_reaparicion(posicion: Vector2) -> void:
	global_position = posicion
	velocity = Vector2.ZERO
	_jump_requested = false
	_dash_requested = false
	_dash_time_left = 0.0
	_dash_cooldown_left = 0.0
	_dash_ghost_timer = 0.0
	_wall_grabbed = false
	_wall_normal = Vector2.ZERO
	_wall_jump_remaining = 0.0
	_wall_jump_total = 0.0
	_air_dash_available = true
	visible = true
	restaurar_estado_vital(max_health, true, max_mana)


func unlock_air_dash() -> void:
	_air_dash_unlocked = true
	_air_dash_available = true


func _input(event: InputEvent) -> void:
	if GameplayInputGate.esta_entrada_bloqueada(get_tree()):
		return
	if event is not InputEventKey:
		return
	var tecla := event as InputEventKey
	# En Saltus, ESPACIO salta y SHIFT solicita el dash.
	if tecla.pressed and not tecla.echo:
		if tecla.keycode == KEY_SPACE or tecla.physical_keycode == KEY_SPACE:
			_jump_requested = true
		elif tecla.keycode == KEY_SHIFT or tecla.physical_keycode == KEY_SHIFT:
			_dash_requested = true


func _unhandled_input(event: InputEvent) -> void:
	if GameplayInputGate.esta_entrada_bloqueada(get_tree()):
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE):
			_jump_requested = true
		elif key.pressed and not key.echo and (key.keycode == KEY_E or key.physical_keycode == KEY_E):
			var gestor := get_tree().get_first_node_in_group("zone_manager")
			if is_instance_valid(gestor) and gestor.has_method("salir_expedicion_saltus"):
				gestor.call("salir_expedicion_saltus")


func _physics_process(delta: float) -> void:
	if GameplayInputGate.esta_entrada_bloqueada(get_tree()):
		_jump_requested = false
		_dash_requested = false
		velocity = Vector2.ZERO
		return
	_elapsed += delta
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	if is_on_floor() and _air_dash_unlocked:
		_air_dash_available = true

	var direction := Input.get_axis("move_left", "move_right")
	var aim_vertical := Input.get_axis("move_up", "move_down")
	var dash_aim := Vector2(direction, aim_vertical).normalized()

	if _wall_jump_remaining > 0.0:
		_procesar_salto_pared(delta)
		_actualizar_presentacion(direction)
		return
	if _wall_grabbed and _procesar_agarre_pared(delta):
		_actualizar_presentacion(direction)
		return

	if _dash_time_left > 0.0:
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
		_dash_ghost_timer -= delta
		if _dash_ghost_timer <= 0.0:
			_crear_estela_dash()
			_dash_ghost_timer = 0.035
		velocity = _dash_direction * (dash_distance / maxf(dash_duration, 0.01))
		move_and_slide()
		if _dash_time_left <= 0.0:
			velocity = Vector2.ZERO
		_actualizar_presentacion(direction)
		return

	if _dash_requested:
		_dash_requested = false
		if _dash_cooldown_left <= 0.0 and (is_on_floor() or _air_dash_available):
			if not is_on_floor():
				_air_dash_available = false
			if dash_aim.length_squared() > 0.01:
				_dash_direction = dash_aim
			elif absf(direction) > 0.01:
				_dash_direction = Vector2(signf(direction), 0.0)
			else:
				_dash_direction = Vector2.LEFT if sprite != null and sprite.flip_h else Vector2.RIGHT
			_dash_time_left = dash_duration
			_dash_ghost_timer = 0.0
			_crear_estela_dash()
			_dash_cooldown_left = dash_cooldown
			velocity = _dash_direction * (dash_distance / maxf(dash_duration, 0.01))
			move_and_slide()
			_actualizar_presentacion(direction)
			return

	var speed := move_speed
	if Input.is_action_pressed("run"):
		speed *= run_multiplier

	if absf(direction) > 0.01:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	var jump_pressed := _jump_requested or Input.is_action_just_pressed("jump")
	_jump_requested = false
	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()
	_detectar_agarre_pared()
	_actualizar_presentacion(direction)


## El sensor de escalada solo busca superficies físicas laterales. El cuerpo
## CharacterBody2D conserva su propia colisión sólida con el TileMapLayer.
func _detectar_agarre_pared() -> void:
	if _wall_grabbed or not Input.is_key_pressed(KEY_CTRL):
		return
	var normal := _buscar_normal_pared()
	if normal.length_squared() < 0.5:
		return
	_wall_normal = normal
	_wall_grabbed = true
	velocity = Vector2.ZERO
	facing = -normal
	_actualizar_posicion_equipo_visual()


func _buscar_normal_pared() -> Vector2:
	if not is_inside_tree() or get_world_2d() == null:
		return Vector2.ZERO
	var espacio := get_world_2d().direct_space_state
	var exclusion: Array[RID] = [get_rid()]
	var offsets_y: Array[float] = [-17.0, -11.0, -5.0]
	var distancia := maxf(wall_grab_probe_distance, 8.0)
	for lado in [-1.0, 1.0]:
		for offset_y in offsets_y:
			var origen := global_position + Vector2(0.0, offset_y)
			var destino := origen + Vector2(lado * distancia, 0.0)
			var consulta := PhysicsRayQueryParameters2D.create(
				origen,
				destino,
				1,
				exclusion
			)
			consulta.collide_with_bodies = true
			consulta.collide_with_areas = false
			var impacto := espacio.intersect_ray(consulta)
			if impacto.is_empty():
				continue
			var collider_variant: Variant = impacto.get("collider")
			if collider_variant is TileMapLayer:
				var terreno := collider_variant as TileMapLayer
				var punto_global: Vector2 = impacto.get("position", destino)
				var celda := terreno.local_to_map(terreno.to_local(punto_global))
				var datos := terreno.get_cell_tile_data(celda)
				if datos != null:
					var es_one_way := false
					for indice_poligono in range(datos.get_collision_polygons_count(0)):
						if datos.is_collision_polygon_one_way(0, indice_poligono):
							es_one_way = true
							break
					if es_one_way:
						continue
			var normal: Vector2 = impacto.get("normal", Vector2.ZERO)
			if absf(normal.x) >= 0.72:
				return normal.normalized()
	return Vector2.ZERO


func _procesar_agarre_pared(_delta: float) -> bool:
	if not Input.is_key_pressed(KEY_CTRL):
		_wall_grabbed = false
		_wall_normal = Vector2.ZERO
		return false
	var normal_actual := _buscar_normal_pared()
	if normal_actual.length_squared() >= 0.5:
		_wall_normal = normal_actual
	else:
		_wall_grabbed = false
		_wall_normal = Vector2.ZERO
		return false
	var salto_solicitado := _jump_requested or Input.is_action_just_pressed("jump")
	_jump_requested = false
	if salto_solicitado or _direccion_alejamiento_just_pressed():
		_iniciar_salto_pared()
		return true
	var vertical := Input.get_axis("move_up", "move_down")
	velocity = Vector2(0.0, vertical * wall_climb_speed)
	move_and_slide()
	return true


func _direccion_alejamiento_just_pressed() -> bool:
	if _wall_normal.x < -0.72:
		return Input.is_action_just_pressed("move_left")
	if _wall_normal.x > 0.72:
		return Input.is_action_just_pressed("move_right")
	return false


func _iniciar_salto_pared() -> void:
	var direccion_salida := _wall_normal
	if direccion_salida.length_squared() < 0.5:
		direccion_salida = Vector2.LEFT if facing.x >= 0.0 else Vector2.RIGHT
	_wall_grabbed = false
	_wall_normal = Vector2.ZERO
	_wall_jump_total = maxf(wall_jump_duration, 0.08)
	_wall_jump_remaining = _wall_jump_total
	velocity = direccion_salida * wall_jump_speed + Vector2.UP * wall_jump_speed * 0.42
	facing = direccion_salida


func _procesar_salto_pared(delta: float) -> void:
	_wall_jump_remaining = maxf(0.0, _wall_jump_remaining - delta)
	velocity = velocity.move_toward(Vector2.ZERO, wall_jump_speed * 4.0 * delta)
	move_and_slide()
	if _wall_jump_remaining <= 0.0:
		velocity = Vector2.ZERO
		_wall_jump_total = 0.0


func _actualizar_presentacion(direction: float) -> void:
	if sprite == null:
		return
	if absf(direction) > 0.05:
		facing = Vector2(signf(direction), 0.0)
		sprite.flip_h = facing.x > 0.0
		if _walk_texture != null:
			sprite.texture = _walk_texture
	else:
		if _idle_texture != null:
			sprite.texture = _idle_texture
		# Mantener la orientación del último movimiento también en reposo,
		# para que el golpe y la pose del personaje coincidan.
		sprite.flip_h = facing.x > 0.0
	if is_on_floor() and absf(velocity.x) > 18.0:
		sprite.position.y = -22.0 + sin(_elapsed * 15.0) * 1.3
	else:
		sprite.position.y = move_toward(sprite.position.y, -22.0, 1.0)
	_actualizar_posicion_equipo_visual()


func _crear_estela_dash() -> void:
	if sprite == null or sprite.texture == null:
		return
	var fantasma := Sprite2D.new()
	fantasma.texture = sprite.texture
	fantasma.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fantasma.flip_h = sprite.flip_h
	fantasma.flip_v = sprite.flip_v
	fantasma.centered = sprite.centered
	fantasma.z_as_relative = false
	fantasma.global_position = sprite.global_position
	fantasma.global_rotation = sprite.global_rotation
	fantasma.global_scale = sprite.global_scale
	fantasma.modulate = Color(0.72, 1.0, 0.68, 0.48)
	fantasma.z_index = 99
	get_parent().add_child(fantasma)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fantasma, "modulate:a", 0.0, 0.17)
	tween.tween_property(fantasma, "scale", sprite.scale * 0.92, 0.17)
	tween.chain().tween_callback(fantasma.queue_free)
