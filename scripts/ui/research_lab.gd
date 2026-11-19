extends CanvasLayer
## Estudio Oris: selección visual de objetos y análisis informativo.

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

@onready var _panel: PanelContainer = $Panel
@onready var _boton_cerrar: Button = $Panel/Margin/Column/Header/Close
@onready var _items_columna: GridContainer = $Panel/Margin/Column/Body/ItemsPanel/ItemMargin/ItemsColumn/ItemScroll/ItemsGrid
@onready var _imagen_seleccionada: TextureRect = $Panel/Margin/Column/Body/SelectionPanel/SelectionMargin/SelectionContent/SelectedImage
@onready var _nombre_seleccionado: Label = $Panel/Margin/Column/Body/SelectionPanel/SelectionMargin/SelectionContent/SelectedName
@onready var _boton_analizar: Button = $Panel/Margin/Column/Body/SelectionPanel/SelectionMargin/SelectionContent/Run
@onready var _resultado_label: Label = $Panel/Margin/Column/Body/SelectionPanel/SelectionMargin/SelectionContent/Result
@onready var _panel_items: PanelContainer = $Panel/Margin/Column/Body/ItemsPanel
@onready var _panel_seleccion: PanelContainer = $Panel/Margin/Column/Body/SelectionPanel

var _inventario: InventoryController = null
var _estacion_id := "examen"
var _indice_seleccionado := -1
var _botones_items: Dictionary = {}


func _ready() -> void:
	layer = 90
	add_to_group("modal_ui")
	add_to_group("research_lab_ui")
	_boton_cerrar.pressed.connect(queue_free)
	_boton_analizar.pressed.connect(_analizar_objeto)
	_boton_analizar.disabled = true
	_boton_analizar.text = "Inspeccionar" if _estacion_id == "forja_inspeccion" else "Analizar"
	_aplicar_estilo_laboratorio()


func configurar(inventario: InventoryController, estacion_id: String = "examen") -> void:
	_inventario = inventario
	_estacion_id = estacion_id
	_boton_analizar.text = "Inspeccionar" if _estacion_id == "forja_inspeccion" else "Analizar"
	_cargar_objetos()


func _aplicar_estilo_laboratorio() -> void:
	PIXEL_UI_THEME.apply(_panel)
	var fondo_button := PIXEL_UI_THEME.button_surface_style()
	if fondo_button != null:
		_panel.add_theme_stylebox_override("panel", fondo_button)
		_panel_items.add_theme_stylebox_override("panel", fondo_button.duplicate())
		_panel_seleccion.add_theme_stylebox_override("panel", fondo_button.duplicate())


func _cargar_objetos() -> void:
	for hijo in _items_columna.get_children():
		_items_columna.remove_child(hijo)
		hijo.queue_free()
	_botones_items.clear()
	_indice_seleccionado = -1
	_imagen_seleccionada.texture = null
	_nombre_seleccionado.text = ""
	_resultado_label.text = ""
	_boton_analizar.disabled = true

	if not is_instance_valid(_inventario):
		_agregar_aviso("No se pudo acceder al inventario.")
		return

	var items: Array[Dictionary] = _inventario.runtime.state.items
	var disponibles := 0
	for indice in range(items.size()):
		var objeto: Dictionary = items[indice]
		if objeto.is_empty() or not _objeto_permitido_en_estacion(objeto):
			continue
		disponibles += 1
		var boton := Button.new()
		boton.toggle_mode = true
		boton.custom_minimum_size = Vector2(64, 64)
		boton.icon = ItemIconResolver.obtener_icono(objeto)
		boton.expand_icon = true
		boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		boton.tooltip_text = str(objeto.get("nombre", "Objeto"))
		boton.pressed.connect(_seleccionar_objeto.bind(indice))
		_items_columna.add_child(boton)
		PIXEL_UI_THEME.apply(boton)
		_botones_items[indice] = boton

	if disponibles == 0:
		if _estacion_id == "forja_inspeccion":
			_agregar_aviso("No llevas armas ni herramientas para inspeccionar.")
		else:
			_agregar_aviso("No llevas materiales ni objetos de estudio.")


func _objeto_permitido_en_estacion(objeto: Dictionary) -> bool:
	var es_equipo := _es_arma(objeto) or _es_herramienta(objeto)
	if _estacion_id == "forja_inspeccion":
		return es_equipo
	return not es_equipo


func _es_arma(objeto: Dictionary) -> bool:
	var tipo := str(objeto.get("tipo", "")).to_lower()
	var categoria := _texto_categoria(objeto).to_lower()
	var nombre := str(objeto.get("nombre", "")).to_lower()
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	var propiedades: Dictionary = propiedades_variant if propiedades_variant is Dictionary else {}
	return tipo.contains("arma") or tipo.contains("weapon") or categoria.contains("arma") or categoria.contains("weapon") or bool(propiedades.get("es_arma", false)) or propiedades.has("danio_arma") or propiedades.has("ataque_arma") or nombre.contains("espada") or nombre.contains("arco") or nombre.contains("daga") or nombre.contains("lanza") or nombre.contains("ballesta") or nombre.contains("honda")


func _es_herramienta(objeto: Dictionary) -> bool:
	var tipo := str(objeto.get("tipo", "")).to_lower()
	var categoria := _texto_categoria(objeto).to_lower()
	var nombre := str(objeto.get("nombre", "")).to_lower()
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	var propiedades: Dictionary = propiedades_variant if propiedades_variant is Dictionary else {}
	var recoleccion: Variant = propiedades.get("recoleccion", {})
	var tiene_recoleccion := recoleccion is Dictionary and not (recoleccion as Dictionary).is_empty()
	return tipo.contains("herramienta") or tipo.contains("tool") or categoria.contains("herramienta") or categoria.contains("tool") or tiene_recoleccion or bool(propiedades.get("es_herramienta", false)) or nombre.contains("hacha") or nombre.contains("pico") or nombre.contains("pala") or nombre.contains("martillo") or nombre.contains("azada") or nombre.contains("guadaña") or nombre.contains("cincel") or nombre.contains("regadera")


func _texto_categoria(objeto: Dictionary) -> String:
	var categoria: Variant = objeto.get("categoria", "")
	if categoria is Dictionary:
		var datos := categoria as Dictionary
		return str(datos.get("nombre", datos.get("clave", "")))
	return str(categoria if not str(categoria).is_empty() else objeto.get("categoria_nombre", objeto.get("categoria_clave", "")))


func _agregar_aviso(texto: String) -> void:
	var aviso := Label.new()
	aviso.text = texto
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_items_columna.add_child(aviso)


func _seleccionar_objeto(indice: int) -> void:
	if not is_instance_valid(_inventario) or indice < 0 or indice >= _inventario.runtime.state.items.size():
		return
	var objeto: Dictionary = _inventario.obtener_item(indice)
	if objeto.is_empty():
		_cargar_objetos()
		return
	_indice_seleccionado = indice
	for otro_indice in _botones_items:
		var boton: Button = _botones_items[otro_indice]
		boton.set_pressed_no_signal(int(otro_indice) == indice)
	_imagen_seleccionada.texture = ItemIconResolver.obtener_icono(objeto)
	_nombre_seleccionado.text = str(objeto.get("nombre", "Objeto"))
	_resultado_label.text = ""
	_boton_analizar.disabled = false


func _analizar_objeto() -> void:
	if not is_instance_valid(_inventario) or _indice_seleccionado < 0:
		return
	var objeto := _inventario.obtener_item(_indice_seleccionado)
	if objeto.is_empty():
		_resultado_label.text = "El inventario cambió. Selecciona nuevamente el objeto."
		_cargar_objetos()
		return
	var nombre := str(objeto.get("nombre", "Objeto"))
	_resultado_label.text = _describir_analisis(objeto, nombre)


func _describir_analisis(objeto: Dictionary, nombre: String) -> String:
	if not _objeto_permitido_en_estacion(objeto):
		return "Este objeto corresponde a otra mesa de trabajo."
	var descripcion := str(objeto.get("descripcion", "")).strip_edges()
	var categoria := _obtener_categoria(objeto)
	if categoria.is_empty() and descripcion.is_empty():
		return "No hay datos registrados sobre este objeto."
	var resultado := "Analizas %s." % nombre
	if not categoria.is_empty():
		resultado += " Está clasificado como %s." % categoria
	if not descripcion.is_empty():
		resultado += " " + descripcion
	resultado += " El análisis no modifica ni consume el objeto."
	return resultado


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
