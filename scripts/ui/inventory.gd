extends Control

const SLOT_SCENE: PackedScene = preload(
	"res://scenes/ui/inventory_slot.tscn"
)
const EQUIPMENT_SLOT_SCENE: PackedScene = preload(
	"res://scenes/ui/inventory_equipment_slot.tscn"
)

const HOTBAR_SLOT_COUNT: int = 8

var inventory_controller := InventoryController.new()

@export var slot_count: int = 24

signal inventory_changed
signal inventory_selection_changed(indice: int, datos: Dictionary)
signal active_item_changed(datos: Dictionary)

var slot_nodes: Array[Button] = []

var objeto_seleccionado: Dictionary = {}
var indice_seleccionado: int = -1

# El runtime es el único estado de inventario.
# Estos accesores mantienen compatibilidad con la UI existente sin duplicar
# items, hotbar o equipamiento en este nodo.
var items: Array[Dictionary]:
	get:
		return inventory_controller.runtime.state.items

var hotbar_indices: Array[int]:
	get:
		return inventory_controller.runtime.hotbar.indices

var equipo: Dictionary:
	get:
		return inventory_controller.runtime.equipment.state.slots

var indice_hotbar_activo: int:
	get:
		return inventory_controller.runtime.hotbar.indice_activo
	set(value):
		inventory_controller.runtime.hotbar.indice_activo = value
var _arrastre_indice: int = -1
var _arrastre_datos: Dictionary = {}
var _abierto: bool = false
var _player: Node = null


@onready var grid: GridContainer = $Window/Margin/Column/Tabs/Inventario/LeftPanel/Grid
@onready var item_name: Label = $Window/Margin/Column/Tabs/Inventario/LeftPanel/InfoPanel/InfoText/ItemName
@onready var item_description: Label = $Window/Margin/Column/Tabs/Inventario/LeftPanel/InfoPanel/InfoText/ItemDescription
@onready var item_icon: TextureRect = $Window/Margin/Column/Tabs/Inventario/LeftPanel/InfoPanel/ItemIcon
@onready var delete_button: Button = $Window/Margin/Column/Tabs/Inventario/LeftPanel/InfoPanel/InfoText/DeleteButton
@onready var equipment_slots: VBoxContainer = $Window/Margin/Column/Tabs/Inventario/RightPanel/EquipmentArea/EquipmentSlots


func _inicializar_navegacion_tabs() -> void:
	var tabs: TabContainer = $Window/Margin/Column/Tabs
	var tab_bar: TabBar = tabs.get_tab_bar()
	tab_bar.visible = false

	var boton_inventario: Button = $Window/Margin/Column/TabButtons/Inventario
	var boton_crafteo: Button = $Window/Margin/Column/TabButtons/Crafteo
	var boton_enciclopedia: Button = $Window/Margin/Column/TabButtons/Enciclopedia
	var boton_mapa: Button = $Window/Margin/Column/TabButtons/Mapa
	var boton_relaciones: Button = $Window/Margin/Column/TabButtons/Relaciones
	var boton_admin: Button = $Window/Margin/Column/TabButtons/Admin

	boton_inventario.pressed.connect(func() -> void:
		tabs.current_tab = 0
	)
	boton_crafteo.pressed.connect(func() -> void:
		tabs.current_tab = 1
	)

	boton_enciclopedia.pressed.connect(func() -> void:
		tabs.current_tab = 2
	)
	boton_mapa.pressed.connect(func() -> void:
		tabs.current_tab = 3
	)
	boton_relaciones.pressed.connect(func() -> void:
		tabs.current_tab = 4
	)
	boton_admin.pressed.connect(func() -> void:
		tabs.current_tab = 5
		var admin_tab := $Window/Margin/Column/Tabs/Admin as Control
		if admin_tab.has_method("abrir"):
			admin_tab.call("abrir", _player)
	)

	boton_inventario.button_pressed = true
	_actualizar_admin_tab()


func configurar(player: Node = null) -> void:
	_player = player


func configurar_input_gate(gate: Node) -> void:
	if inventory_controller.has_method("configurar_gate"):
		inventory_controller.configurar_gate(gate)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("inventory")
	add_child(inventory_controller)

	_inicializar_items()
	_inicializar_hotbar()
	_crear_slots()
	_crear_slots_equipamiento()
	delete_button.pressed.connect(_al_eliminar_seleccionado)
	_inicializar_navegacion_tabs()
	_limpiar_informacion()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed:
			return

		if key_event.echo:
			return

		if event.is_action_pressed("inventory"):
			toggle()
			get_viewport().set_input_as_handled()

		elif key_event.keycode == KEY_ESCAPE:
			if visible:
				cerrar()
				get_viewport().set_input_as_handled()


func _actualizar_admin_tab() -> void:
	var boton_admin: Button = $Window/Margin/Column/TabButtons/Admin
	var admin_tab := $Window/Margin/Column/Tabs/Admin as Control
	var jugador := _player
	var es_admin := false
	var datos_variant: Variant = GameState.flags.get("personaje_admin", {})
	if datos_variant is Dictionary:
		es_admin = str((datos_variant as Dictionary).get("rol", "explorador")).to_lower() == "admin"
	boton_admin.visible = es_admin
	admin_tab.visible = es_admin
	if not es_admin and $Window/Margin/Column/Tabs.current_tab == 5:
		$Window/Margin/Column/Tabs.current_tab = 0
	if es_admin and admin_tab.has_method("abrir"):
		admin_tab.call("abrir", jugador)


func toggle() -> void:
	if _abierto:
		cerrar()
	else:
		abrir()


func abrir() -> void:
	_abierto = true
	visible = true
	_actualizar_admin_tab()

	# La tecla E siempre abre el inventario principal.
	# La pestaña Admin solo se abre al pulsar su botón.
	var tabs: TabContainer = $Window/Margin/Column/Tabs
	tabs.current_tab = 0
	$Window/Margin/Column/TabButtons/Inventario.button_pressed = true

	actualizar()


func cerrar() -> void:
	_abierto = false

	# Al cerrar, ningún control del inventario debe conservar el foco GUI.
	# Esto evita que un Button de equipamiento retenga la siguiente entrada
	# del ratón y bloquee el flujo normal de _unhandled_input del juego.
	get_viewport().gui_release_focus()
	_arrastre_indice = -1
	_arrastre_datos.clear()

	visible = false

	objeto_seleccionado.clear()
	indice_seleccionado = -1

	_limpiar_informacion()


func esta_abierto() -> bool:
	# El inventario solo puede bloquear gameplay mientras su ventana
	# está realmente abierta. Esto evita que un estado interno antiguo
	# sobreviva si la escena/UI fue ocultada por otro sistema.
	if not visible:
		_abierto = false
		return false

	return _abierto


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

		if slot.has_signal("arrastre_recibido"):
			slot.connect(
				"arrastre_recibido",
				_al_recibir_arrastre
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


func _al_recibir_arrastre(slot: Button, datos_arrastre: Dictionary) -> void:
	var indice_destino: int = slot_nodes.find(slot)
	var indice_origen: int = int(datos_arrastre.get("indice", -1))
	if indice_origen < 0 or indice_destino < 0:
		return
	if inventory_controller.intercambiar_o_apilar(indice_origen, indice_destino):
		actualizar()
		inventory_changed.emit()
		_emitir_objeto_activo()

func _al_iniciar_arrastre(slot: Button, datos: Dictionary) -> void:
	_arrastre_indice = slot_nodes.find(slot)
	_arrastre_datos = datos.duplicate(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and _abierto:
		_abierto = false
		_arrastre_indice = -1
		_arrastre_datos.clear()
		get_viewport().gui_release_focus()
		return

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
		["cabeza", "CABEZA"],
		["torso", "TORSO"],
		["pies", "PIES"],
		["mano_secundaria", "MANO SECUNDARIA"]
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
	if objeto.is_empty():
		return
	var source_index := _buscar_indice_objeto(objeto)
	if source_index < 0:
		return
	var clave := ""
	if slot.has_method("obtener_clave"):
		clave = str(slot.call("obtener_clave"))
	if clave.is_empty():
		return
	if inventory_controller.equipar_desde_inventario(clave, source_index, objeto):
		if slot.has_method("configurar_objeto"):
			slot.call("configurar_objeto", objeto)
		actualizar()
		inventory_changed.emit()
		_emitir_objeto_activo()


func _al_desequipar_objeto(slot: Button, objeto: Dictionary) -> void:
	if objeto.is_empty():
		return
	var clave := ""
	if slot.has_method("obtener_clave"):
		clave = str(slot.call("obtener_clave"))
	if clave.is_empty():
		return
	if not inventory_controller.desequipar_a_inventario(clave):
		print("Inventory: no hay espacio para desequipar → ", str(objeto.get("nombre", "Objeto")))
		return
	if slot.has_method("limpiar_objeto"):
		slot.call("limpiar_objeto")
	actualizar()
	inventory_changed.emit()
	_emitir_objeto_activo()


func obtener_equipamiento() -> Dictionary:
	return inventory_controller.obtener_equipamiento()

func obtener_objeto_equipado(clave: String = "mano_secundaria") -> Dictionary:
	return inventory_controller.obtener_objeto_equipado(clave)

func consumir_durabilidad_equipo(clave: String = "mano_secundaria") -> bool:
	var resultado: bool = inventory_controller.consumir_durabilidad_equipo(clave)
	if resultado:
		actualizar()
		_actualizar_slots_equipamiento()
		inventory_changed.emit()
	return resultado


func obtener_estadistica_equipo(
	clave: String,
	valor_por_defecto: float = 0.0
) -> float:
	var buscada: String = clave.strip_edges()
	if buscada.is_empty():
		return valor_por_defecto

	var total: float = valor_por_defecto

	for objeto_variant in equipo.values():
		if not objeto_variant is Dictionary:
			continue

		var objeto := objeto_variant as Dictionary
		var propiedades_variant: Variant = objeto.get(
			"propiedades_game",
			{}
		)

		if not propiedades_variant is Dictionary:
			continue

		var propiedades := propiedades_variant as Dictionary
		var valor: Variant = propiedades.get(
			buscada,
			null
		)

		if valor is int or valor is float:
			total += float(valor)

	return total


func obtener_estadisticas_equipo() -> Dictionary:
	var estadisticas: Dictionary = {}

	for objeto_variant in equipo.values():
		if not objeto_variant is Dictionary:
			continue

		var objeto := objeto_variant as Dictionary
		var propiedades_variant: Variant = objeto.get(
			"propiedades_game",
			{}
		)

		if not propiedades_variant is Dictionary:
			continue

		var propiedades := propiedades_variant as Dictionary

		for clave_variant in propiedades.keys():
			var clave: String = str(clave_variant)
			var valor: Variant = propiedades.get(
				clave_variant,
				null
			)

			if not (valor is int or valor is float):
				continue

			estadisticas[clave] = (
				float(estadisticas.get(clave, 0.0))
				+ float(valor)
			)

	return estadisticas


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
	var resultado: bool = inventory_controller.agregar_objeto(datos_objeto)
	if resultado:
		actualizar()
		inventory_changed.emit()
		_emitir_objeto_activo()
	return resultado

func _puede_apilar_con(
	existente: Dictionary,
	nuevo_objeto: Dictionary
) -> bool:
	if existente.is_empty() or nuevo_objeto.is_empty():
		return false

	var max_stack_existente: int = maxi(
		1,
		int(existente.get("max_stack", 1))
	)
	var max_stack_nuevo: int = maxi(
		1,
		int(nuevo_objeto.get("max_stack", 1))
	)

	if max_stack_existente <= 1 or max_stack_nuevo <= 1:
		return false

	var id_existente: String = str(
		existente.get(
			"id",
			existente.get("item_id", "")
		)
	).strip_edges()

	var id_nuevo: String = str(
		nuevo_objeto.get(
			"id",
			nuevo_objeto.get("item_id", "")
		)
	).strip_edges()

	if not id_existente.is_empty() and not id_nuevo.is_empty():
		return id_existente == id_nuevo

	var nombre_existente: String = str(
		existente.get("nombre", "")
	).strip_edges().to_lower()

	var nombre_nuevo: String = str(
		nuevo_objeto.get("nombre", "")
	).strip_edges().to_lower()

	return (
		nombre_existente == nombre_nuevo
		and not nombre_existente.is_empty()
	)


func usar_objeto_activo(usuario: Node = null) -> bool:
	var indice: int = obtener_indice_inventario_hotbar(
		indice_hotbar_activo
	)

	if indice < 0:
		return false

	if indice >= items.size() or items[indice].is_empty():
		return false

	var objeto: Dictionary = items[indice]
	var uso: Dictionary = _obtener_definicion_uso(objeto)

	if uso.is_empty():
		return false

	var actor: Node = usuario
	if actor == null:
		actor = _player

	if actor == null or not is_instance_valid(actor):
		return false

	var efectos_aplicados: int = _aplicar_efectos_uso(
		uso,
		actor
	)

	if efectos_aplicados <= 0:
		return false

	quitar_cantidad(indice, 1)

	Events.notification_pushed.emit(
		"Usaste " + str(objeto.get("nombre", "Objeto"))
	)

	return true


func _obtener_definicion_uso(objeto: Dictionary) -> Dictionary:
	var propiedades_variant: Variant = objeto.get(
		"propiedades_game",
		{}
	)

	if not propiedades_variant is Dictionary:
		return {}

	var propiedades: Dictionary = propiedades_variant as Dictionary
	var uso_variant: Variant = propiedades.get(
		"uso",
		{}
	)

	if not uso_variant is Dictionary:
		return {}

	var uso: Dictionary = uso_variant as Dictionary

	if bool(uso.get("permitido", true)) == false:
		return {}

	var tipo: String = str(
		uso.get("tipo", "")
	).strip_edges().to_lower()

	if tipo.is_empty():
		return {}

	return uso.duplicate(true)


func _aplicar_efectos_uso(
	uso: Dictionary,
	actor: Node
) -> int:
	var aplicados: int = 0
	var efectos_variant: Variant = uso.get(
		"efectos",
		null
	)

	if efectos_variant is Array:
		for efecto_variant in efectos_variant as Array:
			if not efecto_variant is Dictionary:
				continue

			if _aplicar_efecto_recurso(
				efecto_variant as Dictionary,
				actor
			):
				aplicados += 1

		return aplicados

	var efecto: Dictionary = uso.duplicate(true)

	if _aplicar_efecto_recurso(efecto, actor):
		aplicados += 1

	return aplicados


func _aplicar_efecto_recurso(
	efecto: Dictionary,
	actor: Node
) -> bool:
	var recurso: String = str(
		efecto.get(
			"recurso",
			efecto.get("efecto", "")
		)
	).strip_edges().to_lower()

	var magnitud_variant: Variant = efecto.get(
		"magnitud",
		efecto.get("cantidad", 0)
	)

	if not (
		magnitud_variant is int
		or magnitud_variant is float
	):
		return false

	var magnitud: float = maxf(
		float(magnitud_variant),
		0.0
	)

	if magnitud <= 0.0:
		return false

	match recurso:
		"vida", "salud", "health":
			if not actor.has_method("heal"):
				return false

			if "health" not in actor or "max_health" not in actor:
				return false

			var antes: int = int(actor.get("health"))
			var maximo: int = int(actor.get("max_health"))

			if antes >= maximo:
				return false

			actor.call("heal", roundi(magnitud))
			return int(actor.get("health")) > antes

		"stamina":
			if not actor.has_method("restaurar_stamina"):
				return false

			var antes_stamina: float = float(actor.get("stamina"))
			var max_stamina_actor: float = float(actor.get("max_stamina"))

			if antes_stamina >= max_stamina_actor:
				return false

			actor.call("restaurar_stamina", magnitud)
			return float(actor.get("stamina")) > antes_stamina

		"eterium", "mana":
			if not actor.has_method("restaurar_eterium"):
				return false

			var antes_eterium: int = int(actor.get("mana"))
			var max_eterium: int = int(actor.get("max_mana"))

			if antes_eterium >= max_eterium:
				return false

			actor.call(
				"restaurar_eterium",
				magnitud
			)
			return int(actor.get("mana")) > antes_eterium

	return false


func consumir_objeto_activo(cantidad: int = 1) -> bool:
	var indice := obtener_indice_inventario_hotbar(indice_hotbar_activo)
	if indice < 0:
		return false
	return quitar_cantidad(indice, maxi(1, cantidad))


func quitar_objeto(indice: int) -> bool:
	if indice < 0 or indice >= items.size():
		return false

	if items[indice].is_empty():
		return false

	var cantidad: int = maxi(
		1,
		int(items[indice].get("cantidad", 1))
	)

	return quitar_cantidad(indice, cantidad)


func quitar_cantidad(indice: int, cantidad: int) -> bool:
	var resultado: bool = inventory_controller.quitar_cantidad(indice, cantidad)
	if not resultado:
		return false
	if indice_seleccionado == indice:
		var actualizado := obtener_objeto(indice)
		if actualizado.is_empty():
			indice_seleccionado = -1
			objeto_seleccionado.clear()
			_limpiar_informacion()
		else:
			objeto_seleccionado = actualizado
			_mostrar_informacion()
	actualizar()
	inventory_changed.emit()
	_emitir_objeto_activo()
	return true

func establecer_objeto(indice: int, datos_objeto: Dictionary) -> bool:
	var resultado: bool = inventory_controller.establecer_objeto(indice, datos_objeto)
	if resultado:
		actualizar()
		inventory_changed.emit()
		_emitir_objeto_activo()
	return resultado

func limpiar_inventario() -> void:
	inventory_controller.limpiar()
	indice_seleccionado = -1
	objeto_seleccionado.clear()
	_arrastre_indice = -1
	_arrastre_datos.clear()
	_inicializar_hotbar()
	indice_hotbar_activo = 0
	actualizar()
	_limpiar_informacion()
	inventory_changed.emit()
	_emitir_objeto_activo()

func _buscar_slot_libre() -> int:
	for i in range(items.size()):
		if items[i].is_empty():
			return i

	return -1


func obtener_objeto_equipado(clave: String) -> Dictionary:
	var objeto_variant: Variant = equipo.get(clave, {})

	if objeto_variant is Dictionary:
		return (objeto_variant as Dictionary).duplicate(true)

	return {}


func robar_objeto_equipado(clave: String) -> Dictionary:
	var objeto: Dictionary = obtener_objeto_equipado(clave)

	if objeto.is_empty():
		return {}

	equipo.erase(clave)

	for child in equipment_slots.get_children():
		if not child.has_method("obtener_clave"):
			continue

		var clave_slot: String = str(
			child.call("obtener_clave")
		)

		if clave_slot != clave:
			continue

		if child.has_method("limpiar_objeto"):
			child.call("limpiar_objeto")

		break

	actualizar()
	inventory_changed.emit()
	_emitir_objeto_activo()

	print(
		"Inventory: objeto robado → ",
		str(objeto.get("nombre", "Objeto"))
	)

	return objeto


func establecer_equipo(nuevo_equipo: Dictionary) -> void:
	equipo.clear()

	for clave_variant in nuevo_equipo.keys():
		var clave := str(clave_variant)
		var objeto_variant: Variant = nuevo_equipo.get(clave_variant, {})

		if objeto_variant is Dictionary:
			var objeto := objeto_variant as Dictionary

			if not objeto.is_empty():
				equipo[clave] = objeto.duplicate(true)

	for child in equipment_slots.get_children():
		if not child.has_method("obtener_clave"):
			continue

		if child.has_method("limpiar_objeto"):
			child.call("limpiar_objeto")

		var clave_slot := str(child.call("obtener_clave"))

		if equipo.has(clave_slot) and child.has_method("configurar_objeto"):
			child.call(
				"configurar_objeto",
				equipo[clave_slot]
			)

	if has_method("actualizar"):
		actualizar()

	if has_signal("inventory_changed"):
		inventory_changed.emit()

	if has_method("_emitir_objeto_activo"):
		_emitir_objeto_activo()


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


func establecer_hotbar_slot(indice_hotbar: int, indice_inventario: int) -> bool:
	var resultado: bool = inventory_controller.establecer_hotbar_slot(
		indice_hotbar,
		indice_inventario
	)
	if resultado:
		inventory_changed.emit()
		_emitir_objeto_activo()
	return resultado

func seleccionar_hotbar(indice_hotbar: int) -> void:
	if indice_hotbar < 0 or indice_hotbar >= HOTBAR_SLOT_COUNT:
		return

	indice_hotbar_activo = indice_hotbar
	inventory_controller.seleccionar_hotbar(indice_hotbar)

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



func consumir_durabilidad_objeto_activo() -> bool:
	var indice_inventario: int = obtener_indice_inventario_hotbar(indice_hotbar_activo)
	if indice_inventario < 0:
		return false
	var resultado: bool = inventory_controller.consumir_durabilidad(indice_inventario)
	if not resultado:
		return false
	actualizar()
	inventory_changed.emit()
	_emitir_objeto_activo()
	return true

func _emitir_objeto_activo() -> void:
	active_item_changed.emit(
		obtener_objeto_activo()
	)
