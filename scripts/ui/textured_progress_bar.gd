extends Control
class_name TexturedProgressBar

## Barra de progreso dibujada con TextureRect de tamaño explícito.
## Evita depender del escalado interno de TextureProgressBar.
var _relleno: TextureRect
var _marco: TextureRect
var _progreso: float = 0.0
var _tamano_barra: Vector2 = Vector2(160.0, 16.0)

func configurar(textura_relleno: Texture2D, textura_marco: Texture2D, tamano: Vector2 = Vector2(160.0, 16.0)) -> void:
	_tamano_barra = tamano
	custom_minimum_size = tamano
	set_size(tamano)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_relleno = TextureRect.new()
	_relleno.name = "Relleno"
	_relleno.texture = textura_relleno
	_relleno.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_relleno.stretch_mode = TextureRect.STRETCH_SCALE
	_relleno.position = Vector2.ZERO
	_relleno.size = tamano
	_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_relleno)

	_marco = TextureRect.new()
	_marco.name = "Marco"
	_marco.texture = textura_marco
	_marco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_marco.stretch_mode = TextureRect.STRETCH_SCALE
	_marco.position = Vector2.ZERO
	_marco.size = tamano
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marco.z_index = 1
	add_child(_marco)
	actualizar_progreso(_progreso)

func actualizar_progreso(valor: float) -> void:
	_progreso = clampf(valor, 0.0, 1.0)
	if is_instance_valid(_relleno):
		_relleno.size = Vector2(_tamano_barra.x * _progreso, _tamano_barra.y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(_relleno) and is_instance_valid(_marco):
		_tamano_barra = size
		_marco.size = size
		actualizar_progreso(_progreso)
