extends Node

const ZONE_MANAGER_SCRIPT = preload("res://scripts/world/zone_manager.gd")

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var flags_originales: Dictionary = GameState.world_state.flags.duplicate(true)
	var entidades := Node2D.new()
	entidades.name = "Entities"
	add_child(entidades)
	var jugador := Node2D.new()
	jugador.name = "Player"
	jugador.global_position = Vector2(73.0, 91.0)
	entidades.add_child(jugador)

	var mundo := Node2D.new()
	mundo.name = "World"
	add_child(mundo)
	var manager := ZONE_MANAGER_SCRIPT.new() as Node2D
	manager.name = "ZoneManager"
	mundo.add_child(manager)

	manager.entrar_reino("torres")
	await get_tree().process_frame
	await get_tree().process_frame
	if manager.obtener_tipo_actual() != "reino_torres":
		_fail("No se pudo preparar Torres para la prueba.")
		return

	manager.salir_de_reino_actual()
	for _frame in range(12):
		if manager.obtener_tipo_actual() == "mundo_abierto" and not bool(manager.obtener_diagnostico().get("transicionando", false)):
			break
		await get_tree().process_frame
	if manager.obtener_tipo_actual() != "mundo_abierto":
		_fail("La salida física de Torres no inició la expedición.")
		return
	if not manager.esta_en_expedicion():
		_fail("El estado de expedición no quedó activo.")
		return

	var estado := manager.obtener_estado_expedicion()
	if str(estado.get("id", "")) != "expedicion_contrato":
		_fail("No se conservó el ID estable de expedición.")
		return
	var origen_variant: Variant = estado.get("origen_posicion", {})
	if not origen_variant is Dictionary:
		_fail("No se serializó el punto de retorno.")
		return
	var origen := origen_variant as Dictionary
	if not is_equal_approx(float(origen.get("x", 0.0)), 73.0) or not is_equal_approx(float(origen.get("y", 0.0)), 91.0):
		_fail("El punto de retorno no coincide con la posición de salida.")
		return

	manager.consumir_salida_reino_pendiente()
	manager.entrar_reino("torres")
	for _frame in range(12):
		if manager.obtener_tipo_actual() == "reino_torres" and not bool(manager.obtener_diagnostico().get("transicionando", false)):
			break
		await get_tree().process_frame
	if manager.obtener_tipo_actual() != "reino_torres":
		_fail("RealmMenu no pudo regresar a Torres desde la expedición.")
		return

	var retorno: Dictionary = manager.consumir_retorno_expedicion()
	if not bool(retorno.get("valido", false)):
		_fail("Main no podría consumir el punto de retorno.")
		return
	var posicion_variant: Variant = retorno.get("posicion", Vector2.ZERO)
	if not posicion_variant is Vector2:
		_fail("El punto de retorno no se entregó como Vector2.")
		return
	jugador.global_position = posicion_variant
	if jugador.global_position.distance_to(Vector2(73.0, 91.0)) > 0.01:
		_fail("La posición del jugador no se pudo restaurar.")
		return
	if manager.consumir_retorno_expedicion().size() != 0:
		_fail("El punto de retorno se consumió más de una vez.")
		return
	if manager.esta_en_expedicion():
		_fail("La expedición siguió activa después de regresar.")
		return

	GameState.world_state.flags = flags_originales
	print("ExpeditionTravelContract: PASS")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("ExpeditionTravelContract: FAIL: " + message)
	get_tree().quit(1)
