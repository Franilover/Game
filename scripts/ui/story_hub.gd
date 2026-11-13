extends Control

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

@onready var chapter_button: Button = $Content/ChapterButton
@onready var back_button: Button = $Content/BackButton


func _ready() -> void:
	chapter_button.pressed.connect(_abrir_reserva_carmesi)
	back_button.pressed.connect(_volver_al_menu)
	PIXEL_UI_THEME.apply(self)
	if GameState.historia_reserva_tiene_progreso():
		chapter_button.text = "CONTINUAR · LA RESERVA CARMESÍ"
	chapter_button.grab_focus()


func _abrir_reserva_carmesi() -> void:
	if GameState.historia_reserva_tiene_progreso():
		GameState.preparar_historia_reserva_carmesi(false)
		var error := get_tree().change_scene_to_file("res://scenes/world/main.tscn")
		if error != OK:
			push_error("Historia: no se pudo reanudar La Reserva Carmesí. Error: %s" % error)
		return
	var error := get_tree().change_scene_to_file("res://scenes/story/reserva_carmesi_intro.tscn")
	if error != OK:
		push_error("Historia: no se pudo abrir La Reserva Carmesí. Error: %s" % error)


func _volver_al_menu() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")
	if error != OK:
		push_error("Historia: no se pudo volver al menú principal. Error: %s" % error)
