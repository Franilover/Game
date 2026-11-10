extends Node

const ADMIN_INVENTORY_SCRIPT: Script = preload("res://scripts/ui/admin_inventory.gd")

var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var admin := ADMIN_INVENTORY_SCRIPT.new() as Control
	add_child(admin)
	await get_tree().process_frame

	var list_scroll := admin.find_child("CreatureObjectListScroll", true, false) as ScrollContainer
	var detail_scroll := admin.find_child("CreatureObjectDetailScroll", true, false) as ScrollContainer
	_expect(list_scroll != null, "La lista de criaturas/objetos debe estar dentro de un ScrollContainer.")
	_expect(detail_scroll != null, "El panel de detalles debe tener desplazamiento vertical.")
	if list_scroll != null:
		_expect(list_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "La lista debe mostrar scroll vertical cuando el contenido lo necesite.")
		_expect(list_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "La lista no debe introducir scroll horizontal.")
		_expect(list_scroll.size_flags_vertical == Control.SIZE_EXPAND_FILL, "La lista debe ocupar el alto disponible para que el contenido pueda desbordar.")
	if detail_scroll != null:
		_expect(detail_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Los detalles deben permitir desplazamiento vertical.")
		_expect(detail_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Los detalles no deben introducir scroll horizontal.")
		_expect(detail_scroll.size_flags_vertical == Control.SIZE_EXPAND_FILL, "Los detalles deben ocupar el alto disponible.")

	admin.queue_free()
	if _failed:
		get_tree().quit(1)
		return
	print("AdminInventoryScrollContract: PASS")
	get_tree().quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("AdminInventoryScrollContract: FAIL: " + message)
