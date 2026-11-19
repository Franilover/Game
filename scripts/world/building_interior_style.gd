extends Node2D
## Acabado visual reutilizable para interiores de Torres.
## Dibuja suelos, paredes, zócalos y marcos sobre una retícula de 16 px.
## Las paletas son provisionales y están centralizadas para poder sustituirlas
## por atlas de tiles dibujados a mano sin cambiar la lógica de las habitaciones.

const TILE_SIZE := 16.0
const WALL_DEPTH := 28.0
const DOOR_LEFT := -14.0
const DOOR_RIGHT := 132.0

var _room_size := Vector2(512.0, 320.0)
var _style: Dictionary = {}


func configurar(tipo: String, dimensiones: Vector2, entrada_id: String = "") -> void:
	_room_size = Vector2(maxf(512.0, dimensiones.x), maxf(320.0, dimensiones.y))
	_style = _obtener_estilo(tipo, entrada_id)
	queue_redraw()


func _draw() -> void:
	_dibujar_suelo()
	_dibujar_paredes()


func _dibujar_suelo() -> void:
	var mitad := _room_size / 2.0
	var base: Color = _style.get("floor", Color("#88745b"))
	var junta: Color = _style.get("floor_joint", Color("#655744"))
	var detalle: Color = _style.get("floor_detail", Color("#a18a69"))
	var patron := str(_style.get("pattern", "wood"))
	var filas := int(_room_size.y / TILE_SIZE)
	var columnas := int(_room_size.x / TILE_SIZE)

	for fila in range(filas):
		for columna in range(columnas):
			var x := -mitad.x + float(columna) * TILE_SIZE
			var y := -mitad.y + float(fila) * TILE_SIZE
			draw_rect(Rect2(Vector2(x, y), Vector2(TILE_SIZE, TILE_SIZE)), base)

			match patron:
				"wood":
					draw_rect(Rect2(x, y + 14.0, TILE_SIZE, 2.0), junta)
					if posmod(fila, 2) == 0:
						draw_rect(Rect2(x + 7.0, y, 1.0, 14.0), junta)
					else:
						draw_rect(Rect2(x + 3.0, y, 1.0, 14.0), junta)
					draw_rect(Rect2(x + 2.0, y + 5.0, 5.0, 1.0), detalle)
				"stone":
					draw_rect(Rect2(x, y + 15.0, TILE_SIZE, 1.0), junta)
					var offset := 0.0 if posmod(fila, 2) == 0 else 8.0
					if posmod(columna, 2) == 0:
						draw_rect(Rect2(x + offset, y, 1.0, 15.0), junta)
				"tile":
					draw_rect(Rect2(x, y + 14.0, TILE_SIZE, 2.0), junta)
					draw_rect(Rect2(x + 14.0, y, 2.0, TILE_SIZE), junta)
					draw_rect(Rect2(x + 3.0, y + 3.0, 2.0, 2.0), detalle)
				"earth":
					if posmod(columna * 3 + fila * 5, 7) == 0:
						draw_rect(Rect2(x + 4.0, y + 5.0, 3.0, 2.0), detalle)
					if posmod(columna + fila * 2, 9) == 0:
						draw_rect(Rect2(x + 11.0, y + 11.0, 2.0, 2.0), junta)
				"garden":
					draw_rect(Rect2(x, y + 15.0, TILE_SIZE, 1.0), junta)
					if posmod(columna + fila, 4) == 0:
						draw_rect(Rect2(x + 3.0, y + 3.0, 2.0, 2.0), detalle)


func _dibujar_paredes() -> void:
	var mitad := _room_size / 2.0
	var pared: Color = _style.get("wall", Color("#b8a17b"))
	var sombra: Color = _style.get("wall_shadow", Color("#76634d"))
	var moldura: Color = _style.get("trim", Color("#5b4636"))
	var luz: Color = _style.get("trim_light", Color("#d0b887"))
	var ventana: Color = _style.get("window", Color("#66858a"))

	# Pared del fondo y laterales: el suelo queda visualmente contenido.
	draw_rect(Rect2(Vector2(-mitad.x, -mitad.y), Vector2(_room_size.x, WALL_DEPTH)), sombra)
	draw_rect(Rect2(Vector2(-mitad.x, -mitad.y), Vector2(_room_size.x, WALL_DEPTH - 5.0)), pared)
	draw_rect(Rect2(Vector2(-mitad.x, -mitad.y + WALL_DEPTH - 5.0), Vector2(_room_size.x, 5.0)), moldura)
	draw_rect(Rect2(Vector2(-mitad.x, -mitad.y), Vector2(WALL_DEPTH, _room_size.y)), sombra)
	draw_rect(Rect2(Vector2(-mitad.x, -mitad.y), Vector2(WALL_DEPTH - 5.0, _room_size.y)), pared)
	draw_rect(Rect2(Vector2(-mitad.x + WALL_DEPTH - 5.0, -mitad.y), Vector2(5.0, _room_size.y)), moldura)
	draw_rect(Rect2(Vector2(mitad.x - WALL_DEPTH, -mitad.y), Vector2(WALL_DEPTH, _room_size.y)), sombra)
	draw_rect(Rect2(Vector2(mitad.x - WALL_DEPTH + 5.0, -mitad.y), Vector2(WALL_DEPTH - 5.0, _room_size.y)), pared)
	draw_rect(Rect2(Vector2(mitad.x - WALL_DEPTH, -mitad.y), Vector2(5.0, _room_size.y)), moldura)

	# Pared frontal dividida para respetar la abertura real de entrada.
	var y_frente := mitad.y - WALL_DEPTH
	var ancho_izq := DOOR_LEFT + mitad.x
	var ancho_der := mitad.x - DOOR_RIGHT
	if ancho_izq > 0.0:
		draw_rect(Rect2(Vector2(-mitad.x, y_frente), Vector2(ancho_izq, WALL_DEPTH)), sombra)
		draw_rect(Rect2(Vector2(-mitad.x, y_frente), Vector2(ancho_izq, WALL_DEPTH - 5.0)), pared)
		draw_rect(Rect2(Vector2(-mitad.x, mitad.y - 5.0), Vector2(ancho_izq, 5.0)), moldura)
	if ancho_der > 0.0:
		draw_rect(Rect2(Vector2(DOOR_RIGHT, y_frente), Vector2(ancho_der, WALL_DEPTH)), sombra)
		draw_rect(Rect2(Vector2(DOOR_RIGHT, y_frente), Vector2(ancho_der, WALL_DEPTH - 5.0)), pared)
		draw_rect(Rect2(Vector2(DOOR_RIGHT, mitad.y - 5.0), Vector2(ancho_der, 5.0)), moldura)

	# Moldura superior y vigas cortas: cambian con la paleta del edificio.
	draw_rect(Rect2(Vector2(-mitad.x + WALL_DEPTH, -mitad.y + WALL_DEPTH), Vector2(_room_size.x - WALL_DEPTH * 2.0, 3.0)), moldura)
	draw_rect(Rect2(Vector2(-mitad.x + WALL_DEPTH, -mitad.y + WALL_DEPTH + 3.0), Vector2(_room_size.x - WALL_DEPTH * 2.0, 2.0)), luz)
	if bool(_style.get("windows", true)):
		var ventana_y := -mitad.y + 7.0
		for ventana_x in [-72.0, 40.0]:
			draw_rect(Rect2(Vector2(ventana_x - 18.0, ventana_y), Vector2(36.0, 13.0)), moldura)
			draw_rect(Rect2(Vector2(ventana_x - 15.0, ventana_y + 3.0), Vector2(30.0, 7.0)), ventana)
			draw_rect(Rect2(Vector2(ventana_x - 1.0, ventana_y + 3.0), Vector2(2.0, 7.0)), luz)


func _obtener_estilo(tipo: String, entrada_id: String) -> Dictionary:
	var estilo: Dictionary
	match tipo:
		"castillo":
			estilo = _perfil("stone", "#77756f", "#4e4d4a", "#9b8453", "#c6aa70", "#536b75", false)
		"archivo":
			estilo = _perfil("wood", "#80694f", "#4f3d2f", "#514235", "#9f8357", "#5e777d", true)
		"biblioteca":
			estilo = _perfil("wood", "#a18a68", "#69543d", "#67543e", "#b79a69", "#6d8587", true)
		"consejo":
			estilo = _perfil("stone", "#99917f", "#6c6558", "#665b4c", "#b9a16e", "#657b82", true)
		"cuartel":
			estilo = _perfil("stone", "#77766f", "#4c4b46", "#55534d", "#927b56", "#5e7478", false)
		"registro":
			estilo = _perfil("tile", "#aaa18e", "#746c5d", "#726653", "#b69a6b", "#71888b", true)
		"taberna":
			estilo = _perfil("wood", "#79563c", "#4e3729", "#62402e", "#a46b3e", "#647c78", true)
		"posada":
			estilo = _perfil("wood", "#a17a4f", "#65472f", "#806344", "#c89a5c", "#708c8b", true)
		"panaderia":
			estilo = _perfil("tile", "#b68c62", "#805c3e", "#8a6248", "#d0a56e", "#75877e", true)
		"escuela":
			estilo = _perfil("wood", "#b7a17d", "#7d684e", "#81745b", "#d0b98b", "#607d86", true)
		"forja":
			estilo = _perfil("stone", "#66645f", "#403f3c", "#4c4136", "#a46c3e", "#5a6d70", false)
		"taller":
			estilo = _perfil("wood", "#806b50", "#514431", "#62513d", "#a17d4d", "#667c78", false)
		"vivero":
			estilo = _perfil("garden", "#9a9a79", "#66684e", "#526044", "#c1b98a", "#6d8980", true)
		"herbolario":
			estilo = _perfil("tile", "#aaa17e", "#71694c", "#69704f", "#b6a879", "#6f8c7d", true)
		"clinica":
			estilo = _perfil("tile", "#c1b9a3", "#8b8576", "#756d5e", "#ded2b5", "#79969a", true)
		"comercio":
			estilo = _perfil("tile", "#a78b64", "#72583e", "#786044", "#c19a67", "#66817d", true)
		"carpinteria":
			estilo = _perfil("wood", "#99764f", "#624a34", "#725238", "#c19a67", "#66817d", true)
		"granero":
			estilo = _perfil("earth", "#927c5b", "#65543e", "#6b5034", "#b39462", "#6c8065", false)
		"molino":
			estilo = _perfil("wood", "#a18a63", "#6b5638", "#806044", "#c19b61", "#71816b", false)
		"corrales":
			estilo = _perfil("earth", "#82704f", "#5a4935", "#72583c", "#a88b59", "#6d8065", false)
		_:
			estilo = _perfil("wood", "#927957", "#5f4c38", "#6b5038", "#b99565", "#6d8580", true)

	# Las viviendas mantienen una base común, pero pequeñas variaciones de
	# moldura distinguen cada hogar sin inventar un sistema de decoración nuevo.
	if tipo == "vivienda":
		match entrada_id:
			"casa_bruna":
				estilo = _perfil("wood", "#8c6d4e", "#594431", "#73543c", "#76513d", "#71837c", true)
			"casa_elian":
				estilo = _perfil("wood", "#a18a65", "#6c563b", "#77714e", "#64765a", "#718b8a", true)
			"casa_darven":
				estilo = _perfil("wood", "#8b7b65", "#5b4d3c", "#5e5662", "#6b647d", "#75888c", false)
			"casa_saira":
				estilo = _perfil("tile", "#aa8d68", "#70563e", "#806348", "#8a6746", "#728a8b", true)
			"casa_narel":
				estilo = _perfil("wood", "#8d8b72", "#5d5b48", "#66716b", "#647b83", "#78918b", true)
	return estilo


func _perfil(patron: String, suelo: String, junta: String, pared: String, moldura: String, ventana: String, tiene_ventanas: bool) -> Dictionary:
	return {
		"pattern": patron,
		"floor": Color(suelo),
		"floor_joint": Color(junta),
		"floor_detail": Color(suelo).lightened(0.16),
		"wall": Color(pared),
		"wall_shadow": Color(pared).darkened(0.34),
		"trim": Color(moldura),
		"trim_light": Color(moldura).lightened(0.28),
		"window": Color(ventana),
		"windows": tiene_ventanas
	}
