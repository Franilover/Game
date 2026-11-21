extends Node

const INVENTORY_SCENE: PackedScene = preload("res://scenes/ui/inventory.tscn")
const GARUMI_HUB_SCENE: PackedScene = preload("res://scenes/ui/garumi_hub.tscn")

var _failed: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_failed = false
	_check(not InputMap.has_action("garumi_hub"), "El acceso rápido G debe retirarse: los Garumis se consultan en el edificio de exploración.")

	var inventario := INVENTORY_SCENE.instantiate() as Control
	_check(inventario != null, "Debe poder instanciarse la UI de inventario.")
	if inventario == null:
		get_tree().quit(1)
		return
	add_child(inventario)
	await get_tree().process_frame
	var tabs := inventario.get_node("Window/Margin/Column/Tabs") as TabContainer
	var garumis_tab := inventario.get_node_or_null("Window/Margin/Column/Tabs/Garumis")
	var boton_garumis := inventario.get_node_or_null("Window/Margin/Column/TabButtons/Garumis")
	_check(garumis_tab == null and boton_garumis == null, "El inventario no debe contener una pestaña ni un botón de Garumis.")
	_check(tabs.get_tab_count() == 6, "Al retirar Garumis, el inventario debe conservar sus seis páginas restantes.")
	var hub := GARUMI_HUB_SCENE.instantiate() as Control
	_check(hub != null, "La mesa de Garumis debe disponer de una interfaz independiente.")
	if hub == null:
		get_tree().quit(1)
		return
	add_child(hub)
	await get_tree().process_frame
	_check(hub.is_in_group("garumi_hub"), "La interfaz independiente debe registrarse para recibir resultados de amistad.")
	_check(hub.has_method("mostrar_resultado_amistad_garumi"), "La mesa debe conservar los avisos de amistad.")
	_check(hub.has_method("actualizar"), "La mesa debe mostrar los vínculos y amistades guardados.")
	hub.queue_free()
	await get_tree().process_frame

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
	if _failed:
		push_error("GarumiEncyclopedia: FAIL")
		get_tree().quit(1)
		return
	print("GarumiEncyclopedia: PASS — Garudex independiente y mesa de Garumis fuera del inventario.")
	get_tree().quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("GarumiEncyclopedia: FAIL: " + message)
