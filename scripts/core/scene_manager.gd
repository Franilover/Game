extends Node
## SceneManager — autoridad única para cambios de escena.
## El cambio inicial también elimina la escena raíz que dejó el menú.
## Las escenas de gameplay no deben crear una segunda escena paralela.

var _current: Node = null

func go_to(path: String) -> void:
	var escena_anterior: Node = get_tree().current_scene

	if is_instance_valid(_current) and _current != escena_anterior:
		_current.queue_free()
		await _current.tree_exited

	if is_instance_valid(escena_anterior):
		escena_anterior.queue_free()
		await escena_anterior.tree_exited

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneManager: no se pudo cargar '%s'" % path)
		return

	_current = packed.instantiate()
	get_tree().root.add_child(_current)
	get_tree().current_scene = _current

	Events.scene_changed.emit(path)
