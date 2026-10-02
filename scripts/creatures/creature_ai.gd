extends Node
class_name CreatureAI


enum Estado {
	EXPLORAR,
	PERSIGUIENDO,
	LANZANDO,
	ENFRIAMIENTO,
	HUYENDO,
	ATACANDO_CUERPO
}


@export_category("Percepción")
@export var distancia_deteccion: float = 150.0
@export var distancia_contacto: float = 12.0


@export_category("Flaxis")
@export var velocidad_persecucion: float = 50.0
@export var velocidad_lanzamiento: float = 220.0
@export var duracion_lanzamiento: float = 0.70
@export var dano_mordida: int = 8

# Tiempo que espera después de acertar.
@export var enfriamiento_ataque: float = 1.50

# Tiempo que espera después de fallar.
@export var enfriamiento_fallido: float = 1.20


@export_category("Zlish (presa)")
@export var zlish_distancia_huida: float = 130.0
@export var zlish_velocidad_huida: float = 65.0
@export var zlish_distancia_segura: float = 220.0


@export_category("Lignianos")
@export var ligniano_velocidad_carga: float = 45.0
@export var ligniano_dano_contacto: int = 6
@export var ligniano_duracion_slow: float = 2.0
@export var ligniano_enfriamiento: float = 2.0


var criatura: Creature = null
var objetivo: Node2D = null

# Posición capturada cuando comienza el salto.
var _objetivo_lanzamiento: Vector2 = Vector2.ZERO

var _estado: Estado = Estado.EXPLORAR

var _tiempo_lanzamiento: float = 0.0
var _tiempo_enfriamiento: float = 0.0

var _movimiento: CreatureMovement = null
var _velocidad_normal: float = 20.0


func _ready() -> void:
	criatura = get_parent() as Creature

	if criatura == null:
		push_error(
			"CreatureAI: el nodo padre no es una Creature."
		)

		set_physics_process(false)
		return

	_encontrar_movimiento()
	_encontrar_objetivo()


func _physics_process(delta: float) -> void:
	if criatura == null:
		return

	if not is_instance_valid(criatura):
		return

	if not criatura.is_alive:
		return

	_encontrar_objetivo()

	match _obtener_tipo_criatura():
		"flaxis":
			_procesar_flaxis(delta)

		"zlish":
			_procesar_zlish(delta)

		"lignianos":
			_procesar_lignianos(delta)

		_:
			_procesar_criatura_generica(delta)


# ============================================================
# IDENTIDAD
# ============================================================

func _obtener_tipo_criatura() -> String:
	if criatura == null:
		return ""

	return criatura.get_nombre().strip_edges().to_lower()


# ============================================================
# FLAXIS
# ============================================================

func _procesar_flaxis(delta: float) -> void:
	if objetivo == null:
		_estado = Estado.EXPLORAR
		criatura.liberar_control_movimiento()
		return

	if not is_instance_valid(objetivo):
		objetivo = null
		_estado = Estado.EXPLORAR
		criatura.liberar_control_movimiento()
		return

	var distancia: float = (
		criatura.global_position.distance_to(
			objetivo.global_position
		)
	)

	match _estado:

		Estado.EXPLORAR:
			if distancia <= distancia_deteccion:
				_iniciar_lanzamiento()
			else:
				criatura.liberar_control_movimiento()


		Estado.PERSIGUIENDO:
			if distancia <= distancia_deteccion:
				_iniciar_lanzamiento()
			else:
				_estado = Estado.EXPLORAR
				criatura.liberar_control_movimiento()


		Estado.LANZANDO:
			_procesar_lanzamiento(delta)


		Estado.ENFRIAMIENTO:
			_procesar_enfriamiento(delta)


# ============================================================
# LANZAMIENTO
# ============================================================

func _iniciar_lanzamiento() -> void:
	if objetivo == null:
		return

	if not is_instance_valid(objetivo):
		return

	_estado = Estado.LANZANDO

	_tiempo_lanzamiento = (
		duracion_lanzamiento
	)

	# Capturamos la posición del jugador
	# UNA SOLA VEZ al comenzar el salto.
	_objetivo_lanzamiento = (
		objetivo.global_position
	)

	criatura.tomar_control_movimiento()

	var direccion: Vector2 = (
		criatura.global_position.direction_to(
			_objetivo_lanzamiento
		)
	)

	criatura.establecer_direccion_movimiento(
		direccion
	)

	_establecer_velocidad(
		velocidad_lanzamiento
	)

	_animar_salto()

	print(
		criatura.get_nombre(),
		" se lanza hacia la posición ",
		_objetivo_lanzamiento
	)


func _procesar_lanzamiento(
	delta: float
) -> void:
	if not is_instance_valid(criatura):
		return

	_tiempo_lanzamiento -= delta

	# Seguimos apuntando exclusivamente al punto
	# capturado al comenzar el salto.
	var distancia_objetivo: float = (
		criatura.global_position.distance_to(
			_objetivo_lanzamiento
		)
	)

	var direccion: Vector2 = (
		criatura.global_position.direction_to(
			_objetivo_lanzamiento
		)
	)

	if distancia_objetivo > distancia_contacto:
		criatura.establecer_direccion_movimiento(
			direccion
		)
	else:
		_finalizar_lanzamiento()
		return

	if _tiempo_lanzamiento <= 0.0:
		_finalizar_lanzamiento()


func _finalizar_lanzamiento() -> void:
	if _estado != Estado.LANZANDO:
		return

	# Comprobamos dónde está realmente el jugador.
	var jugador_cerca: bool = false

	if objetivo != null:
		if is_instance_valid(objetivo):
			var distancia_jugador: float = (
				criatura.global_position.distance_to(
					objetivo.global_position
				)
			)

			jugador_cerca = (
				distancia_jugador <= distancia_contacto
			)

	if jugador_cerca:
		_morder()
		return

	# Falló el salto.
	criatura.detener_movimiento()

	_establecer_velocidad(
		_velocidad_normal
	)

	_estado = Estado.ENFRIAMIENTO

	_tiempo_enfriamiento = (
		enfriamiento_fallido
	)

	print(
		criatura.get_nombre(),
		" falló el salto y espera ",
		enfriamiento_fallido,
		"s antes de intentarlo otra vez."
	)


func _morder() -> void:
	if objetivo == null:
		_cancelar_lanzamiento()
		return

	if not is_instance_valid(objetivo):
		objetivo = null
		_cancelar_lanzamiento()
		return

	if objetivo.has_method("take_damage"):
		objetivo.take_damage(
			dano_mordida
		)

		print(
			criatura.get_nombre(),
			" mordió a ",
			objetivo.name,
			" por ",
			dano_mordida,
			" de daño."
		)

	criatura.detener_movimiento()

	_establecer_velocidad(
		_velocidad_normal
	)

	_estado = Estado.ENFRIAMIENTO

	_tiempo_enfriamiento = (
		enfriamiento_ataque
	)


func _cancelar_lanzamiento() -> void:
	criatura.detener_movimiento()

	_establecer_velocidad(
		_velocidad_normal
	)

	_estado = Estado.EXPLORAR


# ============================================================
# ENFRIAMIENTO
# ============================================================

func _procesar_enfriamiento(
	delta: float
) -> void:
	# Durante el enfriamiento NO persigue al jugador.
	criatura.detener_movimiento()

	_tiempo_enfriamiento -= delta

	if _tiempo_enfriamiento > 0.0:
		return

	_tiempo_enfriamiento = 0.0

	if objetivo == null:
		_estado = Estado.EXPLORAR
		return

	if not is_instance_valid(objetivo):
		objetivo = null
		_estado = Estado.EXPLORAR
		return

	var distancia: float = (
		criatura.global_position.distance_to(
			objetivo.global_position
		)
	)

	# Solo vuelve a atacar si el jugador sigue cerca.
	if distancia <= distancia_deteccion:
		_iniciar_lanzamiento()
	else:
		_estado = Estado.EXPLORAR


# ============================================================
# ANIMACIÓN DEL SALTO
# ============================================================

func _animar_salto() -> void:
	if criatura == null:
		return

	var escala_original: Vector2 = (
		criatura.scale
	)

	var tween := criatura.create_tween()

	tween.tween_property(
		criatura,
		"scale",
		escala_original * 1.18,
		0.08
	)

	tween.tween_property(
		criatura,
		"scale",
		escala_original * 0.92,
		0.10
	)

	tween.tween_property(
		criatura,
		"scale",
		escala_original,
		0.14
	)


# ============================================================
# ZLISH — huye del jugador
# ============================================================

func _procesar_zlish(delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_estado = Estado.EXPLORAR
		criatura.liberar_control_movimiento()
		return

	var distancia: float = (
		criatura.global_position.distance_to(
			objetivo.global_position
		)
	)

	match _estado:

		Estado.EXPLORAR:
			criatura.liberar_control_movimiento()

			if distancia <= zlish_distancia_huida:
				_iniciar_huida()

		Estado.HUYENDO:
			_procesar_huida(delta)

		_:
			_estado = Estado.EXPLORAR
			criatura.liberar_control_movimiento()


func _iniciar_huida() -> void:
	if objetivo == null:
		return

	_estado = Estado.HUYENDO
	criatura.tomar_control_movimiento()
	_establecer_velocidad(zlish_velocidad_huida)

	var direccion_huida: Vector2 = (
		objetivo.global_position.direction_to(
			criatura.global_position
		)
	)

	criatura.establecer_direccion_movimiento(
		direccion_huida
	)

	print(
		criatura.get_nombre(),
		" huye del jugador."
	)


func _procesar_huida(_delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_estado = Estado.EXPLORAR
		criatura.liberar_control_movimiento()
		return

	var distancia: float = (
		criatura.global_position.distance_to(
			objetivo.global_position
		)
	)

	# Sigue huyendo → actualiza dirección cada frame.
	if distancia <= zlish_distancia_segura:
		var direccion_huida: Vector2 = (
			objetivo.global_position.direction_to(
				criatura.global_position
			)
		)

		criatura.establecer_direccion_movimiento(
			direccion_huida
		)
	else:
		# Ya está suficientemente lejos, vuelve a deambular.
		_estado = Estado.EXPLORAR
		_establecer_velocidad(_velocidad_normal)
		criatura.liberar_control_movimiento()

		print(
			criatura.get_nombre(),
			" está a salvo, vuelve a deambular."
		)


# ============================================================
# LIGNIANOS — ataque cuerpo a cuerpo + slow
# ============================================================

func _procesar_lignianos(delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_estado = Estado.EXPLORAR
		criatura.liberar_control_movimiento()
		return

	var distancia: float = (
		criatura.global_position.distance_to(
			objetivo.global_position
		)
	)

	match _estado:

		Estado.EXPLORAR:
			criatura.liberar_control_movimiento()

			if distancia <= distancia_deteccion:
				_iniciar_carga_ligniano()

		Estado.ATACANDO_CUERPO:
			_procesar_carga_ligniano(delta, distancia)

		Estado.ENFRIAMIENTO:
			_procesar_enfriamiento_ligniano(delta, distancia)

		_:
			_estado = Estado.EXPLORAR
			criatura.liberar_control_movimiento()


func _iniciar_carga_ligniano() -> void:
	if objetivo == null:
		return

	_estado = Estado.ATACANDO_CUERPO
	criatura.tomar_control_movimiento()
	_establecer_velocidad(ligniano_velocidad_carga)

	var direccion: Vector2 = (
		criatura.global_position.direction_to(
			objetivo.global_position
		)
	)

	criatura.establecer_direccion_movimiento(
		direccion
	)

	print(
		criatura.get_nombre(),
		" carga hacia el jugador."
	)


func _procesar_carga_ligniano(
	_delta: float,
	distancia: float
) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_estado = Estado.EXPLORAR
		criatura.liberar_control_movimiento()
		return

	if distancia > distancia_deteccion * 1.3:
		# El jugador escapó.
		_estado = Estado.EXPLORAR
		_establecer_velocidad(_velocidad_normal)
		criatura.liberar_control_movimiento()
		return

	# Actualiza dirección continuamente.
	var direccion: Vector2 = (
		criatura.global_position.direction_to(
			objetivo.global_position
		)
	)

	criatura.establecer_direccion_movimiento(
		direccion
	)

	if distancia <= distancia_contacto:
		_golpear_ligniano()


func _golpear_ligniano() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cancelar_a_explorar()
		return

	# Daño.
	if objetivo.has_method("take_damage"):
		objetivo.take_damage(ligniano_dano_contacto)

		print(
			criatura.get_nombre(),
			" golpea a ",
			objetivo.name,
			" por ",
			ligniano_dano_contacto,
			" de daño."
		)

	# Slow — el jugador puede implementar este método.
	if objetivo.has_method("aplicar_efecto_slow"):
		objetivo.aplicar_efecto_slow(
			ligniano_duracion_slow
		)

		print(
			criatura.get_nombre(),
			" ralentiza a ",
			objetivo.name,
			" durante ",
			ligniano_duracion_slow,
			"s."
		)

	criatura.detener_movimiento()
	_establecer_velocidad(_velocidad_normal)

	_estado = Estado.ENFRIAMIENTO
	_tiempo_enfriamiento = ligniano_enfriamiento


func _procesar_enfriamiento_ligniano(
	delta: float,
	distancia: float
) -> void:
	criatura.detener_movimiento()

	_tiempo_enfriamiento -= delta

	if _tiempo_enfriamiento > 0.0:
		return

	_tiempo_enfriamiento = 0.0

	if distancia <= distancia_deteccion:
		_iniciar_carga_ligniano()
	else:
		_cancelar_a_explorar()


func _cancelar_a_explorar() -> void:
	_estado = Estado.EXPLORAR
	_establecer_velocidad(_velocidad_normal)
	criatura.liberar_control_movimiento()


# ============================================================
# OTRAS CRIATURAS
# ============================================================

func _procesar_criatura_generica(
	_delta: float
) -> void:
	return


# ============================================================
# MOVIMIENTO
# ============================================================

func _encontrar_movimiento() -> void:
	if criatura == null:
		return

	_movimiento = criatura.get_node_or_null(
		"CreatureMovement"
	) as CreatureMovement

	if _movimiento != null:
		_velocidad_normal = (
			_movimiento.move_speed
		)


func _establecer_velocidad(
	nueva_velocidad: float
) -> void:
	if _movimiento == null:
		_encontrar_movimiento()

	if _movimiento == null:
		return

	_movimiento.move_speed = maxf(
		nueva_velocidad,
		0.0
	)


# ============================================================
# OBJETIVO
# ============================================================

func _encontrar_objetivo() -> void:
	var jugador: Node = (
		get_tree().get_first_node_in_group(
			"player"
		)
	)

	if jugador is Node2D:
		objetivo = jugador as Node2D
		return

	var escena: Node = get_tree().current_scene

	if escena == null:
		objetivo = null
		return

	var encontrado: Node = (
		_buscar_nodo_jugador(escena)
	)

	if encontrado is Node2D:
		objetivo = encontrado as Node2D
	else:
		objetivo = null


func _buscar_nodo_jugador(
	nodo: Node
) -> Node:
	if nodo.name == "Player":
		return nodo

	for child in nodo.get_children():
		var encontrado: Node = (
			_buscar_nodo_jugador(child)
		)

		if encontrado != null:
			return encontrado

	return null
