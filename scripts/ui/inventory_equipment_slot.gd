extends Button

signal objeto_equipado(slot: Button, datos: Dictionary)
signal objeto_desequipado(slot: Button, datos: Dictionary)

var clave_equipo: String = ""
var datos: Dictionary = {}

@onready var icon_texture: TextureRect = $Icon
@onready var label: Label = $Label

func obtener_clave() -> String:
	return clave_equipo

func obtener_datos() -> Dictionary:
	return datos.duplicate(true)

func configurar(clave: String, nombre: String) -> void:
	clave_equipo = clave
	label.text = nombre
	_limpiar()

func _limpiar() -> void:
	datos.clear()
	icon_texture.texture = null
	icon_texture.visible = false

func configurar_objeto(nuevo_objeto: Dictionary) -> void:
	datos = nuevo_objeto.duplicate(true)
	var textura: Texture2D = ItemIconResolver.obtener_icono(datos)
	icon_texture.texture = textura
	icon_texture.visible = textura != null


func limpiar_objeto() -> void:
	_limpiar()


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var drop := data as Dictionary
	if str(drop.get("tipo", "")) != "inventario_objeto":
		return false
	var objeto_variant: Variant = drop.get("datos", {})
	if not objeto_variant is Dictionary:
		return false
	return _es_compatible(objeto_variant as Dictionary)

func _drop_data(_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_position, data):
		return
	var drop := data as Dictionary
	var objeto := (drop.get("datos", {}) as Dictionary).duplicate(true)
	objeto_equipado.emit(self, objeto)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT and not datos.is_empty():
			# El inventario decide si el objeto puede volver.
			# No limpiamos el slot antes de recibir esa confirmación.
			objeto_desequipado.emit(
				self,
				datos.duplicate(true)
			)


func _es_compatible(objeto: Dictionary) -> bool:
	var tipo: String = str(
		objeto.get(
			"tipo",
			""
		)
	).strip_edges().to_lower()

	if clave_equipo == "arma":
		return tipo == "arma"

	var tipo_variant: Variant = objeto.get("tipo_objeto", {})
	if not tipo_variant is Dictionary:
		return false

	var tipo_objeto := tipo_variant as Dictionary

	return str(
		tipo_objeto.get(
			"clave",
			""
		)
	).strip_edges().to_lower() == clave_equipo
