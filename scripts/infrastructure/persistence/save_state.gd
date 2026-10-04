extends RefCounted
class_name SaveState

var active_save_id: String = ""
var active_save_name: String = ""
var save_version: int = 3

func limpiar() -> void:
	active_save_id = ""
	active_save_name = ""

func configurar(id: String, nombre: String) -> void:
	active_save_id = id
	active_save_name = nombre
