extends Control

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const VELOCIDAD_MAQUINA_ESCRIBIR := 18.0

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
@onready var text_panel: PanelContainer = $Content/TextPanel
@onready var inset_panel: PanelContainer = $Content/TextPanel/InsetPanel
@onready var page_text: Label = $Content/TextPanel/InsetPanel/PageText
@onready var previous_button: Button = $Content/Navigation/PreviousButton
@onready var next_button: Button = $Content/Navigation/NextButton

var _pagina_actual: int = 0
var _texto_tween: Tween


func _ready() -> void:
	previous_button.pressed.connect(_pagina_anterior)
	next_button.pressed.connect(_pagina_siguiente)
	PIXEL_UI_THEME.apply(self)
	_configurar_panel_texto()
	_actualizar_pagina()


func _configurar_panel_texto() -> void:
	# Marco exterior con profundidad y un segundo plano interior para evitar el aspecto de bloque plano.
	var marco := StyleBoxFlat.new()
	marco.bg_color = Color(0.16, 0.075, 0.059, 0.98)
	marco.border_color = Color(0.58, 0.30, 0.19, 1.0)
	marco.set_border_width_all(2)
	marco.set_corner_radius_all(5)
	marco.shadow_color = Color(0.008, 0.004, 0.004, 0.62)
	marco.shadow_size = 14
	marco.shadow_offset = Vector2(0, 5)
	marco.content_margin_left = 7.0
	marco.content_margin_right = 7.0
	marco.content_margin_top = 7.0
	marco.content_margin_bottom = 7.0
	text_panel.add_theme_stylebox_override("panel", marco)

	var interior := StyleBoxFlat.new()
	interior.bg_color = Color(0.075, 0.046, 0.041, 1.0)
	interior.border_color = Color(0.31, 0.17, 0.12, 1.0)
	interior.set_border_width_all(1)
	interior.set_corner_radius_all(2)
	interior.content_margin_left = 20.0
	interior.content_margin_right = 20.0
	interior.content_margin_top = 15.0
	interior.content_margin_bottom = 15.0
	inset_panel.add_theme_stylebox_override("panel", interior)


func _actualizar_pagina() -> void:
	var pagina: Dictionary = PAGINAS[_pagina_actual]
	page_counter.text = "INTRODUCCIÓN  ·  %02d / %02d" % [_pagina_actual + 1, PAGINAS.size()]
	page_title.text = str(pagina["titulo"])
	page_text.text = str(pagina["texto"])
	page_text.visible_characters = 0
	previous_button.disabled = _pagina_actual == 0
	next_button.text = "Comenzar capítulo" if _pagina_actual == PAGINAS.size() - 1 else "Continuar"

	if _texto_tween and _texto_tween.is_running():
		_texto_tween.kill()
	page_title.modulate.a = 0.0
	text_panel.modulate.a = 0.0
	var entrada := create_tween().set_parallel(true)
	entrada.tween_property(page_title, "modulate:a", 1.0, 0.38)
	entrada.tween_property(text_panel, "modulate:a", 1.0, 0.42).set_delay(0.06)

	# Ritmo pausado para poder leer mientras aparecen los caracteres.
	var cantidad_caracteres := page_text.get_total_character_count()
	var duracion := maxf(1.0, float(cantidad_caracteres) / VELOCIDAD_MAQUINA_ESCRIBIR)
	_texto_tween = create_tween()
	_texto_tween.tween_property(page_text, "visible_characters", cantidad_caracteres, duracion)


func _pagina_anterior() -> void:
	if _pagina_actual <= 0:
		return
	_pagina_actual -= 1
	_actualizar_pagina()


func _pagina_siguiente() -> void:
	# El primer toque termina la animación; el siguiente avanza de página.
	if _texto_tween and _texto_tween.is_running():
		_texto_tween.kill()
		page_text.visible_characters = -1
		return
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
