extends Control
class_name EteriumRadialMenu

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

## Panel compacto de acciones de Eterium, integrado con el estilo de los menús del juego.
## Pulsa X para abrir; usa los botones o las teclas 1–3.

const COSTO_CURACION: int = 10
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
const TOQUES_CURACION_NECESARIOS := 12
const COSTO_FALLO_MINIJUEGO := 3
var _minijuego_layer: Control
var _minijuego_titulo: Label
var _minijuego_instruccion: Label
var _minijuego_barra: ProgressBar
var _minijuego_tiempo: ProgressBar
var _minijuego_sombra: ColorRect
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
	PIXEL_UI_THEME.apply(self)

func _crear_interfaz() -> void:
	_overlay = get_node("Fondo") as ColorRect
	if _overlay == null:
		push_error("EteriumRadialMenu: falta Fondo en la escena.")
		return
	_overlay.gui_input.connect(_al_input_overlay)
	_botones.clear()
	for i in range(2):
		var boton := _overlay.get_node_or_null("MenuPanel/Options/AccionEterium%d" % (i + 1)) as Button
		if boton == null:
			push_error("EteriumRadialMenu: falta el botón de acción %d." % (i + 1))
			continue
		boton.pressed.connect(_seleccionar.bind(i))
		_botones.append(boton)


func _al_input_overlay(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_cerrar()

func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var tecla := event as InputEventKey
	var es_espacio := tecla.keycode == KEY_SPACE or tecla.physical_keycode == KEY_SPACE
	if es_espacio:
		if tecla.pressed and not tecla.echo:
			if _estado_minijuego == "curacion":
				_registrar_toque_curacion()
			elif tecla.ctrl_pressed:
				_iniciar_minijuego_curacion()
				if _estado_minijuego == "curacion":
					_registrar_toque_curacion()
			else:
				_al_presionar_espacio()
		elif not tecla.pressed:
			_al_soltar_espacio()
		get_viewport().set_input_as_handled()
		return
	if not tecla.pressed or tecla.echo:
		return
	if _estado_minijuego == "concentracion":
		if tecla.keycode == KEY_ESCAPE:
			_al_soltar_espacio()
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
		if tecla.keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _estado_minijuego == "curacion":
		_tiempo_minijuego = maxf(_tiempo_minijuego - delta, 0.0)
		_minijuego_tiempo.value = _tiempo_minijuego / DURACION_CURACION * 100.0
		if _tiempo_minijuego <= 0.0:
			_fallar_minijuego("Se agotó el tiempo de curación.")
	if _estado_minijuego == "concentracion" and _espacio_pulsado:
		_tiempo_sostenido += delta
		_minijuego_barra.value = minf(100.0, _tiempo_sostenido / TIEMPO_CONCENTRACION * 100.0)
		_actualizar_panel_minijuego("CONCENTRANDO", "Mantén ESPACIO para recuperar Eterium.")
		if _tiempo_sostenido >= TIEMPO_CONCENTRACION:
			_completar_meditacion()
	_actualizar_indicador_tiempo()


func _al_presionar_espacio() -> void:
	if _admin_abierto() or _otra_interfaz_abierta() or visible_menu:
		return
	if (_estado_minijuego != "" and _estado_minijuego != "espera_meditacion") or not is_instance_valid(jugador):
		return
	if not bool(jugador.get("is_alive")):
		return
	var eterium_actual: Variant = jugador.get("eterium")
	if eterium_actual == null or not eterium_actual.has_method("mana") or not eterium_actual.has_method("max_mana"):
		return
	if int(eterium_actual.call("mana")) >= int(eterium_actual.call("max_mana")):
		return
	_estado_minijuego = "concentracion"
	add_to_group("modal_ui")
	_espacio_pulsado = true
	_tiempo_sostenido = 0.0
	_mostrar_minijuego()
	_actualizar_panel_minijuego("CONCENTRANDO", "Mantén ESPACIO para recuperar Eterium.")
	_minijuego_barra.value = 0.0
	_minijuego_tiempo.visible = false


func _al_soltar_espacio() -> void:
	if _estado_minijuego != "concentracion" or not _espacio_pulsado:
		return
	_espacio_pulsado = false
	_notificar("Concentración interrumpida.")
	_limpiar_minijuego()


func _construir_interfaz_minijuego() -> void:
	_minijuego_layer = get_node("MinijuegoEterium") as Control
	if _minijuego_layer == null:
		push_error("EteriumRadialMenu: falta MinijuegoEterium en la escena.")
		return
	_minijuego_sombra = _minijuego_layer.get_node("Sombra") as ColorRect
	_panel = _minijuego_layer.get_node("Panel") as PanelContainer
	_minijuego_titulo = _minijuego_layer.get_node("Panel/Columna/Titulo") as Label
	_minijuego_instruccion = _minijuego_layer.get_node("Panel/Columna/Instruccion") as Label
	_minijuego_barra = _minijuego_layer.get_node("Panel/Columna/Progreso") as ProgressBar
	_minijuego_tiempo = _minijuego_layer.get_node("Panel/Columna/Tiempo") as ProgressBar
	_indicador_tiempo = get_node("IndicadorTiempo") as Label


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


func _registrar_toque_curacion() -> void:
	if _estado_minijuego != "curacion":
		return
	_toques_curacion += 1
	_minijuego_barra.value = float(_toques_curacion) / float(TOQUES_CURACION_NECESARIOS) * 100.0
	_actualizar_panel_minijuego(
		"Curación · %d/%d" % [_toques_curacion, TOQUES_CURACION_NECESARIOS],
		"Pulsa ESPACIO hasta completar la barra."
	)
	if _toques_curacion >= TOQUES_CURACION_NECESARIOS:
		_completar_curacion()


func _iniciar_concentracion() -> void:
	# Los cuatro segundos ya se cumplieron antes de entrar aquí.
	_completar_meditacion()


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
	_actualizar_panel_minijuego("MEDITAR", "Mantén ESPACIO durante 4 segundos para recuperar Eterium.")


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
	var meditacion := _estado_minijuego in ["concentracion", "espera_meditacion"]
	if is_instance_valid(_minijuego_sombra):
		_minijuego_sombra.visible = not meditacion
	if is_instance_valid(_panel):
		_panel.visible = true
		if meditacion:
			_panel.offset_left = -150.0
			_panel.offset_top = 14.0
			_panel.offset_right = 150.0
			_panel.offset_bottom = 50.0
			_panel.custom_minimum_size = Vector2(300.0, 36.0)
	_minijuego_tiempo.visible = _estado_minijuego == "curacion"
	_indicador_tiempo.visible = _estado_minijuego == "concentracion"


func _actualizar_panel_minijuego(titulo: String, instruccion: String) -> void:
	if not is_instance_valid(_minijuego_titulo):
		return
	_minijuego_titulo.text = titulo
	_minijuego_instruccion.text = instruccion
	var meditacion := _estado_minijuego in ["concentracion", "espera_meditacion"]
	_minijuego_titulo.visible = not instruccion.is_empty() and not meditacion
	_minijuego_instruccion.visible = not instruccion.is_empty() and not meditacion


func _actualizar_indicador_tiempo() -> void:
	if not is_instance_valid(_indicador_tiempo) or not is_instance_valid(jugador):
		return
	var mostrar := _estado_minijuego in ["concentracion"] or (_estado_minijuego == "esperando_toques" and _espacio_pulsado and _tiempo_sostenido > 0.15)
	_indicador_tiempo.visible = mostrar
	if not mostrar:
		return
	_indicador_tiempo.text = "Concentración %.1fs" % maxf(0.0, TIEMPO_CONCENTRACION - _tiempo_sostenido)
	var transformacion: Transform2D = (jugador as Node2D).get_global_transform_with_canvas()
	_indicador_tiempo.position = transformacion.origin + Vector2(-75.0, -52.0)


func _al_cambio_vida_minijuego(vida: int, _maxima: int) -> void:
	if _ultima_vida >= 0 and vida < _ultima_vida:
		if _estado_minijuego == "concentracion":
			_fallar_minijuego("Recibiste daño y perdiste la concentración.")
		elif _estado_minijuego == "curacion":
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
	if _botones.size() >= 2:
		_botones[0].disabled = jugador == null or int(jugador.get("health")) >= int(jugador.get("max_health"))
		_botones[1].disabled = eterium == null or not eterium.has_method("mana") or not eterium.has_method("max_mana") or int(eterium.call("mana")) >= int(eterium.call("max_mana"))

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
			_meditar()

func _curarse() -> void:
	_iniciar_minijuego_curacion()


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


