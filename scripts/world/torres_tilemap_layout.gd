extends RefCounted
## Distribución urbana compartida de Torres.
## 104 x 68 celdas de 32 px, con plaza central, barrios laterales y zona agrícola.

const TILE_SIZE := 32
const ORIGIN := Vector2(-1664.0, -1088.0)
const COLUMNS := 104
const ROWS := 68
const ZONES := [0, 1, 8]
const BASE_ATLAS_TILE := Vector2i(2, 1)


static func zone_for_point(point: Vector2, cell: Vector2i) -> int:
	if _is_forest_border(point, cell):
		return 8
	if _is_road(point):
		return 1
	return 0


static func _is_road(point: Vector2) -> bool:
	# Ejes principales y plaza pública.
	if _near_segment(point, Vector2(-1664.0, 0.0), Vector2(1664.0, 0.0), 48.0):
		return true
	if _near_segment(point, Vector2(0.0, -1088.0), Vector2(0.0, 1088.0), 48.0):
		return true
	if absf(point.x) <= 370.0 and absf(point.y) <= 270.0:
		return true

	# Calles de acceso a los barrios residenciales occidental y oriental.
	for x_calle: float in [-1024.0, 1024.0]:
		if _near_segment(point, Vector2(x_calle, -1000.0), Vector2(x_calle, 1020.0), 30.0):
			return true

	# Las calles transversales siguen las manzanas, no una cuadrícula uniforme.
	for y_calle: float in [-700.0, -300.0, -180.0, 150.0, 430.0, 720.0, 850.0, 980.0]:
		if _near_segment(point, Vector2(-1600.0, y_calle), Vector2(-960.0, y_calle), 25.0):
			return true
		if _near_segment(point, Vector2(960.0, y_calle), Vector2(1600.0, y_calle), 25.0):
			return true

	# Conexiones de los edificios públicos, comerciales y productivos.
	if _near_segment(point, Vector2(-420.0, 0.0), Vector2(-650.0, 180.0), 30.0):
		return true
	if _near_segment(point, Vector2(-650.0, 180.0), Vector2(-650.0, 520.0), 27.0):
		return true
	if _near_segment(point, Vector2(420.0, 0.0), Vector2(650.0, 180.0), 30.0):
		return true
	if _near_segment(point, Vector2(650.0, 180.0), Vector2(650.0, 650.0), 27.0):
		return true
	if _near_segment(point, Vector2(-1024.0, -600.0), Vector2(-850.0, -600.0), 26.0):
		return true
	if _near_segment(point, Vector2(850.0, -600.0), Vector2(1024.0, -600.0), 26.0):
		return true
	if _near_segment(point, Vector2(-1024.0, 520.0), Vector2(-900.0, 520.0), 25.0):
		return true
	if _near_segment(point, Vector2(-900.0, 520.0), Vector2(-650.0, 520.0), 25.0):
		return true
	if _near_segment(point, Vector2(650.0, 430.0), Vector2(1024.0, 430.0), 25.0):
		return true
	if _near_segment(point, Vector2(650.0, 650.0), Vector2(1024.0, 720.0), 25.0):
		return true
	if _near_segment(point, Vector2(1024.0, 980.0), Vector2(900.0, 980.0), 25.0):
		return true
	return false


static func _is_forest_border(_point: Vector2, cell: Vector2i) -> bool:
	if cell.y <= 1 or cell.y >= ROWS - 2:
		return true
	if cell.x <= 1 and absf(_point.y) > 112.0:
		return true
	if cell.x >= COLUMNS - 2 and absf(_point.y) > 144.0:
		return true
	return false


static func _near_segment(point: Vector2, start: Vector2, finish: Vector2, width: float) -> bool:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start) <= width
	var weight := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * weight) <= width
