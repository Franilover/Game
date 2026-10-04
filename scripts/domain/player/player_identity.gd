extends RefCounted
class_name PlayerIdentity

## Identidad persistente del personaje.
## No contiene nodos, UI ni reglas de gameplay.

var nombre: String = ""
var genero: String = ""
var especie: Dictionary = {}
var skin: String = ""

func configurar(
	nuevo_nombre: String,
	nuevo_genero: String,
	nueva_especie: Dictionary,
	nueva_skin: String
) -> void:
	nombre = nuevo_nombre
	genero = nuevo_genero
	especie = nueva_especie.duplicate(true)
	skin = nueva_skin

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
	nombre = str(data.get("nombre", ""))
	genero = str(data.get("genero", ""))
	skin = str(data.get("skin", ""))

	var especie_data: Variant = data.get("especie", {})
	if especie_data is Dictionary:
		especie = (especie_data as Dictionary).duplicate(true)
	else:
		especie = {}
