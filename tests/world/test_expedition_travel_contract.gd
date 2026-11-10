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
	jugador.global_position = Vector2(1080.0, 0.0)
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

	# Ejercitar el mismo camino que usa el Area2D de salida de Torres:
	# la escena emite salida_solicitada y ZoneManager debe enrutarla al bosque.
	var zona_torres: Node = manager.obtener_zona_actual()
	if zona_torres == null or zona_torres.get_node_or_null("ExpeditionEntrance") == null:
		_fail("Torres no tiene la entrada de expedición en el antiguo portón este.")
		return
	if zona_torres.get_node_or_null("Exit") != null:
		_fail("La antigua salida/teletransporte del portón sigue presente.")
		return
	if zona_torres == null or not zona_torres.has_signal("salida_solicitada"):
		_fail("La escena de Torres no expone la señal de salida física.")
		return
	zona_torres.emit_signal("salida_solicitada")
	for _frame in range(120):
		if manager.obtener_tipo_actual() == "expedicion:bosque":
			break
		await get_tree().process_frame
	await get_tree().process_frame
	if manager.obtener_tipo_actual() != "expedicion:bosque":
		_fail("La salida física de Torres no inició la zona dedicada de bosque.")
		return
	if not manager.esta_en_expedicion():
		_fail("El estado de expedición no quedó activo.")
		return
	var generador: WorldGenerator = manager.obtener_world_generator()
	if generador == null:
		_fail("La expedición no expuso su WorldGenerator.")
		return
	if not generador.usar_semilla_fija or generador.map_seed != 31415926:
		_fail("La zona de bosque no usa la semilla fija esperada.")
		return
	if generador.bioma_forzado_id != "fdc97953-f400-4f39-9b54-0a1c85f2c9a1":
		_fail("La zona no tiene configurado el ID canónico del bioma Bosque.")
		return

	var estado: Dictionary = manager.obtener_estado_expedicion()
	if str(estado.get("id", "")) != "primera_expedicion":
		_fail("No se conservó el ID estable de expedición.")
		return
	var origen_variant: Variant = estado.get("origen_posicion", {})
	if not origen_variant is Dictionary:
		_fail("No se serializó el punto de retorno.")
		return
	var origen := origen_variant as Dictionary
	if not is_equal_approx(float(origen.get("x", 0.0)), 900.0) or not is_equal_approx(float(origen.get("y", 0.0)), 0.0):
		_fail("El punto de retorno no coincide con la posición de salida.")
		return

	manager.consumir_salida_reino_pendiente()
	manager.entrar_reino("torres")
	for _frame in range(60):
		if manager.obtener_tipo_actual() == "reino_torres":
			break
		await get_tree().process_frame
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
	if jugador.global_position.distance_to(Vector2(900.0, 0.0)) > 0.01:
		_fail("La posición del jugador no se pudo restaurar.")
		return
	if manager.consumir_retorno_expedicion().size() != 0:
		_fail("El punto de retorno se consumió más de una vez.")
		return
	if manager.esta_en_expedicion():
		_fail("La expedición siguió activa después de regresar.")
		return

	# Desde Mundo Abierto, seleccionar Torres debe cargar la escena fija local.
	manager.entrar_mundo_abierto()
	for _frame in range(120):
		if manager.obtener_tipo_actual() == "mundo_abierto":
			break
		await get_tree().process_frame
	manager.entrar_reino("torres")
	for _frame in range(120):
		if manager.obtener_tipo_actual() == "reino_torres":
			break
		await get_tree().process_frame
	if manager.obtener_tipo_actual() != "reino_torres":
		_fail("Viajar a Torres desde Mundo Abierto no cargó reino_torres.")
		return
	var escena_torres: Node = manager.obtener_zona_actual()
	if not is_instance_valid(escena_torres) or escena_torres.scene_file_path != "res://scenes/kingdom/reino_torres.tscn":
		_fail("El destino Torres no corresponde a su escena fija local.")
		return

	# El selector espacial debe devolver el mismo bioma forzado en cualquier coordenada.
	var areas := WorldTerrainAreas.new()
	areas.configurar(31415926)
	var bioma_prueba := [{
		"id": "bioma-bosque-prueba",
		"ecosistemas": [{"id": "ecosistema-bosque-prueba"}]
	}]
	var ecosistemas_prueba := [{"id": "ecosistema-bosque-prueba"}]
	var indices_prueba := {"ecosistema-bosque-prueba": 0}
	areas.cargar_datos(bioma_prueba, ecosistemas_prueba, indices_prueba)
	if not areas.establecer_bioma_forzado_id("bioma-bosque-prueba"):
		_fail("No se pudo activar el bioma forzado.")
		return
	for x in range(-128, 129, 16):
		for y in range(-128, 129, 16):
			if areas.bioma_index_at_tile(Vector2i(x, y)) != 0:
				_fail("El bioma forzado varió entre coordenadas.")
				return

	GameState.world_state.flags = flags_originales
	print("ExpeditionTravelContract: PASS")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("ExpeditionTravelContract: FAIL: " + message)
	get_tree().quit(1)
