extends Node

const WATERING_SCRIPT = preload("res://scripts/gameplay/watering_interactable.gd")


class MockWorldClock extends Node:
	var fecha: Dictionary = {"anio": 1, "dia": 2, "calendario_cargado": true}

	func obtener_tiempo() -> Dictionary:
		return fecha.duplicate(true)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_fake := Node.new()
	main_fake.name = "Main"
	get_tree().root.add_child(main_fake)
	var systems := Node.new()
	systems.name = "Systems"
	main_fake.add_child(systems)
	var reloj := MockWorldClock.new()
	reloj.name = "WorldAtmosphere"
	systems.add_child(reloj)

	var parcela := Node2D.new()
	parcela.set_script(WATERING_SCRIPT)
	add_child(parcela)
	parcela.set("_planta", {
		"sprite": "res://assets/art/props/Flor Azul.png",
		"dia_plantado": 1001,
		"ultimo_riego_dia": 1001,
		"riegos": 1,
		"humedo": true
	})
	parcela.set("_humedo", true)

	if int(parcela.call("_dia_mundo_actual")) != 1002:
		_fail("Nursery plots must read the global calendar even when WorldContext has no atmosphere.")
		return

	parcela.call("_actualizar_progreso_planta")
	if bool(parcela.get("_humedo")) or bool((parcela.get("_planta") as Dictionary).get("humedo", true)):
		_fail("A watered plot must become dry after the world date advances.")
		return

	parcela.set("_planta", {
		"sprite": "res://assets/art/props/Flor Azul.png",
		"dia_plantado": 1001,
		"ultimo_riego_dia": 1001,
		"riegos": 2
	})
	if bool(parcela.call("_planta_esta_madura")):
		_fail("A crop must not be harvestable before two full world days have elapsed.")
		return

	reloj.fecha["dia"] = 3
	if not bool(parcela.call("_planta_esta_madura")):
		_fail("A crop with two watering events must become harvestable after two world days.")
		return

	# Un bancal vacío también conserva la humedad y se seca al cambiar el día.
	parcela.set("_clave", "__test_bancal_vacio")
	parcela.set("_planta", {})
	parcela.set("_humedo", true)
	parcela.set("_ultimo_riego_dia_bancal", 1003)
	parcela.call("_guardar_estado_parcela")
	var estados_test: Dictionary = GameState.world_state.flags.get("vivero_bancales", {})
	var estado_vacio: Variant = estados_test.get("__test_bancal_vacio", {})
	if not estado_vacio is Dictionary or not bool((estado_vacio as Dictionary).get("humedo", false)):
		_fail("An empty watered plot must persist its moisture state.")
		return
	reloj.fecha["dia"] = 4
	parcela.call("_actualizar_progreso_planta")
	if bool(parcela.get("_humedo")):
		_fail("An empty nursery plot must be allowed to dry after the world date advances.")
		return
	estados_test.erase("__test_bancal_vacio")
	GameState.world_state.flags["vivero_bancales"] = estados_test

	parcela.queue_free()
	main_fake.queue_free()
	await get_tree().process_frame
	print("NurseryGrowthTest: PASS")
	get_tree().quit(0)


func _fail(mensaje: String) -> void:
	push_error("NurseryGrowthTest: " + mensaje)
	get_tree().quit(1)
