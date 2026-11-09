extends Node

const ValidatorScript = preload("res://scripts/state/world_snapshot_validator.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var valido := {
		"biomas": [{
			"id": "bioma-1",
			"ecosistemas": [{
				"id": "ecosistema-1",
				"habitats": [{
					"id": "habitat-1",
					"criaturas": [{
						"id": "criatura-1",
						"nombre": "Criatura de prueba"
					}]
				}]
			}]
		}],
		"misiones_game": [],
		"garumis_game": []
	}
	_comprobar(errores, "snapshot anidado válido", valido, true)

	var archivo_snapshot := FileAccess.open("res://data/world_initial.json", FileAccess.READ)
	if archivo_snapshot == null:
		errores.append("No se pudo abrir el snapshot incluido para validar compatibilidad.")
	else:
		var snapshot_variant: Variant = JSON.parse_string(archivo_snapshot.get_as_text())
		archivo_snapshot.close()
		if not snapshot_variant is Dictionary:
			errores.append("El snapshot incluido no se pudo interpretar como Dictionary.")
		elif not ValidatorScript.es_valido(snapshot_variant as Dictionary):
			errores.append("El snapshot incluido no cumple la estructura mínima del validador.")

	var sin_biomas := valido.duplicate(true)
	sin_biomas.erase("biomas")
	_comprobar(errores, "biomas ausentes", sin_biomas, false)

	var biomas_vacios := valido.duplicate(true)
	biomas_vacios["biomas"] = []
	_comprobar(errores, "biomas vacíos", biomas_vacios, false)

	var bioma_sin_id := valido.duplicate(true)
	bioma_sin_id["biomas"][0].erase("id")
	_comprobar(errores, "bioma sin ID", bioma_sin_id, false)

	var ecosistemas_incorrectos := valido.duplicate(true)
	ecosistemas_incorrectos["biomas"][0]["ecosistemas"] = {}
	_comprobar(errores, "ecosistemas con tipo incorrecto", ecosistemas_incorrectos, false)

	var habitat_sin_id := valido.duplicate(true)
	habitat_sin_id["biomas"][0]["ecosistemas"][0]["habitats"][0].erase("id")
	_comprobar(errores, "habitat sin ID", habitat_sin_id, false)

	var criatura_sin_nombre := valido.duplicate(true)
	criatura_sin_nombre["biomas"][0]["ecosistemas"][0]["habitats"][0]["criaturas"][0].erase("nombre")
	_comprobar(errores, "criatura sin nombre", criatura_sin_nombre, false)

	var opcional_incorrecto := valido.duplicate(true)
	opcional_incorrecto["misiones_game"] = {}
	_comprobar(errores, "catálogo opcional con tipo incorrecto", opcional_incorrecto, false)

	var jerarquia_vacia := {
		"biomas": [{
			"id": "bioma-sin-ecosistemas",
			"ecosistemas": []
		}]
	}
	_comprobar(errores, "jerarquía válida sin hijos", jerarquia_vacia, true)

	if not errores.is_empty():
		for error in errores:
			push_error("WorldSnapshotValidatorContract: FAIL: " + error)
		get_tree().quit(1)
		return

	print("WorldSnapshotValidatorContract: PASS")
	get_tree().quit(0)


func _comprobar(
	errores: Array[String],
	caso: String,
	datos: Dictionary,
	esperado: bool
) -> void:
	var resultado := ValidatorScript.es_valido(datos)
	if resultado != esperado:
		errores.append("%s: esperado %s y se obtuvo %s." % [
			caso,
			str(esperado),
			str(resultado)
		])
