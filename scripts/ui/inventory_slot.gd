extends Button


signal seleccionado(slot: Button)


var datos: Dictionary = {}


@onready var icon_texture: TextureRect = $Icon
@onready var icon_placeholder: ColorRect = $IconPlaceholder
@onready var quantity_label: Label = $Quantity


func _ready() -> void:
	pressed.connect(
		_al_pulsar
	)

	actualizar()


func configurar(
	nuevos_datos: Dictionary
) -> void:
	datos = nuevos_datos

	actualizar()


func limpiar() -> void:
	datos.clear()

	actualizar()


func esta_ocupado() -> bool:
	return not datos.is_empty()


func obtener_datos() -> Dictionary:
	return datos


func actualizar() -> void:
	if not is_inside_tree():
		return

	if datos.is_empty():
		icon_texture.texture = null
		icon_placeholder.visible = true
		quantity_label.text = ""
		return


	var textura: Variant = datos.get(
		"icono",
		null
	)

	if textura is Texture2D:
		icon_texture.texture = textura
		icon_placeholder.visible = false
	else:
		icon_texture.texture = null
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
