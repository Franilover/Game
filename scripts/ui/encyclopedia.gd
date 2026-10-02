extends Control


var _ids_descubiertos: Array[String] = []

var _lista: ItemList
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

	var title: Label = Label.new()
	title.text = "ENCICLOPEDIA DE CRIATURAS"
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
		"Derrota una criatura para comenzar su registro."
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

	var registros_variant: Variant = GameState.flags.get(
		"enciclopedia_criaturas",
		{}
	)

	if not registros_variant is Dictionary:
		_mostrar_sin_descubrimientos()
		return

	var registros: Dictionary = registros_variant as Dictionary
	var candidatos: Array = []

	for id_variant in registros.keys():
		var id: String = str(id_variant)

		if id.is_empty():
			continue

		var derrotas: int = int(
			registros.get(
				id_variant,
				0
			)
		)

		if derrotas <= 0:
			continue

		var criatura: Dictionary = WorldData.obtener_criatura(id)

		if criatura.is_empty():
			continue

		criatura["_derrotas_registradas"] = derrotas
		candidatos.append(criatura)

	candidatos.sort_custom(_ordenar_criaturas)

	for criatura_variant in candidatos:
		if not criatura_variant is Dictionary:
			continue

		var criatura: Dictionary = criatura_variant as Dictionary
		var id: String = str(criatura.get("id", ""))

		if id.is_empty():
			continue

		_ids_descubiertos.append(id)
		_lista.add_item(
			str(
				criatura.get(
					"nombre",
					"Criatura"
				)
			)
		)

	_contador.text = (
		str(_ids_descubiertos.size())
		+ " descubiertas"
	)

	if _ids_descubiertos.is_empty():
		_mostrar_sin_descubrimientos()
		return

	_lista.select(0)
	_mostrar_criatura(0)


func _ordenar_criaturas(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var nombre_a: String = str(a.get("nombre", "")).to_lower()
	var nombre_b: String = str(b.get("nombre", "")).to_lower()

	return nombre_a < nombre_b


func _al_seleccionar(indice: int) -> void:
	_mostrar_criatura(indice)


func _mostrar_criatura(indice: int) -> void:
	if indice < 0 or indice >= _ids_descubiertos.size():
		return

	var id: String = _ids_descubiertos[indice]
	var criatura: Dictionary = WorldData.obtener_criatura(id)

	if criatura.is_empty():
		return

	var nombre: String = str(
		criatura.get(
			"nombre",
			"Criatura"
		)
	)

	_nombre.text = nombre

	var ruta: String = (
		"res://assets/art/creatures/"
		+ nombre
		+ ".png"
	)

	if ResourceLoader.exists(ruta):
		_icono.texture = load(ruta)
		_icono.visible = true
	else:
		_icono.texture = null
		_icono.visible = false

	var registros_variant: Variant = GameState.flags.get(
		"enciclopedia_criaturas",
		{}
	)

	var derrotas: int = 0

	if registros_variant is Dictionary:
		derrotas = int(
			(registros_variant as Dictionary).get(
				id,
				0
			)
		)

	var partes: Array[String] = []
\tpartes.append(
\t\t"[color=#8f754f]Derrotas registradas:[/color] " + str(derrotas)
\t)

	_ficha.text = "\n\n".join(partes)


func _mostrar_sin_descubrimientos() -> void:
	_contador.text = "0 descubiertas"
	_nombre.text = "Ninguna criatura descubierta"
	_icono.texture = null
	_icono.visible = false
	_ficha.text = (
		"[center]"
		+ "[color=#8f754f]La enciclopedia está vacía.[/color]\n\n"
		+ "Explora Garlia y derrota criaturas para registrar sus datos."
		+ "[/center]"
	)


func _al_descubrir_criatura(_criatura_id: String) -> void:
	actualizar()


func _al_mundo_actualizado() -> void:
	actualizar()
