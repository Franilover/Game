extends Node2D
## Permite rellenar una regadera en un pozo y regar los bancales del vivero.
## El nivel de agua viaja dentro de los datos del objeto y se guarda con el inventario.

const AGUA_MAXIMA := 4
const ICONOS_REGADERA := {
	4: "res://assets/art/items/regadera llena.png",
	3: "res://assets/art/items/regadera casi llena.png",
	2: "res://assets/art/items/regadera media.png",
	1: "res://assets/art/items/regadera casi vacia.png",
	0: "res://assets/art/items/regadera vacia.png"
}
const COLOR_TIERRA_SECA := Color("#765039")
const COLOR_TIERRA_HUMEDA := Color("#52606A")

var _tipo := "bancal"
var _clave := ""
var _distancia := 76.0
var _tierra: Polygon2D = null
var _humedo := false


func configurar_parcela(clave: String) -> void:
	_tipo = "bancal"
	_clave = clave.strip_edges()
	_distancia = 82.0
	_tierra = get_node_or_null("Tierra") as Polygon2D
	add_to_group("interactable")
	_cargar_estado_parcela()


func configurar_pozo() -> void:
	_tipo = "pozo"
	_clave = "pozo"
	_distancia = 88.0
	add_to_group("interactable")


func es_recolectable() -> bool:
	return true


func get_interaction_distance() -> float:
	return _distancia


func get_interaction_priority() -> int:
	return 145 if _tipo == "pozo" else 115


func get_interaction_text() -> String:
	if _tipo == "pozo":
		return "Rellenar regadera"
	return "Regar bancal"


func can_interact(jugador: Node) -> bool:
	if not is_instance_valid(jugador) or not jugador is Node2D:
		return false
	if (jugador as Node2D).global_position.distance_to(global_position) > _distancia:
		return false
	var regadera := _buscar_regadera()
	if regadera.is_empty():
		return false
	if _tipo == "pozo":
		return int(regadera.get("agua", AGUA_MAXIMA)) < AGUA_MAXIMA
	return not _humedo and int(regadera.get("agua", AGUA_MAXIMA)) > 0


func interact(jugador: Node) -> void:
	if not can_interact(jugador):
		return
	var regadera := _buscar_regadera()
	if regadera.is_empty():
		return
	if _tipo == "pozo":
		_rellenar_regadera(regadera)
	else:
		_regar_bancal(regadera)


func _buscar_regadera() -> Dictionary:
	var inventario := get_tree().get_first_node_in_group("inventory")
	if not is_instance_valid(inventario):
		return {}
	for mano in ["izquierda", "derecha"]:
		var objeto_variant: Variant = inventario.call("obtener_objeto_mano_activa", mano)
		if not objeto_variant is Dictionary:
			continue
		var objeto := (objeto_variant as Dictionary).duplicate(true)
		if objeto.is_empty() or not _es_regadera(objeto):
			continue
		var indice := int(inventario.call("obtener_indice_mano_activa", mano))
		var agua := _obtener_agua(objeto)
		return {
			"inventario": inventario,
			"mano": mano,
			"indice": indice,
			"objeto": objeto,
			"agua": agua
		}
	return {}


func _es_regadera(objeto: Dictionary) -> bool:
	var identidad := _normalizar(str(objeto.get("nombre", "")) + " " + str(objeto.get("item_id", objeto.get("id", ""))))
	if identidad.contains("regadera"):
		return true
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var herramienta_variant: Variant = (propiedades_variant as Dictionary).get("herramienta_recoleccion", {})
		if herramienta_variant is Dictionary:
			var tipo_herramienta := _normalizar(str((herramienta_variant as Dictionary).get("tipo", "")))
			return tipo_herramienta == "regadera"
	return false


func _obtener_agua(objeto: Dictionary) -> int:
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var regadera_variant: Variant = (propiedades_variant as Dictionary).get("regadera", {})
		if regadera_variant is Dictionary:
			return clampi(int((regadera_variant as Dictionary).get("agua", AGUA_MAXIMA)), 0, AGUA_MAXIMA)
	return AGUA_MAXIMA


func _guardar_regadera(regadera: Dictionary, nueva_cantidad: int) -> bool:
	var inventario: Node = regadera.get("inventario")
	if not is_instance_valid(inventario):
		return false
	var objeto: Dictionary = (regadera.get("objeto", {}) as Dictionary).duplicate(true)
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	var propiedades: Dictionary = (propiedades_variant as Dictionary).duplicate(true) if propiedades_variant is Dictionary else {}
	var estado_variant: Variant = propiedades.get("regadera", {})
	var estado: Dictionary = (estado_variant as Dictionary).duplicate(true) if estado_variant is Dictionary else {}
	var agua := clampi(nueva_cantidad, 0, AGUA_MAXIMA)
	estado["agua"] = agua
	estado["capacidad"] = AGUA_MAXIMA
	propiedades["regadera"] = estado
	objeto["propiedades_game"] = propiedades
	objeto["icono_ruta"] = str(ICONOS_REGADERA[agua])
	return bool(inventario.call("establecer_objeto", int(regadera.get("indice", -1)), objeto))


func _rellenar_regadera(regadera: Dictionary) -> void:
	if _guardar_regadera(regadera, AGUA_MAXIMA):
		_notificar("Regadera rellenada.")
	else:
		_notificar("No se pudo actualizar la regadera.")


func _regar_bancal(regadera: Dictionary) -> void:
	var agua := int(regadera.get("agua", 0))
	if agua <= 0:
		_notificar("La regadera está vacía. Busca un pozo.")
		return
	if not _guardar_regadera(regadera, agua - 1):
		_notificar("No se pudo usar la regadera.")
		return
	_humedo = true
	_actualizar_visual()
	_guardar_estado_parcela()
	_notificar("Bancal regado. Agua restante: " + str(agua - 1) + "/4.")


func _cargar_estado_parcela() -> void:
	var estados_variant: Variant = GameState.world_state.flags.get("vivero_bancales", {})
	if estados_variant is Dictionary:
		_humedo = bool((estados_variant as Dictionary).get(_clave, false))
	_actualizar_visual()


func _guardar_estado_parcela() -> void:
	var estados_variant: Variant = GameState.world_state.flags.get("vivero_bancales", {})
	var estados: Dictionary = (estados_variant as Dictionary).duplicate(true) if estados_variant is Dictionary else {}
	estados[_clave] = _humedo
	GameState.world_state.flags["vivero_bancales"] = estados
	if not GameState.active_save_id.is_empty():
		GameState.call_deferred("guardar_partida")


func _actualizar_visual() -> void:
	if not is_instance_valid(_tierra):
		_tierra = get_node_or_null("Tierra") as Polygon2D
	if is_instance_valid(_tierra):
		_tierra.color = COLOR_TIERRA_HUMEDA if _humedo else COLOR_TIERRA_SECA


func _notificar(mensaje: String) -> void:
	var eventos := get_tree().root.get_node_or_null("Events")
	if is_instance_valid(eventos) and eventos.has_signal("notification_pushed"):
		eventos.emit_signal("notification_pushed", mensaje)


func _normalizar(valor: String) -> String:
	return valor.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("_", " ").strip_edges()
