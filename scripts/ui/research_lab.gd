extends CanvasLayer
## Interfaz de trabajo del laboratorio. Las pruebas no consumen objetos hasta que
## exista una reacción definida y confirmada para sus materiales.

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

const PROCEDIMIENTOS_POR_ESTACION: Dictionary = {
	"examen": ["Examinar", "Medir", "Comparar"],
	"mezclas": ["Mezclar", "Disolver"],
	"termica": ["Calentar", "Enfriar", "Fundir"],
	"observacion": ["Observar estructura", "Comparar"],
	"eterium": ["Observar Eterium", "Aplicar Eterium"]
}

const TITULOS_ESTACION: Dictionary = {
	"examen": "MESA DE EXAMINACIÓN",
	"mezclas": "ESTACIÓN DE MEZCLAS",
	"termica": "ESTACIÓN TÉRMICA",
	"observacion": "ESTACIÓN DE OBSERVACIÓN",
	"eterium": "ESTACIÓN DE ETERIUM"
}

var _inventario: InventoryController = null
var _estacion_id := "examen"
var _seleccionados: Array[int] = []
var _botones_items: Dictionary = {}
var _procedimiento: OptionButton
var _seleccion_label: Label
var _resultado_label: Label
var _items_columna: VBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	layer = 90
	add_to_group("modal_ui")


func configurar(inventario: InventoryController, estacion_id: String) -> void:
	_inventario = inventario
	_estacion_id = estacion_id if PROCEDIMIENTOS_POR_ESTACION.has(estacion_id) else "examen"
	_crear_interfaz()


func _crear_interfaz() -> void:
	if _panel != null:
		return

	_panel = PanelContainer.new()
	_panel.name = "ResearchLabPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -370.0
	_panel.offset_top = -235.0
	_panel.offset_right = 370.0
	_panel.offset_bottom = 235.0
	_panel.custom_minimum_size = Vector2(740.0, 470.0)
	add_child(_panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 16)
	margen.add_theme_constant_override("margin_top", 14)
	margen.add_theme_constant_override("margin_right", 16)
	margen.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	margen.add_child(columna)

	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)

	var titulo := Label.new()
	titulo.name = "Title"
	titulo.text = str(TITULOS_ESTACION.get(_estacion_id, "LABORATORIO"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_theme_font_size_override("font_size", 17)
	cabecera.add_child(titulo)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(82, 32)
	cerrar.pressed.connect(queue_free)
	cabecera.add_child(cerrar)

	var descripcion := Label.new()
	descripcion.text = "Selecciona los elementos que quieres estudiar y el procedimiento que deseas aplicar."
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(descripcion)

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 14)
	columna.add_child(cuerpo)

	var columna_items := VBoxContainer.new()
	columna_items.custom_minimum_size = Vector2(350, 0)
	columna_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(columna_items)

	var titulo_items := Label.new()
	titulo_items.text = "OBJETOS DISPONIBLES"
	columna_items.add_child(titulo_items)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna_items.add_child(scroll)

	_items_columna = VBoxContainer.new()
	_items_columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_columna.add_theme_constant_override("separation", 5)
	scroll.add_child(_items_columna)

	var columna_prueba := VBoxContainer.new()
	columna_prueba.custom_minimum_size = Vector2(300, 0)
	columna_prueba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna_prueba.add_theme_constant_override("separation", 9)
	cuerpo.add_child(columna_prueba)

	var titulo_procedimiento := Label.new()
	titulo_procedimiento.text = "PROCEDIMIENTO"
	columna_prueba.add_child(titulo_procedimiento)

	_procedimiento = OptionButton.new()
	_procedimiento.custom_minimum_size = Vector2(280, 34)
	for procedimiento in PROCEDIMIENTOS_POR_ESTACION[_estacion_id]:
		_procedimiento.add_item(str(procedimiento))
	columna_prueba.add_child(_procedimiento)

	_seleccion_label = Label.new()
	_seleccion_label.text = "Elementos seleccionados: 0/4"
	_seleccion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna_prueba.add_child(_seleccion_label)

	var nota := Label.new()
	nota.text = "Puedes seleccionar entre uno y cuatro elementos. Las pruebas preliminares no consumen ni modifican objetos."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_font_size_override("font_size", 11)
	columna_prueba.add_child(nota)

	_resultado_label = Label.new()
	_resultado_label.name = "ExperimentResult"
	_resultado_label.text = "El resultado de la prueba aparecerá aquí."
	_resultado_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resultado_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_resultado_label.custom_minimum_size = Vector2(280, 90)
	columna_prueba.add_child(_resultado_label)

	var ejecutar := Button.new()
	ejecutar.text = "Realizar prueba"
	ejecutar.custom_minimum_size = Vector2(0, 38)
	ejecutar.pressed.connect(_ejecutar_prueba)
	columna_prueba.add_child(ejecutar)

	_cargar_objetos()
	PIXEL_UI_THEME.apply(_panel)


func _cargar_objetos() -> void:
	if not is_instance_valid(_items_columna):
		return
	for hijo in _items_columna.get_children():
		_items_columna.remove_child(hijo)
		hijo.queue_free()
	_botones_items.clear()
	_seleccionados.clear()

	if not is_instance_valid(_inventario):
		var aviso := Label.new()
		aviso.text = "No se pudo acceder al inventario."
		_items_columna.add_child(aviso)
		return

	var items: Array[Dictionary] = _inventario.runtime.state.items
	var disponibles := 0
	for indice in range(items.size()):
		var objeto: Dictionary = items[indice]
		if objeto.is_empty():
			continue
		disponibles += 1
		var boton := Button.new()
		boton.toggle_mode = true
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.custom_minimum_size = Vector2(0, 38)
		boton.text = "%s  x%d" % [
			str(objeto.get("nombre", "Objeto")),
			maxi(1, int(objeto.get("cantidad", 1)))
		]
		boton.icon = ItemIconResolver.obtener_icono(objeto)
		boton.pressed.connect(_alternar_seleccion.bind(indice, boton))
		_items_columna.add_child(boton)
		_botones_items[indice] = boton

	if disponibles == 0:
		var vacio := Label.new()
		vacio.text = "No llevas objetos para examinar."
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_items_columna.add_child(vacio)
	_actualizar_seleccion()


func _alternar_seleccion(indice: int, boton: Button) -> void:
	if boton.button_pressed:
		if _seleccionados.size() >= 4:
			boton.button_pressed = false
			Events.notification_pushed.emit("La estación admite hasta cuatro elementos por prueba.")
			return
		if not _seleccionados.has(indice):
			_seleccionados.append(indice)
	else:
		_seleccionados.erase(indice)
	_actualizar_seleccion()


func _actualizar_seleccion() -> void:
	if is_instance_valid(_seleccion_label):
		_seleccion_label.text = "Elementos seleccionados: %d/4" % _seleccionados.size()


func _ejecutar_prueba() -> void:
	if not is_instance_valid(_inventario):
		_resultado_label.text = "No se pudo acceder al inventario."
		return

	var procedimiento := _procedimiento.get_item_text(_procedimiento.selected).strip_edges()
	var requiere_varios := procedimiento in ["Comparar", "Mezclar", "Disolver"]
	var minimo := 2 if requiere_varios else 1
	if _seleccionados.size() < minimo:
		_resultado_label.text = "Selecciona al menos %d elemento(s) para este procedimiento." % minimo
		return

	var objetos: Array[Dictionary] = []
	var nombres: Array[String] = []
	for indice in _seleccionados:
		var objeto := _inventario.obtener_item(indice)
		if objeto.is_empty():
			_resultado_label.text = "El inventario cambió. Vuelve a seleccionar los elementos."
			_cargar_objetos()
			return
		objetos.append(objeto)
		nombres.append(str(objeto.get("nombre", "Objeto")))

	_resultado_label.text = _describir_resultado_preliminar(procedimiento, objetos, nombres)


func _describir_resultado_preliminar(procedimiento: String, objetos: Array[Dictionary], nombres: Array[String]) -> String:
	if procedimiento in ["Examinar", "Observar estructura", "Observar Eterium", "Medir"]:
		var objeto := objetos[0]
		var nombre := nombres[0]
		var descripcion := str(objeto.get("descripcion", "")).strip_edges()
		var categoria := _obtener_categoria(objeto)
		var resultado := "Examinas %s." % nombre
		if not categoria.is_empty():
			resultado += " Está clasificado como %s." % categoria
		if not descripcion.is_empty():
			resultado += " " + descripcion
		resultado += " La observación no modifica el objeto."
		return resultado

	if procedimiento in ["Comparar"]:
		var resumen: Array[String] = []
		for objeto in objetos:
			var categoria := _obtener_categoria(objeto)
			var detalle := str(objeto.get("nombre", "Objeto"))
			if not categoria.is_empty():
				detalle += " (%s)" % categoria
			resumen.append(detalle)
		return "Comparas %s. La estación permite revisar sus diferencias visibles y sus datos conocidos. No se han alterado las muestras." % ", ".join(resumen)

	return "La prueba con %s ha terminado. Todavía no hay una reacción definida para esta combinación y procedimiento. Los elementos se conservaron intactos." % ", ".join(nombres)


func _obtener_categoria(objeto: Dictionary) -> String:
	var categoria: Variant = objeto.get("categoria", "")
	if categoria is Dictionary:
		return str((categoria as Dictionary).get("nombre", (categoria as Dictionary).get("clave", ""))).strip_edges()
	if categoria is String and not str(categoria).strip_edges().is_empty():
		return str(categoria).strip_edges()
	return str(objeto.get("categoria_nombre", objeto.get("categoria_clave", ""))).strip_edges()
