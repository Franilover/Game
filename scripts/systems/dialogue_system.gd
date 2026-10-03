extends Node


signal dialogue_started(speaker: String)
signal dialogue_finished


var player: Node = null
var ui_root: Node = null

var dialogue_panel: PanelContainer = null
var speaker_label: Label = null
var text_label: Label = null
var hint_label: Label = null
var action_button: Button = null
var cancel_button: Button = null
var _botones_accion: HBoxContainer = null

var _acciones: Array[Dictionary] = []

var _abierto: bool = false
var _lineas: Array[Dictionary] = []
var _indice_linea: int = 0
var _fuente: Node = null

var _texto_completo: String = ""
var _indice_caracter: int = 0
var _temporizador_texto: float = 0.0
var _intervalo_caracter: float = 0.018


func _ready() -> void:
	add_to_group("dialogue_system")


func configurar(nuevo_player: Node, nuevo_ui_root: Node) -> void:
	player = nuevo_player
	ui_root = nuevo_ui_root
	_crear_interfaz()


func _process(delta: float) -> void:
	if not _abierto:
		return

	if _indice_caracter >= _texto_completo.length():
		return

	_temporizador_texto -= delta
	if _temporizador_texto > 0.0:
		return

	_temporizador_texto = _intervalo_caracter
	_indice_caracter += 1
	text_label.text = _texto_completo.substr(0, _indice_caracter)
	_actualizar_boton_accion()


func _input(event: InputEvent) -> void:
	if not _abierto:
		return

	if event.is_action_pressed("primary_action"):
		if action_button != null and action_button.visible and event is InputEventMouseButton:
			return
		_avanzar()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_ESCAPE:
			cerrar()
			get_viewport().set_input_as_handled()


func esta_abierto() -> bool:
	return _abierto


func abrir_desde(fuente: Node) -> bool:
	print("DialogueSystem: abrir_desde() → ", fuente.name if is_instance_valid(fuente) else "<invalido>")
	if fuente == null or not is_instance_valid(fuente):
		print("DialogueSystem: fuente invalida.")
		return false

	if not fuente.has_method("get_dialogue_data"):
		print("DialogueSystem: la fuente no tiene get_dialogue_data().")
		return false

	var datos_variant: Variant = fuente.call("get_dialogue_data")
	print("DialogueSystem: datos recibidos = ", datos_variant is Dictionary, " | claves = ", datos_variant.keys() if datos_variant is Dictionary else [])
	if not datos_variant is Dictionary:
		return false

	return abrir(datos_variant as Dictionary, fuente)


func abrir(datos: Dictionary, fuente: Node = null) -> bool:
	print("DialogueSystem: abrir() | fuente = ", fuente.name if is_instance_valid(fuente) else "<ninguna>")
	var datos_seleccionados := _seleccionar_dialogo(datos)
	var lineas := _normalizar_lineas(datos_seleccionados)
	var acciones_debug: Array = []
	var acciones_variant_debug: Variant = datos_seleccionados.get("acciones", [])
	if acciones_variant_debug is Array:
		acciones_debug = acciones_variant_debug

	print(
		"DialogueSystem: variante = ",
		str(datos_seleccionados.get("clave", "<sin clave>")),
		" | lineas = ",
		lineas.size(),
		" | acciones = ",
		acciones_debug.size()
	)

	if lineas.is_empty():
		print("DialogueSystem: ABORTADO → no hay lineas normalizadas.")
		return false

	if dialogue_panel == null:
		_crear_interfaz()

	if dialogue_panel == null:
		return false

	_fuente = fuente

	if is_instance_valid(_fuente) and _fuente.has_method("get_personaje_game_id"):
		var personaje_id := str(_fuente.call("get_personaje_game_id")).strip_edges()
		if not personaje_id.is_empty():
			var mission_manager: Node = get_node_or_null("/root/MissionManager")
			if mission_manager != null:
				mission_manager.call(
					"registrar_dialogo_desde_fuente",
					personaje_id,
					str(datos_seleccionados.get("clave", "principal")),
					_fuente
				)
			var datos_actualizados := _seleccionar_dialogo(datos)
			if str(datos_actualizados.get("clave", "")) != str(datos_seleccionados.get("clave", "")):
				datos_seleccionados = datos_actualizados
				lineas = _normalizar_lineas(datos_seleccionados)
				if lineas.is_empty():
					return false

	_lineas = lineas
	_acciones.clear()

	var acciones_variant: Variant = datos_seleccionados.get("acciones", [])
	if acciones_variant is Array:
		for accion_variant in acciones_variant as Array:
			if accion_variant is Dictionary:
				_acciones.append((accion_variant as Dictionary).duplicate(true))

	_indice_linea = 0
	_abierto = true

	if is_instance_valid(_fuente):
		if _fuente.has_method("detener_movimiento"):
			_fuente.call("detener_movimiento")
		if _fuente.has_method("tomar_control_movimiento"):
			_fuente.call("tomar_control_movimiento")

	dialogue_panel.visible = true
	print(
		"DialogueSystem: PANEL VISIBLE → ",
		dialogue_panel.get_path(),
		" | pos=",
		dialogue_panel.position,
		" | size=",
		dialogue_panel.size
	)
	_mostrar_linea_actual()

	var hablante := str(_lineas[0].get("hablante", "")).strip_edges()
	if hablante.is_empty() and is_instance_valid(_fuente):
		if _fuente.has_method("get_nombre"):
			hablante = str(_fuente.call("get_nombre"))
		else:
			hablante = _fuente.name

	speaker_label.text = hablante
	dialogue_started.emit(hablante)
	Events.dialog_opened.emit(hablante, _texto_completo)

	return true


func cerrar() -> void:
	if not _abierto:
		return

	_abierto = false
	_lineas.clear()
	_indice_linea = 0
	_texto_completo = ""
	_indice_caracter = 0
	_temporizador_texto = 0.0

	if is_instance_valid(_fuente):
		if _fuente.has_method("liberar_control_movimiento"):
			_fuente.call("liberar_control_movimiento")

	_fuente = null
	_acciones.clear()

	if action_button != null:
		action_button.visible = false
	if cancel_button != null:
		cancel_button.visible = false

	if dialogue_panel != null:
		dialogue_panel.visible = false

	dialogue_finished.emit()
	Events.dialog_closed.emit()


func _avanzar() -> void:
	if _indice_caracter < _texto_completo.length():
		_indice_caracter = _texto_completo.length()
		text_label.text = _texto_completo
		return

	_indice_linea += 1

	if _indice_linea >= _lineas.size():
		cerrar()
		return

	_mostrar_linea_actual()


func _mostrar_linea_actual() -> void:
	if _lineas.is_empty() or _indice_linea < 0 or _indice_linea >= _lineas.size():
		return

	var linea: Dictionary = _lineas[_indice_linea]

	var hablante := str(linea.get("hablante", "")).strip_edges()
	if hablante.is_empty() and is_instance_valid(_fuente):
		if _fuente.has_method("get_nombre"):
			hablante = str(_fuente.call("get_nombre"))
		else:
			hablante = _fuente.name

	var texto := str(
		linea.get(
			"texto",
			linea.get("text", "")
		)
	).strip_edges()

	speaker_label.text = hablante
	_texto_completo = texto
	_indice_caracter = 0
	_temporizador_texto = 0.0
	text_label.text = ""
	hint_label.text = "[ LMB ] Continuar · [ ESC ] Cerrar"
	_actualizar_boton_accion()


func _seleccionar_dialogo(datos: Dictionary) -> Dictionary:
	var variantes_variant: Variant = datos.get("variantes", [])
	if not variantes_variant is Array:
		return datos.duplicate(true)

	var principal: Dictionary = {}
	for variante_variant in variantes_variant as Array:
		if not variante_variant is Dictionary:
			continue

		var variante := (variante_variant as Dictionary).duplicate(true)
		var requisito_variant: Variant = variante.get("requisito", {})

		if requisito_variant is Dictionary:
			var requisito := requisito_variant as Dictionary
			var mision_clave := str(requisito.get("mision_clave", "")).strip_edges()
			var estado_requerido := str(requisito.get("estado", "")).strip_edges().to_lower()

			if not mision_clave.is_empty() and not estado_requerido.is_empty():
				var mission_manager: Node = get_node_or_null("/root/MissionManager")
				if mission_manager == null:
					continue

				var mision: Dictionary = mission_manager.call("buscar_mision_por_clave", mision_clave)
				if mision.is_empty():
					continue

				var mision_id := str(mision.get("id", ""))
				var estado_actual := str(
					mission_manager.call("obtener_estado_mision", mision_id).get(
						"estado",
						"disponible"
					)
				).to_lower()

				if estado_actual == estado_requerido:
					return variante

				continue

		if str(variante.get("clave", "")).strip_edges().to_lower() == "principal":
			principal = variante

	if not principal.is_empty():
		return principal

	return datos.duplicate(true)


func _actualizar_boton_accion() -> void:
	if action_button == null:
		return

	if _acciones.is_empty():
		action_button.visible = false
		if cancel_button != null:
			cancel_button.visible = false
		return

	var texto_completo := _texto_completo.length()
	if _indice_caracter < texto_completo:
		action_button.visible = false
		if cancel_button != null:
			cancel_button.visible = false
		return

	var accion: Dictionary = _acciones[0]
	action_button.text = str(accion.get("texto", "Aceptar"))
	action_button.visible = true
	if cancel_button != null:
		cancel_button.visible = true


func _ejecutar_accion_dialogo() -> void:
	if _acciones.is_empty():
		return

	var accion: Dictionary = _acciones[0]
	var tipo := str(accion.get("tipo", "")).strip_edges().to_lower()

	match tipo:
		"aceptar_mision":
			var clave := str(accion.get("mision_clave", "")).strip_edges()
			if clave.is_empty():
				return

			var mission_manager: Node = get_node_or_null("/root/MissionManager")
			if mission_manager != null and bool(mission_manager.call("aceptar_mision", clave)):
				_acciones.clear()
				action_button.visible = false
				hint_label.text = "Misión aceptada · [ LMB ] Continuar"
				Events.notification_pushed.emit(
					"Misión aceptada: "
					+ str(mission_manager.call("buscar_mision_por_clave", clave).get("nombre", clave))
				)
				return

		"seguir_jugador":
			if is_instance_valid(_fuente) and _fuente.has_method("iniciar_seguimiento_jugador"):
				if _fuente.call("iniciar_seguimiento_jugador", player):
					_acciones.clear()
					action_button.visible = false
					hint_label.text = "Abel te está siguiendo · [ LMB ] Cerrar"
					return


func _normalizar_lineas(datos: Dictionary) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	var lineas_variant: Variant = datos.get(
		"lineas",
		datos.get("lines", [])
	)

	if not lineas_variant is Array:
		var texto := str(
			datos.get(
				"texto",
				datos.get("text", "")
			)
		).strip_edges()

		if not texto.is_empty():
			resultado.append({
				"texto": texto,
				"hablante": str(
					datos.get(
						"hablante",
						datos.get("speaker", "")
					)
				)
			})

		return resultado

	for linea_variant in lineas_variant as Array:
		if linea_variant is String:
			var texto_linea := str(linea_variant).strip_edges()
			if not texto_linea.is_empty():
				resultado.append({
					"texto": texto_linea,
					"hablante": ""
				})
			continue

		if not linea_variant is Dictionary:
			continue

		var linea := (linea_variant as Dictionary).duplicate(true)
		var texto := str(
			linea.get(
				"texto",
				linea.get("text", "")
			)
		).strip_edges()

		if texto.is_empty():
			continue

		resultado.append({
			"texto": texto,
			"hablante": str(
				linea.get(
					"hablante",
					linea.get("speaker", "")
				)
			).strip_edges()
		})

	return resultado


func _crear_interfaz() -> void:
	if ui_root == null:
		return

	if dialogue_panel != null and is_instance_valid(dialogue_panel):
		return

	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.visible = false
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.z_index = 3000
	# El HUD es el Control raíz dentro del CanvasLayer. Usamos
	# coordenadas relativas al centro inferior para no depender de
	# tamaños heredados de otros paneles del HUD.
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_panel.offset_left = -360.0
	dialogue_panel.offset_top = -238.0
	dialogue_panel.offset_right = 360.0
	dialogue_panel.offset_bottom = -18.0
	dialogue_panel.custom_minimum_size = Vector2(720.0, 220.0)
	dialogue_panel.size = Vector2(720.0, 220.0)
	dialogue_panel.clip_contents = false
	dialogue_panel.z_as_relative = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.05, 0.032, 0.97)
	style.border_color = Color(0.58, 0.43, 0.24, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	dialogue_panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 14)
	dialogue_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	speaker_label = Label.new()
	speaker_label.name = "Speaker"
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	speaker_label.add_theme_color_override(
		"font_color",
		Color(0.93, 0.84, 0.65, 1.0)
	)
	speaker_label.add_theme_font_size_override("font_size", 14)
	column.add_child(speaker_label)

	text_label = Label.new()
	text_label.name = "Text"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 76)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.75, 0.63, 1.0)
	)
	text_label.add_theme_font_size_override("font_size", 13)
	column.add_child(text_label)

	_botones_accion = HBoxContainer.new()
	_botones_accion.name = "DialogueActions"
	_botones_accion.alignment = BoxContainer.ALIGNMENT_CENTER
	_botones_accion.add_theme_constant_override("separation", 10)
	column.add_child(_botones_accion)

	action_button = Button.new()
	action_button.name = "DialogueAction"
	action_button.visible = false
	action_button.custom_minimum_size = Vector2(180, 34)
	action_button.add_theme_font_size_override("font_size", 11)
	action_button.pressed.connect(_ejecutar_accion_dialogo)
	_botones_accion.add_child(action_button)

	cancel_button = Button.new()
	cancel_button.name = "DialogueCancel"
	cancel_button.text = "Salir"
	cancel_button.visible = false
	cancel_button.custom_minimum_size = Vector2(120, 34)
	cancel_button.add_theme_font_size_override("font_size", 11)
	cancel_button.pressed.connect(cerrar)
	_botones_accion.add_child(cancel_button)

	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_color_override(
		"font_color",
		Color(0.55, 0.48, 0.38, 1.0)
	)
	hint_label.add_theme_font_size_override("font_size", 9)
	column.add_child(hint_label)

	ui_root.add_child(dialogue_panel)
	dialogue_panel.visible = false
