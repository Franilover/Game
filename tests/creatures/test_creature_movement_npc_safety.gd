extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const NPCScheduleScript = preload("res://scripts/world/npc_schedule_system.gd")
const NPCNavigationScript = preload("res://scripts/world/npc_navigation_system.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var npc_a := CreatureScene.instantiate() as Creature
	var npc_b := CreatureScene.instantiate() as Creature
	if npc_a == null or npc_b == null:
		_fail(["No se pudieron crear los NPC de prueba."])
		return

	npc_a.position = Vector2.ZERO
	npc_b.position = Vector2(18.0, 0.0)
	get_tree().root.add_child(npc_a)
	get_tree().root.add_child(npc_b)
	npc_a.add_to_group("torres_game_npc")
	npc_b.add_to_group("torres_game_npc")
	await get_tree().process_frame

	var movimiento := npc_a.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		_fail(["El NPC no contiene CreatureMovement."])
		return

	var agenda := NPCScheduleScript.new() as NPCScheduleSystem
	get_tree().root.add_child(agenda)
	var malla_prueba := AStarGrid2D.new()
	malla_prueba.region = Rect2i(Vector2i.ZERO, Vector2i(5, 5))
	malla_prueba.cell_size = Vector2.ONE
	malla_prueba.update()
	malla_prueba.set_point_solid(Vector2i(2, 2), true)
	var celda_cercana := NPCNavigationScript.buscar_celda_transitable_cercana(malla_prueba, Vector2i(2, 2))
	if Vector2(celda_cercana - Vector2i(2, 2)).length_squared() != 1.0:
		errores.append("La búsqueda de celda libre no eligió la alternativa más cercana.")

	var direccion := movimiento._direccion_evitar_superposicion_npcs(Vector2.RIGHT)
	if absf(direccion.y) < 0.2:
		errores.append("Un NPC que encuentra a otro delante no cede lateralmente.")

	# Los NPC fuera del radio de separación no deben alterar el rumbo.
	npc_b.global_position = npc_a.global_position + Vector2(1000.0, 0.0)
	var direccion_lejos := movimiento._direccion_evitar_superposicion_npcs(Vector2.RIGHT)
	if direccion_lejos.distance_to(Vector2.RIGHT) > 0.01:
		errores.append("Un NPC lejano está alterando el rumbo de separación.")

	# El límite es exclusivo: a 34 px exactos no se aplica repulsión.
	npc_b.global_position = npc_a.global_position + Vector2(34.0, 0.0)
	var direccion_limite := movimiento._direccion_evitar_superposicion_npcs(Vector2.RIGHT)
	if direccion_limite.distance_to(Vector2.RIGHT) > 0.01:
		errores.append("La separación se activa fuera del radio definido.")

	npc_b.global_position = npc_a.global_position + Vector2(18.0, 0.0)

	# La corrección final sólo desplaza parejas realmente superpuestas.
	npc_a.set_physics_process(false)
	npc_b.set_physics_process(false)
	npc_a.velocity = Vector2.ZERO
	npc_b.velocity = Vector2.ZERO
	npc_a.global_position = Vector2(200.0, 200.0)
	npc_b.global_position = Vector2(210.0, 200.0)
	agenda._separar_npcs_superpuestos()
	var distancia_corregida := npc_a.global_position.distance_to(npc_b.global_position)
	var distancia_minima_esperada := NPCScheduleScript.RADIO_COLISION_NPC * 2.0
	if distancia_corregida < distancia_minima_esperada - 0.01:
		errores.append("La corrección final no separó dos NPC superpuestos.")
	npc_a.global_position = Vector2.ZERO
	npc_b.global_position = Vector2(18.0, 0.0)

	npc_a.set_meta("rutina_en_transito", true)
	npc_b.set_meta("rutina_en_transito", true)
	npc_a.set_meta("rutina_destino_es_edificio", true)
	npc_b.set_meta("rutina_destino_es_edificio", true)
	npc_a.set_meta("rutina_edificio_objetivo", "panaderia")
	npc_b.set_meta("rutina_edificio_objetivo", "panaderia")
	var direccion_mismo_edificio := movimiento._direccion_evitar_superposicion_npcs(Vector2.RIGHT)
	if direccion_mismo_edificio.distance_to(Vector2.RIGHT) > 0.01:
		errores.append("NPC que van al mismo edificio siguen desviándose entre sí.")

	# Un NPC atascado conserva un desvío estable; no cambia de lado
	# repetidamente, lo que antes hacía vibrar el sprite sin avanzar.
	movimiento._seguro_inicializado = true
	movimiento._ultima_posicion_seguro = npc_a.global_position
	movimiento._tiempo_sin_progreso = 1.0
	movimiento._direccion_base_atasco = Vector2.RIGHT
	var desvio_atasco := movimiento._aplicar_seguro_atasco_npc(Vector2.RIGHT, 0.1)
	var desvio_repetido := movimiento._aplicar_seguro_atasco_npc(Vector2.RIGHT, 0.1)
	if desvio_atasco.length_squared() <= 0.01 or desvio_repetido.distance_to(desvio_atasco) > 0.01:
		errores.append("El seguro de atasco no mantiene un desvío estable.")

	# El planificador debe detener paseos interiores desde una única transición.
	# Un cambio de edificio invalida también el siguiente horario del paseo.
	movimiento.establecer_ruta(PackedVector2Array([npc_a.global_position + Vector2(100.0, 0.0)]))
	npc_a.set_meta("rutina_paseo_interior_activo", true)
	npc_a.set_meta("rutina_paseo_interior_siguiente", 75)
	npc_a.set_meta("rutina_en_transito", true)
	agenda._detener_paseo_interior(npc_a, true)
	if movimiento.rutina_en_ejecucion() or npc_a.velocity.length_squared() > 0.001:
		errores.append("La limpieza del paseo interior no detuvo el movimiento.")
	if npc_a.has_meta("rutina_paseo_interior_activo") or npc_a.has_meta("rutina_paseo_interior_siguiente") or bool(npc_a.get_meta("rutina_en_transito", true)):
		errores.append("El cambio de edificio dejó metadatos del paseo interior activos.")

	# Una pausa del interior no debe perder el próximo horario ya calculado.
	movimiento.establecer_ruta(PackedVector2Array([npc_a.global_position + Vector2(100.0, 0.0)]))
	npc_a.set_meta("rutina_paseo_interior_activo", true)
	npc_a.set_meta("rutina_paseo_interior_siguiente", 90)
	npc_a.set_meta("rutina_en_transito", true)
	agenda._detener_paseo_interior(npc_a)
	if int(npc_a.get_meta("rutina_paseo_interior_siguiente", -1)) != 90:
		errores.append("La pausa temporal eliminó el siguiente horario del paseo interior.")

	npc_b.set_meta("rutina_edificio_objetivo", "posada")
	var direccion_edificios_distintos := movimiento._direccion_evitar_superposicion_npcs(Vector2.RIGHT)
	if absf(direccion_edificios_distintos.y) < 0.2:
		errores.append("NPC con destinos distintos dejaron de ceder el paso.")

	movimiento._ultima_posicion_seguro = npc_a.global_position
	movimiento._tiempo_sin_progreso = 0.0
	var direccion_recuperacion := Vector2.RIGHT
	for _i in range(10):
		direccion_recuperacion = movimiento._aplicar_seguro_atasco_npc(Vector2.RIGHT, 0.1)
	if absf(direccion_recuperacion.y) <= absf(direccion_recuperacion.x):
		errores.append("El seguro de atasco no activa un rodeo lateral tras perder progreso.")

	# Un NPC oculto dentro de un edificio no puede participar en la
	# separación exterior ni desplazar a quienes esperan en la puerta.
	npc_b.set_meta("rutina_en_edificio", true)
	npc_b.visible = false
	if agenda._npc_puede_ajustar_separacion(npc_b):
		errores.append("Un NPC oculto dentro de un edificio sigue participando en la separación exterior.")

	npc_a.remove_from_group("torres_game_npc")
	npc_b.remove_from_group("torres_game_npc")
	npc_a.queue_free()
	npc_b.queue_free()
	agenda.queue_free()
	await get_tree().process_frame

	if not errores.is_empty():
		_fail(errores)
		return

	print("CreatureMovementNPCSafety: PASS")
	get_tree().quit(0)


func _fail(errores: Array[String]) -> void:
	for error in errores:
		push_error("CreatureMovementNPCSafety: FAIL: " + error)
	get_tree().quit(1)
