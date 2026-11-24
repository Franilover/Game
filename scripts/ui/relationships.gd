extends Control

class_name RelationshipsUI

const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")

const TAMANO_RETRATO := Vector2(64.0, 72.0)
const SEPARACION_RETRATOS := 8

var lista: VBoxContainer
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
	var panel_detalle := get_node_or_null("DetailPanelRight") as PanelContainer
	if is_instance_valid(panel_detalle):
		panel_detalle.add_theme_stylebox_override("panel", PIXEL_UI_THEME.button_surface_style())

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
	_lista_scroll.custom_minimum_size = Vector2(190.0, 0.0)
	_lista_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_scroll.size_flags_stretch_ratio = 1.35
	_lista_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lista_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_lista_scroll.resized.connect(_ajustar_columnas_retratos)
	contenido.add_child(_lista_scroll)

	lista = VBoxContainer.new()
	lista.name = "KingdomGroups"
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 10)
	_lista_scroll.add_child(lista)

	var panel_detalle := PanelContainer.new()
	panel_detalle.name = "DetailPanelRight"
	panel_detalle.custom_minimum_size = Vector2(145.0, 0.0)
	panel_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_detalle.size_flags_stretch_ratio = 0.8
	panel_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(panel_detalle)

	var margen_detalle := MarginContainer.new()
	margen_detalle.name = "DetailPanelMargin"
	margen_detalle.add_theme_constant_override("margin_left", 7)
	margen_detalle.add_theme_constant_override("margin_top", 7)
	margen_detalle.add_theme_constant_override("margin_right", 7)
	margen_detalle.add_theme_constant_override("margin_bottom", 7)
	panel_detalle.add_child(margen_detalle)

	detalle = VBoxContainer.new()
	detalle.name = "DetailContent"
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detalle.add_theme_constant_override("separation", 8)
	margen_detalle.add_child(detalle)

	estado = Label.new()
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.add_theme_color_override("font_color", Color(0.55, 0.43, 0.29, 1.0))
	estado.add_theme_font_size_override("font_size", 10)
	columna.add_child(estado)
	call_deferred("_ajustar_columnas_retratos")


func _ajustar_columnas_retratos() -> void:
	if not is_instance_valid(lista) or not is_instance_valid(_lista_scroll):
		return
	# El ancho disponible ya excluye la barra vertical. Mantener una sola
	# columna en paneles estrechos evita que el GridContainer fuerce scroll
	# horizontal; en ventanas amplias se aprovecha el espacio hasta seis.
	var ancho_util := maxi(1, int(_lista_scroll.size.x) - 18)
	var paso := TAMANO_RETRATO.x + float(SEPARACION_RETRATOS)
	var columnas := clampi(floori(float(ancho_util + SEPARACION_RETRATOS) / paso), 1, 6)
	for rejilla_variant in lista.find_children("KingdomCharacterGrid", "GridContainer", true, false):
		var rejilla := rejilla_variant as GridContainer
		rejilla.columns = columnas


func _actualizar() -> void:
	_limpiar()

	# La lista visual depende del catálogo de personajes, no de que el
	# servicio de relaciones haya terminado de cargar. Antes se retornaba
	# aquí y se ocultaban todos los habitantes durante una carga social lenta.
	var personajes: Array[Dictionary] = WorldData.obtener_personajes_game()
	if personajes.is_empty():
		estado.text = "Sin habitantes"
		return

	var grupos: Dictionary = {}
	for personaje in personajes:
		var clave_reino := _clave_reino_personaje(personaje)
		if not grupos.has(clave_reino):
			grupos[clave_reino] = []
		(grupos[clave_reino] as Array).append(personaje)

	var claves_reinos: Array = grupos.keys()
	claves_reinos.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _nombre_reino(str(a)) < _nombre_reino(str(b))
	)
	for clave_reino_variant in claves_reinos:
		var clave_reino := str(clave_reino_variant)
		var seccion := PanelContainer.new()
		seccion.name = "Kingdom_" + clave_reino
		seccion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fondo_reino: StyleBox = PIXEL_UI_THEME.button_surface_style()
		if fondo_reino != null:
			seccion.add_theme_stylebox_override("panel", fondo_reino)
		lista.add_child(seccion)

		var margen_reino := MarginContainer.new()
		margen_reino.add_theme_constant_override("margin_left", 8)
		margen_reino.add_theme_constant_override("margin_top", 6)
		margen_reino.add_theme_constant_override("margin_right", 8)
		margen_reino.add_theme_constant_override("margin_bottom", 7)
		seccion.add_child(margen_reino)

		var contenido_reino := VBoxContainer.new()
		contenido_reino.add_theme_constant_override("separation", 6)
		margen_reino.add_child(contenido_reino)

		var titulo_reino := Label.new()
		titulo_reino.name = "KingdomHeading"
		titulo_reino.text = _nombre_reino(clave_reino).to_upper()
		titulo_reino.add_theme_color_override("font_color", Color("#E6D0A6"))
		titulo_reino.add_theme_font_size_override("font_size", 12)
		contenido_reino.add_child(titulo_reino)

		var rejilla := GridContainer.new()
		rejilla.name = "KingdomCharacterGrid"
		rejilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rejilla.add_theme_constant_override("h_separation", SEPARACION_RETRATOS)
		rejilla.add_theme_constant_override("v_separation", SEPARACION_RETRATOS)
		contenido_reino.add_child(rejilla)
		for personaje_variant in grupos[clave_reino] as Array:
			if personaje_variant is Dictionary:
				_crear_tarjeta_personaje(personaje_variant as Dictionary, rejilla)

	call_deferred("_ajustar_columnas_retratos")

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


func _clave_reino_personaje(personaje: Dictionary) -> String:
	for campo in ["reino_clave", "reino", "reino_id", "reino_nombre"]:
		var valor := str(personaje.get(campo, "")).strip_edges()
		if not valor.is_empty():
			return valor.to_lower().replace(" ", "_")
	var nacionalidad := str(personaje.get("nacionalidad", "")).strip_edges().to_lower()
	if nacionalidad.contains("frosl"):
		return "froslia"
	if nacionalidad.contains("torres"):
		return "torres"
	return "sin_reino"


func _nombre_reino(clave: String) -> String:
	if clave == "froslia":
		return "Froslia"
	if clave == "torres":
		return "Torres"
	var reinos: Array[Dictionary] = WorldData.obtener_reinos_game()
	for reino in reinos:
		if str(reino.get("clave", "")).strip_edges().to_lower() == clave.to_lower() or str(reino.get("id", "")).strip_edges().to_lower() == clave.to_lower():
			return str(reino.get("nombre", clave.capitalize()))
	return clave.replace("_", " ").capitalize()


func _crear_tarjeta_personaje(personaje: Dictionary, rejilla: GridContainer) -> void:
	# El catálogo ya contiene habitantes jugables/sociales; no excluirlos
	# por campos opcionales de activación que pueden faltar en snapshots antiguos.
	var personaje_id := str(personaje.get("id", "")).strip_edges()
	if personaje_id.is_empty():
		return
	var nombre := str(personaje.get("nombre", "")).strip_edges()
	if nombre.is_empty():
		nombre = personaje_id
	var asset_key := str(personaje.get("asset_key", nombre)).strip_edges()
	var visual := WorldData.obtener_configuracion_visual_personaje_game(personaje_id)
	_personajes_por_id[personaje_id] = {
		"nombre": nombre,
		"asset_key": asset_key,
		"sprite_key": str(personaje.get("sprite_key", "")).strip_edges(),
		"sprite_path": str(visual.get("sprite_path", "")).strip_edges(),
		"portrait_path": str(visual.get("portrait_path", "")).strip_edges()
	}

	var boton := Button.new()
	boton.name = "RelationshipPortraitButton"
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

	var textura_cara := _cargar_textura_ruta(str(visual.get("portrait_path", "")))
	if textura_cara == null:
		textura_cara = _cargar_textura_ruta(str(visual.get("sprite_path", "")))
	if textura_cara == null:
		textura_cara = _cargar_retrato_cara(asset_key, nombre)
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

	var fondo_nombre := PanelContainer.new()
	fondo_nombre.name = "NameButtonSurface"
	fondo_nombre.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fondo_nombre.offset_left = 2.0
	fondo_nombre.offset_right = -2.0
	fondo_nombre.offset_top = -16.0
	fondo_nombre.offset_bottom = -1.0
	fondo_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo_nombre.add_theme_stylebox_override("panel", PIXEL_UI_THEME.button_surface_style())
	var nombre_margen := MarginContainer.new()
	nombre_margen.add_theme_constant_override("margin_left", 2)
	nombre_margen.add_theme_constant_override("margin_right", 2)
	nombre_margen.add_theme_constant_override("margin_top", 0)
	nombre_margen.add_theme_constant_override("margin_bottom", 0)
	var etiqueta := Label.new()
	etiqueta.text = nombre
	etiqueta.clip_text = true
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", 8)
	etiqueta.add_theme_color_override("font_color", Color("#FFF3D6"))
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nombre_margen.add_child(etiqueta)
	fondo_nombre.add_child(nombre_margen)
	boton.add_child(fondo_nombre)

	rejilla.add_child(boton)
	_botones.append(boton)



func _cargar_textura_ruta(ruta: String) -> Texture2D:
	var ruta_limpia := ruta.strip_edges()
	if ruta_limpia.is_empty() or not ruta_limpia.begins_with("res://") or not ResourceLoader.exists(ruta_limpia):
		return null
	var recurso: Resource = ResourceLoader.load(ruta_limpia)
	return recurso as Texture2D if recurso is Texture2D else null


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


func _cargar_sprite_mapa(sprite_key: String, nombre: String, tiene_personaje: bool) -> Texture2D:
	var claves: Array[String] = []
	if not sprite_key.is_empty() and not sprite_key.contains("/") and not sprite_key.contains("\\"):
		claves.append(sprite_key)
	if not nombre.is_empty() and not nombre.contains("/") and not nombre.contains("\\") and nombre not in claves:
		claves.append(nombre)
	for clave in claves:
		for extension in [".png", ".PNG"]:
			var ruta: String = "res://assets/art/characters/" + clave + str(extension)
			if not ResourceLoader.exists(ruta):
				continue
			var recurso: Resource = load(ruta)
			if recurso is Texture2D:
				return recurso as Texture2D

	# Es el mismo fallback que utiliza Creature._cargar_sprite() en el mapa.
	if tiene_personaje:
		var ruta_base := "res://assets/art/characters/Sprite-0004.png"
		if ResourceLoader.exists(ruta_base):
			return load(ruta_base) as Texture2D
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
	var sprite_key := str(datos_personaje.get("sprite_key", "")).strip_edges()
	var sprite_path := str(datos_personaje.get("sprite_path", "")).strip_edges()
	var portrait_path := str(datos_personaje.get("portrait_path", "")).strip_edges()
	var textura_cara := _cargar_textura_ruta(portrait_path)
	if textura_cara == null:
		textura_cara = _cargar_textura_ruta(sprite_path)
	if textura_cara == null:
		textura_cara = _cargar_retrato_cara(asset_key, nombre)
	var textura_retrato := textura_cara if textura_cara != null else _cargar_retrato(asset_key, nombre)
	var textura_mapa := _cargar_textura_ruta(sprite_path)
	if textura_mapa == null:
		textura_mapa = _cargar_sprite_mapa(sprite_key, nombre, not personaje_id.is_empty())

	# Las dos referencias visuales comparten el mismo ancho: retrato de perfil
	# a la izquierda y sprite real de exploración a la derecha.
	# Cada imagen tiene su propia superficie Button y no necesita rótulo.
	var fila_imagenes := HBoxContainer.new()
	fila_imagenes.name = "CharacterImagesRow"
	fila_imagenes.custom_minimum_size = Vector2(0.0, 112.0)
	fila_imagenes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_imagenes.add_theme_constant_override("separation", 5)
	detalle.add_child(fila_imagenes)

	var marco_retrato := PanelContainer.new()
	marco_retrato.name = "PortraitButtonSurface"
	marco_retrato.custom_minimum_size = Vector2(0.0, 112.0)
	marco_retrato.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marco_retrato.size_flags_stretch_ratio = 1.0
	marco_retrato.add_theme_stylebox_override("panel", PIXEL_UI_THEME.button_surface_style())
	fila_imagenes.add_child(marco_retrato)

	var retrato_cara := TextureRect.new()
	retrato_cara.name = "CharacterFace"
	retrato_cara.custom_minimum_size = Vector2(0.0, 102.0)
	retrato_cara.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retrato_cara.size_flags_vertical = Control.SIZE_EXPAND_FILL
	retrato_cara.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato_cara.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato_cara.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	retrato_cara.texture = textura_retrato
	if textura_retrato == null:
		var iniciales_retrato := Label.new()
		iniciales_retrato.name = "CharacterFaceFallback"
		iniciales_retrato.text = nombre.substr(0, 2).to_upper()
		iniciales_retrato.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		iniciales_retrato.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		iniciales_retrato.add_theme_font_size_override("font_size", 20)
		marco_retrato.add_child(iniciales_retrato)
	else:
		marco_retrato.add_child(retrato_cara)

	var marco_mapa := PanelContainer.new()
	marco_mapa.name = "MapSpriteButtonSurface"
	marco_mapa.custom_minimum_size = Vector2(0.0, 112.0)
	marco_mapa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marco_mapa.size_flags_stretch_ratio = 1.0
	marco_mapa.add_theme_stylebox_override("panel", PIXEL_UI_THEME.button_surface_style())
	fila_imagenes.add_child(marco_mapa)

	var sprite_mapa := TextureRect.new()
	sprite_mapa.name = "CharacterMapSprite"
	sprite_mapa.custom_minimum_size = Vector2(0.0, 102.0)
	sprite_mapa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_mapa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_mapa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_mapa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_mapa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_mapa.texture = textura_mapa
	if textura_mapa == null:
		var sin_sprite := Label.new()
		sin_sprite.name = "MapSpriteFallback"
		sin_sprite.text = "—"
		sin_sprite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sin_sprite.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sin_sprite.add_theme_font_size_override("font_size", 18)
		marco_mapa.add_child(sin_sprite)
	else:
		marco_mapa.add_child(sprite_mapa)

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
	# La superficie Button del panel derecho ya contiene toda la columna;
	# la sección de amistad queda transparente para evitar un segundo recuadro.
	panel_amistad.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
	barra_amistad.min_value = 0.0
	barra_amistad.max_value = 100.0
	barra_amistad.value = amistad_visual
	barra_amistad.show_percentage = false
	barra_amistad.custom_minimum_size = Vector2(0.0, 16.0)
	barra_amistad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PIXEL_UI_THEME.apply(barra_amistad, false)
	# Usar las mismas texturas de las barras de vida; evitar el relleno
	# rectangular predeterminado de ProgressBar.
	var marco_amistad := load("res://assets/art/UI/Menus/bar_frame.png") as Texture2D
	var relleno_amistad := load("res://assets/art/UI/Menus/bar_fill_health.png") as Texture2D
	if marco_amistad != null:
		var estilo_marco := StyleBoxTexture.new()
		estilo_marco.texture = marco_amistad
		estilo_marco.texture_margin_left = 3
		estilo_marco.texture_margin_top = 3
		estilo_marco.texture_margin_right = 3
		estilo_marco.texture_margin_bottom = 3
		barra_amistad.add_theme_stylebox_override("background", estilo_marco)
	if relleno_amistad != null:
		var estilo_relleno := StyleBoxTexture.new()
		estilo_relleno.texture = relleno_amistad
		estilo_relleno.texture_margin_left = 2
		estilo_relleno.texture_margin_top = 2
		estilo_relleno.texture_margin_right = 2
		estilo_relleno.texture_margin_bottom = 2
		barra_amistad.add_theme_stylebox_override("fill", estilo_relleno)
	contenido_amistad.add_child(barra_amistad)


func _amistad_a_valor_visual(amistad: float) -> float:
	return clampf(amistad, 0.0, 100.0)


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
