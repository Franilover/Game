extends Control

const START_MENU_PATH := "res://scenes/ui/start_menu.tscn"

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var reaparecer_button: Button = $Panel/Margin/Column/ReaparecerButton
@onready var menu_button: Button = $Panel/Margin/Column/MenuButton

var _player: Node = null
var _abierto: bool = false
var _esperando: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El menú permanece en la escena, pero cerrado no debe bloquear
	# ningún click del juego ni de otras interfaces.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	visible = true
	overlay.visible = false
	panel.visible = false

	reaparecer_button.pressed.connect(_reaparecer)
	menu_button.pressed.connect(_volver_al_menu)

	_buscar_player()


func _buscar_player() -> void:
	var jugador := get_tree().get_first_node_in_group("player")

	if jugador == null or not is_instance_valid(jugador):
		return

	_player = jugador

	if _player.has_signal("died"):
		if not _player.died.is_connected(_al_morir):
			_player.died.connect(_al_morir)


func _al_morir() -> void:
	if _abierto or _esperando:
		return

	var inventario := get_tree().get_first_node_in_group("inventory")

	if inventario != null and is_instance_valid(inventario):
		if inventario.has_method("cerrar"):
			inventario.call("cerrar")

	_esperando = true

	# Dejamos terminar la animación de muerte antes de detener el mundo.
	await get_tree().create_timer(0.4, true).timeout

	_esperando = false

	if _player == null or not is_instance_valid(_player):
		return

	if bool(_player.get("is_alive")):
		return

	_abierto = true
	overlay.visible = true
	panel.visible = true

	get_tree().paused = true

	reaparecer_button.grab_focus()


func _reaparecer() -> void:
	if not _abierto:
		return

	var inventario := get_tree().get_first_node_in_group("inventory")

	if inventario != null and is_instance_valid(inventario):
		if inventario.has_method("limpiar_inventario"):
			inventario.call("limpiar_inventario")

	if _player == null or not is_instance_valid(_player):
		_cerrar()
		get_tree().paused = false
		return

	if _player.has_method("reaparecer"):
		_player.call("reaparecer")

	_cerrar()
	get_tree().paused = false

	# Persistimos inmediatamente la pérdida de objetos y el nuevo spawn.
	GameState.guardar_partida()


func _volver_al_menu() -> void:
	if not _abierto:
		return

	_cerrar()
	get_tree().paused = false

	var error := get_tree().change_scene_to_file(
		START_MENU_PATH
	)

	if error != OK:
		push_error(
			"DeathMenu: no se pudo volver al menú. Error: "
			+ str(error)
		)


func _cerrar() -> void:
	_abierto = false
	overlay.visible = false
	panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _abierto:
		return

	if event.is_action_pressed("cancel"):
		_reaparecer()
		get_viewport().set_input_as_handled()
