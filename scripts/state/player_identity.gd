extends RefCounted
class_name PlayerIdentity

## Identidad persistente y configuración personal del personaje.
## No contiene nodos, UI ni reglas de gameplay.

var nombre: String = ""
var genero: String = ""
var especie: Dictionary = {}
var skin: String = ""

func configurar(nuevo_nombre: String, nuevo_genero: String, nueva_especie: Dictionary, nueva_skin: String) -> void:
	nombre = nuevo_nombre.strip_edges()
	genero = nuevo_genero.strip_edges()
	especie = nueva_especie.duplicate(true)
	skin = nueva_skin.strip_edges()

func establecer_nombre(nuevo_nombre: String) -> bool:
	var valor := nuevo_nombre.strip_edges()
	if valor.is_empty():
		return false
	nombre = valor
	return true

func establecer_genero(nuevo_genero: String) -> void:
	genero = nuevo_genero.strip_edges()

func establecer_especie(nueva_especie: Dictionary) -> bool:
	var especie_id := str(nueva_especie.get("id", "")).strip_edges()
	if especie_id.is_empty():
		return false
	especie = nueva_especie.duplicate(true)
	return true

func establecer_skin(nueva_skin: String) -> void:
	skin = nueva_skin.strip_edges()

func obtener_especie_id() -> String:
	return str(especie.get("id", "")).strip_edges()

func obtener_especie_nombre() -> String:
	return str(especie.get("nombre", "")).strip_edges()

func esta_configurada() -> bool:
	return not nombre.is_empty() or not obtener_especie_id().is_empty() or not skin.is_empty()

func limpiar() -> void:
	nombre = ""
	genero = ""
	especie.clear()
	skin = ""

func to_dictionary() -> Dictionary:
	return {
		"nombre": nombre,
		"genero": genero,
		"especie": especie.duplicate(true),
		"skin": skin
	}

func from_dictionary(data: Dictionary) -> void:
	nombre = str(data.get("nombre", "")).strip_edges()
	genero = str(data.get("genero", "")).strip_edges()
	skin = str(data.get("skin", "")).strip_edges()
	var especie_data: Variant = data.get("especie", {})
	if especie_data is Dictionary:
		especie = (especie_data as Dictionary).duplicate(true)
	else:
		especie = {}
