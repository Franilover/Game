extends Node

const RuntimeScript = preload("res://scripts/gameplay/inventory/inventory_runtime.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var runtime := RuntimeScript.new() as InventoryRuntime
	var items: Array = []
	for i in range(18):
		items.append({})
	items[6] = {"id": "sword_a", "nombre": "Espada A", "cantidad": 1, "max_stack": 1}
	runtime.establecer_items(items)

	# La UI puede entregar una copia vieja: el runtime debe equipar el slot real.
	var stale_copy := {"id": "sword_b", "nombre": "Espada B", "cantidad": 1}
	if not runtime.equipar_desde_inventario("mano_derecha", 6, stale_copy):
		errors.append("No equipó un objeto válido desde el inventario.")
	if str(runtime.obtener_equipo("mano_derecha").get("id", "")) != "sword_a":
		errors.append("Equipó la copia obsoleta de la UI en vez del objeto canónico.")
	if not runtime.state.items[6].is_empty():
		errors.append("No retiró el objeto equipado de su slot de inventario.")

	# Un índice vacío no debe reemplazar ni borrar el equipo existente.
	if runtime.equipar_desde_inventario("mano_derecha", 7, stale_copy):
		errors.append("Permitió equipar desde un slot vacío.")
	if str(runtime.obtener_equipo("mano_derecha").get("id", "")) != "sword_a":
		errors.append("Una operación inválida alteró el equipo existente.")

	# El cambio de equipo intercambia ambos objetos sin perder ninguno.
	items[8] = {"id": "axe_c", "nombre": "Hacha C", "cantidad": 1, "max_stack": 1}
	runtime.establecer_items(items)
	if not runtime.equipar_desde_inventario("mano_derecha", 8, {}):
		errors.append("No pudo intercambiar el objeto equipado por el nuevo.")
	if str(runtime.obtener_equipo("mano_derecha").get("id", "")) != "axe_c":
		errors.append("El objeto nuevo no quedó equipado.")
	if str(runtime.state.items[8].get("id", "")) != "sword_a":
		errors.append("El objeto previamente equipado no regresó al slot de origen.")

	# Sin espacio libre, desequipar debe fallar sin perder el objeto.
	var full_items: Array = []
	for i in range(18):
		full_items.append({"id": "full_%d" % i, "nombre": "Lleno", "cantidad": 1, "max_stack": 1})
	runtime.establecer_items(full_items)
	if runtime.desequipar_a_inventario("mano_derecha"):
		errors.append("Desequipó aunque el inventario estaba lleno.")
	if str(runtime.obtener_equipo("mano_derecha").get("id", "")) != "axe_c":
		errors.append("El fallo por inventario lleno perdió el equipo.")

	# Con espacio libre, devuelve el objeto y limpia el slot de equipo.
	runtime.state.items[17] = {}
	if not runtime.desequipar_a_inventario("mano_derecha"):
		errors.append("No devolvió el equipo al inventario cuando había espacio.")
	if not runtime.obtener_equipo("mano_derecha").is_empty():
		errors.append("No limpió el slot de equipo tras devolver el objeto.")
	if str(runtime.state.items[17].get("id", "")) != "axe_c":
		errors.append("No conservó el objeto devuelto al inventario.")

	# La durabilidad usa una sola regla para objetos en mochila y equipados.
	runtime.state.items[6] = {
		"id": "tool_worn",
		"nombre": "Herramienta",
		"cantidad": 1,
		"max_stack": 1,
		"propiedades_game": {"durabilidad": 2},
		"durabilidad_actual": 2
	}
	if not runtime.consumir_durabilidad(6):
		errors.append("No consumió durabilidad de un objeto del inventario.")
	if int(runtime.state.items[6].get("durabilidad_actual", 0)) != 1:
		errors.append("No redujo la durabilidad del objeto en inventario.")
	if not runtime.consumir_durabilidad(6) or not runtime.state.items[6].is_empty():
		errors.append("No retiró el objeto del inventario al agotar su durabilidad.")

	runtime.equipar("armadura", {
		"id": "armor_worn",
		"nombre": "Armadura",
		"propiedades_game": {"durabilidad": 1},
		"durabilidad_actual": 1
	})
	if not runtime.consumir_durabilidad_equipo("armadura"):
		errors.append("No consumió durabilidad de un objeto equipado.")
	if not runtime.obtener_equipo("armadura").is_empty():
		errors.append("No retiró el equipo al agotar su durabilidad.")

	if not errors.is_empty():
		for error in errors:
			push_error("InventoryEquipmentTransaction: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryEquipmentTransaction: PASS")
	get_tree().quit(0)
