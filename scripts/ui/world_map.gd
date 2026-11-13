extends Control

class_name WorldMapUI

const MAP_TILE_PIXELS_BASE: float = 8.0
const MAP_TILE_PIXELS_MIN: float = 4.0
const MAP_TILE_PIXELS_MAX: float = 24.0
const VIEW_TILES_X: int = 45
const VIEW_TILES_Y: int = 24
const EXPLORATION_RADIUS: int = 6

var _world_context: WorldContext = null
var _player: Node2D = null
var _explorado: Dictionary = {}
var _tile_size: int = 32
var _ultima_actualizacion: Vector2i = Vector2i(2147483647, 2147483647)
var _texturas: Dictionary = {}
var _zoom: float = 1.0
var _tipo_zona: String = "mundo_abierto"
var _zona_fija: Node = null
var _poligonos_fijos: Array[Polygon2D] = []
var _limites_mapa_fijo := Rect2()
var _tiempo_marcadores := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_actualizar_bloqueo_modal()

	GameState.mapa_exploracion_actualizada.connect(
		_al_exploracion_actualizada
	)

	_refrescar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_actualizar_bloqueo_modal()


func _actualizar_bloqueo_modal() -> void:
	if is_visible_in_tree():
		if not is_in_group("modal_ui"):
			add_to_group("modal_ui")
	elif is_in_group("modal_ui"):
		remove_from_group("modal_ui")


func configurar(jugador: Node2D, contexto: WorldContext) -> void:
	configurar_zona(jugador, contexto, "mundo_abierto", null)


func configurar_zona(jugador: Node2D, contexto: WorldContext, tipo_zona: String, zona: Node = null) -> void:
	_player = jugador
	_world_context = contexto
	_tipo_zona = tipo_zona
	_zona_fija = zona
	_poligonos_fijos.clear()
	_limites_mapa_fijo = Rect2()
	if _world_context != null:
		_tile_size = maxi(_world_context.get_tile_size(), 1)
	if _tipo_zona == "reino_torres" and is_instance_valid(_zona_fija):
		for nodo in _zona_fija.find_children("*", "Polygon2D", true, false):
			if nodo is Polygon2D:
				_poligonos_fijos.append(nodo as Polygon2D)
		_limites_mapa_fijo = Rect2(-1200.0, -700.0, 2400.0, 1400.0)
	elif _tipo_zona == "expedicion:bosque":
		_limites_mapa_fijo = Rect2(0.0, -1024.0, 5120.0, 2048.0)
	_ultima_actualizacion = Vector2i(2147483647, 2147483647)
	_refrescar()


func _process(delta: float) -> void:
	if not visible or _player == null:
		return
	if _tipo_zona == "reino_torres" or _tipo_zona == "expedicion:bosque":
		var posicion_jugador := _player.global_position
		var tile_fijo := Vector2i(floori(posicion_jugador.x / 32.0), floori(posicion_jugador.y / 32.0))
		if tile_fijo != _ultima_actualizacion:
			_ultima_actualizacion = tile_fijo
			queue_redraw()
		if _tipo_zona == "reino_torres":
			_tiempo_marcadores += delta
			if _tiempo_marcadores >= 0.5:
				_tiempo_marcadores = 0.0
				queue_redraw()
		return
	if _world_context == null:
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
	draw_rect(Rect2(Vector2.ZERO, size), Color("#191009"), true)
	var mapa_rect := Rect2(4.0, 20.0, size.x - 8.0, size.y - 24.0)
	if mapa_rect.size.x <= 0.0 or mapa_rect.size.y <= 0.0:
		return
	draw_rect(mapa_rect, Color("#26170d"), true)

	if _tipo_zona == "reino_torres" or _tipo_zona == "expedicion:bosque":
		_dibujar_mapa_zona_fija(mapa_rect)
		return

	var centro := _obtener_tile_jugador()
	var tile_pixels := MAP_TILE_PIXELS_BASE * _zoom
	var ancho: int = maxi(int(mapa_rect.size.x / tile_pixels), 1)
	var alto: int = maxi(int(mapa_rect.size.y / tile_pixels), 1)
	var inicio_x: int = centro.x - ancho / 2
	var inicio_y: int = centro.y - alto / 2
	for y in range(alto):
		for x in range(ancho):
			var tile := Vector2i(inicio_x + x, inicio_y + y)
			var rect := Rect2(mapa_rect.position + Vector2(float(x) * tile_pixels, float(y) * tile_pixels), Vector2(tile_pixels + 0.2, tile_pixels + 0.2))
			if not _explorado.has(_clave_tile(tile)):
				draw_rect(rect, Color("#120b07"), true)
				continue
			_dibujar_tile_real(tile, rect)
	var posicion_jugador := mapa_rect.position + Vector2(
		(float(centro.x - inicio_x) + 0.5) * tile_pixels,
		(float(centro.y - inicio_y) + 0.5) * tile_pixels
	)
	_dibujar_marcador_jugador(posicion_jugador)


func _dibujar_mapa_zona_fija(mapa_rect: Rect2) -> void:
	var limites := _limites_mapa_fijo
	if limites.size.x <= 0.0 or limites.size.y <= 0.0:
		return

	if _tipo_zona == "expedicion:bosque":
		_dibujar_mapa_bosque(mapa_rect, limites)
	else:
		for poligono in _poligonos_fijos:
			if not is_instance_valid(poligono) or poligono.polygon.size() < 3:
				continue
			var puntos: PackedVector2Array = PackedVector2Array()
			for punto in poligono.polygon:
				var punto_global := poligono.to_global(punto)
				var punto_local := _zona_fija.to_local(punto_global)
				puntos.append(_punto_a_mapa(punto_local, mapa_rect, limites))
			var color := poligono.color
			if color.a > 0.05:
				draw_colored_polygon(puntos, color)
			if puntos.size() >= 3:
				var contorno := PackedVector2Array(puntos)
				contorno.append(puntos[0])
				draw_polyline(contorno, Color("#302316", 0.45), 1.0, true)

	var posicion := limites.get_center()
	if is_instance_valid(_player) and is_instance_valid(_zona_fija):
		posicion = _zona_fija.to_local(_player.global_position)
	_dibujar_marcador_jugador(_punto_a_mapa(posicion, mapa_rect, limites))
	if _tipo_zona == "reino_torres":
		_dibujar_marcadores_aldeanos(mapa_rect, limites)
		_dibujar_leyenda_aldeanos()


func _dibujar_marcadores_aldeanos(mapa_rect: Rect2, limites: Rect2) -> void:
	if not is_instance_valid(_zona_fija):
		return

	var posiciones_edificios := {
		"plaza": Vector2(0.0, 0.0),
		"panaderia": Vector2(-205.0, -78.0),
		"forja": Vector2(-320.0, -122.0),
		"cuartel": Vector2(690.0, -248.0),
		"registro": Vector2(690.0, -170.0),
		"casa_comercio": Vector2(890.0, -260.0),
		"casa_estudio": Vector2(-370.0, -482.0),
		"archivo_real": Vector2(-130.0, -572.0),
		"casa_elian": Vector2(220.0, -117.0),
		"casa_bruna": Vector2(-235.0, 193.0),
		"casa_darven": Vector2(385.0, -108.0),
		"casa_saira": Vector2(385.0, 173.0),
		"casa_narel": Vector2(-520.0, -213.0),
		"castillo": Vector2(0.0, -125.0)
	}
	var aldeanos: Array[Node] = []
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if is_instance_valid(nodo) and nodo is Node2D:
			aldeanos.append(nodo)
	aldeanos.sort_custom(func(a: Node, b: Node) -> bool:
		var datos_a: Variant = a.get("datos")
		var datos_b: Variant = b.get("datos")
		var nombre_a := str(datos_a.get("nombre", a.name)) if datos_a is Dictionary else a.name
		var nombre_b := str(datos_b.get("nombre", b.name)) if datos_b is Dictionary else b.name
		return nombre_a.to_lower() < nombre_b.to_lower()
	)

	var paleta := [
		Color("#e5bd69"), Color("#8fc2a0"), Color("#d99579"),
		Color("#a9a0d4"), Color("#8ebbd1"), Color("#d6a7c5"),
		Color("#d1cf91")
	]
	var indice := 0
	for aldeano in aldeanos:
		var nombre := str(aldeano.call("get_nombre_visual")) if aldeano.has_method("get_nombre_visual") else aldeano.name
		var posicion_local: Vector2
		if bool(aldeano.get_meta("rutina_en_edificio", false)):
			var clave := str(aldeano.get_meta("rutina_ubicacion", ""))
			posicion_local = posiciones_edificios.get(clave, _zona_fija.to_local((aldeano as Node2D).global_position))
		else:
			posicion_local = _zona_fija.to_local((aldeano as Node2D).global_position)
		if not Rect2(limites.position, limites.size).has_point(posicion_local):
			continue
		var punto := _punto_a_mapa(posicion_local, mapa_rect, limites)
		var color: Color = paleta[indice % paleta.size()]
		indice += 1
		draw_circle(punto, 5.0, Color("#21170e"))
		draw_circle(punto, 3.6, color)
		draw_circle(punto, 1.2, Color("#fff2c2"))
		var fuente := ThemeDB.fallback_font
		if fuente != null:
			draw_string(fuente, punto + Vector2(7.0, 3.0), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#21170e"))
			draw_string(fuente, punto + Vector2(6.0, 2.0), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#f0dfbd"))


func _dibujar_leyenda_aldeanos() -> void:
	var fuente := ThemeDB.fallback_font
	if fuente == null:
		return
	draw_string(fuente, Vector2(10.0, 13.0), "TORRES · ALDEANOS EN TIEMPO REAL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#f0dfbd"))
	draw_circle(Vector2(size.x - 15.0, 12.0), 3.5, Color("#d8b56a"))
	draw_string(fuente, Vector2(size.x - 84.0, 13.0), "Tú", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#f0dfbd"))


func _dibujar_mapa_bosque(mapa_rect: Rect2, limites: Rect2) -> void:
	# La expedición tiene un mapa fijo de 160 x 64 celdas de 32 px.
	# Se representa su anillo boscoso y los senderos definidos por ForestMap.
	draw_rect(mapa_rect, Color("#64734a"), true)
	var ancho_bosque := limites.size.x * 5.0 / 160.0
	var alto_bosque := limites.size.y * 5.0 / 64.0
	draw_rect(Rect2(mapa_rect.position, Vector2(mapa_rect.size.x, mapa_rect.size.y * alto_bosque / limites.size.y)), Color("#29472d"), true)
	draw_rect(Rect2(mapa_rect.position + Vector2(0.0, mapa_rect.size.y - mapa_rect.size.y * alto_bosque / limites.size.y), Vector2(mapa_rect.size.x, mapa_rect.size.y * alto_bosque / limites.size.y)), Color("#29472d"), true)
	draw_rect(Rect2(mapa_rect.position, Vector2(mapa_rect.size.x * ancho_bosque / limites.size.x, mapa_rect.size.y)), Color("#29472d"), true)
	draw_rect(Rect2(mapa_rect.position + Vector2(mapa_rect.size.x - mapa_rect.size.x * ancho_bosque / limites.size.x, 0.0), Vector2(mapa_rect.size.x * ancho_bosque / limites.size.x, mapa_rect.size.y)), Color("#29472d"), true)

	var sendero := PackedVector2Array()
	var puntos_mundo := [
		Vector2(560, 120), Vector2(820, 120), Vector2(1080, 120),
		Vector2(1360, 40), Vector2(1600, -80), Vector2(1800, -160),
		Vector2(2080, -80), Vector2(2380, 20), Vector2(2680, 120),
		Vector2(3100, 120), Vector2(3600, 120), Vector2(4040, 120),
		Vector2(4480, 120)
	]
	for punto in puntos_mundo:
		sendero.append(_punto_a_mapa(punto, mapa_rect, limites))
	draw_polyline(sendero, Color("#9b7950"), 4.0, true)
	draw_polyline(sendero, Color("#c2a477"), 1.2, true)
	var desvio := PackedVector2Array([
		_punto_a_mapa(Vector2(1800, -160), mapa_rect, limites),
		_punto_a_mapa(Vector2(1880, -300), mapa_rect, limites),
		_punto_a_mapa(Vector2(1980, -560), mapa_rect, limites)
	])
	draw_polyline(desvio, Color("#9b7950"), 2.0, true)


func _punto_a_mapa(punto: Vector2, mapa_rect: Rect2, limites: Rect2) -> Vector2:
	return mapa_rect.position + Vector2(
		(punto.x - limites.position.x) / limites.size.x * mapa_rect.size.x,
		(punto.y - limites.position.y) / limites.size.y * mapa_rect.size.y
	)


func _dibujar_marcador_jugador(posicion: Vector2) -> void:
	draw_circle(posicion, 4.0, Color("#21170e"))
	draw_circle(posicion, 2.8, Color("#d8b56a"))
	draw_circle(posicion, 1.2, Color("#fff2c2"))



func _dibujar_tile_real(tile: Vector2i, rect: Rect2) -> void:
	# Cada celda explorada se representa con el bioma real del WorldContext.
	# Esta función es la que conecta el mapa procedural con sus datos de terreno.
	var color_zona := _color_zona(tile)
	draw_rect(rect, color_zona, true)

	# Borde discreto para conservar la lectura de cuadrícula cuando hay espacio.
	if rect.size.x >= 6.0 and rect.size.y >= 6.0:
		draw_rect(rect, Color(0.08, 0.055, 0.035, 0.28), false, 0.6)


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
		8:
			return Color("#254b2c")
		_:
			return Color("#6b5138")
