extends Control

@onready var list_container: VBoxContainer = $Panel/Margin/Column/Scroll/Partidas
@onready var status_label: Label = $Panel/Margin/Column/Status
@onready var character_creation: Control = $CharacterCreation
var _confirmacion_borrado: ConfirmationDialog
var _dialogo_edicion: ConfirmationDialog
var _nombre_edicion: LineEdit
var _semilla_edicion: LineEdit
var _id_pendiente_borrar: String = ""
var _id_pendiente_editar: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	actualizar_lista()
	_configurar_confirmacion_borrado()
	_configurar_dialogo_edicion()
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


func _configurar_dialogo_edicion() -> void:
	_dialogo_edicion = ConfirmationDialog.new()
	_dialogo_edicion.title = "Editar mundo"
	_dialogo_edicion.ok_button_text = "Guardar cambios"
	_dialogo_edicion.cancel_button_text = "Cancelar"
	_dialogo_edicion.dialog_text = "Cambia el nombre o la semilla del mundo."
	_dialogo_edicion.confirmed.connect(_guardar_edicion_partida)
	_dialogo_edicion.exclusive = true

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 8)
	_dialogo_edicion.add_child(contenido)

	var nombre_label := Label.new()
	nombre_label.text = "Nombre del mundo"
	contenido.add_child(nombre_label)

	_nombre_edicion = LineEdit.new()
	_nombre_edicion.placeholder_text = "Nombre del mundo"
	_nombre_edicion.max_length = 64
	contenido.add_child(_nombre_edicion)

	var semilla_label := Label.new()
	semilla_label.text = "Semilla del mundo"
	contenido.add_child(semilla_label)

	_semilla_edicion = LineEdit.new()
	_semilla_edicion.placeholder_text = "Número entero"
	_semilla_edicion.max_length = 20
	contenido.add_child(_semilla_edicion)

	var aviso := Label.new()
	aviso.text = "Cambiar la semilla modifica el terreno generado. Puede no coincidir con zonas exploradas previamente."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(aviso)

	add_child(_dialogo_edicion)


func _editar_partida(id: String) -> void:
	if id.is_empty() or _dialogo_edicion == null:
		return

	var partida_encontrada: Dictionary = {}
	for partida in GameState.obtener_partidas():
		if str(partida.get("id", "")) == id:
			partida_encontrada = partida
			break

	if partida_encontrada.is_empty():
		status_label.visible = true
		status_label.text = "No se encontró ese mundo."
		return

	_id_pendiente_editar = id
	_nombre_edicion.text = str(partida_encontrada.get("nombre", "Partida"))
	_semilla_edicion.text = str(partida_encontrada.get("semilla", ""))
	_dialogo_edicion.popup_centered(Vector2i(520, 300))


func _guardar_edicion_partida() -> void:
	var id := _id_pendiente_editar
	_id_pendiente_editar = ""
	if id.is_empty():
		return

	var nombre := _nombre_edicion.text.strip_edges()
	var semilla := _semilla_edicion.text.strip_edges()
	status_label.visible = true
	if nombre.is_empty():
		status_label.text = "El nombre del mundo no puede estar vacío."
		return

	var regex := RegEx.new()
	regex.compile("^-?[0-9]+$")
	if semilla.is_empty() or regex.search(semilla) == null:
		status_label.text = "La semilla debe ser un número entero."
		return

	if GameState.actualizar_configuracion_partida(id, nombre, semilla):
		actualizar_lista()
		status_label.visible = true
		status_label.text = "Configuración del mundo guardada."
	else:
		status_label.text = "No se pudieron guardar los cambios."


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
