extends Node

const INVENTORY_SCENE: PackedScene = preload("res://scenes/ui/inventory.tscn")

var _failed: bool = false


func _ready() -> void:
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
		get_tree().quit(1)
		return
	add_child(inventario)
	await get_tree().process_frame

	var tabs := inventario.get_node("Window/Margin/Column/Tabs") as TabContainer
	var enciclopedia := inventario.get_node("Window/Margin/Column/Tabs/Enciclopedia") as Control
	_check(enciclopedia.has_method("abrir_en_garumis"), "La Enciclopedia debe exponer abrir_en_garumis().")

	# Recorrer el pipeline real de entrada de Godot; no llamar _input() directamente.
	var tecla := InputEventKey.new()
	tecla.pressed = true
	tecla.keycode = KEY_G
	tecla.physical_keycode = KEY_G
	Input.parse_input_event(tecla)
	await get_tree().process_frame
	_check(inventario.visible, "Pulsar G debe abrir la ventana del inventario.")
	_check(tabs.current_tab == 2, "Pulsar G debe seleccionar la pestaña Enciclopedia.")
	_check(str(enciclopedia.get("_modo")) == "garumis", "Pulsar G debe seleccionar la sección Garumis.")

	# Soltar G y pulsarla de nuevo para verificar el cierre por la misma ruta.
	var soltar_tecla := InputEventKey.new()
	soltar_tecla.keycode = KEY_G
	soltar_tecla.physical_keycode = KEY_G
	soltar_tecla.pressed = false
	Input.parse_input_event(soltar_tecla)
	await get_tree().process_frame

	var segunda_tecla := InputEventKey.new()
	segunda_tecla.pressed = true
	segunda_tecla.keycode = KEY_G
	segunda_tecla.physical_keycode = KEY_G
	Input.parse_input_event(segunda_tecla)
	await get_tree().process_frame
	_check(not inventario.visible, "Pulsar G de nuevo en Garumis debe cerrar la ventana.")
	if _failed:
		push_error("GarumiEncyclopedia: FAIL")
		get_tree().quit(1)
		return
	print("GarumiEncyclopedia: PASS — G abre Garumis y vuelve a cerrar la ventana.")
	get_tree().quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("GarumiEncyclopedia: FAIL: " + message)
