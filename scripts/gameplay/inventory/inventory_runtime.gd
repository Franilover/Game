extends RefCounted
class_name InventoryRuntime

## Estado runtime del inventario.
## Objetos, hotbar y equipamiento son estados independientes.

var state := InventoryState.new()
var hotbar := InventoryHotbarState.new()
var equipment := InventoryEquipment.new()

func limpiar() -> void:
	state.limpiar()
	hotbar.configurar([])
	equipment.limpiar()

func establecer_items(items: Array) -> void:
	state.establecer_items(items)

func obtener_item(indice: int) -> Dictionary:
	return state.obtener_item(indice)

func seleccionar_hotbar(indice: int) -> bool:
	return hotbar.seleccionar(indice)

func establecer_equipamiento(equipamiento: Dictionary) -> void:
	equipment.limpiar()
	for clave_variant in equipamiento.keys():
		var clave := str(clave_variant)
		var item_variant: Variant = equipamiento.get(clave, {})
		if item_variant is Dictionary and not (item_variant as Dictionary).is_empty():
			equipment.equipar(clave, item_variant as Dictionary)

func equipar(slot: String, item: Dictionary) -> void:
	equipment.equipar(slot, item)

func desequipar(slot: String) -> Dictionary:
	return equipment.desequipar(slot)

func obtener_equipo(slot: String) -> Dictionary:
	return equipment.obtener(slot)

func obtener_equipamiento() -> Dictionary:
	return equipment.state.slots.duplicate(true)

func agregar_objeto(datos: Dictionary) -> bool:
	if datos.is_empty():
		return false
	var objeto := datos.duplicate(true)
	var cantidad: int = maxi(1, int(objeto.get("cantidad", 1)))
	var max_stack: int = maxi(1, int(objeto.get("max_stack", 1)))
	objeto["cantidad"] = cantidad
	objeto["max_stack"] = max_stack
	var restante := cantidad
	if max_stack > 1:
		for i in range(state.items.size()):
			if restante <= 0:
				break
			var existente: Dictionary = state.items[i]
			if existente.is_empty():
				continue
			if not _puede_apilar_con(existente, objeto):
				continue
			var ocupacion := maxi(1, int(existente.get("cantidad", 1)))
			var capacidad := max_stack - ocupacion
			if capacidad <= 0:
				continue
			var anadido := mini(restante, capacidad)
			state.items[i]["cantidad"] = ocupacion + anadido
			restante -= anadido
	if restante > 0:
		for i in range(state.items.size()):
			if restante <= 0:
				break
			if not state.items[i].is_empty():
				continue
			var lote := mini(restante, max_stack)
			var nuevo := objeto.duplicate(true)
			nuevo["cantidad"] = lote
			state.items[i] = nuevo
			restante -= lote
	return restante <= 0

func quitar_cantidad(indice: int, cantidad: int = 1) -> bool:
	if indice < 0 or indice >= state.items.size() or state.items[indice].is_empty():
		return false
	var actual := maxi(1, int(state.items[indice].get("cantidad", 1)))
	var quitar := maxi(1, cantidad)
	if quitar >= actual:
		state.items[indice] = {}
	else:
		state.items[indice]["cantidad"] = actual - quitar
	return true

func establecer_objeto(indice: int, datos: Dictionary) -> bool:
	if indice < 0 or indice >= state.items.size():
		return false
	state.items[indice] = datos.duplicate(true)
	return true

func intercambiar_o_apilar(origen: int, destino: int) -> bool:
	if origen < 0 or destino < 0 or origen >= state.items.size() or destino >= state.items.size() or origen == destino:
		return false
	var a: Dictionary = state.items[origen].duplicate(true)
	var b: Dictionary = state.items[destino].duplicate(true)
	if a.is_empty():
		return false
	if not b.is_empty() and _puede_apilar_con(b, a):
		var max_stack := maxi(1, int(b.get("max_stack", 1)))
		var cantidad_b := maxi(1, int(b.get("cantidad", 1)))
		var cantidad_a := maxi(1, int(a.get("cantidad", 1)))
		var espacio := max_stack - cantidad_b
		if espacio > 0:
			var movido := mini(espacio, cantidad_a)
			b["cantidad"] = cantidad_b + movido
			cantidad_a -= movido
			state.items[destino] = b
			if cantidad_a <= 0:
				state.items[origen] = {}
			else:
				a["cantidad"] = cantidad_a
				state.items[origen] = a
			return true
	state.items[origen] = b
	state.items[destino] = a
	return true

func _puede_apilar_con(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	var max_a := maxi(1, int(a.get("max_stack", 1)))
	var max_b := maxi(1, int(b.get("max_stack", 1)))
	if max_a <= 1 or max_b <= 1:
		return false
	var id_a := str(a.get("id", a.get("item_id", ""))).strip_edges()
	var id_b := str(b.get("id", b.get("item_id", ""))).strip_edges()
	if not id_a.is_empty() and not id_b.is_empty():
		return id_a == id_b
	var nombre_a := str(a.get("nombre", "")).strip_edges().to_lower()
	var nombre_b := str(b.get("nombre", "")).strip_edges().to_lower()
	return not nombre_a.is_empty() and nombre_a == nombre_b

func equipar_desde_inventario(slot: String, indice: int, item: Dictionary) -> bool:
	if indice < 0 or indice >= state.items.size() or item.is_empty():
		return false
	var anterior := equipment.obtener(slot)
	state.items[indice] = anterior.duplicate(true) if not anterior.is_empty() else {}
	equipment.equipar(slot, item)
	return true

func desequipar_a_inventario(slot: String) -> bool:
	var objeto := equipment.obtener(slot)
	if objeto.is_empty():
		return false
	var libre := -1
	for i in range(state.items.size()):
		if state.items[i].is_empty():
			libre = i
			break
	if libre < 0:
		return false
	state.items[libre] = objeto.duplicate(true)
	equipment.desequipar(slot)
	return true

func establecer_hotbar_slot(indice_hotbar: int, indice_inventario: int) -> bool:
	if indice_hotbar < 0 or indice_hotbar >= hotbar.indices.size():
		return false
	if indice_inventario < 0 or indice_inventario >= state.items.size():
		return false
	hotbar.indices[indice_hotbar] = indice_inventario
	return true

func consumir_durabilidad(indice: int) -> bool:
	if indice < 0 or indice >= state.items.size() or state.items[indice].is_empty():
		return false
	var objeto: Dictionary = state.items[indice]
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if not propiedades_variant is Dictionary:
		return false
	var propiedades: Dictionary = propiedades_variant as Dictionary
	var maxima_variant: Variant = propiedades.get("durabilidad", null)
	if not (maxima_variant is int or maxima_variant is float):
		return false
	var maxima := maxi(1, int(maxima_variant))
	var actual := maxi(0, int(objeto.get("durabilidad_actual", maxima))) - 1
	if actual <= 0:
		state.items[indice] = {}
	else:
		state.items[indice]["durabilidad_actual"] = actual
	return true

func robar_equipamiento(slot: String) -> Dictionary:
	var objeto := equipment.desequipar(slot)
	return objeto

func consumir_durabilidad_equipo(slot: String) -> bool:
	var objeto := equipment.obtener(slot)
	if objeto.is_empty():
		return false
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if not propiedades_variant is Dictionary:
		return false
	var propiedades := propiedades_variant as Dictionary
	var maxima_variant: Variant = propiedades.get("durabilidad", null)
	if not (maxima_variant is int or maxima_variant is float):
		return false
	var maxima := maxi(1, int(maxima_variant))
	var actual := maxi(0, int(objeto.get("durabilidad_actual", maxima))) - 1
	if actual <= 0:
		equipment.desequipar(slot)
	else:
		objeto["durabilidad_actual"] = actual
		equipment.equipar(slot, objeto)
	return true
