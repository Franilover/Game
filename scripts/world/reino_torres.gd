extends Node2D

const WORLD_SCENE_PATH: String = "res://scenes/world/main.tscn"

@onready var _player: Player = $Player
@onready var _camera: Camera2D = $Camera
@onready var _exit: Area2D = $Exit

var _input_router: GameplayInputRouter = null
var _transicionando: bool = false

func _ready() -> void:
	# El Reino Torres no usa el Main del mundo abierto, por lo que
	# necesita registrar la misma autoridad de entrada del gameplay.
	# Sin este router, GameplayInputGate bloquea el movimiento por diseño.
	_input_router = GameplayInputRouter.new()
	add_child(_input_router)

	_exit.body_entered.connect(_al_entrar_salida)
	_camera.make_current()

func _process(_delta: float) -> void:
	if _player == null or _camera == null:
		return
	_camera.global_position = _player.global_position

func _al_entrar_salida(body: Node2D) -> void:
	if _transicionando or body != _player:
		return
	_transicionando = true
	print("ReinoTorres: saliendo al mundo abierto.")
	SceneManager.go_to(WORLD_SCENE_PATH)
