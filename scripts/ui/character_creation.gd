extends ColorRect

signal confirmed(config: Dictionary, action: String)
signal cancelled

var _action: String = ""
var _skin_base: String = ""
var _personalizacion: Dictionary = {}
var _personalizacion_items: Dictionary = {}
var _personalizacion_colores: Dictionary = {}
var _personalizacion_vistas: Dictionary = {}
var _personalizacion_rows: VBoxContainer
var _preview_container: Control
var _preview_base: TextureRect
var _preview_layers: Dictionary = {}
@onready var appearance_container: VBoxContainer = $Panel/Margin/Column/Content/Appearance
@onready var creation_margin: MarginContainer = $Panel/Margin
@onready var creation_column: VBoxContainer = $Panel/Margin/Column
@onready var creation_content: HBoxContainer = $Panel/Margin/Column/Content
@onready var creation_fields: VBoxContainer = $Panel/Margin/Column/Content/Fields

@onready var partida_name_input: LineEdit = $Panel/Margin/Column/Content/Fields/PartidaName
@onready var seed_input: LineEdit = $Panel/Margin/Column/Content/Fields/SeedInput
@onready var name_input: LineEdit = $Panel/Margin/Column/Content/Fields/NameInput
@onready var gender: OptionButton = $Panel/Margin/Column/Content/Fields/Gender
@onready var gender_free: LineEdit = $Panel/Margin/Column/Content/Fields/GenderFree
@onready var species: OptionButton = $Panel/Margin/Column/Content/Fields/Species
@onready var status: Label = $Panel/Margin/Column/Status
@onready var confirm_button: Button = $Panel/Margin/Column/Buttons/Confirm
@onready var cancel_button: Button = $Panel/Margin/Column/Buttons/Cancel

func _ready() -> void:
	visible = false
	_instalar_scroll_contenido()
	get_viewport().size_changed.connect(_configurar_layout_responsive)
	_configurar_layout_responsive()
	gender.add_item("El")
	gender.add_item("Ella")
	gender.add_item("Elle")
	gender.add_item("Eso")
	gender.add_item("Texto libre")
	gender.item_selected.connect(_on_gender_selected)
	partida_name_input.text_changed.connect(func(_text: String) -> void:
		_update_confirm())
	name_input.text_changed.connect(func(_text: String) -> void:
		_update_confirm())
	gender_free.text_changed.connect(func(_text: String) -> void:
		_update_confirm())
	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)
	_cargar_skin_base()
	_crear_vista_previa()
	_construir_controles_personalizacion()
	_actualizar_vista_previa()
	if not SupabaseClient.especies_jugables_cargadas.is_connected(_on_species_loaded):
		SupabaseClient.especies_jugables_cargadas.connect(_on_species_loaded)
	SupabaseClient.cargar_especies_jugables()


func _instalar_scroll_contenido() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "CreationContentScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	creation_column.add_child(scroll)
	creation_column.move_child(scroll, creation_content.get_index())
	creation_column.remove_child(creation_content)
	scroll.add_child(creation_content)
	creation_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creation_content.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _configurar_layout_responsive() -> void:
	var tamano := get_viewport_rect().size
	var compacto := tamano.x < 760.0 or tamano.y < 520.0
	creation_margin.add_theme_constant_override("margin_left", 12 if tamano.x < 560.0 else 20)
	creation_margin.add_theme_constant_override("margin_right", 12 if tamano.x < 560.0 else 20)
	creation_margin.add_theme_constant_override("margin_top", 10 if tamano.y < 440.0 else 16)
	creation_margin.add_theme_constant_override("margin_bottom", 10 if tamano.y < 440.0 else 16)
	creation_column.add_theme_constant_override("separation", 6 if compacto else 10)
	creation_content.add_theme_constant_override("separation", 10 if compacto else 20)
	creation_fields.custom_minimum_size.x = 0
	appearance_container.custom_minimum_size.x = 0

func open(action: String) -> void:
	_action = action
	partida_name_input.text = ""
	seed_input.text = ""
	name_input.text = ""
	gender.select(0)
	gender_free.text = ""
	gender_free.visible = false
	if species.item_count > 0:
		species.select(0)
	for slot in CharacterAppearance.SLOTS:
		var lista: ItemList = _personalizacion_items.get(slot) as ItemList
		if lista != null and lista.item_count > 0:
			lista.select(0)
		var color_inicial := _color_inicial(slot)
		var selector_color: ColorPickerButton = _personalizacion_colores.get(slot) as ColorPickerButton
		if selector_color != null:
			selector_color.color = color_inicial
		_personalizacion[slot] = {"ruta": "", "color": CharacterAppearance.color_a_html(color_inicial)}
	_actualizar_vista_previa()
	visible = true
	name_input.grab_focus()
	_update_confirm()

func _on_cancel() -> void:
	_action = ""
	visible = false
	cancelled.emit()

func _on_gender_selected(index: int) -> void:
	gender_free.visible = index == 4
	_update_confirm()

func _actualizar_genero_segun_especie() -> void:
	if species.selected < 0:
		return
	var datos_variant: Variant = species.get_item_metadata(species.selected)
	if not datos_variant is Dictionary:
		return
	var datos := datos_variant as Dictionary
	var clave := str(datos.get("clave", "")).strip_edges().to_lower()
	var es_feerin := clave == "feerin"
	gender.visible = not es_feerin
	gender_free.visible = not es_feerin and gender.selected == 3

func _on_species_selected(_index: int) -> void:
	_actualizar_genero_segun_especie()
	_update_confirm()

func _on_species_loaded(data: Array) -> void:
	species.clear()
	for item_variant in data:
		if not item_variant is Dictionary:
			continue
		var item: Dictionary = item_variant as Dictionary
		species.add_item(str(item.get("nombre", "Especie")))
		species.set_item_metadata(species.item_count - 1, item.duplicate(true))
	species.disabled = species.item_count == 0
	if not species.item_selected.is_connected(_on_species_selected):
		species.item_selected.connect(_on_species_selected)
	if species.item_count > 0:
		species.select(0)
		_actualizar_genero_segun_especie()
	else:
		status.text = "No hay especies jugables disponibles."
	_update_confirm()

func _cargar_skin_base() -> void:
	# Se conserva un cuerpo base por compatibilidad; ya no hay selector de sprites completos.
	_skin_base = ""
	var directorio := DirAccess.open("res://assets/art/characters/skins/")
	if directorio == null:
		status.text = "No se encontró la carpeta de skins."
		return
	var archivos := directorio.get_files()
	archivos.sort()
	for nombre_archivo in archivos:
		if nombre_archivo.get_extension().to_lower() not in ["png", "webp", "jpg", "jpeg"]:
			continue
		var ruta := "res://assets/art/characters/skins/" + nombre_archivo
		if load(ruta) is Texture2D:
			_skin_base = ruta
			break
	if _skin_base.is_empty():
		status.text = "No se encontró un sprite base de personaje."
	_actualizar_vista_previa()



func _crear_vista_previa() -> void:
	_preview_container = Control.new()
	_preview_container.name = "VistaPreviaPersonaje"
	_preview_container.custom_minimum_size = Vector2(0, 84)
	_preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_base = TextureRect.new()
	_preview_base.name = "CuerpoBase"
	_preview_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_container.add_child(_preview_base)
	for slot in ["shoes", "pants", "shirt", "eyes", "hair"]:
		var capa := TextureRect.new()
		capa.name = "Preview_" + slot
		capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_container.add_child(capa)
		_preview_layers[slot] = capa
	appearance_container.add_child(_preview_container)
	appearance_container.move_child(_preview_container, 1)


func _actualizar_vista_previa() -> void:
	if _preview_base == null:
		return
	_preview_base.texture = load(_skin_base) as Texture2D if not _skin_base.is_empty() else null
	for slot in ["shoes", "pants", "shirt", "eyes", "hair"]:
		var capa: TextureRect = _preview_layers.get(slot) as TextureRect
		var lista: ItemList = _personalizacion_items.get(slot) as ItemList
		var selector_color: ColorPickerButton = _personalizacion_colores.get(slot) as ColorPickerButton
		if capa == null or lista == null:
			continue
		var seleccionados := lista.get_selected_items()
		var ruta := ""
		if not seleccionados.is_empty():
			ruta = str(lista.get_item_metadata(seleccionados[0]))
		capa.texture = load(ruta) as Texture2D if not ruta.is_empty() and ResourceLoader.exists(ruta) else null
		capa.modulate = selector_color.color if selector_color != null else Color.WHITE
		capa.visible = capa.texture != null

func _construir_controles_personalizacion() -> void:
	# Carruseles compactos por categoría; no se muestran sprites completos predefinidos.
	var etiqueta_skin := appearance_container.get_node_or_null("SkinLabel") as Label
	if etiqueta_skin != null:
		etiqueta_skin.visible = false

	_personalizacion_rows = VBoxContainer.new()
	_personalizacion_rows.name = "FilasPersonalizacion"
	_personalizacion_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_personalizacion_rows.add_theme_constant_override("separation", 4)
	appearance_container.add_child(_personalizacion_rows)
	appearance_container.move_child(_personalizacion_rows, 2)

	for slot in CharacterAppearance.SLOTS:
		var fila := HBoxContainer.new()
		fila.name = "Fila_" + slot
		fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 8)
		_personalizacion_rows.add_child(fila)

		# La lista conserva rutas y selección, pero no se muestra: la interfaz
		# presenta una sola miniatura con flechas para recorrer las opciones.
		var lista := ItemList.new()
		lista.name = "CatalogoInterno"
		lista.visible = false
		lista.add_item("")
		lista.set_item_metadata(0, "")
		for pieza in CharacterAppearance.catalogo(slot):
			lista.add_icon_item(pieza["textura"], true)
			var indice := lista.item_count - 1
			lista.set_item_text(indice, "")
			lista.set_item_metadata(indice, str(pieza["ruta"]))
		lista.select(0)
		lista.item_selected.connect(_al_seleccionar_pieza.bind(slot))
		fila.add_child(lista)
		_personalizacion_items[slot] = lista

		var anterior := Button.new()
		anterior.text = "‹"
		anterior.custom_minimum_size = Vector2(34, 34)
		anterior.focus_mode = Control.FOCUS_NONE
		anterior.tooltip_text = "Opción anterior"
		anterior.pressed.connect(_cambiar_opcion.bind(slot, -1))
		fila.add_child(anterior)

		var icono := TextureRect.new()
		icono.name = "MiniaturaActual"
		icono.custom_minimum_size = Vector2(38, 38)
		icono.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(icono)
		_personalizacion_vistas[slot] = icono

		var siguiente := Button.new()
		siguiente.text = "›"
		siguiente.custom_minimum_size = Vector2(34, 34)
		siguiente.focus_mode = Control.FOCUS_NONE
		siguiente.tooltip_text = "Opción siguiente"
		siguiente.pressed.connect(_cambiar_opcion.bind(slot, 1))
		fila.add_child(siguiente)

		var selector_color := ColorPickerButton.new()
		selector_color.custom_minimum_size = Vector2(28, 28)
		selector_color.color = _color_inicial(slot)
		selector_color.tooltip_text = "Cambiar color"
		selector_color.color_changed.connect(_al_cambiar_color_pieza.bind(slot))
		fila.add_child(selector_color)
		_personalizacion_colores[slot] = selector_color
		_personalizacion[slot] = {
			"ruta": "",
			"color": CharacterAppearance.color_a_html(selector_color.color)
		}
		_actualizar_icono_opcion(slot)


func _cambiar_opcion(slot: String, direccion: int) -> void:
	var lista: ItemList = _personalizacion_items.get(slot) as ItemList
	if lista == null or lista.item_count == 0:
		return
	var seleccionados := lista.get_selected_items()
	var indice_actual := seleccionados[0] if not seleccionados.is_empty() else 0
	var nuevo_indice := posmod(indice_actual + direccion, lista.item_count)
	lista.select(nuevo_indice)
	_al_seleccionar_pieza(nuevo_indice, slot)


func _actualizar_icono_opcion(slot: String) -> void:
	var lista: ItemList = _personalizacion_items.get(slot) as ItemList
	var icono: TextureRect = _personalizacion_vistas.get(slot) as TextureRect
	if lista == null or icono == null:
		return
	var seleccionados := lista.get_selected_items()
	var indice := seleccionados[0] if not seleccionados.is_empty() else 0
	icono.texture = lista.get_item_icon(indice) if indice > 0 else null

func _color_inicial(slot: String) -> Color:
	match slot:
		"hair": return Color("#5b3828")
		"eyes": return Color("#7a9e8a")
		"shirt": return Color("#7896b5")
		"pants": return Color("#4b536d")
		"shoes": return Color("#5a443b")
	return Color.WHITE


func _al_seleccionar_pieza(indice: int, slot: String) -> void:
	var lista: ItemList = _personalizacion_items.get(slot) as ItemList
	if lista == null:
		return
	var pieza: Dictionary = _personalizacion.get(slot, {}).duplicate(true)
	pieza["ruta"] = str(lista.get_item_metadata(indice))
	_personalizacion[slot] = pieza
	_actualizar_icono_opcion(slot)
	_actualizar_vista_previa()


func _al_cambiar_color_pieza(color: Color, slot: String) -> void:
	var pieza: Dictionary = _personalizacion.get(slot, {}).duplicate(true)
	pieza["color"] = CharacterAppearance.color_a_html(color)
	_personalizacion[slot] = pieza
	_actualizar_vista_previa()


func _obtener_personalizacion() -> Dictionary:
	var resultado: Dictionary = {}
	for slot in CharacterAppearance.SLOTS:
		var pieza: Dictionary = _personalizacion.get(slot, {}).duplicate(true)
		var lista: ItemList = _personalizacion_items.get(slot) as ItemList
		var selector_color: ColorPickerButton = _personalizacion_colores.get(slot) as ColorPickerButton
		if lista != null:
			var seleccionados := lista.get_selected_items()
			if not seleccionados.is_empty():
				pieza["ruta"] = str(lista.get_item_metadata(seleccionados[0]))
		if selector_color != null:
			pieza["color"] = CharacterAppearance.color_a_html(selector_color.color)
		resultado[slot] = pieza
	return resultado

func _update_confirm(_index: int = -1) -> void:
	if confirm_button == null:
		return
	var partida_name_ok: bool = not partida_name_input.text.strip_edges().is_empty()
	var name_ok: bool = not name_input.text.strip_edges().is_empty()
	var gender_ok: bool = not gender.visible or gender.selected != 4 or not gender_free.text.strip_edges().is_empty()
	var species_ok: bool = species.item_count > 0 and species.selected >= 0
	var skin_ok: bool = not _skin_base.is_empty()
	confirm_button.disabled = not (partida_name_ok and name_ok and gender_ok and species_ok and skin_ok)

func _on_confirm() -> void:
	_update_confirm()
	if confirm_button.disabled:
		return
	if _skin_base.is_empty():
		return
	var gender_value: String = gender.get_item_text(gender.selected)
	if not gender.visible:
		gender_value = "sin_genero"
	if gender.selected == 4:
		gender_value = gender_free.text.strip_edges()
	var species_data: Dictionary = species.get_item_metadata(species.selected) as Dictionary
	var config: Dictionary = {
		"nombre_partida": partida_name_input.text.strip_edges(),
		"semilla": seed_input.text.strip_edges(),
		"nombre": name_input.text.strip_edges(),
		"genero": gender_value,
		"especie": species_data.duplicate(true),
		"skin": _skin_base,
		"skin_nombre": _skin_base.get_file().get_basename(),
		"personalizacion": _obtener_personalizacion()
	}
	visible = false
	confirmed.emit(config, _action)
	_action = ""
