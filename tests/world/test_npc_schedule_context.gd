extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const NPCScheduleScript = preload("res://scripts/world/npc_schedule_system.gd")
const NPCConversationScript = preload("res://scripts/world/npc_conversation_system.gd")
const WorldAtmosphereScript = preload("res://scripts/world/world_atmosphere.gd")
const NPCNavigationScript = preload("res://scripts/world/npc_navigation_system.gd")


class ZoneManagerPrueba extends Node:
	var tipo_actual := "reino_torres"

	func obtener_tipo_actual() -> String:
		return tipo_actual


class ZonaInteriorPrueba extends Node2D:
	var _interior_activo := true
	var _entrada_interior_id := "panaderia"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var destino_origen := NPCScheduleScript.resolver_destino_reintento(Vector2.ZERO, Vector2(80.0, 40.0))
	if destino_origen != Vector2.ZERO:
		errores.append("La recuperación de rutas debe conservar Vector2.ZERO como destino válido.")
	var destino_respaldo := NPCScheduleScript.resolver_destino_reintento(null, Vector2(80.0, 40.0))
	if destino_respaldo != Vector2(80.0, 40.0):
		errores.append("La recuperación de rutas no usa el destino alternativo cuando no hay uno guardado.")
	if not NPCScheduleScript.ruta_sin_progreso(Vector2(10.0, 10.0), Vector2(10.0, 10.0), 5000, 1000):
		errores.append("La vigilancia no detecta una ruta inmóvil tras superar el tiempo límite.")
	if NPCScheduleScript.ruta_sin_progreso(Vector2(20.0, 10.0), Vector2(10.0, 10.0), 5000, 1000):
		errores.append("La vigilancia marca como atascado a un NPC que sí avanzó.")
	if NPCScheduleScript.ruta_sin_progreso(Vector2(10.0, 10.0), Vector2(10.0, 10.0), 3000, 1000):
		errores.append("La vigilancia interrumpe una ruta antes del tiempo de tolerancia.")
	var agenda := NPCScheduleScript.new() as NPCScheduleSystem
	var npc_a := CreatureScene.instantiate() as Creature
	var npc_b := CreatureScene.instantiate() as Creature
	if agenda == null or npc_a == null or npc_b == null:
		_fail(["No se pudieron crear las instancias para el contrato de agenda NPC."])
		return

	add_child(agenda)
	agenda.add_to_group("npc_schedule_system")
	add_child(npc_a)
	add_child(npc_b)
	npc_a.add_to_group("torres_game_npc")
	npc_b.add_to_group("torres_game_npc")
	await get_tree().process_frame

	_comprobar_contexto_compartido(agenda, npc_a, npc_b, errores)
	_comprobar_memoria_diaria(agenda, npc_a, errores)
	_comprobar_seleccion_rutina_y_copia(agenda, npc_a, errores)
	_comprobar_destinos_rutina(npc_a, errores)
	_comprobar_busqueda_muebles(errores)
	_comprobar_interrupcion_cinematica(agenda, npc_a, errores)
	_comprobar_cancelacion_acercamiento_sin_contexto(agenda, npc_b, errores)
	await _comprobar_retorno_a_rutina_con_contexto(agenda, npc_b, errores)

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
		npc, {}, "casa_elian", false, {}, Vector2.ZERO
	)
	if destino_hogar != Vector2(25.0, 50.0):
		errores.append("Una rutina sin actividad debe priorizar la posición local guardada del hogar.")

	var destino_edificio: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, {}, "panaderia", true, {"id": "panaderia", "pos": Vector2(-360.0, -86.0)}, Vector2.ZERO
	)
	if destino_edificio != Vector2(-360.0, -58.0):
		errores.append("El destino de un edificio debe quedar 28 px fuera de la puerta.")

	var rutina_plaza_absoluta := {"posicion_absoluta_plaza": Vector2(11.0, 22.0)}
	var destino_plaza_absoluto: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, rutina_plaza_absoluta, "plaza", true, {}, Vector2(5.0, 6.0)
	)
	if destino_plaza_absoluto != Vector2(11.0, 22.0):
		errores.append("La posición absoluta de plaza debe prevalecer sobre los desplazamientos.")

	var destino_plaza_elian: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, {}, "plaza", true, {}, Vector2(5.0, 6.0)
	)
	if destino_plaza_elian != Vector2(-67.0, 30.0):
		errores.append("La plaza debe conservar el punto estable de Elian y sumar su variación.")

	npc.nombre_individual = "Habitante sin catálogo"
	var destino_npc_adicional: Vector2 = NPCScheduleScript._resolver_destino_rutina_local(
		npc, {}, "plaza", true, {}, Vector2.ZERO
	)
	if not is_equal_approx(destino_npc_adicional.length(), 118.0):
		errores.append("Los NPC sin posición propia deben distribuirse en el perímetro de la plaza.")


func _comprobar_busqueda_muebles(errores: Array[String]) -> void:
	var contenedor := Node2D.new()
	var cama := Sprite2D.new()
	cama.name = "Cama_Madera"
	var litera := Sprite2D.new()
	litera.name = "Litera_Superior"
	var asiento := Sprite2D.new()
	asiento.name = "Asiento_Plaza"
	var decoracion := Node2D.new()
	contenedor.add_child(cama)
	contenedor.add_child(decoracion)
	contenedor.add_child(litera)
	contenedor.add_child(asiento)

	var camas := NPCScheduleScript._obtener_muebles_por_tokens(contenedor, ["cama", "litera"])
	if camas.size() != 2 or camas[0] != cama or camas[1] != litera:
		errores.append("La búsqueda de muebles debe conservar el orden de hijos y todos los elementos coincidentes.")

	var asientos := NPCScheduleScript._obtener_muebles_por_tokens(contenedor, ["silla", "asiento"])
	if asientos.size() != 1 or asientos[0] != asiento:
		errores.append("La búsqueda compartida debe reconocer los tokens de silla/asiento.")

	if not NPCScheduleScript._obtener_muebles_por_tokens(contenedor, []).is_empty():
		errores.append("Una búsqueda sin tokens no debe devolver mobiliario.")
	contenedor.free()


func _comprobar_cancelacion_acercamiento_sin_contexto(
	agenda: NPCScheduleSystem,
	npc: Creature,
	errores: Array[String]
) -> void:
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if not is_instance_valid(movimiento):
		errores.append("La cancelación de iniciativa requiere CreatureMovement.")
		return

	var conversaciones := NPCConversationScript.new() as Node
	add_child(conversaciones)
	movimiento.establecer_ruta(PackedVector2Array([npc.global_position + Vector2(120.0, 0.0)]))
	npc.set_meta("acercamiento_social_activo", true)
	npc.set_meta("rutina_en_transito", true)
	npc.set_meta("rutina_firma", "acercamiento_anterior")

	# Reproduce el cierre del diálogo: el movimiento temporal se reanuda
	# antes de que el sistema de conversación cancele el acercamiento.
	npc.pausar_movimiento_temporal()
	npc.reanudar_movimiento_temporal()
	conversaciones.set("_acercamiento_activo", {
		"npc": npc,
		"personaje_id": "",
		"dialogo_iniciado": false
	})
	conversaciones.call("_cancelar_acercamiento")

	if movimiento.rutina_en_ejecucion() or npc.velocity.length_squared() > 0.001:
		errores.append("La cancelación dejó activa la ruta de acercamiento sin contexto de mundo.")
	if bool(npc.get_meta("acercamiento_social_activo", false)):
		errores.append("La cancelación conservó la marca de acercamiento social.")
	if bool(npc.get_meta("rutina_en_transito", true)):
		errores.append("La cancelación conservó el estado de tránsito sin una ruta válida.")
	if str(npc.get_meta("rutina_firma", "x")) != "":
		errores.append("La cancelación conservó la firma de la rutina anterior.")
	if not (conversaciones.get("_acercamiento_activo") as Dictionary).is_empty():
		errores.append("El sistema de conversación no liberó su estado de acercamiento.")
	conversaciones.queue_free()



func _comprobar_retorno_a_rutina_con_contexto(
	agenda: NPCScheduleSystem,
	npc: Creature,
	errores: Array[String]
) -> void:
	var zona := Node2D.new()
	zona.name = "ZonaPruebaRetornoRutina"
	add_child(zona)
	var zona_manager := ZoneManagerPrueba.new()
	add_child(zona_manager)
	var atmosfera := WorldAtmosphereScript.new() as WorldAtmosphere
	var modulacion := CanvasModulate.new()
	modulacion.name = "DayNightModulation"
	atmosfera.add_child(modulacion)
	atmosfera.set("_calendario_cargado", true)
	atmosfera.hora_del_dia = 10.0
	atmosfera.dia_del_anio = 0
	atmosfera.anio = 2
	atmosfera.dias_por_anio = 100
	add_child(atmosfera)

	var navegacion := NPCNavigationScript.new() as NPCNavigationSystem
	add_child(navegacion)
	var malla := AStarGrid2D.new()
	malla.region = Rect2i(Vector2i.ZERO, Vector2i(104, 68))
	malla.cell_size = Vector2(32.0, 32.0)
	malla.offset = Vector2(-1648.0, -1072.0)
	malla.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	malla.update()
	navegacion.set("_zona", zona)
	navegacion.set("_malla", malla)
	navegacion.set("_malla_lista", true)

	agenda.configurar(atmosfera, zona_manager, null, navegacion)
	agenda._zona = zona
	npc.nombre_individual = "Habitante de prueba"
	npc.global_position = Vector2.ZERO
	npc.datos = {
		"rutinas": [{
			"clave": "prueba_retomar_rutina",
			"hora_inicio": "09:00",
			"hora_fin": "17:00",
			"dias_semana": [0],
			"actividad_clave": "pasear_y_saludar",
			"ubicacion_clave": "plaza"
		}]
	}
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		errores.append("La recuperación de rutina requiere el ejecutor CreatureMovement real.")
		return

	movimiento.establecer_ruta(PackedVector2Array([npc.global_position + Vector2(96.0, 0.0)]))
	npc.set_meta("acercamiento_social_activo", true)
	npc.set_meta("rutina_en_transito", true)
	npc.set_meta("rutina_firma", "ruta_temporal_anterior")
	npc.set_meta("rutina_cambio_pendiente", "prueba_retomar_rutina|plaza|pasear_y_saludar|(0.0, 0.0)")
	npc.set_meta("rutina_cambio_inicio", -1000000)
	agenda.finalizar_acercamiento_social(npc)

	var destino_local := NPCScheduleScript._resolver_destino_rutina_local(
		npc, {"actividad_clave": "pasear_y_saludar"}, "plaza", true, {}, Vector2.ZERO
	)
	var destino_global := zona.to_global(destino_local)
	if bool(npc.get_meta("acercamiento_social_activo", false)):
		errores.append("La recuperación de rutina conservó la marca de acercamiento.")
	if str(npc.get_meta("rutina_actual", "")) != "prueba_retomar_rutina":
		errores.append("Con mundo disponible, el cierre de iniciativa no recuperó la rutina programada.")
	if str(npc.get_meta("rutina_ubicacion", "")) != "plaza":
		errores.append("La rutina recuperada no conservó su ubicación programada.")
	if not bool(npc.get_meta("rutina_en_transito", false)) or not movimiento.rutina_en_ejecucion():
		errores.append("La rutina recuperada no volvió a poner en marcha la navegación.")
	if movimiento._ruta_rutina.is_empty() or movimiento._ruta_rutina[-1].distance_to(destino_global) > 36.0:
		errores.append("La ruta recuperada no termina en el destino canónico de la rutina.")
	if str(npc.get_meta("rutina_firma", "")).begins_with("ruta_temporal"):
		errores.append("La firma temporal anterior sobrevivió a la recuperación de la rutina.")

	agenda._zona = null
	npc.remove_meta("rutina_cambio_pendiente")
	npc.remove_meta("rutina_cambio_inicio")
	npc.remove_meta("rutina_firma")
	npc.remove_meta("rutina_actual")
	npc.remove_meta("rutina_ubicacion")
	npc.remove_meta("rutina_en_transito")
	npc.remove_meta("rutina_error_firma")
	npc.datos = {}
	atmosfera.queue_free()
	navegacion.queue_free()
	zona_manager.queue_free()
	zona.queue_free()
	await get_tree().process_frame


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


func _comprobar_interrupcion_cinematica(
	agenda: NPCScheduleSystem,
	npc: Creature,
	errores: Array[String]
) -> void:
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if not is_instance_valid(movimiento):
		errores.append("La prueba de interrupción requiere CreatureMovement.")
		return

	movimiento.establecer_ruta(PackedVector2Array([npc.global_position + Vector2(100.0, 0.0)]))
	npc.set_meta("rutina_paseo_interior_activo", true)
	npc.set_meta("rutina_paseo_interior_siguiente", 90)
	npc.set_meta("rutina_en_transito", true)
	npc.set_meta("cinematica_npc_activa", true)
	agenda._actualizar_rutina_interior(npc, "panaderia", 60, "trabajar")

	if movimiento.rutina_en_ejecucion() or npc.velocity.length_squared() > 0.001:
		errores.append("Una cinemática dejó activo el desplazamiento de la rutina interior.")
	if npc.has_meta("rutina_paseo_interior_activo") or bool(npc.get_meta("rutina_en_transito", true)):
		errores.append("La interrupción cinematográfica no liberó el control de locomoción.")
	if int(npc.get_meta("rutina_paseo_interior_siguiente", -1)) != 90:
		errores.append("La interrupción cinematográfica perdió el siguiente horario del paseo.")

	# La interrupción no debe consumir el próximo horario. Al terminar la
	# cinemática, la agenda debe poder reactivar el paseo desde la habitación.
	npc.remove_meta("cinematica_npc_activa")
	var zona := ZonaInteriorPrueba.new()
	zona.name = "ZonaPrueba"
	add_child(zona)
	var habitacion := Node2D.new()
	habitacion.name = "Habitacion_panaderia"
	zona.add_child(habitacion)
	npc.reparent(habitacion, true)
	agenda._zona = zona
	agenda._actualizar_rutina_interior(npc, "panaderia", 90, "trabajar")
	if not movimiento.rutina_en_ejecucion():
		errores.append("El paseo interior pendiente no se reanudó después de terminar la cinemática.")
	if not bool(npc.get_meta("rutina_paseo_interior_activo", false)) or not bool(npc.get_meta("rutina_en_transito", false)):
		errores.append("La reanudación no restauró el estado activo de la rutina interior.")
	if int(npc.get_meta("rutina_paseo_interior_siguiente", -1)) != 90:
		errores.append("La reanudación alteró el horario pendiente del paseo.")

	# Si cambia la actividad pero el NPC permanece en el mismo edificio,
	# no debe terminar el recorrido hacia el puesto de la tarea anterior.
	agenda._actualizar_rutina_interior(npc, "panaderia", 91, "dormir")
	if str(npc.get_meta("rutina_paseo_interior_actividad", "")) != "dormir":
		errores.append("El cambio de actividad no reemplazó el destino del paseo interior anterior.")
	if not movimiento.rutina_en_ejecucion() or not bool(npc.get_meta("rutina_en_transito", false)):
		errores.append("El cambio de actividad no inició una nueva ruta interior.")
	if int(npc.get_meta("rutina_paseo_interior_siguiente", -1)) != 91:
		errores.append("El cambio de actividad no actualizó el próximo intento de paseo.")

	agenda._zona = null
	npc.reparent(self, true)
	zona.queue_free()
	npc.remove_meta("rutina_paseo_interior_siguiente")
