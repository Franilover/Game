extends Node

const CONTRACT_DIRECTORY := "user://contracts/home_process_restart"
const MANIFEST_PATH := CONTRACT_DIRECTORY + "/save_id.txt"
const SAVE_ID_PREFIX := "home_process_restart_"


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
	if writer_exit != 0 or not _contains(writer_output, "HomeProcessRestart: WRITE PASS"):
		_fail("El proceso escritor falló: %s" % "\n".join(writer_output))
		return

	var reader_output: Array = []
	var reader_exit := _run_child("read", reader_output)
	if reader_exit != 0 or not _contains(reader_output, "HomeProcessRestart: READ PASS"):
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
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_PATH))
	print("HomeProcessRestart: PASS (two processes, real menu, Main, Hogar and open interior)")
	get_tree().quit(0)


func _run_child(mode: String, output: Array) -> int:
	return OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/persistence/test_home_process_restart.tscn",
		"--", mode
	], output, true)


func _worker_write() -> void:
	var stamp := str(Time.get_unix_time_from_system()).replace(".", "_")
	var game_state: Node = get_tree().root.get_node("GameState")
	var save_id := str(game_state.call("crear_partida", "Hogar restart", "7348292", {
		"nombre": "Home restart probe",
		"especie": "Humano"
	}))
	if save_id.is_empty():
		_fail("GameState.crear_partida no creó la partida.")
		return

	var repository: Variant = game_state.get("save_repository")
	var data := repository.call("leer_partida", save_id) as Dictionary
	if data.is_empty():
		_fail("No se pudo releer el archivo creado.")
		return

	var home_state := {
		"version": 1,
		"decoraciones": [
			{"tipo": "arbol", "x": 180.0, "y": 220.0, "giro": 0.0},
			{
				"tipo": "cofre", "x": -140.0, "y": 96.0, "giro": 0.0,
				"cofre_id": "restart_outer_chest",
				"contenido": [{"id": "restart_outer_ore", "cantidad": 5}]
			}
		],
		"interior_abierto": true,
		"interior_decoraciones": {
			"version": 2,
			"siguiente_id_cofre": 9,
			"decoraciones": [
				{"tipo": "cama", "x": -96.0, "y": -48.0, "giro": 0.0},
				{
					"tipo": "cofre", "x": 112.0, "y": 64.0, "giro": 0.0,
					"cofre_id": "restart_inner_chest",
					"contenido": [{"id": "restart_inner_gem", "cantidad": 2}]
				}
			]
		}
	}
	var state: Dictionary = data.get("estado", {}) as Dictionary
	state["player"] = {
		"health": 64,
		"mana": 37,
		"stamina": 0.65,
		"position_valid": true,
		"position": {"x": 4000.0, "y": 0.0},
		"tile_valid": false,
		"tile": {"x": 0, "y": 0},
		"facing": {"x": -1.0, "y": 0.0}
	}
	state["flags"] = {
		"zona_actual_tipo": "hogar",
		"hogar_estado": home_state.duplicate(true),
		"estado_zona_actual": home_state.duplicate(true),
		"inventario_estado": {
			"items": [
				{"id": "home_restart_item", "cantidad": 3},
				{}, {}, {}, {}, {}, {}
			],
			"hotbar_indices": [0, 1, 2, 3, 4, 5],
			"indice_hotbar_activo": 0,
			"equipo": {},
			"mano_izquierda_activa": 0,
			"mano_derecha_activa": 1
		}
	}
	state["scene"] = "res://scenes/world/main.tscn"
	data["estado"] = state
	if not bool(repository.call("escribir_partida", save_id, data)):
		_fail("No se pudo escribir el snapshot de Hogar.")
		return

	var manifest := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest == null:
		_fail("No se pudo crear el manifiesto del contrato.")
		return
	manifest.store_string(save_id)
	manifest.close()
	print("HomeProcessRestart: WRITE PASS id=%s pid=%d stamp=%s" % [save_id, OS.get_process_id(), stamp])
	get_tree().quit(0)


func _worker_read() -> void:
	var manifest := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest == null:
		_fail("El lector no encontró el manifiesto.")
		return
	var save_id := manifest.get_as_text().strip_edges()
	manifest.close()
	if save_id.is_empty():
		_fail("El manifiesto está vacío.")
		return

	# Esta integración debe funcionar sin catálogo remoto ni conexión Supabase.
	var world_data: Node = get_tree().root.get_node("WorldData")
	world_data.set("cargado", false)
	var game_state: Node = get_tree().root.get_node("GameState")
	var repository: Variant = game_state.get("save_repository")
	var persisted: Dictionary = repository.call("leer_partida", save_id) as Dictionary
	if not bool(game_state.call("_datos_partida_cargables", save_id, persisted)):
		_fail("El proceso lector no pudo validar la partida de Hogar.")
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
	menu.call("_abrir_selector_partidas")
	await get_tree().process_frame
	var selector := menu.get_node_or_null("LocalSaveSelector")
	if selector == null:
		_fail("El menú no creó el selector de partidas.")
		return

	Events.scene_changed.connect(_freeze_player_on_main, CONNECT_ONE_SHOT)
	selector.call("_jugar_partida", save_id)

	var frames := 0
	var main: Node = null
	var player: Player = null
	var zone_manager: Node = null
	var home: Node = null
	while frames < 600:
		main = get_tree().current_scene
		if is_instance_valid(main):
			zone_manager = main.get_node_or_null("World/ZoneManager")
			player = main.get_node_or_null("Entities/Player") as Player
			if is_instance_valid(zone_manager) and is_instance_valid(player):
				if str(zone_manager.call("obtener_tipo_actual")) == "hogar":
					home = zone_manager.call("obtener_zona_actual") as Node
					if is_instance_valid(home) and home.get_node_or_null("InteriorCasa") != null:
						break
		await get_tree().process_frame
		frames += 1
	if not is_instance_valid(home) or not is_instance_valid(player):
		_fail("Main no reanudó la zona Hogar con Player.")
		return

	player.set_process(false)
	player.set_physics_process(false)
	player.eterium.aplicar_runtime({"limite_estable_s": 100.0, "escala_runtime": 1.0}, [])
	var species_rule := {
		"especie_eterium_v1": {"especie_id": "home_restart_probe", "capacidad_base": 100},
		"eterium_inicial": 100,
		"vida_eterium_compartidos": false
	}
	if not player.eterium.aplicar_especie(species_rule, "home_restart_probe"):
		_fail("No se pudo resolver Eterium local para la verificación.")
		return
	player.eterium.marcar_especie_configuracion_resuelta()
	game_state.call("_restaurar_estado_vital_pendiente")

	frames = 0
	while frames < 180 and (
		not bool(game_state.get("_partida_aplicada_en_escena"))
		or not bool(game_state.get("_estado_vital_restaurado_en_escena"))
	):
		await get_tree().process_frame
		frames += 1

	var errors: Array[String] = []
	if str(game_state.get("active_save_id")) != save_id:
		errors.append("GameState no activó la partida seleccionada.")
	if str(zone_manager.call("obtener_tipo_actual")) != "hogar":
		errors.append("ZoneManager no reanudó el tipo de zona Hogar.")
	if player.global_position != Vector2(4000.0, 0.0):
		errors.append("La posición dentro del interior no se restauró: %s" % str(player.global_position))
	if player.health != 64 or player.mana != 37:
		errors.append("Los valores vitales no sobrevivieron al reinicio.")
	if not bool(game_state.get("_partida_aplicada_en_escena")):
		errors.append("GameState no aplicó el snapshot a Main.")
	if not bool(game_state.get("_estado_vital_restaurado_en_escena")):
		errors.append("La restauración vital no terminó.")

	if not bool(home.get("_interior_abierto")):
		errors.append("Hogar no restauró el interior abierto.")
	var interior := home.get_node_or_null("InteriorCasa")
	if not is_instance_valid(interior) or not bool(interior.visible):
		errors.append("InteriorCasa no quedó visible tras el reinicio.")
	else:
		var inner_state: Dictionary = interior.call("obtener_estado_guardado")
		var inner_decorations: Array = inner_state.get("decoraciones", []) as Array
		if inner_decorations.size() != 2:
			errors.append("No se restauraron los muebles interiores.")
		elif str((inner_decorations[1] as Dictionary).get("cofre_id", "")) != "restart_inner_chest":
			errors.append("El cofre interior perdió su identidad.")
		else:
			var contents: Array = interior.call("obtener_contenido_cofre", 1)
			if contents.is_empty() or str((contents[0] as Dictionary).get("id", "")) != "restart_inner_gem":
				errors.append("El contenido del cofre interior no sobrevivió.")
		if int(inner_state.get("siguiente_id_cofre", 0)) != 9:
			errors.append("El contador de cofres interiores no sobrevivió.")

	var outer_decorations: Array = home.call("obtener_decoraciones")
	if outer_decorations.size() != 2:
		errors.append("No se restauraron las decoraciones exteriores.")
	elif str((outer_decorations[1] as Dictionary).get("cofre_id", "")) != "restart_outer_chest":
		errors.append("El cofre exterior perdió su identidad.")
	else:
		var outer_contents: Array = home.call("obtener_contenido_cofre", 1)
		if outer_contents.is_empty() or str((outer_contents[0] as Dictionary).get("id", "")) != "restart_outer_ore":
			errors.append("El contenido del cofre exterior no sobrevivió.")

	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	print("HomeProcessRestart: READ PASS id=%s pid=%d" % [save_id, OS.get_process_id()])
	get_tree().quit(0)


func _contains(output: Array, needle: String) -> bool:
	return "\n".join(output).contains(needle)


func _fail(message: String) -> void:
	push_error("HomeProcessRestart: FAIL: " + message)
	get_tree().quit(1)


func _freeze_player_on_main(scene_path: String) -> void:
	if scene_path != "res://scenes/world/main.tscn":
		return
	var main := get_tree().current_scene
	if not is_instance_valid(main):
		return
	var player := main.get_node_or_null("Entities/Player") as Player
	if is_instance_valid(player):
		player.set_process(false)
		player.set_physics_process(false)
