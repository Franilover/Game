extends Control

const START_MENU_PATH := "res://scenes/ui/start_menu.tscn"

@onready var volver_button: Button = $Panel/Margin/Column/VolverButton
@onready var mundo_button: Button = $Panel/Margin/Column/MundoButton
@onready var configuracion_button: Button = $Panel/Margin/Column/ConfiguracionButton
@onready var menu_button: Button = $Panel/Margin/Column/MenuButton

var abierto: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	$Overlay.visible = false
	$Panel.visible = false

	volver_button.pressed.connect(_volver)
	menu_button.pressed.connect(_volver_al_menu)

	# Estas opciones forman parte de la interfaz desde ahora,
	# pero todavía no tienen sistema detrás.
	mundo_button.disabled = true
	configuracion_button.disabled = true


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode != KEY_ESCAPE:
		return

	# El inventario conserva prioridad sobre la pausa.
	var inventario := get_tree().get_first_node_in_group("inventory")

	if not abierto and inventario != null:
		if inventario is Control and (inventario as Control).visible:
			return

	_alternar()
	get_viewport().set_input_as_handled()


func _alternar() -> void:
	if abierto:
		_cerrar()
	else:
		_abrir()


func _abrir() -> void:
	if abierto:
		return

	abierto = true
	$Overlay.visible = true
	$Panel.visible = true
	get_tree().paused = true
	volver_button.grab_focus()


func _cerrar() -> void:
	if not abierto:
		return

	abierto = false
	$Overlay.visible = false
	$Panel.visible = false
	get_tree().paused = false


func _volver() -> void:
	_cerrar()


func _volver_al_menu() -> void:
	# El menú se ejecuta mientras el árbol está pausado,
	# por eso el guardado debe ocurrir antes de reanudar.
	GameState.guardar_partida()

	abierto = false
	$Overlay.visible = false
	$Panel.visible = false
	get_tree().paused = false

	var error := get_tree().change_scene_to_file(
		START_MENU_PATH
	)

	if error != OK:
		push_error(
			"PauseMenu: no se pudo volver al menú. Error: "
			+ str(error)
		)
