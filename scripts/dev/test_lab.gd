extends Control

const START_MENU_SCENE: String = "res://scenes/ui/start_menu.tscn"

const TESTS: Array[Dictionary] = [
	{
		"id": "tilemap_dual",
		"title": "TileMapDual — Terreno aislado",
		"description": "Prueba mínima del autotiling y las transiciones sin WorldData, biomas, ecosistemas ni streaming.",
		"scene": "res://scenes/dev/tilemap_dual_test.tscn",
	},
]


func _ready() -> void:
	$Center/BackButton.pressed.connect(_volver_al_menu)

	var list: VBoxContainer = $Center/Tests

	for test: Dictionary in TESTS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.text = str(test["title"])
		button.tooltip_text = str(test["description"])
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(
			_abrir_test.bind(str(test["scene"]))
		)
		list.add_child(button)

		var description := Label.new()
		description.text = str(test["description"])
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 12)
		description.modulate = Color(0.82, 0.75, 0.64, 1.0)
		list.add_child(description)

		if test != TESTS.back():
			var separator := HSeparator.new()
			list.add_child(separator)

	$Center/BackButton.grab_focus()


func _abrir_test(scene_path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error(
			"TestLab: no se pudo abrir la escena: "
			+ scene_path
			+ " Error: "
			+ str(error)
		)


func _volver_al_menu() -> void:
	var error: Error = get_tree().change_scene_to_file(START_MENU_SCENE)
	if error != OK:
		push_error(
			"TestLab: no se pudo volver al menú principal. Error: "
			+ str(error)
		)
