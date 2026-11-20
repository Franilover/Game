extends Node

var _world_data_cargado_original: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	# Main no necesita materializar NPCs para verificar la restauración del
	# jugador. Evitar ese trabajo lateral mantiene aislado el contrato.
	_world_data_cargado_original = WorldData.cargado
	WorldData.cargado = false
	GameState.active_save_id = "main_scene_resume_integration_probe"
	GameState.active_save_name = "Main scene resume integration"
	GameState._partida_aplicada_en_escena = false
	GameState._estado_vital_restaurado_en_escena = false
	GameState._guardado_rapido_conectado = false
	GameState.world_state.flags.clear()
	GameState.world_state.flags["zona_actual_tipo"] = "reino_torres"
	GameState.world_state.flags["bienvenida_torres_vista"] = true
	GameState.world_state.flags["inventario_estado"] = {
		"items": [
			{"id": "main_scene_resume_left", "cantidad": 2},
			{},
			{},
			{},
			{},
			{},
			{"id": "main_scene_resume_hotbar", "cantidad": 4}
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

	var main_scene: PackedScene = load("res://scenes/world/main.tscn") as PackedScene
	if main_scene == null:
		await _limpiar_estado_global()
		_finalizar(["No se pudo cargar scenes/world/main.tscn."])
		return
	var main: Node = main_scene.instantiate()
	main_scene = null
	if main == null:
		await _limpiar_estado_global()
		_finalizar(["No se pudo instanciar scenes/world/main.tscn."])
		return
	get_tree().root.add_child(main)
	get_tree().current_scene = main

	var frames := 0
	var zone_manager: Node = null
	var player: Player = null
	var inventory: GarliaInventory = null
	while frames < 360:
		zone_manager = main.get_node_or_null("World/ZoneManager")
		player = main.get_node_or_null("Entities/Player") as Player
		inventory = main.get_node_or_null("UI/Inventory") as GarliaInventory
		if (
			is_instance_valid(zone_manager)
			and str(zone_manager.call("obtener_tipo_actual")) == "reino_torres"
			and is_instance_valid(player)
			and is_instance_valid(inventory)
		):
			break
		await get_tree().process_frame
		frames += 1

	var errores: Array[String] = []
	if not is_instance_valid(zone_manager) or str(zone_manager.call("obtener_tipo_actual")) != "reino_torres":
		errores.append("Main no inició Torres desde el tipo de zona guardado.")
	if not is_instance_valid(player):
		errores.append("Main no conservó el Player real de la escena principal.")
	if not is_instance_valid(inventory):
		errores.append("Main no conservó la instancia real del inventario.")
	if not errores.is_empty():
		await _limpiar_main(main)
		_finalizar(errores)
		return

	# Detener movimiento/regeneración mientras se inspecciona la aplicación del
	# snapshot: el test mide el valor restaurado, no su evolución posterior.
	player.set_process(false)
	player.set_physics_process(false)

	# Resolver Eterium localmente para no depender de credenciales ni red.
	player.eterium.aplicar_runtime({
		"limite_estable_s": 100.0,
		"escala_runtime": 1.0
	}, [])
	var regla_especie := {
		"especie_eterium_v1": {
			"especie_id": "main_scene_resume_probe",
			"capacidad_base": 100
		},
		"eterium_inicial": 100,
		"vida_eterium_compartidos": false
	}
	if not player.eterium.aplicar_especie(regla_especie, "main_scene_resume_probe"):
		errores.append("No se pudo resolver la configuración local de Eterium.")
	player.eterium.marcar_especie_configuracion_resuelta()

	# Esperar la aplicación automática que Main programó al configurar
	# GameState. El Player permanece pausado para medir los valores iniciales,
	# antes de que física o regeneración de dash los modifiquen.
	frames = 0
	while frames < 120 and (
		not GameState._partida_aplicada_en_escena
		or not GameState._estado_vital_restaurado_en_escena
	):
		await get_tree().process_frame
		frames += 1

	if str(zone_manager.call("obtener_tipo_actual")) != "reino_torres":
		errores.append("La zona cambió inesperadamente durante la restauración.")
	if player.global_position != Vector2(321.5, -87.25):
		errores.append("Main no restauró la posición guardada después del spawn de Torres: %s." % str(player.global_position))
	if player.facing != Vector2.LEFT:
		errores.append("Main no restauró la orientación del Player.")
	if not is_equal_approx(player.stamina, 0.65):
		errores.append("Main no restauró la stamina del snapshot: %s." % str(player.stamina))
	if player.health != 64:
		errores.append("Main no restauró la salud.")
	if player.mana != 37:
		errores.append("Main no restauró el Eterium.")
	if inventory.items.size() <= 6 or str(inventory.items[6].get("id", "")) != "main_scene_resume_hotbar":
		errores.append("Main no restauró los objetos en el inventario real.")
	if inventory.hotbar_indices.size() != 6 or inventory.hotbar_indices[0] != 6:
		errores.append("Main no restauró la selección de hotbar.")
	if not GameState._partida_aplicada_en_escena:
		errores.append("GameState no marcó la aplicación del snapshot en Main.")
	if not GameState._estado_vital_restaurado_en_escena:
		errores.append("La restauración vital no terminó dentro de Main.")

	await _limpiar_main(main)
	_finalizar(errores)


func _limpiar_main(main: Node) -> void:
	await _limpiar_estado_global()
	if is_instance_valid(main):
		get_tree().current_scene = self
		# Este harness es headless y no necesita una animación de salida:
		# liberar el runtime completo evita dejar NPCs/deferred nodes al salir.
		main.free()
	await get_tree().process_frame
	await get_tree().process_frame


func _limpiar_estado_global() -> void:
	GameState.active_save_id = ""
	GameState.active_save_name = ""
	GameState._partida_aplicada_en_escena = false
	GameState._estado_vital_restaurado_en_escena = false
	GameState.configurar_dependencias(null, null, null, null, null, null)
	WorldData.cargado = _world_data_cargado_original
	await get_tree().process_frame


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("MainSceneResume: FAIL: " + error)
		get_tree().quit(1)
		return
	print("MainSceneResume: PASS")
	get_tree().quit(0)
