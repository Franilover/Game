extends Control

class_name WorldMapUI

const MAP_TILE_PIXELS_BASE: float = 8.0
const MAP_TILE_PIXELS_MIN: float = 4.0
const MAP_TILE_PIXELS_MAX: float = 24.0
const VIEW_TILES_X: int = 91
const VIEW_TILES_Y: int = 43
const EXPLORATION_RADIUS: int = 6

var _world_context: WorldContext = null
var _player: Node2D = null
var _explorado: Dictionary = {}
var _tile_size: int = 32
var _ultima_actualizacion: Vector2i = Vector2i(2147483647, 2147483647)
var _texturas: Dictionary = {}
var _zoom: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

	GameState.mapa_exploracion_actualizada.connect(
		_al_exploracion_actualizada
	)

	_refrescar()


func configurar(jugador: Node2D, contexto: WorldContext) -> void:
	_player = jugador
	_world_context = contexto
	if _world_context != null:
		_tile_size = maxi(_world_context.get_tile_size(), 1)
	_refrescar()


func _process(_delta: float) -> void:
	if not visible or _world_context == null or _player == null:
		return

	if not is_instance_valid(_world_context) or not is_instance_valid(_player):
		return

	var tile: Vector2i = _obtener_tile_jugador()
	if tile != _ultima_actualizacion:
		_ultima_actualizacion = tile
		_refrescar()


func _refrescar() -> void:
	_explorado = GameState.obtener_terreno_explorado()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var rueda := event as InputEventMouseButton
		if rueda.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = minf(_zoom + 0.125, MAP_TILE_PIXELS_MAX / MAP_TILE_PIXELS_BASE)
			accept_event()
			queue_redraw()
		elif rueda.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxf(_zoom - 0.125, MAP_TILE_PIXELS_MIN / MAP_TILE_PIXELS_BASE)
			accept_event()
			queue_redraw()
	elif event is InputEventMagnifyGesture:
		var gesto := event as InputEventMagnifyGesture
		_zoom = clampf(_zoom * gesto.factor, MAP_TILE_PIXELS_MIN / MAP_TILE_PIXELS_BASE, MAP_TILE_PIXELS_MAX / MAP_TILE_PIXELS_BASE)
		accept_event()
		queue_redraw()


func _al_exploracion_actualizada() -> void:
	_refrescar()


func _obtener_tile_jugador() -> Vector2i:
	if _player == null or not is_instance_valid(_player):
		return Vector2i.ZERO

	if _world_context != null:
		var tile_variant: Vector2i = _world_context.get_tile_at(_player.global_position)

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
	var tile_pixels := MAP_TILE_PIXELS_BASE * _zoom
	var ancho: int = maxi(int(mapa_rect.size.x / tile_pixels), 1)
	var alto: int = maxi(int(mapa_rect.size.y / tile_pixels), 1)

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
					float(x) * tile_pixels,
					float(y) * tile_pixels
				),
				Vector2(
					tile_pixels + 0.2,
					tile_pixels + 0.2
				)
			)

			if not _explorado.has(_clave_tile(tile)):
				draw_rect(
					rect,
					Color("#120b07"),
					true
				)
				continue

			_dibujar_tile_real(tile, rect)

	var posicion_jugador := Vector2(
		mapa_rect.position.x
		+ float(centro.x - inicio_x) * tile_pixels
		+ tile_pixels * 0.5,
		mapa_rect.position.y
		+ float(centro.y - inicio_y) * tile_pixels
		+ tile_pixels * 0.5
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


func _dibujar_tile_real(tile: Vector2i, rect: Rect2) -> void:
	if _world_context == null:
		return

	var zona: int = _world_context.get_zona_at(tile)
	var textura: Texture2D = _obtener_textura_zona(tile, zona)
	if textura == null:
		draw_rect(rect, Color("#120b07"), true)
		return

	# El mundo usa atlas 4x4 de 32x32. Tomamos exactamente la misma
	# celda base que WorldTerrainVisual usa para el terreno.
	var region := Rect2(3.0 * float(_tile_size_real()), 3.0 * float(_tile_size_real()), float(_tile_size_real()), float(_tile_size_real()))
	draw_texture_rect_region(textura, rect, region)


func _tile_size_real() -> int:
	if _world_context != null:
		return maxi(_world_context.get_tile_size(), 1)
	return maxi(_tile_size, 1)


func _obtener_textura_zona(tile: Vector2i, zona: int) -> Texture2D:
	var bioma_variant: Dictionary = _world_context.get_bioma_at(tile)
	var bioma_nombre := ""
	if bioma_variant is Dictionary:
		bioma_nombre = str((bioma_variant as Dictionary).get("nombre", "")).strip_edges()

	var clave := bioma_nombre + "::" + str(zona)
	if _texturas.has(clave):
		return _texturas[clave]

	# Reutiliza los atlas canónicos del renderer de terreno; no aproxima
	# una zona con texturas genéricas de otro nombre.
	var paths: Array[String] = []
	if not bioma_nombre.is_empty():
		paths.append("res://assets/tilesets/" + bioma_nombre + ".png")
	var rutas_zona: Array[String] = [
		"res://assets/tilesets/Pradera.png",
		"res://assets/tilesets/Tierra.png",
		"res://assets/tilesets/Montaña.png",
		"res://assets/tilesets/Desierto.png",
		"res://assets/tilesets/Marino.png",
		"res://assets/tilesets/Marino.png",
		"res://assets/tilesets/Marino.png",
		"res://assets/tilesets/Montaña.png",
		"res://assets/tilesets/Bosque.png",
		"res://assets/tilesets/Desierto.png"
	]
	if zona >= 0 and zona < rutas_zona.size():
		paths.append(rutas_zona[zona])

	var textura: Texture2D = null
	for path in paths:
		textura = load(path) as Texture2D
		if textura != null and textura.get_width() >= _tile_size_real() * 4 and textura.get_height() >= _tile_size_real() * 4:
			break
		textura = null

	_texturas[clave] = textura
	return textura


func _color_zona(tile: Vector2i) -> Color:
	if _world_context == null:
		return Color("#6b5138")

	var zona_variant: int = _world_context.get_zona_at(tile)

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
