extends Node
## SceneManager — autoridad única para cambios de escena.
## El cambio inicial también elimina la escena raíz que dejó el menú.
## Las escenas de gameplay no deben crear una segunda escena paralela.

var _current: Node = null


func go_to(path: String) -> void:
	var tiempo_inicio_ms := Time.get_ticks_msec()
	var escena_anterior: Node = get_tree().current_scene

	if is_instance_valid(_current) and _current != escena_anterior:
		_current.queue_free()
		await _current.tree_exited

	# Si StartMenu ya inició la precarga en segundo plano, esperar aquí
	# conservando el menú visible en lugar de bloquear el hilo principal.
	var estado_carga := ResourceLoader.load_threaded_get_status(path)
	while estado_carga == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		estado_carga = ResourceLoader.load_threaded_get_status(path)
	var packed: PackedScene
	if estado_carga == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
	else:
		packed = load(path) as PackedScene
	print("SceneManager: recurso preparado → ", path, " | ", Time.get_ticks_msec() - tiempo_inicio_ms, " ms")
	if packed == null:
		push_error("SceneManager: no se pudo cargar '%s'" % path)
		return

	if is_instance_valid(escena_anterior):
		escena_anterior.queue_free()
		await escena_anterior.tree_exited

	var tiempo_instancia_ms := Time.get_ticks_msec()
	_current = packed.instantiate()
	print("SceneManager: instancia creada → ", path, " | ", Time.get_ticks_msec() - tiempo_instancia_ms, " ms")
	get_tree().root.add_child(_current)
	get_tree().current_scene = _current

	Events.scene_changed.emit(path)
