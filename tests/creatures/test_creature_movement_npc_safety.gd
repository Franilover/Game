extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const NPCScheduleScript = preload("res://scripts/world/npc_schedule_system.gd")


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
	agenda._malla = AStarGrid2D.new()
	agenda._malla.region = Rect2i(Vector2i.ZERO, Vector2i(5, 5))
	agenda._malla.cell_size = Vector2.ONE
	agenda._malla.update()
	agenda._malla.set_point_solid(Vector2i(2, 2), true)
	var celda_cercana := agenda._buscar_celda_transitable_cercana(Vector2i(2, 2))
	if Vector2(celda_cercana - Vector2i(2, 2)).length_squared() != 1.0:
		errores.append("La búsqueda de celda libre no eligió la alternativa más cercana.")

	var direccion := movimiento._direccion_evitar_superposicion_npcs(Vector2.RIGHT)
	if absf(direccion.y) < 0.2:
		errores.append("Un NPC que encuentra a otro delante no cede lateralmente.")

	npc_a.set_meta("rutina_en_transito", true)
	npc_b.set_meta("rutina_en_transito", true)
	npc_a.set_meta("rutina_destino_es_edificio", true)
	npc_b.set_meta("rutina_destino_es_edificio", true)
	npc_a.set_meta("rutina_edificio_objetivo", "panaderia")
	npc_b.set_meta("rutina_edificio_objetivo", "panaderia")
	var direccion_mismo_edificio := movimiento._direccion_evitar_superposicion_npcs(Vector2.RIGHT)
	if direccion_mismo_edificio.distance_to(Vector2.RIGHT) > 0.01:
		errores.append("NPC que van al mismo edificio siguen desviándose entre sí.")

	# El watchdog tampoco debe convertir la espera de otro NPC en un rodeo
	# lateral cuando ambos comparten la misma entrada.
	movimiento._seguro_inicializado = true
	movimiento._ultima_posicion_seguro = npc_a.global_position
	movimiento._tiempo_sin_progreso = 1.0
	movimiento._direccion_base_atasco = Vector2.RIGHT
	var direccion_mismo_destino_atascado := movimiento._aplicar_seguro_atasco_npc(Vector2.RIGHT, 0.1)
	if direccion_mismo_destino_atascado.distance_to(Vector2.RIGHT) > 0.01:
		errores.append("El seguro de atasco desvía a un NPC que comparte entrada con otro.")
	if movimiento._tiempo_sin_progreso > 0.01:
		errores.append("El seguro de atasco no se reinicia al compartir la entrada.")

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
