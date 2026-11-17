extends Node

const DialogueSystemScript = preload("res://scripts/gameplay/dialogue_system.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var dialogo := DialogueSystemScript.new() as DialogueSystem
	add_child(dialogo)

	dialogo.dialogue_panel = PanelContainer.new()
	dialogo.add_child(dialogo.dialogue_panel)
	dialogo._dialogue_margin = MarginContainer.new()
	dialogo.add_child(dialogo._dialogue_margin)
	dialogo._dialogue_content_row = HBoxContainer.new()
	dialogo.add_child(dialogo._dialogue_content_row)
	dialogo._dialogue_text_column = VBoxContainer.new()
	dialogo.add_child(dialogo._dialogue_text_column)
	dialogo._dialogue_social_column = VBoxContainer.new()
	dialogo.add_child(dialogo._dialogue_social_column)
	dialogo.portrait_rect = TextureRect.new()
	dialogo.add_child(dialogo.portrait_rect)
	dialogo.speaker_label = Label.new()
	dialogo.add_child(dialogo.speaker_label)
	dialogo.text_label = Label.new()
	dialogo.add_child(dialogo.text_label)
	dialogo.hint_label = Label.new()
	dialogo.add_child(dialogo.hint_label)
	dialogo.action_button = Button.new()
	dialogo.add_child(dialogo.action_button)
	dialogo.cancel_button = Button.new()
	dialogo.add_child(dialogo.cancel_button)
	dialogo._boton_regalo = Button.new()
	dialogo.add_child(dialogo._boton_regalo)
	dialogo._boton_preguntar_item = Button.new()
	dialogo.add_child(dialogo._boton_preguntar_item)
	dialogo._boton_tienda_mercado = Button.new()
	dialogo.add_child(dialogo._boton_tienda_mercado)
	dialogo._selector_items = PanelContainer.new()
	dialogo.add_child(dialogo._selector_items)
	dialogo._selector_items_grid = GridContainer.new()
	dialogo.add_child(dialogo._selector_items_grid)
	dialogo._selector_conversacion_grid = GridContainer.new()
	dialogo.add_child(dialogo._selector_conversacion_grid)

	dialogo._adaptar_panel_dialogo(Vector2(360.0, 640.0))
	if dialogo.dialogue_panel.size.x > 336.0:
		errores.append("El panel de diálogo desborda el viewport móvil de 360 px.")
	if dialogo.portrait_rect.visible:
		errores.append("El retrato no se ocultó en el layout móvil estrecho.")
	if dialogo.action_button.custom_minimum_size.x > 110.0 or dialogo.cancel_button.custom_minimum_size.x > 76.0:
		errores.append("Los botones principales conservan anchos de escritorio en móvil.")
	if dialogo._selector_items_grid.columns != 1:
		errores.append("El selector de objetos no pasó a una columna en móvil estrecho.")

	dialogo._adaptar_panel_dialogo(Vector2(640.0, 360.0))
	if dialogo.dialogue_panel.size.x > 616.0:
		errores.append("El panel de diálogo desborda el viewport horizontal de 640 px.")
	if not dialogo.portrait_rect.visible or dialogo.portrait_rect.custom_minimum_size.x != 120.0:
		errores.append("El retrato no recuperó el tamaño compacto en paisaje.")
	if dialogo._selector_items_grid.columns != 2:
		errores.append("El selector de objetos no recuperó dos columnas en paisaje.")

	dialogo._adaptar_panel_dialogo(Vector2(960.0, 540.0))
	if dialogo.dialogue_panel.size != Vector2(720.0, 260.0):
		errores.append("El layout de escritorio dejó de conservar el tamaño previsto.")

	dialogo.queue_free()
	await get_tree().process_frame
	if not errores.is_empty():
		for error in errores:
			push_error("DialogueMobileLayout: FAIL: " + error)
		get_tree().quit(1)
		return
	print("DialogueMobileLayout: PASS")
	get_tree().quit(0)
