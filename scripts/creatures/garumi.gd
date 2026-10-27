extends Creature
class_name Garumi

signal vinculo_establecido(garumi: Garumi, jugador: Node, tipo: String)
signal propuesta_vinculo_rechazada(garumi: Garumi, jugador: Node)
signal salud_combate_cambiada(actual: int, maxima: int)
signal encuentro_iniciado(garumi: Garumi, jugador: Node)
signal nivel_cambiado(nivel_anterior: int, nivel_actual: int)
signal experiencia_cambiada(total: int, nivel: int)
signal eterium_cambiado(actual: int, maximo: int)
signal evolucion_completada(origen_id: String, destino_id: String, nivel: int)

const OPCION_OFRECER_VINCULO := 0
const OPCION_ENFRENTAR := 1
const OPCION_FORZAR_VINCULO := 2
const OPCION_RETIRARSE := 3

@export_category("Vínculo y combate")
@export_range(1, 1000, 1) var salud_combate_predeterminada: int = 40
@export_range(0.05, 0.75, 0.05) var umbral_vinculo_forzado: float = 0.25

var _enfrentamiento_activo: bool = false
var _vinculado: bool = false
var _tipo_vinculo: String = ""
var _jugador_del_encuentro: Node = null
var _menu_contextual: CanvasLayer = null
var _jugador_vinculado: Node = null
var _guardado: bool = false
var _distancia_maxima_seguimiento: float = 520.0
var _cerebro_garumi: GarumiBrain = null
var _progresion: GarumiProgression = GarumiProgression.new()
var nivel: int = 1
var experiencia_total: int = 0
var estadisticas_combate: Dictionary = {}
var eterium_maximo: int = 30
var eterium_actual: int = 30


func _ready() -> void:
	super._ready()
	_normalizar_grupos_garumi()
	_configurar_cerebro_garumi()


func _configurar_cerebro_garumi() -> void:
	if _cerebro_garumi == null or not is_instance_valid(_cerebro_garumi):
		_cerebro_garumi = GarumiBrain.new()
		_cerebro_garumi.name = "GarumiBrain"
		add_child(_cerebro_garumi)
	_cerebro_garumi.configurar(self)


func _physics_process(delta: float) -> void:
	if _vinculado:
		if _guardado:
			return
		if not is_instance_valid(_jugador_vinculado):
			_guardar_garumi()
			return
		if not _enfrentamiento_activo and global_position.distance_to((_jugador_vinculado as Node2D).global_position) > _distancia_maxima_seguimiento:
			_guardar_garumi()
			return
		super._physics_process(delta)
		return
	super._physics_process(delta)


func obtener_estadisticas_combate() -> Dictionary:
	return estadisticas_combate.duplicate(true)


func puede_evolucionar_a(destino: Dictionary, relacion: Dictionary) -> bool:
	if _enfrentamiento_activo or destino.is_empty() or relacion.is_empty():
		return false
	if nivel < GarumiProgression.NIVEL_EVOLUCION_FISICA:
		return false
	if str(datos.get("estado_evolutivo", "")).strip_edges().to_lower() != "inicial":
		return false
	var estado_relacion := str(relacion.get("estado_documentacion", "")).strip_edges().to_lower()
	if estado_relacion not in ["canon", "aprobado"]:
		return false
	var origen_id := str(datos.get("id", criatura_id)).strip_edges()
	var destino_id := str(destino.get("id", "")).strip_edges()
	if origen_id.is_empty() or destino_id.is_empty() or origen_id == destino_id:
		return false
	if str(relacion.get("especie_origen_id", "")).strip_edges() != origen_id:
		return false
	if str(relacion.get("especie_destino_id", "")).strip_edges() != destino_id:
		return false
	if str(destino.get("original_id", "")).strip_edges() != str(datos.get("original_id", "")).strip_edges():
		return false
	if str(destino.get("categoria_garumi", "")).strip_edges().to_lower() != "normal":
		return false
	if str(destino.get("estado_evolutivo", "")).strip_edges().to_lower() != "final":
		return false
	var estado_destino := str(destino.get("estado_documentacion", "")).strip_edges().to_lower()
	return estado_destino in ["canon", "aprobado"]


func evolucionar_a(destino: Dictionary, relacion: Dictionary) -> bool:
	if not puede_evolucionar_a(destino, relacion):
		return false
	var origen_id := str(datos.get("id", criatura_id)).strip_edges()
	var destino_id := str(destino.get("id", "")).strip_edges()
	var proporcion_vida := 1.0
	if max_health > 0:
		proporcion_vida = clampf(float(health) / float(max_health), 0.0, 1.0)
	var datos_nuevos := destino.duplicate(true)
	datos_nuevos["nivel"] = nivel
	datos_nuevos["experiencia_total"] = experiencia_total
	datos_nuevos["eterium_actual"] = eterium_actual
	datos_nuevos["vinculado"] = _vinculado
	datos_nuevos["tipo_vinculo"] = _tipo_vinculo
	datos_nuevos["asset_key"] = str(destino.get("asset_key", destino.get("nombre", "")))
	configurar(datos_nuevos)
	health = clampi(roundi(proporcion_vida * float(max_health)), 1, max_health)
	vital_state.configurar(max_health, max_mana)
	vital_state.health = health
	vital_state.is_alive = true
	_sync_desde_vital()
	health_changed.emit(health, max_health)
	evolucion_completada.emit(origen_id, destino_id, nivel)
	print("Garumi: evolución completada ", origen_id, " → ", destino_id, " | nivel ", nivel)
	return true


func experiencia_para_siguiente_nivel() -> int:
	if nivel >= GarumiProgression.NIVEL_MAXIMO:
		return 0
	return _progresion.xp_para_siguiente_nivel(nivel)


func ganar_experiencia(cantidad: int) -> int:
	if cantidad <= 0 or nivel >= GarumiProgression.NIVEL_MAXIMO:
		return 0
	var nivel_anterior := nivel
	var vida_maxima_anterior := max_health
	var eterium_maximo_anterior := eterium_maximo
	experiencia_total += cantidad
	nivel = _progresion.nivel_desde_experiencia(experiencia_total)
	estadisticas_combate = _progresion.obtener_estadisticas(nivel)
	max_health = int(estadisticas_combate.get("vida", max_health))
	eterium_maximo = int(estadisticas_combate.get("eterium", eterium_maximo))
	if nivel > nivel_anterior:
		# El aumento de capacidad no castiga la salud o Eterium que ya tenía.
		health = mini(max_health, health + max_health - vida_maxima_anterior)
		eterium_actual = mini(eterium_maximo, eterium_actual + eterium_maximo - eterium_maximo_anterior)
		vital_state.configurar(max_health, max_mana)
		vital_state.health = health
		vital_state.is_alive = health > 0
		_sync_desde_vital()
		health_changed.emit(health, max_health)
		eterium_cambiado.emit(eterium_actual, eterium_maximo)
		nivel_cambiado.emit(nivel_anterior, nivel)
	datos["nivel"] = nivel
	datos["experiencia_total"] = experiencia_total
	datos["eterium_actual"] = eterium_actual
	experiencia_cambiada.emit(experiencia_total, nivel)
	return nivel - nivel_anterior


func calcular_danio_ofensivo(potencia: float = 100.0) -> int:
	return _progresion.calcular_danio(
		int(estadisticas_combate.get("ataque", 10)),
		0,
		potencia
	)


func calcular_danio_recibido(danio_base: int) -> int:
	return _progresion.calcular_danio(
		danio_base,
		int(estadisticas_combate.get("defensa", 0)),
		100.0
	)


func gastar_eterium(cantidad: int) -> bool:
	if cantidad < 0 or eterium_actual < cantidad:
		return false
	eterium_actual -= cantidad
	datos["eterium_actual"] = eterium_actual
	eterium_cambiado.emit(eterium_actual, eterium_maximo)
	return true


func restaurar_eterium(cantidad: int) -> int:
	if cantidad <= 0:
		return 0
	var anterior := eterium_actual
	eterium_actual = mini(eterium_maximo, eterium_actual + cantidad)
	if eterium_actual != anterior:
		datos["eterium_actual"] = eterium_actual
		eterium_cambiado.emit(eterium_actual, eterium_maximo)
	return eterium_actual - anterior


func esta_guardado() -> bool:
	return _guardado


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
	_progresion.configurar(datos_separados)
	nivel = clampi(int(datos_separados.get("nivel", 1)), 1, GarumiProgression.NIVEL_MAXIMO)
	experiencia_total = maxi(0, int(datos_separados.get("experiencia_total", 0)))
	nivel = _progresion.nivel_desde_experiencia(experiencia_total)
	estadisticas_combate = _progresion.obtener_estadisticas(nivel)
	max_health = int(estadisticas_combate.get("vida", salud_combate_predeterminada))
	health = max_health
	eterium_maximo = int(estadisticas_combate.get("eterium", 30))
	eterium_actual = clampi(int(datos_separados.get("eterium_actual", eterium_maximo)), 0, eterium_maximo)
	datos["nivel"] = nivel
	datos["experiencia_total"] = experiencia_total
	datos["eterium_actual"] = eterium_actual
	vital_state.configurar(max_health, max_mana)
	_sync_desde_vital()
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
	return not _vinculado


func can_interact(_jugador: Node) -> bool:
	return is_inside_tree() and not _vinculado


func get_interaction_priority() -> int:
	return 20


func get_interaction_distance() -> float:
	return 48.0


func get_interaction_text() -> String:
	if _vinculado:
		return ""
	if _enfrentamiento_activo and puede_forzar_vinculo():
		return "Garumi debilitado: interactuar"
	if _enfrentamiento_activo:
		return "Enfrentamiento: interactuar"
	return "Interactuar con " + (criatura_nombre if not criatura_nombre.is_empty() else name)


## Se invoca desde InteractionSystem al acercarse y usar la acción contextual.
func interact(jugador: Node) -> void:
	if jugador == null or not is_instance_valid(jugador) or _vinculado:
		return
	_mostrar_menu_contextual(jugador)


func _mostrar_menu_contextual(jugador: Node) -> void:
	if is_instance_valid(_menu_contextual):
		_al_cerrar_menu_contextual()

	# Capa propia para que el menú no dependa de la posición del cursor
	# ni de la transformación/cámara del mundo.
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

	var fondo := ColorRect.new()
	fondo.name = "FondoOscuro"
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.025, 0.02, 0.015, 0.68)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fondo)

	var panel := PanelContainer.new()
	panel.name = "GarumiBondMenu"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -190.0
	panel.offset_top = -145.0
	panel.offset_right = 190.0
	panel.offset_bottom = 145.0
	panel.z_index = 1
	panel.custom_minimum_size = Vector2(380.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var estilo_panel := StyleBoxFlat.new()
	estilo_panel.bg_color = Color(0.08, 0.055, 0.035, 0.99)
	estilo_panel.border_color = Color(0.58, 0.43, 0.24, 1.0)
	estilo_panel.set_border_width_all(2)
	estilo_panel.set_corner_radius_all(6)
	estilo_panel.content_margin_left = 22.0
	estilo_panel.content_margin_top = 18.0
	estilo_panel.content_margin_right = 22.0
	estilo_panel.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", estilo_panel)
	overlay.add_child(panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	panel.add_child(columna)

	var titulo := Label.new()
	titulo.text = criatura_nombre if not criatura_nombre.strip_edges().is_empty() else name
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.add_theme_color_override("font_color", Color(0.93, 0.84, 0.65, 1.0))
	titulo.add_theme_font_size_override("font_size", 18)
	columna.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "¿Cómo quieres acercarte a este Garumi?"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitulo.add_theme_color_override("font_color", Color(0.72, 0.64, 0.52, 1.0))
	subtitulo.add_theme_font_size_override("font_size", 11)
	columna.add_child(subtitulo)

	var separador := HSeparator.new()
	columna.add_child(separador)

	if _enfrentamiento_activo:
		if puede_forzar_vinculo():
			_agregar_boton_menu_garumi(columna, "Forzar vínculo", OPCION_FORZAR_VINCULO, jugador)
		_agregar_boton_menu_garumi(columna, "Retirarse del enfrentamiento", OPCION_RETIRARSE, jugador)
	else:
		_agregar_boton_menu_garumi(columna, "Ofrecer vínculo", OPCION_OFRECER_VINCULO, jugador)
		_agregar_boton_menu_garumi(columna, "Enfrentar", OPCION_ENFRENTAR, jugador)

	var cerrar := _crear_boton_menu_garumi("Cerrar", -1)
	cerrar.pressed.connect(_al_cerrar_menu_contextual)
	columna.add_child(cerrar)


func _agregar_boton_menu_garumi(contenedor: VBoxContainer, texto: String, opcion: int, jugador: Node) -> void:
	var boton := _crear_boton_menu_garumi(texto, opcion)
	boton.pressed.connect(_al_seleccionar_opcion.bind(opcion, jugador))
	contenedor.add_child(boton)


func _crear_boton_menu_garumi(texto: String, opcion: int) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0.0, 38.0)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.focus_mode = Control.FOCUS_ALL
	boton.add_theme_color_override("font_color", Color(0.91, 0.83, 0.68, 1.0))
	boton.add_theme_color_override("font_hover_color", Color(0.98, 0.91, 0.75, 1.0))
	boton.add_theme_color_override("font_pressed_color", Color(0.98, 0.91, 0.75, 1.0))
	boton.add_theme_font_size_override("font_size", 13)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.105, 0.065, 1.0)
	normal.border_color = Color(0.38, 0.28, 0.16, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	boton.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.17, 0.095, 1.0)
	hover.border_color = Color(0.78, 0.61, 0.34, 1.0)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.075, 0.045, 1.0)
	boton.add_theme_stylebox_override("pressed", pressed)
	return boton



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
	if is_instance_valid(menu_a_cerrar):
		menu_a_cerrar.queue_free()


func _al_seleccionar_opcion(opcion: int, jugador: Node) -> void:
	# Liberar el menú antes de ejecutar una acción que cambie de estado o de cámara.
	_al_cerrar_menu_contextual()
	match opcion:
		OPCION_OFRECER_VINCULO:
			ofrecer_vinculo(jugador)
		OPCION_ENFRENTAR:
			iniciar_enfrentamiento(jugador)
		OPCION_FORZAR_VINCULO:
			forzar_vinculo(jugador)
		OPCION_RETIRARSE:
			finalizar_enfrentamiento()


func _al_ocultar_menu() -> void:
	_al_cerrar_menu_contextual()


func ofrecer_vinculo(jugador: Node) -> bool:
	if _vinculado or _enfrentamiento_activo or jugador == null or not is_instance_valid(jugador):
		return false
	var probabilidad := clampf(float(datos.get("aceptacion_vinculo", 0.5)), 0.0, 1.0)
	if _rng.randf() > probabilidad:
		propuesta_vinculo_rechazada.emit(self, jugador)
		_notificar_resultado_vinculo(false, "")
		print("Garumi: ", criatura_nombre, " rechaza la propuesta de vínculo.")
		return false
	_establecer_vinculo(jugador, "voluntario")
	return true


func iniciar_enfrentamiento(jugador: Node) -> bool:
	if _vinculado or _enfrentamiento_activo:
		return false
	if jugador == null or not is_instance_valid(jugador):
		return false

	_jugador_del_encuentro = jugador
	_enfrentamiento_activo = true
	max_health = maxi(1, int(estadisticas_combate.get("vida", datos.get("salud_combate", salud_combate_predeterminada))))
	vital_state.configurar(max_health, max_mana)
	restaurar_estado_vital(max_health, true)
	add_to_group("damageable")
	salud_combate_cambiada.emit(health, max_health)
	encuentro_iniciado.emit(self, jugador)
	var escena_principal := get_tree().current_scene
	if escena_principal != null and escena_principal.has_method("iniciar_arena_garumi"):
		escena_principal.call("iniciar_arena_garumi", self, jugador)
	return true


func puede_forzar_vinculo() -> bool:
	if _vinculado or not _enfrentamiento_activo or max_health <= 0:
		return false
	return float(health) / float(max_health) <= umbral_vinculo_forzado


## El daño común sigue sin afectar a los Garumis. Solo el daño durante un
## enfrentamiento explícito reduce su salud y nunca puede matarlos.
func take_damage(cantidad: int, origen: String = "desconocido") -> void:
	if not _enfrentamiento_activo or _vinculado or not is_alive:
		return
	if cantidad <= 0:
		return

	var dano_real := calcular_danio_recibido(cantidad)
	var salud_anterior := health
	health = maxi(1, health - dano_real)
	vital_state.health = health
	vital_state.is_alive = true
	_sync_desde_vital()
	if health != salud_anterior:
		health_changed.emit(health, max_health)
		salud_combate_cambiada.emit(health, max_health)
		print("Garumi: ", criatura_nombre, " recibe ", salud_anterior - health, " de daño tras defensa (", origen, ") | ", health, "/", max_health)


func forzar_vinculo(jugador: Node) -> bool:
	if not puede_forzar_vinculo() or jugador == null or not is_instance_valid(jugador):
		return false
	_establecer_vinculo(jugador, "forzado")
	return true


func _establecer_vinculo(jugador: Node, tipo: String) -> void:
	if _enfrentamiento_activo:
		var escena_principal := get_tree().current_scene
		if escena_principal != null and escena_principal.has_method("terminar_arena_garumi"):
			escena_principal.call("terminar_arena_garumi", self)
	_vinculado = true
	_jugador_vinculado = jugador
	_guardado = false
	_tipo_vinculo = tipo
	_enfrentamiento_activo = false
	_jugador_del_encuentro = null
	remove_from_group("damageable")
	datos["vinculado"] = true
	datos["tipo_vinculo"] = tipo
	set_meta("vinculado", true)
	set_meta("tipo_vinculo", tipo)
	vinculo_establecido.emit(self, jugador, tipo)
	if has_method("iniciar_seguimiento_jugador"):
		iniciar_seguimiento_jugador(jugador)
	_notificar_resultado_vinculo(true, tipo)
	print("Garumi: vínculo ", tipo, " establecido con ", jugador.name)


func finalizar_enfrentamiento() -> void:
	if _enfrentamiento_activo:
		var escena_principal := get_tree().current_scene
		if escena_principal != null and escena_principal.has_method("terminar_arena_garumi"):
			escena_principal.call("terminar_arena_garumi", self)
	_enfrentamiento_activo = false
	_jugador_del_encuentro = null
	remove_from_group("damageable")
	restaurar_estado_vital(max_health, true)


func esta_vinculado() -> bool:
	return _vinculado


func obtener_tipo_vinculo() -> String:
	return _tipo_vinculo


func esta_enfrentamiento() -> bool:
	return _enfrentamiento_activo


func _notificar_resultado_vinculo(exito: bool, tipo: String) -> void:
	for nodo_hud in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(nodo_hud) and nodo_hud.has_method("mostrar_resultado_vinculo"):
			nodo_hud.call("mostrar_resultado_vinculo", self, exito, tipo)
