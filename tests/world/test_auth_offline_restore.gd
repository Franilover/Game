extends Node

const MockAuthScript = preload("res://tests/world/mock_garlia_auth.gd")

const TEST_SESSION_PATH := "user://contracts/auth_offline_restore.json"

var restauraciones_finalizadas: int = 0
var sesiones_restauradas: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://contracts")
	)
	var archivo := FileAccess.open(TEST_SESSION_PATH, FileAccess.WRITE)
	if archivo == null:
		_finalizar(["No se pudo crear el archivo de sesión temporal."])
		return
	archivo.store_string(JSON.stringify({
		"refresh_token": "refresh-token-original",
		"user_email": "offline@example.test"
	}))
	archivo.close()

	var auth = MockAuthScript.new()
	auth.set("_session_file_path", TEST_SESSION_PATH)
	restauraciones_finalizadas = 0
	sesiones_restauradas = 0
	auth.session_restore_finished.connect(_al_finalizar_restauracion)
	auth.session_restored.connect(_al_restaurar_sesion)
	add_child(auth)

	var frames := 0
	while restauraciones_finalizadas < 1 and frames < 30:
		await get_tree().process_frame
		frames += 1

	if restauraciones_finalizadas < 1:
		errores.append("La restauración offline no terminó.")
	if not FileAccess.file_exists(TEST_SESSION_PATH):
		errores.append("Un error de red eliminó el archivo de sesión.")
	if str(auth.get("refresh_token")) != "refresh-token-original":
		errores.append("Un error de red limpió el refresh token local.")
	if auth.get("_restore_retry_timer") == null or auth.get("_restore_retry_timer").is_stopped():
		errores.append("No se programó un reintento automático tras el fallo temporal.")

	auth.set("simular_offline", false)
	auth.call("_restaurar_sesion")
	frames = 0
	while restauraciones_finalizadas < 2 and frames < 30:
		await get_tree().process_frame
		frames += 1

	if restauraciones_finalizadas < 2:
		errores.append("La restauración no volvió a intentarse al recuperar la conexión.")
	if sesiones_restauradas != 1:
		errores.append("La sesión no se restauró exactamente una vez al recuperar conexión.")
	if not auth.call("esta_autenticado"):
		errores.append("El perfil no quedó autenticado tras recuperar conexión.")
	if str(auth.get("refresh_token")) != "refresh-token-rotated":
		errores.append("No se conservó el refresh token rotado por Supabase.")
	if auth.get("_restore_retry_timer") != null and not auth.get("_restore_retry_timer").is_stopped():
		errores.append("El temporizador de reintento no se detuvo tras restaurar la sesión.")

	auth.queue_free()
	await get_tree().process_frame
	if FileAccess.file_exists(TEST_SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SESSION_PATH))
	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("AuthOfflineRestore: FAIL: " + error)
		get_tree().quit(1)
		return
	print("AuthOfflineRestore: PASS transient_failure_preserves_session=true reconnect_restores=true")
	get_tree().quit(0)


func _al_finalizar_restauracion() -> void:
	restauraciones_finalizadas += 1


func _al_restaurar_sesion() -> void:
	sesiones_restauradas += 1
