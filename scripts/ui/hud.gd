extends Control
class_name HUD

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const MISSION_PANEL_SCENE: PackedScene = preload("res://scenes/ui/hud_mission_panel.tscn")
const INTERACTION_PANEL_SCENE: PackedScene = preload("res://scenes/ui/hud_interaction_panel.tscn")
const DASH_CHARGES_SCENE: PackedScene = preload("res://scenes/ui/hud_dash_charges.tscn")
const DISCOVERY_NOTICE_SCENE: PackedScene = preload("res://scenes/ui/hud_discovery_notice.tscn")
const CALENDAR_CLOCK_SCENE: PackedScene = preload("res://scenes/ui/hud_calendar_clock.tscn")
const HAND_SLOT_SCENE: PackedScene = preload("res://scenes/ui/hud_hand_slot.tscn")
const HAND_ITEM_SELECTOR_SCENE: PackedScene = preload("res://scenes/ui/hud_hand_item_selector.tscn")

var player: Player = null
var world_context: WorldContext = null
var mission_manager: MissionManagerService = null
var entity_manager: WorldEntityManager = null
var supabase_client: GarliaSupabaseClient = null
var world_data: WorldDataService = null
var game_state: GameStateService = null
var _inventory_ref: GarliaInventory = null
var _hand_selector: PanelContainer = null
var _hand_selector_grid: Control = null
var _hand_selector_buttons: Array[Button] = []
var _hand_selector_activo: String = ""
var _left_hand_display: Button = null
var _right_hand_display: Button = null
var _world_atmosphere_ref: WorldAtmosphere = null
var _calendar_panel: PanelContainer = null
var _calendar_label: Label = null
var _calendar_elapsed: float = 0.0
var _eterium_ui_elapsed: float = 0.0

var mostrar_contexto_mundo: bool = false

var _tiempo_contexto: float = 0.0
var _combate_garumi_activo: bool = false
var _ultima_tile_contexto: Vector2i = Vector2i(2147483647, 2147483647)

var location_panel: Control = null
var location_label: Label = null

var health_bar: ProgressBar = null
var health_value: Label = null

var stamina_bar: ProgressBar = null
var stamina_value: Label = null
var _stamina_pips: Array[Panel] = []

var eterium_bar: ProgressBar = null
var eterium_value: Label = null

var interaction_prompt: PanelContainer = null
var interaction_prompt_action: Label = null
var interaction_panel: PanelContainer = null
var interaction_title: Label = null
var interaction_body: Label = null
var interaction_close: Button = null
var _interaction_panel_open: bool = false

var mission_panel: PanelContainer = null
var mission_list: VBoxContainer = null
var mission_hint: Label = null
var _mission_panel_open: bool = false

var discovery_notice: Label = null
var _discovery_notice_timer: float = 0.0
var _garumis_vinculados_ids: Dictionary = {}
var _garumis_vinculados_nodos: Array[Node] = []
var _garumi_companero_actual: Node = null
var _garumi_companero_slot: Button = null
var _garumi_selector_panel: PanelContainer = null
var _garumi_selector_lista: HBoxContainer = null
var _r_hold_activo := false
var _r_hold_elapsed := 0.0
var _r_selector_abierto := false
const R_HOLD_DELAY := 0.24
var _dialogo_ruptura_vinculo: ConfirmationDialog = null

@onready var _health_bar_node: ProgressBar = $HealthBar
@onready var _health_value_node: Label = $BottomLeft/HealthValue
@onready var _stamina_bar_node: ProgressBar = $StaminaBar
@onready var _stamina_value_node: Label = $StaminaValue
@onready var _eterium_bar_node: ProgressBar = $EteriumBar
@onready var _eterium_value_node: Label = $BottomRight/EteriumValue
@onready var _interaction_prompt_node: PanelContainer = $InteractionPrompt
@onready var _interaction_prompt_action_node: Label = $InteractionPrompt/Margin/Content/Action
@onready var _location_panel_node: Panel = $LocationPanel
@onready var _location_label_node: Label = $LocationPanel/Scroll/LocationLabel


func configurar(nuevo_player: Player = null, nuevo_world_context: WorldContext = null, nuevo_mission_manager: MissionManagerService = null, nuevo_entity_manager: WorldEntityManager = null, nuevo_supabase_client: GarliaSupabaseClient = null, nuevo_inventory: GarliaInventory = null, nuevo_world_data: WorldDataService = null, nuevo_game_state: GameStateService = null) -> void:
	if nuevo_player != null and is_instance_valid(nuevo_player):
		if is_instance_valid(player) and player != nuevo_player:
			_desconectar_senales_player()
		player = nuevo_player
		if is_instance_valid(_garumi_companero_actual):
			for garumi_vinculado in _garumis_vinculados_nodos:
				if is_instance_valid(garumi_vinculado) and garumi_vinculado.has_method("establecer_estado_companero"):
					var es_companero := garumi_vinculado == _garumi_companero_actual
					var estaba_guardado := bool(garumi_vinculado.call("esta_guardado")) if garumi_vinculado.has_method("esta_guardado") else false
					garumi_vinculado.call("establecer_estado_companero", player, es_companero and not estaba_guardado)
	if nuevo_world_context != null and is_instance_valid(nuevo_world_context):
		world_context = nuevo_world_context
	if nuevo_mission_manager != null and is_instance_valid(nuevo_mission_manager):
		mission_manager = nuevo_mission_manager
	if nuevo_entity_manager != null and is_instance_valid(nuevo_entity_manager):
		entity_manager = nuevo_entity_manager
	if nuevo_supabase_client != null and is_instance_valid(nuevo_supabase_client):
		supabase_client = nuevo_supabase_client
	world_data = nuevo_world_data
	if nuevo_game_state != null and is_instance_valid(nuevo_game_state):
		if is_instance_valid(game_state) and game_state != nuevo_game_state:
			_desconectar_senal_game_state()
		game_state = nuevo_game_state
		_conectar_senal_game_state()
	if nuevo_inventory != null and is_instance_valid(nuevo_inventory):
		if is_instance_valid(_inventory_ref):
			if _inventory_ref.hand_item_changed.is_connected(_actualizar_huecos_manos):
				_inventory_ref.hand_item_changed.disconnect(_actualizar_huecos_manos)
			if _inventory_ref.inventory_changed.is_connected(_al_cambiar_inventario_manos):
				_inventory_ref.inventory_changed.disconnect(_al_cambiar_inventario_manos)
		_inventory_ref = nuevo_inventory
		if not _inventory_ref.hand_item_changed.is_connected(_actualizar_huecos_manos):
			_inventory_ref.hand_item_changed.connect(_actualizar_huecos_manos)
		if not _inventory_ref.inventory_changed.is_connected(_al_cambiar_inventario_manos):
			_inventory_ref.inventory_changed.connect(_al_cambiar_inventario_manos)
		_actualizar_huecos_manos("", 0, {})
	if mission_manager != null:
		_conectar_senales_misiones()
	if is_inside_tree():
		_conectar_senales_player()
		_actualizar_vida()
		_actualizar_stamina()
		_actualizar_eterium()

func _desconectar_senales_player() -> void:
	if not is_instance_valid(player):
		return
	if player.health_changed.is_connected(_al_recibir_cambio_vida):
		player.health_changed.disconnect(_al_recibir_cambio_vida)
	if player.stamina_changed.is_connected(_al_recibir_cambio_stamina):
		player.stamina_changed.disconnect(_al_recibir_cambio_stamina)
	if player.mana_changed.is_connected(_al_recibir_cambio_mana):
		player.mana_changed.disconnect(_al_recibir_cambio_mana)

func _ready() -> void:
	add_to_group("hud")

	_configurar_referencias_ui()
	PIXEL_UI_THEME.apply(self)
	_crear_selector_manos()
	_crear_huecos_manos()
	_preparar_location()
	_preparar_aviso_descubrimiento()
	_preparar_panel_garumis_vinculados()
	_preparar_panel_interaccion()
	_preparar_panel_misiones()
	_preparar_reloj_calendario()
	_conectar_senales_misiones()

	if location_panel:
		location_panel.visible = false

	if interaction_prompt:
		interaction_prompt.visible = false


	_conectar_senal_game_state()

	print("HUD: iniciado.")

func _desconectar_senal_game_state() -> void:
	if not is_instance_valid(game_state):
		return
	if game_state.has_signal("descubrimiento_mundo") and game_state.descubrimiento_mundo.is_connected(_al_descubrimiento_mundo):
		game_state.descubrimiento_mundo.disconnect(_al_descubrimiento_mundo)


func _conectar_senal_game_state() -> void:
	if not is_instance_valid(game_state):
		return
	if game_state.has_signal("descubrimiento_mundo") and not game_state.descubrimiento_mundo.is_connected(_al_descubrimiento_mundo):
		game_state.descubrimiento_mundo.connect(_al_descubrimiento_mundo)


func _process(delta: float) -> void:
	_procesar_hold_companero(delta)
	_eterium_ui_elapsed += delta
	if _eterium_ui_elapsed >= 0.1:
		_eterium_ui_elapsed = 0.0
		# Consultar las fuentes de verdad evita que el HUD dependa de una señal
		# perdida durante la inicialización o de una propiedad pública desfasada.
		_actualizar_stamina()
		_actualizar_eterium()
	if mostrar_contexto_mundo and not _interaction_panel_open and not _mission_panel_open:
		_tiempo_contexto += delta
		if _tiempo_contexto >= 0.25:
			_tiempo_contexto = 0.0
			_actualizar_contexto()
	else:
		_tiempo_contexto = 0.0

	# El calendario pertenece al HUD, pero nunca debe tapar ventanas modales.
	var inventario_abierto := false
	for nodo in get_tree().get_nodes_in_group("inventory"):
		if nodo is CanvasItem and (nodo as CanvasItem).visible:
			inventario_abierto = true
			break
	if is_instance_valid(_calendar_panel):
		_calendar_panel.visible = not inventario_abierto and not _combate_garumi_activo
	_calendar_elapsed += delta
	if _calendar_elapsed >= 0.2:
		_calendar_elapsed = 0.0
		_actualizar_reloj_calendario()

	if discovery_notice != null and discovery_notice.visible:
		_discovery_notice_timer -= delta
		if _discovery_notice_timer <= 0.0:
			discovery_notice.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		if _procesar_tecla_garumis(key_event):
			get_viewport().set_input_as_handled()
			return

		if key_event.keycode == KEY_F3:
			mostrar_contexto_mundo = not mostrar_contexto_mundo

			if location_panel:
				location_panel.visible = mostrar_contexto_mundo
				if mostrar_contexto_mundo:
					location_panel.move_to_front()

			if mostrar_contexto_mundo:
				_actualizar_contexto()

			get_viewport().set_input_as_handled()


func _preparar_puntos_dash() -> void:
	if not is_instance_valid(_stamina_bar_node):
		return
	_stamina_bar_node.visible = false
	_stamina_value_node.visible = false

	var contenedor := DASH_CHARGES_SCENE.instantiate() as HBoxContainer
	if contenedor == null:
		push_error("HUD: no se pudo instanciar hud_dash_charges.tscn.")
		return
	contenedor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	contenedor.anchor_left = 0.5
	contenedor.anchor_right = 0.5
	contenedor.anchor_top = 1.0
	contenedor.anchor_bottom = 1.0
	contenedor.offset_left = -42.0
	contenedor.offset_right = 42.0
	contenedor.offset_top = -30.0
	contenedor.offset_bottom = -12.0
	contenedor.size = Vector2(84.0, 18.0)
	add_child(contenedor)

	_stamina_pips.clear()
	for i in range(5):
		var pip := contenedor.get_node_or_null("DashCharge" + str(i + 1)) as Panel
		if pip != null:
			_stamina_pips.append(pip)
	_actualizar_puntos_dash(5.0, 5.0)


func _actualizar_puntos_dash(actual: float, maximo: float) -> void:
	for i in range(_stamina_pips.size()):
		var pip := _stamina_pips[i]
		var activo := float(i) < actual
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.78, 0.66, 0.46, 1.0) if activo else Color(0.075, 0.05, 0.035, 0.95)
		estilo.border_width_left = 2
		estilo.border_width_top = 2
		estilo.border_width_right = 2
		estilo.border_width_bottom = 2
		estilo.border_color = Color(0.93, 0.84, 0.65, 1.0) if activo else Color(0.29, 0.19, 0.12, 1.0)
		estilo.corner_radius_top_left = 7
		estilo.corner_radius_top_right = 7
		estilo.corner_radius_bottom_left = 7
		estilo.corner_radius_bottom_right = 7
		pip.add_theme_stylebox_override("panel", estilo)

func _configurar_referencias_ui() -> void:
	_preparar_puntos_dash()
	health_bar = _health_bar_node
	health_value = _health_value_node
	stamina_bar = _stamina_bar_node
	stamina_value = _stamina_value_node
	eterium_bar = _eterium_bar_node
	eterium_value = _eterium_value_node
	interaction_prompt = _interaction_prompt_node
	interaction_prompt_action = _interaction_prompt_action_node
	location_panel = _location_panel_node
	location_label = _location_label_node


func _preparar_aviso_descubrimiento() -> void:
	discovery_notice = DISCOVERY_NOTICE_SCENE.instantiate() as Label
	if discovery_notice == null:
		push_error("HUD: no se pudo instanciar hud_discovery_notice.tscn.")
		return
	add_child(discovery_notice)


func _al_descubrimiento_mundo(nivel: String, id: String) -> void:
	if discovery_notice == null:
		return

	var texto := id if not id.is_empty() else "Nuevo descubrimiento"

	discovery_notice.text = texto
	discovery_notice.visible = true
	_discovery_notice_timer = 4.0


func _preparar_location() -> void:
	if location_panel == null:
		push_error("HUD: falta LocationPanel en hud.tscn.")
		return
	if location_label == null:
		push_error("HUD: falta LocationLabel en hud.tscn.")
		return

	# El panel de diagnóstico vive en una capa propia para quedar por encima
	# del mundo, el HUD y las interfaces habituales.
	var capa_contexto := CanvasLayer.new()
	capa_contexto.name = "WorldContextLayer"
	capa_contexto.layer = 300
	add_child(capa_contexto)
	location_panel.reparent(capa_contexto, false)
	location_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	location_panel.position = Vector2(16.0, 16.0)
	var viewport_size := get_viewport_rect().size
	location_panel.size = Vector2(
		minf(560.0, maxf(280.0, viewport_size.x - 32.0)),
		minf(760.0, maxf(220.0, viewport_size.y - 32.0))
	)
	location_panel.z_index = 0
	location_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	PIXEL_UI_THEME.apply(location_panel, false)

func _buscar_primer_label(nodo: Node) -> Label:
	for child in nodo.get_children():
		if child is Label:
			return child as Label

		var encontrado := _buscar_primer_label(child)

		if encontrado != null:
			return encontrado

	return null


func _conectar_senales_player() -> void:
	if not is_instance_valid(player):
		return

	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_al_recibir_cambio_vida):
			player.health_changed.connect(_al_recibir_cambio_vida)

	if player.has_signal("stamina_changed"):
		if not player.stamina_changed.is_connected(_al_recibir_cambio_stamina):
			player.stamina_changed.connect(_al_recibir_cambio_stamina)

	if player.has_signal("mana_changed"):
		if not player.mana_changed.is_connected(_al_recibir_cambio_mana):
			player.mana_changed.connect(_al_recibir_cambio_mana)


func _al_recibir_cambio_vida(actual: int, maximo: int) -> void:
	_actualizar_barra(
		health_bar,
		health_value,
		actual,
		maximo
	)


func _al_recibir_cambio_stamina(actual: float, maximo: float) -> void:
	_actualizar_puntos_dash(actual, maximo)


func _al_recibir_cambio_mana(actual: int, maximo: int) -> void:
	_actualizar_barra(
		eterium_bar,
		eterium_value,
		actual,
		maximo
	)


func _actualizar_vida() -> void:
	var vida_actual := _obtener_entero(
		player,
		"health",
		0
	)

	var vida_maxima := _obtener_entero(
		player,
		"max_health",
		100
	)

	_actualizar_barra(
		health_bar,
		health_value,
		vida_actual,
		vida_maxima
	)


func _actualizar_stamina() -> void:
	var stamina_actual := _obtener_float(
		player,
		"stamina",
		0.0
	)
	var stamina_maxima := _obtener_float(
		player,
		"max_stamina",
		5.0
	)

	# PlayerStaminaController es la fuente de verdad de las cargas de dash.
	var controlador: Variant = player.get("stamina_controller") if is_instance_valid(player) else null
	if controlador != null:
		var actual_controlador: Variant = controlador.get("current")
		var maximo_controlador: Variant = controlador.get("maximum")
		if actual_controlador != null:
			stamina_actual = float(actual_controlador)
		if maximo_controlador != null:
			stamina_maxima = float(maximo_controlador)

	_actualizar_puntos_dash(stamina_actual, stamina_maxima)


func _actualizar_eterium() -> void:
	var eterium_actual := _obtener_float(
		player,
		"mana",
		0.0
	)
	var eterium_maximo := _obtener_float(
		player,
		"max_mana",
		100.0
	)

	# El runtime opera directamente sobre VitalState; leerlo evita mostrar una
	# copia antigua de Player.mana entre dos sincronizaciones.
	var runtime: Variant = player.get("eterium_runtime") if is_instance_valid(player) else null
	if runtime != null and runtime.has_method("mana") and runtime.has_method("max_mana"):
		eterium_actual = float(runtime.call("mana"))
		eterium_maximo = float(runtime.call("max_mana"))

	_actualizar_barra_float(
		eterium_bar,
		eterium_value,
		eterium_actual,
		eterium_maximo
	)


func _actualizar_barra(
	barra: ProgressBar,
	texto: Label,
	actual: int,
	maximo: int
) -> void:
	if barra == null:
		return

	barra.max_value = maximo
	barra.value = actual

	if texto != null:
		var nuevo_texto := str(actual) + " / " + str(maximo)
		if texto.text != nuevo_texto:
			texto.text = nuevo_texto


func _actualizar_barra_float(
	barra: ProgressBar,
	texto: Label,
	actual: float,
	maximo: float
) -> void:
	if barra == null:
		return

	barra.max_value = maximo
	barra.value = actual

	if texto != null:
		var nuevo_texto := str(roundi(actual)) + " / " + str(roundi(maximo))
		if texto.text != nuevo_texto:
			texto.text = nuevo_texto


func _actualizar_contexto() -> void:
	if not mostrar_contexto_mundo:
		if location_panel:
			location_panel.visible = false
		return

	if location_panel:
		location_panel.visible = true

	if location_label == null:
		return

	if not is_instance_valid(player):
		location_label.text = "Sin jugador"
		return

	if not is_instance_valid(world_context):
		location_label.text = "Sin WorldGenerator"
		return

	var tile_actual: Vector2i = world_context.get_tile_at(player.global_position)

	var cambio_de_tile := tile_actual != _ultima_tile_contexto
	_ultima_tile_contexto = tile_actual

	var bioma := "Desconocido"
	var ecosistema := "Desconocido"
	var habitat := "Desconocido"
	if cambio_de_tile:
		var contexto := _obtener_contexto_mundo(player.global_position)
		bioma = _obtener_nombre_contexto(contexto, "bioma")
		ecosistema = _obtener_nombre_contexto(contexto, "ecosistema")
		habitat = _obtener_nombre_contexto(contexto, "habitat")
	else:
		var lineas_actuales: PackedStringArray = location_label.text.split("\n")
		for linea in lineas_actuales:
			if linea.begins_with("Bioma: "):
				bioma = linea.trim_prefix("Bioma: ")
			elif linea.begins_with("Ecosistema: "):
				ecosistema = linea.trim_prefix("Ecosistema: ")
			elif linea.begins_with("Hábitat: "):
				habitat = linea.trim_prefix("Hábitat: ")

	var tile := tile_actual

	var chunk_size: int = maxi(world_context.get_chunk_size_tiles(), 1)
	var chunk := Vector2i(
		floori(float(tile.x) / float(chunk_size)),
		floori(float(tile.y) / float(chunk_size))
	)

	var reinos: Array[Dictionary] = world_context.get_reinos_at_position(player.global_position)

	var nombres_reinos: Array[String] = []
	for reino in reinos:
		var nombre_reino := str(reino.get("nombre", "")).strip_edges()
		if nombre_reino.is_empty():
			nombre_reino = str(reino.get("clave", "")).strip_edges()
		if not nombre_reino.is_empty() and nombre_reino not in nombres_reinos:
			nombres_reinos.append(nombre_reino)

	var reino_texto := "Sin reino"
	if not nombres_reinos.is_empty():
		reino_texto = " · ".join(nombres_reinos)

	var seed := str(world_context.get_map_seed())
	var version := "—"
	if world_data != null:
		var mundo: Dictionary = world_data.mundo
		version = str(mundo.get("version", "—"))
	var supabase_estado := "Connected"
	if supabase_client != null and not supabase_client.esta_conectado():
		supabase_estado = "Offline"

	var fps: int = Engine.get_frames_per_second()
	var frame_ms: float = 1000.0 / float(maxi(fps, 1))
	var process_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	var physics_ms: float = float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var total_draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var static_memory_mb: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	var criaturas := 0
	var props := 0
	if entity_manager != null:
		for entidad in entity_manager.obtener_entidades_activas():
			if entidad is Node and entidad.is_in_group("creatures"):
				criaturas += 1
			elif entidad is Node and entidad.is_in_group("world_props"):
				props += 1
	var entidades := criaturas + props

	var chunks_cargados: int = world_context.get_chunks_cargados().size()

	location_label.text = (
		"RENDIMIENTO\n"
		+ "FPS: " + str(fps) + "    Frame: " + ("%.1f" % frame_ms) + " ms\n"
		+ "Proceso: " + ("%.2f" % process_ms) + " ms    Física: " + ("%.2f" % physics_ms) + " ms\n"
		+ "Draw total: " + str(total_draw_calls) + "    Objetos: " + str(objects) + "    Nodos: " + str(nodes) + "\n"
		+ "Memoria estática: " + ("%.1f" % static_memory_mb) + " MB\n\n"
		+ "MUNDO\n"
		+ "Reino: " + reino_texto + "\n"
		+ "Seed: " + seed + "\n"
		+ "World version: " + version + "\n"
		+ "Supabase: " + supabase_estado + "\n\n"
		+ "UBICACIÓN\n"
		+ "Posición: " + str(tile.x) + ", " + str(tile.y) + "\n"
		+ "Chunk: " + str(chunk.x) + ", " + str(chunk.y) + "\n"
		+ "Bioma: " + bioma + "\n"
		+ "Ecosistema: " + ecosistema + "\n"
		+ "Hábitat: " + habitat + "\n\n"
		+ "ENTIDADES\n"
		+ "Criaturas: " + str(criaturas) + "\n"
		+ "Props: " + str(props) + "\n"
		+ "Entidades: " + str(entidades) + "\n"
		+ "Chunks cargados: " + str(chunks_cargados)
	)

func _formatear_ambiente_efectivo(
	factores: Dictionary
) -> String:
	var partes: Array[String] = []

	var temperatura: Variant = _obtener_valor_factor(
		factores,
		"temperatura_media"
	)
	if temperatura != null:
		partes.append("T: " + _formatear_numero(float(temperatura)))

	var humedad: Variant = _obtener_valor_factor(
		factores,
		"humedad_relativa"
	)
	if humedad != null:
		partes.append(
			"H: " + _formatear_numero(
				float(humedad) * 100.0
			) + "%"
		)

	var agua: Variant = _obtener_valor_factor(
		factores,
		"disponibilidad_agua"
	)
	if agua != null:
		partes.append(
			"Agua: " + _formatear_numero(
				float(agua) * 100.0
			) + "%"
		)

	if partes.is_empty():
		return ""

	return "Ambiente: " + " · ".join(partes)


func _obtener_valor_factor(
	factores: Dictionary,
	clave: String
) -> Variant:
	var factor_variant: Variant = factores.get(
		clave,
		null
	)

	if not factor_variant is Dictionary:
		return null

	var factor: Dictionary = factor_variant as Dictionary

	if not factor.has("valor"):
		return null

	var valor: Variant = factor.get("valor")
	if valor == null:
		return null

	return valor


func _formatear_numero(
	valor: float
) -> String:
	return "%.2f" % valor


func _obtener_tiempo_mundo() -> Dictionary:
	if not is_instance_valid(world_context):
		return {}
	return world_context.obtener_tiempo()

func _obtener_contexto_mundo(posicion: Vector2) -> Dictionary:
	if not is_instance_valid(world_context):
		return {}
	return world_context.get_contexto_at(posicion)


func _obtener_nombre_contexto(
	contexto: Dictionary,
	clave: String
) -> String:
	var valor = contexto.get(clave, null)

	if valor == null:
		valor = contexto.get(
			clave + "_nombre",
			null
		)

	if valor == null:
		return "Desconocido"

	if valor is String:
		return valor

	if valor is Dictionary:
		if valor.has("nombre"):
			return str(valor["nombre"])

		if valor.has("name"):
			return str(valor["name"])

		if valor.has(clave + "_nombre"):
			return str(valor[clave + "_nombre"])

		return "Desconocido"

	if valor is Object:
		var nombre = valor.get("nombre")

		if nombre != null:
			return str(nombre)

		nombre = valor.get("name")

		if nombre != null:
			return str(nombre)

	return str(valor)


func _obtener_entero(
	objeto: Object,
	propiedad: String,
	valor_por_defecto: int
) -> int:
	if not is_instance_valid(objeto):
		return valor_por_defecto

	var valor = objeto.get(propiedad)

	if valor == null:
		return valor_por_defecto

	return int(valor)


func _obtener_float(
	objeto: Object,
	propiedad: String,
	valor_por_defecto: float
) -> float:
	if not is_instance_valid(objeto):
		return valor_por_defecto

	var valor = objeto.get(propiedad)

	if valor == null:
		return valor_por_defecto

	return float(valor)


func mostrar_interaccion(texto: String) -> void:
	if interaction_prompt == null:
		return

	if interaction_prompt_action != null:
		interaction_prompt_action.text = texto
	interaction_prompt.visible = true
	interaction_prompt.z_index = 1000


func ocultar_interaccion() -> void:
	if interaction_prompt == null:
		return

	interaction_prompt.visible = false


func _obtener_mission_manager() -> MissionManagerService:
	return mission_manager


func _conectar_senales_misiones() -> void:
	var manager: MissionManagerService = _obtener_mission_manager()
	if manager == null:
		return

	if not manager.misiones_cargadas.is_connected(_actualizar_panel_misiones):
		manager.misiones_cargadas.connect(_actualizar_panel_misiones)

	if not manager.progreso_actualizado.is_connected(_al_progreso_mision):
		manager.progreso_actualizado.connect(_al_progreso_mision)

	if not manager.mision_completada.is_connected(_al_mision_completada):
		manager.mision_completada.connect(_al_mision_completada)


func _al_progreso_mision(
	_mision_id: String,
	_objetivo_id: String,
	_progreso: int,
	_requerido: int
) -> void:
	if _mission_panel_open:
		_actualizar_panel_misiones()


func _al_mision_completada(_mision: Dictionary) -> void:
	if _mission_panel_open:
		_actualizar_panel_misiones()


func _preparar_panel_misiones() -> void:
	mission_panel = MISSION_PANEL_SCENE.instantiate() as PanelContainer
	if mission_panel == null:
		push_error("HUD: no se pudo instanciar hud_mission_panel.tscn.")
		return

	mission_panel.visible = false
	mission_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mission_panel.z_index = 2500
	mission_panel.set_anchors_preset(Control.PRESET_CENTER)
	mission_panel.position = Vector2(-280.0, -210.0)
	mission_panel.size = Vector2(560.0, 420.0)
	mission_list = mission_panel.get_node("Margin/Column/MissionList") as VBoxContainer
	mission_hint = mission_panel.get_node("Margin/Column/MissionHint") as Label
	add_child(mission_panel)
	PIXEL_UI_THEME.apply(mission_panel)


func _limpiar_lista_misiones() -> void:
	if mission_list == null:
		return

	for child in mission_list.get_children():
		child.queue_free()


func _actualizar_panel_misiones() -> void:
	if mission_list == null:
		return

	_limpiar_lista_misiones()

	var manager := _obtener_mission_manager()
	if manager == null:
		return

	var misiones: Array[Dictionary] = manager.obtener_misiones()
	if misiones.is_empty():
		var vacio := Label.new()
		vacio.text = "No hay misiones registradas."
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vacio.add_theme_color_override("font_color", Color(0.72, 0.64, 0.52, 1.0))
		mission_list.add_child(vacio)
		return

	for mision in misiones:
		var estado_mision: Dictionary = manager.obtener_estado_mision(
			str(mision.get("id", ""))
		)

		var estado := str(estado_mision.get("estado", "disponible"))
		var titulo_texto := str(mision.get("nombre", "Misión"))

		var bloque := VBoxContainer.new()
		bloque.add_theme_constant_override("separation", 3)
		mission_list.add_child(bloque)

		var encabezado := Label.new()
		var indicador := "✓" if estado == "completada" else "○"
		var estado_texto := "COMPLETADA" if estado == "completada" else ("EN CURSO" if estado == "activa" else "NO INICIADA")
		encabezado.text = indicador + "  " + titulo_texto + "  ·  " + estado_texto
		encabezado.add_theme_color_override(
			"font_color",
			Color(0.82, 0.92, 0.68, 1.0) if estado == "completada" else Color(0.9, 0.79, 0.58, 1.0)
		)
		encabezado.add_theme_font_size_override("font_size", 13)
		bloque.add_child(encabezado)

		var descripcion := str(mision.get("descripcion", "")).strip_edges()
		if not descripcion.is_empty():
			var desc_label := Label.new()
			desc_label.text = "   " + descripcion
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_label.add_theme_color_override("font_color", Color(0.70, 0.63, 0.51, 1.0))
			desc_label.add_theme_font_size_override("font_size", 10)
			bloque.add_child(desc_label)

		var objetivos_variant: Variant = estado_mision.get("objetivos", [])
		if objetivos_variant is Array:
			for objetivo_variant in objetivos_variant as Array:
				if not objetivo_variant is Dictionary:
					continue

				var objetivo := objetivo_variant as Dictionary
				var progreso := int(objetivo.get("progreso", 0))
				var requerido := maxi(1, int(objetivo.get("cantidad_requerida", 1)))
				var objetivo_completado := bool(objetivo.get("completado", false))
				var objetivo_indicador := "✓" if objetivo_completado else "•"
				var objetivo_texto := str(objetivo.get("descripcion", "Objetivo"))
				var linea := "   " + objetivo_indicador + " " + objetivo_texto
				linea += "  [" + str(progreso) + "/" + str(requerido) + "]"

				var objetivo_label := Label.new()
				objetivo_label.text = linea
				objetivo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				objetivo_label.add_theme_color_override(
					"font_color",
					Color(0.76, 0.88, 0.65, 1.0) if objetivo_completado else Color(0.78, 0.70, 0.57, 1.0)
				)
				objetivo_label.add_theme_font_size_override("font_size", 11)
				bloque.add_child(objetivo_label)


func mostrar_panel_misiones() -> void:
	if mission_panel == null:
		return

	if _interaction_panel_open:
		cerrar_panel_interaccion()

	_actualizar_panel_misiones()
	mission_panel.visible = true
	_mission_panel_open = true
	get_viewport().set_input_as_handled()


func cerrar_panel_misiones() -> void:
	if mission_panel == null:
		return

	mission_panel.visible = false
	_mission_panel_open = false


func _toggle_panel_misiones() -> void:
	if _mission_panel_open:
		cerrar_panel_misiones()
	else:
		mostrar_panel_misiones()


func esta_mostrando_panel_misiones() -> bool:
	return _mission_panel_open


func _preparar_panel_interaccion() -> void:
	interaction_panel = INTERACTION_PANEL_SCENE.instantiate() as PanelContainer
	if interaction_panel == null:
		push_error("HUD: no se pudo instanciar hud_interaction_panel.tscn.")
		return

	interaction_panel.visible = false
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	interaction_panel.z_index = 2000
	interaction_panel.set_anchors_preset(Control.PRESET_CENTER)
	interaction_panel.position = Vector2(-280.0, -190.0)
	interaction_panel.size = Vector2(560.0, 380.0)
	interaction_title = interaction_panel.get_node("Margin/Column/Title") as Label
	interaction_body = interaction_panel.get_node("Margin/Column/Body") as Label
	interaction_close = interaction_panel.get_node("Margin/Column/Close") as Button
	interaction_close.pressed.connect(cerrar_panel_interaccion)
	add_child(interaction_panel)
	PIXEL_UI_THEME.apply(interaction_panel)


func mostrar_panel_interaccion(datos: Dictionary) -> void:
	if interaction_panel == null:
		return

	var titulo: String = str(
		datos.get(
			"titulo",
			"Interacción"
		)
	)

	var accion: String = str(
		datos.get(
			"accion",
			""
		)
	)

	if not accion.is_empty():
		interaction_title.text = accion + " · " + titulo
	else:
		interaction_title.text = titulo

	var lineas: Array[String] = []

	var bioma: String = str(datos.get("bioma", "")).strip_edges()
	if not bioma.is_empty():
		lineas.append("Bioma: " + bioma)

	var ecosistema: String = str(datos.get("ecosistema", "")).strip_edges()
	if not ecosistema.is_empty():
		lineas.append("Ecosistema: " + ecosistema)

	var habitat: String = str(datos.get("habitat", "")).strip_edges()
	if not habitat.is_empty():
		lineas.append("Hábitat: " + habitat)

	var item_nombre: String = str(datos.get("item_nombre", "")).strip_edges()
	if not item_nombre.is_empty():
		lineas.append("Objeto relacionado: " + item_nombre)

	var descripcion: String = str(datos.get("descripcion", "")).strip_edges()
	if not descripcion.is_empty():
		lineas.append("")
		lineas.append(descripcion)

	if lineas.is_empty():
		lineas.append("No hay información adicional registrada.")

	interaction_body.text = "
".join(lineas)
	interaction_panel.visible = true
	_interaction_panel_open = true

	if interaction_close != null:
		interaction_close.grab_focus()


func cerrar_panel_interaccion() -> void:
	if interaction_panel == null:
		return

	interaction_panel.visible = false
	_interaction_panel_open = false

	if interaction_close != null:
		interaction_close.release_focus()


func esta_mostrando_panel_interaccion() -> bool:
	return _interaction_panel_open or _mission_panel_open


func _crear_huecos_manos() -> void:
	_left_hand_display = _crear_hueco_mano("LeftHandSlot", "Q")
	_right_hand_display = _crear_hueco_mano("RightHandSlot", "E")
	_actualizar_huecos_manos("", 0, {})


func _crear_hueco_mano(nombre: String, tecla: String) -> Button:
	var slot := HAND_SLOT_SCENE.instantiate() as Button
	if slot == null:
		push_error("HUD: no se pudo instanciar hud_hand_slot.tscn.")
		return null
	slot.name = nombre
	slot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	slot.anchor_left = 0.5
	slot.anchor_right = 0.5
	slot.anchor_top = 1.0
	slot.anchor_bottom = 1.0
	slot.offset_top = -48.0
	slot.offset_bottom = 0.0
	slot.offset_left = -134.0 if tecla == "Q" else 86.0
	slot.offset_right = -86.0 if tecla == "Q" else 134.0
	PIXEL_UI_THEME.apply(slot)
	slot.tooltip_text = "Mano " + ("izquierda" if tecla == "Q" else "derecha") + " (" + tecla + ")"
	var etiqueta_tecla := slot.get_node_or_null("HandKey") as Label
	if etiqueta_tecla != null:
		etiqueta_tecla.text = tecla
	if OS.has_feature("android"):
		slot.pressed.connect(func() -> void:
			if not _interaction_panel_open and not _mission_panel_open and (_inventory_ref == null or not _inventory_ref.esta_abierto()):
				var mano := "izquierda" if tecla == "Q" else "derecha"
				if _hand_selector_activo == mano:
					_hand_selector_activo = ""
					_hand_selector.visible = false
				else:
					_abrir_selector_mano(mano)
		)
	add_child(slot)
	return slot


func _al_cambiar_inventario_manos() -> void:
	_actualizar_huecos_manos("", 0, {})


func _actualizar_huecos_manos(_mano: String, _slot_index: int, _datos: Dictionary) -> void:
	if not is_instance_valid(_inventory_ref):
		return
	_actualizar_hueco_mano(_left_hand_display, "izquierda")
	_actualizar_hueco_mano(_right_hand_display, "derecha")


func _actualizar_hueco_mano(slot: Button, mano: String) -> void:
	if not is_instance_valid(slot) or not is_instance_valid(_inventory_ref):
		return
	var datos: Dictionary = _inventory_ref.obtener_objeto_mano_activa(mano)
	slot.icon = ItemIconResolver.obtener_icono(datos) if not datos.is_empty() else null
	slot.text = "" if not datos.is_empty() else "—"
	slot.tooltip_text = ("Mano izquierda (Q): " if mano == "izquierda" else "Mano derecha (E): ") + str(datos.get("nombre", "Vacía"))


func _crear_selector_manos() -> void:
	_hand_selector = HAND_ITEM_SELECTOR_SCENE.instantiate() as PanelContainer
	if _hand_selector == null:
		push_error("HUD: no se pudo instanciar hud_hand_item_selector.tscn.")
		return
	PIXEL_UI_THEME.apply(_hand_selector)
	_hand_selector_grid = _hand_selector.get_node_or_null("Buttons") as VBoxContainer
	if _hand_selector_grid == null:
		push_error("HUD: falta Buttons en hud_hand_item_selector.tscn.")
		return
	_hand_selector_buttons.clear()
	for i in range(6):
		var button := _hand_selector_grid.get_node_or_null("Slot%d" % (i + 1)) as Button
		if button == null:
			push_error("HUD: falta Slot%d en el selector de manos." % (i + 1))
			continue
		button.pressed.connect(_al_pulsar_selector_mano.bind(i))
		_hand_selector_buttons.append(button)
	add_child(_hand_selector)


func _abrir_selector_mano(mano: String) -> void:
	if _inventory_ref == null or not is_instance_valid(_inventory_ref):
		return
	_hand_selector_activo = mano
	var boton_mano := _left_hand_display if mano == "izquierda" else _right_hand_display
	if not is_instance_valid(boton_mano):
		return

	for i in range(6):
		var indice := i if mano == "izquierda" else 12 + i
		var datos := _inventory_ref.obtener_objeto(indice)
		var button := _hand_selector_buttons[i]
		# El icono identifica las ranuras ocupadas; el número solo se muestra
		# en espacios vacíos para evitar superponer texto sobre los objetos.
		button.text = "" if not datos.is_empty() else str(i + 1)
		button.icon = ItemIconResolver.obtener_icono(datos) if not datos.is_empty() else null
		button.tooltip_text = str(i + 1) + " · " + str(datos.get("nombre", "Vacío")) if not datos.is_empty() else str(i + 1) + " · Vacío"

	# Posición local respecto al HUD: justo encima del botón que abrió el selector.
	_hand_selector.size = Vector2(42, 0)
	_hand_selector.reset_size()
	_hand_selector.size = Vector2(42, _hand_selector.get_combined_minimum_size().y)
	var rect := boton_mano.get_global_rect()
	var hud_rect := get_global_rect()
	var x := rect.position.x + (rect.size.x - _hand_selector.size.x) * 0.5 - hud_rect.position.x
	var y := rect.position.y - _hand_selector.size.y - 6.0 - hud_rect.position.y
	_hand_selector.position = Vector2(
		clampf(x, 4.0, maxf(4.0, size.x - _hand_selector.size.x - 4.0)),
		clampf(y, 4.0, maxf(4.0, size.y - _hand_selector.size.y - 4.0))
	)
	_hand_selector.visible = true
	_hand_selector.move_to_front()


func _confirmar_selector_mano(posicion: Vector2) -> void:
	var mano := _hand_selector_activo
	_hand_selector_activo = ""
	_hand_selector.visible = false
	if mano.is_empty() or _inventory_ref == null:
		return
	for i in range(_hand_selector_buttons.size()):
		if _hand_selector_buttons[i].get_global_rect().has_point(posicion):
			_inventory_ref.seleccionar_slot_mano(mano, i)
			return


func _al_pulsar_selector_mano(indice: int) -> void:
	if _hand_selector_activo.is_empty() or _inventory_ref == null:
		return
	_inventory_ref.seleccionar_slot_mano(_hand_selector_activo, indice)
	_hand_selector_activo = ""
	_hand_selector.visible = false


func accion_controles_moviles(accion: String) -> void:
	match accion:
		"abrir_selector_q":
			_abrir_selector_mano("izquierda")
		"abrir_selector_e":
			_abrir_selector_mano("derecha")
		"toggle_inventory":
			var inventory_node := get_tree().get_first_node_in_group("inventory")
			if inventory_node != null and inventory_node.has_method("toggle"):
				inventory_node.call_deferred("toggle")


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var hand_key := event as InputEventKey
		if hand_key.keycode == KEY_R:
			if hand_key.pressed and not hand_key.echo:
				if not _combate_garumi_activo and not _interaction_panel_open and not _mission_panel_open and (_inventory_ref == null or not _inventory_ref.esta_abierto()):
					_r_hold_activo = true
					_r_hold_elapsed = 0.0
					get_viewport().set_input_as_handled()
					return
			elif not hand_key.pressed and _r_hold_activo:
				_r_hold_activo = false
				if not _r_selector_abierto:
					_alternar_companero_actual()
				get_viewport().set_input_as_handled()
				return
		# Capturar Tab en _input para evitar que otro control consuma la entrada.
		if hand_key.pressed and not hand_key.echo and hand_key.keycode == KEY_M and not hand_key.shift_pressed:
			var inventory_node := get_tree().get_first_node_in_group("inventory")
			if inventory_node != null and inventory_node.has_method("toggle_mapa"):
				inventory_node.call("toggle_mapa")
				get_viewport().set_input_as_handled()
				return
		if hand_key.pressed and not hand_key.echo and hand_key.keycode == KEY_TAB:
			var inventory_node := get_tree().get_first_node_in_group("inventory")
			if inventory_node != null and inventory_node.has_method("toggle"):
				inventory_node.call("toggle")
				get_viewport().set_input_as_handled()
				return
		# Mientras el selector de mano está abierto, 1–6 elige un objeto.
		if hand_key.pressed and not hand_key.echo and not _hand_selector_activo.is_empty() and hand_key.keycode >= KEY_1 and hand_key.keycode <= KEY_6:
			var indice_mano := hand_key.keycode - KEY_1
			if is_instance_valid(_inventory_ref):
				_inventory_ref.seleccionar_slot_mano(_hand_selector_activo, indice_mano)
			_hand_selector_activo = ""
			_hand_selector.visible = false
			get_viewport().set_input_as_handled()
			return
		if hand_key.keycode == KEY_Q or hand_key.keycode == KEY_E:
			if hand_key.pressed and not hand_key.echo:
				if not _interaction_panel_open and not _mission_panel_open and (_inventory_ref == null or not _inventory_ref.esta_abierto()):
					var mano_solicitada := "izquierda" if hand_key.keycode == KEY_Q else "derecha"
					if _hand_selector_activo == mano_solicitada:
						_hand_selector_activo = ""
						_hand_selector.visible = false
					else:
						_abrir_selector_mano(mano_solicitada)
				get_viewport().set_input_as_handled()
				return
		if hand_key.pressed and not hand_key.echo:
			if hand_key.keycode == KEY_F:
				_toggle_panel_misiones()
				get_viewport().set_input_as_handled()
				return

			if hand_key.keycode == KEY_ESCAPE and _mission_panel_open:
				cerrar_panel_misiones()
				get_viewport().set_input_as_handled()
				return

	if not _hand_selector_activo.is_empty() and event is InputEventMouseButton:
		var click_selector := event as InputEventMouseButton
		if click_selector.pressed and click_selector.button_index == MOUSE_BUTTON_LEFT:
			var dentro_de_opcion := false
			for boton_selector in _hand_selector_buttons:
				if boton_selector.get_global_rect().has_point(click_selector.position):
					dentro_de_opcion = true
					break
			if not dentro_de_opcion:
				_hand_selector_activo = ""
				_hand_selector.visible = false
				get_viewport().set_input_as_handled()
				return

	if not _interaction_panel_open:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_ESCAPE:
			cerrar_panel_interaccion()
			get_viewport().set_input_as_handled()


func configurar_reloj_calendario(atmosfera: WorldAtmosphere) -> void:
	_world_atmosphere_ref = atmosfera
	_actualizar_reloj_calendario()


func _preparar_reloj_calendario() -> void:
	_calendar_panel = CALENDAR_CLOCK_SCENE.instantiate() as PanelContainer
	if _calendar_panel == null:
		push_error("HUD: no se pudo instanciar hud_calendar_clock.tscn.")
		return
	_calendar_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_calendar_panel.anchor_left = 1.0
	_calendar_panel.anchor_right = 1.0
	_calendar_panel.anchor_top = 0.0
	_calendar_panel.anchor_bottom = 0.0
	_calendar_panel.offset_left = -174.0
	_calendar_panel.offset_top = 12.0
	_calendar_panel.offset_right = -12.0
	_calendar_panel.offset_bottom = 82.0
	_calendar_label = _calendar_panel.get_node("CalendarText") as Label
	add_child(_calendar_panel)
	PIXEL_UI_THEME.apply(_calendar_panel)


func _actualizar_reloj_calendario() -> void:
	if not is_instance_valid(_calendar_label):
		return
	# En reinos fijos no existe WorldAtmosphere. Conservamos la última
	# lectura válida en vez de reemplazar el reloj por "no disponible".
	if not is_instance_valid(_world_atmosphere_ref):
		return
	var tiempo: Dictionary = _world_atmosphere_ref.obtener_tiempo()
	if not bool(tiempo.get("calendario_cargado", false)):
		_calendar_label.text = "GARLIA\nCargando calendario…"
		return
	var hora := str(tiempo.get("hora", "--:--"))
	var periodo := str(tiempo.get("periodo", ""))
	var estacion := str(tiempo.get("estacion", "—"))
	var dia_estacion := int(tiempo.get("dia_de_estacion", 0))
	var anio := int(tiempo.get("anio", 0))
	var fecha := "Día %d · %s" % [dia_estacion, estacion] if dia_estacion > 0 else estacion
	_calendar_label.text = "%s   %s\n%s · Año %d" % [hora, periodo, fecha, anio]



func _preparar_panel_garumis_vinculados() -> void:
	# Un único botón cuadrado, reutilizando exactamente la escena visual de Q/E.
	_garumi_companero_slot = HAND_SLOT_SCENE.instantiate() as Button
	if not is_instance_valid(_garumi_companero_slot):
		push_error("HUD: no se pudo crear el botón de compañero R.")
		return
	_garumi_companero_slot.name = "GarumiCompanionSlot"
	_garumi_companero_slot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_garumi_companero_slot.anchor_left = 0.5
	_garumi_companero_slot.anchor_right = 0.5
	_garumi_companero_slot.anchor_top = 1.0
	_garumi_companero_slot.anchor_bottom = 1.0
	_garumi_companero_slot.offset_top = -48.0
	_garumi_companero_slot.offset_bottom = 0.0
	_garumi_companero_slot.offset_left = -24.0
	_garumi_companero_slot.offset_right = 24.0
	PIXEL_UI_THEME.apply(_garumi_companero_slot)
	_garumi_companero_slot.tooltip_text = "Compañero (R): guardar o liberar · mantener R para elegir"
	var etiqueta := _garumi_companero_slot.get_node_or_null("HandKey") as Label
	if is_instance_valid(etiqueta):
		etiqueta.text = "R"
	_garumi_companero_slot.pressed.connect(_alternar_companero_actual)
	add_child(_garumi_companero_slot)

	_garumi_selector_panel = PanelContainer.new()
	_garumi_selector_panel.name = "GarumiCompanionSelector"
	_garumi_selector_panel.visible = false
	_garumi_selector_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_garumi_selector_panel.anchor_left = 0.5
	_garumi_selector_panel.anchor_right = 0.5
	_garumi_selector_panel.anchor_top = 1.0
	_garumi_selector_panel.anchor_bottom = 1.0
	_garumi_selector_panel.offset_left = -91.0
	_garumi_selector_panel.offset_right = 91.0
	_garumi_selector_panel.offset_top = -108.0
	_garumi_selector_panel.offset_bottom = -54.0
	PIXEL_UI_THEME.apply(_garumi_selector_panel, false)
	_garumi_selector_lista = HBoxContainer.new()
	_garumi_selector_lista.alignment = BoxContainer.ALIGNMENT_CENTER
	_garumi_selector_lista.add_theme_constant_override("separation", 5)
	_garumi_selector_panel.add_child(_garumi_selector_lista)
	add_child(_garumi_selector_panel)


func mostrar_panel_garumis_durante_combate(_mostrar: bool) -> void:
	# Se conserva la API para el sistema de combate, pero el HUD ya no dibuja círculos.
	pass


func mostrar_resultado_vinculo(garumi: Node, exito: bool, tipo: String = "") -> void:
	if discovery_notice == null:
		return
	var nombre := "Garumi"
	if is_instance_valid(garumi):
		nombre = str(garumi.get("criatura_nombre"))
		if nombre.strip_edges().is_empty() or nombre == "<null>":
			nombre = garumi.name
	if exito:
		var detalle := "vínculo establecido"
		if tipo == "forzado":
			detalle = "vínculo establecido tras el enfrentamiento"
		discovery_notice.text = nombre + ": " + detalle
		_agregar_garumi_vinculado(garumi, nombre)
	else:
		discovery_notice.text = nombre + " rechazó la propuesta de vínculo."
	discovery_notice.visible = true
	_discovery_notice_timer = 3.8


func registrar_garumi_restaurado(garumi: Node) -> void:
	if not is_instance_valid(garumi):
		return
	var nombre := str(garumi.get("criatura_nombre"))
	if nombre.strip_edges().is_empty() or nombre == "<null>":
		nombre = garumi.name
	_agregar_garumi_vinculado(garumi, nombre)


func _agregar_garumi_vinculado(garumi: Node, _nombre: String) -> void:
	if not is_instance_valid(garumi):
		return
	var id := str(garumi.get_instance_id())
	if _garumis_vinculados_ids.has(id):
		_actualizar_selector_companero()
		return
	if _garumis_vinculados_nodos.size() >= 3:
		return
	_garumis_vinculados_ids[id] = true
	_garumis_vinculados_nodos.append(garumi)
	if not is_instance_valid(_garumi_companero_actual):
		_establecer_companero(garumi)
	else:
		if garumi.has_method("establecer_estado_companero"):
			garumi.call("establecer_estado_companero", player, false)
	_actualizar_selector_companero()


func _procesar_hold_companero(delta: float) -> void:
	if not _r_hold_activo or _r_selector_abierto:
		return
	_r_hold_elapsed += delta
	if _r_hold_elapsed >= R_HOLD_DELAY:
		_abrir_selector_companero()


func _abrir_selector_companero() -> void:
	if _combate_garumi_activo or not is_instance_valid(_garumi_selector_panel):
		return
	_r_selector_abierto = true
	for hijo in _garumi_selector_lista.get_children():
		hijo.queue_free()
	for i in range(_garumis_vinculados_nodos.size()):
		var garumi := _garumis_vinculados_nodos[i]
		if not is_instance_valid(garumi):
			continue
		var boton := HAND_SLOT_SCENE.instantiate() as Button
		if boton == null:
			continue
		boton.name = "ElegirGarumi%d" % (i + 1)
		boton.custom_minimum_size = Vector2(42, 42)
		boton.text = ""
		boton.tooltip_text = "%d · %s" % [i + 1, str(garumi.get("criatura_nombre"))]
		var tecla := boton.get_node_or_null("HandKey") as Label
		if is_instance_valid(tecla):
			tecla.text = str(i + 1)
		var textura := _buscar_textura_garumi(garumi)
		if textura != null:
			boton.icon = textura
		boton.pressed.connect(_seleccionar_companero.bind(garumi))
		_garumi_selector_lista.add_child(boton)
	_garumi_selector_panel.visible = not _garumis_vinculados_nodos.is_empty()
	_garumi_selector_panel.move_to_front()


func _cerrar_selector_companero() -> void:
	_r_selector_abierto = false
	if is_instance_valid(_garumi_selector_panel):
		_garumi_selector_panel.visible = false


func _seleccionar_companero(garumi: Node) -> void:
	if not is_instance_valid(garumi):
		return
	_establecer_companero(garumi)
	_cerrar_selector_companero()


func _establecer_companero(garumi: Node) -> void:
	if not is_instance_valid(garumi) or not _garumis_vinculados_nodos.has(garumi):
		return
	if is_instance_valid(_garumi_companero_actual) and _garumi_companero_actual != garumi:
		if _garumi_companero_actual.has_method("establecer_estado_companero"):
			_garumi_companero_actual.call("establecer_estado_companero", player, false)
	_garumi_companero_actual = garumi
	if is_instance_valid(player) and garumi.has_method("establecer_estado_companero"):
		garumi.call("establecer_estado_companero", player, true)
	_actualizar_selector_companero()


func _alternar_companero_actual() -> void:
	if not is_instance_valid(_garumi_companero_actual) or not is_instance_valid(player):
		if not _garumis_vinculados_nodos.is_empty():
			_establecer_companero(_garumis_vinculados_nodos[0])
		return
	var guardado := bool(_garumi_companero_actual.call("esta_guardado")) if _garumi_companero_actual.has_method("esta_guardado") else false
	if _garumi_companero_actual.has_method("establecer_estado_companero"):
		_garumi_companero_actual.call("establecer_estado_companero", player, guardado)
	_actualizar_selector_companero()


func _actualizar_selector_companero() -> void:
	if not is_instance_valid(_garumi_companero_slot):
		return
	var retrato := _buscar_textura_garumi(_garumi_companero_actual) if is_instance_valid(_garumi_companero_actual) else null
	_garumi_companero_slot.icon = retrato
	_garumi_companero_slot.text = "" if retrato != null else "—"
	if is_instance_valid(_garumi_companero_actual):
		var guardado := bool(_garumi_companero_actual.call("esta_guardado")) if _garumi_companero_actual.has_method("esta_guardado") else false
		_garumi_companero_slot.tooltip_text = "%s · %s (R)" % [str(_garumi_companero_actual.get("criatura_nombre")), "guardado" if guardado else "acompañándote"]
	else:
		_garumi_companero_slot.tooltip_text = "Sin compañero · mantener R para elegir"


func _buscar_textura_garumi(nodo: Node) -> Texture2D:
	if not is_instance_valid(nodo):
		return null
	if nodo is Sprite2D and (nodo as Sprite2D).texture != null:
		return (nodo as Sprite2D).texture
	if nodo is AnimatedSprite2D:
		var animado := nodo as AnimatedSprite2D
		if animado.sprite_frames != null and animado.sprite_frames.has_animation(animado.animation):
			var fotograma := animado.sprite_frames.get_frame_texture(animado.animation, animado.frame)
			if fotograma != null:
				return fotograma
	if nodo is TextureRect and (nodo as TextureRect).texture != null:
		return (nodo as TextureRect).texture
	for hijo in nodo.get_children():
		var textura := _buscar_textura_garumi(hijo)
		if textura != null:
			return textura
	return null

func _procesar_tecla_garumis(evento: InputEventKey) -> bool:
	# 1, 2 y 3 quedan reservadas para los tres dones equipados del compañero.
	if _combate_garumi_activo:
		return false
	for nodo_inventario in get_tree().get_nodes_in_group("inventory"):
		if nodo_inventario is CanvasItem and (nodo_inventario as CanvasItem).visible:
			return false
	for modal in get_tree().get_nodes_in_group("modal_ui"):
		if is_instance_valid(modal) and modal.is_inside_tree() and not modal.is_queued_for_deletion():
			return false
	var codigo := evento.keycode
	if codigo >= KEY_KP_1 and codigo <= KEY_KP_3:
		codigo = KEY_1 + (codigo - KEY_KP_1)
	if codigo < KEY_1 or codigo > KEY_3:
		return false
	_usar_don_companero(codigo - KEY_1)
	return true


func _usar_don_companero(indice: int) -> void:
	if not is_instance_valid(_garumi_companero_actual):
		return
	var companero_guardado := bool(_garumi_companero_actual.call("esta_guardado")) if _garumi_companero_actual.has_method("esta_guardado") else false
	if companero_guardado:
		return
	if _garumi_companero_actual.has_method("usar_don_por_slot"):
		_garumi_companero_actual.call("usar_don_por_slot", indice)
	elif is_instance_valid(discovery_notice):
		discovery_notice.text = "Los dones de este Garumi aún no están disponibles."
		discovery_notice.visible = true
		_discovery_notice_timer = 2.0


func _curar_garumi_vinculado_con_eterium(garumi: Node) -> void:
	const COSTO_ETERIUM := 10
	const CURACION := 25

	if not is_instance_valid(player) or not is_instance_valid(garumi):
		return
	if not garumi.has_method("curar_con_eterium"):
		return
	if not bool(garumi.get("is_alive")):
		return

	var vida_actual := int(garumi.get("health"))
	var vida_maxima := maxi(1, int(garumi.get("max_health")))
	if vida_actual >= vida_maxima:
		return
	if int(player.get("mana")) < COSTO_ETERIUM:
		return
	if not player.eterium.gastar(COSTO_ETERIUM):
		return

	player._sync_desde_vital()
	player.mana_changed.emit(player.mana, player.max_mana)
	var recuperada := int(garumi.call("curar_con_eterium", CURACION))
	if recuperada <= 0:
		# No cobrar si el Garumi no pudo recibir la curación.
		player.eterium.restaurar(COSTO_ETERIUM)
		player._sync_desde_vital()
		player.mana_changed.emit(player.mana, player.max_mana)


func _pedir_ruptura_vinculo(garumi: Node) -> void:
	if not is_instance_valid(garumi) or not garumi.has_method("romper_vinculo"):
		return
	if is_instance_valid(_dialogo_ruptura_vinculo):
		_dialogo_ruptura_vinculo.queue_free()
	_dialogo_ruptura_vinculo = ConfirmationDialog.new()
	_dialogo_ruptura_vinculo.title = "Romper vínculo"
	_dialogo_ruptura_vinculo.dialog_text = "¿Quieres romper el vínculo con %s? El Garumi quedará libre y dejará de ocupar uno de tus tres espacios." % str(garumi.get("criatura_nombre"))
	_dialogo_ruptura_vinculo.ok_button_text = "Romper vínculo"
	_dialogo_ruptura_vinculo.cancel_button_text = "Conservar vínculo"
	add_child(_dialogo_ruptura_vinculo)
	_dialogo_ruptura_vinculo.confirmed.connect(_confirmar_ruptura_vinculo.bind(garumi))
	_dialogo_ruptura_vinculo.canceled.connect(_al_cancelar_dialogo_ruptura)
	for control in _dialogo_ruptura_vinculo.find_children("*", "Control", true, false):
		PIXEL_UI_THEME.apply(control as Control)
	_dialogo_ruptura_vinculo.popup_centered()


func _confirmar_ruptura_vinculo(garumi: Node) -> void:
	if is_instance_valid(garumi) and garumi.has_method("romper_vinculo"):
		garumi.call("romper_vinculo")
	if is_instance_valid(_dialogo_ruptura_vinculo):
		_dialogo_ruptura_vinculo.queue_free()
	_dialogo_ruptura_vinculo = null


func _al_cancelar_dialogo_ruptura() -> void:
	if is_instance_valid(_dialogo_ruptura_vinculo):
		_dialogo_ruptura_vinculo.queue_free()
	_dialogo_ruptura_vinculo = null


func eliminar_garumi_vinculado(garumi: Node) -> void:
	if not is_instance_valid(garumi):
		return
	var id := str(garumi.get_instance_id())
	_garumis_vinculados_ids.erase(id)
	_garumis_vinculados_nodos.erase(garumi)
	if _garumi_companero_actual == garumi:
		_garumi_companero_actual = null
		if not _garumis_vinculados_nodos.is_empty():
			_establecer_companero(_garumis_vinculados_nodos[0])
	_actualizar_selector_companero()


func actualizar_estado_garumi(garumi: Node, _guardado: bool) -> void:
	if garumi == _garumi_companero_actual:
		_actualizar_selector_companero()
