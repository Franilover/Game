extends Node
class_name CreatureAI


signal estado_cambiado(anterior: int, nuevo: int)


enum Estado {
	IDLE,
	EXPLORANDO,
	INVESTIGANDO,
	PERSIGUIENDO,
	ATACANDO,
	HUYENDO,
	RECUPERANDO
}


enum Perfil {
	GENERICO,
	FLAXIS,
	ZLISH,
	LIGNIANOS
}


@export_category("State Machine")
@export var estado_inicial: Estado = Estado.EXPLORANDO
@export var mostrar_estado_debug: bool = false
@export var intervalo_pensamiento: float = 0.12


@export_category("Percepción")
@export var distancia_deteccion: float = 150.0
@export var distancia_contacto: float = 12.0


@export_category("Flaxis")
@export var velocidad_persecucion: float = 50.0
@export var velocidad_lanzamiento: float = 220.0
@export var duracion_lanzamiento: float = 0.70
@export var dano_mordida: int = 8
@export var enfriamiento_ataque: float = 1.50
@export var enfriamiento_fallido: float = 1.20


@export_category("Zlish")
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


var estado: Estado = Estado.EXPLORANDO
var perfil: Perfil = Perfil.GENERICO


var ultima_posicion_objetivo: Vector2 = Vector2.ZERO
var objetivo_detectado: bool = false


var _tiempo_pensamiento: float = 0.0
var _tiempo_estado: float = 0.0
var _tiempo_accion: float = 0.0
var _tiempo_recuperacion: float = 0.0


var _objetivo_ataque: Vector2 = Vector2.ZERO
var _ataque_resuelto: bool = false


var _movimiento: CreatureMovement = null
var _velocidad_normal: float = 20.0


func _ready() -> void:
	_configurar_desde_padre()

	if criatura == null:
		push_error(
			"CreatureAI: el nodo padre no es una Creature."
		)
		set_physics_process(false)
		return

	_encontrar_movimiento()
	_refrescar_perfil()
	_cambiar_estado(estado_inicial)


func configurar_criatura() -> void:
	_refrescar_perfil()

	if criatura == null:
		return

	if not criatura.is_alive:
		_cambiar_estado(Estado.IDLE)


func _physics_process(delta: float) -> void:
	if criatura == null:
		return

	if not is_instance_valid(criatura):
		return

	if not criatura.is_alive:
		if estado != Estado.IDLE:
			_cambiar_estado(Estado.IDLE)
		return

	_tiempo_pensamiento -= delta

	if _tiempo_pensamiento <= 0.0:
		_tiempo_pensamiento = maxf(
			intervalo_pensamiento,
			0.01
		)
		_actualizar_percepcion()

	_procesar_estado(delta)


# ============================================================
# STATE MACHINE
# ============================================================

func _cambiar_estado(nuevo_estado: Estado) -> void:
	if estado == nuevo_estado:
		return

	var anterior := estado

	_salir_estado(anterior)

	estado = nuevo_estado
	_tiempo_estado = 0.0

	_entrar_estado(nuevo_estado)

	estado_cambiado.emit(
		int(anterior),
		int(nuevo_estado)
	)

	if mostrar_estado_debug and criatura != null:
		print(
			"CreatureAI [",
			criatura.get_nombre(),
			"] ",
			_obtener_nombre_estado(anterior),
			" → ",
			_obtener_nombre_estado(nuevo_estado)
		)


func get_estado() -> Estado:
	return estado


func get_estado_nombre() -> String:
	return _obtener_nombre_estado(estado)


func _obtener_nombre_estado(valor: Estado) -> String:
	match valor:
		Estado.IDLE:
			return "IDLE"
		Estado.EXPLORANDO:
			return "EXPLORANDO"
		Estado.INVESTIGANDO:
			return "INVESTIGANDO"
		Estado.PERSIGUIENDO:
			return "PERSIGUIENDO"
		Estado.ATACANDO:
			return "ATACANDO"
		Estado.HUYENDO:
			return "HUYENDO"
		Estado.RECUPERANDO:
			return "RECUPERANDO"

	return "DESCONOCIDO"


func _entrar_estado(nuevo_estado: Estado) -> void:
	match nuevo_estado:
		Estado.IDLE:
			criatura.detener_movimiento()

		Estado.EXPLORANDO:
			_establecer_velocidad(_velocidad_normal)
			criatura.liberar_control_movimiento()

		Estado.INVESTIGANDO:
			_establecer_velocidad(_velocidad_normal)
			criatura.tomar_control_movimiento()

		Estado.PERSIGUIENDO:
			_iniciar_persecucion()

		Estado.ATACANDO:
			_iniciar_ataque()

		Estado.HUYENDO:
			_iniciar_huida()

		Estado.RECUPERANDO:
			criatura.detener_movimiento()


func _salir_estado(anterior: Estado) -> void:
	match anterior:
		Estado.PERSIGUIENDO, Estado.ATACANDO, Estado.HUYENDO, Estado.INVESTIGANDO:
			_establecer_velocidad(_velocidad_normal)


func _procesar_estado(delta: float) -> void:
	_tiempo_estado += delta

	match estado:
		Estado.IDLE:
			_procesar_idle()

		Estado.EXPLORANDO:
			_procesar_explorando()

		Estado.INVESTIGANDO:
			_procesar_investigando()

		Estado.PERSIGUIENDO:
			_procesar_persiguiendo()

		Estado.ATACANDO:
			_procesar_atacando(delta)

		Estado.HUYENDO:
			_procesar_huyendo()

		Estado.RECUPERANDO:
			_procesar_recuperando(delta)


func _procesar_idle() -> void:
	criatura.detener_movimiento()

	if criatura.is_alive:
		_cambiar_estado(Estado.EXPLORANDO)


func _procesar_explorando() -> void:
	criatura.liberar_control_movimiento()

	if not objetivo_detectado:
		return

	match _obtener_respuesta_a_objetivo():
		"huir":
			_cambiar_estado(Estado.HUYENDO)

		"atacar":
			_cambiar_estado(Estado.ATACANDO)

		"perseguir":
			_cambiar_estado(Estado.PERSIGUIENDO)

		"investigar":
			_cambiar_estado(Estado.INVESTIGANDO)


func _procesar_investigando() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	if objetivo_detectado:
		match _obtener_respuesta_a_objetivo():
			"huir":
				_cambiar_estado(Estado.HUYENDO)

			"atacar":
				_cambiar_estado(Estado.ATACANDO)

			"perseguir":
				_cambiar_estado(Estado.PERSIGUIENDO)

			_:
				_cambiar_estado(Estado.EXPLORANDO)
		return

	var direccion := criatura.global_position.direction_to(
		ultima_posicion_objetivo
	)

	if direccion.length_squared() <= 0.01:
		_cambiar_estado(Estado.EXPLORANDO)
		return

	criatura.establecer_direccion_movimiento(direccion)

	if criatura.global_position.distance_to(
		ultima_posicion_objetivo
	) <= distancia_contacto:
		criatura.detener_movimiento()
		_cambiar_estado(Estado.EXPLORANDO)


func _procesar_persiguiendo() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	if not objetivo_detectado:
		_cambiar_estado(Estado.INVESTIGANDO)
		return

	var distancia := criatura.global_position.distance_to(
		objetivo.global_position
	)

	if _obtener_distancia_maxima_persecucion() > 0.0:
		if distancia > _obtener_distancia_maxima_persecucion():
			_cambiar_estado(Estado.INVESTIGANDO)
			return

	_establecer_velocidad(velocidad_persecucion)
	criatura.tomar_control_movimiento()

	var direccion := criatura.global_position.direction_to(
		objetivo.global_position
	)

	criatura.establecer_direccion_movimiento(direccion)

	if distancia <= distancia_contacto:
		_cambiar_estado(Estado.ATACANDO)


func _procesar_atacando(delta: float) -> void:
	match perfil:
		Perfil.FLAXIS:
			_procesar_ataque_flaxis(delta)

		Perfil.LIGNIANOS:
			_procesar_ataque_lignianos()

		_:
			_cambiar_estado(Estado.RECUPERANDO)


func _procesar_huyendo() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	var distancia := criatura.global_position.distance_to(
		objetivo.global_position
	)

	if distancia > _obtener_distancia_segura_huida():
		_cambiar_estado(Estado.EXPLORANDO)
		return

	_establecer_velocidad(_obtener_velocidad_huida())
	criatura.tomar_control_movimiento()

	var direccion := objetivo.global_position.direction_to(
		criatura.global_position
	)

	criatura.establecer_direccion_movimiento(direccion)


func _procesar_recuperando(delta: float) -> void:
	criatura.detener_movimiento()

	_tiempo_recuperacion -= delta

	if _tiempo_recuperacion > 0.0:
		return

	_tiempo_recuperacion = 0.0

	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	if objetivo_detectado:
		match _obtener_respuesta_a_objetivo():
			"huir":
				_cambiar_estado(Estado.HUYENDO)

			"atacar":
				_cambiar_estado(Estado.ATACANDO)

			"perseguir":
				_cambiar_estado(Estado.PERSIGUIENDO)

			"investigar":
				_cambiar_estado(Estado.INVESTIGANDO)

			_:
				_cambiar_estado(Estado.EXPLORANDO)
	else:
		_cambiar_estado(Estado.INVESTIGANDO)


# ============================================================
# PERCEPCIÓN
# ============================================================

func _actualizar_percepcion() -> void:
	_refrescar_objetivo()

	objetivo_detectado = false

	if objetivo == null or not is_instance_valid(objetivo):
		return

	if "is_alive" in objetivo:
		if not bool(objetivo.is_alive):
			return

	var distancia := criatura.global_position.distance_to(
		objetivo.global_position
	)

	if distancia <= distancia_deteccion:
		objetivo_detectado = true
		ultima_posicion_objetivo = objetivo.global_position


func _refrescar_objetivo() -> void:
	if objetivo != null and is_instance_valid(objetivo):
		return

	var jugador := get_tree().get_first_node_in_group("player")

	if jugador is Node2D:
		objetivo = jugador as Node2D
		return

	var escena := get_tree().current_scene

	if escena == null:
		objetivo = null
		return

	var encontrado := _buscar_nodo_jugador(escena)

	if encontrado is Node2D:
		objetivo = encontrado as Node2D
	else:
		objetivo = null


func _buscar_nodo_jugador(nodo: Node) -> Node:
	if nodo.name == "Player":
		return nodo

	for child in nodo.get_children():
		var encontrado := _buscar_nodo_jugador(child)

		if encontrado != null:
			return encontrado

	return null


# ============================================================
# DECISIÓN
# ============================================================

func _obtener_respuesta_a_objetivo() -> String:
	if perfil == Perfil.ZLISH:
		return "huir"

	if perfil == Perfil.FLAXIS:
		return "atacar"

	if perfil == Perfil.LIGNIANOS:
		return "perseguir"

	var comportamiento := ""
	if criatura != null:
		comportamiento = criatura.comportamiento.strip_edges().to_lower()

	if comportamiento.is_empty():
		return "investigar"

	if (
		"huir" in comportamiento
		or "huid" in comportamiento
		or "evita" in comportamiento
	):
		return "huir"

	if (
		"agres" in comportamiento
		or "atac" in comportamiento
		or "caz" in comportamiento
	):
		return "perseguir"

	return "investigar"


func _obtener_distancia_maxima_persecucion() -> float:
	if perfil == Perfil.LIGNIANOS:
		return distancia_deteccion * 1.3

	return distancia_deteccion


func _refrescar_perfil() -> void:
	if criatura == null:
		perfil = Perfil.GENERICO
		return

	var comportamiento := criatura.comportamiento.strip_edges().to_lower()

	# Compatibilidad con las tres IA prototipo actuales.
	# Cuando Supabase tenga comportamiento estructurado,
	# ese dato podrá tomar el control sin cambiar la máquina.
	if comportamiento.is_empty():
		match criatura.get_nombre().strip_edges().to_lower():
			"flaxis":
				perfil = Perfil.FLAXIS

			"zlish":
				perfil = Perfil.ZLISH

			"lignianos":
				perfil = Perfil.LIGNIANOS

			_:
				perfil = Perfil.GENERICO

		return

	match comportamiento:
		"flaxis":
			perfil = Perfil.FLAXIS

		"zlish":
			perfil = Perfil.ZLISH

		"lignianos":
			perfil = Perfil.LIGNIANOS

		_:
			perfil = Perfil.GENERICO


# ============================================================
# ATAQUES
# ============================================================

func _iniciar_ataque() -> void:
	_ataque_resuelto = false

	match perfil:
		Perfil.FLAXIS:
			_iniciar_ataque_flaxis()

		Perfil.LIGNIANOS:
			_iniciar_ataque_ligniano()

		_:
			_cambiar_estado(Estado.RECUPERANDO)


func _iniciar_ataque_flaxis() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	_tiempo_accion = maxf(
		duracion_lanzamiento,
		0.01
	)

	_objetivo_ataque = objetivo.global_position
	ultima_posicion_objetivo = _objetivo_ataque

	criatura.tomar_control_movimiento()
	_establecer_velocidad(velocidad_lanzamiento)

	var direccion := criatura.global_position.direction_to(
		_objetivo_ataque
	)

	criatura.establecer_direccion_movimiento(direccion)

	if mostrar_estado_debug:
		print(
			criatura.get_nombre(),
			" inicia ataque de salto → ",
			_objetivo_ataque
		)

	_animar_salto()


func _procesar_ataque_flaxis(delta: float) -> void:
	if _ataque_resuelto:
		return

	_tiempo_accion -= delta

	var distancia_punto := criatura.global_position.distance_to(
		_objetivo_ataque
	)

	if distancia_punto <= distancia_contacto:
		_resolver_ataque_flaxis()
		return

	var direccion := criatura.global_position.direction_to(
		_objetivo_ataque
	)

	criatura.establecer_direccion_movimiento(direccion)

	if _tiempo_accion <= 0.0:
		_resolver_ataque_flaxis()


func _resolver_ataque_flaxis() -> void:
	if _ataque_resuelto:
		return

	_ataque_resuelto = true
	criatura.detener_movimiento()
	_establecer_velocidad(_velocidad_normal)

	var jugador_cerca := false

	if objetivo != null and is_instance_valid(objetivo):
		jugador_cerca = (
			criatura.global_position.distance_to(
				objetivo.global_position
			) <= distancia_contacto
		)

	if jugador_cerca and objetivo.has_method("take_damage"):
		objetivo.call(
			"take_damage",
			dano_mordida
		)

		if mostrar_estado_debug:
			print(
				criatura.get_nombre(),
				" impacta por ",
				dano_mordida,
				" de daño."
			)

		_iniciar_recuperacion(enfriamiento_ataque)
		return

	_iniciar_recuperacion(enfriamiento_fallido)


func _iniciar_ataque_ligniano() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	criatura.detener_movimiento()

	if objetivo.has_method("take_damage"):
		objetivo.call(
			"take_damage",
			ligniano_dano_contacto
		)

		if objetivo.has_method("aplicar_efecto_slow"):
			objetivo.call(
				"aplicar_efecto_slow",
				ligniano_duracion_slow
			)

		if mostrar_estado_debug:
			print(
				criatura.get_nombre(),
				" golpea a ",
				objetivo.name,
				" por ",
				ligniano_dano_contacto,
				" y aplica slow."
			)

	_iniciar_recuperacion(ligniano_enfriamiento)


func _procesar_ataque_lignianos() -> void:
	if not _ataque_resuelto:
		_ataque_resuelto = true
		# El ataque se ejecuta al entrar al estado.
		# El estado ATACANDO dura un frame lógico.
		_cambiar_estado(Estado.RECUPERANDO)


func _resolver_ataque_lignianos() -> void:
	return


func _iniciar_recuperacion(duracion: float) -> void:
	_tiempo_recuperacion = maxf(
		duracion,
		0.0
	)
	_cambiar_estado(Estado.RECUPERANDO)


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
		_velocidad_normal = maxf(
			_movimiento.move_speed,
			0.0
		)


func _establecer_velocidad(nueva_velocidad: float) -> void:
	if _movimiento == null:
		_encontrar_movimiento()

	if _movimiento == null:
		return

	_movimiento.move_speed = maxf(
		nueva_velocidad,
		0.0
	)


func _obtener_velocidad_huida() -> float:
	if perfil == Perfil.ZLISH:
		return zlish_velocidad_huida

	return maxf(
		velocidad_persecucion,
		_velocidad_normal
	)


func _obtener_distancia_segura_huida() -> float:
	if perfil == Perfil.ZLISH:
		return zlish_distancia_segura

	return distancia_deteccion


# ============================================================
# ANIMACIÓN
# ============================================================

func _animar_salto() -> void:
	if criatura == null:
		return

	var escala_original := criatura.scale

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
