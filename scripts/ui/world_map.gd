extends Control

const MAP_TILE_PIXELS: float = 8.0
const VIEW_TILES_X: int = 91
const VIEW_TILES_Y: int = 43
const EXPLORATION_RADIUS: int = 6

var _world_generator: Node = null
var _player: Node2D = null
var _explorado: Dictionary = {}
var _tile_size: int = 32
var _ultima_actualizacion: Vector2i = Vector2i(2147483647, 2147483647)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

	GameState.mapa_exploracion_actualizada.connect(
		_al_exploracion_actualizada
	)

	_buscar_dependencias()
	_refrescar()


func _process(_delta: float) -> void:
	if not visible:
		return

	if _world_generator == null or not is_instance_valid(_world_generator):
		_buscar_dependencias()
		_refrescar()
		return

	if _player == null or not is_instance_valid(_player):
		_buscar_dependencias()
		_refrescar()
		return

	var tile: Vector2i = _obtener_tile_jugador()

	if tile != _ultima_actualizacion:
		_ultima_actualizacion = tile
		_refrescar()


func _buscar_dependencias() -> void:
	_world_generator = get_tree().get_first_node_in_group(
		"world_generator"
	)
	_player = get_tree().get_first_node_in_group(
		"player"
	) as Node2D

	if _world_generator != null:
		if _world_generator.has_method("get_tile_size"):
			_tile_size = maxi(
				int(_world_generator.call("get_tile_size")),
				1
			)


func _refrescar() -> void:
	_explorado = GameState.obtener_terreno_explorado()
	queue_redraw()


func _al_exploracion_actualizada() -> void:
	_refrescar()


func _obtener_tile_jugador() -> Vector2i:
	if _player == null or not is_instance_valid(_player):
		return Vector2i.ZERO

	if _world_generator != null and _world_generator.has_method(
		"get_tile_at"
	):
		var tile_variant: Variant = _world_generator.call(
			"get_tile_at",
			_player.global_position
		)

		if tile_variant is Vector2i:
			return tile_variant as Vector2i

	return Vector2i.ZERO


func _clave_tile(tile: Vector2i) -> String:
	return str(tile.x) + "," + str(tile.y)


func _draw() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color("#191009"),
		true
	)

	var margen: float = 8.0
	var mapa_rect := Rect2(
		margen,
		32.0,
		size.x - margen * 2.0,
		size.y - 40.0
	)

	if mapa_rect.size.x <= 0.0 or mapa_rect.size.y <= 0.0:
		return

	draw_rect(
		mapa_rect,
		Color("#26170d"),
		true
	)

	var centro := _obtener_tile_jugador()
	var ancho: int = mini(
		VIEW_TILES_X,
		maxi(int(mapa_rect.size.x / MAP_TILE_PIXELS), 1)
	)
	var alto: int = mini(
		VIEW_TILES_Y,
		maxi(int(mapa_rect.size.y / MAP_TILE_PIXELS), 1)
	)

	var inicio_x: int = centro.x - ancho / 2
	var inicio_y: int = centro.y - alto / 2

	for y in range(alto):
		for x in range(ancho):
			var tile := Vector2i(
				inicio_x + x,
				inicio_y + y
			)

			var rect := Rect2(
				mapa_rect.position
				+ Vector2(
					float(x) * MAP_TILE_PIXELS,
					float(y) * MAP_TILE_PIXELS
				),
				Vector2(
					MAP_TILE_PIXELS + 0.2,
					MAP_TILE_PIXELS + 0.2
				)
			)

			if not _explorado.has(_clave_tile(tile)):
				draw_rect(
					rect,
					Color("#120b07"),
					true
				)
				continue

			draw_rect(
				rect,
				_color_zona(tile),
				true
			)

	var posicion_jugador := Vector2(
		mapa_rect.position.x
		+ float(centro.x - inicio_x) * MAP_TILE_PIXELS
		+ MAP_TILE_PIXELS * 0.5,
		mapa_rect.position.y
		+ float(centro.y - inicio_y) * MAP_TILE_PIXELS
		+ MAP_TILE_PIXELS * 0.5
	)

	draw_circle(
		posicion_jugador,
		3.0,
		Color("#d8b56a")
	)

	draw_circle(
		posicion_jugador,
		1.2,
		Color("#fff2c2")
	)


func _color_zona(tile: Vector2i) -> Color:
	if _world_generator == null:
		return Color("#6b5138")

	var zona_variant: Variant = _world_generator.call(
		"get_zona_at",
		tile
	)

	if not zona_variant is int:
		return Color("#6b5138")

	match int(zona_variant):
		0:
			return Color("#65714b")
		1:
			return Color("#806044")
		2:
			return Color("#77716a")
		3:
			return Color("#b5965e")
		4:
			return Color("#537078")
		5:
			return Color("#405c67")
		6:
			return Color("#8f7957")
		7:
			return Color("#b9b7a2")
		_:
			return Color("#6b5138")
