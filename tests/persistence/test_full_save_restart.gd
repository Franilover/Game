extends Node

const SAVE_DIRECTORY := "user://partidas"
const CONTRACT_DIRECTORY := "user://contracts/full_restart"
const MANIFEST_PATH := CONTRACT_DIRECTORY + "/save_id.txt"
const SAVE_ID_PREFIX := "full_restart_probe_"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and args[0] == "write":
		_worker_write()
		return
	if args.size() == 1 and args[0] == "read":
		_worker_read()
		return
	_run_parent()


func _run_parent() -> void:
	var directory := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTRACT_DIRECTORY))
	if directory != OK and directory != ERR_ALREADY_EXISTS:
		_fail("No se pudo preparar el directorio del contrato.")
		return
	var writer_output: Array = []
	var writer_exit := _run_child("write", writer_output)
	if writer_exit != 0 or not _contains(writer_output, "FullSaveRestart: WRITE PASS"):
		_fail("El proceso escritor falló: %s" % "\n".join(writer_output))
		return

	var reader_output: Array = []
	var reader_exit := _run_child("read", reader_output)
	if reader_exit != 0 or not _contains(reader_output, "FullSaveRestart: READ PASS"):
		_fail("El proceso lector falló: %s" % "\n".join(reader_output))
		return

	var manifest := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest != null:
		var save_id := manifest.get_as_text().strip_edges()
		manifest.close()
		if not save_id.is_empty():
			var game_state: Node = get_tree().root.get_node("GameState")
			var repository: Variant = game_state.get("save_repository")
			repository.call("eliminar_partida", save_id)
	var manifest_absolute := ProjectSettings.globalize_path(MANIFEST_PATH)
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(manifest_absolute)
	print("FullSaveRestart: PASS (real GameState + save selector + main scene across independent processes)")
	get_tree().quit(0)


func _run_child(mode: String, output: Array) -> int:
	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	return OS.execute(executable, [
		"--headless", "--path", project_path,
		"res://tests/persistence/test_full_save_restart.tscn",
		"--", mode
	], output, true)


func _worker_write() -> void:
	var stamp := str(Time.get_unix_time_from_system()).replace(".", "_")
	var save_id := SAVE_ID_PREFIX + stamp
	var game_state: Node = get_tree().root.get_node("GameState")
	var repository: Variant = game_state.get("save_repository")
	var created_id := str(game_state.call("crear_partida", "Restart integration", "7348291", {
		"nombre": "Restart probe",
		"especie": "Humano"
	}))
	if created_id.is_empty():
		_fail("GameState.crear_partida no creó la partida.")
		return
	save_id = created_id

	var data := repository.call("leer_partida", save_id) as Dictionary
	if data.is_empty():
		_fail("No se pudo releer el archivo creado por GameState.")
		return
	var world: Dictionary = data.get("mundo", {}) as Dictionary
	if int(world.get("semilla", 0)) != 7348291:
		_fail("GameState no persistió la semilla solicitada.")
		return

	var state: Dictionary = data.get("estado", {}) as Dictionary
	state["player"] = {
		"health": 64,
		"mana": 37,
		"stamina": 1.75,
		"position_valid": true,
		"position": {"x": 321.5, "y": -87.25},
		"tile_valid": false,
		"tile": {"x": 0, "y": 0},
		"facing": {"x": -1.0, "y": 0.0}
	}
	state["flags"] = {
		"zona_actual_tipo": "reino_torres",
		"inventario_estado": {
			"items": [
				{"id": "full_restart_item", "cantidad": 3},
				{}, {}, {}, {}, {},
				{"id": "full_restart_hotbar", "cantidad": 4}
			],
			"hotbar_indices": [6, 7, 8, 9, 10, 11],
			"indice_hotbar_activo": 0,
			"equipo": {},
			"mano_izquierda_activa": 0,
			"mano_derecha_activa": 1
		},
		"misiones_estado": {
			"estado": {"restart_probe_mission": "completada"},
			"origen_misiones": {"restart_probe_mission": "contrato"},
			"progreso": {"restart_probe_mission": {"objetivo": 4}},
			"recompensas_reclamadas": {"restart_probe_mission": true}
		}
	}
	state["scene"] = "res://scenes/world/main.tscn"
	data["estado"] = state
	if not bool(repository.call("escribir_partida", save_id, data)):
		_fail("No se pudo preparar el snapshot real de la partida.")
		return

	var manifest := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest == null:
		_fail("No se pudo escribir el manifiesto de prueba.")
		return
	manifest.store_string(save_id)
	manifest.close()
	print("FullSaveRestart: WRITE PASS id=%s pid=%d" % [save_id, OS.get_process_id()])
	get_tree().quit(0)


func _worker_read() -> void:
	var manifest := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest == null:
		_fail("El proceso lector no encontró el manifiesto.")
		return
	var save_id := manifest.get_as_text().strip_edges()
	manifest.close()
	if save_id.is_empty():
		_fail("El manifiesto no contiene un ID de partida.")
		return

	# Mantener la prueba offline y evitar materialización de NPCs dependientes
	# del catálogo remoto. Torres es una zona local y debe reanudarse igualmente.
	var world_data: Node = get_tree().root.get_node("WorldData")
	world_data.set("cargado", false)
	var game_state: Node = get_tree().root.get_node("GameState")
	var save_repository: Variant = game_state.get("save_repository")
	var persisted: Dictionary = save_repository.call("leer_partida", save_id) as Dictionary
	var valid_save := bool(game_state.call("_datos_partida_cargables", save_id, persisted))
	print("FullSaveRestart: READER_DIAGNOSTIC id=%s path=%s exists=%s keys=%s valid=%s" % [
		save_id,
		str(save_repository.get("directorio")),
		str(not persisted.is_empty()),
		str(persisted.keys()),
		str(valid_save)
	])
	if not valid_save:
		_fail("El proceso lector no puede validar el archivo creado en el proceso escritor.")
		return
	var menu_scene := load("res://scenes/ui/start_menu.tscn") as PackedScene
	if menu_scene == null:
		_fail("No se pudo cargar el menú real.")
		return
	var menu := menu_scene.instantiate() as Control
	if menu == null:
		_fail("No se pudo instanciar el menú real.")
		return
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame

	# Abrir el selector real desde el menú y usar el mismo callback que el
	# botón Jugar de cada partida guardada.
	menu.call("_abrir_selector_partidas")
	await get_tree().process_frame
	var selector := menu.get_node_or_null("LocalSaveSelector")
	if selector == null:
		_fail("El menú no creó el selector de partidas.")
		return
	selector.call("_jugar_partida", save_id)

	var frames := 0
	var main: Node = null
	var player: Player = null
	var inventory: GarliaInventory = null
	while frames < 420:
		main = get_tree().current_scene
		if is_instance_valid(main) and str(main.scene_file_path) == "res://scenes/world/main.tscn":
			player = main.get_node_or_null("Entities/Player") as Player
			inventory = main.get_node_or_null("UI/Inventory") as GarliaInventory
			if is_instance_valid(player) and is_instance_valid(inventory):
				break
		await get_tree().process_frame
		frames += 1
	if not is_instance_valid(player) or not is_instance_valid(inventory):
		_fail("La selección de partida no llegó al runtime Main con Player e inventario.")
		return

	player.set_process(false)
	player.set_physics_process(false)
	player.eterium.aplicar_runtime({"limite_estable_s": 100.0, "escala_runtime": 1.0}, [])
	var species_rule := {
		"especie_eterium_v1": {"especie_id": "full_restart_probe", "capacidad_base": 100},
		"eterium_inicial": 100,
		"vida_eterium_compartidos": false
	}
	if not player.eterium.aplicar_especie(species_rule, "full_restart_probe"):
		_fail("No se pudo resolver Eterium local para la verificación.")
		return
	player.eterium.marcar_especie_configuracion_resuelta()

	frames = 0
	while frames < 180 and (
		not bool(game_state.get("_partida_aplicada_en_escena"))
		or not bool(game_state.get("_estado_vital_restaurado_en_escena"))
	):
		await get_tree().process_frame
		frames += 1

	var errors: Array[String] = []
	if str(game_state.get("active_save_id")) != save_id:
		errors.append("GameState no activó el ID seleccionado.")
	if int(game_state.get("world_state").get("world_seed")) != 7348291:
		errors.append("La semilla no fue cargada por GameState.")
	var zone_manager := main.get_node_or_null("World/ZoneManager")
	if not is_instance_valid(zone_manager) or str(zone_manager.call("obtener_tipo_actual")) != "reino_torres":
		errors.append("El menú no reanudó la zona guardada de Torres.")
	if player.global_position != Vector2(321.5, -87.25):
		errors.append("La posición no se restauró en Main: %s" % str(player.global_position))
	if player.facing != Vector2.LEFT:
		errors.append("La orientación del jugador no se restauró.")
	if player.health != 64 or player.mana != 37:
		errors.append("Salud/Eterium no se restauraron: %d/%d" % [player.health, player.mana])
	if not is_equal_approx(player.stamina, 1.75):
		errors.append("La stamina no se restauró: %s" % str(player.stamina))
	if inventory.items.size() <= 6 or str(inventory.items[6].get("id", "")) != "full_restart_hotbar":
		errors.append("El inventario real no restauró el objeto de hotbar.")
	if inventory.hotbar_indices.size() != 6 or inventory.hotbar_indices[0] != 6:
		errors.append("La selección de hotbar no se restauró.")
	if not bool(game_state.get("_partida_aplicada_en_escena")):
		errors.append("GameState no marcó la aplicación del estado.")
	if not bool(game_state.get("_estado_vital_restaurado_en_escena")):
		errors.append("La restauración vital no terminó.")
	var mission_manager: Node = get_tree().root.get_node("MissionManager")
	var mission_state: Dictionary = mission_manager.call("serializar_estado_partida") as Dictionary
	var mission_status: Dictionary = mission_state.get("estado", {}) as Dictionary
	var mission_progress: Dictionary = mission_state.get("progreso", {}) as Dictionary
	var mission_rewards: Dictionary = mission_state.get("recompensas_reclamadas", {}) as Dictionary
	if str(mission_status.get("restart_probe_mission", "")) != "completada":
		errors.append("El estado de misión no sobrevivió al reinicio.")
	var objective_progress: Dictionary = mission_progress.get("restart_probe_mission", {}) as Dictionary
	if int(objective_progress.get("objetivo", 0)) != 4:
		errors.append("El progreso de misión no sobrevivió al reinicio.")
	if not bool(mission_rewards.get("restart_probe_mission", false)):
		errors.append("La recompensa reclamada no sobrevivió al reinicio.")

	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	print("FullSaveRestart: READ PASS id=%s pid=%d" % [save_id, OS.get_process_id()])
	get_tree().quit(0)


func _contains(output: Array, needle: String) -> bool:
	return "\n".join(output).contains(needle)


func _fail(message: String) -> void:
	push_error("FullSaveRestart: FAIL: " + message)
	get_tree().quit(1)
