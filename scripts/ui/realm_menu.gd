extends Control
## Menú de viaje entre zonas. Las escenas siguen siendo responsabilidad de ZoneManager.

signal destino_solicitado(clave: String)

const COLOR_FONDO := Color(0.055, 0.045, 0.055, 0.94)
const COLOR_PANEL := Color(0.105, 0.082, 0.075, 0.99)
const COLOR_BORDE := Color(0.48, 0.35, 0.20, 1.0)
const COLOR_TEXTO := Color(0.91, 0.86, 0.75, 1.0)
const COLOR_SECUNDARIO := Color(0.68, 0.61, 0.51, 1.0)

var _abierto: bool = false
var _supabase_client: GarliaSupabaseClient
var _game_state: GameStateService
var _tipo_zona_actual: String = ""
var _panel: PanelContainer
var _lista: VBoxContainer
var _subtitulo: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_construir_interfaz()


func esta_abierto() -> bool:
	return _abierto


func alternar(cliente: GarliaSupabaseClient, estado: GameStateService, tipo_zona: String) -> void:
	if _abierto:
		cerrar()
		return
	_supabase_client = cliente
	_game_state = estado
	_tipo_zona_actual = tipo_zona
	_reconstruir_destinos()
	_abierto = true
	visible = true
	if not is_in_group("modal_ui"):
		add_to_group("modal_ui")
	_panel.grab_focus()


func cerrar() -> void:
	_abierto = false
	visible = false
	if is_in_group("modal_ui"):
		remove_from_group("modal_ui")


func _construir_interfaz() -> void:
	var velo := ColorRect.new()
	velo.name = "Velo"
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.color = COLOR_FONDO
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(velo)

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(centro)

	_panel = PanelContainer.new()
	_panel.name = "PanelReinos"
	_panel.focus_mode = Control.FOCUS_ALL
	_panel.custom_minimum_size = Vector2(340.0, 260.0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.add_theme_stylebox_override("panel", _crear_estilo_panel())
	centro.add_child(_panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 20)
	margen.add_theme_constant_override("margin_right", 20)
	margen.add_theme_constant_override("margin_top", 16)
	margen.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margen)

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 10)
	margen.add_child(contenido)

	var cabecera := HBoxContainer.new()
	contenido.add_child(cabecera)

	var titulo := Label.new()
	titulo.text = "VIAJAR"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_theme_color_override("font_color", COLOR_TEXTO)
	titulo.add_theme_font_size_override("font_size", 19)
	cabecera.add_child(titulo)

	var cerrar_boton := Button.new()
	cerrar_boton.text = "×"
	cerrar_boton.custom_minimum_size = Vector2(30.0, 28.0)
	_estilizar_boton(cerrar_boton, true)
	cerrar_boton.pressed.connect(cerrar)
	cabecera.add_child(cerrar_boton)

	_subtitulo = Label.new()
	_subtitulo.text = "Elige un destino descubierto"
	_subtitulo.add_theme_color_override("font_color", COLOR_SECUNDARIO)
	_subtitulo.add_theme_font_size_override("font_size", 11)
	contenido.add_child(_subtitulo)

	var separador := HSeparator.new()
	separador.add_theme_color_override("separator", COLOR_BORDE)
	contenido.add_child(separador)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 7)
	contenido.add_child(_lista)

	var pie := Label.new()
	pie.text = "SHIFT + M  ·  CERRAR"
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.add_theme_color_override("font_color", COLOR_SECUNDARIO)
	pie.add_theme_font_size_override("font_size", 10)
	contenido.add_child(pie)


func _reconstruir_destinos() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()

	var desbloqueados: Dictionary = {}
	if is_instance_valid(_game_state) and _game_state.has_method("obtener_reinos_desbloqueados"):
		desbloqueados = _game_state.call("obtener_reinos_desbloqueados")

	var agregados: Dictionary = {}
	if is_instance_valid(_supabase_client):
		for variante in _supabase_client.obtener_reinos_game():
			if not variante is Dictionary:
				continue
			var reino := variante as Dictionary
			var clave := str(reino.get("clave", "")).strip_edges().to_lower()
			if clave.is_empty() or agregados.has(clave) or not bool(desbloqueados.get(clave, false)):
				continue
			var propiedades_variant: Variant = reino.get("propiedades", {})
			if not propiedades_variant is Dictionary:
				continue
			var propiedades := propiedades_variant as Dictionary
			var escena := str(propiedades.get("escena", "")).strip_edges()
			if escena.is_empty():
				continue
			var nombre := str(propiedades.get("nombre", propiedades.get("titulo", clave.capitalize()))).strip_edges()
			if nombre.is_empty():
				nombre = clave.capitalize()
			var es_actual := (clave == "torres" and _tipo_zona_actual == "reino_torres") or clave == _tipo_zona_actual or ("reino:" + clave) == _tipo_zona_actual
			_agregar_destino(clave, nombre, "REINO", es_actual)
			agregados[clave] = true

	# Torres siempre aparece desbloqueado por defecto, incluso si su catálogo remoto
	# todavía no terminó de cargar; la transición valida la configuración real.
	if not agregados.has("torres") and bool(desbloqueados.get("torres", true)):
		_agregar_destino("torres", "Torres", "REINO", _tipo_zona_actual == "reino_torres")
		agregados["torres"] = true

	_agregar_destino("mundo_abierto", "Mundo Abierto", "EXPLORACIÓN", _tipo_zona_actual == "mundo_abierto")
	_subtitulo.text = "Elige un destino descubierto" if agregados.size() > 1 else "Torres está disponible. Descubre otros reinos explorando."


func _agregar_destino(clave: String, nombre: String, categoria: String, actual: bool) -> void:
	var boton := Button.new()
	boton.text = nombre + ("   ·   ACTUAL" if actual else "")
	boton.custom_minimum_size = Vector2(292.0, 42.0)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.disabled = actual
	boton.focus_mode = Control.FOCUS_ALL
	boton.tooltip_text = categoria
	_estilizar_boton(boton, actual)
	boton.pressed.connect(_seleccionar_destino.bind(clave))
	_lista.add_child(boton)


func _seleccionar_destino(clave: String) -> void:
	cerrar()
	destino_solicitado.emit(clave)


func _estilizar_boton(boton: Button, seleccionado: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.115, 0.09, 1.0) if not seleccionado else Color(0.21, 0.16, 0.11, 1.0)
	normal.border_color = COLOR_BORDE if seleccionado else Color(0.27, 0.21, 0.15, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.23, 0.17, 0.11, 1.0)
	hover.border_color = Color(0.68, 0.51, 0.30, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.075, 0.06, 1.0)
	boton.add_theme_stylebox_override("normal", normal)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", pressed)
	boton.add_theme_stylebox_override("disabled", normal)
	boton.add_theme_color_override("font_color", COLOR_TEXTO)
	boton.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.73, 1.0))
	boton.add_theme_color_override("font_disabled_color", COLOR_SECUNDARIO)
	boton.add_theme_font_size_override("font_size", 13)


func _crear_estilo_panel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_PANEL
	estilo.border_color = COLOR_BORDE
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	estilo.shadow_size = 12
	return estilo


func _input(event: InputEvent) -> void:
	if not _abierto:
		return
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
			cerrar()
			get_viewport().set_input_as_handled()
