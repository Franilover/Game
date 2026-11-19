extends Node

const RuntimeScript = preload("res://scripts/gameplay/inventory/inventory_runtime.gd")
const WorldItemsScript = preload("res://scripts/infrastructure/garlia_world_items.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var runtime := RuntimeScript.new() as InventoryRuntime

	var base := {
		"id": "carta_aoris_id",
		"item_id": "carta_aoris_id",
		"nombre": "Carta Aoris",
		"descripcion": "Una carta con alas.",
		"max_stack": 10,
		"cantidad": 5
	}
	var ejemplar := {
		"id": "carta_aoris_id",
		"item_id": "carta_aoris_id",
		"nombre": "Carta Aoris de Elian",
		"nombre_sprite": "Carta Aoris",
		"ejemplar_id": "ejemplar_elian",
		"es_ejemplar": true,
		"descripcion_detallada": "Descripción única de prueba.",
		"max_stack": 1,
		"cantidad": 1
	}

	var items: Array = []
	for i in range(18):
		items.append({})
	items[6] = base.duplicate(true)
	runtime.establecer_items(items)
	if not runtime.agregar_objeto(ejemplar):
		errores.append("No se pudo insertar el ejemplar en un slot libre.")
	if int(runtime.state.items[6].get("cantidad", 0)) != 5:
		errores.append("El ejemplar se apiló dentro del objeto base.")
	var indice_ejemplar := -1
	for i in range(runtime.state.items.size()):
		if str(runtime.state.items[i].get("ejemplar_id", "")) == "ejemplar_elian":
			indice_ejemplar = i
			break
	if indice_ejemplar < 0:
		errores.append("El inventario no conservó el identificador del ejemplar.")

	var otro_ejemplar := ejemplar.duplicate(true)
	otro_ejemplar["ejemplar_id"] = "ejemplar_otro"
	if not runtime.agregar_objeto(otro_ejemplar):
		errores.append("No se pudo insertar un segundo ejemplar.")
	if indice_ejemplar >= 0 and int(runtime.state.items[indice_ejemplar].get("cantidad", 0)) != 1:
		errores.append("Dos ejemplares distintos se fusionaron.")

	var world_items := WorldItemsScript.new() as GarliaWorldItems
	world_items._items_por_id["carta_aoris_id"] = {
		"item_id": "carta_aoris_id",
		"id": "carta_aoris_id",
		"nombre": "Carta Aoris",
		"descripcion": "Descripción base.",
		"max_stack": 10,
		"tipo": "documento",
		"propiedades_game": {"peso": 1}
	}
	world_items._ejemplares_por_id["ejemplar_elian"] = {
		"id": "ejemplar_elian",
		"item_base_id": "carta_aoris_id",
		"nombre": "Carta Aoris de Elian",
		"descripcion": "",
		"descripcion_detallada": "Descripción única.",
		"vinculos": [{"tipo_vinculo": "personaje", "personaje_id": "elian_id"}],
		"metadatos": {}
	}
	var resuelto := world_items.crear_datos_ejemplar("ejemplar_elian")
	if str(resuelto.get("nombre", "")) != "Carta Aoris de Elian":
		errores.append("El nombre propio del ejemplar no se resolvió.")
	if str(resuelto.get("nombre_sprite", "")) != "Carta Aoris":
		errores.append("El ejemplar no heredó el nombre del sprite base.")
	if str(resuelto.get("descripcion", "")) != "Descripción base.":
		errores.append("La descripción común no se heredó correctamente.")
	if str(resuelto.get("descripcion_detallada", "")) != "Descripción única.":
		errores.append("La descripción detallada única no se resolvió.")
	if int(resuelto.get("max_stack", 0)) != 1:
		errores.append("El ejemplar no quedó marcado como no apilable.")
	if (resuelto.get("propiedades_game", {}) as Dictionary).get("peso", 0) != 1:
		errores.append("El ejemplar no heredó las propiedades del objeto base.")

	world_items.free()
	runtime.free()
	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("InventoryExemplarContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryExemplarContract: PASS")
	get_tree().quit(0)
