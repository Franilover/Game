extends Control

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

const PAGINAS: Array[Dictionary] = [
	{
		"titulo": "UN TERRITORIO DEL ABISMO",
		"texto": "En el Abismo se extiende un territorio inmenso conocido como la Reserva Carmesí. Bosques densos, praderas abiertas, ríos, pantanos y valles forman parte de sus dominios. Aunque parece una región natural, toda la extensión está bajo control privado."
	},
	{
		"titulo": "EL ENTRETENIMIENTO DE LA ARISTOCRACIA",
		"texto": "La Reserva pertenece a una tradición de las familias aristocráticas del Abismo. Sus propietarios reciben invitados y organizan cacerías en las que humanos y otros seres conscientes son perseguidos por diversión y para alimentar a los nobles mediante el miedo y el dolor."
	},
	{
		"titulo": "LAS PRESAS Y LOS SUPERVIVIENTES",
		"texto": "La muerte no es el final obligatorio de una cacería. Quienes consiguen sobrevivir permanecen dentro de la Reserva y pueden convertirse en presas de nuevas partidas. Algunos aprenden a esconderse, reconocen los caminos y forman grupos para resistir."
	},
	{
		"titulo": "UNA JOVEN EN LA RESERVA",
		"texto": "En este lugar se encuentra Aurora, una joven humana atrapada en el Abismo. Para comprender dónde está, tendrá que conocer sus territorios, sus habitantes y las reglas impuestas por quienes controlan la Reserva. Su historia comienza aquí."
	}
]

@onready var page_counter: Label = $Content/PageCounter
@onready var page_title: Label = $Content/PageTitle
@onready var page_text: Label = $Content/PageText
@onready var previous_button: Button = $Content/Navigation/PreviousButton
@onready var next_button: Button = $Content/Navigation/NextButton

var _pagina_actual: int = 0


func _ready() -> void:
	previous_button.pressed.connect(_pagina_anterior)
	next_button.pressed.connect(_pagina_siguiente)
	PIXEL_UI_THEME.apply(self)
	_actualizar_pagina()


func _actualizar_pagina() -> void:
	var pagina: Dictionary = PAGINAS[_pagina_actual]
	page_counter.text = "INTRODUCCIÓN  ·  %02d / %02d" % [_pagina_actual + 1, PAGINAS.size()]
	page_title.text = str(pagina["titulo"])
	page_text.text = str(pagina["texto"])
	previous_button.disabled = _pagina_actual == 0
	next_button.text = "Comenzar capítulo" if _pagina_actual == PAGINAS.size() - 1 else "Continuar"

	page_text.modulate.a = 0.0
	page_title.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(page_title, "modulate:a", 1.0, 0.32)
	tween.tween_property(page_text, "modulate:a", 1.0, 0.48).set_delay(0.08)


func _pagina_anterior() -> void:
	if _pagina_actual <= 0:
		return
	_pagina_actual -= 1
	_actualizar_pagina()


func _pagina_siguiente() -> void:
	if _pagina_actual < PAGINAS.size() - 1:
		_pagina_actual += 1
		_actualizar_pagina()
		return

	_comenzar_capitulo()


func _comenzar_capitulo() -> void:
	GameState.world_state.flags["historia_iniciar_reserva_carmesi"] = true
	var error := get_tree().change_scene_to_file("res://scenes/world/main.tscn")
	if error != OK:
		GameState.world_state.flags.erase("historia_iniciar_reserva_carmesi")
		push_error("Historia: no se pudo iniciar La Reserva Carmesí. Error: %s" % error)


func _volver_a_historia() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/story/story_hub.tscn")
	if error != OK:
		push_error("Historia: no se pudo volver al selector de capítulos. Error: %s" % error)
