extends CanvasLayer
## Interfaz editable de trabajo del laboratorio.
## Las pruebas preliminares no consumen objetos ni modifican sus datos.

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

const PROCEDIMIENTOS_POR_ESTACION: Dictionary = {
	"examen": ["Analizar objeto"]
}

const TITULOS_ESTACION: Dictionary = {
	"examen": "ANÁLISIS DE OBJETOS"
}

@onready var _panel: PanelContainer = $Panel
@onready var _titulo: Label = $Panel/Margin/Column/Header/Title
@onready var _boton_cerrar: Button = $Panel/Margin/Column/Header/Close
@onready var _items_columna: VBoxContainer = $Panel/Margin/Column/Body/ItemsColumn/ItemScroll/ItemsList
@onready var _procedimiento: OptionButton = $Panel/Margin/Column/Body/ProcedureColumn/Procedure
@onready var _resultado_label: Label = $Panel/Margin/Column/Body/ProcedureColumn/Result
@onready var _boton_ejecutar: Button = $Panel/Margin/Column/Body/ProcedureColumn/Run

var _inventario: InventoryController = null
var _estacion_id := "examen"
var _indice_seleccionado := -1
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
	_resultado_label.text = ""
	_cargar_objetos()
	_aplicar_estilo_laboratorio()


func _aplicar_estilo_laboratorio() -> void:
	# El marco principal utiliza la misma superficie dibujada que los botones
	# del resto de la interfaz, en lugar del panel genérico/transparente.
	PIXEL_UI_THEME.apply(_panel)
	var fondo_button := PIXEL_UI_THEME.button_surface_style()
	if fondo_button != null:
		_panel.add_theme_stylebox_override("panel", fondo_button)


func _cargar_objetos() -> void:
	if not is_instance_valid(_items_columna):
		return
	for hijo in _items_columna.get_children():
		_items_columna.remove_child(hijo)
		hijo.queue_free()
	_botones_items.clear()
	_indice_seleccionado = -1

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
		boton.icon_max_width = 36
		boton.custom_minimum_size = Vector2(0, 42)
		_botones_items[indice] = boton

	if disponibles == 0:
		var vacio := Label.new()
		vacio.text = "No llevas objetos para examinar."
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_items_columna.add_child(vacio)
	_actualizar_seleccion()


func _alternar_seleccion(indice: int, boton: Button) -> void:
	if boton.button_pressed:
		for otro_indice in _botones_items:
			if int(otro_indice) != indice:
				var otro_boton: Button = _botones_items[otro_indice]
				otro_boton.button_pressed = false
		_indice_seleccionado = indice
	else:
		_indice_seleccionado = -1
	_actualizar_seleccion()


func _actualizar_seleccion() -> void:
	# Mantiene sincronizado el estado visual de los botones con la selección única.
	for indice in _botones_items:
		var boton: Button = _botones_items[indice]
		boton.set_pressed_no_signal(int(indice) == _indice_seleccionado)
	_boton_ejecutar.disabled = _indice_seleccionado < 0


func _ejecutar_prueba() -> void:
	if not is_instance_valid(_inventario):
		_resultado_label.text = "No se pudo acceder al inventario."
		return
	if _indice_seleccionado < 0:
		_resultado_label.text = "Selecciona un objeto."
		return

	var procedimiento := _procedimiento.get_item_text(_procedimiento.selected).strip_edges()
	var objeto := _inventario.obtener_item(_indice_seleccionado)
	if objeto.is_empty():
		_resultado_label.text = "El inventario cambió. Vuelve a seleccionar el objeto."
		_cargar_objetos()
		return

	var nombre := str(objeto.get("nombre", "Objeto"))
	_resultado_label.text = _describir_resultado_preliminar(procedimiento, objeto, nombre)


func _describir_resultado_preliminar(procedimiento: String, objeto: Dictionary, nombre: String) -> String:
	if procedimiento == "Analizar objeto":
		var descripcion := str(objeto.get("descripcion", "")).strip_edges()
		var categoria := _obtener_categoria(objeto)
		if categoria.is_empty() and descripcion.is_empty():
			return "No hay datos."
		var resultado := "Analizas %s." % nombre
		if not categoria.is_empty():
			resultado += " Está clasificado como %s." % categoria
		if not descripcion.is_empty():
			resultado += " " + descripcion
		resultado += " La observación no modifica el objeto."
		return resultado

	return "La prueba con %s ha terminado. Todavía no hay una reacción definida para este procedimiento. El objeto se conservó intacto." % nombre


func _obtener_categoria(objeto: Dictionary) -> String:
	var categoria: Variant = objeto.get("categoria", "")
	if categoria is Dictionary:
		return str((categoria as Dictionary).get("nombre", (categoria as Dictionary).get("clave", ""))).strip_edges()
	if categoria is String and not str(categoria).strip_edges().is_empty():
		return str(categoria).strip_edges()
	return str(objeto.get("categoria_nombre", objeto.get("categoria_clave", ""))).strip_edges()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
