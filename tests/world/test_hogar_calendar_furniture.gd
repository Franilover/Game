extends Node

const HOGAR_INTERIOR_SCRIPT = preload("res://scripts/world/hogar_interior.gd")
const WORLD_INTERACTABLE_SCRIPT = preload("res://scripts/gameplay/interaction/world_interactable.gd")
const WORLD_CALENDAR_PANEL_SCRIPT = preload("res://scripts/ui/world_calendar_panel.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var catalogo: Dictionary = HOGAR_INTERIOR_SCRIPT.CATALOGO
	if not catalogo.has("calendario"):
		errores.append("El editor de muebles no ofrece el calendario.")
	else:
		var ruta := str((catalogo["calendario"] as Dictionary).get("ruta", ""))
		if ruta != "res://assets/art/places/Muebles/calendario.svg":
			errores.append("El calendario no apunta a su recurso visual.")
		if not ResourceLoader.exists(ruta):
			errores.append("No existe el recurso visual del calendario.")

	var mueble := WORLD_INTERACTABLE_SCRIPT.new() as Node2D
	if not is_instance_valid(mueble):
		errores.append("No se pudo crear el objetivo de interacción.")
	else:
		add_child(mueble)
		mueble.call("configurar_calendario")
		if str(mueble.call("get_interaction_text")) != "Consultar":
			errores.append("El mueble no muestra la acción Consultar.")
		if not mueble.is_in_group("interactable"):
			errores.append("El mueble no se registra como interactuable.")
		if not bool(mueble.call("es_dialogable")):
			errores.append("El controlador de interacción no reconoce el mueble.")
		if float(mueble.call("get_interaction_distance")) <= 0.0:
			errores.append("El mueble no define una distancia de interacción válida.")
		mueble.queue_free()

	if WORLD_CALENDAR_PANEL_SCRIPT == null:
		errores.append("No se pudo cargar la interfaz visual del calendario.")

	await get_tree().process_frame
	if not errores.is_empty():
		for error in errores:
			push_error("HogarCalendarFurniture: FAIL: " + error)
		get_tree().quit(1)
		return
	print("HogarCalendarFurniture: PASS")
	get_tree().quit(0)
