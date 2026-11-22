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

	parcela.queue_free()
	main_fake.queue_free()
	await get_tree().process_frame
	print("NurseryGrowthTest: PASS")
	get_tree().quit(0)


func _fail(mensaje: String) -> void:
	push_error("NurseryGrowthTest: " + mensaje)
	get_tree().quit(1)
