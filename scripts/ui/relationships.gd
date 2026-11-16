extends Control

class_name RelationshipsUI

const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")

const TAMANO_RETRATO := Vector2(64.0, 72.0)
const SEPARACION_RETRATOS := 8

var lista: GridContainer
var detalle: VBoxContainer
var estado: Label
var _lista_scroll: ScrollContainer
var _botones: Array[Button] = []
var _personajes_por_id: Dictionary = {}
var _relationship_system: Node = null
var _personaje_seleccionado_id := ""


func _ready() -> void:
	_crear_ui()
	PIXEL_UI_THEME.apply(self, false)

	# La pestaña puede abrirse antes de que WorldData termine de recibir
	# personajes_game desde Supabase. Escuchar ambos eventos evita dejar
	# la lista vacía hasta volver a abrir el menú.
	if WorldData.has_signal("mundo_listo"):
		var senal_mundo_listo: Signal = WorldData.mundo_listo
		if not senal_mundo_listo.is_connected(_al_catalogo_personajes_actualizado):
			senal_mundo_listo.connect(_al_catalogo_personajes_actualizado)
	if WorldData.has_signal("mundo_actualizado"):
		var senal_mundo_actualizado: Signal = WorldData.mundo_actualizado
		if not senal_mundo_actualizado.is_connected(_al_catalogo_personajes_actualizado):
			senal_mundo_actualizado.connect(_al_catalogo_personajes_actualizado)

	_actualizar()


func _al_catalogo_personajes_actualizado() -> void:
	_actualizar()


func configurar(sistema: Node) -> void:
	if _relationship_system != null and is_instance_valid(_relationship_system):
		if _relationship_system.has_signal("reglas_sociales_cargadas"):
			var senal_reglas_anterior: Signal = _relationship_system.reglas_sociales_cargadas
			if senal_reglas_anterior.is_connected(_al_reglas_sociales_cargadas):
				senal_reglas_anterior.disconnect(_al_reglas_sociales_cargadas)
		if _relationship_system.has_signal("relacion_cambiada"):
			var senal_relacion_anterior: Signal = _relationship_system.relacion_cambiada
			if senal_relacion_anterior.is_connected(_al_relacion_cambiada):
				senal_relacion_anterior.disconnect(_al_relacion_cambiada)

	_relationship_system = sistema
	if _relationship_system != null:
		if _relationship_system.has_signal("reglas_sociales_cargadas"):
			var senal_reglas: Signal = _relationship_system.reglas_sociales_cargadas
			if not senal_reglas.is_connected(_al_reglas_sociales_cargadas):
				senal_reglas.connect(_al_reglas_sociales_cargadas)
		if _relationship_system.has_signal("relacion_cambiada"):
			var senal_relacion: Signal = _relationship_system.relacion_cambiada
			if not senal_relacion.is_connected(_al_relacion_cambiada):
				senal_relacion.connect(_al_relacion_cambiada)
	_actualizar()


func _al_reglas_sociales_cargadas() -> void:
	_actualizar()


func _al_relacion_cambiada(personaje_id: String, relacion: Dictionary) -> void:
	if personaje_id != _personaje_seleccionado_id or not is_instance_valid(detalle):
		return
	var barra := detalle.get_node_or_null("FriendshipPanel/FriendshipMargin/FriendshipContent/FriendshipBar") as ProgressBar
	if barra == null:
		return
	barra.value = _amistad_a_valor_visual(float(relacion.get("amistad", 0.0)))


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

	detalle = VBoxContainer.new()
	detalle.custom_minimum_size = Vector2(170.0, 0.0)
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

	# La lista visual depende del catálogo de personajes, no de que el
	# servicio de relaciones haya terminado de cargar. Antes se retornaba
	# aquí y se ocultaban todos los habitantes durante una carga social lenta.
	var personajes: Array[Dictionary] = WorldData.obtener_personajes_game()
	if personajes.is_empty():
		estado.text = "Todavía no hay habitantes disponibles."
		return

	for personaje in personajes:
		# El catálogo ya contiene habitantes jugables/sociales; no excluirlos
		# por campos opcionales de activación que pueden faltar en snapshots antiguos.
		var personaje_id := str(personaje.get("id", "")).strip_edges()
		if personaje_id.is_empty():
			continue
		var nombre := str(personaje.get("nombre", "")).strip_edges()
		if nombre.is_empty():
			nombre = personaje_id
		var asset_key := str(personaje.get("asset_key", nombre)).strip_edges()
		_personajes_por_id[personaje_id] = {
			"nombre": nombre,
			"asset_key": asset_key
		}

		var boton := Button.new()
		boton.name = "SlotRelationshipPortrait"
		boton.custom_minimum_size = TAMANO_RETRATO
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.size_flags_vertical = Control.SIZE_FILL
		boton.toggle_mode = true
		boton.clip_contents = true
		boton.text = ""
		boton.set_meta("personaje_id", personaje_id)
		boton.tooltip_text = ""
		boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		boton.pressed.connect(_seleccionar.bind(personaje_id, nombre))
		PIXEL_UI_THEME.apply(boton, false)

		var textura_cara := _cargar_retrato_cara(asset_key, nombre)
		var textura := textura_cara if textura_cara != null else _cargar_retrato(asset_key, nombre)
		if textura != null:
			var retrato := TextureRect.new()
			retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			retrato.offset_left = 4.0
			retrato.offset_top = 3.0
			retrato.offset_right = -4.0
			retrato.offset_bottom = -16.0
			retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
			retrato.texture = textura
			boton.add_child(retrato)
		else:
			var iniciales := Label.new()
			iniciales.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			iniciales.offset_bottom = -16.0
			iniciales.text = nombre.substr(0, 2).to_upper()
			iniciales.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			iniciales.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			iniciales.add_theme_font_size_override("font_size", 14)
			iniciales.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boton.add_child(iniciales)

		var etiqueta := Label.new()
		etiqueta.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		etiqueta.offset_left = 2.0
		etiqueta.offset_right = -2.0
		etiqueta.offset_top = -15.0
		etiqueta.offset_bottom = -1.0
		etiqueta.text = nombre
		etiqueta.clip_text = true
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta.add_theme_font_size_override("font_size", 8)
		etiqueta.add_theme_color_override("font_color", Color("#FFF3D6"))
		etiqueta.add_theme_color_override("font_outline_color", Color("#302014"))
		etiqueta.add_theme_constant_override("outline_size", 2)
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(etiqueta)

		lista.add_child(boton)
		_botones.append(boton)

	estado.text = ""
	if not _personaje_seleccionado_id.is_empty():
		if _personajes_por_id.has(_personaje_seleccionado_id):
			var datos_personaje: Dictionary = _personajes_por_id[_personaje_seleccionado_id]
			_seleccionar(
				_personaje_seleccionado_id,
				str(datos_personaje.get("nombre", _personaje_seleccionado_id))
			)
		else:
			_personaje_seleccionado_id = ""


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


func _cargar_retrato_cara(asset_key: String, nombre: String) -> Texture2D:
	var claves: Array[String] = []
	if not asset_key.is_empty():
		claves.append(asset_key)
	if not nombre.is_empty() and nombre not in claves:
		claves.append(nombre)
	for clave in claves:
		var ruta := "res://assets/art/characters/heads/" + clave + ".png"
		if ResourceLoader.exists(ruta):
			var recurso: Resource = load(ruta)
			if recurso is Texture2D:
				return recurso as Texture2D
	return null


func _seleccionar(personaje_id: String, nombre: String) -> void:
	_personaje_seleccionado_id = personaje_id
	for boton in _botones:
		boton.button_pressed = str(boton.get_meta("personaje_id", "")) == personaje_id

	_limpiar_detalle()

	var sistema := _relationship_system
	var relacion: Dictionary = {}
	if sistema != null and is_instance_valid(sistema) and sistema.has_method("esta_cargado"):
		if bool(sistema.call("esta_cargado")):
			var relacion_variant: Variant = sistema.call("obtener_relacion", personaje_id)
			if relacion_variant is Dictionary:
				relacion = relacion_variant as Dictionary

	var datos_personaje: Dictionary = _personajes_por_id.get(personaje_id, {})
	var asset_key := str(datos_personaje.get("asset_key", nombre))
	var textura_cara := _cargar_retrato_cara(asset_key, nombre)
	var textura := textura_cara if textura_cara != null else _cargar_retrato(asset_key, nombre)
	var fondo_retrato := Button.new()
	fondo_retrato.name = "CharacterFaceFrame"
	fondo_retrato.text = ""
	fondo_retrato.custom_minimum_size = Vector2(0.0, 96.0)
	fondo_retrato.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fondo_retrato.focus_mode = Control.FOCUS_NONE
	fondo_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo_retrato.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	PIXEL_UI_THEME.apply(fondo_retrato, false)
	detalle.add_child(fondo_retrato)

	if textura != null:
		var retrato_cara := TextureRect.new()
		retrato_cara.name = "CharacterFace"
		retrato_cara.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		retrato_cara.offset_left = 5.0
		retrato_cara.offset_top = 4.0
		retrato_cara.offset_right = -5.0
		retrato_cara.offset_bottom = -4.0
		retrato_cara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		retrato_cara.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		retrato_cara.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		retrato_cara.mouse_filter = Control.MOUSE_FILTER_IGNORE
		retrato_cara.texture = textura
		fondo_retrato.add_child(retrato_cara)
	else:
		var iniciales := Label.new()
		iniciales.name = "CharacterFaceFallback"
		iniciales.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		iniciales.text = nombre.substr(0, 2).to_upper()
		iniciales.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		iniciales.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		iniciales.add_theme_font_size_override("font_size", 24)
		iniciales.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fondo_retrato.add_child(iniciales)

	var titulo := Button.new()
	titulo.name = "CharacterName"
	titulo.text = nombre
	titulo.custom_minimum_size = Vector2(0.0, 28.0)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.focus_mode = Control.FOCUS_NONE
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titulo.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	titulo.add_theme_font_size_override("font_size", 13)
	titulo.add_theme_color_override("font_color", Color("#FFF3D6"))
	PIXEL_UI_THEME.apply(titulo, false)
	detalle.add_child(titulo)

	if relacion.is_empty():
		var estado_relacion := Label.new()
		estado_relacion.text = "Relaciones sociales cargando..."
		estado_relacion.add_theme_font_size_override("font_size", 9)
		detalle.add_child(estado_relacion)
		return

	# Agrupar amistad y progreso sobre la misma superficie que los botones.
	var panel_amistad := PanelContainer.new()
	panel_amistad.name = "FriendshipPanel"
	panel_amistad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fondo_amistad := PIXEL_UI_THEME.button_surface_style()
	if fondo_amistad != null:
		panel_amistad.add_theme_stylebox_override("panel", fondo_amistad)
	detalle.add_child(panel_amistad)

	var margen_amistad := MarginContainer.new()
	margen_amistad.name = "FriendshipMargin"
	margen_amistad.add_theme_constant_override("margin_left", 7)
	margen_amistad.add_theme_constant_override("margin_top", 5)
	margen_amistad.add_theme_constant_override("margin_right", 7)
	margen_amistad.add_theme_constant_override("margin_bottom", 5)
	panel_amistad.add_child(margen_amistad)

	var contenido_amistad := VBoxContainer.new()
	contenido_amistad.name = "FriendshipContent"
	contenido_amistad.add_theme_constant_override("separation", 4)
	margen_amistad.add_child(contenido_amistad)

	var etiqueta_amistad := Label.new()
	etiqueta_amistad.text = "Amistad"
	etiqueta_amistad.add_theme_font_size_override("font_size", 10)
	contenido_amistad.add_child(etiqueta_amistad)

	var amistad_guardada := float(relacion.get("amistad", 0.0))
	var amistad_visual := _amistad_a_valor_visual(amistad_guardada)
	var barra_amistad := ProgressBar.new()
	barra_amistad.name = "FriendshipBar"
	barra_amistad.min_value = 1.0
	barra_amistad.max_value = 100.0
	barra_amistad.value = amistad_visual
	barra_amistad.show_percentage = false
	barra_amistad.custom_minimum_size = Vector2(0.0, 16.0)
	barra_amistad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PIXEL_UI_THEME.apply(barra_amistad, false)
	contenido_amistad.add_child(barra_amistad)


func _amistad_a_valor_visual(amistad: float) -> float:
	return clampf(roundi((amistad + 100.0) * 0.495 + 1.0), 1.0, 100.0)


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
