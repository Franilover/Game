extends Control

var lista: VBoxContainer
var detalle: VBoxContainer
var estado: Label
var _botones: Array[Button] = []

func _ready() -> void:
	_crear_ui()
	_actualizar()

func _crear_ui() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 18)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 18)
	margen.add_theme_constant_override("margin_bottom", 12)
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	margen.add_child(columna)

	var contenido := HBoxContainer.new()
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 18)
	columna.add_child(contenido)

	lista = VBoxContainer.new()
	lista.custom_minimum_size = Vector2(220, 0)
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 5)
	contenido.add_child(lista)

	var separador := VSeparator.new()
	separador.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(separador)

	detalle = VBoxContainer.new()
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detalle.add_theme_constant_override("separation", 8)
	contenido.add_child(detalle)

	estado = Label.new()
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.add_theme_color_override("font_color", Color(0.55, 0.43, 0.29, 1.0))
	estado.add_theme_font_size_override("font_size", 10)
	columna.add_child(estado)

func _actualizar() -> void:
	_limpiar()

	var sistema := get_node_or_null("/root/RelationshipSystem")
	if sistema == null or not sistema.has_method("esta_cargado") or not sistema.call("esta_cargado"):
		estado.text = "Las relaciones se cargarán desde Supabase."
		return

	var reglas_variant: Variant = sistema.get("_reglas")
	if not reglas_variant is Dictionary:
		estado.text = "No hay relaciones descubiertas."
		return

	var reglas: Dictionary = reglas_variant as Dictionary
	if reglas.is_empty():
		estado.text = "No hay relaciones descubiertas."
		return

	for personaje_id_variant in reglas.keys():
		var personaje_id := str(personaje_id_variant)
		var regla_variant: Variant = reglas.get(personaje_id_variant, {})
		if not regla_variant is Dictionary:
			continue

		var regla: Dictionary = regla_variant as Dictionary
		var nombre := ""
		var personaje := WorldData.obtener_personaje_game_por_id(personaje_id)
		if not personaje.is_empty():
			nombre = str(personaje.get("nombre", "")).strip_edges()
		if nombre.is_empty():
			nombre = personaje_id

		var boton := Button.new()
		boton.text = nombre
		boton.custom_minimum_size = Vector2(0, 34)
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.pressed.connect(_seleccionar.bind(personaje_id, nombre))
		lista.add_child(boton)
		_botones.append(boton)

	estado.text = str(reglas.size()) + " relaciones"

func _seleccionar(personaje_id: String, nombre: String) -> void:
	for boton in _botones:
		boton.button_pressed = false

	_limpiar_detalle()

	var sistema := get_node_or_null("/root/RelationshipSystem")
	if sistema == null:
		return

	var relacion_variant: Variant = sistema.call("obtener_relacion", personaje_id)
	if not relacion_variant is Dictionary:
		return

	var relacion: Dictionary = relacion_variant as Dictionary

	var titulo := Label.new()
	titulo.text = nombre
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", Color(0.9, 0.79, 0.58, 1.0))
	detalle.add_child(titulo)

	var descripcion := Label.new()
	descripcion.text = "Relación actual"
	descripcion.add_theme_color_override("font_color", Color(0.65, 0.52, 0.35, 1.0))
	detalle.add_child(descripcion)

	for clave in ["amistad", "confianza", "respeto", "afecto"]:
		var valor := float(relacion.get(clave, 0.0))
		var fila := Label.new()
		fila.text = clave.capitalize() + ": " + str(roundi(valor))
		fila.add_theme_font_size_override("font_size", 13)
		detalle.add_child(fila)

func _limpiar() -> void:
	_botones.clear()
	if lista != null:
		for hijo in lista.get_children():
			hijo.queue_free()
	_limpiar_detalle()

func _limpiar_detalle() -> void:
	if detalle == null:
		return
	for hijo in detalle.get_children():
		hijo.queue_free()
