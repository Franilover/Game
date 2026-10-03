extends CanvasLayer
class_name AdminConsole


var _panel: PanelContainer
var _historial: RichTextLabel
var _entrada: LineEdit

var _sugerencias_panel: PanelContainer
var _sugerencias_scroll: ScrollContainer
var _sugerencias_lista: VBoxContainer

var _abierto: bool = false
var _sugerencias: Array[String] = []


const COMANDO_SUMMON: String = "/summon"
const COMANDO_GIVE: String = "/give"
const COMANDO_TIME: String = "/time"
const COMANDO_TP: String = "/tp"
const MAX_SUGERENCIAS_VISIBLES: int = 8
const ANCHO_SUGERENCIAS: float = 320.0
const ALTURA_SUGERENCIAS_POR_FILA: float = 22.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	add_to_group("admin_console")

	_crear_interfaz()
	visible = false

	if WorldData.has_signal("mundo_listo"):
		WorldData.mundo_listo.connect(
			_al_datos_disponibles
		)

	if GarliaWorldItems.has_signal("catalogo_cargado"):
		GarliaWorldItems.catalogo_cargado.connect(
			_al_datos_disponibles
		)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var tecla: InputEventKey = event as InputEventKey

	if not tecla.pressed or tecla.echo:
		return

	if not _abierto:
		if tecla.keycode == KEY_T:
			abrir()
			get_viewport().set_input_as_handled()

		return

	if tecla.keycode == KEY_ESCAPE:
		cerrar()
		get_viewport().set_input_as_handled()


func _shortcut_input(_event: InputEvent) -> void:
	if not _abierto:
		return

	get_viewport().set_input_as_handled()


func abrir() -> void:
	if _abierto:
		return

	_abierto = true
	visible = true

	get_tree().paused = true

	_entrada.clear()
	_entrada.grab_focus()
	_ocultar_sugerencias()

	_agregar_linea("[ADMIN] Consola abierta.")


func cerrar() -> void:
	if not _abierto:
		return

	_abierto = false
	visible = false

	_entrada.release_focus()
	_ocultar_sugerencias()

	get_tree().paused = false


func esta_abierta() -> bool:
	return _abierto


func _crear_interfaz() -> void:
	_panel = PanelContainer.new()
	_panel.name = "AdminPanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 12.0
	_panel.offset_top = 12.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = 120.0

	add_child(_panel)

	var columna: VBoxContainer = VBoxContainer.new()
	columna.name = "Column"
	_panel.add_child(columna)

	var titulo: Label = Label.new()
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
	_entrada.placeholder_text = "/summon <criatura>"
	_entrada.clear_button_enabled = true
	_entrada.text_submitted.connect(
		_al_enviar_comando
	)
	_entrada.text_changed.connect(
		_al_texto_cambiado
	)
	_entrada.gui_input.connect(
		_al_input_entrada
	)

	columna.add_child(_entrada)

	_crear_panel_sugerencias()


func _crear_panel_sugerencias() -> void:
	_sugerencias_panel = PanelContainer.new()
	_sugerencias_panel.name = "CommandSuggestions"
	_sugerencias_panel.visible = false
	_sugerencias_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sugerencias_panel.custom_minimum_size = Vector2(
		ANCHO_SUGERENCIAS,
		0.0
	)
	_sugerencias_panel.z_index = 10

	add_child(_sugerencias_panel)

	_sugerencias_scroll = ScrollContainer.new()
	_sugerencias_scroll.name = "Scroll"
	_sugerencias_scroll.custom_minimum_size = Vector2(
		ANCHO_SUGERENCIAS,
		ALTURA_SUGERENCIAS_POR_FILA * MAX_SUGERENCIAS_VISIBLES
	)
	_sugerencias_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sugerencias_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sugerencias_panel.add_child(_sugerencias_scroll)

	_sugerencias_lista = VBoxContainer.new()
	_sugerencias_lista.name = "List"
	_sugerencias_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sugerencias_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sugerencias_scroll.add_child(_sugerencias_lista)


func _al_texto_cambiado(_texto: String) -> void:
	if not _abierto:
		return

	_actualizar_sugerencias()


func _al_input_entrada(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var tecla: InputEventKey = event as InputEventKey

	if not tecla.pressed or tecla.echo:
		return

	if tecla.keycode != KEY_TAB:
		return

	if _sugerencias.is_empty():
		return

	_completar_sugerencia(_sugerencias[0])
	get_viewport().set_input_as_handled()


func _actualizar_sugerencias() -> void:
	var texto: String = _entrada.text

	if _es_comando_con_sugerencias(texto, COMANDO_SUMMON):
		_mostrar_sugerencias_summon(texto)
		return

	if _es_comando_con_sugerencias(texto, COMANDO_TP):
		_mostrar_sugerencias_tp(texto)
		return

	if _es_comando_con_sugerencias(texto, COMANDO_PLAYER):
		_mostrar_sugerencias(_obtener_nombres_jugadores(), COMANDO_PLAYER)
		return

	if _es_comando_con_sugerencias(texto, COMANDO_GIVE):
		if GarliaWorldItems.catalogo.is_empty():
			GarliaWorldItems.cargar_catalogo()

		var nombre_parcial: String = _extraer_argumento(texto, COMANDO_GIVE)
		_mostrar_sugerencias(
			_filtrar_nombres(
				_obtener_nombres_objetos(),
				nombre_parcial
			),
			COMANDO_GIVE
		)
		return

	_ocultar_sugerencias()


func _mostrar_sugerencias_tp(texto: String) -> void:
	var argumento := _extraer_argumento(texto, COMANDO_TP)
	var partes := argumento.split(" ", false)
	var tipos: Array[String] = ["criatura", "reino", "jugador", "humano"]

	if partes.is_empty():
		_mostrar_sugerencias(tipos, COMANDO_TP)
		return

	if partes.size() == 1 and not texto.ends_with(" "):
		_mostrar_sugerencias(_filtrar_nombres(tipos, partes[0]), COMANDO_TP)
		return

	var tipo := partes[0].to_lower()
	var parcial := ""
	if partes.size() >= 2:
		parcial = partes[1]

	var nombres: Array[String] = []
	match tipo:
		"criatura":
			nombres = _obtener_nombres_criaturas()
		"humano":
			nombres = _obtener_nombres_personajes_game()
		"reino":
			for reino in WorldData.obtener_reinos_game():
				var nombre := str(reino.get("nombre", "")).strip_edges()
				if not nombre.is_empty():
					nombres.append(nombre)
		"jugador":
			var jugador := get_tree().get_first_node_in_group("player")
			if jugador != null:
				nombres.append(jugador.name)
		_:
			_mostrar_sugerencias([], COMANDO_TP)
			return

	_mostrar_sugerencias(_filtrar_nombres(nombres, parcial), COMANDO_TP)

func _mostrar_sugerencias_summon(
	texto: String
) -> void:
	var argumento_crudo: String = texto.substr(
		COMANDO_SUMMON.length()
	)

	var argumento: String = argumento_crudo.strip_edges()
	var partes: PackedStringArray = PackedStringArray()

	if not argumento.is_empty():
		partes = argumento.split(
			" ",
			false
		)

	# Una segunda palabra después de "Humano" significa que
	# el usuario está eligiendo un personaje individual.
	var es_humano: bool = (
		not partes.is_empty()
		and partes[0].to_lower() == "humano"
	)

	if es_humano and (
		partes.size() >= 2
		or texto.ends_with(" ")
	):
		var nombre_parcial: String = ""

		if partes.size() >= 2:
			nombre_parcial = partes[1]

		var criatura_humana: Dictionary = (
			WorldData.buscar_criatura_por_nombre(
				"Humano"
			)
		)

		var nombres_personajes: Array[String] = []

		if not criatura_humana.is_empty():
			var personajes: Array[Dictionary] = (
				WorldData.obtener_personajes_game_de_criatura(
					str(
						criatura_humana.get(
							"id",
							""
						)
					)
				)
			)

			for personaje in personajes:
				var nombre_personaje: String = str(
					personaje.get(
						"nombre",
						""
					)
				).strip_edges()

				if nombre_personaje.is_empty():
					continue

				nombres_personajes.append(
					nombre_personaje
				)

		_mostrar_sugerencias(
				_filtrar_nombres(
					nombres_personajes,
					nombre_parcial
				),
			COMANDO_SUMMON
		)
		return

	var nombre_parcial: String = _extraer_argumento(
		texto,
		COMANDO_SUMMON
	)

	var nombres_summon: Array[String] = (
		_obtener_nombres_criaturas()
	)

	nombres_summon.append_array(
		_obtener_nombres_personajes_game()
	)

	nombres_summon = _deduplicar_nombres(
		nombres_summon
	)

	_mostrar_sugerencias(
		_filtrar_nombres(
			nombres_summon,
			nombre_parcial
		),
		COMANDO_SUMMON
	)


func _mostrar_sugerencias(
	nombres: Array[String],
	_comando: String
) -> void:
	_sugerencias = nombres

	for hijo in _sugerencias_lista.get_children():
		hijo.queue_free()

	if _sugerencias.is_empty():
		_ocultar_sugerencias()
		return

	for nombre in _sugerencias:
		var fila: Label = Label.new()
		fila.text = nombre
		fila.custom_minimum_size = Vector2(
			ANCHO_SUGERENCIAS - 12.0,
			ALTURA_SUGERENCIAS_POR_FILA
		)
		fila.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_theme_font_size_override(
			"font_size",
			11
		)
		_sugerencias_lista.add_child(fila)

	_sugerencias_panel.visible = true
	_actualizar_posicion_sugerencias()


func _ocultar_sugerencias() -> void:
	_sugerencias.clear()

	if is_instance_valid(_sugerencias_panel):
		_sugerencias_panel.visible = false


func _actualizar_posicion_sugerencias() -> void:
	if not is_instance_valid(_sugerencias_panel):
		return

	if not is_instance_valid(_entrada):
		return

	var posicion: Vector2 = _entrada.global_position
	posicion.y += _entrada.size.y + 4.0

	_sugerencias_panel.global_position = posicion


func _obtener_nombres_criaturas() -> Array[String]:
	var nombres: Array[String] = []

	if not WorldData.has_method("obtener_criaturas"):
		return nombres

	var criaturas: Array[Dictionary] = WorldData.obtener_criaturas()

	for criatura in criaturas:
		var nombre: String = str(
			criatura.get("nombre", "")
		).strip_edges()

		if nombre.is_empty():
			continue

		if nombre in nombres:
			continue

		nombres.append(nombre)

	nombres.sort()
	return nombres


func _obtener_nombres_personajes_game() -> Array[String]:
	var nombres: Array[String] = []

	if not WorldData.has_method("obtener_personajes_game"):
		return nombres

	var personajes: Array[Dictionary] = (
		WorldData.obtener_personajes_game()
	)

	for personaje in personajes:
		var nombre: String = str(
			personaje.get(
				"nombre",
				""
			)
		).strip_edges()

		if nombre.is_empty():
			continue

		nombres.append(nombre)

	nombres.sort()
	return nombres


func _deduplicar_nombres(
	nombres: Array[String]
) -> Array[String]:
	var resultado: Array[String] = []

	for nombre in nombres:
		if nombre.is_empty():
			continue

		if nombre in resultado:
			continue

		resultado.append(nombre)

	resultado.sort()
	return resultado


func _obtener_nombres_objetos() -> Array[String]:
	var nombres: Array[String] = []
	var catalogo: Array[Dictionary] = GarliaWorldItems.catalogo

	for item in catalogo:
		var nombre: String = str(
			item.get("nombre", "")
		).strip_edges()

		if nombre.is_empty():
			continue

		if nombre in nombres:
			continue

		nombres.append(nombre)

	nombres.sort()
	return nombres


func _filtrar_nombres(
	nombres: Array[String],
	filtro: String
) -> Array[String]:
	var resultado: Array[String] = []
	var coincidencias_parciales: Array[String] = []
	var buscado: String = filtro.to_lower().strip_edges()

	for nombre in nombres:
		var nombre_lower: String = nombre.to_lower()

		if buscado.is_empty() or nombre_lower.begins_with(buscado):
			resultado.append(nombre)
		elif nombre_lower.contains(buscado):
			coincidencias_parciales.append(nombre)

	resultado.append_array(coincidencias_parciales)
	return resultado


func _es_comando_con_sugerencias(
	texto: String,
	comando: String
) -> bool:
	var limpio: String = texto.strip_edges().to_lower()
	var comando_minusculas: String = comando.to_lower()

	return (
		limpio == comando_minusculas
		or limpio.begins_with(comando_minusculas + " ")
	)


func _extraer_argumento(
	texto: String,
	comando: String
) -> String:
	if not _es_comando_con_sugerencias(texto, comando):
		return ""

	var limpio: String = texto.strip_edges()

	if limpio.to_lower() == comando.to_lower():
		return ""

	return texto.substr(comando.length()).strip_edges()


func _completar_sugerencia(nombre: String) -> void:
	var comando: String = _comando_actual()

	if comando.is_empty():
		return

	var prefijo: String = comando + " "

	if comando == COMANDO_SUMMON:
		var argumento_crudo: String = _entrada.text.substr(
			COMANDO_SUMMON.length()
		)
		var partes: PackedStringArray = PackedStringArray()

		if not argumento_crudo.strip_edges().is_empty():
			partes = argumento_crudo.strip_edges().split(
				" ",
				false
			)

		if (
			not partes.is_empty()
			and partes[0].to_lower() == "humano"
			and (
				partes.size() >= 2
				or _entrada.text.ends_with(" ")
			)
		):
			prefijo = COMANDO_SUMMON + " Humano "

	elif comando == COMANDO_TP:
		var argumento_crudo: String = _entrada.text.substr(
			COMANDO_TP.length()
		)
		var partes: PackedStringArray = PackedStringArray()

		if not argumento_crudo.strip_edges().is_empty():
			partes = argumento_crudo.strip_edges().split(
				" ",
				false
			)

		if not partes.is_empty():
			var tipo: String = partes[0]
			if partes.size() >= 2 or _entrada.text.ends_with(" "):
				prefijo = COMANDO_TP + " " + tipo + " "

	_entrada.text = prefijo + nombre
	_entrada.caret_column = _entrada.text.length()
	_actualizar_sugerencias()
	_entrada.grab_focus()


func _comando_actual() -> String:
	var texto: String = _entrada.text

	if _es_comando_con_sugerencias(texto, COMANDO_SUMMON):
		return COMANDO_SUMMON

	if _es_comando_con_sugerencias(texto, COMANDO_GIVE):
		return COMANDO_GIVE

	if _es_comando_con_sugerencias(texto, COMANDO_TP):
		return COMANDO_TP

	if _es_comando_con_sugerencias(texto, COMANDO_PLAYER):
		return COMANDO_PLAYER

	return ""


func _al_datos_disponibles(_datos: Variant = null) -> void:
	if not _abierto:
		return

	_actualizar_sugerencias()


func _al_enviar_comando(texto: String) -> void:
	var comando: String = texto.strip_edges()

	if comando.is_empty():
		return

	_agregar_linea(
		"> " + comando
	)

	_entrada.clear()
	_ocultar_sugerencias()

	_ejecutar_comando(comando)

	if _abierto:
		_entrada.grab_focus()


func _ejecutar_comando(comando: String) -> void:
	if not comando.begins_with("/"):
		_agregar_linea(
			"[color=#d88]"
			+ "Los comandos deben comenzar con /"
			+ "[/color]"
		)
		return

	var separador: int = comando.find(" ")
	var nombre_comando: String
	var argumentos: String

	if separador < 0:
		nombre_comando = comando.to_lower()
		argumentos = ""
	else:
		nombre_comando = comando.substr(0, separador).to_lower()
		argumentos = comando.substr(separador + 1).strip_edges()

	match nombre_comando:
		"/help":
			_comando_help()

		"/summon":
			_comando_summon(argumentos)

		"/give":
			_comando_give(argumentos)

		"/time":
			_comando_time(argumentos)

		"/tp":
			_comando_tp(argumentos)

		"/player":
			_comando_player(argumentos)

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
		+ "/give <objeto>"
		+ "[/color]"
	)

	_agregar_linea(
		"[color=#b4befe]"
		+ "/time <lock|day|night|restart>"
		+ "[/color]"
	)

	_agregar_linea(
		"[color=#b4befe]"
		+ "/tp <criatura|reino|jugador|humano> <nombre>"
		+ "[/color]"
	)

	_agregar_linea(
		"[color=#b4befe]"
		+ "/player <nombre> — editar jugador"
		+ "[/color]"
	)

	_agregar_linea(
		"[color=#b4befe]"
		+ "/help"
		+ "[/color]"
	)


func _comando_summon(nombre: String) -> void:
	var nombre_solicitado: String = nombre.strip_edges()

	if nombre_solicitado.is_empty():
		_agregar_linea(
			"[color=#d88]"
			+ "Uso: /summon <criatura> o /summon Humano <personaje>"
			+ "[/color]"
		)
		return

	var world_generator: Node = (
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

	# Primero intentamos el texto completo. Esto permite criaturas
	# cuyos nombres tienen espacios y evita interpretar sus nombres
	# como si fueran argumentos especiales de Humano.
	var resultado: Variant = (
		world_generator.call(
			"summon_criatura",
			nombre_solicitado
		)
	)

	if resultado is Dictionary:
		var datos: Dictionary = resultado as Dictionary

		if bool(datos.get("ok", false)):
			_agregar_linea(
				"[color=#9fd18b]"
				+ "Invocada: "
				+ str(datos.get("nombre", nombre_solicitado))
				+ "[/color]"
			)
			return

		# Si no era una criatura/personaje directo, probamos la sintaxis
		# explícita /summon Humano <personaje>.
		var partes: PackedStringArray = nombre_solicitado.split(" ", false)

		if partes.size() >= 2 and partes[0].to_lower() == "humano":
			var nombre_personaje := " ".join(
				partes.slice(1)
			).strip_edges()

			if not nombre_personaje.is_empty():
				resultado = world_generator.call(
					"summon_criatura",
					nombre_personaje
				)

				if resultado is Dictionary:
					datos = resultado as Dictionary

					if bool(datos.get("ok", false)):
						_agregar_linea(
							"[color=#9fd18b]"
							+ "Invocado: "
							+ str(datos.get(
								"nombre",
								nombre_personaje
							))
							+ "[/color]"
						)
						return

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
		return

	_agregar_linea(
		"[color=#d88]"
		+ "No se pudo ejecutar /summon."
		+ "[/color]"
	)

func _obtener_nombres_jugadores() -> Array[String]:
	var nombres: Array[String] = []
	var jugador := get_tree().get_first_node_in_group("player")
	if jugador != null:
		var nombre := str(jugador.get("personaje_nombre")).strip_edges()
		if nombre.is_empty():
			nombre = jugador.name
		nombres.append(nombre)
	return nombres


func _comando_player(nombre: String) -> void:
	var nombre_solicitado := nombre.strip_edges()
	if nombre_solicitado.is_empty():
		_agregar_linea("[color=#d88]Uso: /player <nombre>[/color]")
		return

	var jugador := get_tree().get_first_node_in_group("player")
	if jugador == null:
		_agregar_linea("[color=#d88]No se encontró el jugador.[/color]")
		return

	var nombre_actual := str(jugador.get("personaje_nombre")).strip_edges()
	if nombre_actual.is_empty():
		nombre_actual = jugador.name

	if nombre_solicitado.to_lower() != nombre_actual.to_lower() and nombre_solicitado.to_lower() not in ["player", "jugador"]:
		_agregar_linea("[color=#d88]No encontré al jugador: " + nombre_solicitado + ".[/color]")
		return

	var editor := get_tree().current_scene.get_node_or_null("AdminPlayerEditor")
	if editor == null:
		var script := load("res://scripts/ui/admin_player_editor.gd")
		if script == null:
			_agregar_linea("[color=#d88]No se pudo cargar el editor de jugador.[/color]")
			return
		editor = Control.new()
		editor.name = "AdminPlayerEditor"
		editor.set_script(script)
		get_tree().current_scene.add_child(editor)

	if not editor.has_method("abrir"):
		_agregar_linea("[color=#d88]El editor de jugador no es válido.[/color]")
		return

	get_tree().paused = false
	_abierto = false
	visible = false
	editor.call("abrir", jugador)



func _comando_tp(argumentos: String) -> void:
	var partes := argumentos.split(" ", false)
	if partes.size() < 2:
		_agregar_linea("[color=#d88]Uso: /tp <criatura|reino|jugador|humano> <nombre>[/color]")
		return

	var tipo := partes[0].strip_edges().to_lower()
	var nombre := " ".join(partes.slice(1)).strip_edges()
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null:
		_agregar_linea("[color=#d88]No se encontró el jugador.[/color]")
		return

	var posicion := Vector2.INF

	match tipo:
		"criatura":
			for nodo in get_tree().get_nodes_in_group("creatures"):
				if nodo is Creature:
					var criatura := nodo as Creature
					if criatura.get_nombre_visual().to_lower() == nombre.to_lower() or criatura.get_nombre().to_lower() == nombre.to_lower():
						posicion = criatura.global_position
						break

		"humano":
			for nodo in get_tree().get_nodes_in_group("creatures"):
				if nodo is Creature:
					var humano := nodo as Creature
					if humano.get_nombre().to_lower() == "humano" and humano.get_nombre_visual().to_lower() == nombre.to_lower():
						posicion = humano.global_position
						break

		"jugador":
			if jugador.name.to_lower() == nombre.to_lower() or nombre.to_lower() == "player" or nombre.to_lower() == "jugador":
				posicion = jugador.global_position

		"reino":
			var world_generator := get_tree().get_first_node_in_group("world_generator")
			if world_generator != null and world_generator.has_method("buscar_posicion_reino"):
				posicion = world_generator.call("buscar_posicion_reino", nombre)

		_:
			_agregar_linea("[color=#d88]Tipo desconocido. Usa criatura, reino, jugador o humano.[/color]")
			return

	if posicion.is_equal_approx(Vector2.INF):
		_agregar_linea("[color=#d88]No encontré " + tipo + ": " + nombre + ".[/color]")
		return

	jugador.global_position = posicion
	_agregar_linea("[color=#9fd18b]Teletransportado a " + tipo + ": " + nombre + ".[/color]")

func _comando_give(nombre: String) -> void:
	var nombre_objeto: String = nombre.strip_edges()

	if nombre_objeto.is_empty():
		_agregar_linea(
			"[color=#d88]"
			+ "Uso: /give <objeto>"
			+ "[/color]"
		)
		return

	var item: Dictionary = (
		GarliaWorldItems.buscar_item_por_nombre(
			nombre_objeto
		)
	)

	if item.is_empty():
		_agregar_linea(
			"[color=#d88]"
			+ "No existe un objeto llamado "
			+ nombre_objeto
			+ "."
			+ "[/color]"
		)
		return

	var inventario: Node = (
		get_tree().get_first_node_in_group(
			"inventory"
		)
	)

	if inventario == null:
		_agregar_linea(
			"[color=#d88]"
			+ "No se encontró el inventario."
			+ "[/color]"
		)
		return

	if not inventario.has_method("agregar_objeto"):
		_agregar_linea(
			"[color=#d88]"
			+ "El inventario no puede recibir objetos."
			+ "[/color]"
		)
		return

	item["cantidad"] = 1

	var agregado: bool = bool(
		inventario.call(
			"agregar_objeto",
			item
		)
	)

	if not agregado:
		_agregar_linea(
			"[color=#d88]"
			+ "No hay espacio en el inventario."
			+ "[/color]"
		)
		return

	_agregar_linea(
		"[color=#9fd18b]"
		+ "Obtenido: "
		+ str(item.get("nombre", nombre_objeto))
		+ "[/color]"
	)


func _comando_time(argumentos: String) -> void:
	var subcomando: String = argumentos.strip_edges().to_lower()

	if subcomando.is_empty():
		_agregar_linea(
			"[color=#d88]"
			+ "Uso: /time <lock|day|night|restart>"
			+ "[/color]"
		)
		return

	var world_generator: Node = (
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

	var atmosfera: Node = world_generator.get_node_or_null(
		"WorldAtmosphere"
	)

	if atmosfera == null:
		_agregar_linea(
			"[color=#d88]"
			+ "No se encontró WorldAtmosphere."
			+ "[/color]"
		)
		return

	match subcomando:
		"lock":
			if not atmosfera.has_method("bloquear_tiempo"):
				_agregar_linea(
					"[color=#d88]"
					+ "WorldAtmosphere no admite /time lock."
					+ "[/color]"
				)
				return

			atmosfera.call("bloquear_tiempo")
			_agregar_linea(
				"[color=#9fd18b]"
				+ "Tiempo bloqueado."
				+ "[/color]"
			)

		"day":
			if not atmosfera.has_method("establecer_dia"):
				_agregar_linea(
					"[color=#d88]"
					+ "WorldAtmosphere no admite /time day."
					+ "[/color]"
				)
				return

			if bool(atmosfera.call("establecer_dia")):
				_agregar_linea(
					"[color=#9fd18b]"
					+ "Hora establecida: 12:00."
					+ "[/color]"
				)
			else:
				_agregar_linea(
					"[color=#d88]"
					+ "El calendario todavía no está cargado."
					+ "[/color]"
				)

		"night":
			if not atmosfera.has_method("establecer_noche"):
				_agregar_linea(
					"[color=#d88]"
					+ "WorldAtmosphere no admite /time night."
					+ "[/color]"
				)
				return

			if bool(atmosfera.call("establecer_noche")):
				_agregar_linea(
					"[color=#9fd18b]"
					+ "Hora establecida: 00:00."
					+ "[/color]"
				)
			else:
				_agregar_linea(
					"[color=#d88]"
					+ "El calendario todavía no está cargado."
					+ "[/color]"
				)

		"restart":
			if not atmosfera.has_method("reiniciar_tiempo"):
				_agregar_linea(
					"[color=#d88]"
					+ "WorldAtmosphere no admite /time restart."
					+ "[/color]"
				)
				return

			if bool(atmosfera.call("reiniciar_tiempo")):
				_agregar_linea(
					"[color=#9fd18b]"
					+ "Tiempo reiniciado al inicio del calendario y desbloqueado."
					+ "[/color]"
				)
			else:
				_agregar_linea(
					"[color=#d88]"
					+ "El calendario todavía no está cargado."
					+ "[/color]"
				)

		_:
			_agregar_linea(
				"[color=#d88]"
				+ "Subcomando desconocido. Usa /time lock, /time day, /time night o /time restart."
				+ "[/color]"
			)


func _agregar_linea(texto: String) -> void:
	if not is_instance_valid(_historial):
		return

	_historial.append_text(
		"\n" + texto
	)
