extends Control

@onready var list_container: VBoxContainer = $Panel/Margin/Column/Scroll/Partidas
@onready var status_label: Label = $Panel/Margin/Column/Status
@onready var character_creation: Control = $CharacterCreation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	actualizar_lista()
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
	panel.custom_minimum_size = Vector2(0, 68)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = str(partida.get("nombre", "Partida"))
	title.add_theme_font_size_override("font_size", 16)
	info.add_child(title)

	var detail := Label.new()
	detail.text = _texto_detalle(partida)
	detail.add_theme_font_size_override("font_size", 10)
	info.add_child(detail)

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


func _texto_detalle(partida: Dictionary) -> String:
	var minutos := int(
		float(partida.get("play_time", 0.0)) / 60.0
	)
	var horas := minutos / 60
	var minutos_restantes := minutos % 60

	var tiempo := "Tiempo: " + str(horas) + " h " + str(
		minutos_restantes
	) + " min"

	var actualizado := str(
		partida.get("actualizado_en", "")
	)

	var semilla := str(partida.get("semilla", "—"))

	return (
		tiempo + "    ·    Semilla: " + semilla
		+ "    ·    Último guardado: " + actualizado
	)


func _jugar_partida(id: String) -> void:
	if id.is_empty():
		return

	visible = false

	if not GameState.iniciar_partida(id):
		visible = true
		status_label.text = "No se pudo abrir la partida."


func _eliminar_partida(id: String) -> void:
	if id.is_empty():
		return

	if GameState.eliminar_partida(id):
		actualizar_lista()
		status_label.text = "Partida eliminada."
	else:
		status_label.text = "No se pudo eliminar la partida."


func _on_create_pressed() -> void:
	character_creation.z_index = 10000
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
