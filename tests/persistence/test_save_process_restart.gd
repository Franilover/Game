extends SceneTree

const SaveRepositoryScript = preload("res://scripts/infrastructure/save_file_repository.gd")
const CONTRACT_DIR := "user://contracts/process_restart"
const SAVE_ID := "independent_process_resume"


func _initialize() -> void:
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
	var repository := SaveRepositoryScript.new() as SaveFileRepository
	repository.configurar(CONTRACT_DIR)
	repository.asegurar_directorio()
	repository.eliminar_partida(SAVE_ID)

	var project_path := ProjectSettings.globalize_path("res://")
	var script_path := "res://tests/persistence/test_save_process_restart.gd"
	var writer_output: Array = []
	var writer_exit := OS.execute(OS.get_executable_path(), [
		"--headless", "--path", project_path, "--script", script_path, "--", "write"
	], writer_output, true)
	if writer_exit != 0:
		_fail("El proceso escritor terminó con código %d: %s" % [writer_exit, "\n".join(writer_output)])
		return
	if not "\n".join(writer_output).contains("SaveProcessRestart: WRITE PASS"):
		_fail("El proceso escritor no confirmó la persistencia: %s" % "\n".join(writer_output))
		return

	var reader_output: Array = []
	var reader_exit := OS.execute(OS.get_executable_path(), [
		"--headless", "--path", project_path, "--script", script_path, "--", "read"
	], reader_output, true)
	if reader_exit != 0:
		_fail("El proceso lector terminó con código %d: %s" % [reader_exit, "\n".join(reader_output)])
		return
	if not "\n".join(reader_output).contains("SaveProcessRestart: READ PASS"):
		_fail("El proceso lector no confirmó la restauración: %s" % "\n".join(reader_output))
		return

	repository.eliminar_partida(SAVE_ID)
	print("SaveProcessRestart: PASS (writer and reader were independent processes)")
	quit(0)


func _worker_write() -> void:
	var repository := SaveRepositoryScript.new() as SaveFileRepository
	repository.configurar(CONTRACT_DIR)
	var payload := {
		"id": SAVE_ID,
		"version": 2,
		"writer_pid": OS.get_process_id(),
		"mundo": {"semilla": 7348291, "generador_version": 1},
		"estado": {
			"player": {
				"health": 67,
				"mana": 42,
				"stamina": 0.75,
				"position": {"x": 321.5, "y": -87.25},
				"facing": {"x": -1.0, "y": 0.0}
			},
			"flags": {
				"zona_actual_tipo": "reino_torres",
				"inventario_estado": {
					"items": [{"id": "process_restart_item", "cantidad": 3}],
					"hotbar_indices": [0, 1, 2],
					"indice_hotbar_activo": 1
				},
				"misiones": {
					"mision_proceso": "completada",
					"mision_proceso_progreso": 4,
					"mision_proceso_recompensa_reclamada": true
				}
			}
		}
	}
	if not repository.escribir_partida(SAVE_ID, payload):
		_fail("El proceso escritor no pudo persistir el snapshot.")
		return
	print("SaveProcessRestart: WRITE PASS pid=%d" % OS.get_process_id())
	quit(0)


func _worker_read() -> void:
	var repository := SaveRepositoryScript.new() as SaveFileRepository
	repository.configurar(CONTRACT_DIR)
	var payload := repository.leer_partida(SAVE_ID)
	if payload.is_empty():
		_fail("El proceso lector no encontró el archivo persistido.")
		return
	var errors: Array[String] = []
	if int(payload.get("writer_pid", -1)) == OS.get_process_id():
		errors.append("El lector parece ser el mismo proceso que escribió.")
	if int(payload.get("version", 0)) != 2:
		errors.append("La versión del save no sobrevivió al reinicio.")
	var world: Dictionary = payload.get("mundo", {}) as Dictionary
	if int(world.get("semilla", 0)) != 7348291:
		errors.append("La semilla del mundo cambió entre procesos.")
	var state: Dictionary = payload.get("estado", {}) as Dictionary
	var player: Dictionary = state.get("player", {}) as Dictionary
	if int(player.get("health", 0)) != 67 or int(player.get("mana", 0)) != 42:
		errors.append("Los valores vitales no sobrevivieron entre procesos.")
	var position: Dictionary = player.get("position", {}) as Dictionary
	if not is_equal_approx(float(position.get("x", 0.0)), 321.5) or not is_equal_approx(float(position.get("y", 0.0)), -87.25):
		errors.append("La posición no sobrevivió entre procesos.")
	var flags: Dictionary = state.get("flags", {}) as Dictionary
	if str(flags.get("zona_actual_tipo", "")) != "reino_torres":
		errors.append("La zona guardada no sobrevivió entre procesos.")
	var inventory: Dictionary = flags.get("inventario_estado", {}) as Dictionary
	var items: Array = inventory.get("items", []) as Array
	if items.is_empty() or str((items[0] as Dictionary).get("id", "")) != "process_restart_item":
		errors.append("El inventario no sobrevivió entre procesos.")
	var missions: Dictionary = flags.get("misiones", {}) as Dictionary
	if str(missions.get("mision_proceso", "")) != "completada" or int(missions.get("mision_proceso_progreso", 0)) != 4:
		errors.append("El progreso de misión no sobrevivió entre procesos.")
	if not bool(missions.get("mision_proceso_recompensa_reclamada", false)):
		errors.append("La reclamación de recompensa no sobrevivió entre procesos.")
	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	print("SaveProcessRestart: READ PASS pid=%d" % OS.get_process_id())
	quit(0)


func _fail(message: String) -> void:
	push_error("SaveProcessRestart: FAIL: " + message)
	quit(1)
