extends Node
## SceneManager — cambia de escena sin crashear.
## Uso: SceneManager.go_to("res://scenes/world/main.tscn")

var _current: Node = null

func go_to(path: String) -> void:
	if _current:
		_current.queue_free()
		await _current.tree_exited

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneManager: no se pudo cargar '%s'" % path)
		return

	_current = packed.instantiate()
	get_tree().root.add_child(_current)
	get_tree().current_scene = _current

	GameState.current_scene = path
	Events.scene_changed.emit(path)
