extends Node2D

var datos_objeto: Dictionary = {}
var nombre: String = "Objeto"

const DISTANCIA_INTERACCION: float = 52.0

var _jugador: Node2D
var _etiqueta: Label
var _etiqueta_visible: bool = false


func _ready() -> void:
	add_to_group("world_item")
	add_to_group("interactable")

	z_index = 10

	_crear_etiqueta()
	queue_redraw()


func configurar(nuevos_datos: Dictionary) -> void:
	datos_objeto = nuevos_datos.duplicate(true)

	nombre = str(
		datos_objeto.get("nombre", "Objeto")
	)

	if is_instance_valid(_etiqueta):
		_etiqueta.text = "E · " + nombre

	queue_redraw()


func obtener_datos() -> Dictionary:
	return datos_objeto.duplicate(true)


func esta_cerca(persona: Node2D) -> bool:
	if not is_instance_valid(persona):
		return false

	return global_position.distance_to(
		persona.global_position
	) <= DISTANCIA_INTERACCION


func _process(_delta: float) -> void:
	if not is_instance_valid(_jugador):
		var encontrado := get_tree().get_first_node_in_group("player")

		if encontrado is Node2D:
			_jugador = encontrado as Node2D

	if not is_instance_valid(_jugador):
		return

	var cerca := esta_cerca(_jugador)

	if cerca == _etiqueta_visible:
		return

	_etiqueta_visible = cerca
	_etiqueta.visible = cerca


func _crear_etiqueta() -> void:
	_etiqueta = Label.new()

	_etiqueta.text = "E · " + nombre
	_etiqueta.position = Vector2(-80.0, -42.0)
	_etiqueta.size = Vector2(160.0, 24.0)

	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiqueta.visible = false

	_etiqueta.add_theme_font_size_override(
		"font_size",
		10
	)

	_etiqueta.add_theme_color_override(
		"font_color",
		Color(0.93, 0.86, 0.68, 1.0)
	)

	_etiqueta.add_theme_color_override(
		"font_shadow_color",
		Color(0.08, 0.05, 0.03, 1.0)
	)

	_etiqueta.add_theme_constant_override(
		"shadow_offset_x",
		1
	)

	_etiqueta.add_theme_constant_override(
		"shadow_offset_y",
		1
	)

	add_child(_etiqueta)


func _draw() -> void:
	var categoria := str(
		datos_objeto.get("categoria", "")
	).to_lower()

	var sombra := Color(0.04, 0.025, 0.015, 0.65)
	var borde := Color(0.18, 0.10, 0.05, 1.0)

	draw_rect(
		Rect2(-10.0, 8.0, 20.0, 5.0),
		sombra
	)

	if "arma" in categoria:
		_dibujar_arma(borde)
	elif "armadura" in categoria:
		_dibujar_armadura(borde)
	elif "herramienta" in categoria:
		_dibujar_herramienta(borde)
	else:
		_dibujar_objeto_generico(borde)


func _dibujar_arma(borde: Color) -> void:
	var hoja := Color(0.72, 0.68, 0.56, 1.0)
	var empunadura := Color(0.34, 0.19, 0.09, 1.0)

	draw_rect(
		Rect2(-2.0, -17.0, 4.0, 21.0),
		hoja
	)

	draw_rect(
		Rect2(-5.0, 2.0, 10.0, 3.0),
		borde
	)

	draw_rect(
		Rect2(-2.0, 5.0, 4.0, 9.0),
		empunadura
	)

	draw_rect(
		Rect2(-3.0, 14.0, 6.0, 3.0),
		borde
	)


func _dibujar_armadura(borde: Color) -> void:
	var metal := Color(0.55, 0.57, 0.52, 1.0)

	draw_rect(
		Rect2(-10.0, -10.0, 20.0, 20.0),
		borde
	)

	draw_rect(
		Rect2(-8.0, -8.0, 16.0, 16.0),
		metal
	)

	draw_rect(
		Rect2(-3.0, -5.0, 6.0, 10.0),
		borde
	)


func _dibujar_herramienta(borde: Color) -> void:
	var madera := Color(0.48, 0.27, 0.12, 1.0)
	var metal := Color(0.68, 0.64, 0.52, 1.0)

	draw_rect(
		Rect2(-2.0, -13.0, 4.0, 26.0),
		madera
	)

	draw_rect(
		Rect2(-9.0, -15.0, 18.0, 6.0),
		borde
	)

	draw_rect(
		Rect2(-7.0, -14.0, 14.0, 4.0),
		metal
	)


func _dibujar_objeto_generico(borde: Color) -> void:
	var objeto := Color(0.69, 0.51, 0.25, 1.0)

	draw_rect(
		Rect2(-9.0, -9.0, 18.0, 18.0),
		borde
	)

	draw_rect(
		Rect2(-7.0, -7.0, 14.0, 14.0),
		objeto
	)

	draw_rect(
		Rect2(-3.0, -3.0, 6.0, 6.0),
		Color(0.85, 0.72, 0.42, 1.0)
	)


func can_interact(persona: Node) -> bool:
	return persona is Node2D and esta_cerca(persona as Node2D)


func get_interaction_text() -> String:
	return "Recoger " + nombre


func interact(persona: Node) -> void:
	if not can_interact(persona):
		return

	var inventario := get_tree().get_first_node_in_group("inventory")
	if inventario == null or not inventario.has_method("agregar_objeto"):
		return

	var datos := obtener_datos()
	if datos.is_empty():
		return
	if not datos.has("cantidad"):
		datos["cantidad"] = 1

	if bool(inventario.call("agregar_objeto", datos)):
		queue_free()
