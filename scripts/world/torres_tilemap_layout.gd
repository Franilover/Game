extends RefCounted
## Distribución compartida del terreno de Torres.
## Se utiliza tanto al regenerar las capas en ejecución como desde el editor.

const TILE_SIZE := 32
const ORIGIN := Vector2(-1440.0, -896.0)
const COLUMNS := 90
const ROWS := 56
const ZONES := [0, 1, 8]
const BASE_ATLAS_TILE := Vector2i(2, 1)


static func zone_for_point(point: Vector2, cell: Vector2i) -> int:
	if _is_road(point):
		return 1
	if _is_forest_border(point, cell):
		return 8
	return 0


static func _is_road(point: Vector2) -> bool:
	if _near_segment(point, Vector2(-1440.0, 0.0), Vector2(1440.0, 0.0), 46.0):
		return true
	if _near_segment(point, Vector2(0.0, -896.0), Vector2(0.0, 896.0), 46.0):
		return true

	if absf(point.x) <= 350.0 and absf(point.y) <= 245.0:
		return true
	if absf(point.x) <= 390.0 and absf(point.y) <= 190.0:
		return true

	if _near_segment(point, Vector2(-1024.0, -760.0), Vector2(-1024.0, 760.0), 27.0):
		return true
	if _near_segment(point, Vector2(1024.0, -760.0), Vector2(1024.0, 760.0), 27.0):
		return true
	if _near_segment(point, Vector2(-1280.0, -480.0), Vector2(-760.0, -480.0), 25.0):
		return true
	if _near_segment(point, Vector2(760.0, -480.0), Vector2(1280.0, -480.0), 25.0):
		return true
	if _near_segment(point, Vector2(-1280.0, 190.0), Vector2(-760.0, 190.0), 25.0):
		return true
	if _near_segment(point, Vector2(760.0, 190.0), Vector2(1280.0, 190.0), 25.0):
		return true

	if _near_segment(point, Vector2(-330.0, -10.0), Vector2(-650.0, 70.0), 29.0):
		return true
	if _near_segment(point, Vector2(-650.0, 70.0), Vector2(-700.0, -420.0), 25.0):
		return true
	if _near_segment(point, Vector2(330.0, -10.0), Vector2(650.0, 65.0), 29.0):
		return true
	if _near_segment(point, Vector2(650.0, 65.0), Vector2(790.0, -420.0), 25.0):
		return true
	if _near_segment(point, Vector2(-900.0, 520.0), Vector2(900.0, 520.0), 27.0):
		return true
	if _near_segment(point, Vector2(-700.0, 190.0), Vector2(-700.0, 520.0), 25.0):
		return true
	if _near_segment(point, Vector2(650.0, 190.0), Vector2(650.0, 520.0), 25.0):
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
