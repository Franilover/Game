extends Creature
class_name Garumi

signal vinculo_establecido(garumi: Garumi, jugador: Node, tipo: String)
signal propuesta_vinculo_rechazada(garumi: Garumi, jugador: Node)
signal eterium_cambiado(actual: int, maximo: int)

@export_category("Vínculo")
var _vinculado: bool = false
var _tipo_vinculo: String = ""
var _garumi_instancia_id: String = ""
var _cerebro_garumi: GarumiBrain = null
var eterium_maximo: int = 30
var eterium_actual: int = 30


func _ready() -> void:
	super._ready()
	add_to_group("garumi_instances")
	_normalizar_grupos_garumi()
	_configurar_cerebro_garumi()


func _configurar_cerebro_garumi() -> void:
	if _cerebro_garumi == null or not is_instance_valid(_cerebro_garumi):
		_cerebro_garumi = GarumiBrain.new()
		_cerebro_garumi.name = "GarumiBrain"
		add_child(_cerebro_garumi)
	_cerebro_garumi.configurar(self)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)


func gastar_eterium(cantidad: int) -> bool:
	if cantidad < 0 or eterium_actual < cantidad:
		return false
	eterium_actual -= cantidad
	datos["eterium_actual"] = eterium_actual
	eterium_cambiado.emit(eterium_actual, eterium_maximo)
	_persistir_estado_vinculo()
	return true


func restaurar_eterium(cantidad: int) -> int:
	if cantidad <= 0:
		return 0
	var anterior := eterium_actual
	eterium_actual = mini(eterium_maximo, eterium_actual + cantidad)
	if eterium_actual != anterior:
		datos["eterium_actual"] = eterium_actual
		eterium_cambiado.emit(eterium_actual, eterium_maximo)
		_persistir_estado_vinculo()
	return eterium_actual - anterior


func configurar(datos_garumi: Dictionary) -> void:
	var datos_separados := datos_garumi.duplicate(true)
	datos_separados["categoria_entidad"] = "garumi"
	if not datos_separados.has("asset_key"):
		datos_separados["asset_key"] = str(datos_separados.get("nombre", ""))
	super.configurar(datos_separados)
	_vinculado = bool(datos_separados.get("vinculado", false))
	_tipo_vinculo = str(datos_separados.get("tipo_vinculo", ""))
	eterium_actual = clampi(int(datos_separados.get("eterium_actual", eterium_maximo)), 0, eterium_maximo)
	datos["eterium_actual"] = eterium_actual
	_configurar_cerebro_garumi()


## Inmunidad estructural: un Garumi nunca recibe daño del sistema de criaturas.
func take_damage(_cantidad: int, _origen: String = "desconocido") -> void:
	return


func activar_como_proxy() -> void:
	super.activar_como_proxy()
	_normalizar_grupos_garumi()


func _normalizar_grupos_garumi() -> void:
	remove_from_group("creatures")
	remove_from_group("damageable")
	add_to_group("garumis")


func es_garumi() -> bool:
	return true


func es_dialogable() -> bool:
	return true


func can_interact(_jugador: Node) -> bool:
	return is_inside_tree()


func get_interaction_priority() -> int:
	return 20


func get_interaction_distance() -> float:
	return 48.0


func get_interaction_text() -> String:
	return "Hablar con " + (criatura_nombre if not criatura_nombre.is_empty() else name)


## Se invoca desde InteractionSystem al acercarse y usar la acción contextual.
func interact(_jugador: Node) -> void:
	# Un Garumi se conoce hablando con él; no abre menús de captura ni combate.
	abrir_dialogo()


func _es_amigo_del_jugador() -> bool:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("es_garumi_amigo"):
		return false
	var id := _obtener_id_instancia_social()
	return not id.is_empty() and bool(game_state.call("es_garumi_amigo", id))


func _obtener_id_instancia_social() -> String:
	if _garumi_instancia_id.is_empty():
		_garumi_instancia_id = str(Time.get_ticks_usec()) + "-" + str(get_instance_id())
	return _garumi_instancia_id


func obtener_datos_amistad() -> Dictionary:
	var registro := datos.duplicate(true)
	registro["categoria_entidad"] = "garumi"
	registro["garumi_instancia_id"] = _obtener_id_instancia_social()
	registro["vinculado"] = _vinculado
	registro["tipo_vinculo"] = _tipo_vinculo
	registro["eterium_actual"] = eterium_actual
	registro.erase("health")
	registro.erase("nivel")
	registro.erase("experiencia_total")
	registro["asset_key"] = str(registro.get("asset_key", registro.get("nombre", criatura_nombre)))
	return registro


func ofrecer_amistad(jugador: Node) -> bool:
	if not is_instance_valid(jugador):
		return false
	if _es_amigo_del_jugador():
		return true
	var probabilidad := clampf(float(datos.get("aceptacion_amistad", datos.get("aceptacion_vinculo", 0.5))), 0.0, 1.0)
	if _rng.randf() > probabilidad:
		_notificar_resultado_amistad(false)
		return false
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("guardar_garumi_amigo"):
		return false
	var exito := bool(game_state.call("guardar_garumi_amigo", obtener_datos_amistad()))
	_notificar_resultado_amistad(exito)
	return exito


func _notificar_resultado_amistad(exito: bool) -> void:
	for nodo in get_tree().get_nodes_in_group("inventory"):
		if not is_instance_valid(nodo):
			continue
		var hub := nodo.get_node_or_null("Window/Margin/Column/Tabs/Garumis")
		if hub != null and hub.has_method("mostrar_resultado_amistad_garumi"):
			hub.call("mostrar_resultado_amistad_garumi", self, exito)


func ofrecer_vinculo(jugador: Node) -> bool:
	if _vinculado or jugador == null or not is_instance_valid(jugador):
		return false
	var probabilidad := clampf(float(datos.get("aceptacion_vinculo", 0.5)), 0.0, 1.0)
	if _rng.randf() > probabilidad:
		propuesta_vinculo_rechazada.emit(self, jugador)
		_notificar_resultado_vinculo(false, "")
		print("Garumi: ", criatura_nombre, " rechaza la propuesta de vínculo.")
		return false
	return _establecer_vinculo(jugador, "voluntario")


func _establecer_vinculo(jugador: Node, tipo: String) -> bool:
	if not _vinculado and not _puede_establecer_otro_vinculo():
		push_warning("Garumi: límite de 3 vínculos alcanzado; establece una relación antes de crear otra.")
		_notificar_resultado_vinculo(false, "limite_alcanzado")
		return false
	_vinculado = true
	_tipo_vinculo = tipo
	datos["vinculado"] = true
	datos["tipo_vinculo"] = tipo
	set_meta("vinculado", true)
	set_meta("tipo_vinculo", tipo)
	vinculo_establecido.emit(self, jugador, tipo)
	_notificar_resultado_vinculo(true, tipo)
	_persistir_estado_vinculo()
	print("Garumi: relación ", tipo, " establecida con ", jugador.name)
	return true


## Identidad y estado de la instancia vinculada para el guardado local.
func obtener_datos_persistencia_vinculo() -> Dictionary:
	if not _vinculado:
		return {}
	if _garumi_instancia_id.is_empty():
		_garumi_instancia_id = str(Time.get_ticks_usec()) + "-" + str(get_instance_id())
	var registro := datos.duplicate(true)
	registro["categoria_entidad"] = "garumi"
	registro["garumi_instancia_id"] = _garumi_instancia_id
	registro["vinculado"] = true
	registro["tipo_vinculo"] = _tipo_vinculo
	registro["eterium_actual"] = eterium_actual
	registro.erase("health")
	registro.erase("nivel")
	registro.erase("experiencia_total")
	registro["position_x"] = global_position.x
	registro["position_y"] = global_position.y
	registro["asset_key"] = str(registro.get("asset_key", registro.get("nombre", criatura_nombre)))
	return registro


func _persistir_estado_vinculo() -> void:
	if not _vinculado:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("guardar_garumi_vinculado"):
		return
	var registro := obtener_datos_persistencia_vinculo()
	if not registro.is_empty():
		game_state.call("guardar_garumi_vinculado", registro)


func restaurar_vinculo_persistido(jugador: Node, _guardado: bool, posicion: Vector2) -> void:
	if not is_instance_valid(jugador) or not jugador is Node2D:
		return
	_vinculado = true
	_tipo_vinculo = str(datos.get("tipo_vinculo", _tipo_vinculo))
	_garumi_instancia_id = str(datos.get("garumi_instancia_id", _garumi_instancia_id))
	global_position = posicion
	set_meta("vinculado", true)
	set_meta("tipo_vinculo", _tipo_vinculo)
	_normalizar_grupos_garumi()


func _puede_establecer_otro_vinculo() -> bool:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("puede_vincular_garumi"):
		return true
	return bool(game_state.call("puede_vincular_garumi"))


func romper_vinculo() -> bool:
	if not _vinculado:
		return false
	var game_state := get_node_or_null("/root/GameState")
	var id_instancia := str(obtener_datos_persistencia_vinculo().get("garumi_instancia_id", "")).strip_edges()
	if game_state != null and not id_instancia.is_empty() and game_state.has_method("eliminar_garumi_vinculado"):
		game_state.call("eliminar_garumi_vinculado", id_instancia)
	for nodo_hud in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(nodo_hud) and nodo_hud.has_method("eliminar_garumi_vinculado"):
			nodo_hud.call("eliminar_garumi_vinculado", self)
	_vinculado = false
	_tipo_vinculo = ""
	remove_from_group("damageable")
	remove_meta("vinculado")
	remove_meta("tipo_vinculo")
	datos["vinculado"] = false
	datos.erase("tipo_vinculo")
	print("Garumi: vínculo roto; ", criatura_nombre, " queda libre y ya no ocupa un espacio.")
	return true


func esta_vinculado() -> bool:
	return _vinculado


func obtener_tipo_vinculo() -> String:
	return _tipo_vinculo


func _notificar_resultado_vinculo(exito: bool, tipo: String) -> void:
	for nodo_hud in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(nodo_hud) and nodo_hud.has_method("mostrar_resultado_vinculo"):
			nodo_hud.call("mostrar_resultado_vinculo", self, exito, tipo)
