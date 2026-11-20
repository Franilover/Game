extends Node

const HOME_SCENE: PackedScene = preload("res://scenes/world/hogar.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var home := HOME_SCENE.instantiate() as Node2D
	if home == null:
		_finish(["No se pudo instanciar HogarZone."])
		return
	add_child(home)

	var frames := 0
	while frames < 120 and home.get_node_or_null("InteriorCasa") == null:
		await get_tree().process_frame
		frames += 1
	var interior := home.get_node_or_null("InteriorCasa")
	if not is_instance_valid(interior):
		_finish(["HogarZone no creó su InteriorCasa real."])
		return

	var saved_state := {
		"version": 1,
		"decoraciones": [
			{"tipo": "arbol", "x": 180.0, "y": 220.0, "giro": 0.0},
			{
				"tipo": "cofre",
				"x": -140.0,
				"y": 96.0,
				"giro": 0.0,
				"cofre_id": "home_outer_chest",
				"contenido": [{"id": "outer_ore", "cantidad": 5}]
			}
		],
		"interior_abierto": true,
		"interior_decoraciones": {
			"version": 2,
			"siguiente_id_cofre": 9,
			"decoraciones": [
				{"tipo": "cama", "x": -96.0, "y": -48.0, "giro": 0.0},
				{
					"tipo": "cofre",
					"x": 112.0,
					"y": 64.0,
					"giro": 0.0,
					"cofre_id": "home_inner_chest",
					"contenido": [{"id": "inner_gem", "cantidad": 2}]
				}
			]
		}
	}
	home.call("restaurar_estado_guardado", saved_state)

	frames = 0
	while frames < 30 and not bool(home.get("_interior_abierto")):
		await get_tree().process_frame
		frames += 1

	if not bool(home.get("_interior_abierto")):
		errors.append("HogarZone no reabrió el interior guardado.")
	if not bool(interior.visible):
		errors.append("InteriorCasa no quedó visible al restaurar la sesión.")
	var exterior: Array = home.call("obtener_decoraciones")
	if exterior.size() != 2:
		errors.append("No se restauraron las dos decoraciones exteriores.")
	elif str((exterior[1] as Dictionary).get("cofre_id", "")) != "home_outer_chest":
		errors.append("El cofre exterior perdió su identidad.")
	else:
		var outer_contents: Array = home.call("obtener_contenido_cofre", 1)
		if outer_contents.is_empty() or str((outer_contents[0] as Dictionary).get("id", "")) != "outer_ore":
			errors.append("El contenido del cofre exterior no sobrevivió.")
	var interior_state: Dictionary = interior.call("obtener_estado_guardado")
	var interior_decorations: Array = interior_state.get("decoraciones", []) as Array
	if interior_decorations.size() != 2:
		errors.append("No se restauraron los muebles interiores.")
	elif str((interior_decorations[1] as Dictionary).get("cofre_id", "")) != "home_inner_chest":
		errors.append("El cofre interior perdió su identidad.")
	else:
		var inner_contents: Array = interior.call("obtener_contenido_cofre", 1)
		if inner_contents.is_empty() or str((inner_contents[0] as Dictionary).get("id", "")) != "inner_gem":
			errors.append("El contenido del cofre interior no sobrevivió.")
	var roundtrip: Dictionary = home.call("obtener_estado_guardado")
	if not bool(roundtrip.get("interior_abierto", false)):
		errors.append("El snapshot no conserva el estado de interior abierto.")
	var roundtrip_interior: Dictionary = roundtrip.get("interior_decoraciones", {}) as Dictionary
	if int(roundtrip_interior.get("siguiente_id_cofre", 0)) != 9:
		errors.append("No se conservó el contador de cofres interiores.")

	home.queue_free()
	await get_tree().process_frame
	_finish(errors)


func _finish(errors: Array[String]) -> void:
	if not errors.is_empty():
		for error in errors:
			push_error("HomeInteriorPersistence: FAIL: " + error)
		get_tree().quit(1)
		return
	print("HomeInteriorPersistence: PASS")
	get_tree().quit(0)
