extends Node

const PlayerScene: PackedScene = preload("res://scenes/characters/player.tscn")
const InventoryScene: PackedScene = preload("res://scenes/ui/inventory.tscn")
const ZoneManagerScript = preload("res://scripts/world/zone_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	var zone_manager := Node2D.new()
	zone_manager.name = "ZoneManager"
	zone_manager.set_script(ZoneManagerScript)
	world.add_child(zone_manager)

	var entities := Node2D.new()
	entities.name = "Entities"
	add_child(entities)
	var player := PlayerScene.instantiate() as Player
	if player == null:
		_finalizar(["No se pudo instanciar Player."])
		return
	player.name = "Player"
	entities.add_child(player)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var inventory := InventoryScene.instantiate() as GarliaInventory
	if inventory == null:
		_finalizar(["No se pudo instanciar el inventario real."])
		return
	inventory.name = "Inventory"
	ui.add_child(inventory)

	await get_tree().process_frame

	# Preparar un snapshot equivalente al que entrega iniciar_partida(),
	# pero sin leer ni sobrescribir archivos reales del usuario.
	GameState.active_save_id = ""
	GameState.active_save_name = "Resume integration"
	GameState.world_state.flags.clear()
	GameState.world_state.flags["zona_actual_tipo"] = "reino_torres"
	GameState.world_state.flags["inventario_estado"] = {
		"items": [
			{"id": "resume_probe_left", "cantidad": 2},
			{},
			{},
			{},
			{},
			{},
			{"id": "resume_probe_hotbar", "cantidad": 3}
		],
		"hotbar_indices": [6, 7, 8, 9, 10, 11],
		"indice_hotbar_activo": 0,
		"equipo": {},
		"mano_izquierda_activa": 0,
		"mano_derecha_activa": 1
	}
	GameState.player_state.health = 64
	GameState.player_state.mana = 37
	GameState.player_state.stamina = 0.65
	GameState.player_state.position = Vector2(321.5, -87.25)
	GameState.player_state.position_valida = true
	GameState.player_state.facing = Vector2.LEFT
	GameState._partida_aplicada_en_escena = false
	GameState._estado_vital_restaurado_en_escena = false

	zone_manager.configurar_dependencias(get_node_or_null("/root/SupabaseClient") as GarliaSupabaseClient)
	zone_manager.iniciar()

	var frames := 0
	while frames < 180:
		if zone_manager.obtener_tipo_actual() == "reino_torres" and is_instance_valid(zone_manager.obtener_zona_actual()):
			break
		await get_tree().process_frame
		frames += 1

	if zone_manager.obtener_tipo_actual() != "reino_torres":
		errores.append("ZoneManager no reanudó la zona guardada de Torres.")
	if not is_instance_valid(zone_manager.obtener_zona_actual()):
		errores.append("La zona guardada no produjo una escena activa.")

	player.eterium.aplicar_runtime({
		"limite_estable_s": 100.0,
		"escala_runtime": 1.0
	}, [])
	var regla_especie := {
		"especie_eterium_v1": {
			"especie_id": "main_session_resume_probe",
			"capacidad_base": 100
		},
		"eterium_inicial": 100,
		"vida_eterium_compartidos": false
	}
	if not player.eterium.aplicar_especie(regla_especie, "main_session_resume_probe"):
		errores.append("No se pudo preparar la fisiología del Player.")
	player.eterium.marcar_especie_configuracion_resuelta()

	GameState.configurar_dependencias(inventory, player, null, null, null, WorldData)
	GameState._aplicar_estado_al_juego()

	if player.global_position != Vector2(321.5, -87.25):
		errores.append("La posición guardada no sobrevivió al inicio de la zona.")
	if player.facing != Vector2.LEFT:
		errores.append("La orientación guardada no se restauró.")
	if not is_equal_approx(player.stamina, 0.65):
		errores.append("La stamina guardada no se restauró.")
	if player.health != 64:
		errores.append("La salud guardada no se restauró.")
	if player.mana != 37:
		errores.append("El Eterium guardado no se restauró.")
	if inventory.items.size() <= 6 or str(inventory.items[6].get("id", "")) != "resume_probe_hotbar":
		errores.append("El inventario guardado no se restauró en el runtime real.")
	if inventory.hotbar_indices.size() != 6 or inventory.hotbar_indices[0] != 6:
		errores.append("La hotbar guardada no se restauró.")
	if not GameState._partida_aplicada_en_escena:
		errores.append("GameState no marcó la sesión como aplicada.")

	GameState.configurar_dependencias(null, null, null, null, null, null)
	zone_manager.queue_free()
	player.queue_free()
	inventory.queue_free()
	await get_tree().process_frame
	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("MainSessionResume: FAIL: " + error)
		get_tree().quit(1)
		return
	print("MainSessionResume: PASS")
	get_tree().quit(0)
