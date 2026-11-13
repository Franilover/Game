extends Node2D
class_name HogarZone
## Parcela privada asociada al guardado local activo.
## El terreno se dibuja en coordenadas de mundo; los datos editables se serializan
## en GameState.world_state.flags mediante ZoneManager.

const ANCHO := 2400.0
const ALTO := 1600.0
const TAMANO_CUADRICULA := 32.0
const COLOR_HIERBA := Color(0.34, 0.48, 0.27, 1.0)
const COLOR_HIERBA_CLARA := Color(0.39, 0.53, 0.30, 1.0)
const COLOR_CAMINO := Color(0.55, 0.43, 0.29, 1.0)
const COLOR_TIERRA := Color(0.39, 0.29, 0.20, 1.0)
const COLOR_BORDE := Color(0.20, 0.29, 0.18, 1.0)

var _decoraciones: Array[Dictionary] = []
var _version_estado := 1


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var parcela := Rect2(-ANCHO * 0.5, -ALTO * 0.5, ANCHO, ALTO)
	draw_rect(parcela, COLOR_HIERBA)
	# Variación discreta para que el terreno no sea una superficie plana.
	for y in range(-24, 25):
		for x in range(-36, 37):
			if posmod(x * 17 + y * 31, 7) == 0:
				var punto := Vector2(x * TAMANO_CUADRICULA, y * TAMANO_CUADRICULA)
				draw_rect(Rect2(punto, Vector2(4, 4)), COLOR_HIERBA_CLARA)
	# Camino de entrada hacia la casa.
	draw_rect(Rect2(-48, 80, 96, 560), COLOR_CAMINO)
	draw_rect(Rect2(-48, 80, 96, 560), COLOR_BORDE, false, 4.0)
	# Parcela de cultivo inicial, lista para ampliar con el sistema de cultivo.
	draw_rect(Rect2(240, 160, 384, 256), COLOR_TIERRA)
	for x in range(252, 624, 32):
		draw_line(Vector2(x, 176), Vector2(x, 400), Color(0.48, 0.36, 0.24, 1.0), 2.0)
	# Límite visual de la propiedad.
	draw_rect(parcela, COLOR_BORDE, false, 12.0)
	# Decoraciones guardadas: cada entrada contiene tipo, x, y y giro.
	for decoracion in _decoraciones:
		var posicion := Vector2(float(decoracion.get("x", 0.0)), float(decoracion.get("y", 0.0)))
		var tamano := Vector2(24.0, 24.0)
		var color := Color(0.58, 0.43, 0.25, 1.0)
		draw_set_transform(posicion, float(decoracion.get("giro", 0.0)), Vector2.ONE)
		draw_rect(Rect2(-tamano * 0.5, tamano), color)
		draw_set_transform(Vector2.ZERO)


func obtener_estado_guardado() -> Dictionary:
	return {
		"version": _version_estado,
		"decoraciones": _decoraciones.duplicate(true)
	}


func cargar_estado_guardado(estado: Dictionary) -> void:
	_version_estado = maxi(1, int(estado.get("version", 1)))
	var datos: Variant = estado.get("decoraciones", [])
	_decoraciones.clear()
	if datos is Array:
		for entrada in datos:
			if not entrada is Dictionary:
				continue
			var item := (entrada as Dictionary).duplicate(true)
			_decoraciones.append({
					"tipo": str(item.get("tipo", "decoracion")),
					"x": clampf(float(item.get("x", 0.0)), -ANCHO * 0.5, ANCHO * 0.5),
					"y": clampf(float(item.get("y", 0.0)), -ALTO * 0.5, ALTO * 0.5),
					"giro": float(item.get("giro", 0.0))
				})
	queue_redraw()


func establecer_decoraciones(decoraciones: Array) -> void:
	cargar_estado_guardado({"version": _version_estado, "decoraciones": decoraciones})


func agregar_decoracion(tipo: String, posicion: Vector2, giro: float = 0.0) -> bool:
	if tipo.strip_edges().is_empty() or not obtener_limites().has_point(posicion):
		return false
	_decoraciones.append({
		"tipo": tipo.strip_edges(),
		"x": posicion.x,
		"y": posicion.y,
		"giro": giro
	})
	queue_redraw()
	return true


func mover_decoracion(indice: int, posicion: Vector2) -> bool:
	if indice < 0 or indice >= _decoraciones.size() or not obtener_limites().has_point(posicion):
		return false
	_decoraciones[indice]["x"] = posicion.x
	_decoraciones[indice]["y"] = posicion.y
	queue_redraw()
	return true


func quitar_decoracion(indice: int) -> bool:
	if indice < 0 or indice >= _decoraciones.size():
		return false
	_decoraciones.remove_at(indice)
	queue_redraw()
	return true


func obtener_decoraciones() -> Array[Dictionary]:
	return _decoraciones.duplicate(true)


func obtener_limites() -> Rect2:
	return Rect2(-ANCHO * 0.5, -ALTO * 0.5, ANCHO, ALTO)
