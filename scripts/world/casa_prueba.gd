extends Sprite2D
## Casa temporal de integración visual. No forma parte del catálogo canónico.
## Se coloca junto al spawn sólo para verificar el asset en el mapa jugable.

const DISTANCIA_DESDE_SPAWN_TILES: int = 3
const TILE_SIZE: int = 32


func _ready() -> void:
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

	global_position = generador.get_spawn_position() + Vector2(
		DISTANCIA_DESDE_SPAWN_TILES * TILE_SIZE,
		0
	)
	visible = true
	print("CasaPrueba: Casa.png visible junto al spawn en ", global_position)
