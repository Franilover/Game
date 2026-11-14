extends Node
class_name CreatureMovement

var creature: CharacterBody2D = null

var move_speed: float = 20.0
var min_move_time: float = 1.0
var max_move_time: float = 3.0

var limites_chunk: Rect2 = Rect2()

var _move_direction: Vector2 = Vector2.ZERO
var _move_timer: float = 0.0

var _usar_direccion_externa: bool = false
var _direccion_externa: Vector2 = Vector2.ZERO
var _control_rutina: bool = false
var _pausado_temporalmente: bool = false
var _ruta_rutina: PackedVector2Array = PackedVector2Array()
var _indice_ruta_rutina: int = 0
var _rutina_completada: bool = false

var _rng := RandomNumberGenerator.new()


func configurar(
	nueva_criatura: CharacterBody2D,
	nueva_velocidad: float,
	nuevo_min_move_time: float,
	nuevo_max_move_time: float,
	semilla: int
) -> void:
	creature = nueva_criatura

	move_speed = maxf(nueva_velocidad, 0.0)
	min_move_time = maxf(nuevo_min_move_time, 0.0)
	max_move_time = maxf(nuevo_max_move_time, min_move_time)

	_rng.seed = semilla

	_move_timer = 0.0
	_move_direction = Vector2.ZERO
	_control_rutina = false
	_pausado_temporalmente = false
	_ruta_rutina.clear()
	_indice_ruta_rutina = 0
	_rutina_completada = false


func configurar_chunk(nuevos_limites: Rect2) -> void:
	limites_chunk = nuevos_limites


func procesar(delta: float) -> void:
	if creature == null:
		return

	if not is_instance_valid(creature):
		return

	# Una conversación pausa el desplazamiento sin borrar la ruta ni cambiar
	# el modo de control que tenía el NPC antes de hablar.
	if _pausado_temporalmente:
		creature.velocity = Vector2.ZERO
		return

	# Las rutinas de NPC usan rutas calculadas sobre la geometría estática.
	# Este control tiene prioridad sobre la movilidad autónoma de criaturas.
	if _control_rutina:
		_procesar_ruta_rutina()
		return

	# Supabase es la fuente canónica: una criatura configurada como inmóvil
	# no puede desplazarse por la patrulla autónoma ni por órdenes de la IA.
	# Se comprueban ambas formas de expresar la restricción para tolerar
	# snapshots antiguos que solo contengan una de las claves.
	if creature is Creature:
		var configuracion: Dictionary = (creature as Creature).obtener_config_ia()
		var movimiento_variant: Variant = configuracion.get("movimiento", {})
		var movimiento: Dictionary = movimiento_variant if movimiento_variant is Dictionary else {}
		var tipo_movimiento := str(movimiento.get("tipo", "")).strip_edges().to_lower()
		var desplazamiento_propio: Variant = movimiento.get("desplazamiento_propio", true)
		var movimiento_permitido: Variant = configuracion.get("movimiento_permitido", true)
		if tipo_movimiento == "inmovil" or desplazamiento_propio == false or movimiento_permitido == false:
			detener()
			_move_timer = maxf(_move_timer, 0.1)
			return

	_move_timer -= delta

	if not _usar_direccion_externa and _move_timer <= 0.0:
		_elegir_movimiento()

	var direccion_objetivo: Vector2 = (
		_direccion_externa
		if _usar_direccion_externa
		else _move_direction
	)

	# El movimiento autónomo no cambia de dirección bruscamente cada vez
	# que termina un ciclo de pensamiento. Se aproxima gradualmente al
	# rumbo elegido para que la criatura se desplace de forma orgánica.
	var direccion_actual := Vector2.ZERO
	if move_speed > 0.0:
		direccion_actual = creature.velocity / move_speed

	if direccion_objetivo.length_squared() <= 0.001:
		direccion_actual = direccion_actual.move_toward(
			Vector2.ZERO,
			maxf(delta * 3.5, 0.0)
		)
	else:
		direccion_actual = direccion_actual.move_toward(
			direccion_objetivo,
			maxf(delta * 2.8, 0.0)
		)

	creature.velocity = direccion_actual * move_speed
	creature.move_and_slide()

	_mantener_en_chunk()


func pausar_temporalmente() -> void:
	_pausado_temporalmente = true
	if creature != null and is_instance_valid(creature):
		creature.velocity = Vector2.ZERO


func reanudar_temporalmente() -> void:
	_pausado_temporalmente = false


func rutina_terminada() -> bool:
	return _control_rutina and _rutina_completada


func rutina_en_ejecucion() -> bool:
	return _control_rutina and not _rutina_completada and _indice_ruta_rutina < _ruta_rutina.size()


func establecer_ruta(ruta: PackedVector2Array) -> void:
	_control_rutina = true
	_ruta_rutina = ruta
	_indice_ruta_rutina = 0
	_rutina_completada = false
	if creature == null or not is_instance_valid(creature):
		return

	# Una orden de rutina debe reactivar el cuerpo que ejecuta
	# Creature._physics_process(); desactivar sólo el nodo hijo de movimiento
	# no basta si el NPC fue pausado por otro sistema.
	creature.set_process(true)
	creature.set_physics_process(true)
	while _indice_ruta_rutina < _ruta_rutina.size() and creature.global_position.distance_to(_ruta_rutina[_indice_ruta_rutina]) <= 7.0:
		_indice_ruta_rutina += 1
	if _indice_ruta_rutina >= _ruta_rutina.size():
		_rutina_completada = true
		creature.velocity = Vector2.ZERO


func detener_por_rutina() -> void:
	_control_rutina = true
	_ruta_rutina.clear()
	_indice_ruta_rutina = 0
	_rutina_completada = false
	_move_direction = Vector2.ZERO
	_direccion_externa = Vector2.ZERO
	if creature != null and is_instance_valid(creature):
		creature.velocity = Vector2.ZERO


func _procesar_ruta_rutina() -> void:
	if creature == null or not is_instance_valid(creature):
		return
	if _indice_ruta_rutina >= _ruta_rutina.size() or move_speed <= 0.0:
		_rutina_completada = _indice_ruta_rutina >= _ruta_rutina.size()
		creature.velocity = Vector2.ZERO
		return

	var destino := _ruta_rutina[_indice_ruta_rutina]
	if creature.global_position.distance_to(destino) <= 7.0:
		_indice_ruta_rutina += 1
		if _indice_ruta_rutina >= _ruta_rutina.size():
			_rutina_completada = true
			creature.velocity = Vector2.ZERO
			return
		destino = _ruta_rutina[_indice_ruta_rutina]

	var direccion := creature.global_position.direction_to(destino)
	creature.velocity = direccion * move_speed
	creature.move_and_slide()


func establecer_direccion(direccion: Vector2) -> void:
	if direccion.length_squared() <= 0.001:
		_direccion_externa = Vector2.ZERO
		return

	_direccion_externa = direccion.normalized()


func tomar_control() -> void:
	_usar_direccion_externa = true


func liberar_control() -> void:
	_usar_direccion_externa = false
	_direccion_externa = Vector2.ZERO


func detener() -> void:
	_control_rutina = false
	_ruta_rutina.clear()
	_indice_ruta_rutina = 0
	_rutina_completada = false
	_move_direction = Vector2.ZERO
	_direccion_externa = Vector2.ZERO

	if creature != null and is_instance_valid(creature):
		creature.velocity = Vector2.ZERO


func _elegir_movimiento() -> void:
	_move_timer = _rng.randf_range(
		min_move_time,
		max_move_time
	)

	if _rng.randf() < 0.30:
		_move_direction = Vector2.ZERO
		return

	var direccion := Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	)

	if direccion.length_squared() <= 0.001:
		_move_direction = Vector2.ZERO
		return

	_move_direction = direccion.normalized()


func _mantener_en_chunk() -> void:
	if creature == null:
		return

	if limites_chunk.size.is_zero_approx():
		return

	var limites: Rect2 = limites_chunk.grow(-10.0)

	if limites.has_point(creature.global_position):
		return

	var centro: Vector2 = limites.get_center()

	var direccion: Vector2 = (
		creature.global_position.direction_to(centro)
	)

	if direccion.length_squared() <= 0.001:
		detener()
		return

	_move_direction = direccion
	_move_timer = 1.0
