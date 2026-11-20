extends Node

const CreatureScript = preload("res://scripts/creatures/creature.gd")
const WorldEntityManagerScript = preload("res://scripts/world/world_entity_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var manager: Variant = WorldEntityManagerScript.new()
	var criatura: Creature = CreatureScript.new() as Creature
	criatura.configurar({"id": "criatura_sin_clave", "nombre": "Criatura de prueba"})
	criatura.global_position = Vector2(418.5, -93.25)
	criatura.velocity = Vector2(12.0, -4.0)
	criatura.restaurar_estado_vital(37, true)

	manager.guardar_estado_entidad(criatura, Vector2i(2, -3))

	var clave_esperada := "2:-3:criatura_sin_clave"
	var clave_duplicada := "2:-3:2:-3:criatura_sin_clave"
	if not manager._runtime_state_by_key.has(clave_esperada):
		errores.append("La criatura sin runtime_instance_key no se guardó bajo su ID natural.")
	if manager._runtime_state_by_key.has(clave_duplicada):
		errores.append("La clave runtime duplicó las coordenadas del chunk.")

	var estado := manager.obtener_estado_criatura(
		Vector2i(2, -3),
		"criatura_sin_clave"
	)
	if estado.is_empty():
		errores.append("El estado guardado no se pudo recuperar mediante el ID natural.")
	else:
		if estado.get("position") != Vector2(418.5, -93.25):
			errores.append("La posición no sobrevivió al guardado y recuperación.")
		if int(estado.get("health", -1)) != 37:
			errores.append("La vida no sobrevivió al guardado y recuperación.")
		if estado.get("velocity") != Vector2(12.0, -4.0):
			errores.append("La velocidad no sobrevivió al guardado y recuperación.")

	var datos_chunk := manager.obtener_datos_chunk(Vector2i(2, -3), "criaturas")
	if datos_chunk.size() != 1 or str(datos_chunk[0].get("runtime_instance_key", "")) != "criatura_sin_clave":
		errores.append("El registro DATA no conservó la misma clave natural.")

	criatura.free()
	manager.free()

	if not errores.is_empty():
		for error in errores:
			push_error("WorldEntityRuntimeKey: FAIL: " + error)
		get_tree().quit(1)
		return
	print("WorldEntityRuntimeKey: PASS")
	get_tree().quit(0)
