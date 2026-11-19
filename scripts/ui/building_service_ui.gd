extends CanvasLayer
class_name BuildingServiceUI

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const MENU_LAYOUT = preload("res://scripts/ui/menu_layout.gd")
const ITEM_ICON_RESOLVER = preload("res://scripts/ui/item_icon_resolver.gd")
const BARRACKS_TRAINING_SCRIPT = preload("res://scripts/gameplay/barracks_training_session.gd")

const ITEM_MADERA := "768a51e5-e34b-4f11-92e7-a6e7dd3bf55c"
const ITEM_PIEDRA_MEDIANA := "0117d138-51ff-4b1b-a317-f8318bf161fa"
const ITEM_ESPADA_MADERA := "2eac0eb8-c33a-47ed-a7b6-dd0342d55ee8"
const ITEM_ESPADA_PIEDRA := "2655370c-2cf7-410e-8a3f-945feb3214d2"

const PRECIO_REPARACION_BRUNA := 15
const PRECIO_LICENCIA_ESPADA := 50
const PRECIO_ESPADA_MADERA := 30
const PRECIO_ESPADA_PIEDRA := 60

const CATALOGO_CARPINTERIA: Array[Dictionary] = [
	{"id":"silla", "nombre":"Silla", "madera":2, "precio":8},
	{"id":"mesa", "nombre":"Mesa", "madera":3, "precio":12},
	{"id":"cofre", "nombre":"Cofre", "madera":4, "precio":18},
	{"id":"armario", "nombre":"Armario", "madera":6, "precio":25}
]

var _tipo := ""
var _inventario: InventoryController
var _world_items: GarliaWorldItems
var _panel: PanelContainer
var _contenido: VBoxContainer
var _estado: Label
var _jugador: Node
var _jugador_fisica_previa := true
var _jugador_input_previo := true
var _jugador_unhandled_previo := true
var _herramienta_seleccionada := -1
var _bancal_seleccionado := "BancalOeste"


func configurar(tipo: String, inventario: InventoryController, world_items: GarliaWorldItems, jugador: Node = null) -> void:
	_tipo = tipo
	_inventario = inventario
	_world_items = world_items
	_jugador = jugador
	if is_instance_valid(_jugador):
		_jugador_fisica_previa = _jugador.is_physics_processing()
		_jugador_input_previo = _jugador.is_processing_input()
		_jugador_unhandled_previo = _jugador.is_processing_unhandled_input()
		_jugador.set_physics_process(false)
		_jugador.set_process_input(false)
		_jugador.set_process_unhandled_input(false)
	call_deferred("_actualizar")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	_crear_interfaz()


func _crear_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.025, 0.02, 0.015, 0.78)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(390, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centro.add_child(_panel)
	PIXEL_UI_THEME.apply(_panel, false)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 14)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 14)
	margen.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margen)

	var scroll_contenido := ScrollContainer.new()
	var alto_viewport: float = get_viewport().get_visible_rect().size.y
	scroll_contenido.custom_minimum_size = Vector2(0.0, minf(440.0, maxf(180.0, alto_viewport - 72.0)))
	scroll_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_contenido.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_contenido.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margen.add_child(scroll_contenido)

	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", 7)
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_contenido.add_child(_contenido)


func _actualizar() -> void:
	if not is_instance_valid(_contenido):
		return
	for hijo in _contenido.get_children():
		hijo.queue_free()
	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if _tipo not in ["forja", "carpinteria", "cuartel_licencia", "cuartel_armas", "cuartel_entrenamiento"]:
		var titulo := Label.new()
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.add_theme_font_size_override("font_size", 18)
		match _tipo:
			"carpinteria": titulo.text = "CARPINTERÍA"
			"vivero": titulo.text = "VIVERO"
			"herbolario_investigacion": titulo.text = "INVESTIGACIÓN BOTÁNICA"
			"herbolario_procesamiento": titulo.text = "PROCESAMIENTO BOTÁNICO"
			"herbolario": titulo.text = "HERBOLARIO"
			_: titulo.text = "EDIFICIO"
		_contenido.add_child(titulo)

	var saldo := Label.new()
	saldo.text = "%d" % GameState.obtener_dinero()
	saldo.size_flags_horizontal = Control.SIZE_SHRINK_END
	_contenido.add_child(saldo)

	match _tipo:
		"forja": _construir_forja()
		"carpinteria": _construir_carpinteria()
		"cuartel_licencia": _construir_cuartel_licencia()
		"cuartel_armas": _construir_cuartel_armas()
		"cuartel_entrenamiento": _construir_cuartel_entrenamiento()
		"vivero": _construir_vivero()
		"herbolario_investigacion": _construir_investigacion_herbolario()
		"herbolario_procesamiento": _construir_procesamiento_herbolario()
		"herbolario": _construir_investigacion_herbolario()

	_contenido.add_child(_estado)
	# Los textos informativos conservan contraste aunque el tema global cambie.
	for nodo in _contenido.find_children("*", "Label", true, false):
		var etiqueta := nodo as Label
		etiqueta.add_theme_color_override("font_color", Color("#FFF3D6"))
		etiqueta.add_theme_color_override("font_outline_color", Color("#302014"))
		etiqueta.add_theme_constant_override("outline_size", 2)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, 34)
	cerrar.pressed.connect(cerrar_interfaz)
	_contenido.add_child(cerrar)
	PIXEL_UI_THEME.apply(cerrar, false)
	call_deferred("_ajustar_menu_al_viewport")


func _ajustar_menu_al_viewport() -> void:
	if is_instance_valid(_panel) and _panel.is_inside_tree():
		MENU_LAYOUT.vigilar_panel_centrado(_panel)


func _construir_forja() -> void:
	var distribucion := HBoxContainer.new()
	distribucion.add_theme_constant_override("separation", 8)
	distribucion.custom_minimum_size = Vector2(440, 260)
	_contenido.add_child(distribucion)

	var panel_herramientas := PanelContainer.new()
	panel_herramientas.custom_minimum_size = Vector2(132, 0)
	panel_herramientas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	distribucion.add_child(panel_herramientas)
	PIXEL_UI_THEME.apply(panel_herramientas, false)

	var lista := GridContainer.new()
	lista.columns = 2
	lista.add_theme_constant_override("h_separation", 5)
	lista.add_theme_constant_override("v_separation", 5)
	panel_herramientas.add_child(lista)

	var panel_detalle := PanelContainer.new()
	panel_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	distribucion.add_child(panel_detalle)
	PIXEL_UI_THEME.apply(panel_detalle, false)

	var detalle := VBoxContainer.new()
	detalle.alignment = BoxContainer.ALIGNMENT_CENTER
	detalle.add_theme_constant_override("separation", 8)
	panel_detalle.add_child(detalle)

	if not is_instance_valid(_inventario):
		return
	var indices: Array[int] = []
	for indice in range(_inventario.runtime.state.items.size()):
		var objeto: Dictionary = _inventario.runtime.state.items[indice]
		if _es_herramienta_reparable(objeto) and _puede_reparar(indice):
			indices.append(indice)

	if indices.is_empty():
		var vacio := Label.new()
		vacio.text = "Sin herramientas dañadas"
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detalle.add_child(vacio)
		return

	if not indices.has(_herramienta_seleccionada):
		_herramienta_seleccionada = indices[0]

	for indice in indices:
		var objeto: Dictionary = _inventario.runtime.state.items[indice]
		var boton_icono := Button.new()
		boton_icono.custom_minimum_size = Vector2(52, 52)
		boton_icono.icon = ITEM_ICON_RESOLVER.obtener_icono(objeto)
		boton_icono.expand_icon = true
		boton_icono.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton_icono.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		boton_icono.toggle_mode = true
		boton_icono.button_pressed = indice == _herramienta_seleccionada
		boton_icono.pressed.connect(_seleccionar_herramienta.bind(indice))
		lista.add_child(boton_icono)
		PIXEL_UI_THEME.apply(boton_icono, false)

	var herramienta: Dictionary = _inventario.runtime.state.items[_herramienta_seleccionada]
	var propiedades: Dictionary = herramienta.get("propiedades_game", {})
	var maximo := maxi(1, int(propiedades.get("durabilidad", 1)))
	var actual := clampi(int(herramienta.get("durabilidad_actual", maximo)), 0, maximo)
	var icono := TextureRect.new()
	icono.texture = ITEM_ICON_RESOLVER.obtener_icono(herramienta)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.custom_minimum_size = Vector2(104, 104)
	detalle.add_child(icono)

	var desgaste := Label.new()
	desgaste.text = "Durabilidad · %d / %d" % [actual, maximo]
	desgaste.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detalle.add_child(desgaste)

	var barra := ProgressBar.new()
	barra.min_value = 0
	barra.max_value = maximo
	barra.value = actual
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 12)
	detalle.add_child(barra)
	PIXEL_UI_THEME.apply(barra, false)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 6)
	detalle.add_child(acciones)

	var material_id := _material_reparacion(herramienta)
	var boton_yunque := Button.new()
	boton_yunque.text = "Yunque"
	boton_yunque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_yunque.disabled = material_id.is_empty() or _contar_item(material_id) < 1
	boton_yunque.pressed.connect(_reparar_con_material.bind(_herramienta_seleccionada, material_id))
	acciones.add_child(boton_yunque)
	PIXEL_UI_THEME.apply(boton_yunque, false)

	var boton_bruna := Button.new()
	boton_bruna.text = "Bruna · %d" % PRECIO_REPARACION_BRUNA
	boton_bruna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_bruna.disabled = GameState.obtener_dinero() < PRECIO_REPARACION_BRUNA
	boton_bruna.pressed.connect(_reparar_con_bruna.bind(_herramienta_seleccionada))
	acciones.add_child(boton_bruna)
	PIXEL_UI_THEME.apply(boton_bruna, false)


func _seleccionar_herramienta(indice: int) -> void:
	_herramienta_seleccionada = indice
	_actualizar()


func _es_herramienta_reparable(objeto: Dictionary) -> bool:
	if objeto.is_empty():
		return false
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if not propiedades_variant is Dictionary:
		return false
	var propiedades := propiedades_variant as Dictionary
	var maximo := int(propiedades.get("durabilidad", 0))
	var recoleccion_variant: Variant = propiedades.get("recoleccion", {})
	var tiene_recoleccion := recoleccion_variant is Dictionary and not (recoleccion_variant as Dictionary).is_empty()
	var nombre := str(objeto.get("nombre", "")).to_lower()
	var tipo := str(objeto.get("tipo", "")).to_lower()
	return maximo > 0 and (tipo.contains("herramienta") or tiene_recoleccion or nombre.contains("pico") or nombre.contains("pala"))


func _material_reparacion(objeto: Dictionary) -> String:
	var nombre := str(objeto.get("nombre", "")).to_lower()
	if nombre.contains("madera"):
		return ITEM_MADERA
	if nombre.contains("piedra"):
		return ITEM_PIEDRA_MEDIANA
	return ""


func _reparar_con_material(indice: int, material_id: String) -> void:
	if not is_instance_valid(_inventario) or material_id.is_empty() or not _puede_reparar(indice):
		_mostrar_estado("La herramienta ya no necesita reparación o no es válida.")
		_actualizar()
		return
	var slot_material := _buscar_slot_item(material_id)
	if slot_material < 0:
		_mostrar_estado("No tienes el material necesario.")
		_actualizar()
		return
	var material_antes := _inventario.obtener_item(slot_material).duplicate(true)
	if not _inventario.quitar_cantidad_desde_ui(slot_material, 1):
		_mostrar_estado("No se pudo entregar el material.")
		return
	if not _reparar_herramienta(indice):
		var devolver := material_antes.duplicate(true)
		devolver["cantidad"] = 1
		if not _inventario.agregar_objeto_desde_ui(devolver):
			push_error("Forja: no se pudo devolver el material tras una reparación fallida.")
		_mostrar_estado("No se pudo reparar; se intentó devolver el material.")
		_actualizar()
		return
	_guardar_reparacion()
	_mostrar_estado("Herramienta reparada por completo en el yunque.")
	_actualizar()


func _reparar_con_bruna(indice: int) -> void:
	if not _puede_reparar(indice):
		_mostrar_estado("La herramienta ya no necesita reparación o no es válida.")
		_actualizar()
		return
	if not GameState.modificar_dinero(-PRECIO_REPARACION_BRUNA):
		_mostrar_estado("No tienes suficientes monedas.")
		return
	if not _reparar_herramienta(indice):
		GameState.modificar_dinero(PRECIO_REPARACION_BRUNA)
		_mostrar_estado("No se pudo reparar; se revirtió el cobro.")
		_actualizar()
		return
	_guardar_reparacion()
	_mostrar_estado("Bruna reparó tu herramienta por completo.")
	_actualizar()


func _puede_reparar(indice: int) -> bool:
	if not is_instance_valid(_inventario) or indice < 0 or indice >= _inventario.runtime.state.items.size():
		return false
	var objeto: Dictionary = _inventario.runtime.state.items[indice]
	if not _es_herramienta_reparable(objeto):
		return false
	var propiedades: Dictionary = objeto.get("propiedades_game", {})
	var maximo := int(propiedades.get("durabilidad", 0))
	return int(objeto.get("durabilidad_actual", maximo)) < maximo


func _reparar_herramienta(indice: int) -> bool:
	if not _puede_reparar(indice):
		return false
	var objeto: Dictionary = _inventario.runtime.state.items[indice].duplicate(true)
	var propiedades: Dictionary = objeto.get("propiedades_game", {})
	objeto["durabilidad_actual"] = int(propiedades.get("durabilidad", 0))
	_inventario.runtime.state.items[indice] = objeto
	_inventario.inventario_cambio.emit()
	return true


func _guardar_reparacion() -> void:
	# El inventario forma parte del estado local de la partida; el guardado rápido
	# evita depender únicamente del siguiente ciclo de autoguardado.
	GameState.call_deferred("_ejecutar_guardado_rapido")


func _construir_carpinteria() -> void:
	_agregar_texto("Entrega madera y monedas para recibir el mueble directamente en tu inventario.")
	for mueble in CATALOGO_CARPINTERIA:
		var tarjeta := PanelContainer.new()
		tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fondo := PIXEL_UI_THEME.button_surface_style()
		if fondo != null:
			tarjeta.add_theme_stylebox_override("panel", fondo)
		_contenido.add_child(tarjeta)

		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		tarjeta.add_child(fila)

		var icono := TextureRect.new()
		icono.texture = ITEM_ICON_RESOLVER.obtener_icono({"nombre": str(mueble.nombre)})
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.custom_minimum_size = Vector2(54, 54)
		fila.add_child(icono)

		var etiqueta := Label.new()
		etiqueta.text = "%s\n%d madera · %d monedas\nEn inventario: %d" % [
			str(mueble.nombre), int(mueble.madera), int(mueble.precio),
			_contar_item("carpinteria_mueble_" + str(mueble.id))
		]
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		etiqueta.add_theme_color_override("font_color", Color("#FFF3D6"))
		etiqueta.add_theme_color_override("font_outline_color", Color("#302014"))
		etiqueta.add_theme_constant_override("outline_size", 2)
		fila.add_child(etiqueta)

		var boton := Button.new()
		boton.text = "Encargar"
		boton.custom_minimum_size = Vector2(82, 38)
		boton.disabled = not is_instance_valid(_inventario) or _contar_item(ITEM_MADERA) < int(mueble.madera) or GameState.obtener_dinero() < int(mueble.precio)
		boton.pressed.connect(_encargar_mueble.bind(str(mueble.id)))
		fila.add_child(boton)
		PIXEL_UI_THEME.apply(boton, false)


func _encargar_mueble(mueble_id: String) -> void:
	var definicion: Dictionary = {}
	for mueble in CATALOGO_CARPINTERIA:
		if str(mueble.id) == mueble_id:
			definicion = mueble
			break
	if definicion.is_empty() or not is_instance_valid(_inventario):
		return
	var madera := int(definicion.get("madera", 0))
	var precio := int(definicion.get("precio", 0))
	var item_id := "carpinteria_mueble_" + mueble_id
	if madera <= 0 or precio < 0 or _contar_item(ITEM_MADERA) < madera or GameState.obtener_dinero() < precio:
		_mostrar_estado("Te faltan madera o monedas.")
		return

	# Primero se entrega el mueble; si no cabe, no se cobra ni se consume material.
	var mueble_item := {
		"id": item_id,
		"item_id": item_id,
		"nombre": str(definicion.get("nombre", "Mueble")),
		"descripcion": "Mueble fabricado por encargo en la Carpintería de Torres.",
		"tipo": "mueble",
		"categoria_clave": "muebles",
		"cantidad": 1,
		"max_stack": 1,
		"propiedades_game": {"origen": "carpinteria", "mueble_id": mueble_id}
	}
	if not _inventario.agregar_objeto_desde_ui(mueble_item):
		_mostrar_estado("No tienes espacio en el inventario. No se cobró el encargo.")
		return

	if not GameState.modificar_dinero(-precio):
		var slot_entregado := _buscar_slot_item(item_id)
		if slot_entregado >= 0:
			_inventario.quitar_cantidad_desde_ui(slot_entregado, 1)
		_mostrar_estado("No se pudo cobrar el encargo; el mueble fue retirado.")
		return

	if not _consumir_item_total(ITEM_MADERA, madera):
		GameState.modificar_dinero(precio)
		var slot_entregado := _buscar_slot_item(item_id)
		if slot_entregado >= 0:
			_inventario.quitar_cantidad_desde_ui(slot_entregado, 1)
		_mostrar_estado("No se pudo consumir la madera; se revirtió el pago.")
		return

	GameState.call_deferred("_ejecutar_guardado_rapido")
	_mostrar_estado("Recibiste %s en tu inventario." % str(definicion.get("nombre", "el mueble")))
	_actualizar()



func _construir_vivero() -> void:
	_panel.custom_minimum_size = Vector2(590, 0)
	_agregar_texto("CUIDADO DE CULTIVOS")
	_agregar_texto("Selecciona un bancal para revisar su cultivo, humedad y cuidados.")
	var nombres := ["BancalOeste", "BancalCentro", "BancalEste", "BancalSurOeste", "BancalSurCentro"]
	var layout := MENU_LAYOUT.crear_selector_dos_paneles(_contenido, 184.0, 268.0, 9)
	var lista := layout["list_content"] as GridContainer
	var panel_lista := layout["list_panel"] as PanelContainer
	var panel_detalle := layout["detail_panel"] as PanelContainer
	var detalle := layout["detail_content"] as VBoxContainer
	PIXEL_UI_THEME.apply(panel_lista, false)
	PIXEL_UI_THEME.apply(panel_detalle, false)

	var estados_variant: Variant = GameState.world_state.flags.get("vivero_bancales", {})
	var estados: Dictionary = estados_variant if estados_variant is Dictionary else {}
	var regadera := _obtener_regadera_en_manos()
	var agua := int(regadera.get("agua", -1))
	var cantidad_ocupados := 0
	var grupo_bancales := ButtonGroup.new()
	for nombre in nombres:
		var registro: Variant = estados.get(nombre, {})
		var cultivo: Dictionary = registro if registro is Dictionary else {}
		if not cultivo.is_empty() and str(cultivo.get("nombre", "")).strip_edges() != "":
			cantidad_ocupados += 1
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(52, 52)
		boton.toggle_mode = true
		boton.button_group = grupo_bancales
		boton.button_pressed = nombre == _bancal_seleccionado
		boton.text = str(nombres.find(nombre) + 1)
		boton.tooltip_text = nombre.replace("Bancal", "Bancal ")
		boton.pressed.connect(_seleccionar_bancal_vivero.bind(nombre, detalle))
		lista.add_child(boton)
		PIXEL_UI_THEME.apply(boton, false)

	if not nombres.has(_bancal_seleccionado):
		_bancal_seleccionado = nombres[0]
	_mostrar_detalle_bancal_vivero(_bancal_seleccionado, detalle)

	var pie := Label.new()
	pie.text = "%d / %d bancales ocupados  ·  Regadera: %s" % [
		cantidad_ocupados, nombres.size(),
		("Agua %d/4" % agua) if agua >= 0 else "no equipada"
	]
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(pie)

	var actualizar := Button.new()
	actualizar.text = "Actualizar estado"
	actualizar.custom_minimum_size = Vector2(0, 34)
	actualizar.pressed.connect(_actualizar)
	_contenido.add_child(actualizar)
	PIXEL_UI_THEME.apply(actualizar, false)


func _seleccionar_bancal_vivero(nombre: String, detalle: VBoxContainer) -> void:
	_bancal_seleccionado = nombre
	_mostrar_detalle_bancal_vivero(nombre, detalle)


func _mostrar_detalle_bancal_vivero(nombre: String, detalle: VBoxContainer) -> void:
	for hijo in detalle.get_children():
		hijo.queue_free()
	var estados_variant: Variant = GameState.world_state.flags.get("vivero_bancales", {})
	var estados: Dictionary = estados_variant if estados_variant is Dictionary else {}
	var registro: Variant = estados.get(nombre, {})
	var cultivo: Dictionary = registro if registro is Dictionary else {}
	var ocupado := not cultivo.is_empty() and str(cultivo.get("nombre", "")).strip_edges() != ""
	var humedo := bool(cultivo.get("humedo", false)) if not cultivo.is_empty() else bool(registro)

	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(0, 104)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ocupado:
		var ruta_sprite := str(cultivo.get("sprite", ""))
		if not ruta_sprite.is_empty() and ResourceLoader.exists(ruta_sprite):
			icono.texture = load(ruta_sprite) as Texture2D
		if icono.texture == null:
			var item_id := str(cultivo.get("item_cosecha_id", cultivo.get("semilla_item_id", "")))
			var objeto: Dictionary = _world_items.buscar_item_por_id(item_id) if is_instance_valid(_world_items) and not item_id.is_empty() else {}
			if objeto.is_empty():
				objeto = {"nombre": str(cultivo.get("nombre", ""))}
			icono.texture = ITEM_ICON_RESOLVER.obtener_icono(objeto)
	detalle.add_child(icono)

	var titulo := Label.new()
	titulo.text = nombre.replace("Bancal", "BANCAL ")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 17)
	detalle.add_child(titulo)

	var estado := Label.new()
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if ocupado:
		var nombre_cultivo := str(cultivo.get("nombre", "Cultivo"))
		estado.text = "%s\n%s\nRiegos: %d / 2" % [
			nombre_cultivo,
			("Suelo húmedo" if humedo else "Necesita agua"),
			int(cultivo.get("riegos", 0))
		]
	else:
		estado.text = "Bancal vacío\nPrepara una semilla desde el inventario y úsala junto a este bancal."
	detalle.add_child(estado)

	var separador := HSeparator.new()
	detalle.add_child(separador)
	var cuidados := Label.new()
	cuidados.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuidados.text = "CUIDADOS\n• Planta una semilla desde el inventario.\n• Equipa la regadera y riega una vez por día.\n• Cuando madure, recoge la flor directamente."
	if ocupado and humedo:
		cuidados.text += "\n\nEl suelo conserva humedad."
	detalle.add_child(cuidados)

	var regadera := _obtener_regadera_en_manos()
	var agua := int(regadera.get("agua", -1))
	var herramienta := Label.new()
	herramienta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	herramienta.text = ("Regadera equipada · Agua %d/4" % agua) if agua >= 0 else "Equipa una regadera para cuidar tus cultivos."
	detalle.add_child(herramienta)


func _obtener_regadera_en_manos() -> Dictionary:
	if not is_instance_valid(_inventario):
		return {}
	for mano in ["izquierda", "derecha"]:
		var indice := _inventario.obtener_indice_mano_activa(mano)
		var objeto := _inventario.obtener_item(indice)
		if objeto.is_empty():
			continue
		var nombre := str(objeto.get("nombre", "")).to_lower()
		var propiedades_variant: Variant = objeto.get("propiedades_game", {})
		var propiedades: Dictionary = propiedades_variant if propiedades_variant is Dictionary else {}
		var herramienta_variant: Variant = propiedades.get("herramienta_recoleccion", {})
		var herramienta: Dictionary = herramienta_variant if herramienta_variant is Dictionary else {}
		if nombre.contains("regadera") or str(herramienta.get("tipo", "")).to_lower() == "regadera":
			var estado_variant: Variant = propiedades.get("regadera", {})
			var estado: Dictionary = estado_variant if estado_variant is Dictionary else {}
			return {"agua": int(estado.get("agua", estado.get("agua_inicial", 4)))}
	return {}



func _construir_investigacion_herbolario() -> void:
	_panel.custom_minimum_size = Vector2(540, 0)
	_agregar_texto("EXAMEN DE MUESTRAS")
	_agregar_texto("Selecciona una muestra para consultar sus datos. La investigación no consume materiales.")
	var layout := MENU_LAYOUT.crear_selector_dos_paneles(_contenido, 164.0, 220.0, 8)
	var lista := layout["list_content"] as GridContainer
	var panel_lista := layout["list_panel"] as PanelContainer
	var panel_detalle := layout["detail_panel"] as PanelContainer
	var detalle := layout["detail_content"] as VBoxContainer
	PIXEL_UI_THEME.apply(panel_lista, false)
	PIXEL_UI_THEME.apply(panel_detalle, false)

	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(0, 88)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detalle.add_child(icono)
	var nombre_label := Label.new()
	nombre_label.text = "Selecciona una muestra"
	nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(nombre_label)
	var descripcion := Label.new()
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descripcion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detalle.add_child(descripcion)
	var estado := Label.new()
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(estado)

	var cantidad := 0
	if is_instance_valid(_inventario):
		for indice in range(_inventario.runtime.state.items.size()):
			var objeto: Dictionary = _inventario.runtime.state.items[indice]
			if objeto.is_empty() or not _es_muestra_botanica(objeto):
				continue
			cantidad += 1
			var boton := MENU_LAYOUT.crear_boton_sprite(ITEM_ICON_RESOLVER.obtener_icono(objeto))
			PIXEL_UI_THEME.apply(boton, false)
			MENU_LAYOUT.agregar_cantidad(boton, maxi(1, int(objeto.get("cantidad", 1))))
			boton.pressed.connect(_seleccionar_muestra_herbolario.bind(objeto.duplicate(true), icono, nombre_label, descripcion, estado))
			lista.add_child(boton)
	if cantidad == 0:
		var vacio := Label.new()
		vacio.text = "No llevas muestras botánicas para estudiar."
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lista.add_child(vacio)
	_agregar_texto("Los descubrimientos se consultan aquí; las muestras permanecen en tu inventario.")

func _seleccionar_muestra_herbolario(objeto: Dictionary, icono: TextureRect, nombre: Label, descripcion: Label, estado: Label) -> void:
	icono.texture = ITEM_ICON_RESOLVER.obtener_icono(objeto)
	nombre.text = str(objeto.get("nombre", "Muestra"))
	descripcion.text = str(objeto.get("descripcion", "Sin descripción registrada."))
	var categoria_variant: Variant = objeto.get("categoria", {})
	var categoria := str(objeto.get("categoria_clave", ""))
	if categoria_variant is Dictionary:
		categoria = str((categoria_variant as Dictionary).get("nombre", categoria))
	if not categoria.is_empty():
		descripcion.text += "\n\nCategoría: " + categoria
	estado.text = "Muestra examinada · No se ha consumido."


func _construir_procesamiento_herbolario() -> void:
	_panel.custom_minimum_size = Vector2(540, 0)
	_agregar_texto("SELECCIÓN DE MATERIAL")
	_agregar_texto("Elige un material para consultar sus procesos disponibles.")
	if not is_instance_valid(_world_items):
		_agregar_texto("No se pudo acceder al catálogo compartido.")
		return
	if not _world_items.recetas_disponibles:
		_agregar_texto("Las recetas todavía se están cargando. Cierra y vuelve a abrir esta mesa en unos momentos.")
		if not _world_items.recetas_cargadas.is_connected(_al_recetas_herbolario_cargadas):
			_world_items.recetas_cargadas.connect(_al_recetas_herbolario_cargadas, CONNECT_ONE_SHOT)
		return

	var layout := MENU_LAYOUT.crear_selector_dos_paneles(_contenido, 180.0, 260.0, 10)
	var lista := layout["list_content"] as GridContainer
	var panel_lista := layout["list_panel"] as PanelContainer
	var panel_detalle := layout["detail_panel"] as PanelContainer
	var detalle := layout["detail_content"] as VBoxContainer
	PIXEL_UI_THEME.apply(panel_lista, false)
	PIXEL_UI_THEME.apply(panel_detalle, false)

	var vistos: Dictionary = {}
	var seleccion_inicial: Dictionary = {}
	var id_inicial := ""
	if is_instance_valid(_inventario):
		for objeto_variant in _inventario.runtime.state.items:
			if not objeto_variant is Dictionary:
				continue
			var objeto := objeto_variant as Dictionary
			if objeto.is_empty() or not _es_muestra_botanica(objeto):
				continue
			var item_id := str(objeto.get("item_id", objeto.get("id", "")))
			if item_id.is_empty() or vistos.has(item_id):
				continue
			var item_catalogo := _world_items.buscar_item_por_id(item_id)
			if item_catalogo.is_empty():
				continue
			vistos[item_id] = true
			if seleccion_inicial.is_empty():
				seleccion_inicial = item_catalogo
				id_inicial = item_id
			var boton := MENU_LAYOUT.crear_boton_sprite(ITEM_ICON_RESOLVER.obtener_icono(item_catalogo))
			PIXEL_UI_THEME.apply(boton, false)
			MENU_LAYOUT.agregar_cantidad(boton, _contar_item(item_id))
			boton.pressed.connect(_mostrar_procesos_item_herbolario.bind(item_id, item_catalogo, detalle))
			lista.add_child(boton)

	if vistos.is_empty():
		var vacio := Label.new()
		vacio.text = "No tienes materiales botánicos."
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lista.add_child(vacio)
		var instruccion := Label.new()
		instruccion.text = "Consigue flores, hojas, semillas o hierbas para consultar sus procesos."
		instruccion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detalle.add_child(instruccion)
	else:
		_mostrar_procesos_item_herbolario(id_inicial, seleccion_inicial, detalle)

func _mostrar_procesos_item_herbolario(item_id: String, item: Dictionary, detalle: VBoxContainer) -> void:
	for hijo in detalle.get_children():
		hijo.queue_free()
	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(0, 88)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture = ITEM_ICON_RESOLVER.obtener_icono(item)
	detalle.add_child(icono)
	var nombre := Label.new()
	nombre.text = str(item.get("nombre", "Material"))
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(nombre)
	var descripcion := Label.new()
	descripcion.text = str(item.get("descripcion", ""))
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_child(descripcion)
	var cantidad := Label.new()
	cantidad.text = "En inventario: %d" % _contar_item(item_id)
	detalle.add_child(cantidad)
	var titulo_procesos := Label.new()
	titulo_procesos.text = "PROCESOS DISPONIBLES"
	detalle.add_child(titulo_procesos)
	var procesos := 0
	for receta in _world_items.obtener_recetas():
		if not _receta_es_botanica(receta) or not _receta_usa_item(receta, item_id):
			continue
		procesos += 1
		_agregar_tarjeta_receta_herbolario(receta, detalle)
	if procesos == 0:
		var sin_procesos := Label.new()
		sin_procesos.text = "No hay procesos registrados para este material."
		sin_procesos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detalle.add_child(sin_procesos)


func _receta_usa_item(receta: Dictionary, item_id: String) -> bool:
	var ingredientes_variant: Variant = receta.get("ingredientes", [])
	if not ingredientes_variant is Array:
		return false
	for ingrediente_variant in ingredientes_variant as Array:
		if ingrediente_variant is Dictionary and str((ingrediente_variant as Dictionary).get("item_id", "")) == item_id:
			return true
	return false


func _al_recetas_herbolario_cargadas(_recetas: Array) -> void:
	if is_inside_tree() and _tipo == "herbolario_procesamiento":
		_actualizar()

func _receta_es_botanica(receta: Dictionary) -> bool:
	var categoria := str(receta.get("categoria", "")).to_lower()
	if categoria.contains("botan") or categoria.contains("herbol"):
		return true
	var ingredientes_variant: Variant = receta.get("ingredientes", [])
	if ingredientes_variant is Array:
		for ingrediente_variant in ingredientes_variant as Array:
			if not ingrediente_variant is Dictionary:
				continue
			var ingrediente := ingrediente_variant as Dictionary
			var item := _world_items.buscar_item_por_id(str(ingrediente.get("item_id", "")))
			if not item.is_empty() and _es_muestra_botanica(item):
				return true
	var resultado_variant: Variant = receta.get("resultado", {})
	if resultado_variant is Dictionary:
		var resultado := _world_items.buscar_item_por_id(str((resultado_variant as Dictionary).get("item_id", "")))
		if not resultado.is_empty() and _es_muestra_botanica(resultado):
			return true
	return false


func _agregar_tarjeta_receta_herbolario(receta: Dictionary, contenedor: VBoxContainer) -> void:
	var tarjeta := PanelContainer.new()
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor.add_child(tarjeta)
	PIXEL_UI_THEME.apply(tarjeta, false)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 4)
	tarjeta.add_child(columna)
	var resultado_variant: Variant = receta.get("resultado", {})
	var resultado: Dictionary = resultado_variant as Dictionary if resultado_variant is Dictionary else {}
	var item_resultado := _world_items.buscar_item_por_id(str(resultado.get("item_id", "")))
	var nombre_resultado := str(item_resultado.get("nombre", resultado.get("nombre", receta.get("nombre", "Producto"))))
	var encabezado := Label.new()
	encabezado.text = str(receta.get("nombre", nombre_resultado))
	encabezado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(encabezado)
	var detalles := Label.new()
	detalles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lineas: Array[String] = []
	var ingredientes_variant: Variant = receta.get("ingredientes", [])
	var suficientes := ingredientes_variant is Array and not (ingredientes_variant as Array).is_empty()
	var tiene_iconos := suficientes
	if suficientes:
		for ingrediente_variant in ingredientes_variant as Array:
			if not ingrediente_variant is Dictionary:
				tiene_iconos = false
				suficientes = false
				continue
			var ingrediente := ingrediente_variant as Dictionary
			var ingrediente_id := str(ingrediente.get("item_id", ""))
			var requerido := maxi(1, int(ingrediente.get("cantidad", 1)))
			var item_ingrediente := _world_items.buscar_item_por_id(ingrediente_id)
			var disponible := _contar_item(ingrediente_id)
			lineas.append("%s · %d/%d" % [str(item_ingrediente.get("nombre", "Material desconocido")), disponible, requerido])
			if item_ingrediente.is_empty() or not ITEM_ICON_RESOLVER.tiene_icono(item_ingrediente):
				tiene_iconos = false
			if disponible < requerido:
				suficientes = false
	else:
		lineas.append("Ingredientes no definidos.")
	detalles.text = "Resultado: %s\n%s" % [nombre_resultado, "\n".join(lineas)]
	columna.add_child(detalles)
	var boton := Button.new()
	boton.text = "Procesar"
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.disabled = not suficientes or not tiene_iconos or item_resultado.is_empty() or not ITEM_ICON_RESOLVER.tiene_icono(item_resultado)
	boton.pressed.connect(_procesar_receta_herbolario.bind(receta.duplicate(true)))
	columna.add_child(boton)
	PIXEL_UI_THEME.apply(boton, false)


func _procesar_receta_herbolario(receta: Dictionary) -> void:
	if not is_instance_valid(_inventario) or not is_instance_valid(_world_items):
		_mostrar_estado("No se pudo acceder al inventario o al catálogo.")
		return
	if not _receta_es_botanica(receta):
		_mostrar_estado("Esta receta no pertenece al procesamiento botánico.")
		_actualizar()
		return
	var ingredientes_variant: Variant = receta.get("ingredientes", [])
	if not ingredientes_variant is Array or (ingredientes_variant as Array).is_empty():
		_mostrar_estado("La receta no tiene ingredientes definidos.")
		return
	for ingrediente_variant in ingredientes_variant as Array:
		if not ingrediente_variant is Dictionary:
			_mostrar_estado("La receta contiene un ingrediente inválido.")
			return
		var ingrediente := ingrediente_variant as Dictionary
		var item_id := str(ingrediente.get("item_id", ""))
		if item_id.is_empty() or _contar_item(item_id) < maxi(1, int(ingrediente.get("cantidad", 1))):
			_mostrar_estado("Faltan materiales para procesar esta receta.")
			return
		var item := _world_items.buscar_item_por_id(item_id)
		if item.is_empty() or not ITEM_ICON_RESOLVER.tiene_icono(item):
			_mostrar_estado("Falta un objeto o sprite de ingrediente en el catálogo.")
			return
	var resultado_variant: Variant = receta.get("resultado", {})
	if not resultado_variant is Dictionary:
		_mostrar_estado("La receta no define un resultado válido.")
		return
	var resultado := resultado_variant as Dictionary
	var output_id := str(resultado.get("item_id", ""))
	var output_cantidad := maxi(1, int(resultado.get("cantidad", 1)))
	var objeto_resultado := _world_items.buscar_item_por_id(output_id)
	if objeto_resultado.is_empty() or not ITEM_ICON_RESOLVER.tiene_icono(objeto_resultado):
		_mostrar_estado("El producto no está disponible o todavía no tiene sprite.")
		return
	objeto_resultado["cantidad"] = output_cantidad
	objeto_resultado["max_stack"] = maxi(1, int(objeto_resultado.get("max_stack", 1)))
	if not _inventario.agregar_objeto_desde_ui(objeto_resultado):
		_mostrar_estado("No hay espacio para el producto. No se consumieron materiales.")
		return
	for ingrediente_variant in ingredientes_variant as Array:
		var ingrediente := ingrediente_variant as Dictionary
		var item_id := str(ingrediente.get("item_id", ""))
		var restante := maxi(1, int(ingrediente.get("cantidad", 1)))
		for indice in range(_inventario.runtime.state.items.size()):
			if restante <= 0:
				break
			var objeto: Dictionary = _inventario.runtime.state.items[indice]
			if objeto.is_empty() or str(objeto.get("item_id", objeto.get("id", ""))) != item_id:
				continue
			var disponible := maxi(1, int(objeto.get("cantidad", 1)))
			var retirar := mini(restante, disponible)
			if _inventario.quitar_cantidad_desde_ui(indice, retirar):
				restante -= retirar
		if restante > 0:
			push_error("Herbolario: no se pudieron consumir todos los ingredientes de una receta validada.")
			_mostrar_estado("No se pudo completar el procesamiento. Revisa el inventario.")
			_actualizar()
			return
	GameState.call_deferred("_ejecutar_guardado_rapido")
	var nombre_producto := str(objeto_resultado.get("nombre", "producto"))
	_mostrar_estado("Procesaste la muestra y obtuviste: " + nombre_producto + ".")
	_actualizar()


func _es_muestra_botanica(objeto: Dictionary) -> bool:
	var identidad := (str(objeto.get("nombre", "")) + " " + str(objeto.get("categoria_clave", ""))).to_lower()
	for termino in ["flor", "planta", "hoja", "hierba", "semilla", "raiz", "raíz", "botan"]:
		if identidad.contains(termino):
			return true
	return false

func _construir_cuartel_licencia() -> void:
	var licencia := bool(GameState.world_state.flags.get("licencia_espadas", false))
	if licencia:
		_agregar_texto("Tu licencia de espadas ya está concedida.")
		return
	_agregar_texto("Solicita aquí la licencia necesaria para portar y comprar espadas.")
	var solicitar := Button.new()
	solicitar.text = "Solicitar licencia · %d monedas" % PRECIO_LICENCIA_ESPADA
	solicitar.disabled = GameState.obtener_dinero() < PRECIO_LICENCIA_ESPADA
	solicitar.pressed.connect(_solicitar_licencia)
	_contenido.add_child(solicitar)
	PIXEL_UI_THEME.apply(solicitar, false)


func _construir_cuartel_armas() -> void:
	if not bool(GameState.world_state.flags.get("licencia_espadas", false)):
		_agregar_texto("Necesitas obtener primero tu licencia en la mesa de solicitudes.")
		return
	_agregar_texto("Licencia verificada. Puedes adquirir estas armas:")
	_agregar_boton_arma("Espada de Madera", ITEM_ESPADA_MADERA, PRECIO_ESPADA_MADERA)
	_agregar_boton_arma("Espada de Piedra", ITEM_ESPADA_PIEDRA, PRECIO_ESPADA_PIEDRA)


func _construir_cuartel_entrenamiento() -> void:
	if not is_instance_valid(_jugador):
		_agregar_texto("No se encontró al jugador.")
		return
	var candidatos: Array[Creature] = []
	for nodo in get_tree().get_nodes_in_group("creatures"):
		if not nodo is Creature or not is_instance_valid(nodo):
			continue
		var candidato := nodo as Creature
		if candidato == _jugador or not candidato.is_alive or candidato.is_in_group("garumis"):
			continue
		if candidato.get_meta("barracks_training_target", false):
			continue
		candidatos.append(candidato)
	candidatos.sort_custom(func(a: Creature, b: Creature) -> bool:
		return _nombre_entrenamiento(a).to_lower() < _nombre_entrenamiento(b).to_lower()
	)
	if candidatos.is_empty():
		_agregar_texto("No hay criaturas ni aldeanos disponibles en esta zona. Vuelve cuando haya alguien cerca.")
		return
	for candidato in candidatos:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		_contenido.add_child(fila)
		var etiqueta := Label.new()
		etiqueta.text = _nombre_entrenamiento(candidato)
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)
		var boton := Button.new()
		boton.text = "Entrenar"
		boton.pressed.connect(_iniciar_entrenamiento.bind(candidato))
		fila.add_child(boton)
		PIXEL_UI_THEME.apply(boton, false)


func _nombre_entrenamiento(candidato: Creature) -> String:
	var nombre := str(candidato.get("nombre_individual")).strip_edges()
	if nombre.is_empty():
		nombre = str(candidato.get("criatura_nombre")).strip_edges()
	if nombre.is_empty():
		nombre = str(candidato.name)
	return nombre


func _iniciar_entrenamiento(candidato: Creature) -> void:
	if not is_instance_valid(candidato) or not candidato.is_alive or not is_instance_valid(_jugador):
		_mostrar_estado("Ese contrincante ya no está disponible.")
		return
	if get_tree().get_first_node_in_group("barracks_training_session") != null:
		_mostrar_estado("Ya hay un entrenamiento en curso.")
		return
	var sesion := BARRACKS_TRAINING_SCRIPT.new() as CanvasLayer
	if not is_instance_valid(sesion):
		_mostrar_estado("No se pudo iniciar el entrenamiento.")
		return
	get_tree().root.add_child(sesion)
	if not bool(sesion.call("iniciar", _jugador, candidato)):
		sesion.queue_free()
		_mostrar_estado("No se pudo preparar el contrincante.")
		return
	cerrar_interfaz()


func _solicitar_licencia() -> void:
	if not GameState.modificar_dinero(-PRECIO_LICENCIA_ESPADA):
		_mostrar_estado("No tienes suficientes monedas.")
		return
	GameState.world_state.flags["licencia_espadas"] = true
	GameState.call_deferred("_ejecutar_guardado_rapido")
	_mostrar_estado("Licencia de espadas concedida y guardada en esta partida.")
	_actualizar()


func _agregar_boton_arma(nombre: String, item_id: String, precio: int) -> void:
	var fila := HBoxContainer.new()
	_contenido.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = "%s · %d monedas" % [nombre, precio]
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	var boton := Button.new()
	boton.text = "Comprar"
	boton.disabled = GameState.obtener_dinero() < precio or not is_instance_valid(_world_items)
	boton.pressed.connect(_comprar_arma.bind(item_id, precio))
	fila.add_child(boton)
	PIXEL_UI_THEME.apply(boton, false)


func _comprar_arma(item_id: String, precio: int) -> void:
	if not bool(GameState.world_state.flags.get("licencia_espadas", false)) or not is_instance_valid(_world_items) or not is_instance_valid(_inventario):
		return
	var objeto := _world_items.buscar_item_por_id(item_id)
	if objeto.is_empty():
		_mostrar_estado("El arma no está disponible en el catálogo.")
		return
	if not GameState.modificar_dinero(-precio):
		_mostrar_estado("No tienes suficientes monedas.")
		return
	objeto["cantidad"] = 1
	if not _inventario.agregar_objeto_desde_ui(objeto):
		GameState.modificar_dinero(precio)
		_mostrar_estado("No tienes espacio en el inventario. Se revirtió el pago.")
		return
	# La compra modifica inventario y dinero de la partida local.
	# Guardamos ambos inmediatamente para que el arma no se pierda al salir.
	GameState.call_deferred("_ejecutar_guardado_rapido")
	_mostrar_estado("Compraste %s." % str(objeto.get("nombre", "el arma")))
	_actualizar()


func _contar_item(item_id: String) -> int:
	if not is_instance_valid(_inventario):
		return 0
	var total := 0
	for objeto_variant in _inventario.runtime.state.items:
		if not objeto_variant is Dictionary:
			continue
		var objeto := objeto_variant as Dictionary
		if str(objeto.get("item_id", objeto.get("id", ""))) == item_id:
			total += int(objeto.get("cantidad", 1))
	return total


func _consumir_item_total(item_id: String, cantidad: int) -> bool:
	if not is_instance_valid(_inventario) or cantidad <= 0 or _contar_item(item_id) < cantidad:
		return false
	var restante := cantidad
	for indice in range(_inventario.runtime.state.items.size()):
		if restante <= 0:
			break
		var objeto: Dictionary = _inventario.runtime.state.items[indice]
		if str(objeto.get("item_id", objeto.get("id", ""))) != item_id or objeto.is_empty():
			continue
		var disponible := maxi(1, int(objeto.get("cantidad", 1)))
		var retirar := mini(restante, disponible)
		if not _inventario.quitar_cantidad_desde_ui(indice, retirar):
			return false
		restante -= retirar
	return restante == 0


func _buscar_slot_item(item_id: String) -> int:
	if not is_instance_valid(_inventario):
		return -1
	for indice in range(_inventario.runtime.state.items.size()):
		var objeto: Dictionary = _inventario.runtime.state.items[indice]
		if str(objeto.get("item_id", objeto.get("id", ""))) == item_id and not objeto.is_empty():
			return indice
	return -1


func _agregar_texto(texto: String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(etiqueta)


func _mostrar_estado(texto: String) -> void:
	if is_instance_valid(_estado):
		_estado.text = texto
		Events.notification_pushed.emit(texto)


func cerrar_interfaz() -> void:
	if is_instance_valid(_jugador):
		_jugador.set_physics_process(_jugador_fisica_previa)
		_jugador.set_process_input(_jugador_input_previo)
		_jugador.set_process_unhandled_input(_jugador_unhandled_previo)
	if is_in_group("modal_ui"):
		remove_from_group("modal_ui")
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cerrar_interfaz()
		get_viewport().set_input_as_handled()
