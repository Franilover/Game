extends Button


signal seleccionado(slot: Button)
signal equipar_solicitado(slot: Button)


var datos: Dictionary = {}


@onready var icon_texture: TextureRect = $Icon
@onready var icon_placeholder: ColorRect = $IconPlaceholder
@onready var quantity_label: Label = $Quantity


func _ready() -> void:
	icon_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	pressed.connect(
		_al_pulsar
	)

	gui_input.connect(
		_al_input_gui
	)

	actualizar()


func configurar(
	nuevos_datos: Dictionary
) -> void:
	datos = nuevos_datos.duplicate(true)

	actualizar()


func limpiar() -> void:
	datos.clear()

	actualizar()


func esta_ocupado() -> bool:
	return not datos.is_empty()


func obtener_datos() -> Dictionary:
	return datos.duplicate(true)


func actualizar() -> void:
	if not is_inside_tree():
		return

	if datos.is_empty():
		icon_texture.texture = null
		icon_texture.visible = false

		icon_placeholder.visible = true

		quantity_label.text = ""

		return

	var textura: Texture2D = (
		ItemIconResolver.obtener_icono(
			datos
		)
	)

	if textura != null:
		icon_texture.texture = textura
		icon_texture.visible = true

		icon_placeholder.visible = false
	else:
		icon_texture.texture = null
		icon_texture.visible = false

		icon_placeholder.visible = true

	var cantidad: int = int(
		datos.get(
			"cantidad",
			1
		)
	)

	if cantidad > 1:
		quantity_label.text = str(
			cantidad
		)
	else:
		quantity_label.text = ""


func _al_pulsar() -> void:
	seleccionado.emit(
		self
	)


func _al_input_gui(
	event: InputEvent
) -> void:
	if datos.is_empty():
		return

	if event is InputEventMouseButton:
		var mouse_event := (
			event as InputEventMouseButton
		)

		if (
			mouse_event.pressed
			and mouse_event.button_index
			== MOUSE_BUTTON_RIGHT
		):
			equipar_solicitado.emit(
				self
			)

			accept_event()
