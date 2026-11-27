@tool
extends Node2D
class_name FirstPerson25D

## Explorador 2.5D independiente para escenas diseñadas a mano.
## Usa un mapa de celdas, una textura de pared y Sprite2D como billboards.
## No participa en el streamer ni en la generación del mundo abierto.

@export_category("Mapa")
@export var mapa: PackedStringArray = [
	"1111111111",
	"1000000001",
	"1000000001",
	"1000000001",
	"1000000001",
	"1000000001",
	"1000000001",
	"1000000001",
	"1000000001",
	"1111111111"
]
@export_range(16.0, 256.0, 1.0) var tamano_celda: float = 64.0
@export var posicion_inicial: Vector2 = Vector2(160.0, 160.0)
@export_range(-360.0, 360.0, 1.0) var angulo_inicial: float = 0.0

@export_category("Texturas y aspecto")
@export var textura_pared: Texture2D = preload("res://assets/tilesets/Bosque.png")
@export var region_textura_pared: Rect2 = Rect2(0.0, 0.0, 32.0, 32.0)
@export var color_pared: Color = Color(0.72, 0.72, 0.72, 1.0)
@export var color_cielo: Color = Color(0.20, 0.25, 0.31, 1.0)
@export var color_suelo: Color = Color(0.25, 0.22, 0.18, 1.0)
@export_range(40, 480, 8) var cantidad_rayos: int = 240
@export_range(45.0, 100.0, 1.0) var campo_vision: float = 72.0

@export_category("Movimiento")
@export_range(30.0, 300.0, 5.0) var velocidad: float = 150.0
@export_range(0.0005, 0.01, 0.0005) var sensibilidad_raton: float = 0.0025
@export var capturar_raton_al_entrar: bool = true

var _posicion: Vector2 = Vector2.ZERO
var _angulo: float = 0.0
var _distancias_pared: PackedFloat32Array = PackedFloat32Array()
var _ultimo_tamano: Vector2 = Vector2.ZERO
var _mostrar_ayuda: bool = true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_posicion = posicion_inicial
	_angulo = deg_to_rad(angulo_inicial)
	if capturar_raton_al_entrar:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process(true)
	set_process_unhandled_input(true)
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_actualizar_movimiento(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mostrar_ayuda = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mostrar_ayuda = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_angulo += -event.relative.x * sensibilidad_raton
		_mostrar_ayuda = false


func _actualizar_movimiento(delta: float) -> void:
	var avance := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var lateral := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var direccion := Vector2(cos(_angulo), sin(_angulo))
	var derecha := Vector2(-direccion.y, direccion.x)
	var movimiento := (direccion * avance + derecha * lateral)
	if movimiento.length_squared() <= 0.0001:
		return
	movimiento = movimiento.normalized() * velocidad * delta
	var candidato_x := Vector2(_posicion.x + movimiento.x, _posicion.y)
	var candidato_y := Vector2(_posicion.x, _posicion.y + movimiento.y)
	if not _hay_colision(candidato_x):
		_posicion.x = candidato_x.x
	if not _hay_colision(candidato_y):
		_posicion.y = candidato_y.y


func _hay_colision(punto: Vector2) -> bool:
	var margen := tamano_celda * 0.16
	var muestras := [
		punto + Vector2(-margen, -margen),
		punto + Vector2(margen, -margen),
		punto + Vector2(-margen, margen),
		punto + Vector2(margen, margen)
	]
	for muestra in muestras:
		if _es_muro(muestra):
			return true
	return false


func _es_muro(punto: Vector2) -> bool:
	var celda_x := floori(punto.x / tamano_celda)
	var celda_y := floori(punto.y / tamano_celda)
	if celda_y < 0 or celda_y >= mapa.size():
		return true
	var fila := mapa[celda_y]
	if celda_x < 0 or celda_x >= fila.length():
		return true
	return fila.substr(celda_x, 1) != "0"


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var mitad := viewport_size.y * 0.5
	draw_rect(Rect2(Vector2.ZERO, Vector2(viewport_size.x, mitad)), color_cielo)
	draw_rect(Rect2(Vector2(0.0, mitad), Vector2(viewport_size.x, mitad)), color_suelo)
	_dibujar_suelo_perspectiva(viewport_size, mitad)
	_distancias_pared.resize(cantidad_rayos)
	var fov := deg_to_rad(campo_vision)
	var direccion := Vector2(cos(_angulo), sin(_angulo))
	var plano := Vector2(-direccion.y, direccion.x) * tan(fov * 0.5)
	var ancho_columna := viewport_size.x / float(cantidad_rayos)
	for indice in range(cantidad_rayos):
		var camara_x := 2.0 * (float(indice) + 0.5) / float(cantidad_rayos) - 1.0
		var rayo := direccion + plano * camara_x
		var impacto := _lanzar_rayo(rayo)
		var distancia: float = maxf(float(impacto.get("distancia", 0.001)), 0.001)
		_distancias_pared[indice] = distancia
		var altura := minf(viewport_size.y * 2.0, tamano_celda * viewport_size.x / (2.0 * tan(fov * 0.5) * distancia))
		var inicio_y := mitad - altura * 0.5
		var destino := Rect2(indice * ancho_columna, inicio_y, ancho_columna + 1.0, altura)
		_dibujar_columna_pared(destino, float(impacto.get("u", 0.0)), bool(impacto.get("lado_y", false)))
	_dibujar_billboards(viewport_size, fov, direccion, plano)
	if _mostrar_ayuda and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var texto := "Clic para mirar · WASD para moverte · ESC libera el ratón"
		draw_string(ThemeDB.fallback_font, Vector2(14.0, viewport_size.y - 18.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)


func _dibujar_suelo_perspectiva(tamano: Vector2, mitad: float) -> void:
	# Líneas de profundidad discretas para reforzar la lectura de perspectiva.
	for indice in range(1, 9):
		var proporcion := float(indice) / 9.0
		var y := mitad + (mitad * proporcion * proporcion)
		draw_line(Vector2(0.0, y), Vector2(tamano.x, y), color_suelo.lightened(0.08), 1.0)


func _lanzar_rayo(direccion_rayo: Vector2) -> Dictionary:
	var celda := Vector2i(floori(_posicion.x / tamano_celda), floori(_posicion.y / tamano_celda))
	var delta_x := INF if absf(direccion_rayo.x) < 0.000001 else absf(tamano_celda / direccion_rayo.x)
	var delta_y := INF if absf(direccion_rayo.y) < 0.000001 else absf(tamano_celda / direccion_rayo.y)
	var paso_x := -1 if direccion_rayo.x < 0.0 else 1
	var paso_y := -1 if direccion_rayo.y < 0.0 else 1
	var borde_x := (_posicion.x - float(celda.x) * tamano_celda) if paso_x < 0 else (float(celda.x + 1) * tamano_celda - _posicion.x)
	var borde_y := (_posicion.y - float(celda.y) * tamano_celda) if paso_y < 0 else (float(celda.y + 1) * tamano_celda - _posicion.y)
	var lado_x := borde_x / maxf(absf(direccion_rayo.x), 0.000001)
	var lado_y := borde_y / maxf(absf(direccion_rayo.y), 0.000001)
	var golpe_lateral := false
	var distancia := 0.0
	for intento in range(128):
		if lado_x < lado_y:
			lado_x += delta_x
			celda.x += paso_x
			golpe_lateral = false
			distancia = lado_x - delta_x
		else:
			lado_y += delta_y
			celda.y += paso_y
			golpe_lateral = true
			distancia = lado_y - delta_y
		if _celda_es_muro(celda):
			break
	var punto := _posicion + direccion_rayo * maxf(distancia, 0.001)
	var u := fposmod(punto.y if not golpe_lateral else punto.x, tamano_celda) / tamano_celda
	if (not golpe_lateral and direccion_rayo.x > 0.0) or (golpe_lateral and direccion_rayo.y < 0.0):
		u = 1.0 - u
	return {"distancia": maxf(distancia, 0.001), "u": u, "lado_y": golpe_lateral}


func _celda_es_muro(celda: Vector2i) -> bool:
	if celda.y < 0 or celda.y >= mapa.size():
		return true
	var fila := mapa[celda.y]
	if celda.x < 0 or celda.x >= fila.length():
		return true
	return fila.substr(celda.x, 1) != "0"


func _dibujar_columna_pared(destino: Rect2, u: float, es_lateral: bool) -> void:
	if textura_pared != null:
		var region := region_textura_pared
		var ancho_fuente := maxf(region.size.x, 1.0)
		var alto_fuente := maxf(region.size.y, 1.0)
		var columna_fuente := clampf(region.position.x + u * ancho_fuente, region.position.x, region.position.x + ancho_fuente - 1.0)
		var fuente := Rect2(columna_fuente, region.position.y, 1.0, alto_fuente)
		draw_texture_rect_region(textura_pared, destino, fuente, color_pared)
	else:
		draw_rect(destino, color_pared)
	if es_lateral:
		draw_rect(destino, Color(0.72, 0.72, 0.72, 0.18))


func _dibujar_billboards(tamano: Vector2, fov: float, direccion: Vector2, plano: Vector2) -> void:
	var contenedor := get_node_or_null("Billboards")
	if contenedor == null:
		return
	var proyeccion := tamano.x / (2.0 * tan(fov * 0.5))
	var objetos: Array[Dictionary] = []
	for nodo in contenedor.get_children():
		if nodo is Sprite2D and nodo.texture != null and nodo.visible:
			var relativo: Vector2 = (nodo as Sprite2D).position - _posicion
			var profundidad := relativo.dot(direccion)
			if profundidad > 4.0:
				objetos.append({"sprite": nodo, "profundidad": profundidad, "lateral": relativo.dot(plano.normalized())})
	objetos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["profundidad"]) > float(b["profundidad"])
	)
	for objeto in objetos:
		var sprite := objeto["sprite"] as Sprite2D
		var profundidad: float = float(objeto["profundidad"])
		var centro_x := tamano.x * 0.5 + (float(objeto["lateral"]) / profundidad) * proyeccion
		var altura := tamano_celda * proyeccion / profundidad * sprite.scale.y
		var textura := sprite.texture
		var ancho := altura * float(textura.get_width()) / maxf(float(textura.get_height()), 1.0) * sprite.scale.x
		var destino := Rect2(centro_x - ancho * 0.5, tamano.y * 0.5 - altura * 0.5 + sprite.position.y * 0.0, ancho, altura)
		var inicio := maxi(0, floori(destino.position.x / tamano.x * float(cantidad_rayos)))
		var fin := mini(cantidad_rayos - 1, ceili(destino.end.x / tamano.x * float(cantidad_rayos)))
		for columna in range(inicio, fin + 1):
			if columna >= _distancias_pared.size() or profundidad >= _distancias_pared[columna]:
				continue
			var x := float(columna) * tamano.x / float(cantidad_rayos)
			var proporcion := clampf((x - destino.position.x) / maxf(destino.size.x, 0.001), 0.0, 1.0)
			var fuente_x := proporcion * float(textura.get_width())
			var destino_columna := Rect2(x, destino.position.y, tamano.x / float(cantidad_rayos) + 1.0, destino.size.y)
			draw_texture_rect_region(textura, destino_columna, Rect2(fuente_x, 0.0, 1.0, float(textura.get_height())), sprite.modulate)


func reiniciar_posicion() -> void:
	_posicion = posicion_inicial
	_angulo = deg_to_rad(angulo_inicial)
	queue_redraw()
