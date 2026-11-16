extends Control

class_name CraftingUI

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const HTTP_TIMEOUT: float = 20.0
const MAX_RECETAS_INTENTOS: int = 3
const RETRASO_REINTENTO_RECETAS: float = 1.5

var _request: HTTPRequest
var _recetas: Array[Dictionary] = []
var _cargando: bool = false
var _intentos_recetas: int = 0
var _reintento_recetas_programado: bool = false
@onready var _lista: VBoxContainer = $Margin/Column/Content/RecipeScroll/RecipeList
@onready var _lista_scroll: ScrollContainer = $Margin/Column/Content/RecipeScroll
@onready var _estado: Label = $Margin/Column/Status
@onready var _detalle_nombre: Label = $Margin/Column/Content/DetailPanel/DetailMargin/DetailColumn/RecipeName
@onready var _detalle_icono: TextureRect = $Margin/Column/Content/DetailPanel/DetailMargin/DetailColumn/RecipeIcon
@onready var _detalle_ingredientes: RichTextLabel = $Margin/Column/Content/DetailPanel/DetailMargin/DetailColumn/Ingredients
@onready var _boton_craftear: Button = $Margin/Column/Content/DetailPanel/DetailMargin/DetailColumn/CraftButton
var _receta_seleccionada: Dictionary = {}
var _tarjeta_receta_seleccionada: Button = null
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
	PIXEL_UI_THEME.apply(self, false)
	var fondo_detalle := get_node_or_null("Margin/Column/Content/DetailPanel") as PanelContainer
	if fondo_detalle != null:
		# El panel de detalle usa exclusivamente la superficie normal de botón.
		# Limpiar primero el estilo de panel clásico evita conservar su marco
		# anterior si la escena o el tema global lo habían aplicado.
		fondo_detalle.remove_theme_stylebox_override("panel")
		var estilo_boton := PIXEL_UI_THEME.button_surface_style()
		if estilo_boton != null:
			fondo_detalle.add_theme_stylebox_override("panel", estilo_boton)
	_boton_craftear.pressed.connect(_craftear_seleccionado)
	_lista_scroll.resized.connect(_ajustar_columnas_recetas)
	call_deferred("_ajustar_columnas_recetas")
	# GarliaAuth restaura la sesión de forma asíncrona al iniciar el juego.
	# Esperamos ese resultado para no consultar recetas con un contexto
	# anónimo mientras la sesión del jugador todavía se está recuperando.
	if GarliaAuth.esta_restaurando_sesion():
		if not GarliaAuth.session_restore_finished.is_connected(_al_finalizar_restauracion_auth):
			GarliaAuth.session_restore_finished.connect(_al_finalizar_restauracion_auth, CONNECT_ONE_SHOT)
	else:
		_cargar_recetas()


func _al_finalizar_restauracion_auth() -> void:
	if is_inside_tree():
		_cargar_recetas()





func _cargar_recetas() -> void:
	if _cargando or _reintento_recetas_programado:
		return

	if _request == null or not is_instance_valid(_request):
		_request = HTTPRequest.new()
		_request.timeout = HTTP_TIMEOUT
		add_child(_request)
		_request.request_completed.connect(_al_recibir_recetas)

	_cargando = true
	_intentos_recetas += 1

	var url := (
		str(GarliaAuth.SUPABASE_URL)
		+ "/rest/v1/recetas_game"
		+ "?select=id,nombre,descripcion,categoria,ingredientes,resultado,propiedades"
		+ "&order=nombre.asc"
	)

	# Mantener el mismo contexto de autenticación que el resto de las
	# consultas REST del juego. Sin Authorization, esta petición podía
	# ejecutarse como anon aunque el jugador ya tuviera sesión iniciada.
	var token := GarliaAuth.access_token
	if token.is_empty():
		token = GarliaAuth.SUPABASE_PUBLISHABLE_KEY
	var headers := PackedStringArray([
		"apikey: " + GarliaAuth.SUPABASE_PUBLISHABLE_KEY,
		"Authorization: Bearer " + token,
		"Accept: application/json"
	])

	var resultado := _request.request(url, headers, HTTPClient.METHOD_GET)

	if resultado != OK:
		_cargando = false
		_estado.text = "Conexión inestable. Reintentando recetas..."
		push_error("Crafting[%s]: no se pudo iniciar GET de recetas → %s" % [str(get_instance_id()), str(resultado)])
		call_deferred("_programar_reintento_recetas", "inicio de solicitud " + str(resultado))
	else:
		_estado.text = "Consultando recetas..."
		print("Crafting[%s]: GET recetas iniciado. intento=%d/%d Auth=%s" % [str(get_instance_id()), _intentos_recetas, MAX_RECETAS_INTENTOS, str(GarliaAuth.esta_autenticado())])


func _al_recibir_recetas(
	resultado: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_cargando = false
	var texto_respuesta := body.get_string_from_utf8()
	print("Crafting[%s]: callback recetas result=%d HTTP=%d bytes=%d" % [str(get_instance_id()), resultado, response_code, body.size()])

	if resultado != HTTPRequest.RESULT_SUCCESS:
		_estado.text = "Conexión inestable. Reintentando recetas..."
		push_error("Crafting[%s]: fallo de red recetas result=%d intento=%d/%d" % [str(get_instance_id()), resultado, _intentos_recetas, MAX_RECETAS_INTENTOS])
		call_deferred("_programar_reintento_recetas", "resultado de red " + str(resultado))
		return

	if response_code < 200 or response_code >= 300:
		if response_code == 429 or response_code >= 500:
			_estado.text = "Supabase está tardando. Reintentando recetas..."
			push_error("Crafting[%s]: Supabase respondió HTTP %d; intento=%d/%d" % [str(get_instance_id()), response_code, _intentos_recetas, MAX_RECETAS_INTENTOS])
			call_deferred("_programar_reintento_recetas", "HTTP " + str(response_code))
		else:
			_estado.text = "No se pudieron cargar las recetas (HTTP " + str(response_code) + ")."
			push_error("Crafting[%s]: fallo HTTP recetas: %s" % [str(get_instance_id()), texto_respuesta.left(500)])
		return

	var json := JSON.new()
	var error_parseo := json.parse(texto_respuesta)
	if error_parseo != OK:
		_estado.text = "Respuesta de recetas inválida."
		push_error("Crafting[%s]: JSON inválido: %s" % [str(get_instance_id()), texto_respuesta.left(500)])
		return
	if not json.data is Array:
		_estado.text = "Respuesta de recetas inválida."
		push_error("Crafting[%s]: se esperaba Array y llegó %s" % [str(get_instance_id()), type_string(typeof(json.data))])
		return

	_intentos_recetas = 0
	_recetas.clear()
	for fila_variant in json.data as Array:
		if fila_variant is Dictionary:
			_recetas.append((fila_variant as Dictionary).duplicate(true))

	print("Crafting[%s]: recetas recibidas=%d; filas JSON=%d" % [str(get_instance_id()), _recetas.size(), (json.data as Array).size()])
	_renderizar_recetas()


func _programar_reintento_recetas(motivo: String) -> void:
	if _reintento_recetas_programado or _intentos_recetas >= MAX_RECETAS_INTENTOS:
		if _intentos_recetas >= MAX_RECETAS_INTENTOS:
			_estado.text = "No se pudo conectar con Supabase. Intenta abrir Crafteo de nuevo."
			print("Crafting[%s]: agotados los intentos de carga de recetas (%s)." % [str(get_instance_id()), motivo])
		return

	_reintento_recetas_programado = true
	var espera := RETRASO_REINTENTO_RECETAS * float(_intentos_recetas)
	print("Crafting[%s]: reintentando recetas → intento %d/%d en %.1fs (%s)" % [str(get_instance_id()), _intentos_recetas + 1, MAX_RECETAS_INTENTOS, espera, motivo])
	await get_tree().create_timer(espera).timeout
	_reintento_recetas_programado = false
	if not is_inside_tree() or not _recetas.is_empty():
		return
	_cargar_recetas()

func _al_catalogo_cargado(_items: Array) -> void:
	_renderizar_recetas()


func _renderizar_recetas() -> void:
	if _lista == null:
		push_error("Crafting[%s]: RecipeList no existe; no se puede renderizar." % str(get_instance_id()))
		return

	print("Crafting[%s]: renderizando %d recetas." % [str(get_instance_id()), _recetas.size()])
	for child in _lista.get_children():
		child.queue_free()

	_receta_seleccionada.clear()
	_tarjeta_receta_seleccionada = null
	_actualizar_panel_detalle()
	if _recetas.is_empty():
		_estado.text = "No hay recetas disponibles."
		return

	_estado.text = ""
	var grupos: Dictionary = {}
	for receta in _recetas:
		var resultado_variant: Variant = receta.get("resultado", {})
		var resultado: Dictionary = resultado_variant as Dictionary if resultado_variant is Dictionary else {}
		var item_resultado := _buscar_item_catalogo(str(resultado.get("item_id", "")))
		var categoria_variant: Variant = item_resultado.get("categoria", {})
		var categoria: Dictionary = categoria_variant as Dictionary if categoria_variant is Dictionary else {}
		var clave := str(categoria.get("clave", "")).strip_edges().to_lower()
		var nombre_categoria := str(categoria.get("nombre", ""))
		if clave.is_empty():
			clave = str(receta.get("categoria", "sin_categoria")).strip_edges().to_lower()
		if nombre_categoria.is_empty():
			nombre_categoria = str(receta.get("categoria", "Otras recetas")).replace("_", " ").capitalize()
		if clave.is_empty():
			clave = "sin_categoria"
		if not grupos.has(clave):
			grupos[clave] = {
				"nombre": nombre_categoria,
				"orden": int(categoria.get("orden", 999)),
				"recetas": []
			}
		(grupos[clave]["recetas"] as Array).append(receta)

	var claves: Array = grupos.keys()
	claves.sort_custom(func(a: Variant, b: Variant) -> bool:
		var grupo_a: Dictionary = grupos[a]
		var grupo_b: Dictionary = grupos[b]
		var orden_a := int(grupo_a.get("orden", 999))
		var orden_b := int(grupo_b.get("orden", 999))
		if orden_a == orden_b:
			return str(grupo_a.get("nombre", a)) < str(grupo_b.get("nombre", b))
		return orden_a < orden_b
	)

	for clave_variant in claves:
		var grupo: Dictionary = grupos[clave_variant]
		# Cada categoría tiene una única superficie de botón que agrupa
		# visualmente su título y todas sus recetas.
		var seccion := PanelContainer.new()
		seccion.name = "Categoria_" + str(clave_variant)
		seccion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fondo_categoria := PIXEL_UI_THEME.button_surface_style()
		if fondo_categoria != null:
			seccion.add_theme_stylebox_override("panel", fondo_categoria)
		_lista.add_child(seccion)

		var margen_categoria := MarginContainer.new()
		margen_categoria.add_theme_constant_override("margin_left", 7)
		margen_categoria.add_theme_constant_override("margin_top", 6)
		margen_categoria.add_theme_constant_override("margin_right", 7)
		margen_categoria.add_theme_constant_override("margin_bottom", 6)
		seccion.add_child(margen_categoria)

		var contenido_categoria := VBoxContainer.new()
		contenido_categoria.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contenido_categoria.add_theme_constant_override("separation", 5)
		margen_categoria.add_child(contenido_categoria)

		var encabezado := Label.new()
		encabezado.name = "CategoryHeading"
		encabezado.text = str(grupo.get("nombre", "Sin categoría")).to_upper()
		encabezado.custom_minimum_size = Vector2(0, 20)
		encabezado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		encabezado.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		encabezado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		encabezado.add_theme_color_override("font_color", Color("#E6D0A6"))
		encabezado.add_theme_font_size_override("font_size", 12)
		contenido_categoria.add_child(encabezado)

		var rejilla := GridContainer.new()
		rejilla.name = "RecipeGrid"
		rejilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rejilla.columns = 3
		rejilla.add_theme_constant_override("h_separation", 6)
		rejilla.add_theme_constant_override("v_separation", 6)
		contenido_categoria.add_child(rejilla)
		for receta_variant in grupo.get("recetas", []) as Array:
			if receta_variant is Dictionary:
				_crear_tarjeta_receta(receta_variant as Dictionary, rejilla)

	call_deferred("_ajustar_columnas_recetas")


func _crear_tarjeta_receta(receta: Dictionary, rejilla: GridContainer) -> void:
	var panel := Button.new()
	# Mantener las tarjetas cuadradas como los slots del inventario.
	# GridContainer organiza las columnas; cada tarjeta conserva su tamaño.
	panel.custom_minimum_size = Vector2(64, 64)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.name = "InventorySlot"
	panel.tooltip_text = ""
	panel.text = ""
	panel.toggle_mode = true
	panel.pressed.connect(func() -> void:
		_seleccionar_receta(receta, panel)
	)
	rejilla.add_child(panel)
	PIXEL_UI_THEME.apply(panel, false)

	var resultado_variant: Variant = receta.get("resultado", {})
	var resultado: Dictionary = resultado_variant as Dictionary if resultado_variant is Dictionary else {}
	var nombre_resultado := str(resultado.get("nombre", receta.get("nombre", "Objeto"))).strip_edges()
	var item_resultado := _buscar_item_catalogo(str(resultado.get("item_id", "")))
	if item_resultado.is_empty():
		item_resultado = _buscar_item_catalogo_por_nombre(nombre_resultado)
	if not item_resultado.is_empty():
		nombre_resultado = str(item_resultado.get("nombre", nombre_resultado))
	var datos_icono := item_resultado.duplicate(true)
	if datos_icono.is_empty():
		datos_icono = {"nombre": nombre_resultado}
	var textura_resultado := ItemIconResolver.obtener_icono(datos_icono)
	if textura_resultado != null:
		var icono := TextureRect.new()
		icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icono.offset_left = 5
		icono.offset_top = 5
		icono.offset_right = -5
		icono.offset_bottom = -5
		icono.custom_minimum_size = Vector2(54, 54)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.texture = textura_resultado
		panel.add_child(icono)



func _ajustar_columnas_recetas() -> void:
	if not is_instance_valid(_lista):
		return
	var separacion := 6
	for rejilla_variant in _lista.find_children("RecipeGrid", "GridContainer", true, false):
		var rejilla := rejilla_variant as GridContainer
		# Cada categoría calcula sus columnas según el ancho real disponible.
		# Así sus sprites se distribuyen horizontalmente y saltan a otra fila.
		var ancho_util := maxi(64, int(rejilla.size.x))
		var columnas := maxi(1, floori(float(ancho_util + separacion) / 70.0))
		rejilla.columns = mini(columnas, 8)


func _seleccionar_receta(receta: Dictionary, tarjeta: Button) -> void:
	if is_instance_valid(_tarjeta_receta_seleccionada) and _tarjeta_receta_seleccionada != tarjeta:
		_tarjeta_receta_seleccionada.set_pressed_no_signal(false)
	_tarjeta_receta_seleccionada = tarjeta
	if is_instance_valid(_tarjeta_receta_seleccionada):
		_tarjeta_receta_seleccionada.set_pressed_no_signal(true)
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
	var nombre_resultado := str(resultado.get("nombre", _receta_seleccionada.get("nombre", "")))
	var item_resultado := _buscar_item_catalogo(str(resultado.get("item_id", "")))
	if item_resultado.is_empty():
		item_resultado = _buscar_item_catalogo_por_nombre(nombre_resultado)
	var datos_icono := item_resultado.duplicate(true)
	if datos_icono.is_empty():
		datos_icono = {"nombre": nombre_resultado}
	_detalle_icono.texture = ItemIconResolver.obtener_icono(datos_icono)

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
			var objeto_ingrediente := _buscar_item_catalogo(item_id)
			var tiene_sprite := not objeto_ingrediente.is_empty() and ItemIconResolver.tiene_icono(objeto_ingrediente)
			var color := "#8fbd78" if disponible >= cantidad and tiene_sprite else "#c87964"
			var texto_ingrediente := _nombre_item(item_id) + "  " + str(disponible) + "/" + str(cantidad)
			partes.append("[color=" + color + "]" + texto_ingrediente + "[/color]")
	else:
		partes.append("No hay materiales definidos.")
	_detalle_ingredientes.text = "\n".join(partes)
	var ingredientes_ilustrados := _receta_ingredientes_tienen_sprites(_receta_seleccionada)
	_boton_craftear.disabled = _inventory == null or not ingredientes_ilustrados or not _puede_craftear(_receta_seleccionada, inventario_disponible)


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


func _receta_tiene_sprites(receta: Dictionary) -> bool:
	# La tarjeta representa el objeto que se fabrica. Los ingredientes sin
	# ilustración se muestran como pendientes, pero no se habilita su uso.
	var resultado_variant: Variant = receta.get("resultado", {})
	if not resultado_variant is Dictionary:
		return false
	var resultado := resultado_variant as Dictionary
	var item_resultado := _buscar_item_catalogo(str(resultado.get("item_id", "")))
	return not item_resultado.is_empty() and ItemIconResolver.tiene_icono(item_resultado)


func _receta_ingredientes_tienen_sprites(receta: Dictionary) -> bool:
	var ingredientes_variant: Variant = receta.get("ingredientes", [])
	if not ingredientes_variant is Array or (ingredientes_variant as Array).is_empty():
		return false
	for ingrediente_variant in ingredientes_variant as Array:
		if not ingrediente_variant is Dictionary:
			return false
		var ingrediente := ingrediente_variant as Dictionary
		var item_ingrediente := _buscar_item_catalogo(str(ingrediente.get("item_id", "")))
		if item_ingrediente.is_empty() or not ItemIconResolver.tiene_icono(item_ingrediente):
			return false
	return true


func _buscar_item_catalogo(item_id: String) -> Dictionary:
	if _world_items == null or not is_instance_valid(_world_items):
		return {}
	return _world_items.buscar_item_por_id(item_id)


func _buscar_item_catalogo_por_nombre(nombre: String) -> Dictionary:
	if _world_items == null or not is_instance_valid(_world_items):
		return {}
	if nombre.strip_edges().is_empty():
		return {}
	return _world_items.buscar_item_por_nombre(nombre)


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

	if not _receta_ingredientes_tienen_sprites(receta):
		_estado.text = "Esta receta todavía no está disponible: falta ilustrar uno o más ingredientes."
		return
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
	if not ItemIconResolver.tiene_icono(objeto_resultado):
		_estado.text = "Este objeto todavía no está implementado: falta su ilustración."
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
