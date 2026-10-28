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


func configurar(player: Node, lab: Node, manager: Node, inventory: Node, admin: Node) -> void:
	jugador = player
	ium_lab = lab
	ium_manager = manager
	inventario = inventory
	admin_console = admin

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_crear_interfaz()

func _crear_interfaz() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Fondo"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.035, 0.022, 0.012, 0.34)
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
	if _admin_abierto() or _otra_interfaz_abierta():
		if visible_menu:
			_cerrar()
		return
	if event is not InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed or tecla.echo:
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

func toggle_menu() -> void:
	if visible_menu:
		_cerrar()
	else:
		_abrir()


func _abrir() -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	visible_menu = true
	visible = true
	_actualizar_resumen()

func _cerrar() -> void:
	visible_menu = false
	visible = false
	cuadrante = -1

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
	match cuadrante:
		0:
			_curarse()
		1:
			_recuperar_dash()
		2:
			_meditar()
 
	_cerrar()

func _curarse() -> void:
	if jugador == null or not jugador.has_method("heal"):
		_notificar("No se puede curar ahora.")
		return
	if int(jugador.get("health")) >= int(jugador.get("max_health")):
		_notificar("La salud ya está completa.")
		return
	if not jugador.eterium.gastar(COSTO_CURACION):
		_notificar("No tienes suficiente Eterium.")
		return
	jugador.heal(maxi(1, roundi(float(jugador.get("max_health")) * 0.25)))
	if jugador.has_method("_sync_desde_vital"):
		jugador.call("_sync_desde_vital")
	if jugador.has_signal("mana_changed"):
		jugador.mana_changed.emit(int(jugador.get("mana")), int(jugador.get("max_mana")))
	if jugador.has_signal("health_changed"):
		jugador.health_changed.emit(int(jugador.get("health")), int(jugador.get("max_health")))
	_notificar("Eterium consumido: curación.")

func _recuperar_dash() -> void:
	if jugador == null or not jugador.has_method("recuperar_dash_con_eterium"):
		return
	var recuperadas: int = jugador.recuperar_dash_con_eterium(1, COSTO_CARGA_DASH)
	if recuperadas > 0:
		_notificar("Carga de dash recuperada.")
	else:
		_notificar("No puedes recuperar una carga: revisa Eterium y cargas.")

func _meditar() -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	var eterium: Variant = jugador.get("eterium")
	if eterium == null:
		_notificar("El sistema de Eterium no está disponible.")
		return
	if not eterium.has_method("restaurar") or not eterium.has_method("mana") or not eterium.has_method("max_mana"):
		_notificar("No se puede recuperar Eterium ahora.")
		return
	if int(eterium.call("mana")) >= int(eterium.call("max_mana")):
		_notificar("Tu Eterium ya está completo.")
		return
	if bool(eterium.call("restaurar", RECUPERACION_MEDITACION)):
		if jugador.has_method("_sync_desde_vital"):
			jugador.call("_sync_desde_vital")
		if jugador.has_signal("mana_changed"):
			jugador.emit_signal("mana_changed", int(jugador.get("mana")), int(jugador.get("max_mana")))
		_notificar("Meditaste y recuperaste Eterium.")
	else:
		_notificar("No puedes meditar para recuperar Eterium ahora.")


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


