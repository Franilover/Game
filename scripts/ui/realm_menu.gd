extends Control
## Menú de viaje entre zonas. Las escenas siguen siendo responsabilidad de ZoneManager.

signal destino_solicitado(clave: String)

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const COLOR_TEXTO := Color(0.91, 0.86, 0.75, 1.0)
const COLOR_SECUNDARIO := Color(0.68, 0.61, 0.51, 1.0)

var _abierto: bool = false
var _supabase_client: GarliaSupabaseClient
var _game_state: GameStateService
var _tipo_zona_actual: String = ""
@onready var _panel: PanelContainer = $Centro/PanelReinos
@onready var _lista: VBoxContainer = $Centro/PanelReinos/Margen/Contenido/Destinos


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


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
			if escena.is_empty() or not ResourceLoader.exists(escena):
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


func _agregar_destino(clave: String, nombre: String, categoria: String, actual: bool) -> void:
	var boton := Button.new()
	boton.text = nombre
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
	PIXEL_UI_THEME.apply(boton)
	boton.add_theme_color_override("font_color", COLOR_TEXTO)
	boton.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.73, 1.0))
	boton.add_theme_color_override("font_disabled_color", COLOR_SECUNDARIO)
	boton.add_theme_font_size_override("font_size", 13)




func _input(event: InputEvent) -> void:
	if not _abierto:
		return
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
			cerrar()
			get_viewport().set_input_as_handled()
