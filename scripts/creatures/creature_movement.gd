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

# Seguro local contra bloqueos: registra el progreso y alterna el rodeo cuando
# otro habitante, una esquina o una entrada impiden avanzar.
var _ultima_posicion_seguro: Vector2 = Vector2.ZERO
var _seguro_inicializado: bool = false
var _direccion_base_atasco: Vector2 = Vector2.ZERO
var _tiempo_sin_progreso: float = 0.0
var _lado_desvio: float = 1.0
var _tiempo_cambio_lado: float = 0.0

var _rng := RandomNumberGenerator.new()

const DISTANCIA_SEPARACION_NPC := 34.0
const DISTANCIA_CEDER_PASO_NPC := 27.0
const UMBRAL_PROGRESO_NPC := 0.45
const TIEMPO_REACCION_ATASCO_NPC := 0.8
const INTERVALO_CAMBIO_LADO_NPC := 0.75


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
	_ultima_posicion_seguro = nueva_criatura.global_position if is_instance_valid(nueva_criatura) else Vector2.ZERO
	_seguro_inicializado = is_instance_valid(nueva_criatura)
	_direccion_base_atasco = Vector2.ZERO
	_tiempo_sin_progreso = 0.0
	_lado_desvio = -1.0 if posmod(semilla, 2) == 0 else 1.0
	_tiempo_cambio_lado = 0.0


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
		_procesar_ruta_rutina(delta)
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

	if direccion_actual.length_squared() > 0.001:
		direccion_actual = _direccion_evitar_superposicion_npcs(direccion_actual)
		direccion_actual = _aplicar_seguro_atasco_npc(direccion_actual, delta)
	else:
		_reiniciar_seguro_atasco()
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


func _procesar_ruta_rutina(delta: float) -> void:
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
	direccion = _direccion_evitar_superposicion_npcs(direccion)
	direccion = _aplicar_seguro_atasco_npc(direccion, delta)
	creature.velocity = direccion * move_speed
	creature.move_and_slide()


## Evita que dos habitantes sigan exactamente el mismo punto o se atraviesen.
## Si alguien está delante, el NPC cede lateralmente en vez de empujarlo.
## Sólo afecta a NPC de Torres; criaturas y jugadores conservan su movimiento.
func _direccion_evitar_superposicion_npcs(direccion: Vector2) -> Vector2:
	if (
		direccion.length_squared() <= 0.001
		or not creature is Creature
		or not (creature as Creature).is_in_group("torres_game_npc")
	):
		return direccion

	var npc_actual := creature as Creature
	var desvio_lateral := Vector2.ZERO
	var repulsion := Vector2.ZERO
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if (
			not nodo is Creature
			or nodo == npc_actual
			or not is_instance_valid(nodo)
			or nodo.is_queued_for_deletion()
		):
			continue
		var otro := nodo as Creature
		if not otro.is_alive or otro.get_parent() != npc_actual.get_parent():
			continue

		var diferencia := npc_actual.global_position - otro.global_position
		var distancia := diferencia.length()
		if distancia >= DISTANCIA_SEPARACION_NPC:
			continue

		var alejamiento := Vector2.RIGHT
		if distancia > 0.01:
			alejamiento = diferencia / distancia
		else:
			# Posiciones idénticas: cada NPC obtiene un lado estable y opuesto.
			alejamiento = Vector2.RIGHT if npc_actual.get_instance_id() < otro.get_instance_id() else Vector2.LEFT

		var hacia_otro := -alejamiento
		var peso := clampf((DISTANCIA_SEPARACION_NPC - distancia) / DISTANCIA_SEPARACION_NPC, 0.0, 1.0)
		repulsion += alejamiento * peso

		# Un NPC quieto o que viene de frente no debe convertirse en una pared.
		# Se cede por un costado, con lados opuestos según el ID para evitar
		# que ambos intenten rodearse por el mismo sitio.
		var esta_delante := direccion.normalized().dot(hacia_otro) > 0.25
		if esta_delante and distancia < DISTANCIA_CEDER_PASO_NPC:
			var prioridad_lateral := -1.0 if npc_actual.get_instance_id() < otro.get_instance_id() else 1.0
			var lado := direccion.normalized().orthogonal() * prioridad_lateral
			var intensidad := clampf((DISTANCIA_CEDER_PASO_NPC - distancia) / 12.0, 0.0, 1.0)
			desvio_lateral += lado * intensidad

	if desvio_lateral.length_squared() > 0.001:
		var lateral := desvio_lateral.normalized()
		var cercania := clampf(desvio_lateral.length(), 0.0, 1.0)
		return (direccion.normalized() * (1.0 - cercania) + lateral * cercania).normalized()

	if repulsion.length_squared() <= 0.001:
		return direccion
	return (direccion + repulsion.normalized() * 1.2).normalized()


## Si el cuerpo deja de avanzar, alterna el rodeo sin cancelar su destino.
## Esto evita que una colisión temporal o un NPC parado en una entrada
## deje la rutina bloqueada para siempre.
func _aplicar_seguro_atasco_npc(direccion: Vector2, delta: float) -> Vector2:
	if (
		direccion.length_squared() <= 0.001
		or not creature is Creature
		or not (creature as Creature).is_in_group("torres_game_npc")
	):
		_reiniciar_seguro_atasco()
		return direccion

	var posicion_actual := creature.global_position
	if not _seguro_inicializado:
		_ultima_posicion_seguro = posicion_actual
		_seguro_inicializado = true
		return direccion

	var avance := posicion_actual.distance_to(_ultima_posicion_seguro)
	_ultima_posicion_seguro = posicion_actual
	if avance >= UMBRAL_PROGRESO_NPC:
		_tiempo_sin_progreso = 0.0
		_tiempo_cambio_lado = 0.0
		_direccion_base_atasco = Vector2.ZERO
		return direccion

	_tiempo_sin_progreso += maxf(delta, 0.0)
	if _tiempo_sin_progreso < TIEMPO_REACCION_ATASCO_NPC:
		_direccion_base_atasco = direccion.normalized()
		return direccion
	if _direccion_base_atasco.length_squared() <= 0.001:
		_direccion_base_atasco = direccion.normalized()

	_tiempo_cambio_lado += maxf(delta, 0.0)
	if _tiempo_cambio_lado >= INTERVALO_CAMBIO_LADO_NPC:
		_lado_desvio *= -1.0
		_tiempo_cambio_lado = 0.0

	var lateral := _direccion_base_atasco.orthogonal() * _lado_desvio
	return (lateral * 0.92 + _direccion_base_atasco * 0.08).normalized()


func _reiniciar_seguro_atasco() -> void:
	_tiempo_sin_progreso = 0.0
	_tiempo_cambio_lado = 0.0
	_direccion_base_atasco = Vector2.ZERO
	if creature != null and is_instance_valid(creature):
		_ultima_posicion_seguro = creature.global_position
		_seguro_inicializado = true

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
