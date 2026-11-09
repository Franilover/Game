extends Control
class_name InventoryHotbar


const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const SLOT_COUNT: int = 6


var indice_seleccionado: int = 0
var inventory: GarliaInventory = null

var slots_container: HBoxContainer = null
var slot_nodes: Array[Button] = []

var _inventario_conectado: bool = false


func _ready() -> void:
	PIXEL_UI_THEME.apply(self)
	var marco_fijo := get_node_or_null(
		"Selection"
	)

	if marco_fijo is Control:
		(marco_fijo as Control).visible = false

	slots_container = $Slots

	if slots_container == null:
		print(
			"Hotbar: ERROR - no se encontró el nodo Slots."
		)
		return

	_obtener_slots()
	_preparar_slots()

	_actualizar()


func _unhandled_input(
	event: InputEvent
) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed:
			return

		if key_event.echo:
			return

		if (
			key_event.keycode >= KEY_1
			and key_event.keycode <= KEY_6
		):
			seleccionar_hotbar(
				key_event.keycode - KEY_1
			)

			get_viewport().set_input_as_handled()

			return

	if event is InputEventMouseButton:
		var mouse_event := (
			event as InputEventMouseButton
		)

		if not mouse_event.pressed:
			return

		if (
			mouse_event.button_index
			== MOUSE_BUTTON_WHEEL_UP
		):
			_mover_seleccion(-1)

			get_viewport().set_input_as_handled()

		elif (
			mouse_event.button_index
			== MOUSE_BUTTON_WHEEL_DOWN
		):
			_mover_seleccion(1)

			get_viewport().set_input_as_handled()


func configurar_inventario(nuevo_inventario: GarliaInventory) -> void:
	if inventory == nuevo_inventario and _inventario_conectado:
		return
	inventory = nuevo_inventario
	_inventario_conectado = false
	_conectar_inventario()
	_actualizar()


func _conectar_inventario() -> void:
	if inventory == null or not is_instance_valid(inventory) or _inventario_conectado:
		return
	if not inventory.inventory_changed.is_connected(_actualizar):
		inventory.inventory_changed.connect(_actualizar)
	if not inventory.active_item_changed.is_connected(_al_objeto_activo_cambiado):
		inventory.active_item_changed.connect(_al_objeto_activo_cambiado)
	_inventario_conectado = true


func _obtener_slots() -> void:
	slot_nodes.clear()

	if slots_container == null:
		return

	for child in slots_container.get_children():
		if child is Button:
			var slot := child as Button

			slot_nodes.append(
				slot
			)

			if not slot.pressed.is_connected(
				_al_pulsar_slot
			):
				slot.pressed.connect(
					_al_pulsar_slot.bind(slot)
				)

			if slot_nodes.size() >= SLOT_COUNT:
				break

	print(
		"Hotbar: slots encontrados → ",
		slot_nodes.size()
	)


func _preparar_slots() -> void:
	for i in range(slot_nodes.size()):
		var slot := slot_nodes[i]

		slot.text = ""
		slot.icon = null
		slot.clip_text = true

		_crear_icono(slot)
		_crear_cantidad(slot)
		_crear_numero(slot)

		var estilo_normal := slot.get_theme_stylebox("normal")
		var estilo_seleccionado: StyleBox = PIXEL_UI_THEME.slot_style(true)
		if estilo_seleccionado == null:
			estilo_seleccionado = slot.get_theme_stylebox("pressed")
		slot.set_meta("normal_style", estilo_normal)
		slot.set_meta("selected_style", estilo_seleccionado)
		if estilo_seleccionado != null:
			slot.add_theme_stylebox_override("hover", estilo_seleccionado)
			slot.add_theme_stylebox_override("pressed", estilo_seleccionado)


func _al_pulsar_slot(
	slot: Button
) -> void:
	var indice := slot_nodes.find(
		slot
	)

	if indice < 0:
		return

	seleccionar_hotbar(
		indice
	)


func _crear_icono(
	slot: Button
) -> TextureRect:
	var icon := slot.get_node_or_null(
		"ItemIcon"
	) as TextureRect

	if icon != null:
		icon.texture_filter = (
			CanvasItem.TEXTURE_FILTER_NEAREST
		)

		return icon

	icon = TextureRect.new()
	icon.name = "ItemIcon"

	icon.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	icon.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)

	icon.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)

	icon.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	slot.add_child(icon)

	icon.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE,
		5
	)

	return icon


func _crear_cantidad(
	slot: Button
) -> Label:
	var label := slot.get_node_or_null(
		"ItemQuantity"
	) as Label

	if label != null:
		return label

	label = Label.new()
	label.name = "ItemQuantity"

	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	label.add_theme_font_size_override(
		"font_size",
		11
	)

	label.add_theme_color_override(
		"font_color",
		Color(
			0.95,
			0.88,
			0.70,
			1.0
		)
	)

	label.add_theme_color_override(
		"font_shadow_color",
		Color(
			0.05,
			0.03,
			0.02,
			1.0
		)
	)

	label.add_theme_constant_override(
		"shadow_offset_x",
		1
	)

	label.add_theme_constant_override(
		"shadow_offset_y",
		1
	)

	slot.add_child(label)

	label.set_anchors_preset(
		Control.PRESET_BOTTOM_RIGHT
	)

	label.position = Vector2(
		-19,
		-17
	)

	label.size = Vector2(
		17,
		15
	)

	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	return label


func _crear_numero(
	slot: Button
) -> Label:
	var label := slot.get_node_or_null(
		"Number"
	) as Label

	if label != null:
		label.text = str(
			slot_nodes.find(slot) + 1
		)

		return label

	label = Label.new()
	label.name = "Number"

	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	label.text = str(
		slot_nodes.find(slot) + 1
	)

	label.add_theme_font_size_override(
		"font_size",
		9
	)

	label.add_theme_color_override(
		"font_color",
		Color(
			0.72,
			0.64,
			0.50,
			1.0
		)
	)

	label.add_theme_color_override(
		"font_shadow_color",
		Color(
			0.04,
			0.025,
			0.015,
			1.0
		)
	)

	label.add_theme_constant_override(
		"shadow_offset_x",
		1
	)

	label.add_theme_constant_override(
		"shadow_offset_y",
		1
	)

	slot.add_child(label)

	label.position = Vector2(
		4,
		2
	)

	label.size = Vector2(
		14,
		12
	)

	return label


func _actualizar() -> void:
	if not is_inside_tree():
		return

	if slot_nodes.is_empty():
		_obtener_slots()

	if inventory == null:
		_actualizar_vacios()
		_actualizar_seleccion()
		return

	for i in range(
		mini(
			SLOT_COUNT,
			slot_nodes.size()
		)
	):
		var datos: Dictionary = inventory.obtener_objeto_hotbar(i)

		_configurar_slot(
			slot_nodes[i],
			datos
		)

	_actualizar_seleccion()


func _actualizar_vacios() -> void:
	for slot in slot_nodes:
		_configurar_slot(
			slot,
			{}
		)


func _configurar_slot(
	slot: Button,
	datos: Dictionary
) -> void:
	var icon := slot.get_node_or_null(
		"ItemIcon"
	) as TextureRect

	var cantidad := slot.get_node_or_null(
		"ItemQuantity"
	) as Label

	if datos.is_empty():
		if icon:
			icon.visible = false
			icon.texture = null

		if cantidad:
			cantidad.visible = false
			cantidad.text = ""

		slot.tooltip_text = ""

		return

	var textura := (
		ItemIconResolver.obtener_icono(
			datos
		)
	)

	if icon:
		icon.texture = textura
		icon.visible = textura != null

	var cantidad_objeto := int(
		datos.get(
			"cantidad",
			1
		)
	)

	if cantidad:
		cantidad.text = str(
			cantidad_objeto
		)

		cantidad.visible = (
			cantidad_objeto > 1
		)

	slot.tooltip_text = str(
		datos.get(
			"nombre",
			"Objeto"
		)
	)


func _actualizar_seleccion() -> void:
	for i in range(
		slot_nodes.size()
	):
		var slot := slot_nodes[i]

		var normal = slot.get_meta(
			"normal_style",
			null
		)

		var seleccionado = slot.get_meta(
			"selected_style",
			null
		)

		if i == indice_seleccionado and seleccionado is StyleBox:
			slot.add_theme_stylebox_override("normal", seleccionado)
		elif normal is StyleBox:
			slot.add_theme_stylebox_override("normal", normal)


func _al_objeto_activo_cambiado(
	_datos: Dictionary
) -> void:
	_actualizar_seleccion()


func seleccionar_hotbar(
	indice: int
) -> void:
	if indice < 0 or indice >= SLOT_COUNT:
		return

	indice_seleccionado = indice

	if inventory != null:
		inventory.seleccionar_hotbar(indice)

	_actualizar()


func _mover_seleccion(
	direccion: int
) -> void:
	var nuevo_indice := (
		indice_seleccionado
		+ direccion
	)

	if nuevo_indice < 0:
		nuevo_indice = SLOT_COUNT - 1

	if nuevo_indice >= SLOT_COUNT:
		nuevo_indice = 0

	seleccionar_hotbar(
		nuevo_indice
	)


func obtener_objeto_seleccionado() -> Dictionary:
	if inventory == null:
		return {}

	return inventory.obtener_objeto_activo()


func obtener_indice_seleccionado() -> int:
	return indice_seleccionado

