extends Button
class_name ContextualActionPrompt
## Aviso contextual reutilizable. Gestiona su aspecto y la acción por clic;
## el nodo propietario decide cuándo está disponible.

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

var _accion: String = ""

func _ready() -> void:
	name = "ContextualActionPrompt"
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(250.0, 38.0)
	size = custom_minimum_size
	visible = false
	PIXEL_UI_THEME.apply(self, false)

func configurar(accion: String, callback: Callable) -> void:
	establecer_accion(accion)
	if pressed.is_connected(callback):
		return
	pressed.connect(callback)

func establecer_accion(accion: String) -> void:
	_accion = accion.strip_edges()
	text = "[ CLIC ]   " + _accion
	tooltip_text = _accion

func establecer_disponible(disponible: bool) -> void:
	visible = disponible
	disabled = not disponible
