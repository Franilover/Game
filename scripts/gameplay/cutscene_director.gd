extends Node
class_name CutsceneDirector

## Reproduce secuencias declarativas usando los sistemas existentes.
## Cada paso es un Dictionary; las secuencias pueden venir de archivos,
## misiones o datos remotos sin acoplar el director a Supabase.

signal cinematica_iniciada(clave: String)
signal cinematica_finalizada(clave: String)
signal evento_solicitado(evento: String, datos: Dictionary)

var _player: Player = null
var _dialogue: DialogueSystem = null
var _camera: Camera2D = null
var _ocupado: bool = false
var _generacion: int = 0
var _clave_actual: String = ""
var _tween_camara: Tween = null
var _zoom_original := Vector2.ONE


func configurar(player: Player, dialogue: DialogueSystem, camera: Camera2D = null) -> void:
	_player = player
	_dialogue = dialogue
	_camera = camera
	if is_instance_valid(_camera):
		_zoom_original = _camera.zoom


func esta_activo() -> bool:
	return _ocupado


func obtener_clave_actual() -> String:
	return _clave_actual


func ejecutar(clave: String, pasos: Array) -> bool:
	var clave_limpia := clave.strip_edges()
	if _ocupado or clave_limpia.is_empty() or pasos.is_empty():
		return false
	if not is_instance_valid(_player) or not is_instance_valid(_dialogue):
		push_warning("CutsceneDirector: faltan Player o DialogueSystem.")
		return false

	_generacion += 1
	var generacion_actual := _generacion
	_ocupado = true
	_clave_actual = clave_limpia
	if not is_in_group("modal_ui"):
		add_to_group("modal_ui")
	cinematica_iniciada.emit(_clave_actual)

	for paso_variant in pasos:
		if generacion_actual != _generacion:
			return false
		if not paso_variant is Dictionary:
			continue
		var paso := paso_variant as Dictionary
		var tipo := str(paso.get("tipo", "")).strip_edges().to_lower()

		match tipo:
			"dialogo":
				var datos_variant: Variant = paso.get("datos", paso)
				if not datos_variant is Dictionary:
					continue
				if _dialogue.abrir(datos_variant as Dictionary):
					await _dialogue.dialogue_finished
					if generacion_actual != _generacion:
						return false
			"esperar":
				var duracion := clampf(float(paso.get("segundos", 0.5)), 0.0, 60.0)
				if duracion > 0.0:
					await get_tree().create_timer(duracion).timeout
					if generacion_actual != _generacion:
						return false
			"camara":
				await _ejecutar_movimiento_camara(paso)
				if generacion_actual != _generacion:
					return false
			"gesto_npc":
				await _ejecutar_gesto_npc(paso)
				if generacion_actual != _generacion:
					return false
			"mirar_npc":
				_ejecutar_mirar_npc(paso)
			"mover_npc":
				await _ejecutar_mover_npc(paso, generacion_actual)
				if generacion_actual != _generacion:
					return false
			"evento":
				var evento := str(paso.get("clave", "")).strip_edges()
				if not evento.is_empty():
					var datos_evento: Variant = paso.get("datos", {})
					evento_solicitado.emit(evento, datos_evento.duplicate(true) if datos_evento is Dictionary else {})
			"notificacion":
				var mensaje := str(paso.get("texto", "")).strip_edges()
				if not mensaje.is_empty():
					Events.notification_pushed.emit(mensaje)
			_:
				push_warning("CutsceneDirector: tipo de paso desconocido: " + tipo)

	await _restaurar_camara()
	if generacion_actual != _generacion:
		return false
	_finalizar()
	return true


func cancelar() -> void:
	if not _ocupado:
		return
	_generacion += 1
	if is_instance_valid(_tween_camara) and _tween_camara.is_running():
		_tween_camara.kill()
	if is_instance_valid(_dialogue) and _dialogue.esta_abierto():
		_dialogue.cerrar()
	if is_instance_valid(_camera) and is_instance_valid(_player):
		_camera.global_position = _player.global_position
		_camera.zoom = _zoom_original
	_finalizar()



func _buscar_npc(clave: String) -> Creature:
	var buscada := clave.strip_edges().to_lower()
	if buscada.is_empty():
		return null
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if not nodo is Creature:
			continue
		var npc := nodo as Creature
		if not is_instance_valid(npc):
			continue
		var nombre := npc.get_nombre().strip_edges().to_lower()
		var id := npc.get_id().strip_edges().to_lower()
		if nombre == buscada or id == buscada:
			return npc
	return null


func _ejecutar_mirar_npc(paso: Dictionary) -> void:
	var npc := _buscar_npc(str(paso.get("npc", "")))
	if npc == null:
		return
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var objetivo := _buscar_npc(str(paso.get("hacia_npc", "")))
	if objetivo != null:
		sprite.flip_h = objetivo.global_position.x < npc.global_position.x
	elif paso.has("izquierda"):
		sprite.flip_h = bool(paso.get("izquierda", false))


func _ejecutar_gesto_npc(paso: Dictionary) -> void:
	var npc := _buscar_npc(str(paso.get("npc", "")))
	if npc == null:
		return
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var gesto := str(paso.get("gesto", "asentir")).strip_edges().to_lower()
	var duracion := clampf(float(paso.get("duracion", 0.55)), 0.15, 2.5)
	var posicion_base := sprite.position
	var escala_base := sprite.scale
	var rotacion_base := sprite.rotation
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	match gesto:
		"asentir":
			tween.tween_property(sprite, "position:y", posicion_base.y - 3.0, duracion * 0.35)
			tween.tween_property(sprite, "position:y", posicion_base.y, duracion * 0.65)
		"saludar":
			tween.tween_property(sprite, "rotation", rotacion_base - 0.10, duracion * 0.25)
			tween.tween_property(sprite, "rotation", rotacion_base + 0.10, duracion * 0.25)
			tween.tween_property(sprite, "rotation", rotacion_base, duracion * 0.5)
		"trabajar":
			tween.tween_property(sprite, "rotation", rotacion_base - 0.07, duracion * 0.25)
			tween.tween_property(sprite, "rotation", rotacion_base + 0.07, duracion * 0.25)
			tween.tween_property(sprite, "rotation", rotacion_base, duracion * 0.5)
		"sorpresa":
			tween.tween_property(sprite, "scale", escala_base * 1.08, duracion * 0.3)
			tween.tween_property(sprite, "scale", escala_base, duracion * 0.7)
		"negar":
			tween.tween_property(sprite, "rotation", rotacion_base + 0.09, duracion * 0.2)
			tween.tween_property(sprite, "rotation", rotacion_base - 0.09, duracion * 0.2)
			tween.tween_property(sprite, "rotation", rotacion_base, duracion * 0.6)
		_:
			tween.tween_property(sprite, "position:y", posicion_base.y - 2.0, duracion * 0.5)
			tween.tween_property(sprite, "position:y", posicion_base.y, duracion * 0.5)
	await tween.finished
	if is_instance_valid(sprite):
		sprite.position = posicion_base
		sprite.scale = escala_base
		sprite.rotation = rotacion_base


func _ejecutar_mover_npc(paso: Dictionary, generacion: int) -> void:
	var npc := _buscar_npc(str(paso.get("npc", "")))
	if npc == null:
		return
	var schedule := get_tree().get_first_node_in_group("npc_schedule_system")
	if not is_instance_valid(schedule) or not schedule.has_method("iniciar_actividad_social"):
		return
	# Las coordenadas del paso son locales a la zona activa, igual que
	# las órdenes sociales del NPCScheduleSystem.
	var destino := Vector2(float(paso.get("x", 0.0)), float(paso.get("y", 0.0)))
	var duracion := clampf(float(paso.get("duracion", 5.0)), 1.0, 30.0)
	if not bool(schedule.call("iniciar_actividad_social", npc, destino, duracion)):
		return
	var tiempo := 0.0
	while is_instance_valid(npc) and bool(npc.get_meta("actividad_social_activa", false)):
		if generacion != _generacion:
			return
		if tiempo >= 35.0:
			break
		await get_tree().create_timer(0.2).timeout
		tiempo += 0.2


func _ejecutar_movimiento_camara(paso: Dictionary) -> void:
	if not is_instance_valid(_camera):
		return
	var destino := Vector2(
		float(paso.get("x", _camera.global_position.x)),
		float(paso.get("y", _camera.global_position.y))
	)
	var objetivo_path := str(paso.get("objetivo", "")).strip_edges()
	if not objetivo_path.is_empty():
		var objetivo := get_tree().root.get_node_or_null(objetivo_path) as Node2D
		if is_instance_valid(objetivo):
			destino = objetivo.global_position
	var duracion := clampf(float(paso.get("duracion", 0.8)), 0.0, 15.0)
	var zoom_objetivo := float(paso.get("zoom", _camera.zoom.x))
	zoom_objetivo = clampf(zoom_objetivo, 0.5, 5.0)
	if is_instance_valid(_tween_camara) and _tween_camara.is_running():
		_tween_camara.kill()
	_tween_camara = create_tween()
	_tween_camara.set_trans(Tween.TRANS_SINE)
	_tween_camara.set_ease(Tween.EASE_IN_OUT)
	_tween_camara.set_parallel(true)
	_tween_camara.tween_property(_camera, "global_position", destino, duracion)
	_tween_camara.tween_property(_camera, "zoom", Vector2.ONE * zoom_objetivo, duracion)
	await _tween_camara.finished


func _restaurar_camara() -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_player):
		return
	if is_instance_valid(_tween_camara) and _tween_camara.is_running():
		_tween_camara.kill()
	_tween_camara = create_tween()
	_tween_camara.set_trans(Tween.TRANS_SINE)
	_tween_camara.set_ease(Tween.EASE_IN_OUT)
	_tween_camara.set_parallel(true)
	_tween_camara.tween_property(_camera, "global_position", _player.global_position, 0.65)
	_tween_camara.tween_property(_camera, "zoom", _zoom_original, 0.65)
	await _tween_camara.finished


func _finalizar() -> void:
	if not _ocupado:
		return
	var clave_finalizada := _clave_actual
	_ocupado = false
	_clave_actual = ""
	if is_in_group("modal_ui"):
		remove_from_group("modal_ui")
	cinematica_finalizada.emit(clave_finalizada)
