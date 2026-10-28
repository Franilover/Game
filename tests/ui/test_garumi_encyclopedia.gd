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

	# La enciclopedia sólo debe exponer el linaje descendiente de Orumi.
	const orumi_id := "24f86486-aced-4a23-bd1b-f025561a8aa3"
	var filas_catalogo: Array[Dictionary] = [
		{"tipo_registro": "original", "entidad_id": orumi_id, "nombre": "Orumi", "letra_original": "O", "orden_catalogo": 1},
		{"tipo_registro": "original", "entidad_id": "varum-test-id", "nombre": "Varum", "letra_original": "V", "orden_catalogo": 2},
		{"tipo_registro": "especie", "entidad_id": "orumi-descendiente-test", "nombre": "Oruvan", "original_id": orumi_id, "nombre_original": "Orumi", "letra_original": "O", "estado_documentacion": "canon", "numero_global": 1},
		{"tipo_registro": "especie", "entidad_id": "varum-descendiente-test", "nombre": "Varumin", "original_id": "varum-test-id", "nombre_original": "Varum", "letra_original": "V", "estado_documentacion": "canon", "numero_global": 2}
	]
	enciclopedia.call("_aplicar_catalogo_desde_filas", filas_catalogo)
	var catalogo_filtrado: Array = enciclopedia.get("_garumis_catalogo")
	var originales_filtrados: Array = enciclopedia.get("_garumi_originales")
	_check(catalogo_filtrado.size() == 1, "La enciclopedia debe mostrar sólo descendientes de Orumi.")
	_check(not catalogo_filtrado.is_empty() and str(catalogo_filtrado[0].get("nombre", "")) == "Oruvan", "Debe conservar el descendiente de Orumi.")
	_check(originales_filtrados.size() == 1 and str(originales_filtrados[0].get("nombre", "")) == "Orumi", "Debe mostrar sólo el Original Orumi como encabezado de linaje.")

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
