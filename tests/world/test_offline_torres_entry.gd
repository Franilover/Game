extends Node

const ZoneManagerScript = preload("res://scripts/world/zone_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := ZoneManagerScript.new() as Node2D
	manager.name = "OfflineZoneManager"
	add_child(manager)

	if manager.get("_supabase_client") != null:
		_fail("ZoneManager comenzó con un cliente remoto inesperado.")
		return

	manager.entrar_reino("torres")
	var frames := 0
	while manager.get("zona_actual") == null and frames < 120:
		await get_tree().process_frame
		frames += 1

	var zone: Node = manager.get("zona_actual")
	if zone == null:
		_fail("Torres no pudo cargarse sin Supabase.")
		return
	if str(manager.get("tipo_actual")) != "reino_torres":
		_fail("ZoneManager no registró el tipo local de Torres.")
		return
	if zone.scene_file_path != "res://scenes/kingdom/reino_torres.tscn":
		_fail("Torres no usó su escena local fija: %s" % zone.scene_file_path)
		return

	print("OfflineTorresEntry: PASS scene=%s frames=%d" % [zone.scene_file_path, frames])
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("OfflineTorresEntry: FAIL: " + message)
	get_tree().quit(1)
