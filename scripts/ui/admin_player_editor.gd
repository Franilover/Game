extends Control
class_name AdminPlayerEditor

var jugador: Node
var _species: OptionButton
var _nombre: LineEdit
var _vida: SpinBox
var _eterium: SpinBox
var _energia: SpinBox
var _admin: CheckBox
var _capacidades: Dictionary = {}
var _estado: Label

const CAPACIDADES := [
	{"clave": "teletransportar", "nombre": "Teletransportar"},
	{"clave": "invocar", "nombre": "Invocar criaturas"},
	{"clave": "editar_jugadores", "nombre": "Editar jugadores"},
	{"clave": "controlar_tiempo", "nombre": "Controlar tiempo"},
	{"clave": "dar_objetos", "nombre": "Dar objetos"},
	{"clave": "modo_dios", "nombre": "Modo dios"}
]


func abrir(objetivo: Node) -> void:
	jugador = objetivo
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_cargar_datos()
	_nombre.grab_focus()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_ui()


func _crear_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.015, 0.01, 0.82)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-440, -210)
	panel.size = Vector2(880, 420)
	add_child(panel)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 26)
	margen.add_theme_constant_override("margin_right", 26)
	margen.add_theme_constant_override("margin_top", 20)
	margen.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	margen.add_child(columna)

	var titulo := Label.new()
	titulo.text = "Editar jugador"
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(titulo)

	var contenido := HBoxContainer.new()
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 28)
	columna.add_child(contenido)

	var izquierda := VBoxContainer.new()
	izquierda.custom_minimum_size = Vector2(390, 0)
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izquierda.add_theme_constant_override("separation", 7)
	contenido.add_child(izquierda)

	_nombre = LineEdit.new()
	_nombre.custom_minimum_size = Vector2(0, 36)
	_nombre.placeholder_text = "Nombre del personaje"
	izquierda.add_child(_campo("Renombrar", _nombre))

	_species = OptionButton.new()
	_species.custom_minimum_size = Vector2(0, 36)
	izquierda.add_child(_campo("Especie", _species))

	_vida = _crear_spin(1, 999999)
	izquierda.add_child(_campo("Vida máxima", _vida))

	_eterium = _crear_spin(1, 999999)
	izquierda.add_child(_campo("Eterium máximo", _eterium))

	_energia = _crear_spin(1, 999999)
	izquierda.add_child(_campo("Energía máxima", _energia))

	var defaults := Button.new()
	defaults.text = "Restablecer valores por defecto"
	defaults.custom_minimum_size = Vector2(0, 36)
	defaults.pressed.connect(_restaurar_defaults)
	izquierda.add_child(defaults)

	var derecha := VBoxContainer.new()
	derecha.custom_minimum_size = Vector2(390, 0)
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.add_theme_constant_override("separation", 5)
	contenido.add_child(derecha)

	_admin = CheckBox.new()
	_admin.text = "Rol de admin en esta partida"
	_admin.toggled.connect(_al_cambiar_admin)
	derecha.add_child(_admin)

	var subtitulo := Label.new()
	subtitulo.text = "Capacidades únicas de esta partida"
	subtitulo.add_theme_font_size_override("font_size", 13)
	derecha.add_child(subtitulo)

	var capacidades_grid := GridContainer.new()
	capacidades_grid.columns = 2
	capacidades_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	derecha.add_child(capacidades_grid)

	for capacidad in CAPACIDADES:
		var check := CheckBox.new()
		check.text = str(capacidad["nombre"])
		check.set_meta("capacidad", str(capacidad["clave"]))
		check.toggled.connect(_al_cambiar_capacidad.bind(str(capacidad["clave"])))
		_capacidades[str(capacidad["clave"])] = check
		capacidades_grid.add_child(check)

	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.custom_minimum_size = Vector2(0, 28)
	derecha.add_child(_estado)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	botones.add_theme_constant_override("separation", 10)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.custom_minimum_size = Vector2(130, 42)
	cancelar.pressed.connect(_cerrar)
	botones.add_child(cancelar)

	var guardar := Button.new()
	guardar.text = "Guardar"
	guardar.custom_minimum_size = Vector2(130, 42)
	guardar.pressed.connect(_guardar)
	botones.add_child(guardar)

	columna.add_child(botones)

func _campo(etiqueta: String, control: Control) -> Control:
	var fila := VBoxContainer.new()
	var label := Label.new()
	label.text = etiqueta
	fila.add_child(label)
	fila.add_child(control)
	return fila


func _crear_spin(minimo: float, maximo: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimo
	spin.max_value = maximo
	spin.step = 1
	spin.allow_greater = false
	spin.allow_lesser = false
	return spin


func _cargar_datos() -> void:
	if jugador == null or not is_instance_valid(jugador):
		return

	var config: Dictionary = {}
	if jugador.has_method("admin_obtener_configuracion"):
		config = jugador.call("admin_obtener_configuracion")

	_nombre.text = str(config.get("nombre", jugador.name))

	_species.clear()
	var especies: Array = SupabaseClient.obtener_especies_jugables()
	var especie_variant: Variant = config.get("especie", {})
	var especie_actual := ""
	if especie_variant is Dictionary:
		especie_actual = str((especie_variant as Dictionary).get("id", ""))

	for especie in especies:
		if not especie is Dictionary:
			continue
		var datos := especie as Dictionary
		var id := str(datos.get("id", ""))
		var nombre := str(datos.get("nombre", id))
		_species.add_item(nombre)
		_species.set_item_metadata(_species.item_count - 1, datos)
		if id == especie_actual:
			_species.select(_species.item_count - 1)

	_vida.value = float(config.get("vida_maxima", 100))
	_eterium.value = float(config.get("eterium_maximo", 100))
	_energia.value = float(config.get("energia_maxima", 100))

	var admin_variant: Variant = GameState.flags.get("personaje_admin", {})
	var admin_data: Dictionary = {}
	if admin_variant is Dictionary:
		admin_data = admin_variant as Dictionary

	_admin.button_pressed = str(admin_data.get("rol", "explorador")).to_lower() == "admin"
	var capacidades: Array = admin_data.get("capacidades", [])
	if _admin.button_pressed and capacidades.is_empty():
		for clave in _capacidades:
			capacidades.append(clave)
	for clave in _capacidades:
		var check: CheckBox = _capacidades[clave]
		check.button_pressed = clave in capacidades


func _al_cambiar_admin(activo: bool) -> void:
	for clave in _capacidades:
		var check: CheckBox = _capacidades[clave]
		check.button_pressed = activo
	_estado.text = "Admin: capacidades habilitadas." if activo else "Explorador: funciones administrativas deshabilitadas."


func _al_cambiar_capacidad(_clave: String, _activo: bool) -> void:
	_estado.text = "Capacidades se guardarán solo en esta partida."


func _restaurar_defaults() -> void:
	if jugador != null and jugador.has_method("admin_restaurar_defaults"):
		jugador.call("admin_restaurar_defaults")
		var admin_variant: Variant = GameState.flags.get("personaje_admin", {})
		if admin_variant is Dictionary:
			(admin_variant as Dictionary).erase("maximos")
		_cargar_datos()
		_estado.text = "Valores por defecto restaurados."
		GameState.guardar_partida()


func _guardar() -> void:
	if jugador == null or not is_instance_valid(jugador):
		return

	if jugador.has_method("admin_cambiar_nombre"):
		if not bool(jugador.call("admin_cambiar_nombre", _nombre.text)):
			_estado.text = "El nombre no puede estar vacío."
			return

	var especie := {}
	if _species.selected >= 0:
		var metadata: Variant = _species.get_item_metadata(_species.selected)
		if metadata is Dictionary:
			especie = (metadata as Dictionary).duplicate(true)

	if not especie.is_empty() and jugador.has_method("admin_cambiar_especie"):
		jugador.call("admin_cambiar_especie", especie)

	if jugador.has_method("admin_establecer_maximos"):
		jugador.call(
			"admin_establecer_maximos",
			int(_vida.value),
			int(_eterium.value),
			float(_energia.value)
		)

	var capacidades: Array[String] = []
	for clave in _capacidades:
		var check: CheckBox = _capacidades[clave]
		if check.button_pressed:
			capacidades.append(clave)

	GameState.flags["personaje_admin"] = {
		"rol": "admin" if _admin.button_pressed else "explorador",
		"capacidades": capacidades,
		"maximos": {
			"vida": int(_vida.value),
			"eterium": int(_eterium.value),
			"energia": float(_energia.value)
		}
	}

	GameState.guardar_partida()
	_estado.text = "Cambios guardados en esta partida."


func _cerrar() -> void:
	visible = false
	get_tree().paused = false
