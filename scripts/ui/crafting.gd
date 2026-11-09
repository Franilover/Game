extends Control

class_name CraftingUI

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const HTTP_TIMEOUT: float = 8.0

var _request: HTTPRequest
var _recetas: Array[Dictionary] = []
var _cargando: bool = false
@onready var _lista: GridContainer = $Margin/Column/Content/RecipeScroll/RecipeGrid
@onready var _lista_scroll: ScrollContainer = $Margin/Column/Content/RecipeScroll
@onready var _estado: Label = $Margin/Column/Status
@onready var _detalle_nombre: Label = $Margin/Column/Content/DetailPanel/DetailMargin/DetailColumn/RecipeName
@onready var _detalle_icono: TextureRect = $Margin/Column/Content/DetailPanel/DetailMargin/DetailColumn/RecipeIcon
@onready var _detalle_ingredientes: RichTextLabel = $Margin/Column/Content/DetailPanel/DetailMargin/DetailColumn/Ingredients
@onready var _boton_craftear: Button = $Margin/Column/Content/DetailPanel/DetailMargin/DetailColumn/CraftButton
var _receta_seleccionada: Dictionary = {}
var _inventory: Node = null
var _world_items: GarliaWorldItems = null


func configurar(inventario: Node, world_items: GarliaWorldItems = null) -> void:
	_inventory = inventario
	_world_items = world_items
	if _world_items != null:
		if not _world_items.catalogo_cargado.is_connected(_al_catalogo_cargado):
			_world_items.catalogo_cargado.connect(_al_catalogo_cargado)
		# El catálogo puede haber terminado de cargar antes de la inyección.
		if not _world_items.catalogo.is_empty():
			call_deferred("_renderizar_recetas")


func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	PIXEL_UI_THEME.apply(self)
	$Margin/Column/Content/DetailPanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_boton_craftear.pressed.connect(_craftear_seleccionado)
	_lista_scroll.resized.connect(_ajustar_columnas_recetas)
	call_deferred("_ajustar_columnas_recetas")
	_cargar_recetas()





func _cargar_recetas() -> void:
	if _cargando:
		return

	_cargando = true

	_request = HTTPRequest.new()
	_request.timeout = HTTP_TIMEOUT
	add_child(_request)
	_request.request_completed.connect(_al_recibir_recetas)

	var url := (
		str(GarliaAuth.SUPABASE_URL)
		+ "/rest/v1/recetas_game"
		+ "?select=id,nombre,descripcion,categoria,ingredientes,resultado,propiedades"
		+ "&order=nombre.asc"
	)

	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Accept: application/json"
	])

	var resultado := _request.request(url, headers, HTTPClient.METHOD_GET)

	if resultado != OK:
		_cargando = false
		_estado.text = "No se pudieron cargar las recetas."
		print("Crafting: error iniciando consulta → ", resultado)


func _al_recibir_recetas(
	resultado: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_cargando = false

	if resultado != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_estado.text = "No se pudieron cargar las recetas."
		print("Crafting: Supabase respondió HTTP ", response_code)
		return

	var datos: Variant = JSON.parse_string(body.get_string_from_utf8())

	if not datos is Array:
		_estado.text = "Respuesta de recetas inválida."
		return

	_recetas.clear()
	for fila_variant in datos as Array:
		if fila_variant is Dictionary:
			_recetas.append((fila_variant as Dictionary).duplicate(true))

	_renderizar_recetas()


func _al_catalogo_cargado(_items: Array) -> void:
	_renderizar_recetas()


func _renderizar_recetas() -> void:
	if _lista == null:
		return

	for child in _lista.get_children():
		child.queue_free()

	_receta_seleccionada.clear()
	_actualizar_panel_detalle()
	if _recetas.is_empty():
		_estado.text = "No hay recetas disponibles."
		return

	# El contador ocupaba una línea útil de la interfaz.
	_estado.text = ""

	for receta in _recetas:
		_crear_tarjeta_receta(receta)


func _crear_tarjeta_receta(receta: Dictionary) -> void:
	var panel := Button.new()
	panel.custom_minimum_size = Vector2(56, 56)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.name = "InventorySlot"
	panel.tooltip_text = str(receta.get("nombre", "Receta"))
	panel.text = ""
	panel.pressed.connect(func() -> void:
		_seleccionar_receta(receta)
	)
	_lista.add_child(panel)
	PIXEL_UI_THEME.apply(panel)

	var resultado: Dictionary = receta.get("resultado", {}) as Dictionary
	var icono := TextureRect.new()
	icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icono.offset_left = 7
	icono.offset_top = 7
	icono.offset_right = -7
	icono.offset_bottom = -7
	icono.custom_minimum_size = Vector2(42, 42)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.texture = ItemIconResolver.obtener_icono(
		_buscar_item_catalogo(str(resultado.get("item_id", "")))
	)
	panel.add_child(icono)



func _ajustar_columnas_recetas() -> void:
	if not is_instance_valid(_lista) or not is_instance_valid(_lista_scroll):
		return
	var separacion := 6
	var ancho_util := maxi(1, int(_lista_scroll.size.x))
	var columnas := floori(float(ancho_util + separacion) / 62.0)
	_lista.columns = clampi(columnas, 3, 8)


func _seleccionar_receta(receta: Dictionary) -> void:
	_receta_seleccionada = receta.duplicate(true)
	_actualizar_panel_detalle()


func _actualizar_panel_detalle() -> void:
	if _detalle_nombre == null:
		return
	if _receta_seleccionada.is_empty():
		_detalle_nombre.text = "Selecciona un objeto"
		_detalle_icono.texture = null
		_detalle_ingredientes.text = ""
		_boton_craftear.disabled = true
		return

	_detalle_nombre.text = str(_receta_seleccionada.get("nombre", "Receta"))
	var resultado_variant: Variant = _receta_seleccionada.get("resultado", {})
	var resultado: Dictionary = resultado_variant as Dictionary if resultado_variant is Dictionary else {}
	_detalle_icono.texture = ItemIconResolver.obtener_icono(
		_buscar_item_catalogo(str(resultado.get("item_id", "")))
	)

	var partes: Array[String] = []
	var ingredientes_variant: Variant = _receta_seleccionada.get("ingredientes", [])
	var inventario_disponible: Array[Dictionary] = []
	if _inventory != null:
		inventario_disponible = _inventory.obtener_objetos()

	if ingredientes_variant is Array and not (ingredientes_variant as Array).is_empty():
		for ingrediente_variant in ingredientes_variant as Array:
			if not ingrediente_variant is Dictionary:
				continue
			var ingrediente := ingrediente_variant as Dictionary
			var item_id := str(ingrediente.get("item_id", ""))
			var cantidad := maxi(1, int(ingrediente.get("cantidad", 1)))
			var disponible := _obtener_cantidad_item(inventario_disponible, item_id)
			var color := "#8fbd78" if disponible >= cantidad else "#c87964"
			partes.append("[color=" + color + "]" + _nombre_item(item_id) + "  " + str(disponible) + "/" + str(cantidad) + "[/color]")
	else:
		partes.append("No hay materiales definidos.")
	_detalle_ingredientes.text = "\n".join(partes)
	_boton_craftear.disabled = _inventory == null or not _puede_craftear(_receta_seleccionada, inventario_disponible)


func _craftear_seleccionado() -> void:
	if not _receta_seleccionada.is_empty():
		_craftear(_receta_seleccionada)


func _tooltip_receta(receta: Dictionary) -> String:
	var partes: Array[String] = [str(receta.get("nombre", "Receta"))]
	var ingredientes_variant: Variant = receta.get("ingredientes", [])
	if ingredientes_variant is Array:
		partes.append("Necesita:")
		for ingrediente_variant in ingredientes_variant as Array:
			if not ingrediente_variant is Dictionary:
				continue
			var ingrediente := ingrediente_variant as Dictionary
			partes.append(_nombre_item(str(ingrediente.get("item_id", ""))) + " x" + str(maxi(1, int(ingrediente.get("cantidad", 1)))))
	return "\n".join(partes)
