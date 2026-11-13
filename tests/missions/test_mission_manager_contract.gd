extends Node

const MissionManagerScript = preload("res://scripts/gameplay/mission_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var manager := MissionManagerScript.new() as MissionManagerService
	add_child(manager)

	var mision := {
		"id": "mision_contrato",
		"nombre": "Contrato de persistencia",
		"objetivos": [
			{
				"id": "mineral",
				"tipo": "recoger_item",
				"item_id": "mineral",
				"cantidad_requerida": 3
			},
			{
				"id": "dialogo",
				"tipo": "hablar_personaje",
				"personaje_id": "personaje_1",
				"cantidad_requerida": 1
			}
		],
		"recompensas": [{"tipo": "item", "item_id": "mineral", "cantidad": 1}]
	}
	manager._misiones = [mision]
	manager._misiones_por_id = {"mision_contrato": mision.duplicate(true)}

	manager.cargar_estado_partida({
		"estado": {"mision_contrato": "activa"},
		"progreso": {
			"mision_contrato": {
				"mineral": 99,
				"dialogo": -5,
				"objetivo_eliminado": 77
			}
		}
	})
	if manager.obtener_progreso("mision_contrato", "mineral") != 3:
		errores.append("El progreso restaurado excedió el máximo del objetivo.")
	if manager.obtener_progreso("mision_contrato", "dialogo") != 0:
		errores.append("El progreso negativo no se normalizó a cero.")
	var estado_serializado := manager.serializar_estado_partida()
	var progreso_serializado_variant: Variant = estado_serializado.get("progreso", {})
	var progreso_serializado: Dictionary = {}
	if progreso_serializado_variant is Dictionary:
		var misiones_serializadas: Dictionary = progreso_serializado_variant as Dictionary
		var mision_serializada_variant: Variant = misiones_serializadas.get("mision_contrato", {})
		if mision_serializada_variant is Dictionary:
			progreso_serializado = mision_serializada_variant as Dictionary
	if progreso_serializado.has("objetivo_eliminado"):
		errores.append("Se conservó progreso de un objetivo que ya no existe.")

	manager.cargar_estado_partida({
		"estado": {"mision_contrato": "estado_desconocido"},
		"progreso": {"mision_contrato": "dato_corrupto"}
	})
	if manager.obtener_estado_mision("mision_contrato").get("estado") != "disponible":
		errores.append("Un estado desconocido no volvió a disponible.")
	if manager.obtener_progreso("mision_contrato", "mineral") != 0:
		errores.append("Un bloque de progreso mal tipado no se rechazó.")

	var completadas: Array[Dictionary] = []
	var recompensas: Array = []
	manager.mision_completada.connect(func(datos: Dictionary) -> void:
		completadas.append(datos)
	)
	manager.recompensa_disponible.connect(func(_datos: Dictionary, items: Array[Dictionary]) -> void:
		recompensas.append(items.duplicate(true))
	)
	if not manager.aceptar_mision("mision_contrato"):
		errores.append("No se pudo aceptar la misión de prueba.")
	if manager.obtener_misiones_activas().size() != 1:
		errores.append("El listado de misiones activas no incluyó la misión aceptada.")
	manager.registrar_recoleccion("mineral", 3)
	manager.registrar_dialogo("personaje_1")
	# Un evento repetido después de completar no debe emitir otra recompensa.
	manager.registrar_recoleccion("mineral", 3)
	if completadas.size() != 1:
		errores.append("La finalización no fue idempotente.")
	var cantidad_recompensas := 0
	if recompensas.size() == 1 and recompensas[0] is Array:
		cantidad_recompensas = (recompensas[0] as Array).size()
	if recompensas.size() != 1 or cantidad_recompensas != 1:
		errores.append("La señal de recompensa no se emitió exactamente una vez.")
	if not manager.esta_completada("mision_contrato"):
		errores.append("La misión no quedó en estado completada.")
	if not manager.obtener_misiones_activas().is_empty():
		errores.append("Una misión completada permaneció en el listado de misiones activas.")

	# Una misión social debe bloquear el regreso hasta completar el objetivo previo.
	var mision_social := {
		"id": "mision_elian",
		"clave": "mision_elian",
		"nombre": "Una hornada a tiempo",
		"objetivos": [
			{
				"id": "consulta",
				"clave": "consulta_elian",
				"tipo": "hablar_personaje",
				"personaje_id": "darven",
				"cantidad_requerida": 1
			},
			{
				"id": "regreso",
				"clave": "regreso",
				"tipo": "hablar_personaje",
				"personaje_id": "elian",
				"cantidad_requerida": 1,
				"datos": {"requiere_objetivo_clave": "consulta_elian"}
			}
		],
		"recompensas": []
	}
	manager._misiones = [mision_social]
	manager._misiones_por_id = {"mision_elian": mision_social.duplicate(true)}
	manager.cargar_estado_partida({})
	if not manager.aceptar_mision("mision_elian"):
		errores.append("No se pudo aceptar la misión social de Elian.")
	if manager.cumple_requisito_dialogo({
		"mision_clave": "mision_elian",
		"estado": "activa",
		"objetivo_clave": "consulta_elian",
		"progreso_objetivo_min": 1
	}):
		errores.append("El diálogo de regreso se habilitó antes de consultar a Darven.")
	manager.registrar_dialogo("elian", "regreso")
	if manager.obtener_progreso("mision_elian", "regreso") != 0:
		errores.append("El objetivo de regreso avanzó antes de cumplir su requisito.")
	manager.registrar_dialogo("darven", "consulta_elian")
	if not manager.cumple_requisito_dialogo({
		"mision_clave": "mision_elian",
		"estado": "activa",
		"objetivo_clave": "consulta_elian",
		"progreso_objetivo_min": 1
	}):
		errores.append("El diálogo de regreso no se habilitó tras consultar a Darven.")
	manager.registrar_dialogo("elian", "regreso")
	if not manager.esta_completada("mision_elian"):
		errores.append("La misión social no se completó tras regresar con Elian.")

	# La reclamación de recompensas debe persistir sin cambiar el estado completado.
	manager._recompensas_reclamadas["mision_elian"] = true
	var guardado_recompensas := manager.serializar_estado_partida()
	var restaurado := MissionManagerScript.new() as MissionManagerService
	add_child(restaurado)
	restaurado._misiones = manager._misiones.duplicate(true)
	restaurado._misiones_por_id = manager._misiones_por_id.duplicate(true)
	restaurado.cargar_estado_partida(guardado_recompensas)
	if not bool(restaurado._recompensas_reclamadas.get("mision_elian", false)):
		errores.append("La reclamación de recompensas no persistió.")
	if restaurado.obtener_estado_mision("mision_elian").get("estado") != "completada":
		errores.append("La reclamación alteró el estado narrativo de misión completada.")
	var objeto_recompensa := manager._construir_objeto_recompensa({
		"tipo": "item",
		"cantidad": 2,
		"datos": {
			"item_data": {
				"id": "item_prueba",
				"nombre": "Objeto de prueba",
				"max_stack": 10
			}
		}
	})
	if str(objeto_recompensa.get("id", "")) != "item_prueba" or int(objeto_recompensa.get("cantidad", 0)) != 2:
		errores.append("La definición de objeto de recompensa no se normalizó correctamente.")

	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("MissionManagerContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("MissionManagerContract: PASS")
	get_tree().quit(0)
