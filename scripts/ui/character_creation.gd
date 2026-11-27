extends ColorRect

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const APPEARANCE_PREVIEW_SCENE = preload("res://scenes/ui/character_appearance_preview.tscn")
const APPEARANCE_OPTION_ROW_SCENE = preload("res://scenes/ui/character_appearance_option_row.tscn")

signal confirmed(config: Dictionary, action: String)
signal cancelled

var _action: String = ""
var _personalizacion: Dictionary = {}
var _personalizacion_items: Dictionary = {}
var _personalizacion_colores: Dictionary = {}
var _personalizacion_vistas: Dictionary = {}
var _kingdom_selector: OptionButton
var _kingdom_label: Label
var _personalizacion_rows: VBoxContainer
var _preview_container: Control
var _preview_layers: Dictionary = {}
var _preview_direction_index: int = 0
const PREVIEW_DIRECTIONS: Array[String] = ["Frente", "Derecha", "Atrás", "Izquierda"]
var _preview_direction_label: Label
@onready var appearance_container: VBoxContainer = $Panel/Margin/Column/Content/Appearance
@onready var creation_margin: MarginContainer = $Panel/Margin
@onready var creation_column: VBoxContainer = $Panel/Margin/Column
@onready var creation_content: BoxContainer = $Panel/Margin/Column/Content
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
	# Esta escena se instancia como hija desde start_menu y save_selector.
	# Godot no siempre conserva el layout de raíz de una PackedScene al insertarla;
	# normalizamos la geometría contra el Control padre antes de medir el layout.
	_normalizar_geometria_raiz()
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
	_crear_selector_reino_inicial()
	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)
	_crear_vista_previa()
	# El selector de apariencia forma parte de la creación de cada partida.
	appearance_container.visible = true
	_construir_controles_personalizacion()
	PIXEL_UI_THEME.apply(self)
	_actualizar_vista_previa()
	if not SupabaseClient.especies_jugables_cargadas.is_connected(_on_species_loaded):
		SupabaseClient.especies_jugables_cargadas.connect(_on_species_loaded)
	# Primero hidratar desde caché: la petición inicial puede haber terminado
	# antes de que esta escena conectara su señal.
	var especies_en_cache: Array = SupabaseClient.obtener_especies_jugables()
	if not especies_en_cache.is_empty():
		_on_species_loaded(especies_en_cache)
	SupabaseClient.cargar_especies_jugables()


func _normalizar_geometria_raiz() -> void:
	# El panel es un overlay de pantalla completa; no debe depender de offsets
	# heredados ni de una posición guardada en el editor.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	# PRESET_FULL_RECT ya ajusta el tamaño según el Control padre.
	# Asignar size aquí provoca el warning de anchors opuestos no iguales.


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
	creation_margin.add_theme_constant_override("margin_left", 10 if tamano.x < 560.0 else 20)
	creation_margin.add_theme_constant_override("margin_right", 10 if tamano.x < 560.0 else 20)
	creation_margin.add_theme_constant_override("margin_top", 8 if tamano.y < 440.0 else 16)
	creation_margin.add_theme_constant_override("margin_bottom", 8 if tamano.y < 440.0 else 16)
	creation_column.add_theme_constant_override("separation", 6 if compacto else 10)
	creation_fields.custom_minimum_size.x = 0
	appearance_container.custom_minimum_size.x = 0
	_ajustar_orientacion_contenido(compacto)


func _ajustar_orientacion_contenido(vertical: bool) -> void:
	var ya_vertical := creation_content is VBoxContainer
	if ya_vertical == vertical:
		creation_content.add_theme_constant_override("separation", 8 if vertical else 20)
		return

	var padre := creation_content.get_parent()
	if padre == null:
		return
	var indice := creation_content.get_index()
	var nuevo: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	nuevo.name = "Content"
	nuevo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nuevo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nuevo.add_theme_constant_override("separation", 8 if vertical else 20)

	# Conserva los mismos controles y conexiones; solo cambia su disposición.
	creation_content.get_parent().remove_child(creation_content)
	padre.add_child(nuevo)
	padre.move_child(nuevo, indice)
	for hijo in creation_content.get_children():
		creation_content.remove_child(hijo)
		nuevo.add_child(hijo)
	creation_content.free()
	creation_content = nuevo

func open(action: String) -> void:
	# Revalidar al abrir evita depender de cómo se añadió esta instancia.
	_normalizar_geometria_raiz()
	_action = action
	if is_instance_valid(_kingdom_label) and is_instance_valid(_kingdom_selector):
		_kingdom_selector.select(0)
		# La aventura directa y el botón «Nueva partida» del selector de
		# guardados son ambos flujos de creación de un mundo nuevo.
		var mostrar_selector_reino := action in ["aventura", "nueva_partida"]
		_kingdom_label.visible = mostrar_selector_reino
		_kingdom_selector.visible = mostrar_selector_reino
	partida_name_input.text = ""
	seed_input.text = ""
	name_input.text = ""
	gender.select(0)
	gender_free.text = ""
	gender_free.visible = false
	_seleccionar_especie_humana()
	status.visible = false
	for slot in CharacterAppearance.SLOTS:
		var lista: ItemList = _personalizacion_items.get(slot) as ItemList
		if lista != null and lista.item_count > 0:
			lista.select(0)
		var color_inicial := _color_inicial(slot)
		var selector_color: ColorPickerButton = _personalizacion_colores.get(slot) as ColorPickerButton
		if selector_color != null:
			selector_color.color = color_inicial
		_personalizacion[slot] = {"ruta": "", "color": CharacterAppearance.color_a_html(color_inicial)}
	# Selecciona de inicio el primer peinado disponible (los nuevos 1/2/3 Front
	# quedan al principio del catálogo) para que la vista previa nunca aparezca calva.
	var lista_pelo: ItemList = _personalizacion_items.get("hair") as ItemList
	if lista_pelo != null and lista_pelo.item_count > 1:
		lista_pelo.select(1)
		_al_seleccionar_pieza(1, "hair")
	_actualizar_vista_previa()
	visible = true
	name_input.grab_focus()
	_update_confirm()

func _crear_selector_reino_inicial() -> void:
	_kingdom_label = Label.new()
	_kingdom_label.name = "KingdomLabel"
	_kingdom_label.text = "Reino inicial"
	_kingdom_selector = OptionButton.new()
	_kingdom_selector.name = "KingdomSelector"
	_kingdom_selector.custom_minimum_size = Vector2(0, 36)
	_kingdom_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kingdom_selector.add_item("Torres")
	_kingdom_selector.set_item_metadata(0, "torres")
	_kingdom_selector.add_item("Froslia")
	_kingdom_selector.set_item_metadata(1, "froslia")
	_kingdom_selector.select(0)
	creation_fields.add_child(_kingdom_label)
	creation_fields.add_child(_kingdom_selector)
	var indice_semilla := seed_input.get_index()
	creation_fields.move_child(_kingdom_label, indice_semilla + 1)
	creation_fields.move_child(_kingdom_selector, indice_semilla + 2)


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

func _seleccionar_especie_humana() -> void:
	if species.item_count == 0:
		return
	for indice in range(species.item_count):
		var datos_variant: Variant = species.get_item_metadata(indice)
		if not datos_variant is Dictionary:
			continue
		var datos := datos_variant as Dictionary
		var nombre := str(datos.get("nombre", "")).strip_edges().to_lower()
		var clave := str(datos.get("clave", "")).strip_edges().to_lower()
		if nombre == "humano" or clave == "humano":
			species.select(indice)
			return
	# No elegimos otra especie silenciosamente si Humano no está disponible.
	species.select(-1)
	status.text = "La especie Humano no está disponible."
	status.visible = true


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
		status.visible = false
		_seleccionar_especie_humana()
		_actualizar_genero_segun_especie()
	else:
		status.text = "No hay especies jugables disponibles."
		status.visible = true
	_update_confirm()

func _crear_vista_previa() -> void:
	var barra_vistas := HBoxContainer.new()
	barra_vistas.name = "SelectorVistaPrevia"
	barra_vistas.alignment = BoxContainer.ALIGNMENT_CENTER
	barra_vistas.add_theme_constant_override("separation", 10)
	var anterior := Button.new()
	anterior.text = "‹"
	anterior.custom_minimum_size = Vector2(38, 30)
	anterior.tooltip_text = "Vista anterior"
	anterior.pressed.connect(_cambiar_vista_previa.bind(-1))
	barra_vistas.add_child(anterior)
	_preview_direction_label = Label.new()
	_preview_direction_label.text = PREVIEW_DIRECTIONS[_preview_direction_index]
	_preview_direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_direction_label.custom_minimum_size.x = 100
	barra_vistas.add_child(_preview_direction_label)
	var siguiente := Button.new()
	siguiente.text = "›"
	siguiente.custom_minimum_size = Vector2(38, 30)
	siguiente.tooltip_text = "Vista siguiente"
	siguiente.pressed.connect(_cambiar_vista_previa.bind(1))
	barra_vistas.add_child(siguiente)
	appearance_container.add_child(barra_vistas)

	_preview_container = APPEARANCE_PREVIEW_SCENE.instantiate() as Control
	_preview_container.name = "VistaPreviaPersonaje"
	for slot in CharacterAppearance.SLOTS:
		var capa := _preview_container.get_node_or_null(slot.capitalize()) as TextureRect
		if capa != null:
			_preview_layers[slot] = capa
	var cuerpo := _preview_layers.get("body") as TextureRect
	if cuerpo != null:
		cuerpo.visible = true
	appearance_container.add_child(_preview_container)
	_actualizar_vista_previa()


func _cambiar_vista_previa(delta: int) -> void:
	_preview_direction_index = posmod(_preview_direction_index + delta, PREVIEW_DIRECTIONS.size())
	if is_instance_valid(_preview_direction_label):
		_preview_direction_label.text = PREVIEW_DIRECTIONS[_preview_direction_index]
	_actualizar_vista_previa()


func _actualizar_vista_previa() -> void:
	var direccion: String = PREVIEW_DIRECTIONS[_preview_direction_index]
	var cuerpo := _preview_layers.get("body") as TextureRect
	if cuerpo != null:
		var clave_sprite := "idle_front"
		match direccion:
			"Atrás": clave_sprite = "walk_back"
			"Izquierda", "Derecha": clave_sprite = "walk_left"
		cuerpo.texture = CharacterAppearance.obtener_textura_sprite(clave_sprite)
		cuerpo.flip_h = direccion == "Derecha"

	for slot in ["shoes", "pants", "shirt", "eyes", "hair"]:
		var capa: TextureRect = _preview_layers.get(slot) as TextureRect
		var lista: ItemList = _personalizacion_items.get(slot) as ItemList
		var selector_color: ColorPickerButton = _personalizacion_colores.get(slot) as ColorPickerButton
		if capa == null:
			continue
		var ruta := ""
		if lista != null:
			var seleccionados := lista.get_selected_items()
			if not seleccionados.is_empty():
				ruta = str(lista.get_item_metadata(seleccionados[0]))
		var ruta_vista := _ruta_pieza_para_vista(ruta, direccion)
		capa.texture = load(ruta_vista) as Texture2D if not ruta_vista.is_empty() and ResourceLoader.exists(ruta_vista) else null
		capa.flip_h = direccion == "Derecha"
		capa.modulate = selector_color.color if selector_color != null else Color.WHITE
		capa.visible = capa.texture != null


func _ruta_pieza_para_vista(ruta: String, direccion: String) -> String:
	if ruta.is_empty():
		return ""
	var sufijo := " Front"
	match direccion:
		"Atrás": sufijo = " Back"
		"Izquierda", "Derecha": sufijo = " Lateral"
	var base := ruta.get_file().get_basename()
	var identificador := base.get_slice(" ", 0)
	var candidata := ruta.get_base_dir() + "/" + identificador + sufijo + ".png"
	return candidata if ResourceLoader.exists(candidata) else ruta

func _construir_controles_personalizacion() -> void:
	# Cada fila tiene estructura propia editable en el editor; el catálogo se
	# rellena aquí porque depende de los assets instalados en el proyecto.
	var etiqueta_skin := appearance_container.get_node_or_null("SkinLabel") as Label
	if etiqueta_skin != null:
		etiqueta_skin.visible = false

	_personalizacion_rows = VBoxContainer.new()
	_personalizacion_rows.name = "FilasPersonalizacion"
	_personalizacion_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_personalizacion_rows.add_theme_constant_override("separation", 4)
	appearance_container.add_child(_personalizacion_rows)

	for slot in CharacterAppearance.SLOTS:
		if slot == "body":
			continue
		var fila := APPEARANCE_OPTION_ROW_SCENE.instantiate() as HBoxContainer
		fila.name = "Fila_" + slot
		_personalizacion_rows.add_child(fila)

		var etiqueta := Label.new()
		etiqueta.text = str(CharacterAppearance.SLOT_LABELS.get(slot, slot.capitalize()))
		etiqueta.custom_minimum_size.x = 104.0
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fila.add_child(etiqueta)
		fila.move_child(etiqueta, 0)

		var lista := fila.get_node("CatalogoInterno") as ItemList
		lista.add_item("")
		lista.set_item_metadata(0, "")
		for pieza in CharacterAppearance.catalogo(slot):
			lista.add_icon_item(pieza["textura"], true)
			var indice := lista.item_count - 1
			lista.set_item_text(indice, "")
			lista.set_item_metadata(indice, str(pieza["ruta"]))
		lista.select(0)
		lista.item_selected.connect(_al_seleccionar_pieza.bind(slot))
		_personalizacion_items[slot] = lista

		var icono := fila.get_node("MiniaturaActual") as TextureRect
		_personalizacion_vistas[slot] = icono

		var anterior := fila.get_node("Anterior") as Button
		anterior.pressed.connect(_cambiar_opcion.bind(slot, -1))
		var siguiente := fila.get_node("Siguiente") as Button
		siguiente.pressed.connect(_cambiar_opcion.bind(slot, 1))

		var selector_color := fila.get_node("Color") as ColorPickerButton
		selector_color.color = _color_inicial(slot)
		selector_color.color_changed.connect(_al_cambiar_color_pieza.bind(slot))
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
		"body": return Color("#d8a078")
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
	confirm_button.disabled = not (partida_name_ok and name_ok and gender_ok and species_ok)

func _on_confirm() -> void:
	_update_confirm()
	if confirm_button.disabled:
		return
	var gender_value: String = gender.get_item_text(gender.selected)
	if not gender.visible:
		gender_value = "sin_genero"
	if gender.selected == 4:
		gender_value = gender_free.text.strip_edges()
	var species_data: Dictionary = species.get_item_metadata(species.selected) as Dictionary
	var reino_seleccionado := str(_kingdom_selector.get_item_metadata(_kingdom_selector.selected)).strip_edges().to_lower() if is_instance_valid(_kingdom_selector) and _kingdom_selector.selected >= 0 else "torres"
	var config: Dictionary = {
		"nombre_partida": partida_name_input.text.strip_edges(),
		"semilla": seed_input.text.strip_edges(),
		"nombre": name_input.text.strip_edges(),
		"genero": gender_value,
		"especie": species_data.duplicate(true),
		"personalizacion": _obtener_personalizacion(),
		"reino_inicial": reino_seleccionado,
		"nacionalidad": "Frosliano" if reino_seleccionado == "froslia" else "Torresiano"
	}
	visible = false
	confirmed.emit(config, _action)
	_action = ""
