extends Node

const RuntimeScript = preload("res://scripts/gameplay/inventory/inventory_runtime.gd")
const CombatDefenseScript = preload("res://scripts/gameplay/combat/combat_defense.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var runtime := RuntimeScript.new() as InventoryRuntime
	var items: Array = []
	for i in range(18):
		items.append({})
	items[6] = {
		"id": "armor_a", "nombre": "Armadura A", "tipo": "armadura",
		"cantidad": 1, "max_stack": 1,
		"propiedades_game": {"ranura_equipamiento": "torso", "durabilidad": 2},
		"durabilidad_actual": 2
	}
	runtime.establecer_items(items)

	# La UI puede entregar una copia vieja: el runtime debe equipar el slot real.
	var stale_copy := {"id": "sword_b", "nombre": "Espada B", "cantidad": 1}
	if not runtime.equipar_desde_inventario("torso", 6, stale_copy):
		errors.append("No equipó un objeto válido desde el inventario.")
	if str(runtime.obtener_equipo("torso").get("id", "")) != "sword_a":
		errors.append("Equipó la copia obsoleta de la UI en vez del objeto canónico.")
	if not runtime.state.items[6].is_empty():
		errors.append("No retiró el objeto equipado de su slot de inventario.")

	# El runtime rechaza armas, ranuras cruzadas y claves desconocidas.
	items[9] = {"id": "weapon_x", "nombre": "Espada", "tipo": "arma"}
	items[10] = {
		"id": "helmet_x", "nombre": "Casco", "tipo": "armadura",
		"propiedades_game": {"ranura_equipamiento": "cabeza"}
	}
	runtime.establecer_items(items)
	if runtime.equipar_desde_inventario("torso", 9, {}):
		errors.append("Permitió equipar un arma como armadura.")
	if runtime.equipar_desde_inventario("torso", 10, {}):
		errors.append("Permitió colocar una armadura en una ranura incorrecta.")
	if runtime.equipar_desde_inventario("arma", 10, {}):
		errors.append("Permitió crear una ranura de equipo desconocida.")
	if not runtime.obtener_equipo("torso").is_empty():
		errors.append("Una operación incompatible alteró la armadura equipada.")
	if str(runtime.state.items[9].get("id", "")) != "weapon_x" or str(runtime.state.items[10].get("id", "")) != "helmet_x":
		errors.append("Una operación incompatible modificó los objetos de origen.")

	# Un índice vacío no debe reemplazar ni borrar el equipo existente.
	if runtime.equipar_desde_inventario("torso", 7, stale_copy):
		errors.append("Permitió equipar desde un slot vacío.")
	if str(runtime.obtener_equipo("mano_derecha").get("id", "")) != "sword_a":
		errors.append("Una operación inválida alteró el equipo existente.")

	# El cambio de equipo intercambia ambos objetos sin perder ninguno.
	items[8] = {
		"id": "armor_b", "nombre": "Armadura B", "tipo": "armadura",
		"cantidad": 1, "max_stack": 1,
		"propiedades_game": {"ranura_equipamiento": "torso", "durabilidad": 3},
		"durabilidad_actual": 3
	}
	runtime.establecer_items(items)
	if not runtime.equipar_desde_inventario("torso", 8, {}):
		errors.append("No pudo intercambiar el objeto equipado por el nuevo.")
	if str(runtime.obtener_equipo("mano_derecha").get("id", "")) != "axe_c":
		errors.append("El objeto nuevo no quedó equipado.")
	if str(runtime.state.items[8].get("id", "")) != "armor_a":
		errors.append("El objeto previamente equipado no regresó al slot de origen.")

	# Sin espacio libre, desequipar debe fallar sin perder el objeto.
	var full_items: Array = []
	for i in range(18):
		full_items.append({"id": "full_%d" % i, "nombre": "Lleno", "cantidad": 1, "max_stack": 1})
	runtime.establecer_items(full_items)
	if runtime.desequipar_a_inventario("torso"):
		errors.append("Desequipó aunque el inventario estaba lleno.")
	if str(runtime.obtener_equipo("mano_derecha").get("id", "")) != "axe_c":
		errors.append("El fallo por inventario lleno perdió el equipo.")

	# Con espacio libre, devuelve el objeto y limpia el slot de equipo.
	runtime.state.items[17] = {}
	if not runtime.desequipar_a_inventario("mano_derecha"):
		errors.append("No devolvió el equipo al inventario cuando había espacio.")
	if not runtime.obtener_equipo("mano_derecha").is_empty():
		errors.append("No limpió el slot de equipo tras devolver el objeto.")
	if str(runtime.state.items[17].get("id", "")) != "armor_b":
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

	runtime.equipar("torso", {
		"id": "armor_worn",
		"nombre": "Armadura",
		"tipo": "armadura",
		"propiedades_game": {"ranura_equipamiento": "torso", "durabilidad": 1},
		"durabilidad_actual": 1
	})
	if not runtime.consumir_durabilidad_equipo("torso"):
		errors.append("No consumió durabilidad de un objeto equipado.")
	if not runtime.obtener_equipo("torso").is_empty():
		errors.append("No retiró el equipo al agotar su durabilidad.")

	# La defensa acepta las dos estructuras de datos que llegan del catálogo,
	# sin sumar dos veces la misma estadística.
	var defensa_catalogo := CombatDefenseScript.obtener_defensa({
		"casco": {"tipo": "armadura", "propiedades_game": {"defensa": 2}},
		"torso": {"tipo": "armadura", "estadisticas": {"defensa": 3}, "propiedades_game": {"defensa": 99}},
		"pies": {"tipo": "armadura", "defensa": 1}
	})
	if not is_equal_approx(defensa_catalogo, 6.0):
		errors.append("No resolvió correctamente defensa desde propiedades, estadísticas y campo raíz.")

	if not errors.is_empty():
		for error in errors:
			push_error("InventoryEquipmentTransaction: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryEquipmentTransaction: PASS")
	get_tree().quit(0)
