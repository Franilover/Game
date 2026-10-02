extends CanvasLayer
class_name AdminConsole


var _panel: PanelContainer
var _historial: RichTextLabel
var _entrada: LineEdit

var _abierto: bool = false


func _ready() -> void:
	layer = 100

	_crear_interfaz()

	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var tecla := event as InputEventKey

	if not tecla.pressed or tecla.echo:
		return

	if tecla.keycode == KEY_T:
		toggle()
		get_viewport().set_input_as_handled()
		return

	if tecla.keycode == KEY_ESCAPE and _abierto:
		cerrar()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _abierto:
		cerrar()
	else:
		abrir()


func abrir() -> void:
	_abierto = true
	visible = true

	_entrada.clear()
	_entrada.grab_focus()

	_agregar_linea(
		"[ADMIN] Consola abierta."
	)


func cerrar() -> void:
	_abierto = false
	visible = false

	_entrada.release_focus()


func _crear_interfaz() -> void:
	_panel = PanelContainer.new()
	_panel.name = "AdminPanel"

	_panel.set_anchors_preset(
		Control.PRESET_TOP_WIDE
	)

	_panel.offset_left = 12.0
	_panel.offset_top = 12.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = 120.0

	add_child(_panel)

	var columna := VBoxContainer.new()
	columna.name = "Column"

	_panel.add_child(columna)

	var titulo := Label.new()
	titulo.text = "ADMIN CONSOLE"

	titulo.add_theme_font_size_override(
		"font_size",
		12
	)

	columna.add_child(titulo)

	_historial = RichTextLabel.new()
	_historial.name = "Historial"

	_historial.bbcode_enabled = true
	_historial.fit_content = true
	_historial.custom_minimum_size = Vector2(
		0.0,
		48.0
	)

	_historial.text = (
		"[color=#b4befe]"
		+ "Garlia Admin"
		+ "[/color]\n"
		+ "Escribe /help para ver comandos."
	)

	columna.add_child(_historial)

	_entrada = LineEdit.new()
	_entrada.name = "CommandInput"

	_entrada.placeholder_text = (
		"/summon Aoris"
	)

	_entrada.clear_button_enabled = true

	_entrada.text_submitted.connect(
		_al_enviar_comando
	)

	columna.add_child(_entrada)


func _al_enviar_comando(
	texto: String
) -> void:
	var comando := texto.strip_edges()

	if comando.is_empty():
		return

	_agregar_linea(
		"> " + comando
	)

	_entrada.clear()

	_ejecutar_comando(
		comando
	)

	if _abierto:
		_entrada.grab_focus()


func _ejecutar_comando(
	comando: String
) -> void:
	if not comando.begins_with("/"):
		_agregar_linea(
			"[color=#d88]"
			+ "Los comandos deben comenzar con /"
			+ "[/color]"
		)
		return

	var partes := comando.split(
		" ",
		false
	)

	if partes.is_empty():
		return

	var nombre_comando := partes[0].to_lower()

	match nombre_comando:
		"/help":
			_comando_help()

		"/summon":
			_comando_summon(partes)

		_:
			_agregar_linea(
				"[color=#d88]"
				+ "Comando desconocido: "
				+ nombre_comando
				+ "[/color]"
			)


func _comando_help() -> void:
	_agregar_linea(
		"[color=#b4befe]"
		+ "/summon <criatura>"
		+ "[/color]"
	)

	_agregar_linea(
		"[color=#b4befe]"
		+ "/help"
		+ "[/color]"
	)


func _comando_summon(
	partes: Array[String]
) -> void:
	if partes.size() < 2:
		_agregar_linea(
			"[color=#d88]"
			+ "Uso: /summon <criatura>"
			+ "[/color]"
		)
		return

	var nombre := partes[1]

	var world_generator := (
		get_tree().get_first_node_in_group(
			"world_generator"
		)
	)

	if world_generator == null:
		_agregar_linea(
			"[color=#d88]"
			+ "No se encontró WorldGenerator."
			+ "[/color]"
		)
		return

	if not world_generator.has_method(
		"summon_criatura"
	):
		_agregar_linea(
			"[color=#d88]"
			+ "WorldGenerator no tiene summon_criatura()."
			+ "[/color]"
		)
		return

	var resultado: Variant = (
		world_generator.call(
			"summon_criatura",
			nombre
		)
	)

	if resultado is Dictionary:
		var datos := resultado as Dictionary

		if bool(
			datos.get(
				"ok",
				false
			)
		):
			_agregar_linea(
				"[color=#9fd18b]"
				+ "Invocada: "
				+ str(
					datos.get(
						"nombre",
						nombre
					)
				)
				+ "[/color]"
			)
		else:
			_agregar_linea(
				"[color=#d88]"
				+ str(
					datos.get(
						"mensaje",
						"No se pudo invocar."
					)
				)
				+ "[/color]"
			)
	else:
		_agregar_linea(
			"[color=#d88]"
			+ "No se pudo ejecutar /summon."
			+ "[/color]"
		)


func _agregar_linea(
	texto: String
) -> void:
	if not is_instance_valid(_historial):
		return

	_historial.append_text(
		"\n"
		+ texto
	)
