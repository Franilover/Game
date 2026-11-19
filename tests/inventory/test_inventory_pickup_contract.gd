extends Node

const RuntimeScript = preload("res://scripts/gameplay/inventory/inventory_runtime.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var runtime := RuntimeScript.new() as InventoryRuntime
	var items: Array = []

	for i in range(18):
		items.append({
			"id": "ocupado_%d" % i,
			"nombre": "Ocupado %d" % i,
			"cantidad": 1,
			"max_stack": 1
		})

	items[6] = {
		"id": "mineral",
		"nombre": "Mineral",
		"cantidad": 9,
		"max_stack": 10
	}
	runtime.establecer_items(items)

	var solicitud := {
		"id": "mineral",
		"nombre": "Mineral",
		"cantidad": 3,
		"max_stack": 10
	}
	var resultado_rechazado := runtime.agregar_objeto(solicitud)
	if resultado_rechazado:
		errores.append("Se aceptó una recogida que excedía la capacidad.")
	if int(runtime.state.items[6].get("cantidad", 0)) != 9:
		errores.append("La recogida rechazada dejó unidades apiladas parcialmente.")
	for i in range(18):
		if i == 6:
			continue
		if str(runtime.state.items[i].get("id", "")) != "ocupado_%d" % i:
			errores.append("La recogida rechazada alteró el slot %d." % i)
			break

	# Con un slot libre, la misma solicitud debe apilar y colocar el remanente.
	items[17] = {}
	runtime.establecer_items(items)
	var resultado_aceptado := runtime.agregar_objeto(solicitud)
	if not resultado_aceptado:
		errores.append("Se rechazó una recogida que cabía entre pila y slot libre.")
	if int(runtime.state.items[6].get("cantidad", 0)) != 10:
		errores.append("La pila compatible no llegó al límite esperado.")
	if (
		str(runtime.state.items[17].get("id", "")) != "mineral"
		or int(runtime.state.items[17].get("cantidad", 0)) != 2
	):
		errores.append("El remanente no se colocó íntegro en el slot libre.")

	var total_mineral := 0
	for item in runtime.state.items:
		if str(item.get("id", "")) == "mineral":
			total_mineral += int(item.get("cantidad", 0))
	if total_mineral != 12:
		errores.append("La transferencia válida no conservó la cantidad total.")

	_probar_identidad_de_apilado(errores)
	_finalizar(errores)


func _probar_identidad_de_apilado(errores: Array[String]) -> void:
	var runtime := RuntimeScript.new() as InventoryRuntime
	var items: Array = []
	for i in range(18):
		items.append({})
	items[6] = {
		"id": "madera_id_a",
		"nombre": "Madera",
		"cantidad": 4,
		"max_stack": 10
	}
	items[17] = {}
	runtime.establecer_items(items)

	# Un objeto sin ID no debe fusionarse con otro que sí tiene identidad.
	var sin_id := {"nombre": "Madera", "cantidad": 2, "max_stack": 10}
	if not runtime.agregar_objeto(sin_id):
		errores.append("No aceptó el objeto sin ID en un slot libre.")
	if int(runtime.state.items[6].get("cantidad", 0)) != 4:
		errores.append("Fusionó un objeto sin ID con una pila identificada.")
	if int(runtime.state.items[7].get("cantidad", 0)) != 2:
		errores.append("No conservó el objeto sin ID en un slot separado.")

	# Dos IDs distintos nunca se fusionan aunque el nombre coincida.
	var otro_id := {"id": "madera_id_b", "nombre": "Madera", "cantidad": 1, "max_stack": 10}
	if not runtime.agregar_objeto(otro_id):
		errores.append("No aceptó un objeto con identidad distinta en los slots libres.")
	if int(runtime.state.items[6].get("cantidad", 0)) != 4:
		errores.append("Fusionó dos IDs distintos por compartir nombre.")

	# Los datos antiguos sin ID conservan el fallback por nombre.
	var legacy := RuntimeScript.new() as InventoryRuntime
	var legacy_items: Array = []
	for i in range(18):
		legacy_items.append({})
	legacy_items[6] = {"nombre": "Piedra", "cantidad": 3, "max_stack": 10}
	legacy.establecer_items(legacy_items)
	if not legacy.agregar_objeto({"nombre": "Piedra", "cantidad": 2, "max_stack": 10}):
		errores.append("Rechazó el apilado por nombre de objetos legacy sin ID.")
	if int(legacy.state.items[6].get("cantidad", 0)) != 5:
		errores.append("No conservó el fallback de apilado legacy por nombre.")



func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("InventoryPickupContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryPickupContract: PASS")
	get_tree().quit(0)
