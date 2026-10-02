extends Node2D
class_name CombatProjectile


var direccion: Vector2 = Vector2.RIGHT
var velocidad: float = 280.0
var tiempo_vida: float = 3.0
var radio_impacto: float = 9.0
var danio: int = 8
var propietario: Node = null

var _tiempo_restante: float = 0.0


func _ready() -> void:
	z_index = 90
	_tiempo_restante = tiempo_vida
	queue_redraw()


func configurar(
	nueva_direccion: Vector2,
	nueva_velocidad: float,
	nueva_vida: float,
	nuevo_radio: float,
	nuevo_danio: int,
	nuevo_propietario: Node
) -> void:
	direccion = nueva_direccion

	if direccion.length_squared() <= 0.01:
		direccion = Vector2.RIGHT
	else:
		direccion = direccion.normalized()

	velocidad = maxf(
		nueva_velocidad,
		0.0
	)

	tiempo_vida = maxf(
		nueva_vida,
		0.01
	)

	radio_impacto = maxf(
		nuevo_radio,
		1.0
	)

	danio = maxi(
		nuevo_danio,
		0
	)

	propietario = nuevo_propietario

	rotation = direccion.angle()

	if is_inside_tree():
		_tiempo_restante = tiempo_vida
		queue_redraw()


func _physics_process(delta: float) -> void:
	var posicion_anterior: Vector2 = (
		global_position
	)

	_tiempo_restante -= delta

	if _tiempo_restante <= 0.0:
		queue_free()
		return

	global_position += (
		direccion
		* velocidad
		* delta
	)

	var objetivo: Node = _buscar_impacto(
		posicion_anterior,
		global_position
	)

	if objetivo == null:
		queue_redraw()
		return

	if objetivo.has_method("take_damage"):
		objetivo.call(
			"take_damage",
			danio
		)

		var visual: CanvasItem = (
			objetivo as CanvasItem
		)

		if visual != null:
			var original: Color = visual.modulate

			var tween := create_tween()

			tween.tween_property(
				visual,
				"modulate",
				Color(
					1.0,
					0.45,
					0.45,
					original.a
				),
				0.04
			)

			tween.tween_property(
				visual,
				"modulate",
				original,
				0.08
			)

		print(
			"CombatProjectile: impacto → ",
			objetivo.name,
			" por ",
			danio,
			" de daño."
		)

	queue_free()


func _buscar_impacto(
	inicio: Vector2,
	final: Vector2
) -> Node:
	var mejor: Node = null
	var mejor_distancia: float = INF

	for candidato in get_tree().get_nodes_in_group(
		"damageable"
	):
		if not is_instance_valid(candidato):
			continue

		if candidato == propietario:
			continue

		if not candidato is Node2D:
			continue

		if not candidato.is_inside_tree():
			continue

		if "is_alive" in candidato:
			if not bool(candidato.is_alive):
				continue

		var candidato_2d: Node2D = (
			candidato as Node2D
		)

		var distancia: float = (
			_distancia_a_segmento(
				candidato_2d.global_position,
				inicio,
				final
			)
		)

		if distancia > radio_impacto:
			continue

		var distancia_inicio: float = (
			candidato_2d.global_position
			.distance_to(inicio)
		)

		if distancia_inicio < mejor_distancia:
			mejor_distancia = distancia_inicio
			mejor = candidato

	return mejor


func _distancia_a_segmento(
	punto: Vector2,
	inicio: Vector2,
	final: Vector2
) -> float:
	var segmento: Vector2 = final - inicio
	var longitud_cuadrado: float = (
		segmento.length_squared()
	)

	if longitud_cuadrado <= 0.0001:
		return punto.distance_to(
			inicio
		)

	var t: float = clampf(
		(punto - inicio).dot(segmento)
		/ longitud_cuadrado,
		0.0,
		1.0
	)

	var proyeccion: Vector2 = (
		inicio
		+ segmento * t
	)

	return punto.distance_to(
		proyeccion
	)


func _draw() -> void:
	var asta_color := Color(
		0.35,
		0.20,
		0.10,
		1.0
	)

	var punta_color := Color(
		0.78,
		0.74,
		0.62,
		1.0
	)

	draw_line(
		Vector2(
			-12.0,
			0.0
		),
		Vector2(
			8.0,
			0.0
		),
		asta_color,
		2.0
	)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(
				13.0,
				0.0
			),
			Vector2(
				6.0,
				-3.0
			),
			Vector2(
				8.0,
				0.0
			),
			Vector2(
				6.0,
				3.0
			)
		]),
		punta_color
	)

	draw_line(
		Vector2(
			-7.0,
			-3.0
		),
		Vector2(
			-7.0,
			3.0
		),
		punta_color,
		1.0
	)
