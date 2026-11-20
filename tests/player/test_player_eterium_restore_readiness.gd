extends Node

const RuntimeScript = preload("res://scripts/gameplay/player/player_eterium_runtime.gd")
const CoordinatorScript = preload("res://scripts/gameplay/player/player_eterium_coordinator.gd")
const VitalStateScript = preload("res://scripts/state/vital_state.gd")


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

	# La llegada de especie antes del runtime no debe dejar la capacidad global al final.
	var vital := VitalStateScript.new() as VitalState
	vital.configurar(100, 100)
	var runtime_orden := RuntimeScript.new() as PlayerEteriumRuntime
	runtime_orden.configurar_vital(vital)
	var regla_especie := {
		"especie_eterium_v1": {"especie_id": "species-a", "capacidad_base": 50},
		"eterium_inicial": 20,
		"vida_eterium_compartidos": false
	}
	if not runtime_orden.aplicar_especie(regla_especie, "species-a"):
		errores.append("No se pudo aplicar la regla de especie de prueba.")
	runtime_orden.aplicar_runtime({"limite_estable_s": 100.0, "escala_runtime": 1.0}, [])
	if runtime_orden.max_mana() != 100:
		errores.append("La prueba no reprodujo el orden de llegada especie/runtime.")
	runtime_orden.aplicar_especie(regla_especie, "species-a")
	if runtime_orden.max_mana() != 50 or runtime_orden.mana() != 20:
		errores.append("La regla de especie no prevaleció después de aplicar runtime general.")

	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("PlayerEteriumRestoreReadiness: FAIL: " + error)
		get_tree().quit(1)
		return
	print("PlayerEteriumRestoreReadiness: PASS")
	get_tree().quit(0)
