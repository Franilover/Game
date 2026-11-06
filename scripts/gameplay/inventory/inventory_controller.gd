extends Node
class_name InventoryController

func _garlia_debug() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("GarliaDebug")




## Coordina el runtime del inventario con una implementación de UI.
## No contiene el estado canónico de items, hotbar o equipamiento.

signal inventario_cambio
signal hotbar_cambio(indice: int)
signal equipo_cambio(slot: String, item: Dictionary)
signal mano_objeto_cambiado(mano: String, slot_index: int, item: Dictionary)

var runtime := InventoryRuntime.new()
var input_gate: GameplayInputGate = null
var mano_izquierda_activa: int = 0
var mano_derecha_activa: int = 0

func configurar_gate(gate: GameplayInputGate) -> void:
	input_gate = gate

func puede_interactuar() -> bool:
	if input_gate == null or not is_instance_valid(input_gate):
		return true
	return not input_gate.esta_bloqueado()

func configurar_items(items: Array, hotbar_indices: Array = []) -> void:
	runtime.establecer_items(items)
	runtime.hotbar.configurar(hotbar_indices)
	inventario_cambio.emit()
	hotbar_cambio.emit(runtime.hotbar.indice_activo)

func cargar_items(items: Array) -> void:
	runtime.establecer_items(items)
	inventario_cambio.emit()
 
func obtener_item(indice: int) -> Dictionary:
	return runtime.obtener_item(indice)

func seleccionar_slot_mano(mano: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= 6:
		return false
	if mano == "izquierda":
		mano_izquierda_activa = slot_index
	elif mano == "derecha":
		mano_derecha_activa = slot_index
	else:
		return false
	return true


func obtener_indice_mano_activa(mano: String) -> int:
	if mano == "izquierda":
		return mano_izquierda_activa
	if mano == "derecha":
		return 12 + mano_derecha_activa
	return -1


func obtener_objeto_mano_activa(mano: String) -> Dictionary:
	return runtime.obtener_item(obtener_indice_mano_activa(mano))


func usar_objeto_mano(mano: String, usuario: Player = null) -> bool:
	if mano not in ["izquierda", "derecha"]:
		return false
	return usar_objeto_en_indice(obtener_indice_mano_activa(mano), usuario, mano)


func usar_objeto_en_indice(
	indice: int,
	usuario: Player = null,
	mano: String = ""
) -> bool:
	if not puede_interactuar():
		return false
	if indice < 0:
		return false

	var objeto := runtime.obtener_item(indice)
	if objeto.is_empty():
		return false

	var uso := _obtener_definicion_uso(objeto)
	if uso.is_empty():
		return false

	if usuario == null or not is_instance_valid(usuario):
		return false

	var efectos_aplicados := _aplicar_efectos_uso(uso, usuario)
	if efectos_aplicados <= 0:
		return false

	if not quitar_cantidad(indice, 1):
		return false

	Events.notification_pushed.emit(
		"Usaste " + str(objeto.get("nombre", "Objeto"))
	)
	if mano in ["izquierda", "derecha"]:
		_emitir_mano_objeto_cambiado(mano)
	return true


func consumir_objeto_mano(mano: String, cantidad: int = 1) -> bool:
	if mano not in ["izquierda", "derecha"]:
		return false
	var indice := obtener_indice_mano_activa(mano)
	if not quitar_cantidad(indice, maxi(1, cantidad)):
		return false
	_emitir_mano_objeto_cambiado(mano)
	return true


func _emitir_mano_objeto_cambiado(mano: String) -> void:
	var indice := obtener_indice_mano_activa(mano)
	if indice < 0:
		return
	var slot_index := mano_izquierda_activa if mano == "izquierda" else mano_derecha_activa
	mano_objeto_cambiado.emit(
		mano,
		slot_index,
		runtime.obtener_item(indice)
	)


func _obtener_definicion_uso(objeto: Dictionary) -> Dictionary:
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if not propiedades_variant is Dictionary:
		return {}

	var propiedades := propiedades_variant as Dictionary
	var uso_variant: Variant = propiedades.get("uso", {})
	if not uso_variant is Dictionary:
		return {}

	var uso := uso_variant as Dictionary
	if not bool(uso.get("permitido", true)):
		return {}

	if str(uso.get("tipo", "")).strip_edges().is_empty():
		return {}
	return uso.duplicate(true)


func _aplicar_efectos_uso(uso: Dictionary, actor: Player) -> int:
	var aplicados := 0
	var efectos_variant: Variant = uso.get("efectos", null)
	if efectos_variant is Array:
		for efecto_variant in efectos_variant as Array:
			if not efecto_variant is Dictionary:
				continue
			if _aplicar_efecto_recurso(efecto_variant as Dictionary, actor):
				aplicados += 1
		return aplicados

	if _aplicar_efecto_recurso(uso.duplicate(true), actor):
		aplicados += 1
	return aplicados


func _aplicar_efecto_recurso(efecto: Dictionary, actor: Player) -> bool:
	var recurso := str(
		efecto.get("recurso", efecto.get("efecto", ""))
	).strip_edges().to_lower()
	var magnitud_variant: Variant = efecto.get(
		"magnitud",
		efecto.get("cantidad", 0)
	)
	if not (magnitud_variant is int or magnitud_variant is float):
		return false

	var magnitud := maxf(float(magnitud_variant), 0.0)
	if magnitud <= 0.0:
		return false

	match recurso:
		"vida", "salud", "health":
			var antes := actor.health
			if antes >= actor.max_health:
				return false
			actor.heal(roundi(magnitud))
			return actor.health > antes
		"stamina":
			var antes_stamina := actor.stamina
			if antes_stamina >= actor.max_stamina:
				return false
			return actor.restaurar_stamina(magnitud)
		"eterium", "mana":
			var antes_eterium := actor.mana
			if antes_eterium >= actor.max_mana:
				return false
			return actor.restaurar_eterium(magnitud)

	return false

func consumir_durabilidad_mano_activa(mano: String) -> bool:
	if mano not in ["izquierda", "derecha"]:
		return false
	var indice := obtener_indice_mano_activa(mano)
	if indice < 0 or not consumir_durabilidad(indice):
		return false
	_emitir_mano_objeto_cambiado(mano)
	return true

func agregar_objeto(datos: Dictionary) -> bool:
	if not puede_interactuar():
		_garlia_debug().call("registrar", "INVENTORY", "agregar_objeto bloqueado por GameplayInputGate.")
		_garlia_debug().call("flujo_error", "InventoryController bloqueó agregar_objeto por GameplayInputGate.")
		return false
	if datos.is_empty():
		_garlia_debug().call("flujo_error", "InventoryController recibió objeto vacío.")
		return false
	var resultado: bool = runtime.agregar_objeto(datos)
	if resultado:
		_garlia_debug().call("flujo_paso", "InventoryController aceptó el objeto.")
		inventario_cambio.emit()
	return resultado

func quitar_cantidad(indice: int, cantidad: int = 1) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.quitar_cantidad(indice, cantidad)
	if resultado:
		inventario_cambio.emit()
	return resultado

func quitar_objeto(indice: int) -> bool:
	return quitar_cantidad(indice, 999999)

func soltar_objeto_al_mundo(
	indice: int,
	posicion: Vector2,
	world_items: GarliaWorldItems
) -> bool:
	if indice < 0 or indice >= runtime.state.items.size():
		return false
	if world_items == null or not is_instance_valid(world_items):
		return false
	# El controller usa el objeto actual del runtime, nunca una copia antigua
	# que la UI haya conservado durante el arrastre.
	var objeto := runtime.obtener_item(indice)
	if objeto.is_empty():
		return false
	# La creación/registración en el mundo ocurre antes de retirar el origen.
	if not world_items.soltar_objeto_al_mundo(objeto, posicion):
		return false
	return quitar_objeto(indice)

func establecer_objeto(indice: int, datos: Dictionary) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.establecer_objeto(indice, datos)
	if resultado:
		inventario_cambio.emit()
	return resultado

func intercambiar_o_apilar(origen: int, destino: int) -> bool:
	# Mover/apilar ranuras es una operación de la UI. El input gate bloquea
	# acciones del personaje mientras el inventario está abierto, así que no
	# debe bloquear esta operación interna.
	var resultado: bool = runtime.intercambiar_o_apilar(origen, destino)
	if resultado:
		inventario_cambio.emit()
	return resultado

func seleccionar_hotbar(indice: int) -> bool:
	if not runtime.seleccionar_hotbar(indice):
		return false
	hotbar_cambio.emit(runtime.hotbar.indice_activo)
	return true

func equipar(slot: String, item: Dictionary) -> void:
	runtime.equipar(slot, item)
	equipo_cambio.emit(slot, item.duplicate(true))

func desequipar(slot: String) -> Dictionary:
	var anterior := runtime.desequipar(slot)
	equipo_cambio.emit(slot, {})
	return anterior

func obtener_equipo(slot: String) -> Dictionary:
	return runtime.obtener_equipo(slot)

func obtener_equipamiento() -> Dictionary:
	return runtime.obtener_equipamiento()

func serializar() -> Dictionary:
	return {
		"items": runtime.state.items.duplicate(true),
		"hotbar_indices": runtime.hotbar.indices.duplicate(),
		"indice_hotbar_activo": runtime.hotbar.indice_activo,
		"equipo": runtime.equipment.state.slots.duplicate(true)
	}

func equipar_desde_inventario(slot: String, indice: int, item: Dictionary) -> bool:
	# Equipar desde la interfaz es una acción de inventario, no una entrada
	# de gameplay. El gate bloquea movimiento/combate, no operaciones de UI.
	var resultado: bool = runtime.equipar_desde_inventario(slot, indice, item)
	if resultado:
		equipo_cambio.emit(slot, runtime.obtener_equipo(slot))
		inventario_cambio.emit()
	return resultado

func desequipar_a_inventario(slot: String) -> bool:
	# La interfaz debe poder devolver objetos al inventario aunque el gate
	# esté bloqueando las acciones del personaje.
	var resultado: bool = runtime.desequipar_a_inventario(slot)
	if resultado:
		equipo_cambio.emit(slot, {})
		inventario_cambio.emit()
	return resultado

func establecer_hotbar_slot(indice_hotbar: int, indice_inventario: int) -> bool:
	if not puede_interactuar():
		return false
	if not runtime.establecer_hotbar_slot(indice_hotbar, indice_inventario):
		return false
	hotbar_cambio.emit(indice_hotbar)
	return true

func consumir_durabilidad(indice: int) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.consumir_durabilidad(indice)
	if resultado:
		inventario_cambio.emit()
	return resultado

func limpiar() -> void:
	runtime.limpiar()
	inventario_cambio.emit()

func robar_objeto_equipado(slot: String) -> Dictionary:
	if not puede_interactuar():
		return {}
	var objeto := runtime.robar_equipamiento(slot)
	if objeto.is_empty():
		return {}
	equipo_cambio.emit(slot, {})
	inventario_cambio.emit()
	return objeto

func consumir_durabilidad_equipo(slot: String) -> bool:
	if not puede_interactuar():
		return false
	var resultado: bool = runtime.consumir_durabilidad_equipo(slot)
	if resultado:
		equipo_cambio.emit(slot, runtime.obtener_equipo(slot))
		inventario_cambio.emit()
	return resultado

func obtener_objeto_equipado(slot: String = "mano_secundaria") -> Dictionary:
	return runtime.obtener_equipo(slot)
