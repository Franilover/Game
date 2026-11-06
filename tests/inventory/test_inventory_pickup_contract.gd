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

	_finalizar(errores)


func _finalizar(errores: Array[String]) -> void:
	if not errores.is_empty():
		for error in errores:
			push_error("InventoryPickupContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("InventoryPickupContract: PASS")
	get_tree().quit(0)
