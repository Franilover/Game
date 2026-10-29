extends SceneTree

const ZONE_MANAGER_SCRIPT = preload("res://scripts/world/zone_manager.gd")
const TORRES_SCENE_PATH := "res://scenes/kingdom/reino_torres.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := ZONE_MANAGER_SCRIPT.new() as Node2D
	root.add_child(manager)

	# No SupabaseClient is injected here on purpose: Torres must still be
	# reachable from the RealmMenu while the remote realm catalog loads.
	manager.entrar_reino("torres")
	await process_frame
	await process_frame

	if manager.obtener_tipo_actual() != "reino_torres":
		_fail("Entrar en Torres no cambió el tipo de zona.")
		return
	var zona: Node = manager.obtener_zona_actual()
	if not is_instance_valid(zona):
		_fail("ZoneManager no creó una zona activa.")
		return
	if zona.scene_file_path != TORRES_SCENE_PATH:
		_fail("La zona activa no es la escena fija local de Torres.")
		return
	if zona.get_node_or_null("TorresCespedDual") == null:
		_fail("Torres entró, pero no se construyó su césped TileMapDual.")
		return

	print("PASS: Torres travel works without waiting for the remote realm catalog.")
	quit()


func _fail(message: String) -> void:
	push_error("ZoneManager Torres fallback regression: " + message)
	quit(1)
