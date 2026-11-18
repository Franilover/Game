extends CanvasLayer
## Archivo Real: consulta de habitantes y cronología histórica desde las tablas canónicas.
const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")

var _panel: PanelContainer
var _contenido: VBoxContainer
var _cuerpo: HBoxContainer
var _lista: VBoxContainer
var _detalle: VBoxContainer
var _estado: Label
var _personajes: Array[Dictionary] = []
var _reinos: Array[Dictionary] = []
var _eventos: Array[Dictionary] = []
var _reino_actual: Dictionary = {}
var _solicitudes: Dictionary = {}
var _vista := "personajes"
var _personaje_seleccionado: Dictionary = {}
var _imagen_detalle: TextureRect


func _ready() -> void:
	layer = 46
	_construir_interfaz()
	_cargar_catalogos()

func configurar_vista(vista: String) -> void:
	_vista = "historia" if vista == "historia_torres" else "personajes"


func _exit_tree() -> void:
	var cliente := get_node_or_null("/root/SupabaseClient")
	if cliente != null and cliente.request_completed.is_connected(_al_request_completed):
		cliente.request_completed.disconnect(_al_request_completed)


func _construir_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.025, 0.025, 0.035, 0.82)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(570, 320)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.add_child(_panel)
	PIXEL_UI_THEME.apply(_panel, false)

	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", 8)
	_panel.add_child(_contenido)

	var encabezado := HBoxContainer.new()
	_contenido.add_child(encabezado)
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_child(espacio)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.pressed.connect(queue_free)
	encabezado.add_child(cerrar)

	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(_estado)

	_cuerpo = HBoxContainer.new()
	_cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cuerpo.add_theme_constant_override("separation", 10)
	_contenido.add_child(_cuerpo)

	var panel_lista := PanelContainer.new()
	panel_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cuerpo.add_child(panel_lista)
	var margen_lista := MarginContainer.new()
	margen_lista.add_theme_constant_override("margin_left", 8)
	margen_lista.add_theme_constant_override("margin_top", 8)
	margen_lista.add_theme_constant_override("margin_right", 8)
	margen_lista.add_theme_constant_override("margin_bottom", 8)
	panel_lista.add_child(margen_lista)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margen_lista.add_child(_lista)

	var panel_detalle := PanelContainer.new()
	panel_detalle.custom_minimum_size.x = 180
	panel_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cuerpo.add_child(panel_detalle)
	var margen_detalle := MarginContainer.new()
	margen_detalle.add_theme_constant_override("margin_left", 8)
	margen_detalle.add_theme_constant_override("margin_top", 8)
	margen_detalle.add_theme_constant_override("margin_right", 8)
	margen_detalle.add_theme_constant_override("margin_bottom", 8)
	panel_detalle.add_child(margen_detalle)
	_detalle = VBoxContainer.new()
	_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margen_detalle.add_child(_detalle)

	var fondo_button: StyleBoxTexture = PIXEL_UI_THEME.button_surface_style()
	if fondo_button != null:
		panel_lista.add_theme_stylebox_override("panel", fondo_button.duplicate())
		panel_detalle.add_theme_stylebox_override("panel", fondo_button.duplicate())
	PIXEL_UI_THEME.apply(_contenido, false)


func _cargar_catalogos() -> void:
	var cliente := get_node_or_null("/root/SupabaseClient")
	if cliente == null:
		_estado.text = "No se encontró la conexión con Supabase."
		return
	if not cliente.request_completed.is_connected(_al_request_completed):
		cliente.request_completed.connect(_al_request_completed)
	var id_personajes: int = cliente.get_rest(
		"personajes",
		"select=id,nombre,img_url,sobre,reino,especie,caracteristicas,don,fecha_nacimiento,genero&reino=eq.Torres&order=nombre.asc"
	)
	var id_reinos: int = cliente.get_rest(
		"reinos",
		"select=id,nombre,orden&order=orden.asc"
	)
	_registrar_solicitud(id_personajes, "personajes")
	_registrar_solicitud(id_reinos, "reinos")
	_estado.text = ""


func _registrar_solicitud(id: int, tipo: String) -> void:
	if id >= 0:
		_solicitudes[id] = tipo
	else:
		_estado.text = "No se pudo iniciar la consulta a Supabase."


func _al_request_completed(id: int, resultado: int, codigo_http: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray) -> void:
	if not _solicitudes.has(id):
		return
	var tipo := str(_solicitudes[id])
	_solicitudes.erase(id)
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http < 200 or codigo_http >= 300:
		_estado.text = "No se pudieron cargar los datos (%s, HTTP %d)." % [tipo, codigo_http]
		return
	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK or not json.data is Array:
		_estado.text = "La respuesta de Supabase para %s no tiene un formato válido." % tipo
		return
	match tipo:
		"personajes":
			_personajes.clear()
			for fila: Variant in json.data:
				if fila is Dictionary:
					_personajes.append((fila as Dictionary).duplicate(true))
			_estado.text = ""
			if _vista == "personajes":
				_mostrar_personajes()
		"reinos":
			_reinos.clear()
			for fila: Variant in json.data:
				if fila is Dictionary:
					_reinos.append((fila as Dictionary).duplicate(true))
			_seleccionar_reino_inicial()
			if _vista == "historia":
				_mostrar_historia()
		"eventos":
			_eventos.clear()
			for fila: Variant in json.data:
				if fila is Dictionary:
					_eventos.append((fila as Dictionary).duplicate(true))
			_renderizar_eventos()


func _seleccionar_reino_inicial() -> void:
	_reino_actual.clear()
	for reino: Dictionary in _reinos:
		if str(reino.get("nombre", "")).strip_edges().to_lower() == "torres":
			_reino_actual = reino.duplicate(true)
			return


func _limpiar(contenedor: Node) -> void:
	for hijo in contenedor.get_children():
		contenedor.remove_child(hijo)
		hijo.queue_free()


func _mostrar_personajes() -> void:
	_vista = "personajes"
	_detalle.visible = true
	_lista.size_flags_stretch_ratio = 1.0
	_detalle.size_flags_stretch_ratio = 1.0
	_limpiar(_lista)
	_limpiar(_detalle)
	var encabezado := Label.new()
	encabezado.text = "HABITANTES DE TORRES"
	_lista.add_child(encabezado)
	if _personajes.is_empty():
		var vacio := Label.new()
		vacio.text = "No hay personajes registrados para Torres."
		_lista.add_child(vacio)
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_child(scroll)
	var filas := VBoxContainer.new()
	filas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(filas)
	for personaje: Dictionary in _personajes:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		filas.add_child(fila)
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(64, 68)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.tooltip_text = "Consultar ficha"
		boton.expand_icon = true
		boton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		var sprite_local := _cargar_sprite_personaje(personaje)
		if sprite_local != null:
			boton.icon = sprite_local
		boton.pressed.connect(_mostrar_ficha_personaje.bind(personaje))
		fila.add_child(boton)
		PIXEL_UI_THEME.apply(boton, false)
	var ayuda := Label.new()
	ayuda.text = "Selecciona un nombre para consultar su ficha."
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.add_child(ayuda)


func _mostrar_ficha_personaje(personaje: Dictionary) -> void:
	_personaje_seleccionado = personaje.duplicate(true)
	_limpiar(_detalle)
	var url := str(personaje.get("img_url", "")).strip_edges()
	_imagen_detalle = TextureRect.new()
	_imagen_detalle.custom_minimum_size = Vector2(112, 112)
	_imagen_detalle.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_imagen_detalle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagen_detalle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detalle.add_child(_imagen_detalle)
	var sprite_personaje := _cargar_sprite_personaje(personaje)
	if sprite_personaje != null:
		_imagen_detalle.texture = sprite_personaje
	elif not url.is_empty():
		_cargar_imagen_personaje(url, _imagen_detalle)

	var nacimiento_variant: Variant = personaje.get("fecha_nacimiento", null)
	var nacimiento := int(nacimiento_variant) if nacimiento_variant != null else -1
	var edad := _calcular_edad(nacimiento)
	_agregar_dato_ficha("Edad", edad)
	_agregar_dato_ficha("Género", str(personaje.get("genero", "")).strip_edges())
	_agregar_dato_ficha("Especie", str(personaje.get("especie", "")).strip_edges())
	_agregar_dato_ficha("Historia", str(personaje.get("sobre", "")).strip_edges())
	var caracteristicas := str(personaje.get("caracteristicas", "")).strip_edges()
	if not caracteristicas.is_empty():
		_agregar_dato_ficha("Características", caracteristicas)
	var don := str(personaje.get("don", "")).strip_edges()
	if not don.is_empty():
		_agregar_dato_ficha("Don", don)


func _agregar_dato_ficha(etiqueta: String, valor: String) -> void:
	var texto := Label.new()
	var contenido := valor if not valor.is_empty() else "Sin registrar"
	texto.text = etiqueta + ": " + contenido
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.add_child(texto)


func _calcular_edad(fecha_nacimiento: int) -> String:
	if fecha_nacimiento < 0:
		return "Sin fecha de nacimiento"
	var atmosfera := GameState._world_atmosphere as WorldAtmosphere
	if not is_instance_valid(atmosfera) or not bool(atmosfera.obtener_tiempo().get("calendario_cargado", false)):
		return "No disponible (calendario sin cargar)"
	var dias_anio := maxi(atmosfera.dias_por_anio, 1)
	var dia_actual := atmosfera.anio * dias_anio + atmosfera.dia_del_anio
	var dias_transcurridos := dia_actual - fecha_nacimiento
	if dias_transcurridos < 0:
		return "Fecha futura"
	return str(floori(float(dias_transcurridos) / float(dias_anio))) + " años"


func _cargar_sprite_personaje(personaje: Dictionary) -> Texture2D:
	var nombre := str(personaje.get("nombre", "")).strip_edges()
	var asset_key := nombre
	var sprite_key := ""
	for dato: Dictionary in WorldData.obtener_personajes_game():
		if str(dato.get("id", "")) == str(personaje.get("id", "")) or str(dato.get("nombre", "")).to_lower() == nombre.to_lower():
			asset_key = str(dato.get("asset_key", nombre)).strip_edges()
			sprite_key = str(dato.get("sprite_key", "")).strip_edges()
			break
	var claves: Array[String] = []
	if not sprite_key.is_empty() and not sprite_key.contains("/") and not sprite_key.contains("\\"):
		claves.append(sprite_key)
	if not asset_key.is_empty() and not asset_key.contains("/") and not asset_key.contains("\\") and asset_key not in claves:
		claves.append(asset_key)
	if not nombre.is_empty() and nombre not in claves:
		claves.append(nombre)
	for clave in claves:
		for ruta in [
			"res://assets/art/characters/" + clave + ".png",
			"res://assets/art/characters/skins/" + clave + ".png"
		]:
			if ResourceLoader.exists(ruta):
				var recurso := load(ruta) as Texture2D
				if recurso != null:
					return recurso
	if not sprite_key.is_empty():
		var ruta_sprite := "res://assets/art/characters/" + sprite_key
		if ResourceLoader.exists(ruta_sprite):
			return load(ruta_sprite) as Texture2D
	# Mismo sprite de reserva que usa Relaciones cuando un habitante aún no
	# tiene una ilustración individual registrada.
	var ruta_base := "res://assets/art/characters/Sprite-0004.png"
	if ResourceLoader.exists(ruta_base):
		return load(ruta_base) as Texture2D
	return null


func _cargar_imagen_personaje(url: String, destino: TextureRect) -> void:
	var solicitud := HTTPRequest.new()
	solicitud.timeout = 15.0
	add_child(solicitud)
	solicitud.request_completed.connect(func(resultado: int, codigo: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
		if not is_instance_valid(destino):
			solicitud.queue_free()
			return
		if resultado == HTTPRequest.RESULT_SUCCESS and codigo >= 200 and codigo < 300:
			var imagen := Image.new()
			var error := imagen.load_png_from_buffer(bytes)
			if error != OK:
				error = imagen.load_jpg_from_buffer(bytes)
			if error != OK:
				error = imagen.load_webp_from_buffer(bytes)
			if error == OK:
				destino.texture = ImageTexture.create_from_image(imagen)
		solicitud.queue_free()
	)
	var error_solicitud := solicitud.request(url)
	if error_solicitud != OK:
		solicitud.queue_free()


func _mostrar_historia() -> void:
	_vista = "historia"
	_detalle.visible = false
	_lista.size_flags_stretch_ratio = 1.0
	_limpiar(_lista)
	_limpiar(_detalle)
	var encabezado := Label.new()
	encabezado.text = "HISTORIA DE TORRES"
	_lista.add_child(encabezado)
	var ayuda := Label.new()
	ayuda.text = "Acontecimientos registrados en orden cronológico."
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lista.add_child(ayuda)
	var scroll := ScrollContainer.new()
	scroll.name = "EventosScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_child(scroll)
	var eventos_lista := VBoxContainer.new()
	eventos_lista.name = "EventosLista"
	eventos_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(eventos_lista)
	_renderizar_eventos()
	_cargar_eventos_reino()


func _cargar_eventos_reino() -> void:
	_eventos.clear()
	_renderizar_eventos()
	_seleccionar_reino_inicial()
	var reino_id := str(_reino_actual.get("id", ""))
	if reino_id.is_empty():
		_estado.text = "No se encontró el identificador del reino."
		return
	var cliente := get_node_or_null("/root/SupabaseClient")
	if cliente == null:
		return
	var id: int = cliente.get_rest(
		"eventos_mundo",
		"select=id,dia_absoluto,titulo,descripcion,reino_id,source&reino_id=eq.%s&order=dia_absoluto.asc" % reino_id
	)
	_registrar_solicitud(id, "eventos")
	_estado.text = ""


func _renderizar_eventos() -> void:
	if _vista != "historia":
		return
	var scroll := _lista.get_node_or_null("EventosScroll/EventosLista")
	if scroll == null:
		return
	_limpiar(scroll)
	if _eventos.is_empty():
		var vacio := Label.new()
		vacio.text = "Este reino todavía no tiene acontecimientos registrados."
		scroll.add_child(vacio)
		return
	for evento: Dictionary in _eventos:
		var tarjeta := PanelContainer.new()
		PIXEL_UI_THEME.apply(tarjeta, false)
		scroll.add_child(tarjeta)
		var bloque := VBoxContainer.new()
		tarjeta.add_child(bloque)
		var dia := Label.new()
		dia.text = "Día %s" % str(evento.get("dia_absoluto", "—"))
		bloque.add_child(dia)
		var nombre := Label.new()
		nombre.text = str(evento.get("titulo", "Acontecimiento"))
		nombre.add_theme_font_size_override("font_size", 13)
		nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bloque.add_child(nombre)
		var descripcion := Label.new()
		descripcion.text = str(evento.get("descripcion", ""))
		descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bloque.add_child(descripcion)
