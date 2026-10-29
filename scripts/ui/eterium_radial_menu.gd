extends Control
class_name EteriumRadialMenu

## Panel compacto de acciones de Eterium, integrado con el estilo de los menús del juego.
## Pulsa X para abrir; usa los botones o las teclas 1–3.

const COSTO_CURACION: int = 10
const COSTO_CARGA_DASH: int = 10
const RECUPERACION_MEDITACION: int = 20

var jugador: Node = null
var ium_lab: Node = null
var ium_manager: Node = null
var inventario: Node = null
var admin_console: Node = null
var visible_menu: bool = false
var cuadrante: int = -1
var _overlay: ColorRect
var _panel: PanelContainer
var _eterium_label: Label
var _estado_label: Label
var _botones: Array[Button] = []
const TIEMPO_CONCENTRACION := 4.0
const VENTANA_TOQUES := 0.6
const DURACION_CURACION := 5.0
const DURACION_DASH_MINIJUEGO := 1.5
const TOQUES_CURACION_NECESARIOS := 12
const COSTO_FALLO_MINIJUEGO := 3
const CICLOS_MEDITACION_NECESARIOS := 4
const RADIO_ANILLO_INICIAL := 112.0
const RADIO_ANILLO_OBJETIVO := 42.0
const VELOCIDAD_ANILLO := 105.0
const MARGEN_Coyote := 0.09
var _minijuego_layer: Control
var _minijuego_titulo: Label
var _minijuego_instruccion: Label
var _minijuego_barra: ProgressBar
var _minijuego_tiempo: ProgressBar
var _anillo_meditacion: Control
var _radio_anillo := RADIO_ANILLO_INICIAL
var _direccion_anillo := -1.0
var _ventana_coyote := 0.0
var _indicador_tiempo: Label
var _estado_minijuego := ""
var _fase_meditacion := ""
var _espacio_pulsado := false
var _tiempo_sostenido := 0.0
var _tiempo_ventana_toques := 0.0
var _toques_espacio := 0
var _tiempo_minijuego := 0.0
var _tiempo_fase := 0.0
var _toques_curacion := 0
var _ciclos_meditacion := 0
var _ultima_vida := -1


func configurar(player: Node, lab: Node, manager: Node, inventory: Node, admin: Node) -> void:
	jugador = player
	_ultima_vida = int(player.get("health")) if player != null else -1
	if player != null and player.has_signal("health_changed"):
		var callback_vida := Callable(self, "_al_cambio_vida_minijuego")
		if not player.is_connected("health_changed", callback_vida):
			player.connect("health_changed", callback_vida)
	ium_lab = lab
	ium_manager = manager
	inventario = inventory
	admin_console = admin

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	_crear_interfaz()
	_construir_interfaz_minijuego()

func _crear_interfaz() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Fondo"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.035, 0.022, 0.012, 0.34)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_cerrar()
	)
	add_child(_overlay)

	# Cada acción tiene su propio contenedor; no existe un panel común.
	var opciones := ["Curarse", "Recuperar dash", "Meditar"]
	for i in range(opciones.size()):
		var contenedor_opcion := PanelContainer.new()
		contenedor_opcion.name = "OpcionEterium%d" % (i + 1)
		contenedor_opcion.custom_minimum_size = Vector2(220.0, 34.0)
		contenedor_opcion.size = Vector2(220.0, 34.0)
		contenedor_opcion.position = Vector2(
			(get_viewport_rect().size.x - 220.0) * 0.5,
			get_viewport_rect().size.y * 0.5 - 55.0 + float(i) * 39.0
		)
		var estilo_opcion := StyleBoxFlat.new()
		estilo_opcion.bg_color = Color(0.105, 0.071, 0.043, 0.98)
		estilo_opcion.border_color = Color(0.48, 0.32, 0.17, 1.0)
		estilo_opcion.set_border_width_all(1)
		estilo_opcion.set_corner_radius_all(4)
		estilo_opcion.content_margin_left = 4.0
		estilo_opcion.content_margin_right = 4.0
		estilo_opcion.content_margin_top = 2.0
		estilo_opcion.content_margin_bottom = 2.0
		contenedor_opcion.add_theme_stylebox_override("panel", estilo_opcion)
		contenedor_opcion.mouse_filter = Control.MOUSE_FILTER_STOP
		_overlay.add_child(contenedor_opcion)

		var boton := Button.new()
		boton.name = "AccionEterium%d" % (i + 1)
		boton.text = opciones[i]
		boton.custom_minimum_size = Vector2(210.0, 28.0)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.alignment = HORIZONTAL_ALIGNMENT_CENTER
		boton.add_theme_font_size_override("font_size", 12)
		boton.add_theme_color_override("font_color", Color(0.91, 0.83, 0.70, 1.0))
		boton.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.82, 1.0))
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.105, 0.071, 0.043, 1.0)
		normal.border_color = Color(0.0, 0.0, 0.0, 0.0)
		normal.set_border_width_all(0)
		normal.set_corner_radius_all(3)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.19, 0.125, 0.065, 1.0)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.25, 0.16, 0.08, 1.0)
		boton.add_theme_stylebox_override("normal", normal)
		boton.add_theme_stylebox_override("hover", hover)
		boton.add_theme_stylebox_override("pressed", pressed)
		boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		boton.pressed.connect(_seleccionar.bind(i))
		contenedor_opcion.add_child(boton)
		_botones.append(boton)

func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var tecla := event as InputEventKey
	var es_espacio := tecla.keycode == KEY_SPACE or tecla.physical_keycode == KEY_SPACE
	if es_espacio:
		if tecla.echo:
			get_viewport().set_input_as_handled()
			return
		if tecla.pressed:
			_al_presionar_espacio()
		else:
			_al_soltar_espacio()
		get_viewport().set_input_as_handled()
		return
	if not tecla.pressed or tecla.echo:
		return
	if not _estado_minijuego.is_empty() and not visible_menu:
		if tecla.keycode == KEY_ESCAPE:
			_fallar_minijuego("Cancelaste el minijuego.")
		get_viewport().set_input_as_handled()
		return
	if _admin_abierto() or _otra_interfaz_abierta():
		if visible_menu:
			_cerrar()
		return
	if visible_menu:
		if tecla.keycode >= KEY_1 and tecla.keycode <= KEY_3:
			_seleccionar(tecla.keycode - KEY_1)
			get_viewport().set_input_as_handled()
			return
		if tecla.keycode == KEY_ESCAPE or tecla.keycode == KEY_X:
			_cerrar()
			get_viewport().set_input_as_handled()
			return
	if tecla.keycode == KEY_X:
		_abrir()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _estado_minijuego == "esperando_toques":
		if _espacio_pulsado:
			_tiempo_sostenido += delta
			if _tiempo_sostenido >= TIEMPO_CONCENTRACION:
				_iniciar_concentracion()
		else:
			_tiempo_ventana_toques -= delta
			if _tiempo_ventana_toques <= 0.0:
				_iniciar_minijuego_curacion()
	elif _estado_minijuego == "concentracion":
		if _espacio_pulsado:
			_tiempo_sostenido += delta
			_actualizar_panel_minijuego("CONCENTRACIÓN", "")
			_minijuego_barra.value = _tiempo_sostenido / TIEMPO_CONCENTRACION * 100.0
			if _tiempo_sostenido >= TIEMPO_CONCENTRACION:
				_estado_minijuego = "eterium"
				_fase_meditacion = "inicial"
				_tiempo_fase = 0.0
				_ciclos_meditacion = 0
				_actualizar_panel_minijuego("SIGUE EL PULSO", "")
				_minijuego_barra.value = 0.0
	elif _estado_minijuego == "eterium":
		_tiempo_fase += delta
		if _fase_meditacion == "soltar" and _tiempo_fase > 0.75:
			_fallar_minijuego("Soltaste demasiado tarde.")
		elif _fase_meditacion == "mantener" and _tiempo_fase > 0.9:
			_fallar_minijuego("Mantuviste ESPACIO demasiado tiempo.")
	elif _estado_minijuego == "dash_menu":
		_tiempo_minijuego = maxf(0.0, _tiempo_minijuego - delta)
		_actualizar_panel_minijuego("DASH · %d/2" % _toques_curacion, "ESPACIO × 2")
		_minijuego_barra.value = float(_toques_curacion) / 2.0 * 100.0
		_minijuego_tiempo.visible = true
		_minijuego_tiempo.value = _tiempo_minijuego / DURACION_DASH_MINIJUEGO * 100.0
		if _tiempo_minijuego <= 0.0:
			_fallar_minijuego("No completaste las dos pulsaciones.")
	elif _estado_minijuego == "curacion":
		_tiempo_minijuego = maxf(0.0, _tiempo_minijuego - delta)
		_actualizar_panel_minijuego("Curación · %d/%d" % [_toques_curacion, TOQUES_CURACION_NECESARIOS], "Pulsa ESPACIO tantas veces como puedas durante 5 segundos.")
		_minijuego_barra.value = minf(100.0, float(_toques_curacion) / TOQUES_CURACION_NECESARIOS * 100.0)
		_minijuego_tiempo.value = _tiempo_minijuego / DURACION_CURACION * 100.0
		if _tiempo_minijuego <= 0.0:
			if _toques_curacion >= TOQUES_CURACION_NECESARIOS:
				_completar_curacion()
			else:
				_fallar_minijuego("No alcanzaste las %d pulsaciones." % TOQUES_CURACION_NECESARIOS)
	_actualizar_indicador_tiempo()


func _al_presionar_espacio() -> void:
	if _admin_abierto() or _otra_interfaz_abierta():
		return
	if _estado_minijuego == "curacion":
		_toques_curacion += 1
		return
	if _estado_minijuego == "dash_menu":
		_toques_curacion += 1
		if _toques_curacion >= 2:
			_recuperar_dash_directo()
			_limpiar_minijuego()
		return
	if _estado_minijuego == "espera_meditacion":
		_espacio_pulsado = true
		_tiempo_sostenido = 0.0
		_estado_minijuego = "concentracion"
		_mostrar_minijuego()
		return
	if _estado_minijuego == "eterium":
		if _espacio_pulsado:
			return
		_espacio_pulsado = true
		if _fase_meditacion == "soltar":
			if _tiempo_fase < 0.2 or _tiempo_fase > 0.75:
				_fallar_minijuego("No seguiste el ritmo.")
				return
			_fase_meditacion = "mantener"
			_tiempo_fase = 0.0
			_actualizar_panel_minijuego("MANTÉN", "")
		return
	if visible_menu:
		return
	if _estado_minijuego == "esperando_toques":
		if _espacio_pulsado:
			return
		_espacio_pulsado = true
		_tiempo_sostenido = 0.0
		_toques_espacio += 1
		if _toques_espacio >= 2:
			_recuperar_dash_directo()
			_limpiar_minijuego()
			return
		_tiempo_ventana_toques = VENTANA_TOQUES
		return
	if not _estado_minijuego.is_empty():
		return
	if not is_instance_valid(jugador) or not bool(jugador.get("is_alive")):
		return
	_estado_minijuego = "esperando_toques"
	add_to_group("modal_ui")
	_espacio_pulsado = true
	_tiempo_sostenido = 0.0
	_toques_espacio = 1
	_tiempo_ventana_toques = VENTANA_TOQUES


func _al_soltar_espacio() -> void:
	if not _espacio_pulsado:
		return
	_espacio_pulsado = false
	if _estado_minijuego == "concentracion":
		_fallar_minijuego("Soltaste antes de completar los 4 segundos.")
	elif _estado_minijuego == "eterium":
		if _fase_meditacion == "inicial":
			_fase_meditacion = "soltar"
			_tiempo_fase = 0.0
			_actualizar_panel_minijuego("SUELTA", "")
		elif _fase_meditacion == "mantener":
			if _tiempo_fase < 0.35:
				_fallar_minijuego("Soltaste antes de completar el pulso.")
				return
			_ciclos_meditacion += 1
			_minijuego_barra.value = float(_ciclos_meditacion) / CICLOS_MEDITACION_NECESARIOS * 100.0
			if _ciclos_meditacion >= CICLOS_MEDITACION_NECESARIOS:
				_completar_meditacion()
			else:
				_fase_meditacion = "soltar"
				_tiempo_fase = 0.0
				_actualizar_panel_minijuego("PULSO %d/%d" % [_ciclos_meditacion, CICLOS_MEDITACION_NECESARIOS], "")


func _construir_interfaz_minijuego() -> void:
	_minijuego_layer = Control.new()
	_minijuego_layer.name = "MinijuegoEterium"
	_minijuego_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_minijuego_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_minijuego_layer.visible = false
	_minijuego_layer.z_index = 80
	add_child(_minijuego_layer)
	var sombra := ColorRect.new()
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.color = Color(0.025, 0.018, 0.012, 0.58)
	sombra.mouse_filter = Control.MOUSE_FILTER_STOP
	_minijuego_layer.add_child(sombra)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -150.0
	panel.offset_top = -52.0
	panel.offset_right = 150.0
	panel.offset_bottom = 52.0
	panel.custom_minimum_size = Vector2(300.0, 104.0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.09, 0.061, 0.038, 0.98)
	estilo.border_color = Color(0.55, 0.39, 0.21, 1.0)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(5)
	estilo.content_margin_left = 10.0
	estilo.content_margin_right = 10.0
	estilo.content_margin_top = 6.0
	estilo.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", estilo)
	_minijuego_layer.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 7)
	panel.add_child(columna)
	_minijuego_titulo = Label.new()
	_minijuego_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minijuego_titulo.add_theme_font_size_override("font_size", 14)
	_minijuego_titulo.add_theme_color_override("font_color", Color(0.94, 0.83, 0.65, 1.0))
	columna.add_child(_minijuego_titulo)
	_minijuego_instruccion = Label.new()
	_minijuego_instruccion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minijuego_instruccion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_minijuego_instruccion.add_theme_font_size_override("font_size", 10)
	_minijuego_instruccion.add_theme_color_override("font_color", Color(0.78, 0.68, 0.53, 1.0))
	columna.add_child(_minijuego_instruccion)
	_minijuego_barra = ProgressBar.new()
	_minijuego_barra.custom_minimum_size = Vector2(0.0, 20.0)
	_minijuego_barra.min_value = 0.0
	_minijuego_barra.max_value = 100.0
	_minijuego_barra.show_percentage = false
	columna.add_child(_minijuego_barra)
	_minijuego_tiempo = ProgressBar.new()
	_minijuego_tiempo.custom_minimum_size = Vector2(0.0, 5.0)
	_minijuego_tiempo.min_value = 0.0
	_minijuego_tiempo.max_value = 100.0
	_minijuego_tiempo.show_percentage = false
	columna.add_child(_minijuego_tiempo)
	_indicador_tiempo = Label.new()
	_indicador_tiempo.visible = false
	_indicador_tiempo.add_theme_font_size_override("font_size", 11)
	_indicador_tiempo.add_theme_color_override("font_color", Color(0.96, 0.84, 0.63, 1.0))
	_indicador_tiempo.add_theme_color_override("font_outline_color", Color(0.035, 0.025, 0.015, 1.0))
	_indicador_tiempo.add_theme_constant_override("outline_size", 3)
	_indicador_tiempo.size = Vector2(150.0, 22.0)
	_indicador_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicador_tiempo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_indicador_tiempo)


func _iniciar_minijuego_curacion() -> void:
	if not is_instance_valid(jugador):
		_limpiar_minijuego()
		return
	if int(jugador.get("health")) >= int(jugador.get("max_health")):
		_notificar("La salud ya está completa.")
		_limpiar_minijuego()
		return
	if int(jugador.get("mana")) < COSTO_CURACION:
		_notificar("Necesitas 10 de Eterium para intentar curarte.")
		_limpiar_minijuego()
		return
	_estado_minijuego = "curacion"
	_tiempo_minijuego = DURACION_CURACION
	_toques_curacion = 0
	_mostrar_minijuego()
	_actualizar_panel_minijuego("Curación · 0/%d" % TOQUES_CURACION_NECESARIOS, "Pulsa ESPACIO tantas veces como puedas durante 5 segundos.")
	_minijuego_barra.value = 0.0
	_minijuego_tiempo.visible = true
	_minijuego_tiempo.value = 100.0


func _iniciar_concentracion() -> void:
	# Los cuatro segundos ya se cumplieron antes de entrar aquí.
	_estado_minijuego = "eterium"
	_fase_meditacion = "inicial"
	_tiempo_fase = 0.0
	_ciclos_meditacion = 0
	_mostrar_minijuego()
	_actualizar_panel_minijuego("SIGUE EL PULSO", "")
	_minijuego_barra.value = 0.0
	_minijuego_tiempo.visible = false


func _iniciar_meditacion_desde_menu() -> void:
	if not is_instance_valid(jugador):
		return
	var eterium_actual: Variant = jugador.get("eterium")
	if eterium_actual == null or not eterium_actual.has_method("mana") or not eterium_actual.has_method("max_mana"):
		_notificar("El sistema de Eterium no está disponible.")
		return
	if int(eterium_actual.call("mana")) >= int(eterium_actual.call("max_mana")):
		_notificar("Tu Eterium ya está completo.")
		return
	_estado_minijuego = "espera_meditacion"
	_espacio_pulsado = false
	_minijuego_tiempo.visible = false
	_mostrar_minijuego()
	_actualizar_panel_minijuego("MEDITAR", "MANTÉN ESPACIO")


func _completar_curacion() -> void:
	_estado_minijuego = ""
	if not is_instance_valid(jugador) or not jugador.has_method("heal"):
		_limpiar_minijuego()
		return
	if not jugador.eterium.gastar(COSTO_CURACION):
		_fallar_minijuego("No tienes suficiente Eterium.")
		return
	jugador.heal(maxi(1, roundi(float(jugador.get("max_health")) * 0.25)))
	if jugador.has_method("_sync_desde_vital"):
		jugador.call("_sync_desde_vital")
	if jugador.has_signal("health_changed"):
		jugador.health_changed.emit(int(jugador.get("health")), int(jugador.get("max_health")))
	if jugador.has_signal("mana_changed"):
		jugador.mana_changed.emit(int(jugador.get("mana")), int(jugador.get("max_mana")))
	_notificar("Curación completada.")
	_limpiar_minijuego()


func _completar_meditacion() -> void:
	_estado_minijuego = ""
	var eterium_actual: Variant = jugador.get("eterium") if is_instance_valid(jugador) else null
	if eterium_actual == null or not eterium_actual.has_method("restaurar"):
		_fallar_minijuego("No se pudo recuperar Eterium.")
		return
	if bool(eterium_actual.call("restaurar", RECUPERACION_MEDITACION)):
		if jugador.has_method("_sync_desde_vital"):
			jugador.call("_sync_desde_vital")
		if jugador.has_signal("mana_changed"):
			jugador.mana_changed.emit(int(jugador.get("mana")), int(jugador.get("max_mana")))
		_notificar("Meditación completada: recuperaste Eterium.")
	else:
		_notificar("No se pudo recuperar más Eterium.")
	_limpiar_minijuego()


func _recuperar_dash_directo() -> void:
	if not is_instance_valid(jugador) or not jugador.has_method("recuperar_dash_con_eterium"):
		return
	var recuperadas: int = jugador.call("recuperar_dash_con_eterium", 1, COSTO_CARGA_DASH)
	if recuperadas > 0:
		_notificar("Dash recuperado (10 de Eterium).")
	else:
		_notificar("No puedes recuperar una carga: revisa Eterium y cargas.")


func _fallar_minijuego(mensaje: String) -> void:
	_estado_minijuego = ""
	if is_instance_valid(jugador):
		var eterium_actual: Variant = jugador.get("eterium")
		if eterium_actual != null and eterium_actual.has_method("gastar") and eterium_actual.has_method("mana"):
			var disponible := int(eterium_actual.call("mana"))
			if disponible > 0:
				eterium_actual.call("gastar", mini(COSTO_FALLO_MINIJUEGO, disponible))
				if jugador.has_method("_sync_desde_vital"):
					jugador.call("_sync_desde_vital")
				if jugador.has_signal("mana_changed"):
					jugador.mana_changed.emit(int(jugador.get("mana")), int(jugador.get("max_mana")))
	_notificar(mensaje + " Perdiste hasta %d de Eterium." % COSTO_FALLO_MINIJUEGO)
	_limpiar_minijuego()


func _limpiar_minijuego() -> void:
	_estado_minijuego = ""
	_fase_meditacion = ""
	if is_in_group("modal_ui"):
		remove_from_group("modal_ui")
	if is_instance_valid(_minijuego_layer) and _minijuego_layer.is_in_group("modal_ui"):
		_minijuego_layer.remove_from_group("modal_ui")
	_espacio_pulsado = false
	_tiempo_sostenido = 0.0
	_tiempo_ventana_toques = 0.0
	_toques_espacio = 0
	_tiempo_minijuego = 0.0
	_tiempo_fase = 0.0
	_ciclos_meditacion = 0
	if is_instance_valid(_minijuego_layer):
		_minijuego_layer.visible = false
	if is_instance_valid(_indicador_tiempo):
		_indicador_tiempo.visible = false


func _mostrar_minijuego() -> void:
	visible = true
	if is_instance_valid(_overlay):
		_overlay.visible = false
	visible_menu = false
	_minijuego_layer.visible = true
	_minijuego_layer.add_to_group("modal_ui")
	_minijuego_tiempo.visible = _estado_minijuego in ["curacion", "dash_menu"]
	_indicador_tiempo.visible = _estado_minijuego in ["concentracion", "eterium"]


func _actualizar_panel_minijuego(titulo: String, instruccion: String) -> void:
	if not is_instance_valid(_minijuego_titulo):
		return
	_minijuego_titulo.text = titulo
	_minijuego_instruccion.text = instruccion
	_minijuego_instruccion.visible = not instruccion.is_empty()


func _actualizar_indicador_tiempo() -> void:
	if not is_instance_valid(_indicador_tiempo) or not is_instance_valid(jugador):
		return
	var mostrar := _estado_minijuego in ["concentracion", "eterium"] or (_estado_minijuego == "esperando_toques" and _espacio_pulsado and _tiempo_sostenido > 0.15)
	_indicador_tiempo.visible = mostrar
	if not mostrar:
		return
	if _estado_minijuego in ["esperando_toques", "concentracion"]:
		_indicador_tiempo.text = "Concentración %.1fs" % maxf(0.0, TIEMPO_CONCENTRACION - _tiempo_sostenido)
	else:
		_indicador_tiempo.text = "Ritmo %d/%d" % [_ciclos_meditacion, CICLOS_MEDITACION_NECESARIOS]
	var transformacion: Transform2D = (jugador as Node2D).get_global_transform_with_canvas()
	_indicador_tiempo.position = transformacion.origin + Vector2(-75.0, -52.0)


func _al_cambio_vida_minijuego(vida: int, _maxima: int) -> void:
	if _ultima_vida >= 0 and vida < _ultima_vida:
		if _estado_minijuego in ["concentracion", "eterium"]:
			_fallar_minijuego("Recibiste daño y perdiste la concentración.")
		elif _estado_minijuego == "esperando_toques" and _espacio_pulsado:
			_fallar_minijuego("Recibiste daño durante la concentración.")
	_ultima_vida = vida


func toggle_menu() -> void:
	if visible_menu:
		_cerrar()
	else:
		_abrir()


func _abrir() -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	visible = true
	visible_menu = true
	_overlay.visible = true
	_actualizar_resumen()

func _cerrar() -> void:
	visible_menu = false
	if is_instance_valid(_overlay):
		_overlay.visible = false
	cuadrante = -1
	visible = true

func _actualizar_resumen() -> void:
	var eterium: Variant = jugador.get("eterium") if jugador != null and is_instance_valid(jugador) else null
	if _botones.size() >= 3:
		_botones[0].disabled = jugador == null or int(jugador.get("health")) >= int(jugador.get("max_health"))
		_botones[1].disabled = jugador == null or not jugador.has_method("recuperar_dash_con_eterium")
		_botones[2].disabled = eterium == null or not eterium.has_method("mana") or not eterium.has_method("max_mana") or int(eterium.call("mana")) >= int(eterium.call("max_mana"))

func _seleccionar(indice: int) -> void:
	cuadrante = indice
	_ejecutar_seleccion()

func _ejecutar_seleccion() -> void:
	var seleccion := cuadrante
	_cerrar()
	match seleccion:
		0:
			_curarse()
		1:
			_recuperar_dash()
		2:
			_meditar()

func _curarse() -> void:
	_iniciar_minijuego_curacion()


func _recuperar_dash() -> void:
	if not is_instance_valid(jugador):
		return
	_estado_minijuego = "dash_menu"
	_toques_curacion = 0
	_tiempo_minijuego = DURACION_DASH_MINIJUEGO
	_mostrar_minijuego()
	_actualizar_panel_minijuego("DASH · 0/2", "ESPACIO × 2")
	_minijuego_barra.value = 0.0
	_minijuego_tiempo.visible = true
	_minijuego_tiempo.value = 100.0


func _meditar() -> void:
	_iniciar_meditacion_desde_menu()


func _abrir_laboratorio_ium() -> void:
	if ium_lab == null or not is_instance_valid(ium_lab):
		_notificar("El menú de IUMs no está disponible.")
		return
	if ium_lab.has_method("_abrir"):
		ium_lab.call("_abrir")
	else:
		Input.action_press("open_ium_lab")
		Input.action_release("open_ium_lab")

func _usar_conjuro() -> void:
	if ium_manager == null or not is_instance_valid(ium_manager):
		_notificar("El sistema de IUMs no está disponible.")
		return
	if ium_manager.has_method("usar_proceso_equipado"):
		var objetivo := _buscar_objetivo_cercano()
		_ium_manager_usar_conjuro(objetivo)

func _buscar_objetivo_cercano() -> Node:
	if jugador == null or not is_instance_valid(jugador):
		return null
	var mejor: Node = null
	var mejor_distancia := 160.0
	for candidato in get_tree().get_nodes_in_group("creatures"):
		if candidato == null or not is_instance_valid(candidato):
			continue
		if not candidato is Node2D or not bool(candidato.get("is_alive")):
			continue
		var distancia := (candidato as Node2D).global_position.distance_to((jugador as Node2D).global_position)
		if distancia <= mejor_distancia:
			mejor_distancia = distancia
			mejor = candidato
	return mejor

func _ium_manager_usar_conjuro(objetivo: Node) -> void:
	if ium_manager.has_method("usar_proceso_equipado"):
		var equipado: Dictionary = ium_manager.get("proceso_equipado")
		if equipado.is_empty():
			_notificar("Primero equipa un proceso en el menú de IUMs.")
			return
		ium_manager.call("usar_proceso_equipado", objetivo)

func _notificar(mensaje: String) -> void:
	if Events != null and Events.has_signal("notification_pushed"):
		Events.notification_pushed.emit(mensaje)

func _admin_abierto() -> bool:
	return is_instance_valid(admin_console) and admin_console.has_method("esta_abierta") and admin_console.call("esta_abierta")

func _otra_interfaz_abierta() -> bool:
	if is_instance_valid(inventario) and inventario.has_method("esta_abierto") and inventario.call("esta_abierto"):
		return true
	return is_instance_valid(ium_lab) and bool(ium_lab.get("visible"))


