extends Node

const StartMenuScene: PackedScene = preload("res://scenes/ui/start_menu.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not WorldData.esta_cargado():
		_fail("El snapshot incluido no está disponible al iniciar el menú.")
		return

	var menu := StartMenuScene.instantiate() as Control
	if menu == null:
		_fail("No se pudo instanciar el menú real.")
		return
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var start_button := menu.get_node_or_null("Center/StartButton") as Button
	if start_button == null:
		_fail("El menú real no contiene el botón Aventura.")
		return
	if start_button.disabled or start_button.text != "Aventura":
		_fail("El menú no habilitó Aventura desde el snapshot local: disabled=%s text=%s" % [str(start_button.disabled), start_button.text])
		return

	menu.call("_iniciar_partida")
	await get_tree().process_frame
	if menu.get_node_or_null("LocalSaveSelector") == null:
		_fail("El menú no pudo abrir el selector local de partidas.")
		return

	print("OfflineMenuStart: PASS world_loaded=true adventure_enabled=true save_selector=true")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("OfflineMenuStart: FAIL: " + message)
	get_tree().quit(1)
