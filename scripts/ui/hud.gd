extends Control
class_name HUD

class GarumiHealthRing extends Control:
	var health_ratio: float = 1.0
	var occupied: bool = false

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		if radius <= 0.0:
			return
		draw_circle(center, radius - 1.5, Color(0.075, 0.05, 0.035, 0.98))
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.29, 0.19, 0.12, 1.0), 3.0, true)
		if occupied:
			var progreso := clampf(health_ratio, 0.0, 1.0)
			if progreso > 0.0:
				draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progreso, 48, Color(0.48, 0.73, 0.96, 1.0), 3.0, true)


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
var _garumis_vinculados_panel: HBoxContainer = null
var _garumis_vinculados_lista: HBoxContainer = null
var _garumis_vinculados_titulo: Label = null
var _garumis_vinculados_ids: Dictionary = {}
var _garumis_vinculados_nodos: Array[Node] = []
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
@onready var _location_label_node: Label = $LocationPanel/LocationLabel


func configurar(nuevo_player: Player = null, nuevo_world_context: WorldContext = null, nuevo_mission_manager: MissionManagerService = null, nuevo_entity_manager: WorldEntityManager = null, nuevo_supabase_client: GarliaSupabaseClient = null, nuevo_inventory: GarliaInventory = null, nuevo_world_data: WorldDataService = null, nuevo_game_state: GameStateService = null) -> void:
	if nuevo_player != null and is_instance_valid(nuevo_player):
		if is_instance_valid(player) and player != nuevo_player:
			_desconectar_senales_player()
		player = nuevo_player
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
	_actualizar_vidas_garumis_vinculados()
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
	if is_instance_valid(_garumis_vinculados_panel):
		_garumis_vinculados_panel.visible = (
			not inventario_abierto
			and not _combate_garumi_activo
		)
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
				_actualizar_contexto()

			get_viewport().set_input_as_handled()


func _preparar_puntos_dash() -> void:
	if not is_instance_valid(_stamina_bar_node):
		return
	_stamina_bar_node.visible = false
	_stamina_value_node.visible = false
	var contenedor := HBoxContainer.new()
	contenedor.name = "DashCharges"
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
	contenedor.add_theme_constant_override("separation", 4)
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor)
	for i in range(5):
		var pip := Panel.new()
		pip.name = "DashCharge" + str(i + 1)
		pip.custom_minimum_size = Vector2(14.0, 14.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenedor.add_child(pip)
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
	# Aviso creado por código para no añadir otra dependencia al .tscn.
	discovery_notice = Label.new()
	discovery_notice.name = "DiscoveryNotice"
	discovery_notice.visible = false
	discovery_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discovery_notice.z_index = 3000
	discovery_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discovery_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discovery_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	discovery_notice.position = Vector2(-260.0, 28.0)
	discovery_notice.size = Vector2(520.0, 48.0)
	discovery_notice.add_theme_color_override(
		"font_color",
		Color(0.93, 0.84, 0.65, 1.0)
	)
	discovery_notice.add_theme_color_override(
		"font_outline_color",
		Color(0.075, 0.05, 0.035, 1.0)
	)
	discovery_notice.add_theme_constant_override("outline_size", 3)
	discovery_notice.add_theme_font_size_override("font_size", 16)
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

	if location_label == null:
		push_error("HUD: falta LocationLabel en hud.tscn.")

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
	mission_panel = PanelContainer.new()
	mission_panel.name = "MissionPanel"
	mission_panel.visible = false
	mission_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mission_panel.z_index = 2500
	mission_panel.set_anchors_preset(Control.PRESET_CENTER)
	mission_panel.position = Vector2(-280.0, -210.0)
	mission_panel.size = Vector2(560.0, 420.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.055, 0.035, 0.98)
	style.border_color = Color(0.58, 0.43, 0.24, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	mission_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	mission_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "MISIONES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.65, 1.0))
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	mission_list = VBoxContainer.new()
	mission_list.name = "MissionList"
	mission_list.add_theme_constant_override("separation", 8)
	mission_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(mission_list)

	mission_hint = Label.new()
	mission_hint.text = "F · Cerrar    ESC · Cerrar"
	mission_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_hint.add_theme_color_override("font_color", Color(0.62, 0.53, 0.42, 1.0))
	mission_hint.add_theme_font_size_override("font_size", 10)
	column.add_child(mission_hint)

	add_child(mission_panel)


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
	interaction_panel = PanelContainer.new()
	interaction_panel.name = "InteractionPanel"
	interaction_panel.visible = false
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	interaction_panel.z_index = 2000

	interaction_panel.set_anchors_preset(Control.PRESET_CENTER)
	interaction_panel.position = Vector2(-230.0, -150.0)
	interaction_panel.size = Vector2(460.0, 300.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.055, 0.035, 0.98)
	style.border_color = Color(0.58, 0.43, 0.24, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	interaction_panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	interaction_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	interaction_title = Label.new()
	interaction_title.name = "Title"
	interaction_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_title.add_theme_color_override(
		"font_color",
		Color(0.93, 0.84, 0.65, 1.0)
	)
	interaction_title.add_theme_font_size_override(
		"font_size",
		18
	)
	column.add_child(interaction_title)

	interaction_body = Label.new()
	interaction_body.name = "Body"
	interaction_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	interaction_body.custom_minimum_size = Vector2(0, 160)
	interaction_body.add_theme_color_override(
		"font_color",
		Color(0.78, 0.70, 0.57, 1.0)
	)
	interaction_body.add_theme_font_size_override(
		"font_size",
		12
	)
	column.add_child(interaction_body)

	interaction_close = Button.new()
	interaction_close.name = "Close"
	interaction_close.text = "Cerrar"
	interaction_close.custom_minimum_size = Vector2(0, 34)
	interaction_close.focus_mode = Control.FOCUS_NONE
	interaction_close.pressed.connect(
		cerrar_panel_interaccion
	)
	column.add_child(interaction_close)

	add_child(interaction_panel)


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
	var slot := Button.new()
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
	slot.custom_minimum_size = Vector2(48, 48)
	slot.focus_mode = Control.FOCUS_NONE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.expand_icon = true
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_theme_stylebox_override("normal", _estilo_hueco_mano(false))
	slot.add_theme_stylebox_override("hover", _estilo_hueco_mano(true))
	slot.add_theme_stylebox_override("pressed", _estilo_hueco_mano(true))
	slot.add_theme_stylebox_override("focus", _estilo_hueco_mano(false))
	slot.tooltip_text = "Mano " + ("izquierda" if tecla == "Q" else "derecha") + " (" + tecla + ")"
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
	var numero := Label.new()
	numero.name = "HandKey"
	numero.text = tecla
	numero.position = Vector2(4, 2)
	numero.size = Vector2(14, 12)
	numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	numero.add_theme_font_size_override("font_size", 9)
	numero.add_theme_color_override("font_color", Color(0.72, 0.64, 0.50, 1))
	slot.add_child(numero)
	add_child(slot)
	return slot


func _estilo_hueco_mano(seleccionado: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.34, 0.27, 0.14, 1.0) if seleccionado else Color(0.18, 0.115, 0.07, 0.98)
	estilo.set_border_width_all(2)
	estilo.border_color = Color(0.74, 0.62, 0.34, 1.0) if seleccionado else Color(0.42, 0.29, 0.17, 1.0)
	estilo.set_corner_radius_all(3)
	return estilo


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
	# Selector compacto anclado encima del botón Q/E, sin panel centrado.
	_hand_selector = PanelContainer.new()
	_hand_selector.name = "HandItemSelector"
	_hand_selector.visible = false
	_hand_selector.custom_minimum_size = Vector2(42, 0)
	_hand_selector.size = Vector2(42, 0)
	_hand_selector.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.065, 0.04, 0.98)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.42, 0.29, 0.17, 1)
	panel_style.set_corner_radius_all(3)
	panel_style.content_margin_left = 3
	panel_style.content_margin_right = 3
	panel_style.content_margin_top = 3
	panel_style.content_margin_bottom = 3
	_hand_selector.add_theme_stylebox_override("panel", panel_style)
	add_child(_hand_selector)

	_hand_selector_grid = VBoxContainer.new()
	_hand_selector_grid.add_theme_constant_override("separation", 3)
	_hand_selector.add_child(_hand_selector_grid)
	for i in range(6):
		var button := Button.new()
		button.custom_minimum_size = Vector2(34, 32)
		button.size = Vector2(34, 32)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.add_theme_color_override("font_color", Color(0.93, 0.84, 0.65, 1))
		button.add_theme_font_size_override("font_size", 9)
		button.add_theme_stylebox_override("normal", _estilo_hueco_mano(false))
		button.add_theme_stylebox_override("hover", _estilo_hueco_mano(true))
		button.add_theme_stylebox_override("pressed", _estilo_hueco_mano(true))
		button.pressed.connect(_al_pulsar_selector_mano.bind(i))
		_hand_selector_grid.add_child(button)
		_hand_selector_buttons.append(button)


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
		button.text = str(i + 1)
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
		"toggle_ium":
			# X abre el menú de acciones de Eterium (curar, dash, IUM y conjuro).
			var radial: Node = get_tree().current_scene.find_child("EteriumRadialMenu", true, false) if get_tree().current_scene != null else null
			if radial != null and radial.has_method("toggle_menu"):
				radial.call("toggle_menu")
			else:
				push_warning("HUD: no se encontró EteriumRadialMenu.")


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var hand_key := event as InputEventKey
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
	_calendar_panel = PanelContainer.new()
	_calendar_panel.name = "CalendarClock"
	_calendar_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_calendar_panel.anchor_left = 1.0
	_calendar_panel.anchor_right = 1.0
	_calendar_panel.anchor_top = 0.0
	_calendar_panel.anchor_bottom = 0.0
	_calendar_panel.offset_left = -174.0
	_calendar_panel.offset_top = 12.0
	_calendar_panel.offset_right = -12.0
	_calendar_panel.offset_bottom = 82.0
	_calendar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.075, 0.05, 0.035, 0.88)
	estilo.set_border_width_all(1)
	estilo.border_color = Color(0.42, 0.29, 0.17, 1.0)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	_calendar_panel.add_theme_stylebox_override("panel", estilo)
	_calendar_label = Label.new()
	_calendar_label.name = "CalendarText"
	_calendar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_calendar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_calendar_label.add_theme_color_override("font_color", Color(0.93, 0.84, 0.65, 1.0))
	_calendar_label.add_theme_color_override("font_outline_color", Color(0.075, 0.05, 0.035, 1.0))
	_calendar_label.add_theme_constant_override("outline_size", 2)
	_calendar_label.add_theme_font_size_override("font_size", 11)
	_calendar_label.text = "GARLIA\nCargando calendario…"
	_calendar_panel.add_child(_calendar_label)
	add_child(_calendar_panel)


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
	# Tres espacios permanentes: número a la izquierda y retrato con anillo de vida.
	# Sin título ni contenedor decorativo; los huecos vacíos usan los tonos de la UI.
	_garumis_vinculados_panel = HBoxContainer.new()
	_garumis_vinculados_panel.name = "GarumisVinculados"
	_garumis_vinculados_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_garumis_vinculados_panel.position = Vector2(18.0, 18.0)
	_garumis_vinculados_panel.add_theme_constant_override("separation", 10)
	_garumis_vinculados_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_garumis_vinculados_panel.z_index = 20
	add_child(_garumis_vinculados_panel)

	_garumis_vinculados_lista = HBoxContainer.new()
	_garumis_vinculados_lista.name = "GarumiSlots"
	_garumis_vinculados_lista.add_theme_constant_override("separation", 10)
	_garumis_vinculados_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_garumis_vinculados_panel.add_child(_garumis_vinculados_lista)

	for i in range(3):
		_crear_hueco_garumi(i + 1)

func _crear_hueco_garumi(numero_slot: int) -> HBoxContainer:
	var slot := HBoxContainer.new()
	slot.name = "GarumiSlot" + str(numero_slot)
	slot.custom_minimum_size = Vector2(56.0, 46.0)
	slot.add_theme_constant_override("separation", 3)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta("garumi_id", "")
	_garumis_vinculados_lista.add_child(slot)

	var numero := Button.new()
	numero.name = "Numero"
	numero.text = str(numero_slot)
	numero.custom_minimum_size = Vector2(16.0, 30.0)
	numero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	numero.focus_mode = Control.FOCUS_NONE
	numero.mouse_filter = Control.MOUSE_FILTER_STOP
	numero.add_theme_color_override("font_color", Color(0.88, 0.75, 0.53, 1.0))
	numero.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.74, 1.0))
	numero.add_theme_font_size_override("font_size", 11)
	numero.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	numero.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	numero.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	numero.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	numero.tooltip_text = "Invocar / guardar Garumi %d" % numero_slot
	numero.pressed.connect(_activar_garumi_por_indice.bind(numero_slot - 1))
	slot.add_child(numero)

	var anillo := GarumiHealthRing.new()
	anillo.name = "Vida"
	anillo.custom_minimum_size = Vector2(42.0, 42.0)
	anillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(anillo)

	var retrato := TextureRect.new()
	retrato.name = "Retrato"
	retrato.set_anchors_preset(Control.PRESET_CENTER)
	retrato.position = Vector2(-15.0, -15.0)
	retrato.size = Vector2(30.0, 30.0)
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anillo.add_child(retrato)
	return slot


func mostrar_panel_garumis_durante_combate(mostrar: bool) -> void:
	if not is_instance_valid(_garumis_vinculados_panel):
		return
	# Durante el combate solo se muestran los marcos del aliado y del rival.
	_garumis_vinculados_panel.visible = mostrar and not _garumis_vinculados_nodos.is_empty()
	_actualizar_vidas_garumis_vinculados()


func establecer_estado_combate_garumi(activo: bool) -> void:
	_combate_garumi_activo = activo
	if is_instance_valid(_calendar_panel):
		_calendar_panel.visible = not activo


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


func _agregar_garumi_vinculado(garumi: Node, nombre: String) -> void:
	if not is_instance_valid(garumi) or _garumis_vinculados_lista == null:
		return
	var id := str(garumi.get_instance_id())
	if _garumis_vinculados_ids.has(id):
		actualizar_estado_garumi(garumi, bool(garumi.call("esta_guardado")) if garumi.has_method("esta_guardado") else false)
		return
	if _garumis_vinculados_nodos.size() >= 3:
		return
	var slot: HBoxContainer = null
	for candidato in _garumis_vinculados_lista.get_children():
		if candidato is HBoxContainer and str(candidato.get_meta("garumi_id", "")) == "":
			slot = candidato as HBoxContainer
			break
	if slot == null:
		return
	_garumis_vinculados_ids[id] = true
	_garumis_vinculados_nodos.append(garumi)
	slot.set_meta("garumi_id", id)
	var numero := slot.get_node_or_null("Numero") as Button
	if numero != null:
		numero.text = str(_garumis_vinculados_nodos.size())
		numero.add_theme_color_override("font_color", Color(0.88, 0.75, 0.53, 1.0))
	var anillo := slot.get_node_or_null("Vida") as GarumiHealthRing
	if anillo != null:
		anillo.occupied = true
		var retrato := anillo.get_node_or_null("Retrato") as TextureRect
		if retrato != null:
			retrato.texture = _buscar_textura_garumi(garumi)
	_actualizar_vidas_garumis_vinculados()
	actualizar_estado_garumi(garumi, bool(garumi.call("esta_guardado")) if garumi.has_method("esta_guardado") else false)


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
	# El combate gestiona Shift+1/2/3 para cambiar el aliado activo.
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

	var indice := codigo - KEY_1
	if indice < 0 or indice >= _garumis_vinculados_nodos.size():
		return false
	if evento.shift_pressed:
		var garumi_curacion := _garumis_vinculados_nodos[indice]
		if is_instance_valid(garumi_curacion):
			_curar_garumi_vinculado_con_eterium(garumi_curacion)
	else:
		_activar_garumi_por_indice(indice)
	return true


func _activar_garumi_por_indice(indice: int) -> void:
	if _combate_garumi_activo or indice < 0 or indice >= _garumis_vinculados_nodos.size():
		return
	if not is_instance_valid(player):
		return
	var garumi := _garumis_vinculados_nodos[indice]
	if is_instance_valid(garumi) and garumi.has_method("alternar_estado_invocacion"):
		garumi.call("alternar_estado_invocacion", player)


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
	if not is_instance_valid(garumi) or not is_instance_valid(_garumis_vinculados_lista):
		return
	var id := str(garumi.get_instance_id())
	var slot := _obtener_slot_garumi(garumi)
	if slot != null:
		slot.set_meta("garumi_id", "")
		var anillo := slot.get_node_or_null("Vida") as GarumiHealthRing
		if anillo != null:
			anillo.occupied = false
			anillo.health_ratio = 1.0
			var retrato := anillo.get_node_or_null("Retrato") as TextureRect
			if retrato != null:
				retrato.texture = null
			anillo.queue_redraw()
	_garumis_vinculados_ids.erase(id)
	_garumis_vinculados_nodos.erase(garumi)
	_renumerar_garumis_vinculados()


func _actualizar_titulo_garumis_vinculados() -> void:
	# El título se eliminó en el nuevo diseño.
	pass

func _renumerar_garumis_vinculados() -> void:
	if not is_instance_valid(_garumis_vinculados_lista):
		return
	# Compacta los vínculos para que el número visible coincida con las teclas 1–3.
	for i in range(_garumis_vinculados_lista.get_child_count()):
		var slot := _garumis_vinculados_lista.get_child(i) as HBoxContainer
		if slot == null:
			continue
		slot.set_meta("garumi_id", "")
		var numero_vacio := slot.get_node_or_null("Numero") as Button
		if numero_vacio != null:
			numero_vacio.text = str(i + 1)
			numero_vacio.add_theme_color_override("font_color", Color(0.88, 0.75, 0.53, 1.0))
		var anillo_vacio := slot.get_node_or_null("Vida") as GarumiHealthRing
		if anillo_vacio != null:
			anillo_vacio.occupied = false
			anillo_vacio.health_ratio = 1.0
			var retrato_vacio := anillo_vacio.get_node_or_null("Retrato") as TextureRect
			if retrato_vacio != null:
				retrato_vacio.texture = null
			anillo_vacio.queue_redraw()
	for i in range(_garumis_vinculados_nodos.size()):
		var garumi := _garumis_vinculados_nodos[i]
		if not is_instance_valid(garumi):
			continue
		var slot := _garumis_vinculados_lista.get_child(i) as HBoxContainer
		if slot == null:
			continue
		slot.set_meta("garumi_id", str(garumi.get_instance_id()))
		var numero := slot.get_node_or_null("Numero") as Button
		if numero != null:
			numero.text = str(i + 1)
		var anillo := slot.get_node_or_null("Vida") as GarumiHealthRing
		if anillo != null:
			anillo.occupied = true
			var retrato := anillo.get_node_or_null("Retrato") as TextureRect
			if retrato != null:
				retrato.texture = _buscar_textura_garumi(garumi)
	_actualizar_vidas_garumis_vinculados()


func _actualizar_vidas_garumis_vinculados() -> void:
	if not is_instance_valid(_garumis_vinculados_lista):
		return
	for garumi in _garumis_vinculados_nodos:
		if not is_instance_valid(garumi):
			continue
		var slot := _obtener_slot_garumi(garumi)
		if slot == null:
			continue
		var anillo := slot.get_node_or_null("Vida") as GarumiHealthRing
		if anillo == null:
			continue
		var vida_maxima := maxi(1, int(garumi.get("max_health")))
		var vida_actual := clampi(int(garumi.get("health")), 0, vida_maxima)
		anillo.health_ratio = float(vida_actual) / float(vida_maxima)
		anillo.occupied = true
		anillo.queue_redraw()

func _obtener_slot_garumi(garumi: Node) -> HBoxContainer:
	if not is_instance_valid(garumi) or not is_instance_valid(_garumis_vinculados_lista):
		return null
	var id := str(garumi.get_instance_id())
	for candidato in _garumis_vinculados_lista.get_children():
		if candidato is HBoxContainer and str(candidato.get_meta("garumi_id", "")) == id:
			return candidato as HBoxContainer
	return null


func actualizar_estado_garumi(garumi: Node, guardado: bool) -> void:
	if not is_instance_valid(garumi):
		return
	var slot := _obtener_slot_garumi(garumi)
	if slot == null:
		return
	var numero := slot.get_node_or_null("Numero") as Button
	if numero != null:
		numero.visible = true
		numero.add_theme_color_override(
			"font_color",
			Color(0.88, 0.75, 0.53, 1.0) if not guardado else Color(0.13, 0.10, 0.075, 1.0)
		)
