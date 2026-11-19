extends Node2D
## Acabados provisionales de interiores construidos con los PNG existentes.
## No dibuja píxeles: repite las texturas 16x16 mediante Sprite2D.

const WALL_HEIGHT := 48.0
const WALL_DEPTH := 48.0
const DOOR_LEFT := -14.0
const DOOR_RIGHT := 132.0
const TILE_ROOT := "res://assets/tilesets/"

const FLOOR_TEXTURES := {
	"wood": "Suelo Madera Oscuro.png",
	"stone": "Suelo Piedra.png",
	"tile": "Suelo Baldosas.png",
	"earth": "Suelo.png",
	"garden": "Suelo.png"
}
const WALL_TEXTURES := {
	"wood": "Muro Madera Oscuro.png",
	"stone": "Muro Piedra.png",
	"tile": "Muro Baldosas.png",
	"earth": "Muro Madera Oscuro.png",
	"garden": "Muro Madera Oscuro.png"
}

var _room_size := Vector2(512.0, 320.0)


func configurar(tipo: String, dimensiones: Vector2, _entrada_id: String = "") -> void:
	_room_size = Vector2(maxf(16.0, dimensiones.x), maxf(16.0, dimensiones.y))
	var perfil := _obtener_perfil(tipo)
	_construir_suelo(str(perfil["floor"]))
	_construir_paredes(str(perfil["wall"]))


func _obtener_perfil(tipo: String) -> Dictionary:
	match tipo:
		"castillo", "archivo", "consejo", "cuartel", "forja", "registro":
			return {"floor": "stone", "wall": "stone"}
		"biblioteca", "clinica", "comercio", "herbolario":
			return {"floor": "tile", "wall": "tile"}
		"taberna", "posada", "panaderia", "escuela", "taller", "carpinteria", "molino", "vivero":
			return {"floor": "wood", "wall": "wood"}
		"granero", "corrales":
			return {"floor": "earth", "wall": "wood"}
		_:
			return {"floor": "wood", "wall": "wood"}


func _construir_suelo(material: String) -> void:
	var textura := _cargar_textura(FLOOR_TEXTURES.get(material, "Suelo.png"))
	if textura == null:
		push_error("BuildingInteriorStyle: no se encontró la textura de suelo: " + material)
		return
	_agregar_textura_repetida(
		"Suelo",
		textura,
		Vector2.ZERO,
		_room_size,
		-12
	)


func _construir_paredes(material: String) -> void:
	var textura := _cargar_textura(WALL_TEXTURES.get(material, "Muro Madera Oscuro.png"))
	if textura == null:
		push_error("BuildingInteriorStyle: no se encontró la textura de muro: " + material)
		return

	var mitad := _room_size / 2.0
	var lateral := WALL_DEPTH
	var frente_y := mitad.y - WALL_HEIGHT
	var ancho_izq := maxf(0.0, DOOR_LEFT + mitad.x)
	var ancho_der := maxf(0.0, mitad.x - DOOR_RIGHT)

	# Fondo y laterales: módulos repetidos con cara visible de 48 px.
	_agregar_textura_repetida(
		"MuroFondo", textura,
		Vector2(0.0, -mitad.y + WALL_HEIGHT / 2.0),
		Vector2(_room_size.x, WALL_HEIGHT), -10
	)
	_agregar_textura_repetida(
		"MuroIzquierdo", textura,
		Vector2(-mitad.x + lateral / 2.0, 0.0),
		Vector2(lateral, _room_size.y), -10
	)
	_agregar_textura_repetida(
		"MuroDerecho", textura,
		Vector2(mitad.x - lateral / 2.0, 0.0),
		Vector2(lateral, _room_size.y), -10
	)

	# Frente dividido para conservar libre la abertura de entrada existente.
	if ancho_izq > 0.0:
		_agregar_textura_repetida(
			"MuroFrontalIzquierdo", textura,
			Vector2(-mitad.x + ancho_izq / 2.0, frente_y + WALL_HEIGHT / 2.0),
			Vector2(ancho_izq, WALL_HEIGHT), -9
		)
	if ancho_der > 0.0:
		_agregar_textura_repetida(
			"MuroFrontalDerecho", textura,
			Vector2(DOOR_RIGHT + ancho_der / 2.0, frente_y + WALL_HEIGHT / 2.0),
			Vector2(ancho_der, WALL_HEIGHT), -9
		)


func _agregar_textura_repetida(
	nombre: String,
	textura: Texture2D,
	posicion: Vector2,
	dimensiones: Vector2,
	orden: int
) -> void:
	var sprite := Sprite2D.new()
	sprite.name = nombre
	sprite.texture = textura
	sprite.centered = true
	sprite.position = posicion
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, dimensiones)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = orden
	add_child(sprite)


func _cargar_textura(nombre: String) -> Texture2D:
	var ruta := TILE_ROOT.path_join(nombre)
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as Texture2D
