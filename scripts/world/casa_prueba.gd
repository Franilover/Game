extends Sprite2D
## Casa temporal de integración visual. No forma parte del catálogo canónico.
## Se coloca junto al spawn para verificar el asset en el mapa jugable.

const DISTANCIA_DESDE_SPAWN_TILES: int = 3
const TILE_SIZE: int = 32


func _ready() -> void:
	# El terreno usa z_index=-4096 absoluto. Esta prueba debe quedar
	# inequívocamente delante de él, independientemente del orden de nodos.
	z_as_relative = false
	z_index = 4096
	visible = false
	call_deferred("_colocar_junto_al_spawn")


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

	print(
		"CasaPrueba: visible=", is_visible_in_tree(),
		" | textura=", texture.get_size() if texture != null else Vector2.ZERO,
		" | spawn=", spawn,
		" | posicion=", global_position,
		" | z_index=", z_index,
		" | viewport=", get_viewport_rect().size
	)
