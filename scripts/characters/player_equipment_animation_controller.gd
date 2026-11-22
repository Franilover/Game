extends RefCounted
class_name PlayerEquipmentAnimationController

## Anima el objeto equipado como una capa independiente del personaje.
## La skin y sus prendas no necesitan variantes de estas animaciones.

var visual: Node2D = null
var sprite_base: Sprite2D = null
var _tween: Tween = null
var _sprite_equipo: Sprite2D = null
var _pivot_equipo: Node2D = null

const ITEM_ICON_RESOLVER: Script = preload("res://scripts/ui/item_icon_resolver.gd")

# Perfiles compartidos por tipo de herramienta. Las duraciones incluyen
# preparación, golpe y recuperación para que cada acción pueda leerse.
const PERFILES := {
	"espada": {"barrido": 2.50, "duracion": 0.42, "alcance": 26.0, "escala": 1.05},
	"hacha": {"barrido": 1.95, "duracion": 0.58, "alcance": 24.0, "escala": 1.08},
	"pico": {"barrido": 1.45, "duracion": 0.50, "alcance": 23.0, "escala": 1.02},
	"pala": {"barrido": 1.40, "duracion": 0.68, "alcance": 24.0, "escala": 1.05},
	"azada": {"barrido": 1.55, "duracion": 0.52, "alcance": 22.0, "escala": 1.00},
	"hoz": {"barrido": 2.20, "duracion": 0.48, "alcance": 24.0, "escala": 1.02},
	"regadera": {"barrido": 0.90, "duracion": 0.55, "alcance": 18.0, "escala": 0.96},
	"generica": {"barrido": 1.60, "duracion": 0.44, "alcance": 22.0, "escala": 0.98}
}

# Recursos explícitos: no dependemos de que DirAccess descubra archivos
# para incluir los sprites de herramientas en una exportación PCK/APK.
const TEXTURAS_RESPALDO := {
	"espada": preload("res://assets/art/items/Espada de Madera.png"),
	"hacha": preload("res://assets/art/items/Hacha de Madera.png"),
	"pico": preload("res://assets/art/items/Pico de Madera.png"),
	"pala": preload("res://assets/art/items/Pala de Madera.png"),
	"azada": preload("res://assets/art/items/Azada Madera.png"),
	"regadera": preload("res://assets/art/items/regadera llena.png")
}


func configurar(nuevo_visual: Node2D, nuevo_sprite_base: Sprite2D) -> void:
	visual = nuevo_visual
	sprite_base = nuevo_sprite_base


static func obtener_tipo_animacion(objeto: Dictionary) -> String:
	var nombre := _normalizar(str(objeto.get("nombre", "")))
	var nombre_sprite := _normalizar(str(objeto.get("nombre_sprite", "")))
	var tipo := _normalizar(str(objeto.get("tipo", "")))
	var propiedades_variant: Variant = objeto.get("propiedades_game", {})
	var propiedades: Dictionary = propiedades_variant as Dictionary if propiedades_variant is Dictionary else {}
	var herramienta_variant: Variant = propiedades.get("herramienta_recoleccion", {})
	var herramienta: Dictionary = herramienta_variant as Dictionary if herramienta_variant is Dictionary else {}
	var tipo_herramienta := _normalizar(str(herramienta.get("tipo", "")))
	var identidad := nombre + " " + nombre_sprite + " " + tipo + " " + tipo_herramienta
	for clave_categoria in ["categoria", "categoria_canonica", "clase", "subtipo"]:
		var categoria_variant: Variant = objeto.get(clave_categoria, "")
		if categoria_variant is Dictionary:
			for campo in ["clave", "nombre", "nombre_humano"]:
				identidad += " " + _normalizar(str((categoria_variant as Dictionary).get(campo, "")))
		else:
			identidad += " " + _normalizar(str(categoria_variant))
	var tipo_objeto_variant: Variant = objeto.get("tipo_objeto", {})
	if tipo_objeto_variant is Dictionary:
		for campo in ["clave", "nombre", "nombre_humano", "categoria_canonica"]:
			identidad += " " + _normalizar(str((tipo_objeto_variant as Dictionary).get(campo, "")))

	if "espada" in identidad or "sword" in identidad:
		return "espada"
	for clave in ["hacha", "pico", "pala", "azada", "hoz", "regadera"]:
		if clave in identidad:
			return clave
	return "generica"


static func obtener_perfil(objeto: Dictionary) -> Dictionary:
	var tipo := obtener_tipo_animacion(objeto)
	return (PERFILES.get(tipo, PERFILES["generica"]) as Dictionary).duplicate(true)


static func obtener_textura_respaldo(tipo: String) -> Texture2D:
	return TEXTURAS_RESPALDO.get(tipo) as Texture2D


func reproducir(objeto: Dictionary, facing: Vector2) -> void:
	if not is_instance_valid(visual) or objeto.is_empty():
		return

	var tipo := obtener_tipo_animacion(objeto)
	# La animación nunca debe buscar archivos ni cargar recursos en el momento
	# del golpe: esa búsqueda síncrona provocaba el tirón al primer uso.
	# Si el inventario ya entrega una Texture2D, se reutiliza directamente;
	# en el resto de casos se usa el recurso precargado por tipo de herramienta.
	# Resolver por identidad del objeto equipado, no por el icono genérico
	# que algunas ranuras conservan como fallback (p. ej. espada de madera).
	var datos_sprite := objeto.duplicate(true)
	datos_sprite.erase("icono")
	var textura: Texture2D = ITEM_ICON_RESOLVER.obtener_icono(datos_sprite)
	if textura == null:
		var textura_variant: Variant = objeto.get("icono", null)
		textura = textura_variant as Texture2D if textura_variant is Texture2D else null
	if textura == null:
		textura = obtener_textura_respaldo(tipo)
	if textura == null:
		return

	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()
	if is_instance_valid(_pivot_equipo):
		_pivot_equipo.queue_free()
		_pivot_equipo = null
	_sprite_equipo = null

	var perfil := obtener_perfil(objeto)
	var direccion := facing.normalized()
	if direccion.length_squared() <= 0.01:
		direccion = Vector2.DOWN
	var perpendicular := Vector2(-direccion.y, direccion.x)
	var origen := sprite_base.position if is_instance_valid(sprite_base) else Vector2(0.0, -22.0)
	var alcance := float(perfil.get("alcance", 22.0))
	var barrido := float(perfil.get("barrido", 1.6))
	var duracion := float(perfil.get("duracion", 0.44))
	var escala := float(perfil.get("escala", 0.98))
	var angulo_base := direccion.angle() + PI * 0.5

	# El pivote queda en la empuñadura, cerca de la mano. El sprite se
	# desplaza hacia delante desde ese punto y rota alrededor del mango,
	# como una espada sostenida de verdad, en vez de girar sobre su centro.
	_pivot_equipo = Node2D.new()
	_pivot_equipo.name = "EquipmentActionPivot"
	_pivot_equipo.position = origen - direccion * 3.0 - perpendicular * 5.0
	_pivot_equipo.rotation = angulo_base - barrido * 0.62
	_pivot_equipo.z_index = 20
	visual.add_child(_pivot_equipo)

	_sprite_equipo = Sprite2D.new()
	_sprite_equipo.name = "EquipmentActionSprite"
	_sprite_equipo.texture = textura
	_sprite_equipo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_equipo.centered = true
	_sprite_equipo.scale = Vector2.ONE * escala
	_sprite_equipo.position = Vector2(0.0, -float(textura.get_height()) * 0.34)
	_pivot_equipo.add_child(_sprite_equipo)

	_tween = visual.create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	# La mano acompaña el golpe, pero la hoja gira desde la empuñadura.
	_tween.tween_interval(0.07)
	_tween.tween_property(
		_pivot_equipo,
		"position",
		origen + direccion * alcance * 0.32 + perpendicular * 2.0,
		duracion * 0.62
	)
	_tween.parallel().tween_property(
		_pivot_equipo,
		"rotation",
		angulo_base + barrido * 0.38,
		duracion * 0.62
	)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(
		_pivot_equipo,
		"position",
		origen + direccion * 2.0 + perpendicular * 5.0,
		duracion * 0.38
	)
	_tween.parallel().tween_property(
		_pivot_equipo,
		"modulate:a",
		0.0,
		duracion * 0.38
	)
	_tween.tween_callback(_limpiar)


func _limpiar() -> void:
	if is_instance_valid(_pivot_equipo):
		_pivot_equipo.queue_free()
	_pivot_equipo = null
	_sprite_equipo = null
	_tween = null


static func _normalizar(valor: String) -> String:
	return valor.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("_", " ").strip_edges()
