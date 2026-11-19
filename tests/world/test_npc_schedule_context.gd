extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const NPCScheduleScript = preload("res://scripts/world/npc_schedule_system.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var agenda := NPCScheduleScript.new() as NPCScheduleSystem
	var npc_a := CreatureScene.instantiate() as Creature
	var npc_b := CreatureScene.instantiate() as Creature
	if agenda == null or npc_a == null or npc_b == null:
		_fail(["No se pudieron crear las instancias para el contrato de agenda NPC."])
		return

	add_child(agenda)
	add_child(npc_a)
	add_child(npc_b)
	npc_a.add_to_group("torres_game_npc")
	npc_b.add_to_group("torres_game_npc")
	await get_tree().process_frame

	_comprobar_contexto_compartido(agenda, npc_a, npc_b, errores)
	_comprobar_memoria_diaria(agenda, npc_a, errores)
	_comprobar_seleccion_rutina_y_copia(agenda, npc_a, errores)
	_comprobar_destinos_rutina(npc_a, errores)

	npc_a.remove_from_group("torres_game_npc")
	npc_b.remove_from_group("torres_game_npc")
	npc_a.queue_free()
	npc_b.queue_free()
	agenda.queue_free()
	await get_tree().process_frame

	if not errores.is_empty():
		_fail(errores)
		return

	print("NPCScheduleContext: PASS")
	get_tree().quit(0)


func _comprobar_contexto_compartido(
	agenda: NPCScheduleSystem,
	npc_a: Creature,
	npc_b: Creature,
	errores: Array[String]
) -> void:
	agenda._npcs_actualizacion = [npc_a]
	agenda._actualizacion_en_curso = true
	var snapshot_tick: Array = agenda._obtener_npcs_torres()
	if snapshot_tick.size() != 1 or snapshot_tick[0] != npc_a:
		errores.append("Durante un tick debe reutilizarse la instantánea compartida de NPC.")

	agenda._tiempo_mundo_actualizacion = {"anio": 3, "dia": 12}
	var tiempo_tick: Dictionary = agenda._obtener_tiempo_actual()
	if int(tiempo_tick.get("anio", 0)) != 3 or int(tiempo_tick.get("dia", 0)) != 12:
		errores.append("Durante un tick debe reutilizarse la instantánea temporal del mundo.")

	agenda._actualizacion_en_curso = false
	var snapshot_fuera: Array = agenda._obtener_npcs_torres()
	if snapshot_fuera.size() != 2 or not snapshot_fuera.has(npc_a) or not snapshot_fuera.has(npc_b):
		errores.append("Fuera del tick debe consultarse el grupo actual de NPC.")
	if not agenda._obtener_tiempo_actual().is_empty():
		errores.append("Sin WorldAtmosphere, el contexto temporal externo debe devolver un diccionario vacío.")


func _comprobar_memoria_diaria(
	agenda: NPCScheduleSystem,
	npc: Creature,
	errores: Array[String]
) -> void:
	agenda._actualizar_resumen_diario_reunion(
		npc, {"anio": 1, "dia": 4}, "trabajo_forja", "trabajar_en_la_forja", "forja"
	)
	if str(npc.get_meta("resumen_dia_reunion_actividad", "")) != "trabajar_en_la_forja":
		errores.append("La actividad significativa debe guardarse para el resumen nocturno.")

	agenda._actualizar_resumen_diario_reunion(
		npc, {"anio": 1, "dia": 4}, "descanso_tarde", "descansar", "casa_bruna"
	)
	if str(npc.get_meta("resumen_dia_reunion_actividad", "")) != "trabajar_en_la_forja":
		errores.append("El descanso no debe borrar la última actividad significativa.")

	npc.set_meta("actividad_actual", "conversar_con_vecinos")
	npc.set_meta("rutina_actual", "reunion_nocturna_castillo")
	npc.set_meta("rutina_ubicacion", "castillo")
	agenda._actualizar_resumen_diario_reunion(
		npc, {"anio": 1, "dia": 5}, "reunion_nocturna_castillo", "conversar", "castillo"
	)
	if str(npc.get_meta("resumen_dia_reunion_clave", "")) != "1:5":
		errores.append("La memoria diaria debe reiniciarse al cambiar de fecha.")
	if str(npc.get_meta("resumen_dia_reunion_actividad", "")) != "conversar_con_vecinos":
		errores.append("La reunión debe recuperar la actividad actual si aún no hay resumen del día.")
	if str(npc.get_meta("resumen_dia_reunion_ubicacion", "")) != "castillo":
		errores.append("La reunión debe conservar la ubicación de la actividad recuperada.")


func _comprobar_destinos_rutina(npc: Creature, errores: Array[String]) -> void:
	npc.nombre_individual = "Elian"
	npc.datos["posicion_hogar_local"] = Vector2(25.0, 50.0)
	var destino_hogar: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, {}, "casa_elian", false, {}
	)
	if destino_hogar != Vector2(25.0, 50.0):
		errores.append("Una rutina sin actividad debe priorizar la posición local guardada del hogar.")

	var destino_edificio: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, {}, "panaderia", true, {"id": "panaderia", "pos": Vector2(-360.0, -86.0)}
	)
	if destino_edificio != Vector2(-360.0, -58.0):
		errores.append("El destino de un edificio debe quedar 28 px fuera de la puerta.")

	var rutina_plaza_absoluta := {
		"posicion_absoluta_plaza": Vector2(11.0, 22.0),
		"variacion_posicion": Vector2(5.0, 6.0)
	}
	var destino_plaza_absoluto: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, rutina_plaza_absoluta, "plaza", true, {}
	)
	if destino_plaza_absoluto != Vector2(11.0, 22.0):
		errores.append("La posición absoluta de plaza debe prevalecer sobre los desplazamientos.")

	var destino_plaza_elian: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, {"variacion_posicion": Vector2(5.0, 6.0)}, "plaza", true, {}
	)
	if destino_plaza_elian != Vector2(-67.0, 30.0):
		errores.append("La plaza debe conservar el punto estable de Elian y sumar su variación.")

	npc.nombre_individual = "Habitante sin catálogo"
	var destino_npc_adicional: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, {}, "plaza", true, {}
	)
	if not is_equal_approx(destino_npc_adicional.length(), 118.0):
		errores.append("Los NPC sin posición propia deben distribuirse en el perímetro de la plaza.")


func _fail(errores: Array[String]) -> void:
	for error in errores:
		push_error("NPCScheduleContext: FAIL: " + error)
	get_tree().quit(1)


func _comprobar_seleccion_rutina_y_copia(
	agenda: NPCScheduleSystem,
	npc: Creature,
	errores: Array[String]
) -> void:
	var rutinas_originales: Array = [
		{
			"clave": "cerrar_panaderia",
			"hora_inicio": "09:00",
			"hora_fin": "16:00",
			"dias_semana": [0],
			"actividad_clave": "atender_panaderia",
			"ubicacion_clave": "panaderia"
		}
	]
	npc.nombre_individual = "Elian"
	npc.datos = {"rutinas": rutinas_originales}
	var resultado: Dictionary = agenda._resolver_rutina_base_y_eventos(npc, 0, 16 * 60 + 30, "elian")
	var rutinas_resueltas: Array = resultado.get("rutinas", [])
	var rutina_elegida: Dictionary = resultado.get("rutina", {})
	if str(rutina_elegida.get("clave", "")) != "cerrar_panaderia":
		errores.append("La extensión del turno de Elian debe conservar la rutina de cierre.")
	if str(rutinas_resueltas[0].get("hora_fin", "")) != "17:00":
		errores.append("La copia local del calendario de Elian debe extender el cierre hasta las 17:00.")
	if str(rutinas_originales[0].get("hora_fin", "")) != "16:00":
		errores.append("La extensión local de Elian no debe mutar el calendario original.")
	if not (resultado.get("evento_comunitario", {}) as Dictionary).is_empty():
		errores.append("Sin calendario mundial disponible no debe inventarse un evento comunitario.")
	if str(npc.get_meta("evento_comunitario_actual", "x")) != "":
		errores.append("La ausencia de evento debe limpiar la metadata de evento anterior.")
