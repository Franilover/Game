extends Control


const SLOT_COUNT: int = 8


var indice_seleccionado: int = 0
var inventory: Node = null

var slots_container: HBoxContainer = null
var slot_nodes: Array[Button] = []

var _inventario_conectado: bool = false


func _ready() -> void:
	var marco_fijo := get_node_or_null(
		"Selection"
	)

	if marco_fijo is Control:
		(marco_fijo as Control).visible = false

	slots_container = _buscar_hbox(
		"Slots"
	)

	if slots_container == null:
		print(
			"Hotbar: ERROR - no se encontró el nodo Slots."
		)
		return

	_buscar_inventario()
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
			and key_event.keycode <= KEY_8
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


func _buscar_hbox(
	nombre: String
) -> HBoxContainer:
	var nodo := find_child(
		nombre,
		true,
		false
	)

	if nodo is HBoxContainer:
		return nodo as HBoxContainer

	return null


func _process(
	_delta: float
) -> void:
	if (
		inventory == null
		or not is_instance_valid(inventory)
	):
		_buscar_inventario()

		if inventory != null:
			_actualizar()


func _buscar_inventario() -> void:
	inventory = get_tree().get_first_node_in_group(
		"inventory"
	)

	if inventory == null:
		_inventario_conectado = false
		return

	if _inventario_conectado:
		return

	if inventory.has_signal(
		"inventory_changed"
	):
		if not inventory.is_connected(
			"inventory_changed",
			_actualizar
		):
			inventory.connect(
				"inventory_changed",
				_actualizar
			)

	if inventory.has_signal(
		"active_item_changed"
	):
		if not inventory.is_connected(
			"active_item_changed",
			_al_objeto_activo_cambiado
		):
			inventory.connect(
				"active_item_changed",
				_al_objeto_activo_cambiado
			)

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
		_crear_placeholder(slot)
		_crear_cantidad(slot)
		_crear_numero(slot)

		_configurar_estilo_normal(slot)
		_configurar_estilo_seleccionado(slot)


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


func _crear_placeholder(
	slot: Button
) -> Panel:
	var placeholder := slot.get_node_or_null(
		"ItemPlaceholder"
	) as Panel

	if placeholder != null:
		return placeholder

	placeholder = Panel.new()
	placeholder.name = "ItemPlaceholder"

	placeholder.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	placeholder.z_index = -1

	slot.add_child(placeholder)

	placeholder.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE,
		8
	)

	var estilo := StyleBoxFlat.new()

	estilo.bg_color = Color(
		0.16,
		0.105,
		0.065,
		0.95
	)

	estilo.border_width_left = 1
	estilo.border_width_top = 1
	estilo.border_width_right = 1
	estilo.border_width_bottom = 1

	estilo.border_color = Color(
		0.30,
		0.20,
		0.12,
		1.0
	)

	placeholder.add_theme_stylebox_override(
		"panel",
		estilo
	)

	return placeholder


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


func _configurar_estilo_normal(
	slot: Button
) -> void:
	var estilo := StyleBoxFlat.new()

	estilo.bg_color = Color(
		0.18,
		0.115,
		0.07,
		0.98
	)

	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_width_right = 2
	estilo.border_width_bottom = 2

	estilo.border_color = Color(
		0.42,
		0.29,
		0.17,
		1.0
	)

	estilo.corner_radius_top_left = 3
	estilo.corner_radius_top_right = 3
	estilo.corner_radius_bottom_left = 3
	estilo.corner_radius_bottom_right = 3

	slot.set_meta(
		"normal_style",
		estilo
	)

	slot.add_theme_stylebox_override(
		"normal",
		estilo
	)


func _configurar_estilo_seleccionado(
	slot: Button
) -> void:
	var estilo := StyleBoxFlat.new()

	estilo.bg_color = Color(
		0.34,
		0.27,
		0.14,
		1.0
	)

	estilo.border_width_left = 2
	estilo.border_width_top = 2
	estilo.border_width_right = 2
	estilo.border_width_bottom = 2

	estilo.border_color = Color(
		0.74,
		0.62,
		0.34,
		1.0
	)

	estilo.corner_radius_top_left = 3
	estilo.corner_radius_top_right = 3
	estilo.corner_radius_bottom_left = 3
	estilo.corner_radius_bottom_right = 3

	slot.set_meta(
		"selected_style",
		estilo
	)


func _actualizar() -> void:
	if not is_inside_tree():
		return

	if inventory == null:
		_buscar_inventario()

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
		var datos: Dictionary = inventory.call(
			"obtener_objeto_hotbar",
			i
		)

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

	var placeholder := slot.get_node_or_null(
		"ItemPlaceholder"
	) as Panel

	var cantidad := slot.get_node_or_null(
		"ItemQuantity"
	) as Label

	if datos.is_empty():
		if icon:
			icon.visible = false
			icon.texture = null

		if placeholder:
			placeholder.visible = false

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

	if placeholder:
		placeholder.visible = textura == null

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

		if (
			i == indice_seleccionado
			and seleccionado is StyleBoxFlat
		):
			slot.add_theme_stylebox_override(
				"normal",
				seleccionado
			)
		else:
			if normal is StyleBoxFlat:
				slot.add_theme_stylebox_override(
					"normal",
					normal
				)


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
		inventory.call(
			"seleccionar_hotbar",
			indice
		)

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
		_buscar_inventario()

	if inventory == null:
		return {}

	return inventory.call(
		"obtener_objeto_activo"
	)


func obtener_indice_seleccionado() -> int:
	return indice_seleccionado
