extends Control
class_name SettingsPanel

signal closed

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const CONTROLES := [
	{"label": "Moverse", "keys": "W · A · S · D"},
	{"label": "Mano izquierda", "keys": "Q"},
	{"label": "Mano derecha", "keys": "E"},
	{"label": "Recuperar Eterium / Curarse / Meditar", "keys": "ESPACIO"},
	{"label": "Seleccionar Garumi", "keys": "1 · 2 · 3"},
	{"label": "Dash", "keys": "SHIFT"},
	{"label": "Misiones", "keys": "F"},
	{"label": "Mapa", "keys": "M"},
	{"label": "Viajar", "keys": "SHIFT + M"},
	{"label": "Pausa", "keys": "ESC"}
]

var _panel: Panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_construir_interfaz()
	PIXEL_UI_THEME.apply(self)
	get_viewport().size_changed.connect(_ajustar_panel_a_pantalla)
	_ajustar_panel_a_pantalla()


func _construir_interfaz() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.015, 0.01, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-310.0, -245.0)
	_panel.size = Vector2(620.0, 490.0)
	# El tema central dibuja el fondo y el borde con el mismo recurso
	# que utilizan los demás paneles actuales del juego.
	add_child(_panel)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 24)
	margen.add_theme_constant_override("margin_top", 20)
	margen.add_theme_constant_override("margin_right", 24)
	margen.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	margen.add_child(columna)

	var titulo := Label.new()
	titulo.text = "Configuración"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 27)
	columna.add_child(titulo)

	var separador := HSeparator.new()
	columna.add_child(separador)

	_agregar_control_volumen(columna, "Volumen general", "Master")
	_agregar_control_volumen(columna, "Música", "Musica")
	_agregar_control_volumen(columna, "Efectos de sonido", "Efectos")

	var separador_controles := HSeparator.new()
	columna.add_child(separador_controles)

	var controles_titulo := Label.new()
	controles_titulo.text = "CONTROLES"
	controles_titulo.add_theme_font_size_override("font_size", 15)
	columna.add_child(controles_titulo)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 185)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 5)
	scroll.add_child(lista)
	_construir_lista_controles(lista)

	var cerrar := Button.new()
	cerrar.text = "Volver"
	cerrar.custom_minimum_size = Vector2(0, 40)
	cerrar.pressed.connect(_cerrar)
	columna.add_child(cerrar)


func _ajustar_panel_a_pantalla() -> void:
	if not is_instance_valid(_panel):
		return
	var area := get_viewport_rect().size
	var ancho := minf(620.0, maxf(280.0, area.x - 32.0))
	var alto := minf(490.0, maxf(300.0, area.y - 32.0))
	_panel.position = Vector2(-ancho * 0.5, -alto * 0.5)
	_panel.size = Vector2(ancho, alto)


func _cerrar() -> void:
	closed.emit()


func _obtener_audio_settings() -> Node:
	# Resolver el autoload por ruta evita depender de que el editor haya
	# refrescado la lista de autoloads al cambiar de rama.
	return get_node_or_null("/root/AudioSettings")


func _agregar_control_volumen(contenedor: VBoxContainer, titulo: String, bus: String) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	contenedor.add_child(fila)

	var etiqueta := Label.new()
	etiqueta.text = titulo
	etiqueta.custom_minimum_size.x = 150
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(etiqueta)

	var deslizador := HSlider.new()
	deslizador.min_value = 0.0
	deslizador.max_value = 100.0
	deslizador.step = 1.0
	deslizador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deslizador.custom_minimum_size.x = 160
	var audio_settings := _obtener_audio_settings()
	deslizador.value = float(audio_settings.call("obtener_volumen", bus)) * 100.0 if audio_settings != null else 100.0
	fila.add_child(deslizador)

	var porcentaje := Label.new()
	porcentaje.custom_minimum_size.x = 42
	porcentaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	porcentaje.text = str(roundi(deslizador.value)) + "%"
	fila.add_child(porcentaje)

	deslizador.value_changed.connect(
		_on_volumen_cambiado.bind(bus, porcentaje)
	)


func _on_volumen_cambiado(valor: float, bus: String, etiqueta: Label) -> void:
	var audio_settings := _obtener_audio_settings()
	if audio_settings == null:
		push_warning("SettingsPanel: no se encontró /root/AudioSettings. Revisa el autoload en project.godot.")
	else:
		audio_settings.call("establecer_volumen", bus, valor / 100.0)
	etiqueta.text = str(roundi(valor)) + "%"


func _construir_lista_controles(lista: VBoxContainer) -> void:
	for control_info in CONTROLES:
		var nombre := str(control_info["label"])
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		lista.add_child(fila)

		var etiqueta := Label.new()
		etiqueta.text = nombre
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)

		var tecla := Label.new()
		tecla.text = str(control_info["keys"])
		tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tecla.add_theme_color_override("font_color", Color(0.88, 0.76, 0.56))
		fila.add_child(tecla)


func _obtener_texto_atajos(accion: String) -> String:
	if not InputMap.has_action(accion):
		return "No asignado"

	var nombres: PackedStringArray = []
	for evento in InputMap.action_get_events(accion):
		var texto := evento.as_text().strip_edges()
		if not texto.is_empty() and not nombres.has(texto):
			nombres.append(texto)

	if nombres.is_empty():
		return "No asignado"
	return " / ".join(nombres)

