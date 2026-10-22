extends Control

class_name CraftingUI

const HTTP_TIMEOUT: float = 8.0

var _request: HTTPRequest
var _recetas: Array[Dictionary] = []
var _cargando: bool = false
var _lista: GridContainer
var _estado: Label
var _detalle_nombre: Label
var _detalle_icono: TextureRect
var _detalle_ingredientes: RichTextLabel
var _boton_craftear: Button
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
	_crear_interfaz()
	_cargar_recetas()



func _crear_interfaz() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_bottom", 8)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	margen.add_child(columna)


	_estado = Label.new()
	_estado.text = "Cargando recetas..."
	_estado.add_theme_font_size_override("font_size", 10)
	_estado.add_theme_color_override("font_color", Color(0.78, 0.66, 0.46))
	columna.add_child(_estado)

	var contenido := HBoxContainer.new()
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 10)
	columna.add_child(contenido)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(scroll)

	_lista = GridContainer.new()
	_lista.columns = 5
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("h_separation", 8)
	_lista.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_lista)

	var panel_detalle := PanelContainer.new()
	panel_detalle.custom_minimum_size = Vector2(210, 0)
	panel_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_detalle.add_theme_stylebox_override("panel", _crear_estilo_boton(Color(0.075, 0.05, 0.035, 0.95), Color(0.29, 0.19, 0.12, 1), 1))
	contenido.add_child(panel_detalle)

	var margen_detalle := MarginContainer.new()
	margen_detalle.add_theme_constant_override("margin_left", 10)
	margen_detalle.add_theme_constant_override("margin_top", 10)
	margen_detalle.add_theme_constant_override("margin_right", 10)
	margen_detalle.add_theme_constant_override("margin_bottom", 10)
	panel_detalle.add_child(margen_detalle)

	var columna_detalle := VBoxContainer.new()
	columna_detalle.add_theme_constant_override("separation", 8)
	margen_detalle.add_child(columna_detalle)

	_detalle_nombre = Label.new()
	_detalle_nombre.text = "Selecciona un objeto"
	_detalle_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detalle_nombre.add_theme_color_override("font_color", Color(0.9, 0.79, 0.58, 1))
	_detalle_nombre.add_theme_font_size_override("font_size", 13)
	columna_detalle.add_child(_detalle_nombre)

	_detalle_icono = TextureRect.new()
	_detalle_icono.custom_minimum_size = Vector2(0, 104)
	_detalle_icono.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalle_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detalle_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detalle_icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detalle_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna_detalle.add_child(_detalle_icono)

	var titulo_ingredientes := Label.new()
	titulo_ingredientes.text = "Necesitas"
	titulo_ingredientes.add_theme_color_override("font_color", Color(0.78, 0.66, 0.46))
	titulo_ingredientes.add_theme_font_size_override("font_size", 11)
	columna_detalle.add_child(titulo_ingredientes)

	_detalle_ingredientes = RichTextLabel.new()
	_detalle_ingredientes.bbcode_enabled = true
	_detalle_ingredientes.fit_content = true
	_detalle_ingredientes.scroll_active = true
	_detalle_ingredientes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detalle_ingredientes.add_theme_color_override("default_color", Color(0.72, 0.61, 0.45, 1))
	_detalle_ingredientes.add_theme_font_size_override("normal_font_size", 10)
	columna_detalle.add_child(_detalle_ingredientes)

	_boton_craftear = Button.new()
	_boton_craftear.text = "Craftear"
	_boton_craftear.custom_minimum_size = Vector2(0, 34)
	_boton_craftear.disabled = true
	_boton_craftear.pressed.connect(_craftear_seleccionado)
	_boton_craftear.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.19, 0.13, 0.08, 1), Color(0.55, 0.40, 0.22, 1), 2))
	_boton_craftear.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.28, 0.20, 0.12, 1), Color(0.74, 0.62, 0.34, 1), 2))
	_boton_craftear.add_theme_stylebox_override("disabled", _crear_estilo_boton(Color(0.10, 0.075, 0.05, 0.8), Color(0.25, 0.18, 0.12, 1), 1))
	columna_detalle.add_child(_boton_craftear)


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
	panel.custom_minimum_size = Vector2(64, 64)
	panel.tooltip_text = str(receta.get("nombre", "Receta"))
	panel.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.11, 0.07, 0.045, 0.9), Color(0.29, 0.19, 0.12, 1), 1))
	panel.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.19, 0.13, 0.08, 1), Color(0.55, 0.40, 0.22, 1), 2))
	panel.add_theme_stylebox_override("pressed", _crear_estilo_boton(Color(0.28, 0.20, 0.12, 1), Color(0.74, 0.62, 0.34, 1), 2))
	panel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	panel.text = ""
	panel.pressed.connect(func() -> void:
		_seleccionar_receta(receta)
	)
	_lista.add_child(panel)

	var resultado: Dictionary = receta.get("resultado", {}) as Dictionary
	var icono := TextureRect.new()
	icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icono.offset_left = 6
	icono.offset_top = 6
	icono.offset_right = -6
	icono.offset_bottom = -6
	icono.custom_minimum_size = Vector2(52, 52)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.texture = ItemIconResolver.obtener_icono(
		_buscar_item_catalogo(str(resultado.get("item_id", "")))
	)
	panel.add_child(icono)



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
	_detalle_ingredientes.text = "\\n".join(partes)
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

func _crear_estilo_boton(fondo: Color, borde: Color, borde_inferior: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(1)
	estilo.border_width_bottom = borde_inferior
	estilo.corner_radius_top_left = 3
	estilo.corner_radius_top_right = 3
	return estilo

func _texto_ingredientes(receta: Dictionary) -> String:
	var partes: Array[String] = []
	var ingredientes_variant: Variant = receta.get("ingredientes", [])

	if not ingredientes_variant is Array:
		return "Materiales: —"

	for ingrediente_variant in ingredientes_variant as Array:
		if not ingrediente_variant is Dictionary:
			continue
		var ingrediente := ingrediente_variant as Dictionary
		var id := str(ingrediente.get("item_id", ""))
		var cantidad := int(ingrediente.get("cantidad", 1))
		partes.append(_nombre_item(id) + " x" + str(cantidad))

	return "Materiales: " + ", ".join(partes)


func _buscar_item_catalogo(item_id: String) -> Dictionary:
	if _world_items == null or not is_instance_valid(_world_items):
		return {}
	return _world_items.buscar_item_por_id(item_id)


func _nombre_item(item_id: String) -> String:
	if _world_items == null:
		return item_id
	var item := _buscar_item_catalogo(item_id)
	if item.is_empty():
		return item_id
	return str(item.get("nombre", item_id))


func _obtener_cantidad_item(items: Array[Dictionary], item_id: String) -> int:
	var total := 0

	for objeto in items:
		var actual := str(objeto.get("item_id", objeto.get("id", "")))
		if actual == item_id:
			total += maxi(1, int(objeto.get("cantidad", 1)))

	return total


func _puede_craftear(receta: Dictionary, items: Array[Dictionary]) -> bool:
	var ingredientes_variant: Variant = receta.get("ingredientes", [])

	if not ingredientes_variant is Array:
		return false

	for ingrediente_variant in ingredientes_variant as Array:
		if not ingrediente_variant is Dictionary:
			return false

		var ingrediente := ingrediente_variant as Dictionary
		var item_id := str(ingrediente.get("item_id", ""))
		var cantidad := maxi(1, int(ingrediente.get("cantidad", 1)))

		if item_id.is_empty() or _obtener_cantidad_item(items, item_id) < cantidad:
			return false

	return true


func _craftear(receta: Dictionary) -> void:
	var inventario := _inventory

	if inventario == null:
		_estado.text = "No se encontró el inventario."
		return

	var items: Array[Dictionary] = inventario.obtener_objetos()

	if not _puede_craftear(receta, items):
		_estado.text = "Faltan materiales para " + str(receta.get("nombre", "esta receta")) + "."
		return

	var resultado_variant: Variant = receta.get("resultado", {})
	if not resultado_variant is Dictionary:
		return

	var resultado := resultado_variant as Dictionary
	var output_id := str(resultado.get("item_id", ""))
	var output_cantidad := maxi(1, int(resultado.get("cantidad", 1)))

	if _world_items == null:
		_estado.text = "No está disponible el catálogo de objetos."
		return

	var objeto_resultado := _world_items.buscar_item_por_id(output_id)

	if objeto_resultado.is_empty():
		_estado.text = "El objeto resultado no está en el catálogo del juego."
		return

	objeto_resultado["cantidad"] = output_cantidad
	objeto_resultado["max_stack"] = maxi(1, int(objeto_resultado.get("max_stack", 1)))

	# Primero añadimos el resultado. agregar_objeto es atómico si no hay espacio,
	# así evitamos consumir materiales cuando el resultado no puede entrar.
	if not inventario.agregar_objeto(objeto_resultado):
		_estado.text = "No hay espacio para el resultado."
		return

	# Los materiales ya fueron comprobados; ahora se consumen de los slots reales.
	var ingredientes := receta.get("ingredientes", []) as Array

	for ingrediente_variant in ingredientes:
		var ingrediente := ingrediente_variant as Dictionary
		var item_id := str(ingrediente.get("item_id", ""))
		var restante := maxi(1, int(ingrediente.get("cantidad", 1)))

		for indice in range(inventario.obtener_objetos().size()):
			if restante <= 0:
				break

			var objeto: Dictionary = inventario.obtener_objeto(indice)
			if objeto.is_empty():
				continue

			var actual_id := str(objeto.get("item_id", objeto.get("id", "")))
			if actual_id != item_id:
				continue

			var disponible := maxi(1, int(objeto.get("cantidad", 1)))
			var quitar := mini(restante, disponible)

			if inventario.quitar_cantidad(indice, quitar):
				restante -= quitar

	Events.notification_pushed.emit(
		"Creaste " + str(objeto_resultado.get("nombre", "Objeto"))
	)
	_estado.text = "Creado: " + str(objeto_resultado.get("nombre", "Objeto")) + "."
	_renderizar_recetas()
