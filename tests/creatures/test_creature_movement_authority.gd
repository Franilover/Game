extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var npc := CreatureScene.instantiate() as Creature
	if npc == null:
		_fail(["No se pudo crear la criatura para probar la autoridad de movimiento."])
		return
	add_child(npc)
	await get_tree().process_frame

	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if not is_instance_valid(movimiento):
		_fail(["La escena Creature debe contener su componente CreatureMovement."])
		return

	var ruta := PackedVector2Array([npc.global_position + Vector2(120.0, 0.0)])
	movimiento.establecer_ruta(ruta)
	if not movimiento.rutina_en_ejecucion():
		errores.append("establecer_ruta debe activar el control de rutina.")
	if not movimiento._control_rutina or movimiento._ruta_rutina != ruta:
		errores.append("La ruta debe permanecer como orden propietaria del movimiento.")

	# Una orden externa no debe reemplazar una ruta que sigue bajo control
	# de la agenda. La pausa tampoco debe borrar esa ruta.
	movimiento.tomar_control()
	movimiento.establecer_direccion(Vector2.DOWN)
	if not movimiento._control_rutina or not movimiento.rutina_en_ejecucion():
		errores.append("La dirección externa desplazó indebidamente la autoridad de la ruta.")
	movimiento.pausar_temporalmente()
	if not movimiento._pausado_temporalmente or not movimiento.rutina_en_ejecucion():
		errores.append("La pausa temporal debe conservar la ruta pendiente.")
	if npc.velocity.length_squared() > 0.001:
		errores.append("La pausa temporal debe detener inmediatamente el cuerpo.")
	movimiento.reanudar_temporalmente()
	if movimiento._pausado_temporalmente or not movimiento.rutina_en_ejecucion():
		errores.append("Reanudar debe devolver el control a la misma ruta.")

	# detener_por_rutina mantiene el modo de agenda incluso con ruta vacía;
	# detener libera ese modo. No son operaciones intercambiables.
	movimiento.detener_por_rutina()
	if not movimiento._control_rutina or movimiento.rutina_en_ejecucion():
		errores.append("detener_por_rutina debe conservar el bloqueo de rutina con la ruta vacía.")
	if not movimiento._ruta_rutina.is_empty():
		errores.append("detener_por_rutina debe limpiar los puntos de ruta.")
	movimiento.establecer_direccion(Vector2.RIGHT)
	movimiento.tomar_control()
	if not movimiento._control_rutina:
		errores.append("Una orden externa no debe liberar el bloqueo de rutina.")

	movimiento.detener()
	if movimiento._control_rutina or movimiento.rutina_en_ejecucion():
		errores.append("detener debe liberar el control de rutina.")
	if npc.velocity.length_squared() > 0.001:
		errores.append("detener debe dejar el cuerpo inmóvil.")
	movimiento.liberar_control()
	if movimiento._usar_direccion_externa or movimiento._direccion_externa.length_squared() > 0.001:
		errores.append("liberar_control debe limpiar el modo y la dirección externos.")

	npc.queue_free()
	await get_tree().process_frame
	if not errores.is_empty():
		_fail(errores)
		return
	print("CreatureMovementAuthority: PASS")
	get_tree().quit(0)


func _fail(errores: Array[String]) -> void:
	for error in errores:
		push_error("CreatureMovementAuthority: FAIL: " + error)
	get_tree().quit(1)
