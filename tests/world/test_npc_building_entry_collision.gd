extends Node

const NPCScheduleScript = preload("res://scripts/world/npc_schedule_system.gd")
const ReinoTorresScript = preload("res://scripts/world/reino_torres.gd")
const CreatureScript = preload("res://scripts/creatures/creature.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var posiciones_castillo: Array[Vector2] = ReinoTorresScript.POSICIONES_NPC_CASTILLO_INTERIOR
	var posiciones_normales: Array[Vector2] = ReinoTorresScript.POSICIONES_NPC_INTERIOR
	if posiciones_castillo.size() != 22:
		errores.append("El catálogo del castillo debe conservar sus 22 posiciones base.")
	if posiciones_normales != [
		Vector2(-90.0, 20.0), Vector2(85.0, 20.0),
		Vector2(-10.0, -5.0), Vector2(135.0, 70.0)
	]:
		errores.append("Las posiciones normales de interiores cambiaron.")
	var zona := ReinoTorresScript.new() as Node2D
	var sistema := NPCScheduleScript.new() as NPCScheduleSystem
	sistema._zona = zona
	var npc := CreatureScript.new() as Creature
	npc.collision_layer = 4
	npc.collision_mask = 6
	add_child(npc)
	await get_tree().process_frame

	sistema._marcar_npc_dentro_edificio(npc, "panaderia")
	if npc.collision_layer != 0 or npc.collision_mask != 0:
		errores.append("Un NPC oculto dentro del edificio conserva colisión en el exterior.")
	if npc.visible or not bool(npc.get_meta("rutina_en_edificio", false)):
		errores.append("El NPC no quedó marcado como dentro del edificio.")

	# La restauración debe respetar si cada NPC era interactuable antes
	# de ocultar el exterior; visibilidad no implica interacción.
	var npc_no_interactivo := CreatureScript.new() as Creature
	var npc_interactivo := CreatureScript.new() as Creature
	npc_no_interactivo.add_to_group("torres_game_npc")
	npc_interactivo.add_to_group("torres_game_npc")
	npc_interactivo.add_to_group("interactable")
	add_child(npc_no_interactivo)
	add_child(npc_interactivo)
	await get_tree().process_frame
	npc_no_interactivo.remove_from_group("interactable")
	zona.call("_ocultar_npcs_exteriores", [npc_no_interactivo, npc_interactivo])
	if npc_no_interactivo.visible or npc_interactivo.visible:
		errores.append("La entrada al interior no ocultó todos los NPC exteriores.")
	zona.call("_restaurar_npcs_exteriores", [npc_no_interactivo, npc_interactivo])
	if not npc_no_interactivo.visible or npc_no_interactivo.is_in_group("interactable"):
		errores.append("La restauración añadió interacción a un NPC que no la tenía.")
	if not npc_interactivo.visible or not npc_interactivo.is_in_group("interactable"):
		errores.append("La restauración no conservó la interacción original del NPC.")

	# Un NPC creado durante la estancia también debe registrar su estado
	# previo antes de ser ocultado y retirado del grupo interactuable.
	var npc_nuevo := CreatureScript.new() as Creature
	npc_nuevo.add_to_group("torres_game_npc")
	npc_nuevo.add_to_group("interactable")
	add_child(npc_nuevo)
	await get_tree().process_frame
	zona.set("_interior_activo", true)
	zona.call("registrar_npc_materializado", npc_nuevo)
	if npc_nuevo.visible or npc_nuevo.is_in_group("interactable"):
		errores.append("El NPC materializado durante el interior no quedó oculto.")
	# Una segunda notificación no debe sustituir el estado original por
	# el estado temporal (oculto y no interactuable).
	zona.call("registrar_npc_materializado", npc_nuevo)
	zona.call("_restaurar_npcs_exteriores", [npc_nuevo])
	if not npc_nuevo.visible or not npc_nuevo.is_in_group("interactable"):
		errores.append("El registro repetido perdió la interacción original del NPC.")

	# La captura original debe sobrevivir a llamadas repetidas y restaurarse
	# al abandonar el edificio.
	npc.collision_layer = 16
	zona.call("desactivar_colision_npc_exterior", npc)
	zona.call("restaurar_colision_npc", npc)
	if npc.collision_layer != 4 or npc.collision_mask != 6:
		errores.append("La restauración no recuperó las capas/máscaras originales.")

	var forma := CollisionShape2D.new()
	forma.shape = CircleShape2D.new()
	npc.add_child(forma)
	zona.set("_estados_colision_exterior", {forma.get_instance_id(): false})
	forma.disabled = true
	zona.call("_restaurar_formas_colision_npc", npc)
	await get_tree().process_frame
	if forma.disabled:
		errores.append("El NPC no recuperó su forma de colisión al entrar al interior.")

	# Simula el traslado del NPC desde una habitación al contenedor exterior
	# cuando su horario cambia de edificio.
	var contenedor_exterior := Node2D.new()
	var capa_interior := Node2D.new()
	var habitacion := Node2D.new()
	add_child(contenedor_exterior)
	add_child(capa_interior)
	capa_interior.add_child(habitacion)
	zona.set("_contenedor_npcs_exterior", contenedor_exterior)
	zona.set("_capa_interior", capa_interior)
	npc.set_meta("rutina_edificio_id", "panaderia")
	npc.reparent(habitacion, true)
	npc.add_to_group("interactable")
	sistema._salir_de_edificio_para_cambiar_rutina(npc, "panaderia")
	if npc.get_parent() != contenedor_exterior:
		errores.append("El NPC no regresó al contenedor exterior al cambiar de edificio.")
	var entrada_panaderia: Dictionary = zona.call("_obtener_entrada_por_id", "panaderia")
	var posicion_puerta_esperada: Vector2 = zona.to_global(
		entrada_panaderia.get("pos", Vector2.ZERO)
	) + Vector2(0.0, 28.0)
	if npc.global_position.distance_to(posicion_puerta_esperada) > 0.1:
		errores.append("El NPC no reapareció en el umbral exterior de su edificio anterior.")
	if bool(npc.get_meta("rutina_en_edificio", true)) or str(npc.get_meta("rutina_edificio_id", "x")) != "":
		errores.append("La transición no limpió el estado del edificio anterior.")
	if npc.visible or npc.is_in_group("interactable"):
		errores.append("El NPC quedó visible o interactuable antes de reanudar su ruta.")
	if npc.collision_layer != 0 or npc.collision_mask != 0:
		errores.append("El NPC recuperó colisiones exteriores antes de salir del interior.")

	# Un NPC puede abandonar su edificio mientras el jugador sigue dentro
	# de otro. Debe permanecer oculto hasta la salida del jugador y entonces
	# recuperar el estado visual, grupo y colisiones que tenía al entrar.
	var npc_cambio_edificio := CreatureScript.new() as Creature
	npc_cambio_edificio.collision_layer = 4
	npc_cambio_edificio.collision_mask = 6
	npc_cambio_edificio.add_to_group("torres_game_npc")
	npc_cambio_edificio.add_to_group("interactable")
	add_child(npc_cambio_edificio)
	await get_tree().process_frame
	zona.call("_guardar_estado_visibilidad_npc", npc_cambio_edificio)
	zona.call("desactivar_colision_npc_exterior", npc_cambio_edificio)
	npc_cambio_edificio.visible = false
	npc_cambio_edificio.remove_from_group("interactable")
	npc_cambio_edificio.set_meta("rutina_en_edificio", true)
	npc_cambio_edificio.set_meta("rutina_edificio_id", "panaderia")
	npc_cambio_edificio.reparent(habitacion, true)
	# Ejecuta la transición real del planificador mientras el jugador sigue
	# dentro: el NPC debe salir de la habitación, pero permanecer oculto.
	sistema._salir_de_edificio_para_cambiar_rutina(npc_cambio_edificio, "panaderia")
	if npc_cambio_edificio.get_parent() != contenedor_exterior:
		errores.append("El cambio de edificio no devolvió el NPC al contenedor exterior.")
	if bool(npc_cambio_edificio.get_meta("rutina_en_edificio", true)) or str(npc_cambio_edificio.get_meta("rutina_edificio_id", "x")) != "":
		errores.append("El cambio de edificio no limpió el estado de su edificio anterior.")
	if npc_cambio_edificio.visible or npc_cambio_edificio.is_in_group("interactable") or npc_cambio_edificio.collision_layer != 0:
		errores.append("El cambio de edificio reactivó al NPC antes de salir del interior.")
	zona.call("_restaurar_npcs_exteriores", [npc_cambio_edificio])
	if not npc_cambio_edificio.visible or not npc_cambio_edificio.is_in_group("interactable"):
		errores.append("El cambio de edificio no restauró visibilidad e interacción al salir.")
	if npc_cambio_edificio.collision_layer != 4 or npc_cambio_edificio.collision_mask != 6:
		errores.append("El cambio de edificio no restauró las colisiones originales al salir.")

	# La salida completa del edificio debe reutilizar la misma transición
	# para todos los NPCs que siguen dentro de habitaciones.
	var npc_colectivo := CreatureScript.new() as Creature
	npc_colectivo.collision_layer = 8
	npc_colectivo.collision_mask = 10
	npc_colectivo.set_meta("rutina_edificio_id", "panaderia")
	npc_colectivo.set_meta("rutina_en_edificio", true)
	npc_colectivo.visible = true
	npc_colectivo.add_to_group("torres_game_npc")
	npc_colectivo.add_to_group("interactable")
	habitacion.add_child(npc_colectivo)
	await get_tree().process_frame
	zona.call("_devolver_npcs_del_interior_al_exterior", [npc_colectivo])
	if npc_colectivo.get_parent() != contenedor_exterior:
		errores.append("La salida completa no devolvió el NPC al contenedor exterior.")
	if npc_colectivo.visible or npc_colectivo.is_in_group("interactable"):
		errores.append("La salida completa dejó visible o interactuable al NPC.")
	if npc_colectivo.collision_layer != 0 or npc_colectivo.collision_mask != 0:
		errores.append("La salida completa reactivó prematuramente las colisiones exteriores.")
	if npc_colectivo.global_position.distance_to(posicion_puerta_esperada) > 0.1:
		errores.append("La salida completa no devolvió al NPC al umbral de su edificio.")

	npc.queue_free()
	npc_colectivo.queue_free()
	npc_no_interactivo.queue_free()
	npc_interactivo.queue_free()
	npc_nuevo.queue_free()
	npc_cambio_edificio.queue_free()
	contenedor_exterior.queue_free()
	capa_interior.queue_free()
	zona.free()
	sistema.free()
	await get_tree().process_frame
	if not errores.is_empty():
		for error in errores:
			push_error("NPCBuildingEntryCollision: FAIL: " + error)
		get_tree().quit(1)
		return
	print("NPCBuildingEntryCollision: PASS")
	get_tree().quit(0)
