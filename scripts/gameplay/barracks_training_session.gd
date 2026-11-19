extends CanvasLayer
class_name BarracksTrainingSession

const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")

var _jugador: Node2D
var _contrincante: Creature
var _posicion_original := Vector2.ZERO
var _posicion_inicio_jugador := Vector2.ZERO
var _vida_original := 1
var _velocidad_original := Vector2.ZERO
var _finalizando := false
var _estado: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("barracks_training_session")


func iniciar(jugador: Node2D, contrincante: Creature) -> bool:
	if not is_instance_valid(jugador) or not is_instance_valid(contrincante):
		return false
	if not contrincante.is_alive or contrincante == jugador:
		return false
	_jugador = jugador
	_contrincante = contrincante
	_posicion_original = contrincante.global_position
	_posicion_inicio_jugador = jugador.global_position
	_vida_original = contrincante.health
	_velocidad_original = contrincante.velocity
	contrincante.set_meta("barracks_training_target", true)
	contrincante.global_position = jugador.global_position + Vector2(52.0, 0.0)
	contrincante.velocity = Vector2.ZERO
	_crear_interfaz()
	return true


func _crear_interfaz() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -150.0
	panel.offset_right = 150.0
	panel.offset_top = -76.0
	panel.offset_bottom = -12.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	PIXEL_UI_THEME.apply(panel, false)
	var columna := VBoxContainer.new()
	panel.add_child(columna)
	_estado = Label.new()
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.text = "Entrenamiento activo · el contrincante no puede morir."
	columna.add_child(_estado)
	var terminar := Button.new()
	terminar.text = "Terminar entrenamiento"
	terminar.custom_minimum_size = Vector2(0, 32)
	terminar.pressed.connect(finalizar)
	columna.add_child(terminar)
	PIXEL_UI_THEME.apply(terminar, false)


func _process(_delta: float) -> void:
	if _finalizando:
		return
	if not is_instance_valid(_jugador) or not is_instance_valid(_contrincante):
		finalizar()
		return
	if not _jugador.get("is_alive") or not _contrincante.is_alive:
		finalizar()
		return
	if _jugador.global_position.distance_to(_posicion_inicio_jugador) > 1200.0:
		finalizar()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		finalizar()
		get_viewport().set_input_as_handled()


func finalizar() -> void:
	if _finalizando:
		return
	_finalizando = true
	if is_instance_valid(_contrincante):
		_contrincante.remove_meta("barracks_training_target")
		_contrincante.restaurar_estado_vital(_vida_original, true)
		_contrincante.global_position = _posicion_original
		_contrincante.velocity = _velocidad_original
	queue_free()
