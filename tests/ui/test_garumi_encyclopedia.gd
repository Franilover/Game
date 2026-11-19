extends Node

const INVENTORY_SCENE: PackedScene = preload("res://scenes/ui/inventory.tscn")

var _failed: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_failed = false
	const ACTION := "garumi_hub"
	_check(InputMap.has_action(ACTION), "Debe existir el acceso rápido al panel de Garumis.")
	var tecla_g_encontrada := false
	if InputMap.has_action(ACTION):
		for evento in InputMap.action_get_events(ACTION):
			if evento is InputEventKey:
				var tecla := evento as InputEventKey
				if tecla.physical_keycode == KEY_G or tecla.keycode == KEY_G:
					tecla_g_encontrada = true
					break
	_check(tecla_g_encontrada, "El acceso rápido debe estar vinculado físicamente a G.")

	var inventario := INVENTORY_SCENE.instantiate() as Control
	_check(inventario != null, "Debe poder instanciarse la UI de inventario.")
	if inventario == null:
		get_tree().quit(1)
		return
	add_child(inventario)
	await get_tree().process_frame

	var tabs := inventario.get_node("Window/Margin/Column/Tabs") as TabContainer
	var enciclopedia := inventario.get_node("Window/Margin/Column/Tabs/Enciclopedia") as Control
	var garumis_tab := inventario.get_node("Window/Margin/Column/Tabs/Garumis") as Control
	var boton_enciclopedia := inventario.get_node("Window/Margin/Column/TabButtons/Enciclopedia") as Button
	var boton_garumis := inventario.get_node("Window/Margin/Column/TabButtons/Garumis") as Button
	_check(garumis_tab.has_method("abrir_en_garumis"), "Garumis debe ser una pestaña independiente.")
	_check(not boton_enciclopedia.visible and not boton_garumis.visible, "Garumis debe iniciar oculto sin descubrimientos y Enciclopedia no debe aparecer en el inventario.")

	# G no debe abrir una pestaña bloqueada.
	var tecla_bloqueada := InputEventKey.new()
	tecla_bloqueada.pressed = true
	tecla_bloqueada.keycode = KEY_G
	tecla_bloqueada.physical_keycode = KEY_G
	Input.parse_input_event(tecla_bloqueada)
	await get_tree().process_frame
	_check(not inventario.visible, "G no debe abrir Garumis antes del primer descubrimiento.")
	var soltar_bloqueada := InputEventKey.new()
	soltar_bloqueada.keycode = KEY_G
	soltar_bloqueada.physical_keycode = KEY_G
	soltar_bloqueada.pressed = false
	Input.parse_input_event(soltar_bloqueada)
	await get_tree().process_frame

	# Descubrir un Garumi desbloquea las dos pestañas.
	_check(GameState.registrar_garumi_descubierto("garumi-desbloqueo-test"), "Debe registrar el primer Garumi descubierto.")
	await get_tree().process_frame
	_check(not boton_enciclopedia.visible and boton_garumis.visible, "Descubrir un Garumi debe mostrar Garumis, pero no Enciclopedia.")

	# El descubrimiento de una criatura también desbloquea el panel de Garumis.
	GameState.world_state.flags.erase("enciclopedia_garumis")
	GameState.discovery_state = DiscoveryState.new()
	inventario.call("_actualizar_visibilidad_tabs_descubrimiento")
	_check(not boton_enciclopedia.visible and not boton_garumis.visible, "Sin descubrimientos de criaturas ni Garumis, la pestaña Garumis vuelve a ocultarse.")
	_check(GameState.registrar_descubrimiento_mundo({"id": "bioma-test"}, {"id": "ecosistema-test"}, [], [{"id": "criatura-desbloqueo-test"}]), "Debe registrar el descubrimiento de una criatura.")
	await get_tree().process_frame
	_check(not boton_enciclopedia.visible and boton_garumis.visible, "Descubrir una criatura debe mostrar Garumis sin devolver Enciclopedia al inventario.")

	# El desbloqueo debe sobrevivir a la serialización y carga de la partida.
	var estado_guardado: Dictionary = GameState.call("_serializar_estado")
	GameState.discovery_state = DiscoveryState.new()
	GameState.call("_aplicar_estado_memoria", estado_guardado)
	inventario.call("_actualizar_visibilidad_tabs_descubrimiento")
	_check(not boton_enciclopedia.visible and boton_garumis.visible, "El descubrimiento debe mantenerse tras guardar y cargar la partida.")

	# Recorrer el pipeline real de entrada de Godot; no llamar _input() directamente.
	var tecla := InputEventKey.new()
	tecla.pressed = true
	tecla.keycode = KEY_G
	tecla.physical_keycode = KEY_G
	Input.parse_input_event(tecla)
	await get_tree().process_frame
	_check(inventario.visible, "Pulsar G debe abrir la ventana del inventario.")
	_check(tabs.current_tab == 3, "Pulsar G debe seleccionar la pestaña Garumis.")
	_check(str(enciclopedia.get("_modo")) != "garumis", "La Enciclopedia no debe contener Garumis.")
	_check(garumis_tab.has_method("abrir_en_garumis"), "El panel de Garumis debe conservar el acceso a vínculos.")

	# La enciclopedia sólo debe exponer el linaje descendiente de Orumi.
	const orumi_id := "24f86486-aced-4a23-bd1b-f025561a8aa3"
	var filas_catalogo: Array[Dictionary] = [
		{"tipo_registro": "original", "entidad_id": orumi_id, "nombre": "Orumi", "letra_original": "O", "orden_catalogo": 1},
		{"tipo_registro": "original", "entidad_id": "varum-test-id", "nombre": "Varum", "letra_original": "V", "orden_catalogo": 2},
		{"tipo_registro": "especie", "entidad_id": "orumi-descendiente-test", "nombre": "Oruvan", "original_id": orumi_id, "nombre_original": "Orumi", "letra_original": "O", "estado_documentacion": "canon", "numero_origen": 1, "numero_global": 4},
		{"tipo_registro": "especie", "entidad_id": "varum-descendiente-test", "nombre": "Varumin", "original_id": "varum-test-id", "nombre_original": "Varum", "letra_original": "V", "estado_documentacion": "canon", "numero_global": 2}
	]
	var garudex := Control.new()
	garudex.set_script(load("res://scripts/ui/encyclopedia.gd"))
	garudex.set("solo_garumis", true)
	add_child(garudex)
	await get_tree().process_frame
	garudex.call("configurar_como_garudex")
	_check(garudex != null, "El Garudex debe poder abrirse como una interfaz independiente de la pestaña de vínculos.")
	if garudex == null:
		get_tree().quit(1)
		return
	garudex.call("_aplicar_catalogo_desde_filas", filas_catalogo)
	var catalogo_filtrado: Array = garudex.get("_garumis_catalogo")
	var originales_filtrados: Array = garudex.get("_garumi_originales")
	_check(catalogo_filtrado.size() == 1, "El Garudex debe mostrar sólo descendientes de Orumi.")
	_check(not catalogo_filtrado.is_empty() and str(catalogo_filtrado[0].get("nombre", "")) == "Oruvan", "Debe conservar el descendiente de Orumi.")
	_check(originales_filtrados.size() == 1 and str(originales_filtrados[0].get("nombre", "")) == "Orumi", "Debe mostrar sólo el Original Orumi como encabezado de linaje.")
	garudex.call("_construir_lista_garumis")
	var arbol: Tree = garudex.get("_arbol")
	_check(arbol.columns == 3, "La lista del Garudex debe separar número de origen, nombre y número global.")
	var grupo_orumi := arbol.get_root().get_first_child()
	var item_oruvan: TreeItem = grupo_orumi.get_first_child() if grupo_orumi != null else null
	_check(item_oruvan != null and item_oruvan.get_text(0) == "1", "El número normal/de origen debe aparecer a la izquierda.")
	_check(item_oruvan != null and item_oruvan.get_text(1) == "Oruvan", "El nombre debe quedar en la columna central.")
	_check(item_oruvan != null and item_oruvan.get_text(2) == "4", "El número global debe aparecer a la derecha.")

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
	print("GarumiEncyclopedia: PASS — Garudex independiente y acceso G al panel de vínculos.")
	get_tree().quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("GarumiEncyclopedia: FAIL: " + message)
