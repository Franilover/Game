@tool
extends Node2D
class_name WorldItem

var datos_objeto: Dictionary = {}
var nombre: String = "Objeto"

const DISTANCIA_INTERACCION: float = 52.0
const DISTANCIA_RECOGIDA_AUTOMATICA: float = 18.0

var _jugador: Player = null
var _inventario: GarliaInventory = null
var _mission_manager: MissionManager = null
@onready var _etiqueta: Label = get_node_or_null("InteractionLabel") as Label
@onready var _icono: Sprite2D = get_node_or_null("ItemIcon") as Sprite2D
var _etiqueta_visible: bool = false
var _consumido_por_criatura: bool = false
var _recogida_automatica: bool = false
var _recogida_en_curso: bool = false


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
	_consumido_por_criatura = false
	datos_objeto = nuevos_datos.duplicate(true)
	nombre = str(datos_objeto.get("nombre", "Objeto"))
	_recogida_automatica = bool(datos_objeto.get("recogida_automatica", false))
	_registrar_coleccionable_expedicion()

	if _recogida_automatica:
		remove_from_group("interactable")
	if is_instance_valid(_etiqueta):
		_etiqueta.text = "[ LMB ] · " + nombre
		_etiqueta.visible = false
	
	_actualizar_icono()
	queue_redraw()


func obtener_datos() -> Dictionary:
	return datos_objeto.duplicate(true)


func es_recolectable() -> bool:
	return not _recogida_automatica and not _recogida_en_curso


func get_interaction_distance() -> float:
	return DISTANCIA_INTERACCION


func get_interaction_priority() -> int:
	return 100


func esta_cerca(persona: Node2D) -> bool:
	if not is_instance_valid(persona):
		return false
	return global_position.distance_to(persona.global_position) <= DISTANCIA_INTERACCION


func _process(_delta: float) -> void:
	if not is_instance_valid(_jugador):
		return

	if _recogida_automatica:
		if not _recogida_en_curso and global_position.distance_squared_to(_jugador.global_position) <= DISTANCIA_RECOGIDA_AUTOMATICA * DISTANCIA_RECOGIDA_AUTOMATICA:
			_recoger_automaticamente()
		return

	if not is_instance_valid(_etiqueta):
		return
	var cerca: bool = esta_cerca(_jugador)
	if cerca == _etiqueta_visible:
		return
	_etiqueta_visible = cerca
	_etiqueta.visible = cerca


func _recoger_automaticamente() -> void:
	if _recogida_en_curso or _consumido_por_criatura or datos_objeto.is_empty():
		return
	if not is_instance_valid(_inventario):
		return
	_recogida_en_curso = true
	var datos := obtener_datos()
	if not datos.has("cantidad"):
		datos["cantidad"] = 1
	datos.erase("recogida_automatica")
	if not _inventario.agregar_objeto(datos):
		_recogida_en_curso = false
		return

	_consumido_por_criatura = true
	_registrar_recoleccion_expedicion()
	var item_id := str(datos.get("item_id", datos.get("id", ""))).strip_edges()
	if not item_id.is_empty() and is_instance_valid(_mission_manager):
		_mission_manager.registrar_recoleccion(item_id, int(datos.get("cantidad", 1)))
	Events.notification_pushed.emit(
		"Recolectaste " + nombre + " x" + str(datos.get("cantidad", 1))
	)
	queue_free()


func _actualizar_icono() -> void:
	if not is_instance_valid(_icono) or datos_objeto.is_empty():
		return
	
	var textura: Texture2D = ItemIconResolver.obtener_icono(datos_objeto)
	_icono.texture = textura
	_icono.visible = textura != null


func _draw() -> void:
	# Los objetos del mundo sólo se representan mediante su sprite de assets.
	# No se dibujan armas, armaduras ni objetos genéricos con formas de código.
	pass


func consumir_por_criatura(item_ids_permitidos: Array) -> bool:
	if _consumido_por_criatura or datos_objeto.is_empty():
		return false
	var item_id := str(datos_objeto.get("item_id", datos_objeto.get("id", ""))).strip_edges()
	if item_id.is_empty() or item_id not in item_ids_permitidos:
		return false
	var cantidad := int(datos_objeto.get("cantidad", 1))
	if cantidad <= 0:
		return false
	if cantidad > 1:
		datos_objeto["cantidad"] = cantidad - 1
		_actualizar_icono()
		queue_redraw()
		return true
	_consumido_por_criatura = true
	queue_free()
	return true


func can_interact(persona: Node) -> bool:
	return not _recogida_automatica and not _recogida_en_curso and persona is Node2D and esta_cerca(persona as Node2D)


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
