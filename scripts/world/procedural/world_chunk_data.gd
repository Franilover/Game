extends RefCounted
class_name WorldChunkData

## Datos puros de un chunk. No contiene nodos, TileMap ni recursos visuales.

var chunk_coord: Vector2i
var origin_tile: Vector2i
var width: int
var height: int
var algorithm_version: int
var elevation: PackedFloat32Array = PackedFloat32Array()
var humidity: PackedFloat32Array = PackedFloat32Array()
var temperature: PackedFloat32Array = PackedFloat32Array()

func _init(
	p_chunk_coord: Vector2i = Vector2i.ZERO,
	p_origin_tile: Vector2i = Vector2i.ZERO,
	p_width: int = 0,
	p_height: int = 0,
	p_algorithm_version: int = 1
) -> void:
	chunk_coord = p_chunk_coord
	origin_tile = p_origin_tile
	width = p_width
	height = p_height
	algorithm_version = p_algorithm_version
	var cell_count := maxi(0, width) * maxi(0, height)
	elevation.resize(cell_count)
	humidity.resize(cell_count)
	temperature.resize(cell_count)

func is_valid() -> bool:
	var expected := width * height
	return width > 0 and height > 0 and elevation.size() == expected and humidity.size() == expected and temperature.size() == expected

func index_at(local_x: int, local_y: int) -> int:
	if local_x < 0 or local_y < 0 or local_x >= width or local_y >= height:
		return -1
	return local_y * width + local_x

func get_elevation(local_x: int, local_y: int) -> float:
	var index := index_at(local_x, local_y)
	return elevation[index] if index >= 0 else 0.0

func get_humidity(local_x: int, local_y: int) -> float:
	var index := index_at(local_x, local_y)
	return humidity[index] if index >= 0 else 0.0

func get_temperature(local_x: int, local_y: int) -> float:
	var index := index_at(local_x, local_y)
	return temperature[index] if index >= 0 else 0.0
