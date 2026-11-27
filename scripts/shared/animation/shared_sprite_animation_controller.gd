extends RefCounted
class_name SharedSpriteAnimationController

## Reproductor común para spritesheets 2D basados en Sprite2D.
## El movimiento, la IA y las reglas de cada entidad siguen fuera de este nodo.

var sprite: Sprite2D = null
var fps: float = 8.0
var primer_frame: int = 0
var cantidad_frames: int = 1
var repetir: bool = true
var reproduciendo: bool = false
var _tiempo: float = 0.0
var _ultimo_frame: int = -1


func configurar(nuevo_sprite: Sprite2D) -> void:
	sprite = nuevo_sprite
	detener(primer_frame)


func reproducir(
	nuevo_fps: float = 8.0,
	nuevo_primer_frame: int = 0,
	nueva_cantidad_frames: int = -1,
	repetir_animacion: bool = true
) -> void:
	if not is_instance_valid(sprite):
		return

	var total := maxi(1, sprite.hframes * sprite.vframes)
	primer_frame = clampi(nuevo_primer_frame, 0, total - 1)
	cantidad_frames = total - primer_frame if nueva_cantidad_frames <= 0 else clampi(nueva_cantidad_frames, 1, total - primer_frame)
	fps = maxf(nuevo_fps, 0.01)
	repetir = repetir_animacion
	_tiempo = 0.0
	_ultimo_frame = -1
	reproduciendo = cantidad_frames > 1
	_aplicar_frame(primer_frame)


func actualizar(delta: float) -> void:
	if not reproduciendo or not is_instance_valid(sprite):
		return

	_tiempo += maxf(delta, 0.0)
	var avance := int(floor(_tiempo * fps))
	if repetir:
		avance %= cantidad_frames
	elif avance >= cantidad_frames:
		avance = cantidad_frames - 1
		reproduciendo = false

	_aplicar_frame(primer_frame + avance)


func detener(frame: int = 0) -> void:
	reproduciendo = false
	_tiempo = 0.0
	_ultimo_frame = -1
	if is_instance_valid(sprite):
		_aplicar_frame(frame)


func _aplicar_frame(frame: int) -> void:
	if not is_instance_valid(sprite) or frame == _ultimo_frame:
		return
	var total := maxi(1, sprite.hframes * sprite.vframes)
	sprite.frame = clampi(frame, 0, total - 1)
	_ultimo_frame = sprite.frame
