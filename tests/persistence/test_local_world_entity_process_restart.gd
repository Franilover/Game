extends Node

const CONTRACT_DIRECTORY := "user://contracts/local_world_entity_restart"
const MANIFEST_PATH := CONTRACT_DIRECTORY + "/save_id.txt"
const ENTITY_MANAGER_SCRIPT = preload("res://scripts/world/world_entity_manager.gd")


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
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTRACT_DIRECTORY))
	if error != OK and error != ERR_ALREADY_EXISTS:
		_fail("No se pudo crear el directorio del contrato.")
		return
	var writer_output: Array = []
	var writer_exit := _run_child("write", writer_output)
	if writer_exit != 0 or not _contains(writer_output, "LocalWorldEntityRestart: WRITE PASS"):
		_fail("Falló el proceso escritor: %s" % "\n".join(writer_output))
		return
	var reader_output: Array = []
	var reader_exit := _run_child("read", reader_output)
	if reader_exit != 0 or not _contains(reader_output, "LocalWorldEntityRestart: READ PASS"):
		_fail("Falló el proceso lector: %s" % "\n".join(reader_output))

	var manifest := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest != null:
		var save_id := manifest.get_as_text().strip_edges()
		manifest.close()
		if not save_id.is_empty():
			var repository: Variant = GameState.get("save_repository")
			repository.call("eliminar_partida", save_id)
	if FileAccess.file_exists(MANIFEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MANIFEST_PATH))
	if reader_exit != 0:
		get_tree().quit(1)
		return
	print("LocalWorldEntityRestart: PASS (GameState JSON save across independent processes)")
	get_tree().quit(0)


func _run_child(mode: String, output: Array) -> int:
	return OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/persistence/test_local_world_entity_process_restart.tscn",
		"--", mode
	], output, true)


func _worker_write() -> void:
	var save_id := str(GameState.call("crear_partida", "Local world entities", "7348293", {
		"nombre": "Entity persistence probe",
		"especie": "Humano"
	}))
	if save_id.is_empty():
		_fail("GameState no creó la partida de prueba.")
		return

	var manager := ENTITY_MANAGER_SCRIPT.new() as Node
	manager.call("restaurar_estado_persistente_mundo", {
		"criaturas": {
			"3:-2:lobo_runtime": {
				"criatura_id": "lobo",
				"position": Vector2(912.5, -64.25),
				"velocity": Vector2(1.25, 0.5),
				"health": 13,
				"necesidades_runtime": {"hambre": 0.72}
			}
		},
		"props": {
			"3:-2:hierro_runtime": {
				"position": Vector2(960.0, -32.0),
				"runtime_instance_key": "hierro_runtime",
				"is_present": false,
				"datos": {"chunk": Vector2i(3, -2), "id": "hierro"}
			}
		}
	})
	if not bool(GameState.call("capturar_estado_entidades_mundo_local", "mundo_abierto", manager)):
		_fail("GameState no capturó los deltas del manager.")
		return
	manager.free()

	var repository: Variant = GameState.get("save_repository")
	var data := repository.call("leer_partida", save_id) as Dictionary
	data["estado"] = GameState.call("_serializar_estado")
	if not bool(repository.call("escribir_partida", save_id, data)):
		_fail("No se pudo escribir el estado local de entidades.")
		return
	var manifest := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest == null:
		_fail("No se pudo crear el manifiesto.")
		return
	manifest.store_string(save_id)
	manifest.close()
	print("LocalWorldEntityRestart: WRITE PASS pid=%d" % OS.get_process_id())
	get_tree().quit(0)


func _worker_read() -> void:
	var manifest := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest == null:
		_fail("El proceso lector no encontró el manifiesto.")
		return
	var save_id := manifest.get_as_text().strip_edges()
	manifest.close()
	var repository: Variant = GameState.get("save_repository")
	var data := repository.call("leer_partida", save_id) as Dictionary
	if data.is_empty() or not bool(GameState.call("_datos_partida_cargables", save_id, data)):
		_fail("El proceso lector no validó el save.")
		return
	var state: Dictionary = data.get("estado", {}) as Dictionary
	GameState.call("_aplicar_estado_memoria", state)
	var restored := GameState.call("obtener_estado_entidades_mundo_local", "mundo_abierto") as Dictionary
	var creatures: Dictionary = restored.get("criaturas", {}) as Dictionary
	var creature: Dictionary = creatures.get("3:-2:lobo_runtime", {}) as Dictionary
	var props: Dictionary = restored.get("props", {}) as Dictionary
	var prop: Dictionary = props.get("3:-2:hierro_runtime", {}) as Dictionary
	var prop_data: Dictionary = prop.get("datos", {}) as Dictionary
	if creature.get("position") != Vector2(912.5, -64.25):
		_fail("La posición de criatura no sobrevivió al reinicio.")
		return
	if creature.get("velocity") != Vector2(1.25, 0.5):
		_fail("La velocidad de criatura no sobrevivió al reinicio.")
		return
	if int(creature.get("health", 0)) != 13 or not is_equal_approx(float((creature.get("necesidades_runtime", {}) as Dictionary).get("hambre", 0.0)), 0.72):
		_fail("El estado de necesidades/vida no sobrevivió al reinicio.")
		return
	if bool(prop.get("is_present", true)) or prop_data.get("chunk") != Vector2i(3, -2):
		_fail("El tombstone del prop no sobrevivió al reinicio.")
		return
	var manager := ENTITY_MANAGER_SCRIPT.new() as Node
	manager.call("restaurar_estado_persistente_mundo", restored)
	var roundtrip: Dictionary = manager.call("capturar_estado_persistente_mundo")
	manager.free()
	if roundtrip != restored:
		_fail("WorldEntityManager no pudo reconstruir el snapshot leído.")
		return
	print("LocalWorldEntityRestart: READ PASS pid=%d" % OS.get_process_id())
	get_tree().quit(0)


func _contains(output: Array, needle: String) -> bool:
	return "\n".join(output).contains(needle)


func _fail(message: String) -> void:
	push_error("LocalWorldEntityRestart: FAIL: " + message)
	get_tree().quit(1)
