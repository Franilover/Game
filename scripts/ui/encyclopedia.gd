extends Control


var _ids_descubiertos: Array[String] = []
var _arbol: Tree
var _nombre: Label
var _ficha: RichTextLabel
var _icono: TextureRect
var _contenedor_superior_detalle: VBoxContainer
var _tab_biomas: Button
var _tab_criaturas: Button
var _barra_tabs: HBoxContainer
var solo_garumis: bool = false
var _modo: String = "biomas"

var _garumis_catalogo: Array[Dictionary] = []
var _garumis_por_id: Dictionary = {}
var _garumi_originales: Array[Dictionary] = []
var _solicitud_catalogo_garumis: int = -1
var _catalogo_garumis_cargado: bool = false

const ORUMI_ORIGINAL_ID: String = "24f86486-aced-4a23-bd1b-f025561a8aa3"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_interfaz()

	if GameState.has_signal("enciclopedia_actualizada"):
		if not GameState.enciclopedia_actualizada.is_connected(_al_descubrir_criatura):
			GameState.enciclopedia_actualizada.connect(_al_descubrir_criatura)

	if GameState.has_signal("descubrimientos_mundo_actualizados"):
		if not GameState.descubrimientos_mundo_actualizados.is_connected(_al_descubrimiento_mundo_actualizado):
			GameState.descubrimientos_mundo_actualizados.connect(_al_descubrimiento_mundo_actualizado)

	if not WorldData.mundo_listo.is_connected(_al_mundo_actualizado):
		WorldData.mundo_listo.connect(_al_mundo_actualizado)

	if not WorldData.mundo_actualizado.is_connected(_al_mundo_actualizado):
		WorldData.mundo_actualizado.connect(_al_mundo_actualizado)
	if not SupabaseClient.request_completed.is_connected(_al_respuesta_catalogo_garumis):
		SupabaseClient.request_completed.connect(_al_respuesta_catalogo_garumis)
	_cargar_catalogo_garumis()
	if solo_garumis:
		_barra_tabs.visible = false
		_mostrar_garumis()
	else:
		actualizar()


func _crear_interfaz() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)

	var tabs := HBoxContainer.new()
	_barra_tabs = tabs
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.alignment = BoxContainer.ALIGNMENT_BEGIN
	tabs.add_theme_constant_override("separation", 3)
	column.add_child(tabs)

	_tab_biomas = Button.new()
	_tab_biomas.text = "Biomas"
	_tab_biomas.toggle_mode = true
	_tab_biomas.button_pressed = true
	_configurar_boton_seccion(_tab_biomas)
	_tab_biomas.pressed.connect(_mostrar_biomas)
	tabs.add_child(_tab_biomas)

	_tab_criaturas = Button.new()
	_tab_criaturas.text = "Criaturas"
	_tab_criaturas.toggle_mode = true
	_configurar_boton_seccion(_tab_criaturas)
	_tab_criaturas.pressed.connect(_mostrar_criaturas)
	tabs.add_child(_tab_criaturas)


	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	column.add_child(body)

	_arbol = Tree.new()
	_arbol.custom_minimum_size = Vector2(190, 0)
	_arbol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arbol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arbol.hide_root = true
	_arbol.columns = 1
	_arbol.set_column_titles_visible(false)
	_arbol.add_theme_color_override("font_color", Color(0.78, 0.66, 0.46, 1.0))
	_arbol.add_theme_color_override("font_selected_color", Color(0.95, 0.88, 0.7, 1.0))

	var estilo_arbol := StyleBoxFlat.new()
	estilo_arbol.bg_color = Color(0.075, 0.05, 0.035, 0.9)
	estilo_arbol.border_width_left = 1
	estilo_arbol.border_width_top = 1
	estilo_arbol.border_width_right = 1
	estilo_arbol.border_width_bottom = 1
	estilo_arbol.border_color = Color(0.29, 0.19, 0.12, 1.0)
	_arbol.add_theme_stylebox_override("panel", estilo_arbol)
	_arbol.item_selected.connect(_al_seleccionar)
	_arbol.item_mouse_selected.connect(_al_click_arbol)
	body.add_child(_arbol)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var estilo_detalle := StyleBoxFlat.new()
	estilo_detalle.bg_color = Color(0.075, 0.05, 0.035, 0.9)
	estilo_detalle.border_width_left = 1
	estilo_detalle.border_width_top = 1
	estilo_detalle.border_width_right = 1
	estilo_detalle.border_width_bottom = 1
	estilo_detalle.border_color = Color(0.29, 0.19, 0.12, 1.0)
	detail_panel.add_theme_stylebox_override("panel", estilo_detalle)
	body.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 5)
	detail_margin.add_theme_constant_override("margin_top", 5)
	detail_margin.add_theme_constant_override("margin_right", 5)
	detail_margin.add_theme_constant_override("margin_bottom", 5)
	detail_panel.add_child(detail_margin)

	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 4)
	detail_margin.add_child(detail_column)

	var top := VBoxContainer.new()
	_contenedor_superior_detalle = top
	top.custom_minimum_size = Vector2(0, 72)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 5)
	detail_column.add_child(top)

	_icono = TextureRect.new()
	_icono.custom_minimum_size = Vector2(64, 54)
	_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono.visible = false
	top.add_child(_icono)

	_nombre = Label.new()
	_nombre.text = "Selecciona un registro"
	_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nombre.add_theme_color_override("font_color", Color(0.9, 0.79, 0.58, 1.0))
	_nombre.add_theme_font_size_override("font_size", 12)
	top.add_child(_nombre)

	_ficha = RichTextLabel.new()
	_ficha.bbcode_enabled = true
	_ficha.fit_content = false
	_ficha.scroll_active = true
	_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ficha.add_theme_color_override("default_color", Color(0.72, 0.61, 0.45, 1.0))
	_ficha.add_theme_font_size_override("normal_font_size", 11)
	detail_column.add_child(_ficha)


func _configurar_boton_seccion(boton: Button) -> void:
	# Subpestañas compactas que se reparten horizontalmente y sólo dibujan el borde.
	boton.custom_minimum_size = Vector2(0, 23)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.size_flags_stretch_ratio = 1.0
	boton.add_theme_constant_override("h_separation", 2)
	boton.add_theme_color_override("font_color", Color(0.61, 0.49, 0.34, 1))
	boton.add_theme_color_override("font_hover_color", Color(0.82, 0.70, 0.51, 1))
	boton.add_theme_color_override("font_pressed_color", Color(0.94, 0.85, 0.66, 1))
	boton.add_theme_font_size_override("font_size", 9)
	var transparente := Color(0, 0, 0, 0)
	var normal := _crear_estilo_boton(transparente, Color(0.22, 0.15, 0.09, 0.8), 1)
	var hover := _crear_estilo_boton(transparente, Color(0.39, 0.29, 0.17, 1), 1)
	var activo := _crear_estilo_boton(transparente, Color(0.57, 0.44, 0.24, 1), 1)
	for estilo in [normal, hover, activo]:
		estilo.set_content_margin_all(7)
		estilo.set_border_width_all(1)
		estilo.corner_radius_top_left = 3
		estilo.corner_radius_top_right = 3
		estilo.corner_radius_bottom_left = 3
		estilo.corner_radius_bottom_right = 3
	boton.add_theme_stylebox_override("normal", normal)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", activo)
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _crear_estilo_boton(fondo: Color, borde: Color, borde_inferior: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(1)
	estilo.border_width_bottom = borde_inferior
	estilo.corner_radius_top_left = 3
	estilo.corner_radius_top_right = 3
	return estilo

func actualizar() -> void:
	if _arbol == null:
		return

	match _modo:
		"criaturas":
			_construir_lista_criaturas()
		"garumis":
			_construir_lista_garumis()
		_:
			_construir_arbol_biomas()


func _mostrar_biomas() -> void:
	_modo = "biomas"
	_arbol.columns = 1
	_arbol.remove_theme_font_size_override("font_size")
	_arbol.set_column_titles_visible(false)
	_tab_biomas.button_pressed = true
	_tab_criaturas.button_pressed = false
	actualizar()


func _mostrar_criaturas() -> void:
	_modo = "criaturas"
	_arbol.columns = 1
	_arbol.remove_theme_font_size_override("font_size")
	_arbol.set_column_titles_visible(false)
	_tab_biomas.button_pressed = false
	_tab_criaturas.button_pressed = true
	actualizar()


func _mostrar_garumis() -> void:
	_modo = "garumis"
	_arbol.columns = 3
	_arbol.add_theme_font_size_override("font_size", 9)
	_arbol.set_column_titles_visible(false)
	_arbol.set_column_expand(0, false)
	_arbol.set_column_expand(1, true)
	_arbol.set_column_expand(2, false)
	_arbol.set_column_custom_minimum_width(0, 38)
	_arbol.set_column_custom_minimum_width(2, 38)
	_tab_biomas.button_pressed = false
	_tab_criaturas.button_pressed = false
	if not _catalogo_garumis_cargado and _solicitud_catalogo_garumis < 0:
		_cargar_catalogo_garumis()
	actualizar()


func abrir_en_garumis() -> void:
	visible = true
	_mostrar_garumis()


func configurar_como_garudex() -> void:
	solo_garumis = true
	if is_inside_tree():
		if is_instance_valid(_barra_tabs):
			_barra_tabs.visible = false
		_mostrar_garumis()


func _cargar_catalogo_garumis() -> void:
	if _catalogo_garumis_cargado or _solicitud_catalogo_garumis >= 0:
		return
	# En builds offline/tests puede no existir configuración de Supabase. La
	# enciclopedia sigue funcionando con el catálogo incluido en WorldData.
	var diagnostico: Dictionary = SupabaseClient.obtener_diagnostico_debug()
	if not bool(diagnostico.get("configurado", false)):
		_usar_catalogo_garumis_del_mundo()
		_catalogo_garumis_cargado = true
		return
	var consulta := (
		"select=entidad_id,tipo_registro,nombre,numero_global,numero_origen,"
		+ "categoria_garumi,original_id,nombre_original,estado_evolutivo,"
		+ "estado_documentacion,descripcion,letra_original,orden_catalogo"
		+ "&order=orden_catalogo.asc"
	)
	_solicitud_catalogo_garumis = SupabaseClient.get_rest("v_garumi_catalogo_numerado_v1", consulta)
	if _solicitud_catalogo_garumis < 0:
		_usar_catalogo_garumis_del_mundo()


func _al_respuesta_catalogo_garumis(
	solicitud_id: int,
	resultado: int,
	codigo_http: int,
	_cabeceras: PackedStringArray,
	cuerpo: PackedByteArray
) -> void:
	if solicitud_id != _solicitud_catalogo_garumis:
		return
	_solicitud_catalogo_garumis = -1
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo_http < 200 or codigo_http >= 300:
		_usar_catalogo_garumis_del_mundo()
		if _modo == "garumis":
			actualizar()
		return
	var json := JSON.new()
	if json.parse(cuerpo.get_string_from_utf8()) != OK or not json.data is Array:
		_usar_catalogo_garumis_del_mundo()
		if _modo == "garumis":
			actualizar()
		return
	_catalogo_garumis_cargado = true
	_aplicar_catalogo_desde_filas(json.data as Array)
	if _modo == "garumis":
		actualizar()


func _aplicar_catalogo_desde_filas(filas: Array) -> void:
	_garumi_originales.clear()
	_garumis_catalogo.clear()
	_garumis_por_id.clear()
	for fila_variant in filas:
		if not fila_variant is Dictionary:
			continue
		var fila := (fila_variant as Dictionary).duplicate(true)
		var tipo := str(fila.get("tipo_registro", ""))
		if tipo == "original":
			if _es_original_orumi(fila) and not str(fila.get("letra_original", "")).strip_edges().is_empty():
				_garumi_originales.append(fila)
			continue
		if tipo != "especie" or not _es_linaje_orumi(fila):
			continue
		var estado := str(fila.get("estado_documentacion", "")).strip_edges().to_lower()
		if estado not in ["canon", "aprobado"]:
			continue
		var id := str(fila.get("entidad_id", fila.get("id", ""))).strip_edges()
		var nombre := str(fila.get("nombre", "")).strip_edges()
		if id.is_empty() or nombre.is_empty() or _garumis_por_id.has(id):
			continue
		fila["id"] = id
		_garumis_catalogo.append(fila)
		_garumis_por_id[id] = fila
	_garumi_originales.sort_custom(_ordenar_por_orden_catalogo)
	_garumis_catalogo.sort_custom(_ordenar_por_orden_catalogo)


func _es_original_orumi(registro: Dictionary) -> bool:
	var id := str(registro.get("entidad_id", registro.get("id", ""))).strip_edges()
	var nombre := str(registro.get("nombre", "")).strip_edges().to_lower()
	return id == ORUMI_ORIGINAL_ID or nombre == "orumi"


func _es_linaje_orumi(registro: Dictionary) -> bool:
	var original_id := str(registro.get("original_id", "")).strip_edges()
	if original_id == ORUMI_ORIGINAL_ID:
		return true
	# Respaldo para snapshots que aún no incluyan original_id.
	var nombre_original := str(registro.get("nombre_original", "")).strip_edges().to_lower()
	return nombre_original == "orumi"


func _ordenar_por_orden_catalogo(a: Dictionary, b: Dictionary) -> bool:
	var orden_a := int(a.get("orden_catalogo", a.get("numero_global", 0)))
	var orden_b := int(b.get("orden_catalogo", b.get("numero_global", 0)))
	if orden_a == orden_b:
		return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()
	return orden_a < orden_b


func _usar_catalogo_garumis_del_mundo() -> void:
	_garumi_originales.clear()
	_garumis_catalogo.clear()
	_garumis_por_id.clear()
	for registro_variant in WorldData.obtener_garumis_game():
		if not registro_variant is Dictionary:
			continue
		var registro := (registro_variant as Dictionary).duplicate(true)
		var id := str(registro.get("id", "")).strip_edges()
		var nombre := str(registro.get("nombre", "")).strip_edges()
		if id.is_empty() or nombre.is_empty() or not _es_linaje_orumi(registro):
			continue
		if str(registro.get("estado_documentacion", "canon")).to_lower() not in ["canon", "aprobado"]:
			continue
		registro["tipo_registro"] = "especie"
		registro["entidad_id"] = id
		_garumis_catalogo.append(registro)
		_garumis_por_id[id] = registro
	_garumis_catalogo.sort_custom(_ordenar_por_orden_catalogo)


func _construir_arbol_biomas() -> void:
	_arbol.clear()
	var raiz := _arbol.create_item()
	var descubrimientos: Dictionary = GameState.obtener_descubrimientos_mundo()
	var biomas_descubiertos := _obtener_descubiertos(descubrimientos, "biomas")
	var ecosistemas_descubiertos := _obtener_descubiertos(descubrimientos, "ecosistemas")
	var habitats_descubiertos := _obtener_descubiertos(descubrimientos, "habitats")

	var primero: TreeItem = null

	var biomas: Array[Dictionary] = _obtener_registros(WorldData.obtener_biomas(), biomas_descubiertos)
	biomas.sort_custom(_ordenar_registros)

	for bioma in biomas:
		var bioma_item := _agregar_item(raiz, bioma, "bioma")
		if primero == null:
			primero = bioma_item

		var ecosistemas: Array[Dictionary] = _obtener_registros(
			bioma.get("ecosistemas", []),
			ecosistemas_descubiertos
		)
		ecosistemas.sort_custom(_ordenar_registros)

		for ecosistema in ecosistemas:
			var eco_item := _agregar_item(bioma_item, ecosistema, "ecosistema")

			var habitats: Array[Dictionary] = _obtener_registros(
				ecosistema.get("habitats", []),
				habitats_descubiertos
			)
			habitats.sort_custom(_ordenar_registros)

			for habitat in habitats:
				_agregar_item(eco_item, habitat, "habitat")

	if primero == null:
		_mostrar_sin_descubrimientos()
		return

	_arbol.set_selected(primero, 0)
	_mostrar_item(primero)


func _construir_lista_criaturas() -> void:
	_arbol.clear()
	var raiz := _arbol.create_item()
	var criaturas_descubiertas := _obtener_descubiertos(
		GameState.obtener_descubrimientos_mundo(),
		"criaturas"
	)

	var criaturas: Array[Dictionary] = _obtener_registros(
		WorldData.obtener_criaturas(),
		criaturas_descubiertas
	)
	criaturas.sort_custom(_ordenar_registros)

	var primero: TreeItem = null
	for criatura in criaturas:
		var item := _agregar_item(raiz, criatura, "criatura")
		if primero == null:
			primero = item

	if primero == null:
		_mostrar_sin_descubrimientos()
		return

	_arbol.set_selected(primero, 0)
	_mostrar_item(primero)


func _construir_lista_garumis() -> void:
	_arbol.columns = 3
	_arbol.clear()
	var raiz := _arbol.create_item()
	var grupos_por_letra: Dictionary = {}
	var primero: TreeItem = null
	for original in _garumi_originales:
		var letra := str(original.get("letra_original", "")).strip_edges()
		if letra.is_empty() or grupos_por_letra.has(letra):
			continue
		var grupo := _arbol.create_item(raiz)
		grupo.set_text(0, "%s · %s" % [letra, str(original.get("nombre", "Original"))])
		grupo.set_metadata(0, {"nivel": "garumi_original", "letra": letra})
		grupos_por_letra[letra] = grupo
		if primero == null:
			primero = grupo
	for garumi in _garumis_catalogo:
		var letra := str(garumi.get("letra_original", "")).strip_edges()
		var clave_grupo := letra if not letra.is_empty() else "__sin_linaje__"
		if not grupos_por_letra.has(clave_grupo):
			var nombre_original := str(garumi.get("nombre_original", "")).strip_edges()
			var grupo := _arbol.create_item(raiz)
			grupo.set_text(0, nombre_original if letra.is_empty() else "%s · %s" % [letra, nombre_original if not nombre_original.is_empty() else "Linaje"])
			grupo.set_metadata(0, {"nivel": "garumi_original", "letra": letra})
			grupos_por_letra[clave_grupo] = grupo
			if primero == null:
				primero = grupo
		var padre := grupos_por_letra[clave_grupo] as TreeItem
		var item := _agregar_item(padre, garumi, "garumi")
		if primero == null:
			primero = item
	if primero == null:
		_nombre.text = "Enciclopedia de Garumis"
		_icono.texture = null
		_icono.visible = false
		_ficha.text = "[center][color=#8f754f]No hay Garumis canónicos o aprobados disponibles.[/color][/center]"
		return
	_arbol.set_selected(primero, 0)
	_mostrar_item(primero)


func _obtener_registros(registros_variant: Variant, descubiertos: Dictionary) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if not registros_variant is Array:
		return resultado

	for registro_variant in registros_variant as Array:
		if not registro_variant is Dictionary:
			continue

		var registro := registro_variant as Dictionary
		var id := str(registro.get("id", ""))
		if id.is_empty() or not descubiertos.has(id):
			continue

		resultado.append(registro)

	return resultado


func _obtener_descubiertos(descubrimientos: Dictionary, categoria: String) -> Dictionary:
	var registros_variant: Variant = descubrimientos.get(categoria, {})
	if registros_variant is Dictionary:
		return registros_variant as Dictionary
	return {}


func _agregar_item(padre: TreeItem, registro: Dictionary, nivel: String) -> TreeItem:
	var item := _arbol.create_item(padre)
	var nombre := str(registro.get("nombre", "Sin nombre"))
	if nivel == "garumi":
		var local := int(registro.get("numero_origen", 0))
		var global_num := int(registro.get("numero_global", 0))
		# Numeración local del Original a la izquierda, nombre al centro y
		# número global del catálogo a la derecha. Así se distinguen ambos
		# números cuando se incorporen los linajes de Varum y Nyru.
		item.set_text(0, str(local) if local > 0 else "—")
		item.set_text(1, nombre)
		item.set_text(2, str(global_num) if global_num > 0 else "—")
		item.set_text_alignment(0, HORIZONTAL_ALIGNMENT_LEFT)
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_LEFT)
		item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		item.set_text(0, nombre)
	item.set_metadata(0, {
		"nivel": nivel,
		"id": str(registro.get("id", ""))
	})
	return item


func _ordenar_registros(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()


func _al_seleccionar() -> void:
	var item := _arbol.get_selected()
	if item == null:
		return
	_mostrar_item(item)


func _al_click_arbol(posicion: Vector2, boton: int) -> void:
	if boton != MOUSE_BUTTON_LEFT:
		return

	var item := _arbol.get_item_at_position(posicion)
	if item == null:
		return

	_arbol.set_selected(item, 0)
	_mostrar_item(item)


func _mostrar_item(item: TreeItem) -> void:
	_restaurar_ficha_detalle()
	var metadata_variant: Variant = item.get_metadata(0)
	if not metadata_variant is Dictionary:
		return

	var metadata := metadata_variant as Dictionary
	var nivel := str(metadata.get("nivel", ""))
	var id := str(metadata.get("id", ""))
	if nivel == "garumi_original":
		_mostrar_ficha_original(str(metadata.get("letra", "")))
		return
	var registro := _obtener_registro_por_nivel(nivel, id)

	if nivel.is_empty() or id.is_empty() or registro.is_empty():
		return

	_nombre.text = str(registro.get("nombre", "Sin nombre"))
	_icono.texture = null
	_icono.visible = false
	if nivel in ["bioma", "ecosistema", "habitat"]:
		_mostrar_sprite_terreno(nivel, registro)

	var partes: Array[String] = []

	if nivel == "criatura":
		_mostrar_ficha_criatura(id, registro, partes)
		return
	if nivel == "garumi":
		_mostrar_ficha_garumi(registro, partes)
		return

	match nivel:
		"bioma":
			partes.append("[color=#8f754f]Ecosistemas:[/color] " + str(_contar_hijos_descubiertos(
				registro.get("ecosistemas", []),
				_obtener_descubiertos(GameState.obtener_descubrimientos_mundo(), "ecosistemas")
			)))
			partes.append("[color=#8f754f]Criaturas en este bioma:[/color]")
			_agregar_criaturas_de_bioma(registro, partes)
		"ecosistema":
			partes.append("[color=#8f754f]Hábitats:[/color] " + str(_contar_hijos_descubiertos(
				registro.get("habitats", []),
				_obtener_descubiertos(GameState.obtener_descubrimientos_mundo(), "habitats")
			)))
			partes.append("[color=#8f754f]Criaturas en este ecosistema:[/color]")
			_agregar_criaturas_de_ecosistema(registro, partes)
		"habitat":
			partes.append("[color=#8f754f]Criaturas:[/color]")
			_agregar_criaturas_de_habitat(registro, partes)

	_ficha.text = "\n\n".join(partes)


func _mostrar_sprite_terreno(nivel: String, registro: Dictionary) -> void:
	# Prioriza la textura declarada por los datos canónicos del registro.
	# Ecosistemas y hábitats pueden heredar la textura del bioma que los contiene.
	var rutas: Array[String] = []
	_agregar_ruta_textura(registro, rutas)

	if nivel != "bioma":
		var bioma_id := ""
		if nivel == "ecosistema":
			bioma_id = _buscar_bioma_de_ecosistema(str(registro.get("id", "")))
		elif nivel == "habitat":
			var contexto := _buscar_contexto_habitat(str(registro.get("id", "")))
			bioma_id = str(contexto.get("bioma_id", ""))
			_agregar_ruta_textura(contexto.get("ecosistema", {}), rutas)
		if not bioma_id.is_empty():
			_agregar_ruta_textura(WorldData.obtener_bioma(bioma_id), rutas)

	for ruta in rutas:
		if not ResourceLoader.exists(ruta):
			continue
		var recurso := load(ruta) as Texture2D
		if recurso == null:
			continue
		# Componer una muestra 3x3 con el centro lleno y los cuatro bordes.
		# El atlas Dual-Grid codifica TL, TR, BL y BR en 16 mascaras;
		# este orden coincide con TILE_SEQUENCE de WorldTerrainVisual.
		var ancho_celda := int(recurso.get_width() / 4)
		var alto_celda := int(recurso.get_height() / 4)
		if ancho_celda <= 0 or alto_celda <= 0:
			continue
		var imagen_atlas := recurso.get_image()
		if imagen_atlas == null or imagen_atlas.is_empty():
			continue
		var secuencia: Array[Vector2i] = [
			Vector2i(0, 3), Vector2i(3, 3),
			Vector2i(0, 2), Vector2i(1, 2),
			Vector2i(0, 0), Vector2i(3, 2),
			Vector2i(2, 3), Vector2i(3, 1),
			Vector2i(1, 3), Vector2i(0, 1),
			Vector2i(1, 0), Vector2i(2, 2),
			Vector2i(3, 0), Vector2i(2, 0),
			Vector2i(1, 1), Vector2i(2, 1),
		]
		# Máscaras para: esquina sup. izq., borde superior, sup. der.,
		# borde izquierdo, centro, borde derecho, inf. izq., borde inferior,
		# esquina inf. der. (bits TL, TR, BL, BR).
		var mascaras: Array[int] = [8, 12, 4, 10, 15, 5, 2, 3, 1]
		var muestra := Image.create(ancho_celda * 3, alto_celda * 3, false, Image.FORMAT_RGBA8)
		for indice in range(mascaras.size()):
			var celda := secuencia[mascaras[indice]]
			var origen := Rect2i(celda.x * ancho_celda, celda.y * alto_celda, ancho_celda, alto_celda)
			var destino := Vector2i((indice % 3) * ancho_celda, int(indice / 3) * alto_celda)
			muestra.blit_rect(imagen_atlas, origen, destino)
		_icono.texture = ImageTexture.create_from_image(muestra)
		_icono.visible = true
		return


func _agregar_ruta_textura(registro: Dictionary, rutas: Array[String]) -> void:
	var generacion_variant: Variant = registro.get("generacion", {})
	if generacion_variant is Dictionary:
		var ruta := str((generacion_variant as Dictionary).get("textura", "")).strip_edges()
		if not ruta.is_empty() and not rutas.has(ruta):
			rutas.append(ruta)


func _buscar_bioma_de_ecosistema(ecosistema_id: String) -> String:
	for bioma_variant in WorldData.obtener_biomas():
		if not bioma_variant is Dictionary:
			continue
		var bioma := bioma_variant as Dictionary
		for eco_variant in bioma.get("ecosistemas", []):
			if eco_variant is Dictionary and str((eco_variant as Dictionary).get("id", "")) == ecosistema_id:
				return str(bioma.get("id", ""))
	return ""


func _buscar_contexto_habitat(habitat_id: String) -> Dictionary:
	for bioma_variant in WorldData.obtener_biomas():
		if not bioma_variant is Dictionary:
			continue
		var bioma := bioma_variant as Dictionary
		for eco_variant in bioma.get("ecosistemas", []):
			if not eco_variant is Dictionary:
				continue
			var eco := eco_variant as Dictionary
			for habitat_variant in eco.get("habitats", []):
				if habitat_variant is Dictionary and str((habitat_variant as Dictionary).get("id", "")) == habitat_id:
					return {"bioma_id": str(bioma.get("id", "")), "ecosistema": eco}
	return {}


func _mostrar_ficha_original(letra: String) -> void:
	var original: Dictionary = {}
	for registro in _garumi_originales:
		if str(registro.get("letra_original", "")) == letra:
			original = registro
			break
	var nombre_original := str(original.get("nombre", "Linaje de Garumis"))
	var cantidad := 0
	for garumi in _garumis_catalogo:
		if str(garumi.get("letra_original", "")) == letra:
			cantidad += 1
	_nombre.text = (letra + " · " if not letra.is_empty() else "") + nombre_original
	_icono.texture = null
	_icono.visible = false
	var partes: Array[String] = ["[color=#8f754f]Original:[/color] " + nombre_original]
	partes.append("[color=#8f754f]Letra del linaje:[/color] " + letra)
	partes.append("[color=#8f754f]Garumis aprobados o canónicos:[/color] " + str(cantidad))
	if cantidad == 0:
		partes.append("Todavía no hay descendientes aprobados para mostrar en este linaje.")
	partes.append("Cada Garumi tiene un número local dentro de su linaje y un número global en el catálogo.")
	_ficha.text = "\n\n".join(partes)


func _mostrar_ficha_garumi(registro: Dictionary, _partes: Array[String]) -> void:
	# Al seleccionar un Garumi, la ficha se convierte en un visor de imagen:
	# sin nombre, estadísticas ni texto que compita con la ilustración.
	_nombre.hide()
	_ficha.hide()
	_icono.custom_minimum_size = Vector2(0, 0)
	_icono.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icono.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenedor_superior_detalle.custom_minimum_size = Vector2(0, 0)
	_contenedor_superior_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenedor_superior_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenedor_superior_detalle.alignment = BoxContainer.ALIGNMENT_CENTER
	_mostrar_sprite_garumi(registro)
	if not _icono.visible:
		# No inventar una ilustración si el recurso todavía no existe.
		_nombre.text = "Sin ilustración"
		_nombre.show()
		return
	_icono.size = _contenedor_superior_detalle.size


func _restaurar_ficha_detalle() -> void:
	if _contenedor_superior_detalle == null:
		return
	_nombre.show()
	_ficha.show()
	_contenedor_superior_detalle.custom_minimum_size = Vector2(0, 72)
	_contenedor_superior_detalle.size_flags_horizontal = Control.SIZE_FILL
	_contenedor_superior_detalle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icono.custom_minimum_size = Vector2(64, 54)
	_icono.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER



func _mostrar_sprite_garumi(registro: Dictionary) -> void:
	_icono.texture = null
	_icono.visible = false
	var claves: Array[String] = []
	var asset_key := str(registro.get("asset_key", "")).strip_edges()
	var nombre := str(registro.get("nombre", "")).strip_edges()
	if not asset_key.is_empty():
		claves.append(asset_key)
	if not nombre.is_empty() and not claves.has(nombre):
		claves.append(nombre)
	for clave in claves:
		for extension in [".png", ".PNG", ".svg", ".SVG"]:
			var ruta: String = "res://assets/art/garumis/" + clave + extension
			if not ResourceLoader.exists(ruta):
				continue
			var textura := load(ruta) as Texture2D
			if textura == null:
				continue
			_icono.texture = textura
			_icono.visible = true
			return


func _mostrar_ficha_criatura(
	id: String,
	registro: Dictionary,
	partes: Array[String]
) -> void:
	var nombre_criatura := str(registro.get("nombre", "")).strip_edges()
	var rutas_sprite: Array[String] = []
	if not nombre_criatura.is_empty():
		# Mismo orden de búsqueda que Creature: sprite estático primero,
		# hoja de caminar como respaldo si no existe imagen estática.
		rutas_sprite.append("res://assets/art/creatures/" + nombre_criatura + "/" + nombre_criatura + ".png")
		rutas_sprite.append("res://assets/art/creatures/" + nombre_criatura + "/" + nombre_criatura + ".PNG")
		rutas_sprite.append("res://assets/art/creatures/" + nombre_criatura + ".png")
		rutas_sprite.append("res://assets/art/creatures/" + nombre_criatura + ".PNG")
		rutas_sprite.append("res://assets/art/creatures/" + nombre_criatura + "/" + nombre_criatura + "_Walking.png")
		rutas_sprite.append("res://assets/art/creatures/" + nombre_criatura + "/" + nombre_criatura + "_Walking.PNG")
		rutas_sprite.append("res://assets/art/creatures/" + nombre_criatura + "/" + nombre_criatura + "_walking.png")
		rutas_sprite.append("res://assets/art/creatures/" + nombre_criatura + "/" + nombre_criatura + "_walking.PNG")

	for ruta_sprite in rutas_sprite:
		if not ResourceLoader.exists(ruta_sprite):
			continue
		var textura := load(ruta_sprite) as Texture2D
		if textura == null:
			continue
		# Las hojas de caminar se muestran como un solo fotograma en la ficha.
		if ruta_sprite.to_lower().contains("_walking"):
			var atlas := AtlasTexture.new()
			atlas.atlas = textura
			var frame_ancho := maxi(1, textura.get_width() / 4)
			atlas.region = Rect2(0, 0, frame_ancho, textura.get_height())
			_icono.texture = atlas
		else:
			_icono.texture = textura
		_icono.visible = true
		break

	partes.append("[color=#8f754f]Bioma:[/color] " + _obtener_biomas_de_criatura(id))
	partes.append("[color=#8f754f]Ecosistema:[/color] " + _obtener_ecosistemas_de_criatura(id))
	partes.append("[color=#8f754f]Hábitat:[/color] " + _obtener_habitats_de_criatura(id))
	partes.append("[color=#8f754f]Encuentros registrados:[/color] " + str(_obtener_derrotas(id)))
	_ficha.text = "\n\n".join(partes)


func _agregar_criaturas_de_bioma(bioma: Dictionary, partes: Array[String]) -> void:
	var criaturas: Array[Dictionary] = []
	var ecosistemas_variant: Variant = bioma.get("ecosistemas", [])
	if not ecosistemas_variant is Array:
		return

	for eco_variant in ecosistemas_variant as Array:
		if not eco_variant is Dictionary:
			continue
		var eco := eco_variant as Dictionary
		var habitats_variant: Variant = eco.get("habitats", [])
		if not habitats_variant is Array:
			continue
		for habitat_variant in habitats_variant as Array:
			if not habitat_variant is Dictionary:
				continue
			_agregar_criaturas_unicas(habitat_variant.get("criaturas", []), criaturas)

	var descubiertas := _obtener_descubiertos(GameState.obtener_descubrimientos_mundo(), "criaturas")
	criaturas = _filtrar_criaturas_descubiertas(criaturas, descubiertas)
	criaturas.sort_custom(_ordenar_registros)
	_agregar_lista_nombres(criaturas, partes)


func _agregar_criaturas_de_ecosistema(ecosistema: Dictionary, partes: Array[String]) -> void:
	var criaturas: Array[Dictionary] = []
	var habitats_variant: Variant = ecosistema.get("habitats", [])
	if habitats_variant is Array:
		for habitat_variant in habitats_variant as Array:
			if habitat_variant is Dictionary:
				_agregar_criaturas_unicas((habitat_variant as Dictionary).get("criaturas", []), criaturas)

	var descubiertas := _obtener_descubiertos(GameState.obtener_descubrimientos_mundo(), "criaturas")
	criaturas = _filtrar_criaturas_descubiertas(criaturas, descubiertas)
	criaturas.sort_custom(_ordenar_registros)
	_agregar_lista_nombres(criaturas, partes)


func _agregar_criaturas_de_habitat(habitat: Dictionary, partes: Array[String]) -> void:
	var criaturas := _filtrar_criaturas_descubiertas(
		_obtener_diccionarios(habitat.get("criaturas", [])),
		_obtener_descubiertos(GameState.obtener_descubrimientos_mundo(), "criaturas")
	)
	criaturas.sort_custom(_ordenar_registros)
	_agregar_lista_nombres(criaturas, partes)


func _agregar_criaturas_unicas(registros_variant: Variant, destino: Array[Dictionary]) -> void:
	if not registros_variant is Array:
		return
	for registro_variant in registros_variant as Array:
		if not registro_variant is Dictionary:
			continue
		var registro := registro_variant as Dictionary
		var id := str(registro.get("id", ""))
		var existe := false
		for anterior in destino:
			if str(anterior.get("id", "")) == id:
				existe = true
				break
		if not existe:
			destino.append(registro)


func _filtrar_criaturas_descubiertas(registros: Array[Dictionary], descubiertas: Dictionary) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for registro in registros:
		var id := str(registro.get("id", ""))
		if not id.is_empty() and descubiertas.has(id):
			resultado.append(registro)
	return resultado


func _obtener_diccionarios(registros_variant: Variant) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if not registros_variant is Array:
		return resultado
	for registro_variant in registros_variant as Array:
		if registro_variant is Dictionary:
			resultado.append(registro_variant as Dictionary)
	return resultado


func _agregar_lista_nombres(criaturas: Array[Dictionary], partes: Array[String]) -> void:
	if criaturas.is_empty():
		partes.append("[color=#55432e]Ninguna criatura descubierta todavía.[/color]")
		return
	for criatura in criaturas:
		partes.append("• " + str(criatura.get("nombre", "Sin nombre")))


func _obtener_criatura_ids_en_bioma(bioma: Dictionary) -> Array[String]:
	var resultado: Array[String] = []
	var ecosistemas_variant: Variant = bioma.get("ecosistemas", [])
	if not ecosistemas_variant is Array:
		return resultado
	for eco_variant in ecosistemas_variant as Array:
		if not eco_variant is Dictionary:
			continue
		var eco := eco_variant as Dictionary
		var habitats_variant: Variant = eco.get("habitats", [])
		if not habitats_variant is Array:
			continue
		for habitat_variant in habitats_variant as Array:
			if not habitat_variant is Dictionary:
				continue
			var criaturas_variant: Variant = (habitat_variant as Dictionary).get("criaturas", [])
			if not criaturas_variant is Array:
				continue
			for criatura_variant in criaturas_variant as Array:
				if criatura_variant is Dictionary:
					var id := str((criatura_variant as Dictionary).get("id", ""))
					if not id.is_empty() and id not in resultado:
						resultado.append(id)
	return resultado


func _obtener_biomas_de_criatura(criatura_id: String) -> String:
	var nombres: Array[String] = []
	for bioma_variant in WorldData.obtener_biomas():
		if not bioma_variant is Dictionary:
			continue
		var bioma := bioma_variant as Dictionary
		var ids := _obtener_criatura_ids_en_bioma(bioma)
		if criatura_id in ids and str(bioma.get("id", "")) in _obtener_descubiertos(GameState.obtener_descubrimientos_mundo(), "biomas"):
			nombres.append(str(bioma.get("nombre", "Sin nombre")))
	nombres.sort()
	return ", ".join(nombres) if not nombres.is_empty() else "Sin bioma descubierto"


func _obtener_ecosistemas_de_criatura(criatura_id: String) -> String:
	var nombres: Array[String] = []
	var descubiertos := _obtener_descubiertos(GameState.obtener_descubrimientos_mundo(), "ecosistemas")
	for bioma_variant in WorldData.obtener_biomas():
		if not bioma_variant is Dictionary:
			continue
		var bioma := bioma_variant as Dictionary
		for eco_variant in bioma.get("ecosistemas", []):
			if not eco_variant is Dictionary:
				continue
			var eco := eco_variant as Dictionary
			if str(eco.get("id", "")) not in descubiertos:
				continue
			for habitat_variant in eco.get("habitats", []):
				if not habitat_variant is Dictionary:
					continue
				for criatura_variant in (habitat_variant as Dictionary).get("criaturas", []):
					if criatura_variant is Dictionary and str((criatura_variant as Dictionary).get("id", "")) == criatura_id:
						var nombre := str(eco.get("nombre", "Sin nombre"))
						if nombre not in nombres:
							nombres.append(nombre)
	nombres.sort()
	return ", ".join(nombres) if not nombres.is_empty() else "Sin ecosistema descubierto"


func _obtener_habitats_de_criatura(criatura_id: String) -> String:
	var nombres: Array[String] = []
	var descubiertos := _obtener_descubiertos(GameState.obtener_descubrimientos_mundo(), "habitats")
	for bioma_variant in WorldData.obtener_biomas():
		if not bioma_variant is Dictionary:
			continue
		var bioma := bioma_variant as Dictionary
		for eco_variant in bioma.get("ecosistemas", []):
			if not eco_variant is Dictionary:
				continue
			var eco := eco_variant as Dictionary
			for habitat_variant in eco.get("habitats", []):
				if not habitat_variant is Dictionary:
					continue
				var habitat := habitat_variant as Dictionary
				if str(habitat.get("id", "")) not in descubiertos:
					continue
				for criatura_variant in habitat.get("criaturas", []):
					if criatura_variant is Dictionary and str((criatura_variant as Dictionary).get("id", "")) == criatura_id:
						var nombre := str(habitat.get("nombre", "Sin nombre"))
						if nombre not in nombres:
							nombres.append(nombre)
	nombres.sort()
	return ", ".join(nombres) if not nombres.is_empty() else "Sin hábitat descubierto"


func _obtener_registro_por_nivel(nivel: String, id: String) -> Dictionary:
	match nivel:
		"garumi":
			var garumi_variant: Variant = _garumis_por_id.get(id, {})
			return (garumi_variant as Dictionary).duplicate(true) if garumi_variant is Dictionary else {}
		"bioma":
			return WorldData.obtener_bioma(id)
		"ecosistema":
			return WorldData.obtener_ecosistema(id)
		"habitat":
			return WorldData.obtener_habitat(id)
		"criatura":
			return WorldData.obtener_criatura(id)
	return {}


func _contar_hijos_descubiertos(registros_variant: Variant, descubiertos: Dictionary) -> int:
	if not registros_variant is Array:
		return 0
	var total := 0
	for registro_variant in registros_variant as Array:
		if registro_variant is Dictionary:
			var id := str((registro_variant as Dictionary).get("id", ""))
			if not id.is_empty() and descubiertos.has(id):
				total += 1
	return total


func _nombre_nivel(nivel: String) -> String:
	match nivel:
		"bioma":
			return "Bioma"
		"ecosistema":
			return "Ecosistema"
		"habitat":
			return "Hábitat"
		"criatura":
			return "Criatura"
	return "Conocimiento"


func _obtener_derrotas(id: String) -> int:
	var registros := GameState.obtener_criaturas_descubiertas()
	return int(registros.get(id, 0))


func _mostrar_sin_descubrimientos() -> void:
	_nombre.text = "Nada descubierto todavía"
	_icono.texture = null
	_icono.visible = false
	_ficha.text = "[center][color=#8f754f]Este registro está vacío.[/color]\\n\\nExplora Garlia para descubrir nuevos conocimientos.[/center]"


func _al_descubrir_criatura(_criatura_id: String) -> void:
	actualizar()


func _al_descubrimiento_mundo_actualizado() -> void:
	actualizar()


func _al_mundo_actualizado() -> void:
	actualizar()
