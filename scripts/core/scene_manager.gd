extends Node
## SceneManager — autoridad única para cambios de escena.
## Las escenas se preparan en segundo plano antes de retirar el menú o runtime.

var _current: Node = null
var _carga_en_curso: bool = false


func preparar(path: String) -> void:
	if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
		return
	var estado := ResourceLoader.load_threaded_get_status(path)
	if estado == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var error := ResourceLoader.load_threaded_request(path, "PackedScene", false)
		if error != OK and error != ERR_BUSY:
			push_warning("SceneManager: no se pudo anticipar la carga de '%s' (error %d)." % [path, error])


func go_to(path: String) -> void:
	if _carga_en_curso:
		push_warning("SceneManager: se ignoró una transición duplicada a '%s'." % path)
		return
	_carga_en_curso = true
	var inicio_transicion_ms := Time.get_ticks_msec()

	# Cargar primero. Si el recurso falla, el menú/escena actual permanece intacto.
	preparar(path)
	var estado := ResourceLoader.load_threaded_get_status(path)
	while estado == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		estado = ResourceLoader.load_threaded_get_status(path)

	if estado != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("SceneManager: no se pudo preparar '%s' (estado %d)." % [path, estado])
		_carga_en_curso = false
		return

	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	print("SceneManager: recurso preparado → ", path, " | ", Time.get_ticks_msec() - inicio_transicion_ms, " ms")
	if packed == null:
		push_error("SceneManager: el recurso preparado no es una PackedScene: '%s'." % path)
		_carga_en_curso = false
		return

	var escena_anterior: Node = get_tree().current_scene
	if is_instance_valid(_current) and _current != escena_anterior:
		_current.queue_free()
		await _current.tree_exited

	if is_instance_valid(escena_anterior):
		escena_anterior.queue_free()
		await escena_anterior.tree_exited

	var inicio_instancia_ms := Time.get_ticks_msec()
	_current = packed.instantiate()
	print("SceneManager: instancia creada → ", path, " | ", Time.get_ticks_msec() - inicio_instancia_ms, " ms")
	if _current == null:
		push_error("SceneManager: no se pudo instanciar '%s'." % path)
		_carga_en_curso = false
		return
	get_tree().root.add_child(_current)
	get_tree().current_scene = _current
	Events.scene_changed.emit(path)
	_carga_en_curso = false
