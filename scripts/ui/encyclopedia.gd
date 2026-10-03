extends Control


var _ids_descubiertos: Array[String] = []
var _categoria_actual: String = "biomas"
var _categoria_selector: OptionButton

var _lista: ItemList
var _nombre: Label
var _contador: Label
var _ficha: RichTextLabel
var _icono: TextureRect
var _subtitulo: Label


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

	if not WorldData.mundo_listo.is_connected(
		_al_mundo_actualizado
	):
		WorldData.mundo_listo.connect(
			_al_mundo_actualizado
		)

	if not WorldData.mundo_actualizado.is_connected(
		_al_mundo_actualizado
	):
		WorldData.mundo_actualizado.connect(
			_al_mundo_actualizado
		)

	actualizar()


func _crear_interfaz() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
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

	_categoria_selector = OptionButton.new()
	_categoria_selector.add_item("Biomas")
	_categoria_selector.add_item("Ecosistemas")
	_categoria_selector.add_item("Hábitats")
	_categoria_selector.add_item("Criaturas")
	_categoria_selector.item_selected.connect(_al_cambiar_categoria)
	header.add_child(_categoria_selector)

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

	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(190, 0)
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_theme_color_override(
		"font_color",
		Color(0.78, 0.66, 0.46, 1.0)
	)
	_lista.add_theme_color_override(
		"font_selected_color",
		Color(0.95, 0.88, 0.7, 1.0)
	)
	_lista.add_theme_font_size_override("font_size", 11)

	var estilo_lista: StyleBoxFlat = StyleBoxFlat.new()
	estilo_lista.bg_color = Color(0.075, 0.05, 0.035, 0.9)
	estilo_lista.border_width_left = 1
	estilo_lista.border_width_top = 1
	estilo_lista.border_width_right = 1
	estilo_lista.border_width_bottom = 1
	estilo_lista.border_color = Color(0.29, 0.19, 0.12, 1.0)
	_lista.add_theme_stylebox_override(
		"panel",
		estilo_lista
	)

	_lista.item_selected.connect(_al_seleccionar)
	body.add_child(_lista)

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
	detail_panel.add_theme_stylebox_override(
		"panel",
		estilo_detalle
	)
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
	top.add_child(_icono)

	var title_column: VBoxContainer = VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(title_column)

	_nombre = Label.new()
	_nombre.text = "Ninguna criatura descubierta"
	_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nombre.add_theme_color_override(
		"font_color",
		Color(0.9, 0.79, 0.58, 1.0)
	)
	_nombre.add_theme_font_size_override("font_size", 17)
	title_column.add_child(_nombre)

	var descubierto: Label = Label.new()
	descubierto.text = (
		"Explora Garlia para descubrir sus formas y lugares."
	)
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
	_ficha.add_theme_font_size_override(
		"normal_font_size",
		11
	)
	detail_column.add_child(_ficha)


func actualizar() -> void:
	if _lista == null:
		return

	_lista.clear()
	_ids_descubiertos.clear()

	var descubrimientos := GameState.obtener_descubrimientos_mundo()
	var registros_variant: Variant = descubrimientos.get(
		_categoria_actual,
		{}
	)

	if not registros_variant is Dictionary:
		_mostrar_sin_descubrimientos()
		return

	var registros := registros_variant as Dictionary
	var candidatos: Array = []

	for id_variant in registros.keys():
		var id := str(id_variant)
		if id.is_empty():
			continue

		var registro: Dictionary = {}
		match _categoria_actual:
			"biomas":
				registro = WorldData.obtener_bioma(id)
			"ecosistemas":
				registro = WorldData.obtener_ecosistema(id)
			"habitats":
				registro = WorldData.obtener_habitat(id)
			"criaturas":
				registro = WorldData.obtener_criatura(id)

		if registro.is_empty():
			continue

		candidatos.append(registro)

	candidatos.sort_custom(_ordenar_registros)

	for registro_variant in candidatos:
		if not registro_variant is Dictionary:
			continue

		var registro := registro_variant as Dictionary
		var id := str(registro.get("id", ""))
		if id.is_empty():
			continue

		_ids_descubiertos.append(id)
		_lista.add_item(str(registro.get("nombre", "Sin nombre")))

	_contador.text = str(_ids_descubiertos.size()) + " " + _nombre_categoria().to_lower()

	if _ids_descubiertos.is_empty():
		_mostrar_sin_descubrimientos()
		return

	_lista.select(0)
	_mostrar_registro(0)


func _ordenar_registros(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()


func _al_cambiar_categoria(indice: int) -> void:
	match indice:
		0:
			_categoria_actual = "biomas"
		1:
			_categoria_actual = "ecosistemas"
		2:
			_categoria_actual = "habitats"
		3:
			_categoria_actual = "criaturas"

	actualizar()


func _al_seleccionar(indice: int) -> void:
	_mostrar_registro(indice)


func _obtener_registro(id: String) -> Dictionary:
	match _categoria_actual:
		"biomas":
			return WorldData.obtener_bioma(id)
		"ecosistemas":
			return WorldData.obtener_ecosistema(id)
		"habitats":
			return WorldData.obtener_habitat(id)
		"criaturas":
			return WorldData.obtener_criatura(id)
	return {}


func _mostrar_registro(indice: int) -> void:
	if indice < 0 or indice >= _ids_descubiertos.size():
		return

	var registro := _obtener_registro(_ids_descubiertos[indice])
	if registro.is_empty():
		return

	_nombre.text = str(registro.get("nombre", "Sin nombre"))
	_icono.texture = null
	_icono.visible = false

	var partes: Array[String] = []
	partes.append("[color=#8f754f]Tipo:[/color] " + _nombre_categoria_singular())

	match _categoria_actual:
		"biomas":
			_agregar_ecosistemas_descubiertos(partes, registro)
		"ecosistemas":
			_agregar_habitats_descubiertos(partes, registro)
		"habitats":
			_agregar_criaturas_descubiertas(partes, registro)
		"criaturas":
			var derrotas := _obtener_derrotas(_ids_descubiertos[indice])
			partes.append("[color=#8f754f]Encuentros registrados:[/color] " + str(derrotas))

	_ficha.text = "\n\n".join(partes)


func _agregar_ecosistemas_descubiertos(partes: Array[String], bioma: Dictionary) -> void:
	var descubiertos_variant: Variant = GameState.obtener_descubrimientos_mundo().get("ecosistemas", {})
	var descubiertos: Dictionary = {}
	if descubiertos_variant is Dictionary:
		descubiertos = (descubiertos_variant as Dictionary).duplicate(true)
	var nombres: Array[String] = []
	for eco_variant in bioma.get("ecosistemas", []):
		if not eco_variant is Dictionary:
			continue
		var eco := eco_variant as Dictionary
		var id := str(eco.get("id", ""))
		if descubiertos.has(id):
			nombres.append(str(eco.get("nombre", "Sin nombre")))
	partes.append("[color=#8f754f]Ecosistemas conocidos:[/color] " + _lista_nombres(nombres))


func _agregar_habitats_descubiertos(partes: Array[String], ecosistema: Dictionary) -> void:
	var descubiertos_variant: Variant = GameState.obtener_descubrimientos_mundo().get("habitats", {})
	var descubiertos: Dictionary = {}
	if descubiertos_variant is Dictionary:
		descubiertos = (descubiertos_variant as Dictionary).duplicate(true)
	var nombres: Array[String] = []
	for habitat_variant in ecosistema.get("habitats", []):
		if not habitat_variant is Dictionary:
			continue
		var habitat := habitat_variant as Dictionary
		var id := str(habitat.get("id", ""))
		if descubiertos is Dictionary and descubiertos.has(id):
			nombres.append(str(habitat.get("nombre", "Sin nombre")))
	partes.append("[color=#8f754f]Hábitats conocidos:[/color] " + _lista_nombres(nombres))


func _agregar_criaturas_descubiertas(partes: Array[String], habitat: Dictionary) -> void:
	var descubiertos_variant: Variant = GameState.obtener_descubrimientos_mundo().get("criaturas", {})
	var descubiertos: Dictionary = {}
	if descubiertos_variant is Dictionary:
		descubiertos = (descubiertos_variant as Dictionary).duplicate(true)
	var nombres: Array[String] = []
	for criatura_variant in habitat.get("criaturas", []):
		if not criatura_variant is Dictionary:
			continue
		var criatura := criatura_variant as Dictionary
		var id := str(criatura.get("id", ""))
		if descubiertos is Dictionary and descubiertos.has(id):
			nombres.append(str(criatura.get("nombre", "Sin nombre")))
	partes.append("[color=#8f754f]Criaturas conocidas:[/color] " + _lista_nombres(nombres))


func _lista_nombres(nombres: Array[String]) -> String:
	if nombres.is_empty():
		return "ninguno todavía"
	return ", ".join(nombres)


func _obtener_derrotas(id: String) -> int:
	var registros_variant: Variant = GameState.flags.get("enciclopedia_criaturas", {})
	if registros_variant is Dictionary:
		return int((registros_variant as Dictionary).get(id, 0))
	return 0


func _nombre_categoria() -> String:
	match _categoria_actual:
		"biomas":
			return "descubiertos"
		"ecosistemas":
			return "descubiertos"
		"habitats":
			return "descubiertos"
		"criaturas":
			return "descubiertas"
	return "descubiertos"


func _nombre_categoria_singular() -> String:
	match _categoria_actual:
		"biomas":
			return "Bioma"
		"ecosistemas":
			return "Ecosistema"
		"habitats":
			return "Hábitat"
		"criaturas":
			return "Criatura"
	return "Registro"


func _mostrar_sin_descubrimientos() -> void:
	_contador.text = "0 descubiertos"
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
