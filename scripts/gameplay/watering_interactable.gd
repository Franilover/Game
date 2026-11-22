extends Node2D
## Permite rellenar una regadera en un pozo y regar los bancales del vivero.
## El nivel de agua viaja dentro de los datos del objeto y se guarda con el inventario.

const AGUA_MAXIMA := 4
const ITEM_CUBO_VACIO_ID := "aeff9ca4-77f4-48d4-8c71-1afb6f603f4a"
const ITEM_CUBO_AGUA_ID := "a0d4a376-cc1a-4fd7-a139-a78915ec93b4"
const RANGO_PLANTAR_CLIC := 64.0
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
var _clave_legacy := ""
var _distancia := 76.0
var _tierra: Polygon2D = null
var _capa_humedad: TileMapLayer = null
var _celda_humedad := Vector2i.ZERO
var _humedo := false
var _planta_sprite: Sprite2D = null
var _planta: Dictionary = {}


func configurar_parcela(
	clave: String,
	clave_legacy: String = "",
	capa_humedad: TileMapLayer = null,
	celda_humedad: Vector2i = Vector2i.ZERO
) -> void:
	_tipo = "bancal"
	_clave = clave.strip_edges()
	_clave_legacy = clave_legacy.strip_edges()
	_distancia = 23.0
	_tierra = null
	_capa_humedad = capa_humedad
	_celda_humedad = celda_humedad
	add_to_group("interactable")
	_cargar_estado_parcela()
	call_deferred("_conectar_reloj_mundo")


func _unhandled_input(event: InputEvent) -> void:
	# Las semillas se plantan haciendo clic directamente sobre una celda de tierra.
	# Al estar en _unhandled_input, los clics consumidos por inventario/menus no llegan aquí.
	if _tipo != "bancal" or not event is InputEventMouseButton:
		return
	var clic := event as InputEventMouseButton
	if not clic.pressed or clic.button_index != MOUSE_BUTTON_LEFT:
		return
	_actualizar_progreso_planta()
	if not _planta.is_empty():
		return
	var semilla := _buscar_semilla()
	if semilla.is_empty():
		return
	var jugador := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(jugador) or not jugador is Node2D:
		return
	if (jugador as Node2D).global_position.distance_to(global_position) > RANGO_PLANTAR_CLIC:
		return
	var punto_local := to_local(get_global_mouse_position())
	if absf(punto_local.x) > 16.0 or absf(punto_local.y) > 16.0:
		return
	if plantar_semilla(
		semilla.get("objeto", {}),
		semilla.get("inventario"),
		int(semilla.get("indice", -1)),
		jugador
	):
		get_viewport().set_input_as_handled()


func _conectar_reloj_mundo() -> void:
	var reloj := get_tree().root.get_node_or_null("Main/Systems/WorldAtmosphere")
	if not is_instance_valid(reloj) or not reloj.has_signal("dia_cambiado"):
		return
	var callback := Callable(self, "_al_cambiar_dia_mundo")
	if not reloj.is_connected("dia_cambiado", callback):
		reloj.connect("dia_cambiado", callback)


func _al_cambiar_dia_mundo(_dia_del_anio: int, _anio: int) -> void:
	_actualizar_progreso_planta()


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
	_actualizar_progreso_planta()
	if not _planta.is_empty() and _planta_esta_madura():
		return "Recoger flor"
	if _planta.is_empty() and not _buscar_semilla().is_empty():
		return "Plantar semilla"
	return "Regar bancal"


func can_interact(jugador: Node) -> bool:
	if not is_instance_valid(jugador) or not jugador is Node2D:
		return false
	if (jugador as Node2D).global_position.distance_to(global_position) > _distancia:
		return false
	if _tipo == "bancal":
		_actualizar_progreso_planta()
		if not _planta.is_empty() and _planta_esta_madura():
			return true
		if _planta.is_empty() and not _buscar_semilla().is_empty():
			return true
	var regadera := _buscar_regadera()
	if regadera.is_empty():
		return false
	if _tipo == "pozo":
		var capacidad := 1 if _es_cubo_con_agua(regadera.get("objeto", {})) or _es_cubo_vacio(regadera.get("objeto", {})) else AGUA_MAXIMA
		return int(regadera.get("agua", AGUA_MAXIMA)) < capacidad
	return not _planta.is_empty() and not _humedo and int(regadera.get("agua", AGUA_MAXIMA)) > 0


func interact(jugador: Node) -> void:
	if not can_interact(jugador):
		return
	if _tipo == "bancal":
		_actualizar_progreso_planta()
		if not _planta.is_empty() and _planta_esta_madura():
			_cosechar_planta()
			return
		if _planta.is_empty():
			var semilla := _buscar_semilla()
			if not semilla.is_empty():
				plantar_semilla(
					semilla.get("objeto", {}),
					semilla.get("inventario"),
					int(semilla.get("indice", -1)),
					jugador
				)
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


func _buscar_semilla() -> Dictionary:
	var inventario := get_tree().get_first_node_in_group("inventory")
	if not is_instance_valid(inventario):
		return {}
	for mano in ["izquierda", "derecha"]:
		var objeto_variant: Variant = inventario.call("obtener_objeto_mano_activa", mano)
		if not objeto_variant is Dictionary:
			continue
		var objeto := (objeto_variant as Dictionary).duplicate(true)
		if objeto.is_empty():
			continue
		var item_id := str(objeto.get("item_id", objeto.get("id", ""))).strip_edges()
		if item_id not in [
			"b1000000-0000-4000-8000-000000000001",
			"b1000000-0000-4000-8000-000000000002",
			"b1000000-0000-4000-8000-000000000003"
		]:
			continue
		return {
			"inventario": inventario,
			"mano": mano,
			"indice": int(inventario.call("obtener_indice_mano_activa", mano)),
			"objeto": objeto
		}
	return {}


func _es_regadera(objeto: Dictionary) -> bool:
	var identidad := _normalizar(str(objeto.get("nombre", "")) + " " + str(objeto.get("item_id", objeto.get("id", ""))))
	if identidad.contains("regadera") or _es_cubo_con_agua(objeto) or _es_cubo_vacio(objeto):
		return true
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var herramienta_variant: Variant = (propiedades_variant as Dictionary).get("herramienta_recoleccion", {})
		if herramienta_variant is Dictionary:
			var tipo_herramienta := _normalizar(str((herramienta_variant as Dictionary).get("tipo", "")))
			return tipo_herramienta in ["regadera", "cubo de agua", "recipiente de agua"]
	return false


func _es_cubo_con_agua(objeto: Dictionary) -> bool:
	var identidad := _normalizar(str(objeto.get("nombre", "")) + " " + str(objeto.get("item_id", objeto.get("id", ""))))
	return (identidad.contains("cubo") or identidad.contains("balde")) and identidad.contains("agua")


func _es_cubo_vacio(objeto: Dictionary) -> bool:
	var identidad := _normalizar(str(objeto.get("nombre", "")) + " " + str(objeto.get("item_id", objeto.get("id", ""))))
	return identidad.contains("cubo") and not identidad.contains("agua")


func _obtener_agua(objeto: Dictionary) -> int:
	if _es_cubo_vacio(objeto):
		return 0
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		var estado_variant: Variant = propiedades.get("recipiente_agua", propiedades.get("regadera", {}))
		if estado_variant is Dictionary:
			var capacidad := 1 if _es_cubo_con_agua(objeto) else AGUA_MAXIMA
			return clampi(int((estado_variant as Dictionary).get("agua", capacidad)), 0, capacidad)
	return 1 if _es_cubo_con_agua(objeto) else AGUA_MAXIMA


func _guardar_regadera(regadera: Dictionary, nueva_cantidad: int) -> bool:
	var inventario: Node = regadera.get("inventario")
	if not is_instance_valid(inventario):
		return false
	var objeto: Dictionary = (regadera.get("objeto", {}) as Dictionary).duplicate(true)
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	var propiedades: Dictionary = (propiedades_variant as Dictionary).duplicate(true) if propiedades_variant is Dictionary else {}
	var es_cubo := _es_cubo_con_agua(objeto)
	var capacidad := 1 if es_cubo else AGUA_MAXIMA
	var estado_variant: Variant = propiedades.get("recipiente_agua", propiedades.get("regadera", {}))
	var estado: Dictionary = (estado_variant as Dictionary).duplicate(true) if estado_variant is Dictionary else {}
	var agua := clampi(nueva_cantidad, 0, capacidad)
	estado["agua"] = agua
	estado["capacidad"] = capacidad
	propiedades["recipiente_agua" if es_cubo else "regadera"] = estado
	objeto["propiedades_game"] = propiedades
	if not es_cubo:
		objeto["icono_ruta"] = str(ICONOS_REGADERA[agua])
	return bool(inventario.call("establecer_objeto", int(regadera.get("indice", -1)), objeto))


func _convertir_objeto_por_id(regadera: Dictionary, item_id: String) -> bool:
	var inventario: Node = regadera.get("inventario")
	if not is_instance_valid(inventario):
		return false
	var world_items := get_tree().root.get_node_or_null("Main/Systems/WorldItems")
	if not is_instance_valid(world_items) or not world_items.has_method("buscar_item_por_id"):
		return false
	var nuevo_objeto: Dictionary = world_items.call("buscar_item_por_id", item_id)
	if nuevo_objeto.is_empty():
		return false
	nuevo_objeto["cantidad"] = 1
	return bool(inventario.call("establecer_objeto", int(regadera.get("indice", -1)), nuevo_objeto))


func _convertir_cubo_en_vacio(regadera: Dictionary) -> bool:
	var inventario: Node = regadera.get("inventario")
	if not is_instance_valid(inventario):
		return false
	var world_items := get_tree().root.get_node_or_null("Main/Systems/WorldItems")
	if not is_instance_valid(world_items) or not world_items.has_method("buscar_item_por_id"):
		return false
	var cubo_vacio: Dictionary = world_items.call("buscar_item_por_id", ITEM_CUBO_VACIO_ID)
	if cubo_vacio.is_empty():
		return false
	cubo_vacio["cantidad"] = 1
	var objeto_actual: Dictionary = (regadera.get("objeto", {}) as Dictionary).duplicate(true)
	var cantidad_actual := maxi(1, int(objeto_actual.get("cantidad", 1)))
	var indice := int(regadera.get("indice", -1))
	if indice < 0:
		return false
	if cantidad_actual == 1:
		return bool(inventario.call("establecer_objeto", indice, cubo_vacio))
	# Si había varios cubos apilados, transforma sólo el utilizado.
	var controlador: Variant = inventario.get("inventory_controller")
	if not is_instance_valid(controlador) or not controlador.has_method("quitar_cantidad_desde_ui"):
		return false
	if not bool(controlador.call("quitar_cantidad_desde_ui", indice, 1)):
		return false
	return bool(inventario.call("agregar_objeto_desde_ui", cubo_vacio))

func _reproducir_animacion_regadera(regadera: Dictionary) -> void:
	var jugador := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(jugador) or not jugador.has_method("reproducir_animacion_herramienta"):
		return
	jugador.call("reproducir_animacion_herramienta", regadera.get("objeto", {}), global_position)


func _rellenar_regadera(regadera: Dictionary) -> void:
	var es_cubo := _es_cubo_vacio(regadera.get("objeto", {})) or _es_cubo_con_agua(regadera.get("objeto", {}))
	var actualizado := _convertir_objeto_por_id(regadera, ITEM_CUBO_AGUA_ID) if es_cubo else _guardar_regadera(regadera, AGUA_MAXIMA)
	if actualizado:
		_reproducir_animacion_regadera(regadera)
		_notificar("Cubo rellenado." if es_cubo else "Regadera rellenada.")
	else:
		_notificar("No se pudo actualizar el recipiente de agua.")


func _regar_bancal(regadera: Dictionary) -> void:
	if _planta.is_empty():
		_notificar("Primero planta una semilla en este bancal.")
		return
	_actualizar_progreso_planta()
	if _humedo:
		_notificar("La tierra todavía está húmeda.")
		return
	var agua := int(regadera.get("agua", 0))
	if agua <= 0:
		_notificar("El cubo está vacío. Busca un pozo." if _es_cubo_con_agua(regadera.get("objeto", {})) else "La regadera está vacía. Busca un pozo.")
		return
	var es_cubo := _es_cubo_con_agua(regadera.get("objeto", {}))
	if es_cubo:
		if not _convertir_cubo_en_vacio(regadera):
			_notificar("No se pudo convertir el cubo. No se regó la tierra.")
			return
	elif not _guardar_regadera(regadera, agua - 1):
		_notificar("No se pudo usar la regadera.")
		return
	_reproducir_animacion_regadera(regadera)
	_humedo = true
	_planta["riegos"] = int(_planta.get("riegos", 0)) + 1
	_planta["ultimo_riego_dia"] = _dia_mundo_actual()
	_actualizar_visual()
	_guardar_estado_parcela()
	if es_cubo:
		_notificar("Planta regada (" + str(_planta["riegos"]) + "/2). El cubo quedó vacío.")
	else:
		_notificar("Planta regada (" + str(_planta["riegos"]) + "/2). Regadera: " + str(agua - 1) + "/" + str(AGUA_MAXIMA) + ".")


func _cargar_estado_parcela() -> void:
	var estados_variant: Variant = GameState.world_state.flags.get("vivero_bancales", {})
	if estados_variant is Dictionary:
		var estados := estados_variant as Dictionary
		var estado: Variant = estados.get(_clave, {})
		# Conserva cultivos de partidas anteriores: cada bancal antiguo se
		# convierte en la celda central del nuevo TileMapDual.
		if (not estado is Dictionary or (estado as Dictionary).is_empty()) and not _clave_legacy.is_empty() and estados.has(_clave_legacy):
			estado = estados[_clave_legacy]
			estados.erase(_clave_legacy)
			estados[_clave] = estado.duplicate(true) if estado is Dictionary else estado
			GameState.world_state.flags["vivero_bancales"] = estados
			if not GameState.active_save_id.is_empty():
				GameState.call_deferred("guardar_partida")
		if estado is Dictionary:
			_planta = (estado as Dictionary).duplicate(true)
			_humedo = bool(_planta.get("humedo", false))
		else:
			# Compatibilidad con partidas anteriores que guardaban solo humedad.
			_humedo = bool(estado)
	_actualizar_visual()
	_actualizar_visual_planta()


func _guardar_estado_parcela() -> void:
	var estados_variant: Variant = GameState.world_state.flags.get("vivero_bancales", {})
	var estados: Dictionary = (estados_variant as Dictionary).duplicate(true) if estados_variant is Dictionary else {}
	if not _planta.is_empty():
		_planta["humedo"] = _humedo
		estados[_clave] = _planta.duplicate(true)
	else:
		estados.erase(_clave)
	GameState.world_state.flags["vivero_bancales"] = estados
	if not GameState.active_save_id.is_empty():
		GameState.call_deferred("guardar_partida")



func plantar_semilla(datos_semilla: Dictionary, inventario: Node, indice: int, jugador: Node) -> bool:
	if _tipo != "bancal" or not is_instance_valid(jugador) or not jugador is Node2D:
		return false
	if (jugador as Node2D).global_position.distance_to(global_position) > RANGO_PLANTAR_CLIC:
		return false
	if not _planta.is_empty():
		return false
	var item_id := str(datos_semilla.get("item_id", datos_semilla.get("id", ""))).strip_edges()
	var cultivos := {
		"b1000000-0000-4000-8000-000000000001": {"flor_id":"6791be24-76b2-415e-8726-5838cc4343e8","sprite":"res://assets/art/props/Flor Azul.png","nombre":"Flor Azul"},
		"b1000000-0000-4000-8000-000000000002": {"flor_id":"222f21a0-21f6-4a35-8239-862c6e072f2e","sprite":"res://assets/art/props/Flor Morada.png","nombre":"Flor Morada"},
		"b1000000-0000-4000-8000-000000000003": {"flor_id":"1906b182-d6b4-44ec-ba6e-cb36f5f81a3d","sprite":"res://assets/art/props/Flor Verdel.png","nombre":"Flor Verde"}
	}
	if not cultivos.has(item_id):
		return false
	if not is_instance_valid(inventario):
		return false
	var controlador: Variant = inventario.get("inventory_controller")
	if not is_instance_valid(controlador) or not controlador.has_method("quitar_cantidad_desde_ui"):
		return false
	if not bool(controlador.call("quitar_cantidad_desde_ui", indice, 1)):
		return false
	var cultivo: Dictionary = cultivos[item_id]
	_planta = {
		"semilla_item_id": item_id,
		"item_cosecha_id": str(cultivo["flor_id"]),
		"sprite": str(cultivo["sprite"]),
		"nombre": str(cultivo["nombre"]),
		"dia_plantado": _dia_mundo_actual(),
		"ultimo_riego_dia": -1,
		"riegos": 0,
		"humedo": false
	}
	_humedo = false
	_actualizar_visual_planta()
	_guardar_estado_parcela()
	_notificar("Plantaste " + str(cultivo["nombre"]) + ". Riégala durante dos días para que crezca.")
	return true


func _dia_mundo_actual() -> int:
	var contexto := get_tree().root.get_node_or_null("Main/Systems/WorldContext")
	if is_instance_valid(contexto) and contexto.has_method("obtener_tiempo"):
		var tiempo: Variant = contexto.call("obtener_tiempo")
		if tiempo is Dictionary:
			return int((tiempo as Dictionary).get("anio", 0)) * 1000 + int((tiempo as Dictionary).get("dia", 1))
	return int(GameState.world_state.elapsed_time / 720.0)


func _actualizar_progreso_planta() -> void:
	if _planta.is_empty():
		return
	var dia := _dia_mundo_actual()
	var ultimo_riego := int(_planta.get("ultimo_riego_dia", -1))
	if _humedo and dia > ultimo_riego:
		_humedo = false
		_planta["humedo"] = false
		_guardar_estado_parcela()
		_actualizar_visual()
	_actualizar_visual_planta()


func _planta_esta_madura() -> bool:
	if _planta.is_empty():
		return false
	var dias := _dia_mundo_actual() - int(_planta.get("dia_plantado", 0))
	return dias >= 2 and int(_planta.get("riegos", 0)) >= 2


func _actualizar_visual_planta() -> void:
	if not is_instance_valid(_planta_sprite):
		_planta_sprite = get_node_or_null("Planta") as Sprite2D
	if _planta.is_empty():
		if is_instance_valid(_planta_sprite):
			_planta_sprite.queue_free()
			_planta_sprite = null
		return
	if not is_instance_valid(_planta_sprite):
		_planta_sprite = Sprite2D.new()
		_planta_sprite.name = "Planta"
		_planta_sprite.position = Vector2(0, -16)
		_planta_sprite.z_index = 3
		_planta_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_planta_sprite)
	var textura := load(str(_planta.get("sprite", ""))) as Texture2D
	_planta_sprite.texture = textura
	var madura := _planta_esta_madura()
	var riegos := clampi(int(_planta.get("riegos", 0)), 0, 2)
	var escala: float = [0.35, 0.62, 0.84][riegos]
	if madura:
		escala = 1.0
	_planta_sprite.visible = textura != null
	_planta_sprite.scale = Vector2.ONE * escala
	_planta_sprite.modulate = Color.WHITE if madura else Color("#A6B58A")


func _cosechar_planta() -> void:
	var inventario := get_tree().get_first_node_in_group("inventory")
	if not is_instance_valid(inventario) or not inventario.has_method("agregar_objeto_desde_ui"):
		_notificar("No se pudo acceder al inventario.")
		return
	var item_id := str(_planta.get("item_cosecha_id", ""))
	var world_items := get_tree().root.get_node_or_null("Main/Systems/WorldItems")
	var objeto: Dictionary = {}
	if is_instance_valid(world_items) and world_items.has_method("buscar_item_por_id"):
		objeto = world_items.call("buscar_item_por_id", item_id)
	if objeto.is_empty():
		_notificar("No se encontró la flor en el catálogo de objetos.")
		return
	if not bool(inventario.call("agregar_objeto_desde_ui", objeto)):
		_notificar("No tienes espacio para recoger la flor.")
		return
	var nombre := str(_planta.get("nombre", "flor"))
	_planta.clear()
	_humedo = false
	_actualizar_visual_planta()
	_actualizar_visual()
	_guardar_estado_parcela()
	_notificar("Recogiste " + nombre + ".")


func _actualizar_visual() -> void:
	if not is_instance_valid(_tierra):
		_tierra = get_node_or_null("Tierra") as Polygon2D
	if is_instance_valid(_tierra):
		_tierra.color = COLOR_TIERRA_HUMEDA if _humedo else COLOR_TIERRA_SECA

	# Una sola capa compartida dibuja el sprite mojado únicamente en las
	# coordenadas de las parcelas húmedas. El estado guardado sigue siendo
	# _humedo; la capa es sólo su representación visual.
	if is_instance_valid(_capa_humedad):
		if _humedo:
			_capa_humedad.set_cell(_celda_humedad, 0, Vector2i(2, 1))
		else:
			_capa_humedad.erase_cell(_celda_humedad)


func _notificar(mensaje: String) -> void:
	var eventos := get_tree().root.get_node_or_null("Events")
	if is_instance_valid(eventos) and eventos.has_signal("notification_pushed"):
		eventos.emit_signal("notification_pushed", mensaje)


func _normalizar(valor: String) -> String:
	return valor.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("_", " ").strip_edges()
