extends Node2D

@export var pantalla_completa: bool = true
@export var camera_zoom: float = 2.0

var _player: Node = null
var _camera: Camera2D = null
var _ultima_posicion_camara: Vector2 = Vector2.INF

@onready var _hud: Control = $UI/HUD
@onready var _inventory: Control = $UI/Inventory
@onready var _interaction_system: Node = $Systems/InteractionSystem
@onready var _combat_system: Node = $Systems/CombatSystem

# Sistemas de interacción narrativa
var _dialogue_system: Node = null

# IUM Lab
var _ium_manager: Node = null
var _ium_lab: Control = null


func _ready() -> void:
	_inicializar_ium()

	var world_gen := $World/WorldGenerator

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

	_configurar_camara()
	_configurar_hud(world_gen)
	_configurar_interaccion()
	_configurar_combate()
	_configurar_inventario()
	_inicializar_dialogo()
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
		_hud.call("configurar", _player, world_gen)
	else:
		push_error("Main: HUD no tiene configurar().")


func _configurar_interaccion() -> void:
	if _interaction_system == null:
		push_error("Main: no se encontró Systems/InteractionSystem.")
		return

	if _interaction_system.has_method("configurar"):
		_interaction_system.configurar(_player, _hud)
	else:
		push_error("Main: InteractionSystem no tiene configurar().")


func _configurar_combate() -> void:
	if _combat_system == null:
		push_error("Main: no se encontró Systems/CombatSystem.")
		return

	if _combat_system.has_method("configurar"):
		_combat_system.configurar(_player)


func _configurar_inventario() -> void:
	if _inventory == null:
		push_error("Main: no se encontró UI/Inventory.")
		return


func _inicializar_dialogo() -> void:
	var systems := get_node_or_null("Systems")
	if systems == null:
		push_error("Main: no se encontró nodo Systems para DialogueSystem.")
		return

	var dialogue_script := load(
		"res://scripts/systems/dialogue_system.gd"
	)
	if dialogue_script == null:
		push_error("Main: no se pudo cargar dialogue_system.gd.")
		return

	_dialogue_system = Node.new()
	_dialogue_system.name = "DialogueSystem"
	_dialogue_system.set_script(dialogue_script)
	systems.add_child(_dialogue_system)

	var ui := get_node_or_null("UI")
	if _dialogue_system.has_method("configurar"):
		_dialogue_system.call(
			"configurar",
			_player,
			ui
		)

	print("Main: DialogueSystem inicializado.")


func _configurar_pantalla() -> void:
	if not pantalla_completa:
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ============================================================
# IUM LAB
# ============================================================

func _inicializar_ium() -> void:
	# Crear IUM Manager como nodo hijo de Systems
	var systems := get_node_or_null("Systems")
	if systems == null:
		push_error("Main: no se encontró nodo Systems.")
		return

	var manager_script := load("res://scripts/systems/ium/ium_manager.gd")
	if manager_script == null:
		push_error("Main: no se pudo cargar ium_manager.gd.")
		return

	_ium_manager = Node.new()
	_ium_manager.name = "IUMManager"
	_ium_manager.set_script(manager_script)
	systems.add_child(_ium_manager)

	# Cargar y añadir escena del IUM Lab a UI
	var lab_scene := load("res://scenes/ui/ium_lab.tscn")
	if lab_scene == null:
		push_error("Main: no se pudo cargar ium_lab.tscn.")
		return

	_ium_lab = lab_scene.instantiate()
	_ium_lab.name = "IUMLab"

	var ui := get_node_or_null("UI")
	if ui != null:
		ui.add_child(_ium_lab)
	else:
		add_child(_ium_lab)

	# Conectar lab con manager
	if _ium_lab.has_method("configurar"):
		_ium_lab.call("configurar", _ium_manager)

	# Conectar proceso equipado → el jugador puede usar magia con R.
	_ium_manager.proceso_equipado_signal.connect(_al_equipar_proceso)

	print("Main: IUM Lab inicializado.")


func _al_equipar_proceso(proceso: Dictionary) -> void:
	# Guardar en player para que pueda usarlo con R
	if _player != null and _player.has_method("equipar_proceso_ium"):
		_player.call("equipar_proceso_ium", proceso)
	else:
		# Guardar en game_state como fallback
		GameState.flags["proceso_equipado"] = proceso

	var nombre: String = proceso.get("nombre", "Proceso")
	print("Main: Proceso IUM equipado → ", nombre)
