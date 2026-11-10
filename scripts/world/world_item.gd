@tool
extends Node2D
class_name WorldItem

var datos_objeto: Dictionary = {}
var nombre: String = "Objeto"

const DISTANCIA_INTERACCION: float = 52.0

var _jugador: Player = null
var _inventario: GarliaInventory = null
var _mission_manager: MissionManager = null
@onready var _etiqueta: Label = get_node_or_null("InteractionLabel") as Label
@onready var _icono: Sprite2D = get_node_or_null("ItemIcon") as Sprite2D
var _etiqueta_visible: bool = false


func _ready() -> void:
	add_to_group("world_item")
	add_to_group("interactable")
	z_index = 10
	
	_actualizar_icono()
	queue_redraw()


func configurar_dependencias(jugador: Player, inventario: GarliaInventory, mission_manager: MissionManager) -> void:
	_jugador = jugador
	_inventario = inventario
	_mission_manager = mission_manager


func configurar(nuevos_datos: Dictionary) -> void:
	datos_objeto = nuevos_datos.duplicate(true)
	nombre = str(datos_objeto.get("nombre", "Objeto"))
	_registrar_coleccionable_expedicion()
	
	if is_instance_valid(_etiqueta):
		_etiqueta.text = "[ LMB ] · " + nombre
	
	_actualizar_icono()
	queue_redraw()


func obtener_datos() -> Dictionary:
	return datos_objeto.duplicate(true)


func es_recolectable() -> bool:
	return true


func get_interaction_distance() -> float:
	return DISTANCIA_INTERACCION


func get_interaction_priority() -> int:
	return 100


func esta_cerca(persona: Node2D) -> bool:
	if not is_instance_valid(persona):
		return false
	return global_position.distance_to(persona.global_position) <= DISTANCIA_INTERACCION


func _process(_delta: float) -> void:
	if not is_instance_valid(_jugador) or not is_instance_valid(_etiqueta):
		return
	
	var cerca: bool = esta_cerca(_jugador)
	if cerca == _etiqueta_visible:
		return
	
	_etiqueta_visible = cerca
	_etiqueta.visible = cerca


func _actualizar_icono() -> void:
	if not is_instance_valid(_icono) or datos_objeto.is_empty():
		return
	
	var textura: Texture2D = ItemIconResolver.obtener_icono(datos_objeto)
	_icono.texture = textura
	_icono.visible = textura != null


func _draw() -> void:
	# Solo dibujamos un respaldo cuando el objeto no tiene un icono local.
	if is_instance_valid(_icono) and _icono.visible:
		return
	
	var tipo: String = str(datos_objeto.get("tipo", "")).to_lower().strip_edges()
	var sombra := Color(0.04, 0.025, 0.015, 0.65)
	var borde := Color(0.18, 0.10, 0.05, 1.0)
	
	draw_rect(Rect2(-10.0, 8.0, 20.0, 5.0), sombra)
	
	match tipo:
		"arma":
			_dibujar_arma(borde)
		"armadura":
			_dibujar_armadura(borde)
		"herramienta":
			_dibujar_herramienta(borde)
		"recurso":
			_dibujar_recurso(borde)
		_:
			_dibujar_objeto_generico(borde)


func _dibujar_arma(borde: Color) -> void:
	var hoja := Color(0.72, 0.68, 0.56, 1.0)
	var empunadura := Color(0.34, 0.19, 0.09, 1.0)
	draw_rect(Rect2(-2.0, -17.0, 4.0, 21.0), hoja)
	draw_rect(Rect2(-5.0, 2.0, 10.0, 3.0), borde)
	draw_rect(Rect2(-2.0, 5.0, 4.0, 9.0), empunadura)
	draw_rect(Rect2(-3.0, 14.0, 6.0, 3.0), borde)


func _dibujar_armadura(borde: Color) -> void:
	var metal := Color(0.55, 0.57, 0.52, 1.0)
	draw_rect(Rect2(-10.0, -10.0, 20.0, 20.0), borde)
	draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), metal)
	draw_rect(Rect2(-3.0, -5.0, 6.0, 10.0), borde)


func _dibujar_herramienta(borde: Color) -> void:
	var madera := Color(0.48, 0.27, 0.12, 1.0)
	var metal := Color(0.68, 0.64, 0.52, 1.0)
	draw_rect(Rect2(-2.0, -13.0, 4.0, 26.0), madera)
	draw_rect(Rect2(-9.0, -15.0, 18.0, 6.0), borde)
	draw_rect(Rect2(-7.0, -14.0, 14.0, 4.0), metal)


func _dibujar_recurso(borde: Color) -> void:
	var pluma := Color(0.82, 0.82, 0.72, 1.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -14.0), Vector2(7.0, -5.0), Vector2(5.0, 8.0),
			Vector2(0.0, 14.0), Vector2(-5.0, 8.0), Vector2(-7.0, -5.0)
		]),
		pluma
	)
	draw_polyline(
		PackedVector2Array([Vector2(0.0, -14.0), Vector2(0.0, 14.0)]),
		borde,
		2.0
	)


func _dibujar_objeto_generico(borde: Color) -> void:
	var objeto := Color(0.69, 0.51, 0.25, 1.0)
	draw_rect(Rect2(-9.0, -9.0, 18.0, 18.0), borde)
	draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), objeto)
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), Color(0.85, 0.72, 0.42, 1.0))


func can_interact(persona: Node) -> bool:
	return persona is Node2D and esta_cerca(persona as Node2D)


func get_interaction_text() -> String:
	return "Recoger " + nombre


func interact(persona: Node) -> void:
	if not can_interact(persona):
		return
	
	var inventario: GarliaInventory = _inventario
	if inventario == null or not is_instance_valid(inventario):
		return
	
	var datos: Dictionary = obtener_datos()
	if datos.is_empty():
		return
	
	if not datos.has("cantidad"):
		datos["cantidad"] = 1
	
	if inventario.agregar_objeto(datos):
		_registrar_recoleccion_expedicion()
		var item_id := str(datos.get("id", datos.get("item_id", ""))).strip_edges()
		if not item_id.is_empty():
			if _mission_manager != null and is_instance_valid(_mission_manager):
				_mission_manager.registrar_recoleccion(item_id, int(datos.get("cantidad", 1)))
		queue_free()



func _registrar_coleccionable_expedicion() -> void:
	var expedicion_id := str(datos_objeto.get("expedicion_id", "")).strip_edges()
	var coleccionable_id := str(datos_objeto.get("expedicion_collectible_id", "")).strip_edges()
	if expedicion_id != "primera_expedicion" or coleccionable_id.is_empty():
		return
	var zone_manager := get_tree().get_first_node_in_group("zone_manager")
	if is_instance_valid(zone_manager) and zone_manager.has_method("registrar_coleccionable_requerido_expedicion"):
		zone_manager.call("registrar_coleccionable_requerido_expedicion", coleccionable_id)


func _registrar_recoleccion_expedicion() -> void:
	var expedicion_id := str(datos_objeto.get("expedicion_id", "")).strip_edges()
	var coleccionable_id := str(datos_objeto.get("expedicion_collectible_id", "")).strip_edges()
	if expedicion_id != "primera_expedicion" or coleccionable_id.is_empty():
		return
	var zone_manager := get_tree().get_first_node_in_group("zone_manager")
	if is_instance_valid(zone_manager) and zone_manager.has_method("registrar_coleccionable_recogido_expedicion"):
		zone_manager.call("registrar_coleccionable_recogido_expedicion", coleccionable_id)
