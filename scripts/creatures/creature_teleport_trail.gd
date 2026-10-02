extends Line2D
class_name CreatureTeleportTrail


var objetivo: Node2D = null
var duracion: float = 0.7
var max_puntos: int = 18
var _tiempo: float = 0.0
var _muestreo: float = 0.0


func configurar(
	nuevo_objetivo: Node2D,
	origen: Vector2,
	destino: Vector2,
	nueva_duracion: float,
	nuevos_puntos: int
) -> void:
	objetivo = nuevo_objetivo
	duracion = maxf(nueva_duracion, 0.1)
	max_puntos = maxi(nuevos_puntos, 4)
	_tiempo = duracion
	_muestreo = 0.0

	width = 3.0
	default_color = Color(0.80, 0.90, 1.0, 0.78)
	z_index = 90

	clear_points()
	add_point(origen)
	add_point(destino)

	if objetivo != null and is_instance_valid(objetivo):
		seguir_objetivo()


func _process(delta: float) -> void:
	_tiempo -= delta
	_muestreo -= delta

	if objetivo == null or not is_instance_valid(objetivo):
		_desvanecer_y_liberar()
		return

	if _muestreo <= 0.0:
		_muestreo = 0.035
		seguir_objetivo()

	if _tiempo <= 0.0:
		_desvanecer_y_liberar()


func seguir_objetivo() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return

	var posicion := objetivo.global_position

	if get_point_count() == 0:
		add_point(posicion)
		return

	var ultimo := get_point_position(
		get_point_count() - 1
	)

	if ultimo.distance_to(posicion) <= 1.5:
		return

	add_point(posicion)

	while get_point_count() > max_puntos:
		remove_point(0)


func _desvanecer_y_liberar() -> void:
	set_process(false)

	var tween := create_tween()

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.16
	)

	tween.tween_callback(queue_free)
