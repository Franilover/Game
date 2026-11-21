extends Node

const FactoryScript = preload("res://scripts/world/world_entity_factory.gd")
const CreatureScript = preload("res://scripts/creatures/creature.gd")
const GarumiScript = preload("res://scripts/creatures/garumi.gd")
const WorldPropScript = preload("res://scripts/world/world_prop.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var factory := FactoryScript.new()

	# Una criatura normal se conserva para reutilización mientras haya cupo.
	var criatura := CreatureScript.new() as Creature
	factory.reciclar_criatura(criatura)
	if factory._creature_pool.size() != 1:
		errores.append("El pool no conservó una criatura cuando tenía capacidad.")

	# Los Garumis mantienen identidad social propia y nunca comparten un nodo
	# reciclado con otra aparición del mundo.
	var garumi := GarumiScript.new() as Garumi
	factory.reciclar_criatura(garumi)
	if not factory._garumi_pool.is_empty():
		errores.append("Un Garumi fue añadido al pool y podría heredar identidad social.")
	if not garumi.is_queued_for_deletion():
		errores.append("El Garumi descargado no fue liberado.")

	# Llenar el pool hasta su límite y verificar que el siguiente nodo se libera.
	for indice in range(FactoryScript.MAX_POOLED_CREATURES - factory._creature_pool.size()):
		factory._creature_pool.append(CreatureScript.new() as Creature)
	var criatura_excedente := CreatureScript.new() as Creature
	factory.reciclar_criatura(criatura_excedente)
	if factory._creature_pool.size() != FactoryScript.MAX_POOLED_CREATURES:
		errores.append("El pool de criaturas superó o no alcanzó su límite.")
	if not criatura_excedente.is_queued_for_deletion():
		errores.append("La criatura excedente no fue liberada.")

	# La misma política acota los props sin cambiar sus datos persistentes,
	# que ya fueron guardados por WorldEntityManager antes de reciclarlos.
	for indice in range(FactoryScript.MAX_POOLED_PROPS):
		factory._prop_pool.append(WorldPropScript.new() as WorldProp)
	var prop_excedente := WorldPropScript.new() as WorldProp
	factory.reciclar_prop(prop_excedente)
	if factory._prop_pool.size() != FactoryScript.MAX_POOLED_PROPS:
		errores.append("El pool de props superó o no alcanzó su límite.")
	if not prop_excedente.is_queued_for_deletion():
		errores.append("El prop excedente no fue liberado.")

	var diagnostico := factory.obtener_diagnostico_pool()
	if int(diagnostico.get("descartadas_criaturas", 0)) != 1:
		errores.append("El diagnóstico no contó la criatura descartada.")
	if int(diagnostico.get("descartadas_garumis", 0)) != 1:
		errores.append("El diagnóstico no contó el Garumi liberado.")
	if int(diagnostico.get("descartadas_props", 0)) != 1:
		errores.append("El diagnóstico no contó el prop descartado.")

	for nodo in factory._creature_pool:
		if is_instance_valid(nodo):
			nodo.free()
	for nodo in factory._prop_pool:
		if is_instance_valid(nodo):
			nodo.free()
	factory.free()

	await get_tree().process_frame
	if is_instance_valid(garumi) or is_instance_valid(criatura_excedente) or is_instance_valid(prop_excedente):
		errores.append("Una entidad descartada permaneció viva después del frame.")

	if not errores.is_empty():
		for error in errores:
			push_error("WorldEntityPool: FAIL: " + error)
		get_tree().quit(1)
		return
	print("WorldEntityPool: PASS")
	get_tree().quit(0)
