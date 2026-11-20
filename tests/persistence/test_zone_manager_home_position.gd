extends Node

const ZONE_MANAGER_SCRIPT = preload("res://scripts/world/zone_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var player := Node2D.new()
	player.name = "HomePositionProbe"
	player.add_to_group("player")
	player.global_position = Vector2(12.0, 34.0)
	add_child(player)

	var manager := ZONE_MANAGER_SCRIPT.new() as Node2D
	add_child(manager)

	GameState.world_state.flags["hogar_estado"] = {
		"jugador": {"x": 4200.5, "y": -72.25}
	}
	manager.call("_restaurar_posicion_jugador_hogar")
	if player.global_position != Vector2(4200.5, -72.25):
		errors.append("No se restauraron las coordenadas válidas guardadas en Hogar.")

	player.global_position = Vector2(15.0, 25.0)
	GameState.world_state.flags["hogar_estado"] = {
		"jugador": {"x": "invalido", "y": 80.0}
	}
	manager.call("_restaurar_posicion_jugador_hogar")
	if player.global_position != Vector2(15.0, 25.0):
		errors.append("Una coordenada inválida modificó la posición actual.")

	GameState.world_state.flags["hogar_estado"] = {
		"jugador": {"x": INF, "y": 80.0}
	}
	manager.call("_restaurar_posicion_jugador_hogar")
	if player.global_position != Vector2(15.0, 25.0):
		errors.append("Una coordenada no finita modificó la posición actual.")

	manager.queue_free()
	player.queue_free()
	await get_tree().process_frame
	if not errors.is_empty():
		for error in errors:
			push_error("ZoneManagerHomePosition: FAIL: " + error)
		get_tree().quit(1)
		return
	print("ZoneManagerHomePosition: PASS")
	get_tree().quit(0)
