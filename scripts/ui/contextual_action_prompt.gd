extends Button
class_name ContextualActionPrompt
## Aviso contextual reutilizable. Gestiona su aspecto y la acción por clic;
## el nodo propietario decide cuándo está disponible.

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

var _accion: String = ""
var _obtener_jugador: Callable
var _obtener_objetivo: Callable
var _condicion: Callable
var _distancia_maxima := 68.0
var _contexto_configurado := false

func _ready() -> void:
	name = "ContextualActionPrompt"
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(250.0, 38.0)
	size = custom_minimum_size
	visible = false
	PIXEL_UI_THEME.apply(self, false)

func configurar(
	accion: String,
	callback: Callable,
	obtener_jugador: Callable,
	obtener_objetivo: Callable,
	distancia_maxima: float = 68.0,
	condicion: Callable = Callable()
) -> void:
	establecer_accion(accion)
	_obtener_jugador = obtener_jugador
	_obtener_objetivo = obtener_objetivo
	_condicion = condicion
	_distancia_maxima = maxf(distancia_maxima, 0.0)
	_contexto_configurado = true
	if not pressed.is_connected(callback):
		pressed.connect(callback)


func _process(_delta: float) -> void:
	if not _contexto_configurado:
		establecer_disponible(false)
		return
	if not _condicion.is_null() and _condicion.is_valid() and not bool(_condicion.call()):
		establecer_disponible(false)
		return
	if not _obtener_jugador.is_valid() or not _obtener_objetivo.is_valid():
		establecer_disponible(false)
		return
	var jugador_variant: Variant = _obtener_jugador.call()
	var objetivo_variant: Variant = _obtener_objetivo.call()
	if not jugador_variant is Node2D or not objetivo_variant is Vector2:
		establecer_disponible(false)
		return
	var jugador := jugador_variant as Node2D
	var objetivo := objetivo_variant as Vector2
	establecer_disponible(jugador.is_inside_tree() and jugador.global_position.distance_to(objetivo) <= _distancia_maxima)

func establecer_accion(accion: String) -> void:
	_accion = accion.strip_edges()
	text = "[ CLIC ]   " + _accion
	tooltip_text = _accion

func establecer_disponible(disponible: bool) -> void:
	visible = disponible
	disabled = not disponible
