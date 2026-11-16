extends RefCounted
## Distribución urbana compartida de Torres.
## Plaza central, manzanas residenciales compactas y servicios próximos al núcleo.

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

	# Calles longitudinales que conectan el centro con los dos barrios.
	for x_calle: float in [-600.0, 600.0]:
		if _near_segment(point, Vector2(x_calle, -560.0), Vector2(x_calle, 520.0), 30.0):
			return true

	# Calles cortas entre las filas de viviendas; forman manzanas reconocibles.
	for y_calle: float in [-475.0, -225.0, 25.0, 275.0]:
		if _near_segment(point, Vector2(-1100.0, y_calle), Vector2(-650.0, y_calle), 25.0):
			return true
		if _near_segment(point, Vector2(650.0, y_calle), Vector2(1100.0, y_calle), 25.0):
			return true

	# Accesos de los edificios públicos y talleres alrededor de la plaza.
	if _near_segment(point, Vector2(-500.0, 0.0), Vector2(-500.0, 242.0), 27.0):
		return true
	if _near_segment(point, Vector2(500.0, 0.0), Vector2(500.0, 246.0), 27.0):
		return true
	if _near_segment(point, Vector2(-520.0, -250.0), Vector2(-520.0, -365.0), 27.0):
		return true
	if _near_segment(point, Vector2(520.0, -250.0), Vector2(520.0, -362.0), 27.0):
		return true
	if _near_segment(point, Vector2(-420.0, 250.0), Vector2(-420.0, 494.0), 27.0):
		return true
	if _near_segment(point, Vector2(-160.0, 250.0), Vector2(-160.0, 494.0), 27.0):
		return true

	# El granero, el molino y los corrales quedan en el borde productivo.
	if _near_segment(point, Vector2(-760.0, 450.0), Vector2(-760.0, 667.0), 25.0):
		return true
	if _near_segment(point, Vector2(-500.0, 450.0), Vector2(-500.0, 664.0), 25.0):
		return true
	if _near_segment(point, Vector2(650.0, 450.0), Vector2(650.0, 716.0), 25.0):
		return true
	if _near_segment(point, Vector2(650.0, 716.0), Vector2(950.0, 898.0), 25.0):
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
