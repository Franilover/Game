extends Control
class_name GarliaInventory

const SLOT_SCENE: PackedScene = preload(
	"res://scenes/ui/inventory_slot.tscn"
)
const EQUIPMENT_SLOT_SCENE: PackedScene = preload(
	"res://scenes/ui/inventory_equipment_slot.tscn"
)

const HOTBAR_SLOT_COUNT: int = 6

var inventory_controller := InventoryController.new()

@export var slot_count: int = 18

signal inventory_changed
signal inventory_selection_changed(indice: int, datos: Dictionary)
signal active_item_changed(datos: Dictionary)
signal hand_item_changed(hand: String, slot_index: int, datos: Dictionary)

var mano_izquierda_activa: int = 0
var mano_derecha_activa: int = 0

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
var _player: Player = null
var _world_items: GarliaWorldItems = null
var _equipment_stats_label: Label = null


@onready var grid: HBoxContainer = $Window/Margin/Column/Tabs/Inventario/LeftPanel/Grid
var _slot_grids: Array[GridContainer] = []
@onready var item_name: Label = $Window/Margin/Column/Tabs/Inventario/LeftPanel/InfoPanel/InfoText/ItemName
@onready var item_description: Label = $Window/Margin/Column/Tabs/Inventario/LeftPanel/InfoPanel/InfoText/ItemDescription
@onready var item_icon: TextureRect = $Window/Margin/Column/Tabs/Inventario/LeftPanel/InfoPanel/ItemIcon
@onready var delete_button: Button = $Window/Margin/Column/Tabs/Inventario/LeftPanel/InfoPanel/InfoText/DeleteButton
@onready var equipment_slots: VBoxContainer = $Window/Margin/Column/Tabs/Inventario/RightPanel/EquipmentArea/EquipmentSlots


func _inicializar_navegacion_tabs() -> void:
	var columna_principal := $Window/Margin/Column as VBoxContainer
	if columna_principal != null:
		# Los selectores superiores ya funcionan como barra de pestañas; no
		# reservar espacio vertical adicional antes del contenido.
		columna_principal.add_theme_constant_override("separation", 0)
	var tabs: TabContainer = $Window/Margin/Column/Tabs

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
		var admin_tab := $Window/Margin/Column/Tabs/Admin as AdminInventory
		if admin_tab != null:
			admin_tab.abrir(_player)
	)

	boton_inventario.button_pressed = true
	_actualizar_admin_tab()


func configurar(
	player: Player = null,
	world_entity_spawner: WorldEntitySpawner = null,
	world_context: WorldContext = null,
	relationship_system: RelationshipSystemService = null,
	world_items: GarliaWorldItems = null
) -> void:
	_player = player
	_world_items = world_items
	_configurar_admin_inventory(world_entity_spawner)
	_configurar_world_map(world_context)
	_configurar_relationships(relationship_system)
	_configurar_crafting()
	_actualizar_admin_tab()


func _configurar_admin_inventory(world_entity_spawner: WorldEntitySpawner) -> void:
	var admin_tab: AdminInventory = $Window/Margin/Column/Tabs/Admin as AdminInventory
	if admin_tab != null:
		admin_tab.configurar(_player, world_entity_spawner, self, _world_items)


func _configurar_world_map(world_context: WorldContext) -> void:
	var mapa: WorldMapUI = $Window/Margin/Column/Tabs/Mapa
	if _player != null and world_context != null:
		mapa.configurar(_player, world_context)


func _configurar_relationships(relationship_system: RelationshipSystemService) -> void:
	var relaciones: RelationshipsUI = $Window/Margin/Column/Tabs/Relaciones
	if relationship_system != null:
		relaciones.configurar(relationship_system)


func _configurar_crafting() -> void:
	var crafting: CraftingUI = $Window/Margin/Column/Tabs/Crafteo
	crafting.configurar(self, _world_items)


func serializar_estado_partida() -> Dictionary:
	var datos := inventory_controller.serializar()
	datos["mano_izquierda_activa"] = mano_izquierda_activa
	datos["mano_derecha_activa"] = mano_derecha_activa
	return datos


func cargar_estado_partida(datos: Dictionary) -> void:
	var items_variant: Variant = datos.get("items", [])
	var hotbar_variant: Variant = datos.get("hotbar_indices", [])
	var items: Array = items_variant as Array if items_variant is Array else []
	var hotbar: Array = hotbar_variant as Array if hotbar_variant is Array else []
	inventory_controller.configurar_items(items, hotbar)
	_normalizar_capacidades_runtime()

	var indice_activo := int(datos.get("indice_hotbar_activo", 0))
	if indice_activo >= 0 and indice_activo < hotbar_indices.size():
		inventory_controller.seleccionar_hotbar(indice_activo)

	mano_izquierda_activa = clampi(int(datos.get("mano_izquierda_activa", 0)), 0, 5)
	mano_derecha_activa = clampi(int(datos.get("mano_derecha_activa", 0)), 0, 5)

	var equipo_variant: Variant = datos.get("equipo", {})
	if equipo_variant is Dictionary:
		for slot_variant in (equipo_variant as Dictionary).keys():
			var slot := str(slot_variant)
			var item_variant: Variant = (equipo_variant as Dictionary).get(slot, {})
			if item_variant is Dictionary and not (item_variant as Dictionary).is_empty():
				inventory_controller.equipar(slot, (item_variant as Dictionary).duplicate(true))

	# El estado de runtime ya cambió; notificar a la hotbar/HUD después de
	# reconstruir los slots para que la carga no dependa de una interacción.
	actualizar()
	_actualizar_slots_equipamiento()
	inventory_changed.emit()
	_emitir_objeto_activo()
	call_deferred("_refrescar_interfaz_cargada")


func _refrescar_interfaz_cargada() -> void:
	if not is_inside_tree():
		return
	actualizar()
	_actualizar_slots_equipamiento()
	_emitir_objeto_activo()


func _normalizar_capacidades_runtime() -> void:
	# La capacidad pertenece a la configuración del inventario, no al archivo
	# de guardado. Una partida antigua o recién creada puede tener "items: []";
	# eso significa "sin objetos", no "0 slots".
	var capacidad := maxi(slot_count, 0)
	if items.size() < capacidad:
		items.resize(capacidad)

	# La hotbar nueva apunta exclusivamente a los seis espacios de mochila
	# (índices 6–11). Las partidas anteriores se normalizan sin descartar objetos.
	var indices_guardados := hotbar_indices.duplicate()
	hotbar_indices.resize(HOTBAR_SLOT_COUNT)
	for i in range(HOTBAR_SLOT_COUNT):
		var destino := 6 + i
		if i < indices_guardados.size() and int(indices_guardados[i]) >= 6 and int(indices_guardados[i]) <= 11:
			hotbar_indices[i] = int(indices_guardados[i])
		else:
			hotbar_indices[i] = destino if destino < items.size() else -1


func configurar_input_router(router: GameplayInputRouter) -> void:
	if router == null or not is_instance_valid(router):
		return
	var gate := GameplayInputGate.new()
	gate.configurar_router(router)
	inventory_controller.configurar_gate(gate)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("inventory")
	add_child(inventory_controller)

	_inicializar_items()
	_inicializar_hotbar()
	_crear_slots()
	_crear_slots_equipamiento()
	_preparar_panel_estadisticas_equipo()
	delete_button.pressed.connect(_al_eliminar_seleccionado)
	_inicializar_navegacion_tabs()
	_limpiar_informacion()


func _input(event: InputEvent) -> void:
	# En Android, tocar fuera de la ventana cierra el inventario.
	# Se consume el toque para evitar activar accidentalmente una acción del juego.
	if not OS.has_feature("android") or not _abierto or not visible:
		return
	var posicion_toque := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		posicion_toque = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		posicion_toque = (event as InputEventMouseButton).position
	if posicion_toque == Vector2.INF:
		return
	var ventana := $Window as Control
	if not ventana.get_global_rect().has_point(posicion_toque):
		cerrar()
		get_viewport().set_input_as_handled()


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
	var admin_tab := $Window/Margin/Column/Tabs/Admin as AdminInventory
	var jugador := _player
	var es_admin := false
	var datos_variant: Variant = GameState.obtener_configuracion_personaje_admin()
	if datos_variant is Dictionary:
		es_admin = str((datos_variant as Dictionary).get("rol", "explorador")).to_lower() == "admin"
	boton_admin.visible = es_admin
	admin_tab.visible = es_admin
	if not es_admin and $Window/Margin/Column/Tabs.current_tab == 5:
		$Window/Margin/Column/Tabs.current_tab = 0
	if es_admin:
		admin_tab.abrir(jugador)


func toggle() -> void:
	if _abierto:
		cerrar()
	else:
		abrir()


func toggle_mapa() -> void:
	var tabs: TabContainer = $Window/Margin/Column/Tabs
	if _abierto and tabs.current_tab == 3:
		cerrar()
		return
	if not _abierto:
		_abierto = true
		visible = true
		_actualizar_admin_tab()
	tabs.current_tab = 3
	$Window/Margin/Column/TabButtons/Mapa.button_pressed = true
	actualizar()


func toggle_enciclopedia_garumis() -> void:
	var tabs: TabContainer = $Window/Margin/Column/Tabs
	var enciclopedia := $Window/Margin/Column/Tabs/Enciclopedia as Control
	if _abierto and tabs.current_tab == 2:
		cerrar()
		return
	if not _abierto:
		_abierto = true
		visible = true
		_actualizar_admin_tab()
	tabs.current_tab = 2
	$Window/Margin/Column/TabButtons/Enciclopedia.button_pressed = true
	if enciclopedia != null and enciclopedia.has_method("abrir_en_garumis"):
		enciclopedia.call("abrir_en_garumis")


func abrir() -> void:
	_abierto = true
	visible = true
	_actualizar_admin_tab()

	# Tab abre el inventario principal.
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
		var indice_mochila := 6 + i
		hotbar_indices.append(indice_mochila if indice_mochila < slot_count else -1)


func _crear_slots() -> void:
	for slot in slot_nodes:
		if is_instance_valid(slot):
			slot.queue_free()
	for child in grid.get_children():
		child.queue_free()

	slot_nodes.clear()
	_slot_grids.clear()

	var nombres_grupo := ["MANO IZQUIERDA", "MOCHILA", "MANO DERECHA"]
	for grupo in range(3):
		var panel_grupo := VBoxContainer.new()
		panel_grupo.name = "Grupo_" + str(grupo)
		panel_grupo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel_grupo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel_grupo.add_theme_constant_override("separation", 8)
		grid.add_child(panel_grupo)

		var titulo := Label.new()
		titulo.text = nombres_grupo[grupo]
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.add_theme_font_size_override("font_size", 10)
		titulo.add_theme_color_override("font_color", Color(0.9, 0.79, 0.58, 1))
		panel_grupo.add_child(titulo)

		var rejilla := GridContainer.new()
		rejilla.name = "Slots"
		rejilla.columns = 3
		rejilla.add_theme_constant_override("h_separation", 5)
		rejilla.add_theme_constant_override("v_separation", 5)
		rejilla.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel_grupo.add_child(rejilla)
		_slot_grids.append(rejilla)

	for visual_index in range(slot_count):
		var slot_node := SLOT_SCENE.instantiate()
		if not slot_node is Button:
			continue
		var slot := slot_node as Button
		var indice_datos := visual_index
		slot.set_meta("inventory_index", indice_datos)
		var grupo := int(visual_index / 6)
		_slot_grids[grupo].add_child(slot)

		if slot.has_signal("seleccionado"):
			slot.connect("seleccionado", _al_seleccionar_slot)
		if slot.has_signal("arrastre_iniciado"):
			slot.connect("arrastre_iniciado", _al_iniciar_arrastre)
		if slot.has_signal("arrastre_recibido"):
			slot.connect("arrastre_recibido", _al_recibir_arrastre)
		slot_nodes.append(slot)

	actualizar()


func actualizar() -> void:
	for slot in slot_nodes:
		var indice_datos := _indice_datos_de_slot(slot)
		if indice_datos < 0 or indice_datos >= items.size():
			slot.limpiar()
			continue
		if items[indice_datos].is_empty():
			slot.limpiar()
		else:
			slot.configurar(items[indice_datos])


func _indice_datos_desde_visual(visual_index: int) -> int:
	# El orden de almacenamiento coincide con los grupos visibles: 6 por grupo.
	return visual_index


func _indice_datos_de_slot(slot: Button) -> int:
	if slot != null and slot.has_meta("inventory_index"):
		return int(slot.get_meta("inventory_index"))
	return -1


func _al_recibir_arrastre(slot: Button, datos_arrastre: Dictionary) -> void:
	var indice_destino: int = _indice_datos_de_slot(slot)
	var indice_origen: int = int(datos_arrastre.get("indice", -1))
	if indice_origen < 0 or indice_destino < 0:
		return
	if inventory_controller.intercambiar_o_apilar(indice_origen, indice_destino):
		actualizar()
		inventory_changed.emit()
		_emitir_objeto_activo()

func _al_iniciar_arrastre(slot: Button, datos: Dictionary) -> void:
	_arrastre_indice = _indice_datos_de_slot(slot)
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

	_soltar_objeto_al_mundo(indice, datos)


func _soltar_objeto_al_mundo(indice: int, datos: Dictionary) -> void:
	if indice < 0 or indice >= items.size() or datos.is_empty():
		return

	var world_items: GarliaWorldItems = _world_items

	if world_items == null:
		print("Inventory: no se encontró GarliaWorldItems para soltar el objeto.")
		return

	# El inventario solo descuenta el objeto si el WorldItem quedó registrado.
	if not world_items.soltar_objeto_al_mundo(datos, get_global_mouse_position()):
		print("Inventory: no se pudo crear el objeto en el mundo; se conserva en inventario.")
		return

	quitar_objeto(indice)


func _al_seleccionar_slot(slot: Button) -> void:
	var indice := _indice_datos_de_slot(slot)

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
		["pies", "PIES"]
	]

	for entrada in configuracion:
		var slot := EQUIPMENT_SLOT_SCENE.instantiate() as InventoryEquipmentSlot
		if slot == null:
			continue
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
	var equipment_slot := slot as InventoryEquipmentSlot
	if equipment_slot == null:
		return
	var clave: String = equipment_slot.obtener_clave()
	if clave.is_empty():
		return
	if inventory_controller.equipar_desde_inventario(clave, source_index, objeto):
		equipment_slot.configurar_objeto(objeto)
		actualizar()
		_actualizar_panel_estadisticas_equipo()
		inventory_changed.emit()
		_emitir_objeto_activo()


func _al_desequipar_objeto(slot: Button, objeto: Dictionary) -> void:
	if objeto.is_empty():
		return
	var equipment_slot := slot as InventoryEquipmentSlot
	if equipment_slot == null:
		return
	var clave: String = equipment_slot.obtener_clave()
	if clave.is_empty():
		return
	if not inventory_controller.desequipar_a_inventario(clave):
		print("Inventory: no hay espacio para desequipar → ", str(objeto.get("nombre", "Objeto")))
		return
	equipment_slot.limpiar_objeto()
	actualizar()
	_actualizar_panel_estadisticas_equipo()
	inventory_changed.emit()
	_emitir_objeto_activo()


func _actualizar_slots_equipamiento() -> void:
	for child in equipment_slots.get_children():
		var slot := child as InventoryEquipmentSlot
		if slot == null:
			continue

		var clave_slot: String = slot.obtener_clave()
		var objeto: Dictionary = obtener_objeto_equipado(clave_slot)

		if objeto.is_empty():
			slot.limpiar_objeto()
			continue

		slot.configurar_objeto(objeto)
	_actualizar_panel_estadisticas_equipo()


func obtener_equipamiento() -> Dictionary:
	return inventory_controller.obtener_equipamiento()

func obtener_objeto_equipado(clave: String = "mano_secundaria") -> Dictionary:
	return inventory_controller.obtener_objeto_equipado(clave)

func consumir_durabilidad_equipo(clave: String = "mano_secundaria") -> bool:
	var resultado: bool = inventory_controller.consumir_durabilidad_equipo(clave)
	if resultado:
		actualizar()
		_actualizar_slots_equipamiento()
		_actualizar_panel_estadisticas_equipo()
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


func _preparar_panel_estadisticas_equipo() -> void:
	var right_panel := $Window/Margin/Column/Tabs/Inventario/RightPanel as VBoxContainer
	if right_panel == null:
		return
	_equipment_stats_label = Label.new()
	_equipment_stats_label.name = "EquipmentStats"
	_equipment_stats_label.custom_minimum_size = Vector2(0, 38)
	_equipment_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipment_stats_label.add_theme_color_override("font_color", Color(0.82, 0.75, 0.61, 1.0))
	_equipment_stats_label.add_theme_font_size_override("font_size", 9)
	_equipment_stats_label.text = "EQUIPO\nSin bonificaciones numéricas registradas"
	right_panel.add_child(_equipment_stats_label)
	_actualizar_panel_estadisticas_equipo()


func _actualizar_panel_estadisticas_equipo() -> void:
	if not is_instance_valid(_equipment_stats_label):
		return
	var estadisticas := obtener_estadisticas_equipo()
	var lineas: PackedStringArray = ["ESTADÍSTICAS DE EQUIPO"]
	var claves: Array[String] = []
	for clave_variant in estadisticas.keys():
		var clave := str(clave_variant)
		# Propiedades físicas descriptivas no se presentan como bonificaciones.
		if clave in ["durabilidad", "dureza", "fractura"]:
			continue
		claves.append(clave)
	claves.sort()
	for clave in claves:
		var valor := float(estadisticas[clave])
		var nombre := clave.replace("_", " ").capitalize()
		var numero := ("+" if valor > 0.0 else "") + (("%.2f" % valor).rstrip("0").rstrip("."))
		lineas.append(nombre + ": " + numero)
	if claves.is_empty():
		lineas.append("Sin bonificaciones numéricas registradas")
	_equipment_stats_label.text = "\n".join(lineas)


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
	var id := str(objeto.get("id", objeto.get("item_id", ""))).strip_edges()
	for i in range(items.size()):
		if items[i].is_empty():
			continue
		var item_id := str(items[i].get("id", items[i].get("item_id", ""))).strip_edges()
		if not id.is_empty():
			if id == item_id:
				return i
			continue
		# Solo recurrir al nombre cuando ambos objetos carecen de ID.
		if item_id.is_empty() and str(items[i].get("nombre", "")) == str(objeto.get("nombre", "")):
			return i
	return -1


func _al_eliminar_seleccionado() -> void:
	if indice_seleccionado < 0:
		return

	if quitar_objeto(indice_seleccionado):
		print("Inventory: objeto eliminado.")


func _mostrar_informacion() -> void:
	var nombre := str(objeto_seleccionado.get("nombre", "Objeto"))
	var lineas: PackedStringArray = []
	var descripcion := str(objeto_seleccionado.get("descripcion", "")).strip_edges()
	if not descripcion.is_empty():
		lineas.append(descripcion)

	var cantidad := int(objeto_seleccionado.get("cantidad", 1))
	if cantidad > 1:
		lineas.append("Cantidad: %d" % cantidad)

	var propiedades_variant: Variant = objeto_seleccionado.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		var etiquetas := {
			"durabilidad": "Durabilidad",
			"dureza": "Dureza",
			"fractura": "Fractura",
			"composicion": "Composición",
			"material": "Material",
			"ranura_equipamiento": "Ranura"
		}
		for clave_variant in etiquetas.keys():
			var clave := str(clave_variant)
			if not propiedades.has(clave):
				continue
			var valor: Variant = propiedades.get(clave)
			if valor == null or str(valor).strip_edges().is_empty():
				continue
			lineas.append("%s: %s" % [str(etiquetas[clave]), str(valor)])

	item_name.text = nombre
	item_description.text = "\n".join(lineas) if not lineas.is_empty() else "Sin descripción ni propiedades adicionales registradas."
	item_description.visible = true
	delete_button.disabled = false

	var textura: Texture2D = ItemIconResolver.obtener_icono(objeto_seleccionado)
	item_icon.texture = textura
	item_icon.visible = textura != null


func _crear_estilo_boton(fondo: Color, borde: Color, borde_inferior: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(1)
	estilo.border_width_bottom = borde_inferior
	estilo.corner_radius_top_left = 3
	estilo.corner_radius_top_right = 3
	return estilo


func _limpiar_informacion() -> void:
	item_name.text = "Ningún objeto"
	item_description.text = ""
	item_description.visible = false
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

func usar_objeto_activo(usuario: Player = null) -> bool:
	return usar_objeto_en_indice(obtener_indice_inventario_hotbar(indice_hotbar_activo), usuario)


func usar_objeto_mano(mano: String, usuario: Player = null) -> bool:
	return usar_objeto_en_indice(obtener_indice_mano_activa(mano), usuario)


func usar_objeto_en_indice(indice: int, usuario: Player = null) -> bool:

	if indice < 0:
		return false

	if indice >= items.size() or items[indice].is_empty():
		return false

	var objeto: Dictionary = items[indice]
	var uso: Dictionary = _obtener_definicion_uso(objeto)

	if uso.is_empty():
		return false

	var actor: Player = usuario
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
	actor: Player
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
	actor: Player
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
			var antes: int = actor.health
			if antes >= actor.max_health:
				return false
			actor.heal(roundi(magnitud))
			return actor.health > antes

		"stamina":
			var antes_stamina: float = actor.stamina
			if antes_stamina >= actor.max_stamina:
				return false
			return actor.restaurar_stamina(magnitud)

		"eterium", "mana":
			var antes_eterium: int = actor.mana
			if antes_eterium >= actor.max_mana:
				return false
			return actor.restaurar_eterium(magnitud)

	return false


func consumir_objeto_activo(cantidad: int = 1) -> bool:
	return quitar_cantidad(obtener_indice_inventario_hotbar(indice_hotbar_activo), maxi(1, cantidad))


func consumir_objeto_mano(mano: String, cantidad: int = 1) -> bool:
	return quitar_cantidad(obtener_indice_mano_activa(mano), maxi(1, cantidad))


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


func robar_objeto_equipado(clave: String) -> Dictionary:
	var objeto: Dictionary = obtener_objeto_equipado(clave)

	if objeto.is_empty():
		return {}

	var objeto_retirado := inventory_controller.robar_objeto_equipado(clave)
	if objeto_retirado.is_empty():
		return {}
	objeto = objeto_retirado

	for child in equipment_slots.get_children():
		if not child is InventoryEquipmentSlot:
			continue

		var equipment_slot := child as InventoryEquipmentSlot
		var clave_slot: String = equipment_slot.obtener_clave()

		if clave_slot != clave:
			continue

		if child is InventoryEquipmentSlot:
			(child as InventoryEquipmentSlot).limpiar_objeto()

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
		if not child is InventoryEquipmentSlot:
			continue

		var equipment_slot := child as InventoryEquipmentSlot
		equipment_slot.limpiar_objeto()
		var clave_slot := equipment_slot.obtener_clave()

		if equipo.has(clave_slot):
			equipment_slot.configurar_objeto(equipo[clave_slot])

	actualizar()

	inventory_changed.emit()

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


func seleccionar_slot_mano(mano: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 6:
		return false
	var indice_datos := slot_index if mano == "izquierda" else 12 + slot_index
	if mano == "izquierda":
		mano_izquierda_activa = slot_index
	elif mano == "derecha":
		mano_derecha_activa = slot_index
	else:
		return false
	hand_item_changed.emit(mano, slot_index, obtener_objeto(indice_datos))
	return true


func obtener_indice_mano_activa(mano: String) -> int:
	if mano == "izquierda":
		return mano_izquierda_activa
	if mano == "derecha":
		return 12 + mano_derecha_activa
	return -1


func obtener_objeto_mano_activa(mano: String) -> Dictionary:
	if mano == "izquierda":
		return obtener_objeto(mano_izquierda_activa)
	if mano == "derecha":
		return obtener_objeto(12 + mano_derecha_activa)
	return {}


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
