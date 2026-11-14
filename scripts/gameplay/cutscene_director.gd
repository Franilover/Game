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
var _estado_ui_cinematica: Array[Dictionary] = []
var _estado_npcs_cinematica: Dictionary = {}
var _modo_cinematica: String = "planeada"
var _pausa_previa: bool = false
var _process_mode_dialogo_previo: int = Node.PROCESS_MODE_INHERIT
var _process_mode_panel_dialogo_previo: int = Node.PROCESS_MODE_INHERIT
var _seguimiento_camara_npcs: Array[String] = []


func configurar(player: Player, dialogue: DialogueSystem, camera: Camera2D = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = player
	_dialogue = dialogue
	_camera = camera
	if is_instance_valid(_camera):
		_zoom_original = _camera.zoom


func _process(delta: float) -> void:
	if _modo_cinematica != "en_vivo" or _seguimiento_camara_npcs.is_empty() or not is_instance_valid(_camera):
		return
	var posiciones: Array[Vector2] = []
	for nombre in _seguimiento_camara_npcs:
		var npc := _buscar_npc(nombre)
		if is_instance_valid(npc) and npc.is_visible_in_tree() and npc.is_alive:
			posiciones.append(npc.global_position)
	if posiciones.is_empty():
		return
	var centro := Vector2.ZERO
	for posicion in posiciones:
		centro += posicion
	centro /= float(posiciones.size())
	_camera.global_position = _camera.global_position.lerp(centro, clampf(delta * 5.0, 0.0, 1.0))


func esta_activo() -> bool:
	return _ocupado


func obtener_clave_actual() -> String:
	return _clave_actual


func ejecutar(clave: String, pasos: Array, tipo: String = "planeada") -> bool:
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
	_modo_cinematica = "en_vivo" if tipo.strip_edges().to_lower() in ["en_vivo", "vivo", "live"] else "planeada"
	if _modo_cinematica == "planeada":
		_pausa_previa = get_tree().paused
		_process_mode_dialogo_previo = _dialogue.process_mode
		_dialogue.process_mode = Node.PROCESS_MODE_ALWAYS
		if is_instance_valid(_dialogue.dialogue_panel):
			_process_mode_panel_dialogo_previo = _dialogue.dialogue_panel.process_mode
			_dialogue.dialogue_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
	if not is_in_group("modal_ui"):
		add_to_group("modal_ui")
	_capturar_y_ocultar_ui()
	if _modo_cinematica == "planeada":
		_ocultar_npcs_fuera_de_cinematica()
	cinematica_iniciada.emit(_clave_actual)

	for paso_variant in pasos:
		if generacion_actual != _generacion:
			return false
		if not paso_variant is Dictionary:
			continue
		var paso := paso_variant as Dictionary
		var tipo_paso := str(paso.get("tipo", "")).strip_edges().to_lower()

		match tipo_paso:
			"dialogo":
				var datos_variant: Variant = paso.get("datos", paso)
				if not datos_variant is Dictionary:
					continue
				var dialogo_abierto := false
				if paso.has("npc"):
					var fuente_dialogo := _buscar_npc(str(paso.get("npc", "")))
					if _modo_cinematica == "planeada" and is_instance_valid(fuente_dialogo):
						_guardar_estado_npc(fuente_dialogo)
						fuente_dialogo.show()
					dialogo_abierto = _dialogue.abrir(datos_variant as Dictionary, fuente_dialogo, true)
				else:
					dialogo_abierto = _dialogue.abrir(datos_variant as Dictionary)
				if dialogo_abierto:
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
			"preparar_npc":
				if _modo_cinematica == "planeada":
					_preparar_npc_cinematica(paso)
			"fijar_npc":
				if _modo_cinematica == "planeada":
					_fijar_npc_cinematica(str(paso.get("npc", "")))
			"ruta_npc":
				await _ejecutar_ruta_npc(paso, generacion_actual)
				if generacion_actual != _generacion:
					return false
			"mover_jugador":
				await _ejecutar_ruta_jugador(paso, generacion_actual)
				if generacion_actual != _generacion:
					return false
			"mover_npc":
				await _ejecutar_ruta_npc(paso, generacion_actual)
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
				push_warning("CutsceneDirector: tipo de paso desconocido: " + tipo_paso)

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
		var nombre_visual := npc.get_nombre_visual().strip_edges().to_lower()
		var id := npc.get_id().strip_edges().to_lower()
		var personaje_id := npc.get_personaje_game_id().strip_edges().to_lower()
		if nombre == buscada or nombre_visual == buscada or id == buscada or personaje_id == buscada:
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


func _capturar_y_ocultar_ui() -> void:
	_estado_ui_cinematica.clear()
	var ui_root := get_parent().get_node_or_null("UI") if is_instance_valid(get_parent()) else null
	if not is_instance_valid(ui_root):
		for grupo in ["hud", "inventory"]:
			for nodo in get_tree().get_nodes_in_group(grupo):
				_ocultar_elemento_ui(nodo)
		return

	var hud := ui_root.get_node_or_null("HUD")
	for nodo in ui_root.get_children():
		if nodo == hud:
			for elemento_hud in hud.get_children():
				_ocultar_elemento_ui(elemento_hud)
		else:
			_ocultar_elemento_ui(nodo)


func _ocultar_elemento_ui(nodo: Node) -> void:
	if not is_instance_valid(nodo):
		return
	var panel_dialogo: Node = _dialogue.dialogue_panel if is_instance_valid(_dialogue) else null
	if nodo == panel_dialogo:
		return
	if is_instance_valid(panel_dialogo) and nodo.is_ancestor_of(panel_dialogo):
		for hijo in nodo.get_children():
			_ocultar_elemento_ui(hijo)
		return
	if nodo is CanvasItem:
		var item := nodo as CanvasItem
		_estado_ui_cinematica.append({"nodo": item, "visible": item.visible})
		item.hide()


func _ocultar_npcs_fuera_de_cinematica() -> void:
	# Las cinemáticas planeadas muestran únicamente a los NPC que participan
	# explícitamente. Así se evita que las rutinas del pueblo distraigan al fondo.
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if not nodo is Creature:
			continue
		var npc := nodo as Creature
		if not is_instance_valid(npc):
			continue
		_guardar_estado_npc(npc)
		npc.hide()


func _guardar_estado_npc(npc: Creature) -> void:
	if not is_instance_valid(npc):
		return
	var id := str(npc.get_instance_id())
	if _estado_npcs_cinematica.has(id):
		return
	var metas := {}
	for clave in ["rutina_en_edificio", "rutina_en_transito", "actividad_social_activa", "acercamiento_social_activo", "conversacion_npc_bloqueada", "cinematica_npc_activa"]:
		metas[clave] = {"tenia": npc.has_meta(clave), "valor": npc.get_meta(clave, null)}
	_estado_npcs_cinematica[id] = {
		"nodo": npc, "posicion": npc.global_position, "visible": npc.visible,
		"velocity": npc.velocity, "process_mode": npc.process_mode, "metas": metas
	}
	npc.set_meta("cinematica_npc_activa", true)
	npc.velocity = Vector2.ZERO
	npc.process_mode = Node.PROCESS_MODE_DISABLED


func _preparar_npc_cinematica(paso: Dictionary) -> void:
	var npc := _buscar_npc(str(paso.get("npc", "")))
	if not is_instance_valid(npc):
		return
	_guardar_estado_npc(npc)
	npc.global_position = Vector2(float(paso.get("x", npc.global_position.x)), float(paso.get("y", npc.global_position.y)))
	npc.show()
	npc.set_meta("rutina_en_edificio", false)
	npc.set_meta("rutina_en_transito", false)
	npc.set_meta("actividad_social_activa", false)
	npc.set_meta("acercamiento_social_activo", false)


func _fijar_npc_cinematica(nombre: String) -> void:
	var npc := _buscar_npc(nombre)
	if is_instance_valid(npc):
		_guardar_estado_npc(npc)


func _ejecutar_ruta_npc(paso: Dictionary, generacion: int) -> void:
	var npc := _buscar_npc(str(paso.get("npc", "")))
	if not is_instance_valid(npc):
		return
	if _modo_cinematica == "planeada":
		_guardar_estado_npc(npc)
		npc.show()
	var puntos_variant: Variant = paso.get("puntos", [])
	var puntos: Array = puntos_variant if puntos_variant is Array else []
	if puntos.is_empty() and paso.has("x") and paso.has("y"):
		puntos = [Vector2(float(paso.get("x", 0.0)), float(paso.get("y", 0.0)))]
	for punto_variant in puntos:
		if generacion != _generacion or not is_instance_valid(npc):
			return
		var destino := Vector2.ZERO
		if punto_variant is Vector2:
			destino = punto_variant
		elif punto_variant is Dictionary:
			destino = Vector2(float(punto_variant.get("x", npc.global_position.x)), float(punto_variant.get("y", npc.global_position.y)))
		else:
			continue
		var distancia := npc.global_position.distance_to(destino)
		var duracion := clampf(float(paso.get("duracion_por_tramo", maxf(0.25, distancia / 65.0))), 0.15, 20.0)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(npc, "global_position", destino, duracion)
		await tween.finished
		if generacion != _generacion:
			return
	var pausa := clampf(float(paso.get("pausa", 0.0)), 0.0, 15.0)
	if pausa > 0.0:
		await get_tree().create_timer(pausa).timeout


func _ejecutar_ruta_jugador(paso: Dictionary, generacion: int) -> void:
	if not is_instance_valid(_player):
		return
	var destino := Vector2(
		float(paso.get("x", _player.global_position.x)),
		float(paso.get("y", _player.global_position.y))
	)
	var distancia := _player.global_position.distance_to(destino)
	var duracion := clampf(float(paso.get("duracion", maxf(0.25, distancia / 90.0))), 0.15, 20.0)
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = Vector2.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_player, "global_position", destino, duracion)
	await tween.finished
	if generacion == _generacion and is_instance_valid(_player) and _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = Vector2.ZERO


func _restaurar_estado_temporal() -> void:
	for estado in _estado_npcs_cinematica.values():
		var npc: Creature = estado.get("nodo") as Creature
		if not is_instance_valid(npc):
			continue
		npc.process_mode = int(estado.get("process_mode", Node.PROCESS_MODE_INHERIT))
		npc.global_position = estado.get("posicion", npc.global_position)
		npc.visible = bool(estado.get("visible", true))
		npc.velocity = estado.get("velocity", Vector2.ZERO)
		var metas: Dictionary = estado.get("metas", {})
		for clave in metas:
			var dato: Dictionary = metas[clave]
			if bool(dato.get("tenia", false)):
				npc.set_meta(clave, dato.get("valor"))
			else:
				npc.remove_meta(clave)
	_estado_npcs_cinematica.clear()
	for estado_ui in _estado_ui_cinematica:
		var nodo: CanvasItem = estado_ui.get("nodo") as CanvasItem
		if is_instance_valid(nodo):
			nodo.visible = bool(estado_ui.get("visible", true))
	_estado_ui_cinematica.clear()


func _ejecutar_movimiento_camara(paso: Dictionary) -> void:
	if not is_instance_valid(_camera):
		return
	var destino := Vector2(
		float(paso.get("x", _camera.global_position.x)),
		float(paso.get("y", _camera.global_position.y))
	)
	_seguimiento_camara_npcs.clear()
	if _modo_cinematica == "en_vivo":
		var seguimiento_variant: Variant = paso.get("seguir_npcs", [])
		if seguimiento_variant is Array:
			for nombre_variant in seguimiento_variant:
				var nombre := str(nombre_variant).strip_edges()
				if not nombre.is_empty():
					_seguimiento_camara_npcs.append(nombre)
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
	if _seguimiento_camara_npcs.is_empty():
		_tween_camara.tween_property(_camera, "global_position", destino, duracion)
	_tween_camara.tween_property(_camera, "zoom", Vector2.ONE * zoom_objetivo, duracion)
	await _tween_camara.finished


func _restaurar_camara() -> void:
	_seguimiento_camara_npcs.clear()
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
	_restaurar_estado_temporal()
	if _modo_cinematica == "planeada":
		if is_instance_valid(_dialogue):
			_dialogue.process_mode = _process_mode_dialogo_previo
			if is_instance_valid(_dialogue.dialogue_panel):
				_dialogue.dialogue_panel.process_mode = _process_mode_panel_dialogo_previo
		get_tree().paused = _pausa_previa
	var clave_finalizada := _clave_actual
	_ocupado = false
	_clave_actual = ""
	_modo_cinematica = "planeada"
	_seguimiento_camara_npcs.clear()
	if is_in_group("modal_ui"):
		remove_from_group("modal_ui")
	cinematica_finalizada.emit(clave_finalizada)
