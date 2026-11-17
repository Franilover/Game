extends Node

const HOGAR_INTERIOR_SCRIPT = preload("res://scripts/world/hogar_interior.gd")
const WORLD_INTERACTABLE_SCRIPT = preload("res://scripts/gameplay/interaction/world_interactable.gd")
const WORLD_CALENDAR_PANEL_SCRIPT = preload("res://scripts/ui/world_calendar_panel.gd")


class MockAtmosphere extends Node:
	signal dia_cambiado(dia_del_anio: int, anio: int)
	signal estacion_cambiada(estacion: Dictionary)

	var estaciones: Array = [
		{"id": "primavera", "nombre": "Primavera", "orden": 1, "duracion_dias": 4},
		{"id": "verano", "nombre": "Verano", "orden": 2, "duracion_dias": 5}
	]
	var estacion_actual: Dictionary = {
		"id": "primavera",
		"nombre": "Primavera",
		"temporada": "Verde",
		"dia_de_estacion": 2,
		"duracion_dias": 4
	}
	var dia_actual := 2

	func obtener_tiempo() -> Dictionary:
		return {
			"calendario_cargado": true,
			"dia_de_estacion": dia_actual,
			"duracion_estacion_dias": 4,
			"estacion": "Primavera",
			"estacion_id": "primavera",
			"anio": 5
		}


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
	else:
		var atmosfera := MockAtmosphere.new()
		add_child(atmosfera)
		var panel := WORLD_CALENDAR_PANEL_SCRIPT.new() as CanvasLayer
		add_child(panel)
		panel.call("abrir", atmosfera)
		var informacion := panel.get("_info") as Label
		var cuadricula := panel.get("_grid") as GridContainer
		if not is_instance_valid(informacion) or not informacion.text.contains("Temporada: Verde") or not informacion.text.contains("Estación: Primavera"):
			errores.append("El calendario no muestra la temporada y estación actuales.")
		if is_instance_valid(informacion) and not informacion.text.contains("Quedan 2 días"):
			errores.append("El calendario no calcula los días restantes.")
		if is_instance_valid(informacion) and not informacion.text.contains("Siguiente: Verano"):
			errores.append("El calendario no identifica la estación siguiente.")
		if not is_instance_valid(cuadricula) or cuadricula.get_child_count() != 11:
			errores.append("La cuadrícula no representa los encabezados semanales y todos los días de la estación.")
		atmosfera.dia_actual = 3
		atmosfera.estacion_actual["dia_de_estacion"] = 3
		atmosfera.dia_cambiado.emit(3, 5)
		if is_instance_valid(informacion) and not informacion.text.contains("Día 3 de 4"):
			errores.append("La vista no se actualiza al cambiar el día.")
		panel.queue_free()
		atmosfera.queue_free()

	await get_tree().process_frame
	if not errores.is_empty():
		for error in errores:
			push_error("HogarCalendarFurniture: FAIL: " + error)
		get_tree().quit(1)
		return
	print("HogarCalendarFurniture: PASS")
	get_tree().quit(0)
