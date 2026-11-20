extends Creature
class_name Garumi

const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")

signal vinculo_establecido(garumi: Garumi, jugador: Node, tipo: String)
signal propuesta_vinculo_rechazada(garumi: Garumi, jugador: Node)
signal eterium_cambiado(actual: int, maximo: int)

const OPCION_OFRECER_VINCULO := 0
const OPCION_OFRECER_AMISTAD := 1

@export_category("Vínculo")
var _vinculado: bool = false
var _tipo_vinculo: String = ""
var _menu_contextual: CanvasLayer = null
var _jugador_menu_contextual: Node2D = null
var _jugador_vinculado: Node = null
var _guardado: bool = false
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


func esta_guardado() -> bool:
	return _guardado


func establecer_estado_companero(jugador: Node, activo: bool) -> void:
	if not _vinculado or not is_instance_valid(jugador) or not jugador is Node2D:
		return
	if activo:
		_invocar_garumi(jugador)
	else:
		_guardar_garumi()


func alternar_estado_invocacion(jugador: Node) -> void:
	if not _vinculado or not is_instance_valid(jugador) or not jugador is Node2D:
		return
	if _guardado:
		_invocar_garumi(jugador)
	elif _esta_en_pantalla():
		_guardar_garumi()
	else:
		# Si está libre pero fuera de cámara, la tecla lo trae junto al jugador.
		global_position = (jugador as Node2D).global_position + Vector2(42.0, 20.0)
		_jugador_vinculado = jugador
		if has_method("iniciar_seguimiento_jugador"):
			iniciar_seguimiento_jugador(jugador)
		actualizar_estado_en_hud()


func _esta_en_pantalla() -> bool:
	var camara := get_viewport().get_camera_2d()
	if camara == null:
		return true
	var posicion_pantalla: Vector2 = get_global_transform_with_canvas().origin
	return get_viewport().get_visible_rect().has_point(posicion_pantalla)


func _guardar_garumi() -> void:
	if _guardado:
		return
	_guardado = true
	if has_method("detener_seguimiento_jugador"):
		detener_seguimiento_jugador()
	if has_method("desactivar_como_proxy"):
		desactivar_como_proxy()
	else:
		visible = false
		set_physics_process(false)
		set_process(false)
	actualizar_estado_en_hud()
	_persistir_estado_vinculo()


func _invocar_garumi(jugador: Node) -> void:
	if not is_instance_valid(jugador) or not jugador is Node2D:
		return
	_guardado = false
	_jugador_vinculado = jugador
	var destino := (jugador as Node2D).global_position + Vector2(42.0, 20.0)
	if has_method("activar_como_proxy"):
		activar_como_proxy()
	_normalizar_grupos_garumi()
	global_position = destino
	velocity = Vector2.ZERO
	if has_method("iniciar_seguimiento_jugador"):
		iniciar_seguimiento_jugador(jugador)
	actualizar_estado_en_hud()
	_persistir_estado_vinculo()


func actualizar_estado_en_hud() -> void:
	for nodo_hud in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(nodo_hud) and nodo_hud.has_method("actualizar_estado_garumi"):
			nodo_hud.call("actualizar_estado_garumi", self, _guardado)


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
func interact(jugador: Node) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	_mostrar_menu_contextual(jugador)


func _mostrar_menu_contextual(jugador: Node) -> void:
	if _vinculado:
		return
	if not is_instance_valid(jugador) or not jugador is Node2D:
		return
	if is_instance_valid(_menu_contextual):
		_al_cerrar_menu_contextual()

	# Dos acciones pequeñas flotan sobre la criatura; sin pantalla oscura ni ventana modal grande.
	_jugador_menu_contextual = jugador as Node2D
	_menu_contextual = CanvasLayer.new()
	_menu_contextual.name = "GarumiBondMenuLayer"
	_menu_contextual.layer = 120
	_menu_contextual.add_to_group("modal_ui")
	get_tree().root.add_child(_menu_contextual)

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_contextual.add_child(overlay)
	overlay.gui_input.connect(_al_input_menu_contextual)

	var panel_menu := PanelContainer.new()
	panel_menu.name = "GarumiBondPanel"
	panel_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel_menu)
	var margen := MarginContainer.new()
	margen.name = "Margin"
	margen.add_theme_constant_override("margin_left", 10)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_right", 10)
	margen.add_theme_constant_override("margin_bottom", 8)
	panel_menu.add_child(margen)
	var acciones := HBoxContainer.new()
	acciones.name = "GarumiBondMenu"
	acciones.add_theme_constant_override("separation", 8)
	acciones.mouse_filter = Control.MOUSE_FILTER_STOP
	acciones.custom_minimum_size = Vector2(0.0, 38.0)
	margen.add_child(acciones)
	PIXEL_UI_THEME.apply(panel_menu, false)

	_agregar_boton_menu_garumi(acciones, "Vincular", OPCION_OFRECER_VINCULO, jugador)
	if not _es_amigo_del_jugador():
		_agregar_boton_menu_garumi(acciones, "Amistad", OPCION_OFRECER_AMISTAD, jugador)
	_actualizar_posicion_menu_contextual()


func cerrar_menu_contextual() -> void:
	_al_cerrar_menu_contextual()


func _actualizar_posicion_menu_contextual() -> void:
	if not is_instance_valid(_menu_contextual) or not is_instance_valid(self):
		return
	var overlay := _menu_contextual.get_node_or_null("Overlay") as Control
	var panel_menu := _menu_contextual.get_node_or_null("Overlay/GarumiBondPanel") as Control
	if overlay == null or panel_menu == null:
		return
	var escala_pantalla := get_global_transform_with_canvas().origin
	var viewport := get_viewport().get_visible_rect().size
	var tamano := panel_menu.get_combined_minimum_size()
	panel_menu.size = tamano
	panel_menu.position = Vector2(
		clampf(escala_pantalla.x - tamano.x * 0.5, 8.0, maxf(8.0, viewport.x - tamano.x - 8.0)),
		clampf(escala_pantalla.y - tamano.y - 22.0, 8.0, maxf(8.0, viewport.y - tamano.y - 8.0))
	)


func _process(_delta: float) -> void:
	if not is_instance_valid(_menu_contextual):
		return
	if not is_instance_valid(_jugador_menu_contextual):
		_al_cerrar_menu_contextual()
		return
	if global_position.distance_to(_jugador_menu_contextual.global_position) > get_interaction_distance() + 12.0:
		_al_cerrar_menu_contextual()
		return
	_actualizar_posicion_menu_contextual()


func _agregar_boton_menu_garumi(contenedor: HBoxContainer, texto: String, opcion: int, jugador: Node) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(112.0, 38.0)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.focus_mode = Control.FOCUS_ALL
	boton.add_theme_font_size_override("font_size", 12)
	PIXEL_UI_THEME.apply(boton, false)
	boton.pressed.connect(_al_seleccionar_opcion.bind(opcion, jugador))
	contenedor.add_child(boton)


func _al_input_menu_contextual(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var tecla := event as InputEventKey
		if tecla.keycode == KEY_ESCAPE:
			_al_cerrar_menu_contextual()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var clic := event as InputEventMouseButton
		if clic.button_index == MOUSE_BUTTON_LEFT:
			var panel := _menu_contextual.get_node_or_null("Overlay/GarumiBondMenu") if is_instance_valid(_menu_contextual) else null
			if panel is Control and not (panel as Control).get_global_rect().has_point(clic.position):
				_al_cerrar_menu_contextual()
				get_viewport().set_input_as_handled()


func _al_cerrar_menu_contextual() -> void:
	var menu_a_cerrar := _menu_contextual
	_menu_contextual = null
	_jugador_menu_contextual = null
	if is_instance_valid(menu_a_cerrar):
		menu_a_cerrar.queue_free()


func _al_seleccionar_opcion(opcion: int, jugador: Node) -> void:
	_al_cerrar_menu_contextual()
	match opcion:
		OPCION_OFRECER_VINCULO:
			ofrecer_vinculo(jugador)
		OPCION_OFRECER_AMISTAD:
			ofrecer_amistad(jugador)


func _al_ocultar_menu() -> void:
	_al_cerrar_menu_contextual()


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
	registro["guardado"] = _guardado
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
	_jugador_vinculado = jugador
	_guardado = true
	_tipo_vinculo = str(datos.get("tipo_vinculo", _tipo_vinculo))
	_garumi_instancia_id = str(datos.get("garumi_instancia_id", _garumi_instancia_id))
	global_position = posicion
	set_meta("vinculado", true)
	set_meta("tipo_vinculo", _tipo_vinculo)
	_normalizar_grupos_garumi()
	actualizar_estado_en_hud()


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
	_guardado = false
	_jugador_vinculado = null
	_jugador_del_encuentro = null
	_enfrentamiento_activo = false
	remove_from_group("damageable")
	remove_meta("vinculado")
	remove_meta("tipo_vinculo")
	datos["vinculado"] = false
	datos.erase("tipo_vinculo")
	set_physics_process(true)
	set_process(true)
	visible = true
	activar_como_proxy()
	_normalizar_grupos_garumi()
	restaurar_estado_vital(max_health, true)
	actualizar_estado_en_hud()
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
