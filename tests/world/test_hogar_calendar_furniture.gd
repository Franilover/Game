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
			"duracion_estacion_dias": int(estacion_actual.get("duracion_dias", 0)),
			"estacion": str(estacion_actual.get("nombre", "")),
			"estacion_id": str(estacion_actual.get("id", "")),
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
		var boton_estacion := panel.get("_boton_estacion") as Button
		var cuadricula := panel.get("_grid") as GridContainer
		if not is_instance_valid(boton_estacion) or boton_estacion.text != "Primavera":
			errores.append("El encabezado no muestra el nombre de la estación actual.")
		if not is_instance_valid(cuadricula) or cuadricula.columns != 5 or cuadricula.get_child_count() != 4:
			errores.append("La cuadrícula no usa semanas de cinco días ni representa los días de la estación.")
		if is_instance_valid(cuadricula):
			var primer_dia := cuadricula.get_child(0) as Button
			if not is_instance_valid(primer_dia) or primer_dia.text != "1" or primer_dia.get_theme_stylebox("normal") == null:
				errores.append("Los números de los días no usan el diseño de Button.")

		var boton_siguiente := panel.find_child("NextSeason", true, false) as Button
		if is_instance_valid(boton_siguiente):
			boton_siguiente.emit_signal("pressed")
		else:
			errores.append("Falta la flecha para avanzar de estación.")
		if is_instance_valid(boton_estacion) and boton_estacion.text != "Verano":
			errores.append("La flecha no permite recorrer las estaciones.")
		if atmosfera.estacion_actual.get("id", "") != "primavera":
			errores.append("Navegar el calendario modificó la fecha del mundo.")

		atmosfera.estacion_actual = {
			"id": "verano",
			"nombre": "Verano",
			"dia_de_estacion": 3,
			"duracion_dias": 5
		}
		atmosfera.dia_actual = 3
		atmosfera.estacion_cambiada.emit(atmosfera.estacion_actual)
		if is_instance_valid(boton_estacion) and boton_estacion.text != "Verano":
			errores.append("La vista no sigue los cambios reales de estación.")
		if is_instance_valid(cuadricula) and cuadricula.get_child_count() != 5:
			errores.append("La cuadrícula no actualiza la cantidad de días de la nueva estación.")

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
