extends Node

const ZONE_MANAGER_SCRIPT = preload("res://scripts/world/zone_manager.gd")
const TORRES_SCENE_PATH := "res://scenes/kingdom/reino_torres.tscn"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := ZONE_MANAGER_SCRIPT.new() as Node2D
	add_child(manager)

	# Una ruta inválida no debe retirar la zona que ya está funcionando.
	var zona_previa := Node2D.new()
	manager.add_child(zona_previa)
	manager.set("zona_actual", zona_previa)
	manager.set("tipo_actual", "zona_prueba")
	await manager.call("_cambiar_zona", "res://scenes/world/escena_inexistente.tscn", "zona_rota")
	if not is_instance_valid(zona_previa) or manager.get("zona_actual") != zona_previa:
		_fail("Una transición inválida retiró la zona activa.")
		return
	if bool(manager.get("_transicionando")):
		_fail("Una transición inválida dejó bloqueado el ZoneManager.")
		return
	zona_previa.queue_free()
	manager.set("zona_actual", null)
	manager.set("tipo_actual", "")
	await get_tree().process_frame

	# No SupabaseClient is injected here on purpose: Torres must still be
	# reachable from the RealmMenu while the remote realm catalog loads.
	manager.entrar_reino("torres")
	await get_tree().process_frame
	await get_tree().process_frame

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
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("ZoneManager Torres fallback regression: " + message)
	get_tree().quit(1)
