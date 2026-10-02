extends Node2D

signal interactuar(prop: Node2D)

var tipo = ""
var bioma = ""
var variante = 0
var semilla = 0
var interactuable = false
var datos = {}

func configurar(nuevo_tipo: String, nuevo_bioma: String, nueva_variante: int, nueva_semilla: int, nuevos_datos: Dictionary = {}) -> void:
	tipo = nuevo_tipo
	bioma = nuevo_bioma
	variante = nueva_variante
	semilla = nueva_semilla
	datos = nuevos_datos.duplicate(true)

	interactuable = tipo == "recurso" or tipo == "planta"

	remove_from_group("world_resource")
	remove_from_group("world_cave")
	remove_from_group("world_structure")

	if tipo == "recurso" or tipo == "planta":
		add_to_group("world_resource")
	elif tipo == "cueva":
		add_to_group("world_cave")
	elif tipo == "estructura":
		add_to_group("world_structure")

	queue_redraw()

func obtener_tipo() -> String:
	return tipo

func obtener_datos() -> Dictionary:
	return datos.duplicate(true)

func _ready() -> void:
	z_index = clampi(int(global_position.y / 8.0), -4096, 4096)

func _draw() -> void:
	match tipo:
		"arbol":
			_dibujar_arbol()
		"flor":
			_dibujar_flor()
		"planta":
			_dibujar_planta()
		"recurso":
			_dibujar_recurso()
		"cueva":
			_dibujar_cueva()
		"estructura":
			_dibujar_estructura()
		_:
			_dibujar_recurso()

func _dibujar_arbol() -> void:
	var oscuro = Color("#46382E")
	var medio = Color("#694F39")
	var claro = Color("#846345")
	var hoja_oscura = Color("#253A2B")
	var hoja_media = Color("#36563A")
	var hoja_clara = Color("#4B7044")

	_dibujar_elipse(Vector2(0, 15), Vector2(19, 6), Color(0, 0, 0, 0.18))

	draw_rect(Rect2(-6, -7, 12, 24), oscuro)
	draw_rect(Rect2(-3, -7, 6, 24), medio)
	draw_rect(Rect2(2, 0, 3, 11), claro)

	var offset = float((variante % 3) - 1) * 2.0

	draw_rect(Rect2(-19 + offset, -32, 38, 24), hoja_oscura)
	draw_rect(Rect2(-14 + offset, -39, 29, 29), hoja_media)
	draw_rect(Rect2(-8 + offset, -43, 17, 9), hoja_clara)
	draw_rect(Rect2(-22 + offset, -24, 44, 10), hoja_oscura)

	draw_rect(Rect2(-11 + offset, -31, 5, 5), hoja_clara)
	draw_rect(Rect2(7 + offset, -26, 5, 5), hoja_clara)

func _dibujar_flor() -> void:
	var tallo = Color("#3D5A32")
	var hoja = Color("#557446")
	var petalo_a = Color("#D9B7A5")
	var petalo_b = Color("#B98DA0")
	var centro = Color("#D7B95C")

	draw_rect(Rect2(-1, -1, 2, 13), tallo)
	draw_rect(Rect2(-5, 5, 5, 2), hoja)
	draw_rect(Rect2(0, 2, 5, 2), hoja)

	var color_flor = petalo_a if variante % 2 == 0 else petalo_b

	draw_rect(Rect2(-2, -9, 4, 7), color_flor)
	draw_rect(Rect2(-8, -6, 7, 4), color_flor)
	draw_rect(Rect2(2, -6, 7, 4), color_flor)
	draw_rect(Rect2(-2, -1, 4, 4), color_flor)
	draw_rect(Rect2(-2, -5, 4, 4), centro)

func _dibujar_planta() -> void:
	var tallo = Color("#3F5D31")
	var verde = Color("#527640")
	var claro = Color("#769A4F")
	var flor = Color("#D0B46F")

	if bioma == "Desierto":
		draw_rect(Rect2(-4, -17, 8, 31), verde)
		draw_rect(Rect2(-10, -8, 6, 17), verde)
		draw_rect(Rect2(4, -3, 6, 13), verde)
		draw_rect(Rect2(-3, -14, 3, 22), claro)
		return

	draw_rect(Rect2(-1, -15, 2, 15), tallo)
	draw_rect(Rect2(-10, -11, 9, 4), verde)
	draw_rect(Rect2(1, -14, 9, 4), verde)
	draw_rect(Rect2(-7, -6, 8, 4), claro)
	draw_rect(Rect2(1, -9, 7, 4), claro)

	if variante % 4 == 0:
		draw_rect(Rect2(-2, -21, 5, 5), flor)

func _dibujar_recurso() -> void:
	var sombra = Color(0, 0, 0, 0.18)
	var roca_oscura = Color("#4A4A43")
	var roca = Color("#6C6B61")
	var roca_clara = Color("#8B8879")

	_dibujar_elipse(Vector2(0, 7), Vector2(10, 4), sombra)

	var puntos = PackedVector2Array([
		Vector2(-9, 3),
		Vector2(-6, -6),
		Vector2(0, -10),
		Vector2(8, -5),
		Vector2(10, 3),
		Vector2(4, 8),
		Vector2(-5, 8)
	])

	draw_colored_polygon(puntos, roca_oscura)
	draw_rect(Rect2(-5, -5, 10, 11), roca)
	draw_rect(Rect2(-2, -7, 5, 4), roca_clara)
	draw_rect(Rect2(4, -2, 3, 5), roca_clara)

func _dibujar_cueva() -> void:
	var piedra_oscura = Color("#3A3935")
	var piedra = Color("#58574E")
	var piedra_clara = Color("#777367")
	var interior = Color("#11110F")

	var puntos = PackedVector2Array([
		Vector2(-28, 13),
		Vector2(-24, -9),
		Vector2(-13, -24),
		Vector2(0, -29),
		Vector2(15, -23),
		Vector2(26, -8),
		Vector2(30, 13)
	])

	draw_colored_polygon(puntos, piedra_oscura)

	var arco = PackedVector2Array([
		Vector2(-18, 12),
		Vector2(-15, -5),
		Vector2(-8, -15),
		Vector2(0, -19),
		Vector2(9, -15),
		Vector2(15, -5),
		Vector2(18, 12)
	])

	draw_colored_polygon(arco, piedra)

	var hueco = PackedVector2Array([
		Vector2(-12, 12),
		Vector2(-10, -2),
		Vector2(-5, -9),
		Vector2(0, -12),
		Vector2(6, -8),
		Vector2(10, -1),
		Vector2(12, 12)
	])

	draw_colored_polygon(hueco, interior)

	draw_rect(Rect2(-20, -3, 5, 4), piedra_clara)
	draw_rect(Rect2(15, 1, 5, 4), piedra_clara)

func _dibujar_estructura() -> void:
	var oscuro = Color("#40372E")
	var madera = Color("#68513C")
	var clara = Color("#8A6A4A")
	var techo = Color("#4E463D")

	_dibujar_elipse(Vector2(0, 10), Vector2(28, 7), Color(0, 0, 0, 0.20))

	draw_rect(Rect2(-25, -19, 50, 30), oscuro)
	draw_rect(Rect2(-20, -14, 40, 25), madera)

	var techo_puntos = PackedVector2Array([
		Vector2(-30, -17),
		Vector2(-20, -27),
		Vector2(-8, -21),
		Vector2(4, -29),
		Vector2(18, -22),
		Vector2(29, -15)
	])

	draw_colored_polygon(techo_puntos, techo)

	draw_rect(Rect2(-5, -4, 10, 15), oscuro)
	draw_rect(Rect2(-16, -9, 5, 5), clara)
	draw_rect(Rect2(12, -9, 5, 5), clara)

func _dibujar_elipse(centro: Vector2, radio: Vector2, color: Color) -> void:
	var puntos = PackedVector2Array()
	var segmentos = 20

	for i in range(segmentos):
		var angulo = TAU * float(i) / float(segmentos)
		puntos.append(centro + Vector2(cos(angulo) * radio.x, sin(angulo) * radio.y))

	draw_colored_polygon(puntos, color)
