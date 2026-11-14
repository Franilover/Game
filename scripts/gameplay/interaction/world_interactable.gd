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
var _durmiendo: bool = false


func configurar_cofre(storage_id: String, storage_owner: Node = null, storage_index: int = -1) -> void:
	_action_type = ActionType.CHEST
	_interaction_text = "Abrir"
	_interaction_distance = 48.0
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
	if _action_type == ActionType.BED and not _es_de_noche():
		return "Solo dormir de noche"
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


func _obtener_atmosfera() -> Node:
	return get_tree().root.find_child("WorldAtmosphere", true, false)


func _es_de_noche() -> bool:
	var atmosfera := _obtener_atmosfera()
	if not is_instance_valid(atmosfera) or not atmosfera.has_method("obtener_tiempo"):
		return false
	var tiempo: Dictionary = atmosfera.call("obtener_tiempo")
	if not bool(tiempo.get("calendario_cargado", false)):
		return false
	var horas_por_dia := maxf(float(tiempo.get("horas_por_dia", 24.0)), 1.0)
	var hora_normalizada := fposmod(float(tiempo.get("hora_del_dia", 0.0)) / horas_por_dia, 1.0)
	# Mantiene el mismo tramo nocturno que utiliza la iluminación de Torres.
	return hora_normalizada >= 0.82 or hora_normalizada < 0.20


func _dormir() -> void:
	if _durmiendo:
		return
	var atmosfera := _obtener_atmosfera()
	if not is_instance_valid(atmosfera) or not atmosfera.has_method("dormir_hasta_manana"):
		push_warning("WorldInteractable: no se encontró el calendario para dormir.")
		return
	if not _es_de_noche():
		# Durante el día la cama sigue mostrando por qué no está disponible.
		return

	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(jugador):
		return

	_durmiendo = true
	var visual := jugador.get_node_or_null("Visual") as Node2D
	var posicion_visual := visual.position if is_instance_valid(visual) else Vector2.ZERO
	var escala_visual := visual.scale if is_instance_valid(visual) else Vector2.ONE
	var fisica_activa := jugador.is_physics_processing()
	var input_activo := jugador.is_processing_input()
	var input_no_manejado_activo := jugador.is_processing_unhandled_input()

	# Detener al personaje durante la pequeña animación para que no se desplace
	# mientras cierra los ojos y se queda dormido.
	jugador.set_physics_process(false)
	jugador.set_process_input(false)
	jugador.set_process_unhandled_input(false)

	var capa := CanvasLayer.new()
	capa.name = "TransicionDormir"
	capa.layer = 100
	var fundido := ColorRect.new()
	fundido.name = "CerrarOjos"
	fundido.color = Color(0.0, 0.0, 0.0, 0.0)
	fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fundido)
	var escena := get_tree().current_scene
	if not is_instance_valid(escena):
		escena = get_tree().root
	escena.add_child(capa)
	capa.add_to_group("modal_ui")

	var tween := create_tween()
	tween.set_parallel(true)
	if is_instance_valid(visual):
		tween.tween_property(visual, "position", posicion_visual + Vector2(0.0, 7.0), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(visual, "scale", Vector2(escala_visual.x, escala_visual.y * 0.78), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fundido, "color:a", 1.0, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	# La pantalla queda a oscuras durante el salto al día siguiente.
	var pudo_dormir := bool(atmosfera.call("dormir_hasta_manana"))
	if pudo_dormir and jugador.has_method("recuperar_cargas_por_descanso"):
		jugador.call("recuperar_cargas_por_descanso")
	if is_instance_valid(visual):
		visual.position = posicion_visual
		visual.scale = escala_visual

	jugador.set_physics_process(fisica_activa)
	jugador.set_process_input(input_activo)
	jugador.set_process_unhandled_input(input_no_manejado_activo)

	if pudo_dormir:
		await get_tree().create_timer(0.18).timeout
	else:
		push_warning("WorldInteractable: no se pudo dormir en el estado actual del calendario.")

	var salida := create_tween()
	salida.tween_property(fundido, "color:a", 0.0, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await salida.finished
	if is_instance_valid(capa):
		capa.queue_free()
	_durmiendo = false
