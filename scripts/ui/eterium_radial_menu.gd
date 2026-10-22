extends Control
class_name EteriumRadialMenu

## Menú radial transparente de acciones de Eterium.
## Mantén X, apunta con el ratón a un cuadrante y haz clic para ejecutar.

const COSTO_CURACION: int = 10
const COSTO_CARGA_DASH: int = 10
const TAMANO_CUADRANTE: float = 110.0

var jugador: Node = null
var ium_lab: Node = null
var ium_manager: Node = null
var inventario: Node = null
var admin_console: Node = null
var visible_menu: bool = false
var cuadrante: int = -1
var _centro: Vector2 = Vector2.ZERO

const NOMBRES := [
	"Curarse",
	"Recuperar dash",
	"Menú de IUMs",
	"Usar conjuro equipado"
]

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
	_centro_inicializar()

func _centro_inicializar() -> void:
	_centro = get_viewport_rect().size * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_centro_inicializar()
		queue_redraw()

func _input(event: InputEvent) -> void:
	if _admin_abierto() or _otra_interfaz_abierta():
		if visible_menu:
			_cerrar()
		return
	if event is InputEventKey:
		var tecla := event as InputEventKey
		if tecla.pressed and not tecla.echo and tecla.keycode == KEY_X:
			if visible_menu:
				_cerrar()
			else:
				_abrir()
			get_viewport().set_input_as_handled()
			return
	if not visible_menu:
		return
	if event is InputEventMouseMotion:
		_actualizar_cuadrante((event as InputEventMouseMotion).position)
		queue_redraw()
	elif event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.button_index == MOUSE_BUTTON_LEFT and boton.pressed:
			_actualizar_cuadrante(boton.position)
			_ejecutar_seleccion()
			get_viewport().set_input_as_handled()
		elif boton.button_index == MOUSE_BUTTON_RIGHT and boton.pressed:
			_cerrar()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_cerrar()
		get_viewport().set_input_as_handled()

func _abrir() -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	_centro_inicializar()
	cuadrante = -1
	visible_menu = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _cerrar() -> void:
	visible_menu = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cuadrante = -1
	queue_redraw()

func _actualizar_cuadrante(posicion: Vector2) -> void:
	var delta := posicion - _centro
	if delta.length() < 22.0:
		cuadrante = -1
	elif delta.x < 0.0 and delta.y < 0.0:
		cuadrante = 0 # superior izquierda: curación
	elif delta.x >= 0.0 and delta.y < 0.0:
		cuadrante = 1 # superior derecha: recuperar dash
	elif delta.x < 0.0 and delta.y >= 0.0:
		cuadrante = 2 # inferior izquierda: laboratorio IUM
	else:
		cuadrante = 3 # inferior derecha: conjuro equipado

func _ejecutar_seleccion() -> void:
	match cuadrante:
		0:
			_curarse()
		1:
			_recuperar_dash()
		2:
			_abrir_laboratorio_ium()
		3:
			_usar_conjuro()
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

func _abrir_laboratorio_ium() -> void:
	if ium_lab == null or not is_instance_valid(ium_lab):
		_notificar("El menú de IUMs no está disponible.")
		return
	if ium_lab.has_method("_abrir"):
		_ium_lab_abrir()
	else:
		Input.action_press("open_ium_lab")
		Input.action_release("open_ium_lab")

func _ium_lab_abrir() -> void:
	if ium_lab.has_method("_abrir"):
		_ium_lab.call("_abrir")

func _usar_conjuro() -> void:
	if ium_manager == null or not is_instance_valid(ium_manager):
		_notificar("El sistema de IUMs no está disponible.")
		return
	if ium_manager.has_method("usar_proceso_equipado"):
		var objetivo: Node = null
		if jugador != null and jugador.has_method("obtener_objetivo_combate"):
			objetivo = jugador.call("obtener_objetivo_combate")
			if objetivo != null:
				_ium_manager_usar_conjuro(objetivo)
				return
		_ium_manager_usar_conjuro(null)

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

func _draw() -> void:
	if not visible_menu:
		return
	var sombra := Color(0.035, 0.025, 0.018, 0.58)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.01, 0.16), true)
	var brazos := [
		Vector2(-1, -1), Vector2(1, -1),
		Vector2(-1, 1), Vector2(1, 1)
	]
	for i in range(4):
		var dir: Vector2 = brazos[i].normalized()
		var inicio := _centro + dir * 20.0
		var fin := _centro + dir * TAMANO_CUADRANTE
		var color := Color(0.78, 0.66, 0.46, 0.95) if i == cuadrante else Color(0.45, 0.32, 0.21, 0.85)
		draw_line(inicio, fin, color, 3.0, true)
		draw_circle(fin, 5.0 if i == cuadrante else 3.5, color)
		var texto := NOMBRES[i]
		var caja := Rect2(fin + Vector2(-78, -23), Vector2(156, 46))
		draw_rect(caja, Color(0.055, 0.038, 0.025, 0.78), true)
		draw_rect(caja, color, false, 1.0)
		draw_string(ThemeDB.fallback_font, caja.position + Vector2(8, 27), texto, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(0.95, 0.88, 0.73, 1.0))
	draw_circle(_centro, 15.0, sombra)
	draw_arc(_centro, 15.0, 0.0, TAU, 32, Color(0.78, 0.66, 0.46, 1.0), 2.0, true)
