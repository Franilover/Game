extends CanvasLayer
## Interfaz de transferencia entre el inventario del jugador y un cofre privado.

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")
const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

var _interior: Node = null
var _inventario: Node = null
var _indice_cofre := -1
var _slots_jugador: Array[InventorySlot] = []
var _slots_cofre: Array[InventorySlot] = []
var _panel: PanelContainer


func abrir(interior: Node, inventario: Node, indice_cofre: int) -> void:
	_interior = interior
	_inventario = inventario
	_indice_cofre = indice_cofre
	add_to_group("modal_ui")
	_crear_interfaz()
	_refrescar()


func _crear_interfaz() -> void:
	var raiz := Control.new()
	raiz.name = "RaizCofre"
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	var oscurecer := ColorRect.new()
	oscurecer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	oscurecer.color = Color(0.035, 0.025, 0.018, 0.72)
	oscurecer.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.add_child(oscurecer)

	_panel = PanelContainer.new()
	_panel.name = "PanelCofre"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -300.0
	_panel.offset_top = -148.0
	_panel.offset_right = 300.0
	_panel.offset_bottom = 148.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.add_child(_panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 10)
	margen.add_theme_constant_override("margin_right", 10)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	margen.add_child(columna)

	var encabezado := HBoxContainer.new()
	columna.add_child(encabezado)
	var titulo := Label.new()
	titulo.name = "Title"
	titulo.text = "COFRE"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_child(titulo)
	var cerrar := Button.new()
	cerrar.text = "X"
	cerrar.custom_minimum_size = Vector2(34, 28)
	cerrar.pressed.connect(_solicitar_cierre)
	encabezado.add_child(cerrar)

	var separador := HSeparator.new()
	columna.add_child(separador)

	var paneles := HBoxContainer.new()
	paneles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paneles.add_theme_constant_override("separation", 12)
	columna.add_child(paneles)

	var panel_jugador := VBoxContainer.new()
	panel_jugador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paneles.add_child(panel_jugador)
	var titulo_jugador := Label.new()
	titulo_jugador.text = "INVENTARIO"
	panel_jugador.add_child(titulo_jugador)
	var rejilla_jugador := GridContainer.new()
	rejilla_jugador.name = "GridJugador"
	rejilla_jugador.columns = 6
	rejilla_jugador.add_theme_constant_override("h_separation", 3)
	rejilla_jugador.add_theme_constant_override("v_separation", 3)
	panel_jugador.add_child(rejilla_jugador)

	var panel_cofre := VBoxContainer.new()
	panel_cofre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paneles.add_child(panel_cofre)
	var titulo_cofre := Label.new()
	titulo_cofre.text = "COFRE · 32 ESPACIOS"
	panel_cofre.add_child(titulo_cofre)
	var rejilla_cofre := GridContainer.new()
	rejilla_cofre.name = "GridCofre"
	rejilla_cofre.columns = 8
	rejilla_cofre.add_theme_constant_override("h_separation", 3)
	rejilla_cofre.add_theme_constant_override("v_separation", 3)
	panel_cofre.add_child(rejilla_cofre)

	_crear_slots(rejilla_jugador, "jugador", 18, _slots_jugador)
	_crear_slots(rejilla_cofre, "cofre", 32, _slots_cofre)

	var ayuda := Label.new()
	ayuda.text = "Arrastra objetos entre ambos inventarios · Esc para cerrar"
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(ayuda)
	PIXEL_UI_THEME.apply(_panel)


func _crear_slots(
	contenedor: GridContainer,
	tipo_contenedor: String,
	cantidad: int,
	destino: Array[InventorySlot]
) -> void:
	for indice in range(cantidad):
		var slot := SLOT_SCENE.instantiate() as InventorySlot
		if slot == null:
			continue
		slot.set_meta("inventory_index", indice)
		slot.set_meta("inventory_container", tipo_contenedor)
		slot.custom_minimum_size = Vector2(36, 36)
		slot.arrastre_recibido.connect(_al_recibir_arrastre)
		contenedor.add_child(slot)
		destino.append(slot)


func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.keycode == KEY_ESCAPE:
		_solicitar_cierre()
	get_viewport().set_input_as_handled()


func _al_recibir_arrastre(slot: Button, datos: Dictionary) -> void:
	if not is_instance_valid(_inventario) or not is_instance_valid(_interior):
		return
	var contenedor_origen := str(datos.get("contenedor", "jugador"))
	var contenedor_destino := str(slot.get_meta("inventory_container", ""))
	var indice_origen := int(datos.get("indice", -1))
	var indice_destino := int(slot.get_meta("inventory_index", -1))
	if contenedor_origen not in ["jugador", "cofre"] or contenedor_destino not in ["jugador", "cofre"]:
		return
	if indice_origen < 0 or indice_destino < 0:
		return
	if contenedor_origen == contenedor_destino and indice_origen == indice_destino:
		return
	var origen_items: Array = _obtener_items(contenedor_origen)
	var destino_items: Array = origen_items if contenedor_origen == contenedor_destino else _obtener_items(contenedor_destino)
	if not _intercambiar_o_apilar(origen_items, indice_origen, destino_items, indice_destino):
		return
	if contenedor_origen == "cofre" or contenedor_destino == "cofre":
		var datos_cofre: Array = origen_items if contenedor_origen == "cofre" else destino_items
		_interior.call("establecer_contenido_cofre", _indice_cofre, datos_cofre)
	_actualizar_inventario_jugador()
	_refrescar()


func _obtener_items(contenedor: String) -> Array:
	if contenedor == "jugador":
		var items_jugador: Variant = _inventario.get("items")
		if items_jugador is Array:
			return items_jugador
		return []
	var items_cofre: Variant = _interior.call("obtener_contenido_cofre", _indice_cofre)
	return items_cofre if items_cofre is Array else []


func _intercambiar_o_apilar(
	origen_items: Array,
	indice_origen: int,
	destino_items: Array,
	indice_destino: int
) -> bool:
	if indice_origen >= origen_items.size() or indice_destino >= destino_items.size():
		return false
	var origen: Dictionary = origen_items[indice_origen].duplicate(true)
	var destino: Dictionary = destino_items[indice_destino].duplicate(true)
	if origen.is_empty():
		return false
	if not destino.is_empty() and _puede_apilar(destino, origen):
		var maximo := maxi(1, int(destino.get("max_stack", 1)))
		var cantidad_destino := maxi(1, int(destino.get("cantidad", 1)))
		var cantidad_origen := maxi(1, int(origen.get("cantidad", 1)))
		var espacio := maximo - cantidad_destino
		if espacio > 0:
			var movido := mini(espacio, cantidad_origen)
			destino["cantidad"] = cantidad_destino + movido
			cantidad_origen -= movido
			destino_items[indice_destino] = destino
			if cantidad_origen <= 0:
				origen_items[indice_origen] = {}
			else:
				origen["cantidad"] = cantidad_origen
				origen_items[indice_origen] = origen
			return true
	origen_items[indice_origen] = destino
	destino_items[indice_destino] = origen
	return true


func _puede_apilar(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if int(a.get("max_stack", 1)) <= 1 or int(b.get("max_stack", 1)) <= 1:
		return false
	var id_a := str(a.get("id", a.get("item_id", ""))).strip_edges()
	var id_b := str(b.get("id", b.get("item_id", ""))).strip_edges()
	if not id_a.is_empty() and not id_b.is_empty():
		return id_a == id_b
	var nombre_a := str(a.get("nombre", "")).strip_edges().to_lower()
	var nombre_b := str(b.get("nombre", "")).strip_edges().to_lower()
	return not nombre_a.is_empty() and nombre_a == nombre_b


func _actualizar_inventario_jugador() -> void:
	_inventario.call("actualizar")
	var seleccionado := int(_inventario.call("obtener_indice_seleccionado"))
	if seleccionado >= 0:
		_inventario.call("seleccionar_slot", seleccionado)
	_inventario.emit_signal("inventory_changed")
	if _inventario.has_method("_emitir_objeto_activo"):
		_inventario.call("_emitir_objeto_activo")


func _refrescar() -> void:
	if not is_instance_valid(_inventario) or not is_instance_valid(_interior):
		return
	var items_jugador: Array = _obtener_items("jugador")
	var items_cofre: Array = _obtener_items("cofre")
	for indice in range(_slots_jugador.size()):
		var slot := _slots_jugador[indice]
		if indice < items_jugador.size() and items_jugador[indice] is Dictionary and not items_jugador[indice].is_empty():
			slot.configurar(items_jugador[indice])
		else:
			slot.limpiar()
	for indice in range(_slots_cofre.size()):
		var slot := _slots_cofre[indice]
		if indice < items_cofre.size() and items_cofre[indice] is Dictionary and not items_cofre[indice].is_empty():
			slot.configurar(items_cofre[indice])
		else:
			slot.limpiar()


func _solicitar_cierre() -> void:
	if is_instance_valid(_interior) and _interior.has_method("cerrar_cofre"):
		_interior.call("cerrar_cofre")
