extends Node2D

@export var pantalla_completa: bool = true
@export var camera_zoom: float = 2.0

var _player: Node = null
var _camera: Camera2D = null
var _ultima_posicion_camara: Vector2 = Vector2.INF
var _input_router: Node = null

@onready var _hud: Control = $UI/HUD
@onready var _inventory: Control = $UI/Inventory
@onready var _interaction_system: Node = $Systems/InteractionSystem
@onready var _combat_system: Node = $Systems/CombatSystem
@onready var _dialogue_system: Node = $Systems/DialogueSystem
@onready var _ium_manager: Node = $Systems/IUMManager
@onready var _ium_lab: Control = $UI/IUMLab
@onready var _supabase_client: GarliaSupabaseClient = SupabaseClient
@onready var _ium_repository: Node = $Systems/IUMRepository


func _ready() -> void:
	var world_gen := $World/WorldGenerator
	if world_gen.has_method("configurar_entidades"):
		world_gen.call("configurar_entidades", $Entities)

	if world_gen.is_world_ready():
		_inicializar_jugador(world_gen)
	else:
		world_gen.mundo_generado.connect(
			_inicializar_jugador.bind(world_gen),
			CONNECT_ONE_SHOT
		)


func _process(_delta: float) -> void:
	_seguir_jugador()


func _inicializar_jugador(world_gen: Node) -> void:
	_player = $Entities/Player

	if _player == null:
		push_error("Main: no se encontró Entities/Player.")
		return

	if _player.has_method("set_spawn_from_world"):
		_player.set_spawn_from_world(world_gen)

	world_gen.registrar_jugador(_player)

	if _player.has_method("configurar_dependencias"):
		_player.call("configurar_dependencias", _inventory, world_gen, _ium_manager, world_gen.entity_manager)

	_configurar_camara()
	_configurar_hud(world_gen)
	_configurar_input_router()
	_configurar_interaccion()
	_configurar_combate(world_gen)
	_configurar_inventario()
	if GameState.has_method("configurar_dependencias"):
		GameState.call("configurar_dependencias", _inventory, _player, world_gen)
	_configurar_dialogo()
	if MissionManager.has_method("configurar_dependencias"):
		MissionManager.call("configurar_dependencias", _player, $World/WorldGenerator/WorldEntityManager)
	_configurar_social()
	_inicializar_ium()
	_configurar_pantalla()

	# Inicializar IUM con jugador (jugador_id puede venir de auth en el futuro)
	if _ium_manager != null:
		var jugador_id: String = ""
		if _player.has_method("get_jugador_id"):
			jugador_id = _player.call("get_jugador_id")
		_ium_manager.inicializar(jugador_id)


func _configurar_camara() -> void:
	var camara_actual: Camera2D = get_viewport().get_camera_2d()

	if camara_actual != null:
		camara_actual.enabled = false

	_camera = get_node_or_null("GameCamera") as Camera2D

	if _camera == null:
		_camera = Camera2D.new()
		_camera.name = "GameCamera"
		add_child(_camera)

	_camera.enabled = true
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_camera.position = Vector2.ZERO
	_camera.offset = Vector2.ZERO
	_camera.position_smoothing_enabled = false
	_ultima_posicion_camara = Vector2.INF
	_camera.drag_horizontal_enabled = false
	_camera.drag_vertical_enabled = false
	_camera.limit_enabled = false
	_camera.make_current()

	_seguir_jugador()


func _seguir_jugador() -> void:
	if _player == null or _camera == null:
		return

	var posicion: Vector2 = _player.global_position
	if posicion == _ultima_posicion_camara:
		return

	_camera.global_position = posicion
	_ultima_posicion_camara = posicion


func _configurar_hud(world_gen: Node) -> void:
	if _hud == null:
		push_error("Main: no se encontró UI/HUD.")
		return

	if _hud.has_method("configurar"):
		_hud.call("configurar", _player, world_gen, MissionManager, world_gen.entity_manager, _supabase_client)
	else:
		push_error("Main: HUD no tiene configurar().")


func _configurar_interaccion() -> void:
	if _interaction_system == null:
		push_error("Main: no se encontró Systems/InteractionSystem.")
		return

	if not _interaction_system.objetivo_cambiado.is_connected(_al_cambio_objetivo_interaccion):
		_interaction_system.objetivo_cambiado.connect(_al_cambio_objetivo_interaccion)

	if _interaction_system.has_method("configurar"):
		_interaction_system.configurar(_player, _inventory, GarliaWorldItems, _input_router)
	else:
		push_error("Main: InteractionSystem no tiene configurar().")

func _al_cambio_objetivo_interaccion(objetivo: Node) -> void:
	if _hud == null:
		return

	if objetivo == null or not is_instance_valid(objetivo):
		if _hud.has_method("ocultar_interaccion"):
			_hud.call("ocultar_interaccion")
		return

	var texto := "Recoger"
	if objetivo.has_method("get_interaction_text"):
		texto = str(objetivo.call("get_interaction_text"))

	if _hud.has_method("mostrar_interaccion"):
		_hud.call("mostrar_interaccion", texto)


func _configurar_combate(world_gen: Node) -> void:
	if _combat_system == null:
		push_error("Main: no se encontró Systems/CombatSystem.")
		return

	if _combat_system.has_method("configurar"):
		_combat_system.configurar(_player, _inventory, world_gen, self)


func _configurar_input_router() -> void:
	var router := get_node_or_null("/root/GameplayInputRouter")
	_input_router = router
	if router == null:
		push_error("Main: no se encontró GameplayInputRouter.")
		return
	if router.has_method("configurar_sistemas"):
		router.call("configurar_sistemas", _interaction_system, _combat_system)
	if router.has_method("configurar_bloqueos"):
		router.call(
		"configurar_bloqueos",
		_inventory,
		$UI/AdminConsole,
		_dialogue_system,
		_hud
	)

func _configurar_inventario() -> void:
	if _inventory == null:
		push_error("Main: no se encontró UI/Inventory.")
		return

	if _inventory.has_method("configurar"):
		_inventory.call("configurar", _player)

	var router: Node = _input_router
	if router != null and _inventory.has_method("configurar_input_gate"):
		_inventory.call("configurar_input_gate", router)


func _configurar_dialogo() -> void:
	if _dialogue_system == null:
		push_error("Main: no se encontró Systems/DialogueSystem.")
		return

	if _dialogue_system.has_method("configurar"):
		_dialogue_system.call("configurar", _player, _hud, MissionManager, RelationshipSystem)


func _configurar_pantalla() -> void:
	if not pantalla_completa:
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ============================================================
# IUM LAB
# ============================================================

func _inicializar_ium() -> void:
	# Compatibilidad de entrada: el sistema ya pertenece a la escena.
	# Main sólo compone dependencias; no crea sistemas dinámicamente.
	if _ium_manager == null:
		push_error("Main: no se encontró Systems/IUMManager.")
		return

	if _supabase_client == null or _ium_repository == null:
		push_error("Main: falta infraestructura Supabase/IUMRepository.")
		return

	if _ium_repository.has_method("configurar"):
		_ium_repository.call("configurar", _supabase_client)
	if _ium_manager.has_method("configurar"):
		_ium_manager.call("configurar", _ium_repository)

	if _ium_lab == null:
		push_error("Main: no se encontró UI/IUMLab.")
		return

	if _ium_lab.has_method("configurar"):
		_ium_lab.call("configurar", _ium_manager)

	if not _ium_manager.proceso_equipado_signal.is_connected(_al_equipar_proceso):
		_ium_manager.proceso_equipado_signal.connect(_al_equipar_proceso)

	print("Main: IUMManager e IUMLab conectados.")

func _al_equipar_proceso(proceso: Dictionary) -> void:
	# Guardar en player para que pueda usarlo con R
	if _player != null and _player.has_method("equipar_proceso_ium"):
		_player.call("equipar_proceso_ium", proceso)
	else:
		# Guardar en game_state como fallback
		GameState.flags["proceso_equipado"] = proceso

	var nombre: String = proceso.get("nombre", "Proceso")
	print("Main: Proceso IUM equipado → ", nombre)


func _configurar_social() -> void:
	if RelationshipSystem.has_method("configurar"):
		RelationshipSystem.call("configurar", SocialRepository)
