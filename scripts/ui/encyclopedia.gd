extends Control


var _ids_descubiertos: Array[String] = []
var _arbol: Tree
var _nombre: Label
var _ficha: RichTextLabel
var _icono: TextureRect
var _tab_biomas: Button
var _tab_criaturas: Button
var _modo: String = "biomas"


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

	actualizar()


func _crear_interfaz() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)

	_tab_biomas = Button.new()
	_tab_biomas.text = "Biomas"
	_tab_biomas.toggle_mode = true
	_tab_biomas.button_pressed = true
	_tab_biomas.custom_minimum_size = Vector2(100, 28)
	_tab_biomas.pressed.connect(_mostrar_biomas)
	tabs.add_child(_tab_biomas)

	_tab_criaturas = Button.new()
	_tab_criaturas.text = "Criaturas"
	_tab_criaturas.toggle_mode = true
	_tab_criaturas.custom_minimum_size = Vector2(100, 28)
	_tab_criaturas.pressed.connect(_mostrar_criaturas)
	tabs.add_child(_tab_criaturas)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)

	_arbol = Tree.new()
	_arbol.custom_minimum_size = Vector2(260, 0)
	_arbol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arbol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arbol.hide_root = true
	_arbol.columns = 1
	_arbol.add_theme_color_override("font_color", Color(0.78, 0.66, 0.46, 1.0))
	_arbol.add_theme_color_override("font_selected_color", Color(0.95, 0.88, 0.7, 1.0))
	_arbol.add_theme_font_size_override("font_size", 11)

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
	detail_margin.add_theme_constant_override("margin_left", 14)
	detail_margin.add_theme_constant_override("margin_top", 12)
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	detail_panel.add_child(detail_margin)

	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 8)
	detail_margin.add_child(detail_column)

	var top := VBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 150)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 5)
	detail_column.add_child(top)

	_icono = TextureRect.new()
	_icono.custom_minimum_size = Vector2(128, 112)
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
	_nombre.add_theme_font_size_override("font_size", 17)
	top.add_child(_nombre)

	_ficha = RichTextLabel.new()
	_ficha.bbcode_enabled = true
	_ficha.fit_content = false
	_ficha.scroll_active = true
	_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ficha.add_theme_color_override("default_color", Color(0.72, 0.61, 0.45, 1.0))
	_ficha.add_theme_font_size_override("normal_font_size", 11)
	detail_column.add_child(_ficha)


func actualizar() -> void:
	if _arbol == null:
		return

	if _modo == "criaturas":
		_construir_lista_criaturas()
	else:
		_construir_arbol_biomas()


func _mostrar_biomas() -> void:
	_modo = "biomas"
	_tab_biomas.button_pressed = true
	_tab_criaturas.button_pressed = false
	actualizar()


func _mostrar_criaturas() -> void:
	_modo = "criaturas"
	_tab_biomas.button_pressed = false
	_tab_criaturas.button_pressed = true
	actualizar()


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
	item.set_text(0, str(registro.get("nombre", "Sin nombre")))
	item.set_metadata(0, {
		"nivel": nivel,
		"id": str(registro.get("id", ""))
	})
	return item


func _ordenar_registros(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()


func _al_seleccionar(item: TreeItem, _columna: int) -> void:
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
	var metadata_variant: Variant = item.get_metadata(0)
	if not metadata_variant is Dictionary:
		return

	var metadata := metadata_variant as Dictionary
	var nivel := str(metadata.get("nivel", ""))
	var id := str(metadata.get("id", ""))
	var registro := _obtener_registro_por_nivel(nivel, id)

	if nivel.is_empty() or id.is_empty() or registro.is_empty():
		return

	_nombre.text = str(registro.get("nombre", "Sin nombre"))
	_icono.texture = null
	_icono.visible = false

	var partes: Array[String] = []

	if nivel == "criatura":
		_mostrar_ficha_criatura(id, registro, partes)
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


func _mostrar_ficha_criatura(
	id: String,
	registro: Dictionary,
	partes: Array[String]
) -> void:
	var nombre_criatura := str(registro.get("nombre", ""))
	var ruta_imagen := "res://assets/art/creatures/" + nombre_criatura + ".png"
	if ResourceLoader.exists(ruta_imagen):
		var textura := load(ruta_imagen) as Texture2D
		if textura != null:
			_icono.texture = textura
			_icono.visible = true

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
	var registros_variant: Variant = GameState.flags.get("enciclopedia_criaturas", {})
	if registros_variant is Dictionary:
		return int((registros_variant as Dictionary).get(id, 0))
	return 0


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
