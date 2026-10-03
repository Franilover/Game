extends ColorRect

signal confirmed(config: Dictionary, action: String)
signal cancelled

var _action: String = ""
var _skins: Array[String] = []

@onready var name_input: LineEdit = $Panel/Margin/Column/NameInput
@onready var gender: OptionButton = $Panel/Margin/Column/Gender
@onready var gender_free: LineEdit = $Panel/Margin/Column/GenderFree
@onready var species: OptionButton = $Panel/Margin/Column/Species
@onready var skins: ItemList = $Panel/Margin/Column/Skins
@onready var status: Label = $Panel/Margin/Column/Status
@onready var confirm_button: Button = $Panel/Margin/Column/Buttons/Confirm
@onready var cancel_button: Button = $Panel/Margin/Column/Buttons/Cancel

func _ready() -> void:
	visible = false
	gender.add_item("Hombre")
	gender.add_item("Mujer")
	gender.add_item("Agenero")
	gender.add_item("Texto libre")
	gender.item_selected.connect(_on_gender_selected)
	name_input.text_changed.connect(_update_confirm)
	gender_free.text_changed.connect(_update_confirm)
	skins.item_selected.connect(_update_confirm)
	confirm_button.pressed.connect(_on_confirm)
	cancel_button.pressed.connect(_on_cancel)
	_load_skins()
	if not SupabaseClient.especies_jugables_cargadas.is_connected(_on_species_loaded):
		SupabaseClient.especies_jugables_cargadas.connect(_on_species_loaded)
	SupabaseClient.cargar_especies_jugables()

func open(action: String) -> void:
	_action = action
	name_input.text = ""
	gender.select(0)
	gender_free.text = ""
	gender_free.visible = false
	if species.item_count > 0:
		species.select(0)
	if skins.item_count > 0:
		skins.select(0)
	visible = true
	name_input.grab_focus()
	_update_confirm()

func _on_cancel() -> void:
	_action = ""
	visible = false
	cancelled.emit()

func _on_gender_selected(index: int) -> void:
	gender_free.visible = index == 3
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
		status.text = "Especies jugables cargadas desde Supabase."
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

func _update_confirm(_index: int = -1) -> void:
	if confirm_button == null:
		return
	var name_ok: bool = not name_input.text.strip_edges().is_empty()
	var gender_ok: bool = gender.selected != 3 or not gender_free.text.strip_edges().is_empty()
	var species_ok: bool = species.item_count > 0 and species.selected >= 0
	var skin_ok: bool = skins.item_count > 0 and skins.get_selected_items().size() > 0
	confirm_button.disabled = not (name_ok and gender_ok and species_ok and skin_ok)

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
	if gender.selected == 3:
		gender_value = gender_free.text.strip_edges()
	var species_data: Dictionary = species.get_item_metadata(species.selected) as Dictionary
	var config: Dictionary = {
		"nombre": name_input.text.strip_edges(),
		"genero": gender_value,
		"especie": species_data.duplicate(true),
		"skin": _skins[skin_index],
		"skin_nombre": _skins[skin_index].get_file().get_basename()
	}
	visible = false
	confirmed.emit(config, _action)
	_action = ""
