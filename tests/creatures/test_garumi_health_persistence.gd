extends Node

const GarumiScript = preload("res://scripts/creatures/garumi.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var garumi: Node = GarumiScript.new()
	garumi.call("configurar", {
		"id": "garumi_no_combate",
		"nombre": "Garumi de prueba",
		"health": 0,
		"nivel": 99,
		"experiencia_total": 999999,
		"eterium_actual": 12
	})
	add_child(garumi)
	await get_tree().process_frame

	for metodo in [
		"iniciar_enfrentamiento",
		"iniciar_enfrentamiento_secundario",
		"entrar_combate_vinculado",
		"recibir_danio_combate",
		"salir_combate_vinculado",
		"ganar_experiencia",
		"curar_con_eterium"
	]:
		if garumi.has_method(metodo):
			errores.append("El modelo Garumi conserva API de combate/progresión: " + metodo)

	if garumi.is_in_group("damageable"):
		errores.append("El Garumi se registró como objetivo de daño.")
	if garumi.has_method("take_damage"):
		garumi.call("take_damage", 999, "test")
		if bool(garumi.get("is_alive")) == false:
			errores.append("Un impacto externo alteró el estado vital del Garumi.")
	if garumi.has_method("obtener_datos_amistad"):
		var amistad: Dictionary = garumi.call("obtener_datos_amistad")
		for campo in ["health", "nivel", "experiencia_total"]:
			if amistad.has(campo):
				errores.append("El registro social conserva el campo de combate: " + campo)

	garumi.set("_vinculado", true)
	if garumi.has_method("obtener_datos_persistencia_vinculo"):
		var vinculo: Dictionary = garumi.call("obtener_datos_persistencia_vinculo")
		for campo in ["health", "nivel", "experiencia_total"]:
			if vinculo.has(campo):
				errores.append("El vínculo persiste el campo de combate: " + campo)

	garumi.queue_free()
	if not errores.is_empty():
		for error in errores:
			push_error("GarumiNonCombatContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("GarumiNonCombatContract: PASS")
	get_tree().quit(0)
