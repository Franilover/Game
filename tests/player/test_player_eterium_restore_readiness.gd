extends Node

const RuntimeScript = preload("res://scripts/gameplay/player/player_eterium_runtime.gd")
const CoordinatorScript = preload("res://scripts/gameplay/player/player_eterium_coordinator.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var runtime := RuntimeScript.new() as PlayerEteriumRuntime
	var coordinator := CoordinatorScript.new() as PlayerEteriumCoordinator
	coordinator.configurar(runtime, null)

	if coordinator.esta_listo_para_restaurar():
		errores.append("Se permitió restaurar antes de cargar el runtime Eterium.")

	runtime.aplicar_runtime({"limite_estable_s": 100.0, "escala_runtime": 1.0}, [])
	if not runtime.runtime_ready:
		errores.append("El runtime de prueba no quedó listo.")
	if coordinator.esta_listo_para_restaurar():
		errores.append("Se permitió restaurar antes de resolver la regla de especie.")

	coordinator.marcar_especie_configuracion_resuelta()
	if not coordinator.esta_listo_para_restaurar():
		errores.append("No se habilitó la restauración tras resolver runtime y especie.")

	coordinator.free()
	runtime.free()
	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("PlayerEteriumRestoreReadiness: FAIL: " + error)
		get_tree().quit(1)
		return
	print("PlayerEteriumRestoreReadiness: PASS")
	get_tree().quit(0)
