extends SceneTree

const INVENTORY_SCENE: PackedScene = preload("res://scenes/ui/inventory.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_failed = false
	const ACTION := "garumi_encyclopedia"
	_check(InputMap.has_action(ACTION), "Debe existir la acción de la Enciclopedia de Garumis.")
	var tecla_g_encontrada := false
	if InputMap.has_action(ACTION):
		for evento in InputMap.action_get_events(ACTION):
			if evento is InputEventKey:
				var tecla := evento as InputEventKey
				if tecla.physical_keycode == KEY_G or tecla.keycode == KEY_G:
					tecla_g_encontrada = true
					break
	_check(tecla_g_encontrada, "La acción debe estar vinculada físicamente a G.")

	var inventario := INVENTORY_SCENE.instantiate() as Control
	_check(inventario != null, "Debe poder instanciarse la UI de inventario.")
	if inventario == null:
		quit(1)
		return
	root.add_child(inventario)
	await process_frame

	var tabs := inventario.get_node("Window/Margin/Column/Tabs") as TabContainer
	var enciclopedia := inventario.get_node("Window/Margin/Column/Tabs/Enciclopedia") as Control
	_check(enciclopedia.has_method("abrir_en_garumis"), "La Enciclopedia debe exponer abrir_en_garumis().")

	# Simular una pulsación física de G sobre el mismo receptor que procesa input real.
	var tecla := InputEventKey.new()
	tecla.pressed = true
	tecla.keycode = KEY_G
	tecla.physical_keycode = KEY_G
	inventario.call("_input", tecla)
	await process_frame
	_check(inventario.visible, "Pulsar G debe abrir la ventana del inventario.")
	_check(tabs.current_tab == 2, "Pulsar G debe seleccionar la pestaña Enciclopedia.")
	_check(str(enciclopedia.get("_modo")) == "garumis", "Pulsar G debe seleccionar la sección Garumis.")

	# El mismo atajo vuelve a cerrar la ventana si ya estamos en Garumis.
	var segunda_tecla := InputEventKey.new()
	segunda_tecla.pressed = true
	segunda_tecla.keycode = KEY_G
	segunda_tecla.physical_keycode = KEY_G
	inventario.call("_input", segunda_tecla)
	await process_frame
	_check(not inventario.visible, "Pulsar G de nuevo en Garumis debe cerrar la ventana.")

	inventario.queue_free()
	if _failed:
		push_error("GarumiEncyclopedia: FAIL")
		quit(1)
		return
	print("GarumiEncyclopedia: PASS — G abre Garumis y vuelve a cerrar la ventana.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("GarumiEncyclopedia: FAIL: " + message)


var _failed: bool = false
