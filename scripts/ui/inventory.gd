extends Control

const SLOT_SCENE: PackedScene = preload(
	"res://scenes/ui/inventory_slot.tscn"
)
const EQUIPMENT_SLOT_SCENE: PackedScene = preload(
	"res://scenes/ui/inventory_equipment_slot.tscn"
)

const HOTBAR_SLOT_COUNT: int = 8

@export var slot_count: int = 24

signal inventory_changed
signal inventory_selection_changed(indice: int, datos: Dictionary)
signal active_item_changed(datos: Dictionary)

var items: Array[Dictionary] = []
var slot_nodes: Array[Button] = []

var objeto_seleccionado: Dictionary = {}
var indice_seleccionado: int = -1

var indice_hotbar_activo: int = 0
var hotbar_indices: Array[int] = []

var equipo: Dictionary = {}
var _arrastre_indice: int = -1
var _arrastre_datos: Dictionary = {}


@onready var grid: GridContainer = $Window/Margin/Column/Content/LeftPanel/Grid
@onready var item_name: Label = $Window/Margin/Column/Content/LeftPanel/InfoPanel/InfoText/ItemName
@onready var item_description: Label = $Window/Margin/Column/Content/LeftPanel/InfoPanel/InfoText/ItemDescription
@onready var item_icon: TextureRect = $Window/Margin/Column/Content/LeftPanel/InfoPanel/ItemIcon
@onready var delete_button: Button = $Window/Margin/Column/Content/LeftPanel/InfoPanel/InfoText/DeleteButton
@onready var equipment_slots: VBoxContainer = $Window/Margin/Column/Content/RightPanel/EquipmentArea/EquipmentSlots


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("inventory")

	_inicializar_items()
	_inicializar_hotbar()
	_crear_slots()
	_crear_slots_equipamiento()
	delete_button.pressed.connect(_al_eliminar_seleccionado)
	_limpiar_informacion()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed:
			return

		if key_event.echo:
			return

		if key_event.keycode == KEY_I:
			toggle()
			get_viewport().set_input_as_handled()

		elif key_event.keycode == KEY_ESCAPE:
			if visible:
				cerrar()
				get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		cerrar()
	else:
		abrir()


func abrir() -> void:
	visible = true
	actualizar()


func cerrar() -> void:
	visible = false

	objeto_seleccionado.clear()
	indice_seleccionado = -1

	_limpiar_informacion()


func _inicializar_items() -> void:
	items.clear()
	items.resize(maxi(slot_count, 0))

	for i in range(items.size()):
		items[i] = {}


func _inicializar_hotbar() -> void:
	hotbar_indices.clear()

	for i in range(HOTBAR_SLOT_COUNT):
		if i < slot_count:
			hotbar_indices.append(i)
		else:
			hotbar_indices.append(-1)


func _crear_slots() -> void:
	for slot in slot_nodes:
		if is_instance_valid(slot):
			slot.queue_free()

	slot_nodes.clear()

	for i in range(slot_count):
		var slot_node := SLOT_SCENE.instantiate()

		if not slot_node is Button:
			continue

		var slot := slot_node as Button

		grid.add_child(slot)

		if slot.has_signal("seleccionado"):
			slot.connect(
				"seleccionado",
				_al_seleccionar_slot
			)

		if slot.has_signal("arrastre_iniciado"):
			slot.connect(
				"arrastre_iniciado",
				_al_iniciar_arrastre
			)

		slot_nodes.append(slot)

	actualizar()


func actualizar() -> void:
	for i in range(slot_nodes.size()):
		var slot := slot_nodes[i]

		if i >= items.size():
			slot.limpiar()
			continue

		if items[i].is_empty():
			slot.limpiar()
		else:
			slot.configurar(items[i])


func _al_iniciar_arrastre(slot: Button, datos: Dictionary) -> void:
	_arrastre_indice = slot_nodes.find(slot)
	_arrastre_datos = datos.duplicate(true)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return

	if _arrastre_indice < 0 or _arrastre_datos.is_empty():
		return

	var indice := _arrastre_indice
	var datos := _arrastre_datos.duplicate(true)
	_arrastre_indice = -1
	_arrastre_datos.clear()

	if get_viewport().gui_is_drag_successful():
		return

	if not visible:
		return

	if not has_method("_soltar_objeto_al_mundo"):
		return

	_soltar_objeto_al_mundo(indice, datos)


func _soltar_objeto_al_mundo(indice: int, datos: Dictionary) -> void:
	if indice < 0 or indice >= items.size() or datos.is_empty():
		return

	var world_items: Node = GarliaWorldItems

	if world_items == null or not world_items.has_method("soltar_objeto_al_mundo"):
		print("Inventory: no se encontró GarliaWorldItems para soltar el objeto.")
		return

	world_items.call(
		"soltar_objeto_al_mundo",
		datos,
		get_global_mouse_position()
	)

	quitar_objeto(indice)


func _al_seleccionar_slot(slot: Button) -> void:
	var indice := slot_nodes.find(slot)

	if indice < 0:
		return

	seleccionar_slot(indice)


func seleccionar_slot(indice: int) -> void:
	if indice < 0:
		indice_seleccionado = -1
		objeto_seleccionado.clear()

		_limpiar_informacion()

		inventory_selection_changed.emit(
			-1,
			{}
		)

		return

	if indice >= items.size():
		return

	indice_seleccionado = indice

	if items[indice].is_empty():
		objeto_seleccionado.clear()

		_limpiar_informacion()

		inventory_selection_changed.emit(
			indice,
			{}
		)

		return

	objeto_seleccionado = items[indice].duplicate(true)

	_mostrar_informacion()

	inventory_selection_changed.emit(
		indice,
		objeto_seleccionado.duplicate(true)
	)


func _crear_slots_equipamiento() -> void:
	for child in equipment_slots.get_children():
		child.queue_free()

	var configuracion := [
		["casco", "CASCO"],
		["pechera", "PECHERA"],
		["pantalones", "PANTALONES"],
		["botas", "BOTAS"]
	]

	for entrada in configuracion:
		var slot_node := EQUIPMENT_SLOT_SCENE.instantiate()
		if not slot_node is Button:
			continue

		var slot := slot_node as Button
		equipment_slots.add_child(slot)
		slot.configurar(str(entrada[0]), str(entrada[1]))
		slot.objeto_equipado.connect(_al_equipar_objeto)
		slot.objeto_desequipado.connect(_al_desequipar_objeto)


func _al_equipar_objeto(slot: Button, objeto: Dictionary) -> void:
	var source_index := _buscar_indice_objeto(objeto)
	if source_index < 0:
		return

	var slot_script := slot as Button
	var anterior: Dictionary = {}
	if slot_script.has_method("obtener_datos"):
		anterior = slot_script.obtener_datos()

	# Si estamos reemplazando, primero aseguramos que el objeto anterior
	# tenga un lugar disponible antes de modificar el equipamiento.
	if not anterior.is_empty():
		var indice_libre := _buscar_slot_libre()
		if indice_libre < 0 and source_index < 0:
			return

	var clave := ""
	if slot_script.has_method("obtener_clave"):
		clave = str(slot_script.obtener_clave())

	if not anterior.is_empty():
		items[source_index] = anterior.duplicate(true)
	else:
		items[source_index] = {}

	equipo[clave] = objeto.duplicate(true)
	slot_script.configurar_objeto(objeto)

	actualizar()
	inventory_changed.emit()
	_emitir_objeto_activo()


func _al_desequipar_objeto(slot: Button, objeto: Dictionary) -> void:
	var indice_libre := _buscar_slot_libre()
	if indice_libre < 0:
		return

	var clave := ""
	if slot.has_method("obtener_clave"):
		clave = str(slot.obtener_clave())

	equipo.erase(clave)
	items[indice_libre] = objeto.duplicate(true)
	actualizar()
	inventory_changed.emit()
	_emitir_objeto_activo()


func _buscar_indice_objeto(objeto: Dictionary) -> int:
	var id := str(objeto.get("id", objeto.get("item_id", "")))
	for i in range(items.size()):
		if items[i].is_empty():
			continue
		var item_id := str(items[i].get("id", items[i].get("item_id", "")))
		if not id.is_empty() and id == item_id:
			return i
		if items[i].get("nombre", "") == objeto.get("nombre", ""):
			return i
	return -1


func _al_eliminar_seleccionado() -> void:
	if indice_seleccionado < 0:
		return

	if quitar_objeto(indice_seleccionado):
		print("Inventory: objeto eliminado.")


func _mostrar_informacion() -> void:
	var nombre := str(
		objeto_seleccionado.get(
			"nombre",
			"Objeto"
		)
	)

	var descripcion := str(
		objeto_seleccionado.get(
			"descripcion",
			"Sin descripción."
		)
	)

	item_name.text = nombre
	item_description.text = descripcion
	delete_button.disabled = false

	var textura: Texture2D = ItemIconResolver.obtener_icono(objeto_seleccionado)
	item_icon.texture = textura
	item_icon.visible = textura != null


func _limpiar_informacion() -> void:
	item_name.text = "Ningún objeto"
	item_description.text = "Selecciona un objeto para estudiar sus propiedades."
	item_icon.texture = null
	item_icon.visible = false
	delete_button.disabled = true


func agregar_objeto(datos_objeto: Dictionary) -> bool:
	if datos_objeto.is_empty():
		return false

	var indice_libre := _buscar_slot_libre()

	if indice_libre < 0:
		print("Inventory: inventario lleno.")
		return false

	var objeto := datos_objeto.duplicate(true)

	if not objeto.has("cantidad"):
		objeto["cantidad"] = 1

	items[indice_libre] = objeto

	actualizar()

	inventory_changed.emit()
	_emitir_objeto_activo()

	print(
		"Inventory: objeto añadido en slot ",
		indice_libre + 1,
		" → ",
		str(objeto.get("nombre", "Objeto"))
	)

	return true


func quitar_objeto(indice: int) -> bool:
	if indice < 0 or indice >= items.size():
		return false

	if items[indice].is_empty():
		return false

	items[indice] = {}

	if indice_seleccionado == indice:
		indice_seleccionado = -1
		objeto_seleccionado.clear()
		_limpiar_informacion()

	actualizar()
	_actualizar_equipo_mostrado()
	inventory_changed.emit()
	_emitir_objeto_activo()

	return true


func establecer_objeto(
	indice: int,
	datos_objeto: Dictionary
) -> bool:
	if indice < 0 or indice >= items.size():
		return false

	if datos_objeto.is_empty():
		items[indice] = {}
	else:
		items[indice] = datos_objeto.duplicate(true)

	actualizar()
	inventory_changed.emit()
	_emitir_objeto_activo()

	return true


func limpiar_inventario() -> void:
	for i in range(items.size()):
		items[i] = {}

	indice_seleccionado = -1
	objeto_seleccionado.clear()

	actualizar()
	_limpiar_informacion()

	inventory_changed.emit()
	_emitir_objeto_activo()


func _buscar_slot_libre() -> int:
	for i in range(items.size()):
		if items[i].is_empty():
			return i

	return -1


func obtener_objeto(indice: int) -> Dictionary:
	if indice < 0 or indice >= items.size():
		return {}

	if items[indice].is_empty():
		return {}

	return items[indice].duplicate(true)


func esta_ocupado(indice: int) -> bool:
	if indice < 0 or indice >= items.size():
		return false

	return not items[indice].is_empty()


func obtener_objetos() -> Array[Dictionary]:
	return items.duplicate(true)


func obtener_objeto_seleccionado() -> Dictionary:
	return objeto_seleccionado.duplicate(true)


func obtener_indice_seleccionado() -> int:
	return indice_seleccionado


func obtener_objeto_hotbar(indice_hotbar: int) -> Dictionary:
	if indice_hotbar < 0:
		return {}

	if indice_hotbar >= hotbar_indices.size():
		return {}

	var indice_inventario := hotbar_indices[indice_hotbar]

	if indice_inventario < 0:
		return {}

	return obtener_objeto(indice_inventario)


func obtener_indice_inventario_hotbar(
	indice_hotbar: int
) -> int:
	if indice_hotbar < 0:
		return -1

	if indice_hotbar >= hotbar_indices.size():
		return -1

	return hotbar_indices[indice_hotbar]


func establecer_hotbar_slot(
	indice_hotbar: int,
	indice_inventario: int
) -> bool:
	if indice_hotbar < 0:
		return false

	if indice_hotbar >= HOTBAR_SLOT_COUNT:
		return false

	if indice_inventario < 0:
		return false

	if indice_inventario >= items.size():
		return false

	hotbar_indices[indice_hotbar] = indice_inventario

	inventory_changed.emit()
	_emitir_objeto_activo()

	return true


func seleccionar_hotbar(indice_hotbar: int) -> void:
	if indice_hotbar < 0 or indice_hotbar >= HOTBAR_SLOT_COUNT:
		return

	indice_hotbar_activo = indice_hotbar

	# La hotbar tiene su propia selección.
	# NO seleccionamos el slot correspondiente del inventario.
	_emitir_objeto_activo()


func obtener_objeto_activo() -> Dictionary:
	var indice_inventario := obtener_indice_inventario_hotbar(
		indice_hotbar_activo
	)

	if indice_inventario < 0:
		return {}

	return obtener_objeto(indice_inventario)


func obtener_indice_hotbar_activo() -> int:
	return indice_hotbar_activo


func _emitir_objeto_activo() -> void:
	active_item_changed.emit(
		obtener_objeto_activo()
	)
