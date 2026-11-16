extends CanvasLayer
## Interfaz editable de trabajo del laboratorio.
## Las pruebas preliminares no consumen objetos ni modifican sus datos.

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

const PROCEDIMIENTOS_POR_ESTACION: Dictionary = {
	"examen": ["Examinar", "Medir", "Comparar"],
	"mezclas": ["Mezclar", "Disolver", "Ensamblar"],
	"termica": ["Calentar", "Enfriar", "Fundir"],
	"observacion": ["Observar estructura", "Comparar"],
	"eterium": ["Observar Eterium", "Aplicar Eterium"]
}

const TITULOS_ESTACION: Dictionary = {
	"examen": "MESA DE EXAMINACIÓN",
	"mezclas": "ESTACIÓN DE PREPARACIÓN",
	"termica": "ESTACIÓN TÉRMICA",
	"observacion": "ESTACIÓN DE OBSERVACIÓN",
	"eterium": "ESTACIÓN DE ETERIUM"
}

@onready var _panel: PanelContainer = $Panel
@onready var _titulo: Label = $Panel/Margin/Column/Header/Title
@onready var _boton_cerrar: Button = $Panel/Margin/Column/Header/Close
@onready var _items_columna: VBoxContainer = $Panel/Margin/Column/Body/ItemsColumn/ItemScroll/ItemsList
@onready var _procedimiento: OptionButton = $Panel/Margin/Column/Body/ProcedureColumn/Procedure
@onready var _seleccion_label: Label = $Panel/Margin/Column/Body/ProcedureColumn/Selection
@onready var _resultado_label: Label = $Panel/Margin/Column/Body/ProcedureColumn/Result
@onready var _boton_ejecutar: Button = $Panel/Margin/Column/Body/ProcedureColumn/Run

var _inventario: InventoryController = null
var _estacion_id := "examen"
var _seleccionados: Array[int] = []
var _botones_items: Dictionary = {}


func _ready() -> void:
	layer = 90
	add_to_group("modal_ui")
	add_to_group("research_lab_ui")
	_boton_cerrar.pressed.connect(queue_free)
	_boton_ejecutar.pressed.connect(_ejecutar_prueba)


func configurar(inventario: InventoryController, estacion_id: String) -> void:
	_inventario = inventario
	_estacion_id = estacion_id if PROCEDIMIENTOS_POR_ESTACION.has(estacion_id) else "examen"
	_crear_interfaz()


func _crear_interfaz() -> void:
	_titulo.text = str(TITULOS_ESTACION.get(_estacion_id, "LABORATORIO"))
	_procedimiento.clear()
	for nombre_procedimiento in PROCEDIMIENTOS_POR_ESTACION[_estacion_id]:
		_procedimiento.add_item(str(nombre_procedimiento))
	_procedimiento.select(0)
	_resultado_label.text = "El resultado de la prueba aparecerá aquí."
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
		boton.custom_minimum_size = Vector2(0, 34)
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
	var requiere_varios := procedimiento in ["Comparar", "Mezclar", "Disolver", "Ensamblar"]
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

	if procedimiento == "Comparar":
		var resumen: Array[String] = []
		for objeto in objetos:
			var categoria := _obtener_categoria(objeto)
			var detalle := str(objeto.get("nombre", "Objeto"))
			if not categoria.is_empty():
				detalle += " (%s)" % categoria
			resumen.append(detalle)
		return "Comparas %s. La estación permite revisar sus diferencias visibles y sus datos conocidos. No se han alterado las muestras." % _unir_textos(resumen)

	return "La prueba con %s ha terminado. Todavía no hay una reacción definida para esta combinación y procedimiento. Los elementos se conservaron intactos." % _unir_textos(nombres)


func _obtener_categoria(objeto: Dictionary) -> String:
	var categoria: Variant = objeto.get("categoria", "")
	if categoria is Dictionary:
		return str((categoria as Dictionary).get("nombre", (categoria as Dictionary).get("clave", ""))).strip_edges()
	if categoria is String and not str(categoria).strip_edges().is_empty():
		return str(categoria).strip_edges()
	return str(objeto.get("categoria_nombre", objeto.get("categoria_clave", ""))).strip_edges()


func _unir_textos(elementos: Array[String]) -> String:
	var resultado := ""
	for elemento in elementos:
		if not resultado.is_empty():
			resultado += ", "
		resultado += elemento
	return resultado


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
