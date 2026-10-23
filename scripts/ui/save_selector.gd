extends Control

@onready var list_container: VBoxContainer = $Panel/Margin/Column/Scroll/Partidas
@onready var status_label: Label = $Panel/Margin/Column/Status
@onready var character_creation: Control = $CharacterCreation
@onready var column: VBoxContainer = $Panel/Margin/Column
@onready var panel_margin: MarginContainer = $Panel/Margin
@onready var scroll_container: ScrollContainer = $Panel/Margin/Column/Scroll
@onready var create_button: Button = $Panel/Margin/Column/CreateButton
@onready var title_label: Label = $Panel/Margin/Column/Title
@onready var subtitle_label: Label = $Panel/Margin/Column/Subtitle
@onready var back_button: Button = $Panel/Margin/Column/BackButton
var _confirmacion_borrado: ConfirmationDialog
var _editor_container: VBoxContainer
var _editor_scroll: ScrollContainer
var _editor_form: VBoxContainer
var _nombre_mundo_input: LineEdit
var _nombre_personaje_input: LineEdit
var _genero_input: OptionButton
var _genero_libre_input: LineEdit
var _aspectos_list: ItemList
var _semilla_label: Label
var _especie_label: Label
var _id_pendiente_borrar: String = ""
var _id_pendiente_editar: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	actualizar_lista()
	_configurar_diseno_responsive()
	get_viewport().size_changed.connect(_configurar_diseno_responsive)
	_configurar_confirmacion_borrado()
	if not character_creation.confirmed.is_connected(_on_character_confirmed):
		character_creation.confirmed.connect(_on_character_confirmed)
	if not character_creation.cancelled.is_connected(_on_character_cancelled):
		character_creation.cancelled.connect(_on_character_cancelled)


func actualizar_lista() -> void:
	for child in list_container.get_children():
		child.queue_free()

	var partidas := GameState.obtener_partidas()

	if partidas.is_empty():
		var vacio := Label.new()
		vacio.text = "Todavía no tienes partidas guardadas."
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vacio.custom_minimum_size = Vector2(0, 44)
		list_container.add_child(vacio)
	else:
		for partida in partidas:
			_crear_fila_partida(partida)


func _crear_fila_partida(partida: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 68)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_stretch_ratio = 1.0
	row.add_child(info)

	var title := Label.new()
	title.text = str(partida.get("nombre", "Partida"))
	title.add_theme_font_size_override("font_size", 16)
	info.add_child(title)

	var edit := Button.new()
	edit.text = "✎"
	edit.tooltip_text = "Editar nombre y configuración del mundo"
	edit.custom_minimum_size = Vector2(44, 42)
	edit.pressed.connect(
		_editar_partida.bind(str(partida.get("id", "")))
	)
	row.add_child(edit)

	var play := Button.new()
	play.text = "Jugar"
	play.custom_minimum_size = Vector2(90, 42)
	play.pressed.connect(
		_jugar_partida.bind(str(partida.get("id", "")))
	)
	row.add_child(play)

	var delete := Button.new()
	delete.text = "Eliminar"
	delete.custom_minimum_size = Vector2(90, 42)
	delete.pressed.connect(
		_eliminar_partida.bind(str(partida.get("id", "")))
	)
	row.add_child(delete)

	list_container.add_child(panel)


func _jugar_partida(id: String) -> void:
	if id.is_empty():
		return

	visible = false

	if not GameState.iniciar_partida(id):
		visible = true
		status_label.text = "No se pudo abrir la partida."


func _configurar_confirmacion_borrado() -> void:
	_confirmacion_borrado = ConfirmationDialog.new()
	_confirmacion_borrado.title = "Eliminar mundo"
	_confirmacion_borrado.dialog_text = "Esta acción no se puede deshacer."
	_confirmacion_borrado.ok_button_text = "Eliminar mundo"
	_confirmacion_borrado.cancel_button_text = "Conservar mundo"
	_confirmacion_borrado.confirmed.connect(_confirmar_borrado_partida)
	_confirmacion_borrado.exclusive = true
	add_child(_confirmacion_borrado)


func _eliminar_partida(id: String) -> void:
	if id.is_empty() or _confirmacion_borrado == null:
		return
	_id_pendiente_borrar = id
	_confirmacion_borrado.dialog_text = "¿Seguro que quieres borrar el mundo «%s»? Esta acción no se puede deshacer." % _nombre_partida(id)
	_confirmacion_borrado.popup_centered()


func _confirmar_borrado_partida() -> void:
	var id := _id_pendiente_borrar
	_id_pendiente_borrar = ""
	if id.is_empty():
		return

	if GameState.eliminar_partida(id):
		actualizar_lista()
		status_label.text = "Partida eliminada."
	else:
		status_label.text = "No se pudo eliminar la partida."


func _nombre_partida(id: String) -> String:
	for partida in GameState.obtener_partidas():
		if str(partida.get("id", "")) == id:
			return str(partida.get("nombre", "Partida"))
	return "Partida"


func _crear_estilo_panel_edicion() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.075, 0.05, 1)
	estilo.set_border_width_all(1)
	estilo.border_color = Color(0.42, 0.33, 0.22, 1)
	estilo.set_corner_radius_all(4)
	return estilo


func _configurar_diseno_responsive() -> void:
	var viewport_size := get_viewport_rect().size
	var compacto := viewport_size.x < 720.0 or viewport_size.y < 560.0
	var margen_horizontal := 12 if viewport_size.x < 520.0 else (18 if compacto else 26)
	var margen_vertical := 10 if viewport_size.y < 460.0 else (14 if compacto else 22)
	panel_margin.add_theme_constant_override("margin_left", margen_horizontal)
	panel_margin.add_theme_constant_override("margin_right", margen_horizontal)
	panel_margin.add_theme_constant_override("margin_top", margen_vertical)
	panel_margin.add_theme_constant_override("margin_bottom", margen_vertical)
	column.add_theme_constant_override("separation", 8 if compacto else 12)
	if _editor_container != null:
		_editor_container.add_theme_constant_override("separation", 6 if compacto else 8)
		if _aspectos_list != null:
			var ancho_util := maxf(180.0, viewport_size.x - margen_horizontal * 2.0 - 80.0)
			_aspectos_list.max_columns = clampi(int(ancho_util / 76.0), 2, 8)
			_aspectos_list.fixed_column_width = clampi(int(ancho_util / float(_aspectos_list.max_columns)), 58, 84)
			var alto_icono := 44 if compacto else 56
			_aspectos_list.fixed_icon_size = Vector2i(alto_icono, alto_icono)
			_aspectos_list.custom_minimum_size.y = 92 if compacto else 124


func _construir_editor_partida() -> void:
	_editor_container = VBoxContainer.new()
	_editor_container.name = "WorldEditor"
	_editor_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_container.add_theme_constant_override("separation", 8)

	_editor_scroll = ScrollContainer.new()
	_editor_scroll.name = "EditorScroll"
	_editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_editor_container.add_child(_editor_scroll)

	_editor_form = VBoxContainer.new()
	_editor_form.name = "EditorFields"
	_editor_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_form.add_theme_constant_override("separation", 8)
	_editor_scroll.add_child(_editor_form)

	var label_mundo := Label.new()
	label_mundo.text = "Nombre del mundo"
	_editor_form.add_child(label_mundo)
	_nombre_mundo_input = LineEdit.new()
	_nombre_mundo_input.custom_minimum_size = Vector2(0, 36)
	_nombre_mundo_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nombre_mundo_input.max_length = 64
	_nombre_mundo_input.add_theme_stylebox_override("normal", _crear_estilo_panel_edicion())
	_nombre_mundo_input.add_theme_stylebox_override("focus", _crear_estilo_panel_edicion())
	_editor_form.add_child(_nombre_mundo_input)

	var label_personaje := Label.new()
	label_personaje.text = "Nombre del personaje"
	_editor_form.add_child(label_personaje)
	_nombre_personaje_input = LineEdit.new()
	_nombre_personaje_input.custom_minimum_size = Vector2(0, 36)
	_nombre_personaje_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nombre_personaje_input.max_length = 48
	_nombre_personaje_input.add_theme_stylebox_override("normal", _crear_estilo_panel_edicion())
	_nombre_personaje_input.add_theme_stylebox_override("focus", _crear_estilo_panel_edicion())
	_editor_form.add_child(_nombre_personaje_input)

	var label_genero := Label.new()
	label_genero.text = "Género"
	_editor_form.add_child(label_genero)
	_genero_input = OptionButton.new()
	_genero_input.custom_minimum_size = Vector2(0, 36)
	_genero_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for valor in ["El", "Ella", "Elle", "Eso", "Texto libre", "Sin género"]:
		_genero_input.add_item(valor)
	_genero_input.item_selected.connect(_al_cambiar_genero_edicion)
	_editor_form.add_child(_genero_input)

	_genero_libre_input = LineEdit.new()
	_genero_libre_input.custom_minimum_size = Vector2(0, 34)
	_genero_libre_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_genero_libre_input.placeholder_text = "Escribe tu género"
	_genero_libre_input.visible = false
	_genero_libre_input.add_theme_stylebox_override("normal", _crear_estilo_panel_edicion())
	_genero_libre_input.add_theme_stylebox_override("focus", _crear_estilo_panel_edicion())
	_editor_form.add_child(_genero_libre_input)

	var datos_fila := HBoxContainer.new()
	datos_fila.add_theme_constant_override("separation", 12)
	_editor_form.add_child(datos_fila)
	var columna_semilla := VBoxContainer.new()
	columna_semilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	datos_fila.add_child(columna_semilla)
	var label_semilla := Label.new()
	label_semilla.text = "Semilla (solo lectura)"
	columna_semilla.add_child(label_semilla)
	_semilla_label = Label.new()
	_semilla_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_semilla_label.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52, 1))
	columna_semilla.add_child(_semilla_label)

	var columna_especie := VBoxContainer.new()
	columna_especie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	datos_fila.add_child(columna_especie)
	var label_especie := Label.new()
	label_especie.text = "Especie (solo lectura)"
	columna_especie.add_child(label_especie)
	_especie_label = Label.new()
	_especie_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_especie_label.add_theme_color_override("font_color", Color(0.78, 0.68, 0.52, 1))
	columna_especie.add_child(_especie_label)

	var label_aspecto := Label.new()
	label_aspecto.text = "Aspecto del personaje"
	_editor_form.add_child(label_aspecto)
	_aspectos_list = ItemList.new()
	_aspectos_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aspectos_list.max_columns = 6
	_aspectos_list.fixed_column_width = 72
	_aspectos_list.fixed_icon_size = Vector2i(56, 56)
	_aspectos_list.icon_mode = ItemList.ICON_MODE_TOP
	_aspectos_list.select_mode = ItemList.SELECT_SINGLE
	_aspectos_list.add_theme_stylebox_override("panel", _crear_estilo_panel_edicion())
	_editor_form.add_child(_aspectos_list)
	_cargar_aspectos_edicion()

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	_editor_container.add_child(botones)
	var guardar := Button.new()
	guardar.text = "Guardar"
	guardar.custom_minimum_size = Vector2(0, 42)
	guardar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guardar.pressed.connect(_guardar_edicion_partida)
	botones.add_child(guardar)
	var volver := Button.new()
	volver.text = "Volver"
	volver.custom_minimum_size = Vector2(0, 42)
	volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volver.pressed.connect(_cancelar_edicion_partida)
	botones.add_child(volver)

	column.add_child(_editor_container)
	column.move_child(_editor_container, 2)
	_editor_container.visible = false
	_configurar_diseno_responsive()

func _cargar_aspectos_edicion() -> void:
	_aspectos_list.clear()
	var directorio := DirAccess.open("res://assets/art/characters/skins/")
	if directorio == null:
		return
	var archivos := directorio.get_files()
	archivos.sort()
	for archivo in archivos:
		if archivo.get_extension().to_lower() not in ["png", "webp", "jpg", "jpeg"]:
			continue
		var ruta := "res://assets/art/characters/skins/" + archivo
		var textura := load(ruta) as Texture2D
		if textura == null:
			continue
		_aspectos_list.add_icon_item(textura, true)
		var indice := _aspectos_list.item_count - 1
		_aspectos_list.set_item_text(indice, archivo.get_basename())
		_aspectos_list.set_item_metadata(indice, ruta)


func _al_cambiar_genero_edicion(indice: int) -> void:
	_genero_libre_input.visible = indice == 4


func _editar_partida(id: String) -> void:
	if id.is_empty():
		return
	var datos: Dictionary = GameState.obtener_datos_edicion_partida(id)
	if datos.is_empty():
		_mostrar_estado_edicion("No se encontró ese mundo.")
		return
	if _editor_container == null:
		_construir_editor_partida()

	_id_pendiente_editar = id
	title_label.visible = true
	title_label.text = "Editar mundo"
	subtitle_label.visible = true
	subtitle_label.text = "Personaliza el nombre y el aspecto de tu personaje."
	scroll_container.visible = false
	create_button.visible = false
	status_label.visible = false
	back_button.visible = false
	_editor_container.visible = true
	_nombre_mundo_input.text = str(datos.get("nombre_mundo", "Partida"))
	_semilla_label.text = str(datos.get("semilla", "—"))

	var personaje: Dictionary = {}
	var variante_personaje: Variant = datos.get("personaje", {})
	if variante_personaje is Dictionary:
		personaje = variante_personaje as Dictionary
	_nombre_personaje_input.text = str(personaje.get("nombre", ""))
	_especie_label.text = _nombre_especie(personaje.get("especie", {}))
	var genero := str(personaje.get("genero", "El"))
	var indice_genero := _indice_genero(genero)
	_genero_input.select(indice_genero)
	_genero_libre_input.text = genero if indice_genero == 4 else ""
	_genero_libre_input.visible = indice_genero == 4

	var skin_path := str(personaje.get("skin", ""))
	var seleccionado := false
	for i in range(_aspectos_list.item_count):
		if str(_aspectos_list.get_item_metadata(i)) == skin_path:
			_aspectos_list.select(i)
			seleccionado = true
			break
	if not seleccionado and _aspectos_list.item_count > 0:
		_aspectos_list.select(0)


func _nombre_especie(valor: Variant) -> String:
	if valor is Dictionary:
		var especie: Dictionary = valor as Dictionary
		return str(especie.get("nombre", especie.get("name", especie.get("clave", "No especificada"))))
	if valor is String and not str(valor).strip_edges().is_empty():
		return str(valor)
	return "No especificada"


func _indice_genero(genero: String) -> int:
	match genero.strip_edges().to_lower():
		"el": return 0
		"ella": return 1
		"elle": return 2
		"eso": return 3
		"sin_genero", "sin género": return 5
		_: return 4


func _guardar_edicion_partida() -> void:
	if _id_pendiente_editar.is_empty():
		return
	var nombre_mundo := _nombre_mundo_input.text.strip_edges()
	var nombre_personaje := _nombre_personaje_input.text.strip_edges()
	if nombre_mundo.is_empty():
		_mostrar_estado_edicion("El nombre del mundo no puede estar vacío.")
		return
	if nombre_personaje.is_empty():
		_mostrar_estado_edicion("El nombre del personaje no puede estar vacío.")
		return
	var seleccionados := _aspectos_list.get_selected_items()
	if seleccionados.is_empty():
		_mostrar_estado_edicion("Selecciona un aspecto para el personaje.")
		return

	var genero := _genero_input.get_item_text(_genero_input.selected)
	if _genero_input.selected == 4:
		genero = _genero_libre_input.text.strip_edges()
		if genero.is_empty():
			_mostrar_estado_edicion("Escribe el género del personaje.")
			return
	elif _genero_input.selected == 5:
		genero = "sin_genero"

	var skin_path := str(_aspectos_list.get_item_metadata(seleccionados[0]))
	if GameState.actualizar_personaje_partida(_id_pendiente_editar, nombre_mundo, nombre_personaje, genero, skin_path):
		_id_pendiente_editar = ""
		_salir_editor_partida()
		actualizar_lista()
		_mostrar_estado_edicion("Cambios guardados.")
	else:
		_mostrar_estado_edicion("No se pudieron guardar los cambios.")


func _mostrar_estado_edicion(mensaje: String) -> void:
	status_label.visible = true
	status_label.text = mensaje


func _cancelar_edicion_partida() -> void:
	_id_pendiente_editar = ""
	_salir_editor_partida()


func _salir_editor_partida() -> void:
	if _editor_container != null:
		_editor_container.visible = false
	scroll_container.visible = true
	create_button.visible = true
	title_label.visible = false
	subtitle_label.visible = false
	back_button.visible = true


func _on_create_pressed() -> void:
	character_creation.z_index = 4000
	character_creation.open("nueva_partida")


func _on_back_pressed() -> void:
	queue_free()


func _on_character_cancelled() -> void:
	status_label.text = "Creación de personaje cancelada."


func _on_character_confirmed(
	config: Dictionary,
	_action: String
) -> void:
	var nombre_partida := str(config.get("nombre_partida", "")).strip_edges()
	var semilla := str(config.get("semilla", "")).strip_edges()
	if nombre_partida.is_empty():
		status_label.text = "Ponle un nombre a la partida."
		return

	var id: String = GameState.crear_partida(
		nombre_partida,
		semilla,
		config
	)

	if id.is_empty():
		status_label.text = "No se pudo crear la partida."
		return

	visible = false

	if not GameState.iniciar_partida(id):
		visible = true
		status_label.text = "Se creó la partida, pero no pudo abrirse."
