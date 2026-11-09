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

	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("MissionManagerContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("MissionManagerContract: PASS")
	get_tree().quit(0)
