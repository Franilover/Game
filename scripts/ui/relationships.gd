extends Control

class_name RelationshipsUI

const TAMANO_RETRATO := Vector2(64.0, 72.0)
const SEPARACION_RETRATOS := 8

var lista: GridContainer
var detalle: VBoxContainer
var estado: Label
var _lista_scroll: ScrollContainer
var _botones: Array[Button] = []
var _personajes_por_id: Dictionary = {}
var _relationship_system: Node = null


func _ready() -> void:
	_crear_ui()
	_actualizar()


func configurar(sistema: Node) -> void:
	_relationship_system = sistema
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
	columna.add_theme_constant_override("separation", 4)
	margen.add_child(columna)

	var contenido := HBoxContainer.new()
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 8)
	columna.add_child(contenido)

	_lista_scroll = ScrollContainer.new()
	_lista_scroll.custom_minimum_size = Vector2(220.0, 0.0)
	_lista_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_scroll.size_flags_stretch_ratio = 1.0
	_lista_scroll.resized.connect(_ajustar_columnas_retratos)
	contenido.add_child(_lista_scroll)

	lista = GridContainer.new()
	lista.columns = 3
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("h_separation", SEPARACION_RETRATOS)
	lista.add_theme_constant_override("v_separation", SEPARACION_RETRATOS)
	_lista_scroll.add_child(lista)

	var separador := VSeparator.new()
	separador.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(separador)

	detalle = VBoxContainer.new()
	detalle.custom_minimum_size = Vector2(150.0, 0.0)
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.size_flags_stretch_ratio = 0.8
	detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detalle.add_theme_constant_override("separation", 8)
	contenido.add_child(detalle)

	estado = Label.new()
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.add_theme_color_override("font_color", Color(0.55, 0.43, 0.29, 1.0))
	estado.add_theme_font_size_override("font_size", 10)
	columna.add_child(estado)
	call_deferred("_ajustar_columnas_retratos")


func _ajustar_columnas_retratos() -> void:
	if not is_instance_valid(lista) or not is_instance_valid(_lista_scroll):
		return
	var ancho_util := maxi(1, int(_lista_scroll.size.x))
	var paso := TAMANO_RETRATO.x + float(SEPARACION_RETRATOS)
	lista.columns = clampi(floori(float(ancho_util + SEPARACION_RETRATOS) / paso), 2, 6)


func _actualizar() -> void:
	_limpiar()

	var sistema := _relationship_system
	if sistema == null or not sistema.has_method("esta_cargado") or not sistema.call("esta_cargado"):
		estado.text = ""
		return

	var reglas_variant: Variant = sistema.call("obtener_reglas_sociales")
	if not reglas_variant is Dictionary:
		estado.text = ""
		return

	var reglas: Dictionary = reglas_variant as Dictionary
	if reglas.is_empty():
		estado.text = ""
		return

	for personaje_id_variant in reglas.keys():
		var personaje_id := str(personaje_id_variant)
		var regla_variant: Variant = reglas.get(personaje_id_variant, {})
		if not regla_variant is Dictionary:
			continue

		var personaje: Dictionary = WorldData.obtener_personaje_game_por_id(personaje_id)
		var nombre := str(personaje.get("nombre", "")).strip_edges()
		if nombre.is_empty():
			nombre = personaje_id
		var asset_key := str(personaje.get("asset_key", nombre)).strip_edges()
		_personajes_por_id[personaje_id] = {
			"nombre": nombre,
			"asset_key": asset_key
		}

		var boton := Button.new()
		boton.custom_minimum_size = TAMANO_RETRATO
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.toggle_mode = true
		boton.set_meta("personaje_id", personaje_id)
		boton.tooltip_text = nombre
		boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		boton.pressed.connect(_seleccionar.bind(personaje_id, nombre))
		var textura := _cargar_retrato(asset_key, nombre)
		if textura != null:
			var retrato := TextureRect.new()
			retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			retrato.offset_left = 6.0
			retrato.offset_top = 6.0
			retrato.offset_right = -6.0
			retrato.offset_bottom = -6.0
			retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
			retrato.texture = textura
			boton.add_child(retrato)
		else:
			boton.text = nombre.substr(0, 2).to_upper()
		lista.add_child(boton)
		_botones.append(boton)

	estado.text = ""


func _cargar_retrato(asset_key: String, nombre: String) -> Texture2D:
	var claves: Array[String] = []
	if not asset_key.is_empty():
		claves.append(asset_key)
	if not nombre.is_empty() and nombre not in claves:
		claves.append(nombre)
	for clave in claves:
		var ruta := "res://assets/art/characters/" + clave + ".png"
		if ResourceLoader.exists(ruta):
			var recurso: Resource = load(ruta)
			if recurso is Texture2D:
				return recurso as Texture2D
	return null


func _seleccionar(personaje_id: String, nombre: String) -> void:
	for boton in _botones:
		boton.button_pressed = str(boton.get_meta("personaje_id", "")) == personaje_id

	_limpiar_detalle()

	var sistema := _relationship_system
	if sistema == null:
		return

	var relacion_variant: Variant = sistema.call("obtener_relacion", personaje_id)
	if not relacion_variant is Dictionary:
		return

	var relacion: Dictionary = relacion_variant as Dictionary
	var datos_personaje: Dictionary = _personajes_por_id.get(personaje_id, {})
	var asset_key := str(datos_personaje.get("asset_key", nombre))
	var textura := _cargar_retrato(asset_key, nombre)
	if textura != null:
		var skin := TextureRect.new()
		skin.custom_minimum_size = Vector2(0.0, 84.0)
		skin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		skin.texture = textura
		detalle.add_child(skin)

	var titulo := Label.new()
	titulo.text = nombre
	titulo.add_theme_font_size_override("font_size", 13)
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
		fila.add_theme_font_size_override("font_size", 10)
		detalle.add_child(fila)


func _limpiar() -> void:
	_botones.clear()
	_personajes_por_id.clear()
	if lista != null:
		for hijo in lista.get_children():
			hijo.queue_free()
	_limpiar_detalle()


func _limpiar_detalle() -> void:
	if detalle == null:
		return
	for hijo in detalle.get_children():
		hijo.queue_free()
