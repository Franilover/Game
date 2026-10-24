extends Sprite2D
## Casa temporal de integración visual. No forma parte del catálogo canónico.
## Se coloca junto al spawn para verificar el asset en el mapa jugable.

const DISTANCIA_DESDE_SPAWN_TILES: int = 3
const TILE_SIZE: int = 32
const DEBUG_COLOR := Color(1.0, 0.0, 1.0, 1.0)


func _ready() -> void:
	# El terreno usa z_index=-4096 absoluto. Esta prueba debe quedar
	# inequívocamente delante de él, independientemente del orden de nodos.
	z_as_relative = false
	z_index = 4096
	modulate = Color.WHITE
	visible = false
	call_deferred("_colocar_junto_al_spawn")


func _draw() -> void:
	# El marco se dibuja aunque Casa.png sea transparente o tenga un problema
	# de importación: permite separar el fallo del asset del de la escena/cámara.
	draw_rect(Rect2(Vector2(-36.0, -36.0), Vector2(72.0, 72.0)), DEBUG_COLOR, false, 3.0)
	draw_line(Vector2(-44.0, 0.0), Vector2(44.0, 0.0), DEBUG_COLOR, 2.0)
	draw_line(Vector2(0.0, -44.0), Vector2(0.0, 44.0), DEBUG_COLOR, 2.0)


func _colocar_junto_al_spawn() -> void:
	var generador := get_parent() as WorldGenerator
	if generador == null:
		push_error("CasaPrueba: debe ser hija de WorldGenerator.")
		return

	while is_instance_valid(generador) and not generador.is_world_ready():
		await get_tree().process_frame

	if not is_instance_valid(generador):
		return

	var spawn := generador.get_spawn_position()
	global_position = spawn + Vector2(DISTANCIA_DESDE_SPAWN_TILES * TILE_SIZE, 0)
	visible = true
	queue_redraw()

	var camara := get_viewport().get_camera_2d()
	var centro_camara := camara.get_screen_center_position() if camara != null else Vector2.INF
	var posicion_pantalla := get_global_transform_with_canvas() * Vector2.ZERO

	print(
		"CasaPrueba: visible=", is_visible_in_tree(),
		" | textura=", texture.get_size() if texture != null else Vector2.ZERO,
		" | spawn=", spawn,
		" | posicion_global=", global_position,
		" | posicion_pantalla=", posicion_pantalla,
		" | camara=", centro_camara,
		" | z_index=", z_index,
		" | viewport=", get_viewport_rect().size
	)
