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
	RECUPERANDO,
	ADHERIDO,
	SALTANDO_LEJOS
}


enum Perfil {
	GENERICO,
	FLAXIS,
	ZLISH,
	LIGNIANOS,
	CAMBIAFORMAS,
	ESPIRITU_ESTELAR,
	RANCRODEEN
}


@export_category("State Machine")
@export var estado_inicial: Estado = Estado.EXPLORANDO
@export var mostrar_estado_debug: bool = false
@export var intervalo_pensamiento: float = 0.12
@export var duracion_investigacion: float = 1.20


@export_category("Compatibilidad de IA antiguas")
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
var configuracion_ia: Dictionary = {}


var estado: Estado = Estado.IDLE
var perfil: Perfil = Perfil.GENERICO


var ultima_posicion_objetivo: Vector2 = Vector2.ZERO
var objetivo_detectado: bool = false


var _tiempo_pensamiento: float = 0.0
var _tiempo_estado: float = 0.0
var _tiempo_accion: float = 0.0
var _tiempo_recuperacion: float = 0.0
var _tiempo_adherido: float = 0.0
var _tiempo_danio_adherido: float = 0.0
var _tiempo_teleport: float = 0.0


var _objetivo_ataque: Vector2 = Vector2.ZERO
var _direccion_salto: Vector2 = Vector2.ZERO
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
	_refrescar_configuracion()
	_cambiar_estado_forzado(estado_inicial)


func configurar_criatura() -> void:
	_refrescar_configuracion()

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

	_tiempo_teleport = maxf(
		_tiempo_teleport - delta,
		0.0
	)

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


func _cambiar_estado_forzado(nuevo_estado: Estado) -> void:
	estado = Estado.IDLE
	_cambiar_estado(nuevo_estado)


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
		Estado.ADHERIDO:
			return "ADHERIDO"
		Estado.SALTANDO_LEJOS:
			return "SALTANDO_LEJOS"

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
			_tiempo_estado = 0.0

		Estado.PERSIGUIENDO:
			_iniciar_persecucion()

		Estado.ATACANDO:
			_iniciar_ataque()

		Estado.HUYENDO:
			_iniciar_huida()

		Estado.RECUPERANDO:
			criatura.detener_movimiento()

		Estado.ADHERIDO:
			_iniciar_estado_adherido()

		Estado.SALTANDO_LEJOS:
			_iniciar_estado_saltando_lejos()


func _salir_estado(anterior: Estado) -> void:
	match anterior:
		Estado.INVESTIGANDO:
			_establecer_velocidad(_velocidad_normal)

		Estado.PERSIGUIENDO:
			_establecer_velocidad(_velocidad_normal)

		Estado.ATACANDO:
			_establecer_velocidad(_velocidad_normal)

		Estado.HUYENDO:
			_establecer_velocidad(_velocidad_normal)

		Estado.ADHERIDO:
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

		Estado.ADHERIDO:
			_procesar_adherido(delta)

		Estado.SALTANDO_LEJOS:
			_procesar_saltando_lejos(delta)


func _procesar_idle() -> void:
	criatura.detener_movimiento()

	if criatura.is_alive:
		_cambiar_estado(Estado.EXPLORANDO)


func _procesar_explorando() -> void:
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
				pass
	else:
		criatura.liberar_control_movimiento()


func _procesar_investigando() -> void:
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

	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	if _tiempo_estado >= duracion_investigacion:
		_cambiar_estado(Estado.EXPLORANDO)
		return

	var direccion := criatura.global_position.direction_to(
		ultima_posicion_objetivo
	)

	if direccion.length_squared() <= 0.01:
		_cambiar_estado(Estado.EXPLORANDO)
		return

	criatura.tomar_control_movimiento()
	criatura.establecer_direccion_movimiento(direccion)


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

	var maxima := _obtener_distancia_maxima_persecucion()

	if maxima > 0.0 and distancia > maxima:
		_cambiar_estado(Estado.INVESTIGANDO)
		return

	_establecer_velocidad(
		_obtener_velocidad_persecucion()
	)
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

		Perfil.CAMBIAFORMAS:
			_procesar_ataque_contacto(
				delta,
				_obtener_danio_ataque(),
				_obtener_enfriamiento_ataque(),
				true
			)

		Perfil.ESPIRITU_ESTELAR:
			_procesar_ataque_contacto(
				delta,
				_obtener_danio_ataque(),
				_obtener_enfriamiento_ataque(),
				false
			)

		Perfil.RANCRODEEN:
			_procesar_ataque_rancrodeen(delta)

		_:
			_cambiar_estado(Estado.RECUPERANDO)


func _procesar_huyendo() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	var distancia := criatura.global_position.distance_to(
		objetivo.global_position
	)

	var segura := _obtener_distancia_segura_huida()

	if distancia > segura:
		_cambiar_estado(Estado.EXPLORANDO)
		return

	_establecer_velocidad(
		_obtener_velocidad_huida()
	)
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

	var deteccion := _obtener_distancia_deteccion()

	if distancia <= deteccion:
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
# CONFIGURACIÓN CANÓNICA
# ============================================================

func _refrescar_configuracion() -> void:
	if criatura == null:
		configuracion_ia = {}
		perfil = Perfil.GENERICO
		return

	configuracion_ia = criatura.obtener_config_ia()

	if not configuracion_ia.is_empty():
		var perfil_texto := str(
			configuracion_ia.get("perfil", "")
		).strip_edges().to_lower()

		perfil = _perfil_desde_texto(perfil_texto)

		if perfil != Perfil.GENERICO:
			return

	var comportamiento := criatura.comportamiento.strip_edges().to_lower()

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

	perfil = _perfil_desde_texto(comportamiento)


func _perfil_desde_texto(texto: String) -> Perfil:
	match texto:
		"flaxis":
			return Perfil.FLAXIS
		"zlish":
			return Perfil.ZLISH
		"lignianos":
			return Perfil.LIGNIANOS
		"cambiaformas":
			return Perfil.CAMBIAFORMAS
		"espiritu_estelar", "espiritu estelar":
			return Perfil.ESPIRITU_ESTELAR
		"rancrodeen":
			return Perfil.RANCRODEEN

	return Perfil.GENERICO


func _obtener_respuesta_a_objetivo() -> String:
	match perfil:
		Perfil.ZLISH:
			return "huir"

		Perfil.FLAXIS:
			return "atacar"

		Perfil.LIGNIANOS:
			return "perseguir"

		Perfil.CAMBIAFORMAS:
			return "perseguir"

		Perfil.ESPIRITU_ESTELAR:
			return "perseguir"

		Perfil.RANCRODEEN:
			return "perseguir"

	var comportamiento := ""
	if criatura != null:
		comportamiento = criatura.comportamiento.strip_edges().to_lower()

	if comportamiento.is_empty():
		return ""

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

	return ""


func _obtener_config_ataque() -> Dictionary:
	var valor: Variant = configuracion_ia.get(
		"ataque",
		{}
	)

	if valor is Dictionary:
		return valor as Dictionary

	return {}


func _obtener_danio_ataque() -> int:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get("danio", dano_mordida)

	if valor is int or valor is float:
		return maxi(int(valor), 0)

	return dano_mordida


func _obtener_enfriamiento_ataque() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"enfriamiento",
		enfriamiento_ataque
	)

	if valor is int or valor is float:
		return maxf(float(valor), 0.0)

	return enfriamiento_ataque


func _obtener_distancia_deteccion() -> float:
	var valor: Variant = configuracion_ia.get(
		"deteccion",
		distancia_deteccion
	)

	if valor is int or valor is float:
		return maxf(float(valor), 0.0)

	return distancia_deteccion


func _obtener_distancia_maxima_persecucion() -> float:
	if perfil == Perfil.LIGNIANOS:
		return _obtener_distancia_deteccion() * 1.3

	var ataque := _obtener_config_ataque()

	if ataque.has("distancia_maxima_persecucion"):
		var valor: Variant = ataque.get(
			"distancia_maxima_persecucion"
		)

		if valor is int or valor is float:
			return maxf(float(valor), 0.0)

	return _obtener_distancia_deteccion()


# ============================================================
# ATAQUES BASE
# ============================================================

func _iniciar_ataque() -> void:
	_ataque_resuelto = false

	match perfil:
		Perfil.FLAXIS:
			_iniciar_ataque_flaxis()

		Perfil.LIGNIANOS:
			_iniciar_ataque_ligniano()

		Perfil.CAMBIAFORMAS, Perfil.ESPIRITU_ESTELAR:
			criatura.tomar_control_movimiento()
			_establecer_velocidad(
				_obtener_velocidad_ataque()
			)

		Perfil.RANCRODEEN:
			criatura.tomar_control_movimiento()
			_establecer_velocidad(
				_obtener_velocidad_ataque()
			)

		_:
			_cambiar_estado(Estado.RECUPERANDO)


func _procesar_ataque_contacto(
	_delta: float,
	danio: int,
	enfriamiento: float,
	copiar_skin: bool
) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	var distancia := criatura.global_position.distance_to(
		objetivo.global_position
	)

	if distancia > distancia_contacto:
		_establecer_velocidad(
			_obtener_velocidad_ataque()
		)
		criatura.tomar_control_movimiento()

		var direccion := criatura.global_position.direction_to(
			objetivo.global_position
		)

		criatura.establecer_direccion_movimiento(direccion)
		return

	if _ataque_resuelto:
		return

	_ataque_resuelto = true
	criatura.detener_movimiento()

	if objetivo.has_method("take_damage"):
		objetivo.call("take_damage", danio)

	if copiar_skin:
		criatura.copiar_skin_de(objetivo)

	_iniciar_recuperacion(enfriamiento)


func _obtener_velocidad_ataque() -> float:
	match perfil:
		Perfil.CAMBIAFORMAS:
			return velocidad_persecucion

		Perfil.RANCRODEEN:
			return velocidad_persecucion

	return velocidad_persecucion


func _iniciar_ataque_generico_contacto() -> void:
	_cambiar_estado(Estado.ATACANDO)


# ============================================================
# FLAXIS
# ============================================================

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

		_iniciar_recuperacion(enfriamiento_ataque)
		return

	_iniciar_recuperacion(enfriamiento_fallido)


# ============================================================
# LIGNIANOS
# ============================================================

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

	_iniciar_recuperacion(ligniano_enfriamiento)


func _procesar_ataque_lignianos() -> void:
	if not _ataque_resuelto:
		_ataque_resuelto = true

	_cambiar_estado(Estado.RECUPERANDO)


# ============================================================
# CAMBIAFORMAS
# ============================================================

func _copiar_skin_de_objetivo() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return

	criatura.copiar_skin_de(objetivo)


# ============================================================
# RANCRODEEN
# ============================================================

func _procesar_ataque_rancrodeen(_delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	var distancia := criatura.global_position.distance_to(
		objetivo.global_position
	)

	if distancia <= distancia_contacto:
		_cambiar_estado(Estado.ADHERIDO)
		return

	criatura.tomar_control_movimiento()
	_establecer_velocidad(
		_obtener_velocidad_ataque()
	)

	var direccion := criatura.global_position.direction_to(
		objetivo.global_position
	)

	criatura.establecer_direccion_movimiento(direccion)


func _iniciar_estado_adherido() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	_tiempo_adherido = _obtener_float_ataque(
		"duracion_adherido",
		5.0
	)

	_tiempo_danio_adherido = 0.0

	criatura.detener_movimiento()
	criatura.establecer_colision(false)


func _procesar_adherido(delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_desprender_rancrodeen()
		return

	_tiempo_adherido -= delta
	_tiempo_danio_adherido -= delta

	criatura.global_position = (
		objetivo.global_position
		+ Vector2(0.0, -16.0)
	)

	if _tiempo_danio_adherido <= 0.0:
		_tiempo_danio_adherido = maxf(
			_obtener_float_ataque(
				"intervalo_danio",
				1.0
			),
			0.05
		)

		if objetivo.has_method("take_damage"):
			objetivo.call(
				"take_damage",
				_obtener_danio_ataque()
			)

	if _tiempo_adherido <= 0.0:
		_iniciar_salto_lejos()


func _desprender_rancrodeen() -> void:
	criatura.establecer_colision(true)
	_cambiar_estado(Estado.EXPLORANDO)


func _iniciar_salto_lejos() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_desprender_rancrodeen()
		return

	var direccion := objetivo.global_position.direction_to(
		criatura.global_position
	)

	if direccion.length_squared() <= 0.01:
		direccion = Vector2.RIGHT.rotated(
			randf_range(-PI, PI)
		)

	_direccion_salto = direccion.normalized()
	_cambiar_estado(Estado.SALTANDO_LEJOS)


func _iniciar_estado_saltando_lejos() -> void:
	_tiempo_accion = maxf(
		_obtener_float_ataque(
			"duracion_salto",
			0.38
		),
		0.01
	)

	var distancia := _obtener_float_ataque(
		"distancia_salto",
		72.0
	)

	_objetivo_ataque = (
		criatura.global_position
		+ _direccion_salto * distancia
	)

	criatura.establecer_colision(true)
	criatura.tomar_control_movimiento()
	_establecer_velocidad(
		_obtener_float_ataque(
			"velocidad_salto",
			190.0
		)
	)
	criatura.establecer_direccion_movimiento(
		_direccion_salto
	)


func _procesar_saltando_lejos(delta: float) -> void:
	_tiempo_accion -= delta

	if (
		criatura.global_position.distance_to(
			_objetivo_ataque
		) <= distancia_contacto
		or _tiempo_accion <= 0.0
	):
		_establecer_velocidad(
			_obtener_velocidad_ataque()
		)
		_cambiar_estado(Estado.PERSIGUIENDO)
		return

	var direccion := criatura.global_position.direction_to(
		_objetivo_ataque
	)

	criatura.establecer_direccion_movimiento(direccion)


# ============================================================
# ESPIRITU ESTELAR
# ============================================================

func al_recibir_danio(_cantidad: int) -> void:
	if perfil != Perfil.ESPIRITU_ESTELAR:
		return

	if _tiempo_teleport > 0.0:
		return

	var reaccion_variant: Variant = configuracion_ia.get(
		"al_recibir_danio",
		{}
	)

	if not reaccion_variant is Dictionary:
		return

	var reaccion := reaccion_variant as Dictionary

	if str(reaccion.get("tipo", "")).to_lower() != "teletransportarse":
		return

	_teletransportar_espiritu_estelar(reaccion)

	_tiempo_teleport = maxf(
		float(reaccion.get("inmunidad", 0.45)),
		0.0
	)


func _teletransportar_espiritu_estelar(
	reaccion: Dictionary
) -> void:
	var origen := criatura.global_position

	var minimo := maxf(
		float(reaccion.get("distancia_minima", 70.0)),
		1.0
	)

	var maximo := maxf(
		float(reaccion.get("distancia_maxima", 110.0)),
		minimo
	)

	var direccion := Vector2.RIGHT

	if objetivo != null and is_instance_valid(objetivo):
		direccion = objetivo.global_position.direction_to(
			origen
		)

	if direccion.length_squared() <= 0.01:
		direccion = Vector2.RIGHT

	direccion = direccion.rotated(
		randf_range(-0.9, 0.9)
	).normalized()

	var destino := (
		origen
		+ direccion * randf_range(minimo, maximo)
	)

	if criatura.limites_chunk.size.x > 0.0:
		var limites := criatura.limites_chunk.grow(-12.0)

		destino.x = clampf(
			destino.x,
			limites.position.x,
			limites.end.x
		)

		destino.y = clampf(
			destino.y,
			limites.position.y,
			limites.end.y
		)

	var rastro_variant: Variant = reaccion.get(
		"rastro",
		{}
	)

	var rastro: Dictionary = {}

	if rastro_variant is Dictionary:
		rastro = rastro_variant as Dictionary

	criatura.crear_rastro_teleport(
		origen,
		destino,
		maxf(float(rastro.get("duracion", 0.7)), 0.1),
		maxi(int(rastro.get("puntos", 18)), 4)
	)

	criatura.global_position = destino


# ============================================================
# HELPERS
# ============================================================

func _obtener_float_ataque(
	clave: String,
	por_defecto: float
) -> float:
	var ataque := _obtener_config_ataque()

	var valor: Variant = ataque.get(
		clave,
		por_defecto
	)

	if valor is int or valor is float:
		return maxf(
			float(valor),
			0.0
		)

	return por_defecto


func _iniciar_recuperacion(duracion: float) -> void:
	_tiempo_recuperacion = maxf(
		duracion,
		0.0
	)
	_cambiar_estado(Estado.RECUPERANDO)


func _iniciar_persecucion() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	criatura.tomar_control_movimiento()
	_establecer_velocidad(
		_obtener_velocidad_persecucion()
	)


func _obtener_velocidad_persecucion() -> float:
	match perfil:
		Perfil.FLAXIS:
			return velocidad_persecucion

		Perfil.LIGNIANOS:
			return ligniano_velocidad_carga

		Perfil.CAMBIAFORMAS:
			return _obtener_float_config(
				"velocidad_persecucion",
				velocidad_persecucion
			)

		Perfil.RANCRODEEN:
			return _obtener_float_config(
				"velocidad_persecucion",
				velocidad_persecucion
			)

	return velocidad_persecucion


func _obtener_float_config(
	clave: String,
	por_defecto: float
) -> float:
	var valor: Variant = configuracion_ia.get(
		clave,
		por_defecto
	)

	if valor is int or valor is float:
		return maxf(
			float(valor),
			0.0
		)

	return por_defecto


func _iniciar_huida() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	criatura.tomar_control_movimiento()
	_establecer_velocidad(
		_obtener_velocidad_huida()
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

	return _obtener_distancia_deteccion()


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


func _configurar_desde_padre() -> void:
	criatura = get_parent() as Creature


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
