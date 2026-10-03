extends Control


var _ids_descubiertos: Array[String] = []
var _arbol: Tree
var _nombre: Label
var _contador: Label
var _ficha: RichTextLabel
var _icono: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_interfaz()

	if GameState.has_signal("enciclopedia_actualizada"):
		if not GameState.enciclopedia_actualizada.is_connected(
			_al_descubrir_criatura
		):
			GameState.enciclopedia_actualizada.connect(
				_al_descubrir_criatura
			)

	if GameState.has_signal("descubrimientos_mundo_actualizados"):
		if not GameState.descubrimientos_mundo_actualizados.is_connected(
			_al_descubrimiento_mundo_actualizado
		):
			GameState.descubrimientos_mundo_actualizados.connect(
				_al_descubrimiento_mundo_actualizado
			)

	if not WorldData.mundo_listo.is_connected(_al_mundo_actualizado):
		WorldData.mundo_listo.connect(_al_mundo_actualizado)

	if not WorldData.mundo_actualizado.is_connected(_al_mundo_actualizado):
		WorldData.mundo_actualizado.connect(_al_mundo_actualizado)

	actualizar()


func _crear_interfaz() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)

	var title: Label = Label.new()
	title.text = "CONOCIMIENTOS DESCUBIERTOS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override(
		"font_color",
		Color(0.9, 0.79, 0.58, 1.0)
	)
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)

	_contador = Label.new()
	_contador.add_theme_color_override(
		"font_color",
		Color(0.55, 0.43, 0.29, 1.0)
	)
	_contador.add_theme_font_size_override("font_size", 10)
	header.add_child(_contador)

	column.add_child(HSeparator.new())

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)

	_arbol = Tree.new()
	_arbol.custom_minimum_size = Vector2(250, 0)
	_arbol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arbol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arbol.hide_root = true
	_arbol.columns = 1
	_arbol.add_theme_color_override(
		"font_color",
		Color(0.78, 0.66, 0.46, 1.0)
	)
	_arbol.add_theme_color_override(
		"font_selected_color",
		Color(0.95, 0.88, 0.7, 1.0)
	)
	_arbol.add_theme_font_size_override("font_size", 11)

	var estilo_arbol: StyleBoxFlat = StyleBoxFlat.new()
	estilo_arbol.bg_color = Color(0.075, 0.05, 0.035, 0.9)
	estilo_arbol.border_width_left = 1
	estilo_arbol.border_width_top = 1
	estilo_arbol.border_width_right = 1
	estilo_arbol.border_width_bottom = 1
	estilo_arbol.border_color = Color(0.29, 0.19, 0.12, 1.0)
	_arbol.add_theme_stylebox_override("panel", estilo_arbol)
	_arbol.item_selected.connect(_al_seleccionar)
	body.add_child(_arbol)

	var detail_panel: PanelContainer = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var estilo_detalle: StyleBoxFlat = StyleBoxFlat.new()
	estilo_detalle.bg_color = Color(0.075, 0.05, 0.035, 0.9)
	estilo_detalle.border_width_left = 1
	estilo_detalle.border_width_top = 1
	estilo_detalle.border_width_right = 1
	estilo_detalle.border_width_bottom = 1
	estilo_detalle.border_color = Color(0.29, 0.19, 0.12, 1.0)
	detail_panel.add_theme_stylebox_override("panel", estilo_detalle)
	body.add_child(detail_panel)

	var detail_margin: MarginContainer = MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 14)
	detail_margin.add_theme_constant_override("margin_top", 12)
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_bottom", 12)
	detail_panel.add_child(detail_margin)

	var detail_column: VBoxContainer = VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 8)
	detail_margin.add_child(detail_column)

	var top: HBoxContainer = HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 92)
	detail_column.add_child(top)

	_icono = TextureRect.new()
	_icono.custom_minimum_size = Vector2(92, 92)
	_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono.visible = false
	top.add_child(_icono)

	var title_column: VBoxContainer = VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(title_column)

	_nombre = Label.new()
	_nombre.text = "Nada descubierto todavía"
	_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nombre.add_theme_color_override(
		"font_color",
		Color(0.9, 0.79, 0.58, 1.0)
	)
	_nombre.add_theme_font_size_override("font_size", 17)
	title_column.add_child(_nombre)

	var descubierto: Label = Label.new()
	descubierto.text = "Explora Garlia para descubrir sus formas y lugares."
	descubierto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descubierto.add_theme_color_override(
		"font_color",
		Color(0.55, 0.43, 0.29, 1.0)
	)
	descubierto.add_theme_font_size_override("font_size", 10)
	title_column.add_child(descubierto)

	_ficha = RichTextLabel.new()
	_ficha.bbcode_enabled = true
	_ficha.fit_content = false
	_ficha.scroll_active = true
	_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ficha.add_theme_color_override(
		"default_color",
		Color(0.72, 0.61, 0.45, 1.0)
	)
	_ficha.add_theme_font_size_override("normal_font_size", 11)
	detail_column.add_child(_ficha)


func actualizar() -> void:
	if _arbol == null:
		return

	_arbol.clear()

	var descubrimientos: Dictionary = GameState.obtener_descubrimientos_mundo()
	var raiz: TreeItem = _arbol.create_item()

	var total: int = 0
	var primero: TreeItem = null

	var biomas_variant: Variant = descubrimientos.get("biomas", {})
	if biomas_variant is Dictionary:
		var biomas: Dictionary = biomas_variant as Dictionary
		var registros_biomas: Array[Dictionary] = _obtener_registros(
			biomas,
			"bioma"
		)
		registros_biomas.sort_custom(_ordenar_registros)

		for bioma in registros_biomas:
			var bioma_item: TreeItem = _agregar_item(
				raiz,
				bioma,
				"bioma"
			)
			total += 1
			if primero == null:
				primero = bioma_item

			var ecosistemas_variant: Variant = bioma.get("ecosistemas", [])
			if not ecosistemas_variant is Array:
				continue

			var ecosistemas_descubiertos: Dictionary = _obtener_descubiertos(
				descubrimientos,
				"ecosistemas"
			)
			var ecosistemas: Array[Dictionary] = _filtrar_descubiertos(
				ecosistemas_variant as Array,
				ecosistemas_descubiertos
			)
			ecosistemas.sort_custom(_ordenar_registros)

			for ecosistema in ecosistemas:
				var eco_item: TreeItem = _agregar_item(
					bioma_item,
					ecosistema,
					"ecosistema"
				)
				total += 1
				if primero == null:
					primero = eco_item

				var habitats_variant: Variant = ecosistema.get("habitats", [])
				if not habitats_variant is Array:
					continue

				var habitats_descubiertos: Dictionary = _obtener_descubiertos(
					descubrimientos,
					"habitats"
				)
				var habitats: Array[Dictionary] = _filtrar_descubiertos(
					habitats_variant as Array,
					habitats_descubiertos
				)
				habitats.sort_custom(_ordenar_registros)

				for habitat in habitats:
					var habitat_item: TreeItem = _agregar_item(
						eco_item,
						habitat,
						"habitat"
					)
					total += 1
					if primero == null:
						primero = habitat_item

					var criaturas_variant: Variant = habitat.get("criaturas", [])
					if not criaturas_variant is Array:
						continue

					var criaturas_descubiertas: Dictionary = _obtener_descubiertos(
						descubrimientos,
						"criaturas"
					)
					var criaturas: Array[Dictionary] = _filtrar_descubiertos(
						criaturas_variant as Array,
						criaturas_descubiertas
					)
					criaturas.sort_custom(_ordenar_registros)

					for criatura in criaturas:
						var criatura_item: TreeItem = _agregar_item(
							habitat_item,
							criatura,
							"criatura"
						)
						total += 1
						if primero == null:
							primero = criatura_item

	_contador.text = str(total) + " conocimientos"

	if primero == null:
		_mostrar_sin_descubrimientos()
		return

	_arbol.set_selected(primero, 0)
	_mostrar_item(primero)


func _obtener_registros(registros: Dictionary, nivel: String) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for id_variant in registros.keys():
		var id: String = str(id_variant)
		if id.is_empty():
			continue

		var registro: Dictionary = _obtener_registro_por_nivel(nivel, id)
		if registro.is_empty():
			continue

		resultado.append(registro)

	return resultado


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


func _obtener_descubiertos(
	descubrimientos: Dictionary,
	categoria: String
) -> Dictionary:
	var registros_variant: Variant = descubrimientos.get(categoria, {})
	if registros_variant is Dictionary:
		return registros_variant as Dictionary
	return {}


func _filtrar_descubiertos(
	registros: Array,
	descubiertos: Dictionary
) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for registro_variant in registros:
		if not registro_variant is Dictionary:
			continue

		var registro: Dictionary = registro_variant as Dictionary
		var id: String = str(registro.get("id", ""))
		if id.is_empty() or not descubiertos.has(id):
			continue

		resultado.append(registro)

	return resultado


func _agregar_item(
	padre: TreeItem,
	registro: Dictionary,
	nivel: String
) -> TreeItem:
	var item: TreeItem = _arbol.create_item(padre)
	var nombre: String = str(registro.get("nombre", "Sin nombre"))
	item.set_text(0, nombre)
	item.set_metadata(0, {
		"nivel": nivel,
		"id": str(registro.get("id", ""))
	})
	item.set_tooltip_text(0, _nombre_nivel(nivel))
	return item


func _ordenar_registros(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()


func _al_seleccionar(item: TreeItem, _columna: int) -> void:
	_mostrar_item(item)


func _mostrar_item(item: TreeItem) -> void:
	var metadata_variant: Variant = item.get_metadata(0)
	if not metadata_variant is Dictionary:
		return

	var metadata: Dictionary = metadata_variant as Dictionary
	var nivel: String = str(metadata.get("nivel", ""))
	var id: String = str(metadata.get("id", ""))

	if nivel.is_empty() or id.is_empty():
		return

	var registro: Dictionary = _obtener_registro_por_nivel(nivel, id)
	if registro.is_empty():
		return

	_nombre.text = str(registro.get("nombre", "Sin nombre"))
	_icono.texture = null
	_icono.visible = false

	var partes: Array[String] = []
	partes.append(
		"[color=#8f754f]Tipo:[/color] " + _nombre_nivel(nivel)
	)

	match nivel:
		"bioma":
			partes.append(
				"[color=#8f754f]Ecosistemas descubiertos:[/color] "
				+ str(_contar_hijos_descubiertos(
					registro.get("ecosistemas", []),
					_obtener_descubiertos(
						GameState.obtener_descubrimientos_mundo(),
						"ecosistemas"
					)
				))
			)
		"ecosistema":
			partes.append(
				"[color=#8f754f]Hábitats descubiertos:[/color] "
				+ str(_contar_hijos_descubiertos(
					registro.get("habitats", []),
					_obtener_descubiertos(
						GameState.obtener_descubrimientos_mundo(),
						"habitats"
					)
				))
			)
		"habitat":
			partes.append(
				"[color=#8f754f]Criaturas descubiertas:[/color] "
				+ str(_contar_hijos_descubiertos(
					registro.get("criaturas", []),
					_obtener_descubiertos(
						GameState.obtener_descubrimientos_mundo(),
						"criaturas"
					)
				))
			)
		"criatura":
			partes.append(
				"[color=#8f754f]Encuentros registrados:[/color] "
				+ str(_obtener_derrotas(id))
			)

	_ficha.text = "\n\n".join(partes)


func _contar_hijos_descubiertos(
	registros_variant: Variant,
	descubiertos: Dictionary
) -> int:
	if not registros_variant is Array:
		return 0

	var total: int = 0
	for registro_variant in registros_variant as Array:
		if not registro_variant is Dictionary:
			continue

		var registro: Dictionary = registro_variant as Dictionary
		var id: String = str(registro.get("id", ""))
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
	var registros_variant: Variant = GameState.flags.get(
		"enciclopedia_criaturas",
		{}
	)
	if registros_variant is Dictionary:
		return int((registros_variant as Dictionary).get(id, 0))
	return 0


func _mostrar_sin_descubrimientos() -> void:
	_contador.text = "0 conocimientos"
	_nombre.text = "Nada descubierto todavía"
	_icono.texture = null
	_icono.visible = false
	_ficha.text = (
		"[center]"
		+ "[color=#8f754f]Este registro está vacío.[/color]\\n\\n"
		+ "Explora Garlia para descubrir nuevos conocimientos."
		+ "[/center]"
	)


func _al_descubrir_criatura(_criatura_id: String) -> void:
	actualizar()


func _al_descubrimiento_mundo_actualizado() -> void:
	actualizar()


func _al_mundo_actualizado() -> void:
	actualizar()
