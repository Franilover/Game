extends RefCounted
class_name PlayerEquipmentAnimationController

## Anima el objeto equipado como una capa independiente del personaje.
## La skin y sus prendas no necesitan variantes de estas animaciones.

var visual: Node2D = null
var sprite_base: Sprite2D = null
var _tween: Tween = null
var _sprite_equipo: Sprite2D = null

const PERFILES := {
	"espada": {"barrido": 1.75, "duracion": 0.18, "alcance": 19.0, "escala": 0.78},
	"hacha": {"barrido": 1.25, "duracion": 0.27, "alcance": 17.0, "escala": 0.78},
	"pico": {"barrido": 1.10, "duracion": 0.25, "alcance": 16.0, "escala": 0.78},
	"pala": {"barrido": 0.95, "duracion": 0.24, "alcance": 15.0, "escala": 0.78},
	"azada": {"barrido": 0.90, "duracion": 0.23, "alcance": 15.0, "escala": 0.78},
	"hoz": {"barrido": 1.45, "duracion": 0.22, "alcance": 17.0, "escala": 0.78},
	"regadera": {"barrido": 0.55, "duracion": 0.30, "alcance": 13.0, "escala": 0.72},
	"generica": {"barrido": 1.05, "duracion": 0.24, "alcance": 15.0, "escala": 0.76}
}


func configurar(nuevo_visual: Node2D, nuevo_sprite_base: Sprite2D) -> void:
	visual = nuevo_visual
	sprite_base = nuevo_sprite_base


static func obtener_tipo_animacion(objeto: Dictionary) -> String:
	var nombre := _normalizar(str(objeto.get("nombre", "")))
	var tipo := _normalizar(str(objeto.get("tipo", "")))
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	var propiedades: Dictionary = propiedades_variant as Dictionary if propiedades_variant is Dictionary else {}
	var herramienta_variant: Variant = propiedades.get("herramienta_recoleccion", {})
	var herramienta: Dictionary = herramienta_variant as Dictionary if herramienta_variant is Dictionary else {}
	var tipo_herramienta := _normalizar(str(herramienta.get("tipo", "")))
	var identidad := nombre + " " + tipo + " " + tipo_herramienta

	if "espada" in identidad or "sword" in identidad:
		return "espada"
	for clave in ["hacha", "pico", "pala", "azada", "hoz", "regadera"]:
		if clave in identidad:
			return clave
	return "generica"


static func obtener_perfil(objeto: Dictionary) -> Dictionary:
	var tipo := obtener_tipo_animacion(objeto)
	return (PERFILES.get(tipo, PERFILES["generica"]) as Dictionary).duplicate(true)


func reproducir(objeto: Dictionary, facing: Vector2) -> void:
	if not is_instance_valid(visual) or objeto.is_empty():
		return
	var textura := ItemIconResolver.obtener_icono(objeto)
	if textura == null:
		return

	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()
	if is_instance_valid(_sprite_equipo):
		_sprite_equipo.queue_free()
		_sprite_equipo = null

	var perfil := obtener_perfil(objeto)
	var direccion := facing.normalized()
	if direccion.length_squared() <= 0.01:
		direccion = Vector2.DOWN
	var perpendicular := Vector2(-direccion.y, direccion.x)
	var origen := sprite_base.position if is_instance_valid(sprite_base) else Vector2(0.0, -22.0)
	var alcance := float(perfil.get("alcance", 15.0))
	var barrido := float(perfil.get("barrido", 1.0))
	var duracion := float(perfil.get("duracion", 0.24))
	var escala := float(perfil.get("escala", 0.76))
	var angulo_base := direccion.angle() + PI * 0.5

	_sprite_equipo = Sprite2D.new()
	_sprite_equipo.name = "EquipmentActionSprite"
	_sprite_equipo.texture = textura
	_sprite_equipo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_equipo.centered = true
	_sprite_equipo.scale = Vector2.ONE * escala
	_sprite_equipo.z_index = 12
	_sprite_equipo.position = origen + direccion * 3.0 - perpendicular * 8.0
	_sprite_equipo.rotation = angulo_base - barrido * 0.5
	visual.add_child(_sprite_equipo)

	_tween = visual.create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(
		_sprite_equipo,
		"position",
		origen + direccion * alcance + perpendicular * 5.0,
		duracion * 0.58
	)
	_tween.parallel().tween_property(
		_sprite_equipo,
		"rotation",
		angulo_base + barrido * 0.5,
		duracion * 0.58
	)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(
		_sprite_equipo,
		"position",
		origen + direccion * 5.0 + perpendicular * 8.0,
		duracion * 0.42
	)
	_tween.parallel().tween_property(
		_sprite_equipo,
		"modulate:a",
		0.0,
		duracion * 0.42
	)
	_tween.tween_callback(_limpiar)


func _limpiar() -> void:
	if is_instance_valid(_sprite_equipo):
		_sprite_equipo.queue_free()
	_sprite_equipo = null
	_tween = null


static func _normalizar(valor: String) -> String:
	return valor.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("_", " ").strip_edges()
