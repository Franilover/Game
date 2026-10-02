extends Control

const SLOT_SCENE: PackedScene = preload(
	"res://scenes/ui/inventory_slot.tscn"
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


@onready var grid: GridContainer = $Window/Margin/Column/Content/SlotsPanel/Grid
@onready var item_name: Label = $Window/Margin/Column/Content/InfoPanel/ItemName
@onready var item_description: Label = $Window/Margin/Column/Content/InfoPanel/ItemDescription


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("inventory")

	_inicializar_items()
	_inicializar_hotbar()
	_crear_slots()
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


func _limpiar_informacion() -> void:
	item_name.text = "Ningún objeto"
	item_description.text = "Selecciona un objeto para estudiar sus propiedades."


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
