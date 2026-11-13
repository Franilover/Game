extends Node

## Navegación independiente para el acceso a Historia.
## Mantiene el menú principal desacoplado del flujo narrativo.

func abrir_historia() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/story/story_hub.tscn")
	if error != OK:
		push_error("Historia: no se pudo abrir el menú de Historia. Error: %s" % error)
