extends Node2D
class_name WorldInteractable
## Interacción reutilizable para muebles y objetos del mundo.
## Los objetos solo declaran su tipo; el HUD y la ejecución son compartidos.

const CHEST_UI_SCRIPT = preload("res://scripts/ui/hogar_chest_inventory.gd")

enum ActionType { CHEST, BED }

var _action_type: ActionType = ActionType.CHEST
var _interaction_text := ""
var _interaction_distance := 72.0
var _storage_id := ""
var _storage_owner: Node = null
var _storage_index := -1
var _chest_ui: Node = null


func configurar_cofre(storage_id: String, storage_owner: Node = null, storage_index: int = -1) -> void:
	_action_type = ActionType.CHEST
	_interaction_text = "Abrir cofre"
	_interaction_distance = 88.0
	_storage_id = storage_id.strip_edges()
	_storage_owner = storage_owner
	_storage_index = storage_index
	add_to_group("interactable")


func configurar_cama(storage_owner: Node = null, storage_index: int = -1) -> void:
	_action_type = ActionType.BED
	_interaction_text = "Dormir"
	_interaction_distance = 72.0
	_storage_owner = storage_owner
	_storage_index = storage_index
	add_to_group("interactable")


func es_dialogable() -> bool:
	return true


func get_interaction_distance() -> float:
	return _interaction_distance


func get_interaction_priority() -> int:
	return 120


func get_interaction_text() -> String:
	return _interaction_text


func can_interact(jugador: Node) -> bool:
	if not is_visible_in_tree() or not is_instance_valid(jugador) or not jugador is Node2D:
		return false
	if _action_type == ActionType.CHEST:
		if esta_cofre_abierto():
			return false
		if is_instance_valid(_storage_owner) and _storage_owner.has_method("esta_cofre_abierto"):
			if bool(_storage_owner.call("esta_cofre_abierto")):
				return false
	if is_instance_valid(_storage_owner) and _storage_owner.has_method("puede_interactuar_mueble"):
		var tipo := "cofre" if _action_type == ActionType.CHEST else "cama"
		if not bool(_storage_owner.call("puede_interactuar_mueble", tipo, jugador, _storage_index)):
			return false
	return (jugador as Node2D).global_position.distance_to(global_position) <= _interaction_distance


func interact(jugador: Node) -> void:
	if not can_interact(jugador):
		return
	match _action_type:
		ActionType.CHEST:
			_abrir_cofre()
		ActionType.BED:
			_dormir()


func _abrir_cofre() -> void:
	var inventario := get_tree().get_first_node_in_group("inventory")
	if not is_instance_valid(inventario):
		push_warning("WorldInteractable: no se encontró el inventario del jugador.")
		return
	if _storage_owner != null and not is_instance_valid(_storage_owner):
		return
	if _storage_owner != null and (
		not _storage_owner.has_method("obtener_contenido_cofre")
		or not _storage_owner.has_method("establecer_contenido_cofre")
	):
		push_warning("WorldInteractable: el propietario no implementa el almacenamiento de cofres.")
		return

	var interfaz := CHEST_UI_SCRIPT.new() as CanvasLayer
	if not is_instance_valid(interfaz):
		return
	_chest_ui = interfaz
	var padre_interfaz := get_parent()
	if not is_instance_valid(padre_interfaz):
		padre_interfaz = get_tree().current_scene
	if not is_instance_valid(padre_interfaz):
		_chest_ui = null
		return
	padre_interfaz.add_child(interfaz)
	interfaz.call("abrir_contenedor", self, inventario)
	if is_instance_valid(_storage_owner) and _storage_owner.has_method("registrar_cofre_abierto"):
		_storage_owner.call("registrar_cofre_abierto", interfaz, self)


func obtener_contenido_cofre() -> Array:
	if is_instance_valid(_storage_owner):
		var contenido: Variant = _storage_owner.call("obtener_contenido_cofre", _storage_index)
		return contenido if contenido is Array else []
	var cofres_variant: Variant = GameState.world_state.flags.get("cofres_mundo", {})
	var cofres: Dictionary = cofres_variant.duplicate(true) if cofres_variant is Dictionary else {}
	var contenido_guardado: Variant = cofres.get(_storage_id, [])
	var resultado: Array = contenido_guardado.duplicate(true) if contenido_guardado is Array else []
	resultado.resize(32)
	return resultado


func establecer_contenido_cofre(objetos: Array) -> bool:
	var contenido := objetos.duplicate(true)
	contenido.resize(32)
	if is_instance_valid(_storage_owner):
		return bool(_storage_owner.call("establecer_contenido_cofre", _storage_index, contenido))
	if _storage_id.is_empty():
		push_warning("WorldInteractable: el cofre no tiene un identificador persistente.")
		return false
	var cofres_variant: Variant = GameState.world_state.flags.get("cofres_mundo", {})
	var cofres: Dictionary = cofres_variant.duplicate(true) if cofres_variant is Dictionary else {}
	cofres[_storage_id] = contenido
	GameState.world_state.flags["cofres_mundo"] = cofres
	if not GameState.active_save_id.is_empty():
		GameState.call_deferred("guardar_partida")
	return true


func esta_cofre_abierto() -> bool:
	return is_instance_valid(_chest_ui)


func cerrar_cofre() -> void:
	if not is_instance_valid(_chest_ui):
		_chest_ui = null
		return
	var interfaz := _chest_ui
	_chest_ui = null
	if is_instance_valid(_storage_owner) and _storage_owner.has_method("registrar_cofre_cerrado"):
		_storage_owner.call("registrar_cofre_cerrado", interfaz, self)
	if interfaz.is_in_group("modal_ui"):
		interfaz.remove_from_group("modal_ui")
	interfaz.queue_free()


func _dormir() -> void:
	var escena := get_tree().current_scene
	var atmosfera: Node = escena.find_child("WorldAtmosphere", true, false) if is_instance_valid(escena) else null
	if not is_instance_valid(atmosfera) or not atmosfera.has_method("dormir_hasta_manana"):
		push_warning("WorldInteractable: no se encontró el calendario para dormir.")
		return
	if not bool(atmosfera.call("dormir_hasta_manana")):
		push_warning("WorldInteractable: no se pudo dormir en el estado actual del calendario.")
