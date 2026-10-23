extends ColorRect

signal confirmed(config: Dictionary, action: String)
signal cancelled

var _action: String = ""
var _skins: Array[String] = []
var _personalizacion: Dictionary = {}
var _personalizacion_items: Dictionary = {}
var _personalizacion_colores: Dictionary = {}
var _personalizacion_tabs: TabContainer
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
@onready var skins: ItemList = $Panel/Margin/Column/Content/Appearance/Skins
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
	skins.item_selected.connect(func(_index: int) -> void:
		_update_confirm())
	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)
	_load_skins()
	_construir_controles_personalizacion()
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
	skins.custom_minimum_size.y = 96 if compacto else 120
	if _personalizacion_tabs != null:
		_personalizacion_tabs.custom_minimum_size.y = 108 if compacto else 132
	for slot in CharacterAppearance.SLOTS:
		var lista: ItemList = _personalizacion_items.get(slot) as ItemList
		if lista != null:
			lista.custom_minimum_size.y = 58 if compacto else 76
			lista.fixed_icon_size = Vector2i(32, 32) if compacto else Vector2i(42, 42)
			lista.fixed_column_width = 48 if compacto else 60

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
	if skins.item_count > 0:
		skins.select(0)
	for slot in CharacterAppearance.SLOTS:
		var lista: ItemList = _personalizacion_items.get(slot) as ItemList
		if lista != null and lista.item_count > 0:
			lista.select(0)
		var color_inicial := _color_inicial(slot)
		var selector_color: ColorPickerButton = _personalizacion_colores.get(slot) as ColorPickerButton
		if selector_color != null:
			selector_color.color = color_inicial
		_personalizacion[slot] = {"ruta": "", "color": CharacterAppearance.color_a_html(color_inicial)}
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

func _load_skins() -> void:
	skins.clear()
	_skins.clear()
	var directory := DirAccess.open("res://assets/art/characters/skins/")
	if directory == null:
		status.text = "No se encontró la carpeta de skins."
		return
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		var extension := file_name.get_extension().to_lower()
		if extension not in ["png", "webp", "jpg", "jpeg"]:
			continue
		var path := "res://assets/art/characters/skins/" + file_name
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		_skins.append(path)
		skins.add_icon_item(texture, true)
		skins.set_item_text(skins.item_count - 1, file_name.get_basename())
	if skins.item_count > 0:
		skins.select(0)
	_update_confirm()


func _construir_controles_personalizacion() -> void:
	_personalizacion_tabs = TabContainer.new()
	_personalizacion_tabs.name = "Personalizacion"
	_personalizacion_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_personalizacion_tabs.custom_minimum_size = Vector2(0, 132)
	appearance_container.add_child(_personalizacion_tabs)

	for slot in CharacterAppearance.SLOTS:
		var pagina := VBoxContainer.new()
		pagina.name = slot.capitalize()
		pagina.add_theme_constant_override("separation", 4)
		_personalizacion_tabs.add_child(pagina)
		_personalizacion_tabs.set_tab_title(pagina.get_index(), str(CharacterAppearance.SLOT_LABELS[slot]))

		var catalogo: Array[Dictionary] = CharacterAppearance.catalogo(slot)
		var lista := ItemList.new()
		lista.name = "Catalogo"
		lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lista.custom_minimum_size = Vector2(0, 76)
		lista.max_columns = 5
		lista.fixed_column_width = 60
		lista.fixed_icon_size = Vector2i(42, 42)
		lista.icon_mode = ItemList.ICON_MODE_TOP
		lista.select_mode = ItemList.SELECT_SINGLE
		lista.add_item("Ninguno")
		lista.set_item_metadata(0, "")
		for pieza in catalogo:
			lista.add_icon_item(pieza["textura"], true)
			var indice := lista.item_count - 1
			lista.set_item_text(indice, str(pieza["nombre"]))
			lista.set_item_metadata(indice, str(pieza["ruta"]))
		lista.select(0)
		lista.item_selected.connect(_al_seleccionar_pieza.bind(slot))
		pagina.add_child(lista)
		_personalizacion_items[slot] = lista

		var fila_color := HBoxContainer.new()
		fila_color.add_theme_constant_override("separation", 8)
		pagina.add_child(fila_color)
		var etiqueta := Label.new()
		etiqueta.text = "Color"
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila_color.add_child(etiqueta)
		var selector_color := ColorPickerButton.new()
		selector_color.custom_minimum_size = Vector2(64, 30)
		selector_color.color = _color_inicial(slot)
		selector_color.tooltip_text = "Color de " + str(CharacterAppearance.SLOT_LABELS[slot]).to_lower()
		selector_color.color_changed.connect(_al_cambiar_color_pieza.bind(slot))
		fila_color.add_child(selector_color)
		_personalizacion_colores[slot] = selector_color
		_personalizacion[slot] = {
			"ruta": "",
			"color": CharacterAppearance.color_a_html(selector_color.color)
		}


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


func _al_cambiar_color_pieza(color: Color, slot: String) -> void:
	var pieza: Dictionary = _personalizacion.get(slot, {}).duplicate(true)
	pieza["color"] = CharacterAppearance.color_a_html(color)
	_personalizacion[slot] = pieza


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
	var skin_ok: bool = skins.item_count > 0 and skins.get_selected_items().size() > 0
	confirm_button.disabled = not (partida_name_ok and name_ok and gender_ok and species_ok and skin_ok)

func _on_confirm() -> void:
	_update_confirm()
	if confirm_button.disabled:
		return
	var selected_skin: PackedInt32Array = skins.get_selected_items()
	if selected_skin.is_empty():
		return
	var skin_index: int = selected_skin[0]
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
		"skin": _skins[skin_index],
		"skin_nombre": _skins[skin_index].get_file().get_basename(),
		"personalizacion": _obtener_personalizacion()
	}
	visible = false
	confirmed.emit(config, _action)
	_action = ""
