extends Control
class_name GarumiHub

const ENCYCLOPEDIA_SCRIPT: Script = preload("res://scripts/ui/encyclopedia.gd")
const TEXTO := Color(0.90, 0.79, 0.58, 1.0)
const SECUNDARIO := Color(0.65, 0.52, 0.35, 1.0)
const BORDE := Color(0.29, 0.19, 0.12, 1.0)

var _subtab: String = "garumis"
var _boton_garumis: Button
var _boton_garudex: Button
var _pagina_garumis: VBoxContainer
var _lista_vinculados: VBoxContainer
var _lista_amigos: VBoxContainer
var _garudex: Control
var _estado: Label
var _detalle: RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_interfaz()
	if GameState.has_signal("garumis_vinculados_actualizados") and not GameState.garumis_vinculados_actualizados.is_connected(actualizar):
		GameState.garumis_vinculados_actualizados.connect(actualizar)
	if GameState.has_signal("garumis_amigos_actualizados") and not GameState.garumis_amigos_actualizados.is_connected(actualizar):
		GameState.garumis_amigos_actualizados.connect(actualizar)
	actualizar()


func _crear_interfaz() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 5)
	margen.add_theme_constant_override("margin_right", 5)
	margen.add_theme_constant_override("margin_bottom", 5)
	add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 0)
	margen.add_child(columna)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	columna.add_child(tabs)
	_boton_garumis = _crear_boton_tab("Garumis")
	_boton_garumis.button_pressed = true
	_boton_garumis.pressed.connect(_mostrar_garumis)
	tabs.add_child(_boton_garumis)
	_boton_garudex = _crear_boton_tab("Garudex")
	_boton_garudex.pressed.connect(_mostrar_garudex)
	tabs.add_child(_boton_garudex)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	columna.add_child(body)
	_pagina_garumis = VBoxContainer.new()
	_pagina_garumis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pagina_garumis.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pagina_garumis.add_theme_constant_override("separation", 5)
	body.add_child(_pagina_garumis)

	var titulo_vinculados := Label.new()
	titulo_vinculados.text = "VÍNCULOS ACTIVOS · MÁXIMO 3"
	titulo_vinculados.add_theme_color_override("font_color", TEXTO)
	titulo_vinculados.add_theme_font_size_override("font_size", 11)
	_pagina_garumis.add_child(titulo_vinculados)
	_lista_vinculados = VBoxContainer.new()
	_lista_vinculados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_vinculados.add_theme_constant_override("separation", 3)
	_pagina_garumis.add_child(_lista_vinculados)

	var separador := HSeparator.new()
	separador.add_theme_color_override("separator", BORDE)
	_pagina_garumis.add_child(separador)
	var titulo_amigos := Label.new()
	titulo_amigos.text = "AMIGOS"
	titulo_amigos.add_theme_color_override("font_color", TEXTO)
	titulo_amigos.add_theme_font_size_override("font_size", 11)
	_pagina_garumis.add_child(titulo_amigos)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pagina_garumis.add_child(scroll)
	_lista_amigos = VBoxContainer.new()
	_lista_amigos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_amigos.add_theme_constant_override("separation", 3)
	scroll.add_child(_lista_amigos)

	_detalle = RichTextLabel.new()
	_detalle.bbcode_enabled = true
	_detalle.fit_content = false
	_detalle.scroll_active = true
	_detalle.custom_minimum_size = Vector2(155, 0)
	_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalle.add_theme_color_override("default_color", SECUNDARIO)
	_detalle.add_theme_font_size_override("normal_font_size", 11)
	body.add_child(_detalle)

	_garudex = Control.new()
	_garudex.name = "GarudexCatalog"
	_garudex.set_script(ENCYCLOPEDIA_SCRIPT)
	_garudex.set("solo_garumis", true)
	_garudex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_garudex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_garudex.visible = false
	body.add_child(_garudex)
	_estado = Label.new()
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.add_theme_color_override("font_color", SECUNDARIO)
	_estado.add_theme_font_size_override("font_size", 10)
	columna.add_child(_estado)


func _crear_boton_tab(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.custom_minimum_size = Vector2(0, 23)
	boton.add_theme_font_size_override("font_size", 11)
	boton.add_theme_color_override("font_color", SECUNDARIO)
	boton.add_theme_color_override("font_hover_color", TEXTO)
	boton.add_theme_color_override("font_pressed_color", TEXTO)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.075, 0.045, 0.95)
	normal.border_color = BORDE
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	boton.add_theme_stylebox_override("normal", normal)
	var activo := normal.duplicate() as StyleBoxFlat
	activo.bg_color = Color(0.28, 0.20, 0.12, 1)
	activo.border_color = Color(0.74, 0.62, 0.34, 1)
	activo.border_width_bottom = 2
	boton.add_theme_stylebox_override("pressed", activo)
	boton.add_theme_stylebox_override("hover", activo)
	boton.add_theme_stylebox_override("focus", activo)
	return boton


func abrir_en_garumis() -> void:
	_mostrar_garumis()


func _mostrar_garumis() -> void:
	_subtab = "garumis"
	_boton_garumis.button_pressed = true
	_boton_garudex.button_pressed = false
	_pagina_garumis.visible = true
	_detalle.visible = true
	_garudex.visible = false
	actualizar()


func _mostrar_garudex() -> void:
	_subtab = "garudex"
	_boton_garumis.button_pressed = false
	_boton_garudex.button_pressed = true
	_pagina_garumis.visible = false
	_detalle.visible = false
	_garudex.visible = true
	if _garudex.has_method("abrir_en_garumis"):
		_garudex.call("abrir_en_garumis")


func actualizar() -> void:
	if not is_instance_valid(_lista_vinculados):
		return
	for hijo in _lista_vinculados.get_children():
		hijo.queue_free()
	for hijo in _lista_amigos.get_children():
		hijo.queue_free()
	var vinculados: Array = GameState.call("obtener_garumis_vinculados") if GameState.has_method("obtener_garumis_vinculados") else []
	if vinculados.is_empty():
		_agregar_mensaje(_lista_vinculados, "No tienes vínculos activos.")
	else:
		for registro in vinculados:
			if registro is Dictionary:
				_agregar_fila(_lista_vinculados, registro as Dictionary, "Vinculado")
	var amigos: Array = GameState.call("obtener_garumis_amigos") if GameState.has_method("obtener_garumis_amigos") else []
	if amigos.is_empty():
		_agregar_mensaje(_lista_amigos, "Aún no tienes amigos Garumis.")
	else:
		for registro in amigos:
			if registro is Dictionary:
				_agregar_fila(_lista_amigos, registro as Dictionary, "Amigo")
	_estado.text = "%d/3 vinculados · %d amigos" % [vinculados.size(), amigos.size()]


func _agregar_fila(contenedor: VBoxContainer, registro: Dictionary, estado: String) -> void:
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 5)
	contenedor.add_child(fila)
	var nombre := str(registro.get("nombre", registro.get("criatura_nombre", "Garumi"))).strip_edges()
	if nombre.is_empty():
		nombre = "Garumi"
	var boton := Button.new()
	boton.text = nombre
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.custom_minimum_size = Vector2(0, 27)
	boton.add_theme_font_size_override("font_size", 10)
	boton.add_theme_color_override("font_color", TEXTO)
	boton.pressed.connect(_mostrar_detalle.bind(registro.duplicate(true), estado))
	fila.add_child(boton)
	var etiqueta := Label.new()
	etiqueta.text = estado
	etiqueta.add_theme_font_size_override("font_size", 9)
	etiqueta.add_theme_color_override("font_color", SECUNDARIO)
	fila.add_child(etiqueta)


func _agregar_mensaje(contenedor: VBoxContainer, mensaje: String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = mensaje
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.add_theme_color_override("font_color", SECUNDARIO)
	contenedor.add_child(etiqueta)


func _mostrar_detalle(registro: Dictionary, estado: String) -> void:
	var nombre := str(registro.get("nombre", registro.get("criatura_nombre", "Garumi")))
	var lineas: PackedStringArray = ["[center][color=#e6c99a][b]" + nombre + "[/b][/color][/center]", "[color=#a68559]Estado:[/color] " + estado]
	lineas.append("[color=#a68559]Nivel:[/color] " + str(int(registro.get("nivel", 1))))
	var origen := str(registro.get("nombre_original", ""))
	if not origen.is_empty():
		lineas.append("[color=#a68559]Original:[/color] " + origen)
	var categoria := str(registro.get("categoria_garumi", ""))
	if not categoria.is_empty():
		lineas.append("[color=#a68559]Categoría:[/color] " + categoria)
	var descripcion := str(registro.get("descripcion", "")).strip_edges()
	if not descripcion.is_empty():
		lineas.append("")
		lineas.append(descripcion)
	_detalle.text = "\n".join(lineas)


func mostrar_resultado_amistad_garumi(garumi: Node, exito: bool) -> void:
	var nombre := "Garumi"
	if is_instance_valid(garumi):
		nombre = str(garumi.get("criatura_nombre"))
	_estado.text = nombre + (" aceptó tu amistad." if exito else " no aceptó la propuesta de amistad.")


func _exit_tree() -> void:
	if is_instance_valid(GameState):
		if GameState.has_signal("garumis_vinculados_actualizados") and GameState.garumis_vinculados_actualizados.is_connected(actualizar):
			GameState.garumis_vinculados_actualizados.disconnect(actualizar)
		if GameState.has_signal("garumis_amigos_actualizados") and GameState.garumis_amigos_actualizados.is_connected(actualizar):
			GameState.garumis_amigos_actualizados.disconnect(actualizar)
