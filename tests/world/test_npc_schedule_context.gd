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


func _fail(errores: Array[String]) -> void:
	for error in errores:
		push_error("NPCScheduleContext: FAIL: " + error)
	get_tree().quit(1)
