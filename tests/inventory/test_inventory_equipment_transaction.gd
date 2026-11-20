extends Node

const RuntimeScript = preload("res://scripts/gameplay/inventory/inventory_runtime.gd")
const CombatDefenseScript = preload("res://scripts/gameplay/combat/combat_defense.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var runtime := RuntimeScript.new() as InventoryRuntime

	# Restaurar equipamiento sustituye el estado anterior y valida cada ranura.
	runtime.equipar("torso", _crear_armadura("armor_stale", "Armadura anterior", "torso", 2))
	var equipo_guardado := {
		"cabeza": _crear_armadura("helmet_saved", "Casco guardado", "cabeza", 3),
		"torso": {"id": "invalid_saved", "tipo": "arma"},
		"mano_principal": {"id": "legacy_saved", "tipo": "arma"}
	}
	runtime.establecer_equipamiento(equipo_guardado)
	if str(runtime.obtener_equipo("cabeza").get("id", "")) != "helmet_saved":
		errores.append("No restauró la armadura válida del snapshot.")
	if not runtime.obtener_equipo("torso").is_empty():
		errores.append("Conservó equipo anterior o aceptó un objeto incompatible al restaurar.")
	if runtime.obtener_equipamiento().has("mano_principal"):
		errores.append("Restauró una ranura de arma heredada.")

	var items: Array = []
	for i in range(18):
		items.append({})
	items[6] = _crear_armadura("armor_a", "Armadura A", "torso", 2)
	runtime.establecer_items(items)

	# El runtime usa el objeto canónico del slot, no la copia entregada por UI.
	var stale_copy := {"id": "sword_b", "nombre": "Espada B", "tipo": "arma"}
	if not runtime.equipar_desde_inventario("torso", 6, stale_copy):
		errors.append("No equipó una armadura válida desde el inventario.")
	if str(runtime.obtener_equipo("torso").get("id", "")) != "armor_a":
		errors.append("Equipó la copia obsoleta de la UI en vez del objeto canónico.")
	if not runtime.state.items[6].is_empty():
		errors.append("No retiró la armadura equipada de su slot de inventario.")

	# El dominio rechaza armas, ranuras cruzadas y claves desconocidas.
	items[9] = {"id": "weapon_x", "nombre": "Espada", "tipo": "arma"}
	items[10] = _crear_armadura("helmet_x", "Casco", "cabeza", 1)
	runtime.establecer_items(items)
	if runtime.equipar_desde_inventario("torso", 9, {}):
		errors.append("Permitió equipar un arma como armadura.")
	if runtime.equipar_desde_inventario("torso", 10, {}):
		errors.append("Permitió colocar una armadura en una ranura incorrecta.")
	if runtime.equipar_desde_inventario("arma", 10, {}):
		errors.append("Permitió crear una ranura de equipo desconocida.")
	if str(runtime.obtener_equipo("torso").get("id", "")) != "armor_a":
		errors.append("Una operación incompatible alteró la armadura equipada.")
	if str(runtime.state.items[9].get("id", "")) != "weapon_x" or str(runtime.state.items[10].get("id", "")) != "helmet_x":
		errors.append("Una operación incompatible modificó los objetos de origen.")

	# Un índice vacío no debe reemplazar ni borrar el equipo existente.
	if runtime.equipar_desde_inventario("torso", 7, stale_copy):
		errors.append("Permitió equipar desde un slot vacío.")
	if str(runtime.obtener_equipo("torso").get("id", "")) != "armor_a":
		errors.append("Una operación inválida alteró el equipo existente.")

	# Reemplazar equipo devuelve el anterior al mismo slot de origen.
	items[8] = _crear_armadura("armor_b", "Armadura B", "torso", 3)
	runtime.establecer_items(items)
	if not runtime.equipar_desde_inventario("torso", 8, {}):
		errors.append("No pudo intercambiar la armadura equipada.")
	if str(runtime.obtener_equipo("torso").get("id", "")) != "armor_b":
		errors.append("La nueva armadura no quedó equipada.")
	if str(runtime.state.items[8].get("id", "")) != "armor_a":
		errors.append("La armadura anterior no regresó al slot de origen.")

	# Sin espacio libre, desequipar falla sin perder el objeto.
	var full_items: Array = []
	for i in range(18):
		full_items.append({"id": "full_%d" % i, "nombre": "Lleno", "cantidad": 1, "max_stack": 1})
	runtime.establecer_items(full_items)
	if runtime.desequipar_a_inventario("torso"):
		errors.append("Desequipó aunque el inventario estaba lleno.")
	if str(runtime.obtener_equipo("torso").get("id", "")) != "armor_b":
		errors.append("El fallo por inventario lleno perdió la armadura.")

	# Con espacio libre, devuelve el objeto y limpia la ranura.
	runtime.state.items[17] = {}
	if not runtime.desequipar_a_inventario("torso"):
		errors.append("No devolvió la armadura cuando había espacio.")
	if not runtime.obtener_equipo("torso").is_empty():
		errors.append("No limpió la ranura tras devolver la armadura.")
	if str(runtime.state.items[17].get("id", "")) != "armor_b":
		errors.append("No conservó la armadura devuelta al inventario.")

	# La durabilidad sigue una única regla para mochila y equipo.
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
		errors.append("No retiró el objeto al agotar su durabilidad.")

	runtime.equipar("torso", _crear_armadura("armor_worn", "Armadura gastada", "torso", 1))
	if not runtime.consumir_durabilidad_equipo("torso"):
		errors.append("No consumió durabilidad de una armadura equipada.")
	if not runtime.obtener_equipo("torso").is_empty():
		errors.append("No retiró la armadura al agotar su durabilidad.")

	# El controlador expone la misma sustitución al flujo de carga de la UI.
	var controller := InventoryController.new()
	controller.runtime.equipar("pies", _crear_armadura("boots_stale", "Botas anteriores", "pies", 2))
	controller.establecer_equipamiento({"cabeza": _crear_armadura("helmet_controller", "Casco", "cabeza", 1)})
	if not controller.obtener_equipo("pies").is_empty():
		errores.append("El controlador conservó equipo de la partida anterior.")
	if str(controller.obtener_equipo("cabeza").get("id", "")) != "helmet_controller":
		errores.append("El controlador no restauró el equipo validado.")
	controller.free()

	# Las operaciones públicas de equipo no admiten las antiguas ranuras de armas.
	runtime.equipar("mano_principal", {"id": "legacy_weapon", "tipo": "arma"})
	if runtime.consumir_durabilidad_equipo("mano_principal"):
		errors.append("Consumió durabilidad mediante una ranura de arma heredada.")
	if runtime.desequipar_a_inventario("mano_principal"):
		errors.append("Permitió devolver equipo desde una ranura de arma heredada.")
	if not runtime.obtener_equipo("mano_principal").is_empty():
		errors.append("Permitió insertar una entrada de arma en Equipment.")

	# La defensa lee estructuras del catálogo sin duplicar la misma estadística.
	var defensa_catalogo := CombatDefenseScript.obtener_defensa({
		"cabeza": {"tipo": "armadura", "propiedades_game": {"defensa": 2}},
		"torso": {"tipo": "armadura", "estadisticas": {"defensa": 3}, "propiedades_game": {"defensa": 99}},
		"pies": {"tipo": "armadura", "defensa": 1},
		"mano_principal": {"tipo": "arma", "defensa": 100}
	})
	if not is_equal_approx(defensa_catalogo, 6.0):
		errors.append("No resolvió defensa por ranura o contó una ranura de mano antigua.")

	# La conversión de defensa a daño entero debe ser estable y nunca negativa.
	if CombatDefenseScript.aplicar(10, defensa_catalogo) != 4:
		errors.append("No restó la defensa al daño recibido.")
	if CombatDefenseScript.aplicar(6, defensa_catalogo) != 0:
		errors.append("No bloqueó el daño cuando la defensa igualó el impacto.")
	if CombatDefenseScript.aplicar(0, defensa_catalogo) != 0:
		errors.append("Un impacto nulo produjo daño.")
	if CombatDefenseScript.aplicar(5, -2.0) != 5:
		errors.append("Una defensa negativa aumentó el daño recibido.")
	if CombatDefenseScript.aplicar(5, 1.5) != 4:
		errors.append("No redondeó de forma conservadora el daño fraccionario.")

	# Una fuente mal formada no debe ocultar una fuente posterior válida.
	var defensa_fallback := CombatDefenseScript.obtener_defensa({
		"torso": {
			"estadisticas": {"defensa": "invalida"},
			"propiedades_game": {"defensa": 2}
		}
	})
	if not is_equal_approx(defensa_fallback, 2.0):
		errors.append("Una estadística mal formada ocultó la defensa válida de respaldo.")

	if not errors.is_empty():
		for error in errors:
			push_error("InventoryEquipmentTransaction: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryEquipmentTransaction: PASS")
	get_tree().quit(0)


func _crear_armadura(id: String, nombre: String, ranura: String, durabilidad: int) -> Dictionary:
	return {
		"id": id,
		"nombre": nombre,
		"tipo": "armadura",
		"cantidad": 1,
		"max_stack": 1,
		"propiedades_game": {
			"ranura_equipamiento": ranura,
			"durabilidad": durabilidad
		},
		"durabilidad_actual": durabilidad
	}
