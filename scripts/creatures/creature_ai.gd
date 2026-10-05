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
	DRAMARIAS,
	CAMBIAFORMAS,
	ESPIRITU_ESTELAR,
	RANCRODEEN,
	GUARDIAN,
	CAZADOR
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


@export_category("Dramarias")
@export var dramarias_distancia_ataque: float = 14.0
@export var dramarias_dano_contacto: int = 6
@export var dramarias_enfriamiento: float = 1.0

@export_category("Lignianos")
@export var ligniano_velocidad_carga: float = 45.0
@export var ligniano_dano_contacto: int = 6
@export var ligniano_duracion_slow: float = 2.0
@export var ligniano_enfriamiento: float = 2.0


var criatura: Creature = null
var objetivo: Node2D = null
var configuracion_ia: Dictionary = {}
var relaciones_ecologicas: Array = []
var jugador: Node2D = null
var entity_manager: WorldEntityManager = null
var inventory: GarliaInventory = null
var combat_system: CombatSystem = null
var world_items: GarliaWorldItems = null
var world_atmosphere: WorldAtmosphere = null

var actividad_horaria: String = "explorar"
var _brillo_horario_activo: bool = false


func configurar_dependencias(
	nuevo_jugador: Node,
	nuevo_entity_manager: WorldEntityManager,
	nuevo_inventory: GarliaInventory,
	nuevo_combat_system: CombatSystem,
	nuevo_world_items: GarliaWorldItems,
	nuevas_relaciones_ecologicas: Array = [],
	nuevo_world_atmosphere: WorldAtmosphere = null
) -> void:
	jugador = nuevo_jugador as Node2D
	entity_manager = nuevo_entity_manager
	inventory = nuevo_inventory
	combat_system = nuevo_combat_system
	world_items = nuevo_world_items
	world_atmosphere = nuevo_world_atmosphere
	relaciones_ecologicas = nuevas_relaciones_ecologicas.duplicate(true)




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
var objeto_robado: Dictionary = {}


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
	_aplicar_configuracion_movimiento()
	_cambiar_estado_forzado(estado_inicial)


func configurar_relaciones_ecologicas(nuevas_relaciones_ecologicas: Array) -> void:
	relaciones_ecologicas = nuevas_relaciones_ecologicas.duplicate(true)


func configurar_criatura() -> void:
	_refrescar_configuracion()
	_aplicar_configuracion_movimiento()

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

	_actualizar_rutina()

	if actividad_horaria in ["dormir", "reposar"]:
		criatura.detener_movimiento()
		criatura.tomar_control_movimiento()
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

	if actividad_horaria == "proteger":
		_procesar_proteccion(delta)
		return

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
	if perfil == Perfil.LIGNIANOS and not _movimiento_permitido():
		criatura.detener_movimiento()
		criatura.tomar_control_movimiento()

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
	elif perfil != Perfil.LIGNIANOS or _movimiento_permitido():
		criatura.liberar_control_movimiento()


func _procesar_investigando() -> void:
	if perfil == Perfil.LIGNIANOS and not _movimiento_permitido():
		criatura.detener_movimiento()
		criatura.tomar_control_movimiento()

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

	if _es_objetivo_refugio() and criatura.global_position.distance_to(objetivo.global_position) <= 28.0:
		criatura.detener_movimiento()
		criatura.tomar_control_movimiento()
		return

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

	if distancia <= _obtener_distancia_contacto():
		_cambiar_estado(Estado.ATACANDO)


func _procesar_atacando(delta: float) -> void:
	match perfil:
		Perfil.DRAMARIAS:			_procesar_ataque_dramarias()
		Perfil.FLAXIS:
			_procesar_ataque_flaxis(delta)

		Perfil.LIGNIANOS:
			_procesar_ataque_lignianos()

		Perfil.CAMBIAFORMAS:
			_procesar_ataque_cambiaformas()

		Perfil.ESPIRITU_ESTELAR:
			_procesar_ataque_contacto(
				delta,
				_obtener_danio_ataque(),
				_obtener_enfriamiento_ataque(),
				false
			)

		Perfil.RANCRODEEN:
			_procesar_ataque_rancrodeen(delta)

		Perfil.GUARDIAN:
			_procesar_ataque_contacto(
				delta,
				_obtener_danio_ataque(),
				_obtener_enfriamiento_ataque(),
				false
			)

		Perfil.CAZADOR:
			_procesar_ataque_contacto(
				delta,
				_obtener_danio_ataque(),
				_obtener_enfriamiento_ataque(),
				false
			)

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


func _obtener_candidatos_entidad() -> Array[Node2D]:
	var candidatos: Array[Node2D] = []
	if jugador != null and is_instance_valid(jugador) and jugador.is_inside_tree():
		candidatos.append(jugador)

	if entity_manager == null or not is_instance_valid(entity_manager):
		return candidatos
	for entidad_variant in entity_manager.obtener_entidades_activas():
		if not entidad_variant is Node2D:
			continue
		var entidad := entidad_variant as Node2D
		if entidad == criatura or not is_instance_valid(entidad):
			continue
		if not entidad.is_inside_tree() or not entidad is Entity:
			continue
		if not entidad in candidatos:
			candidatos.append(entidad)

	return candidatos


func _refrescar_objetivo() -> void:
	if actividad_horaria == "proteger":
		objetivo = _buscar_amenaza_para_refugio()
		return

	if _debe_buscar_refugio():
		var refugio := _buscar_refugio()
		if refugio != null:
			objetivo = refugio
			return

	var candidatos: Array[Node2D] = []
	for candidato in _obtener_candidatos_entidad():
		if candidato == jugador:
			candidatos.append(candidato)
			continue
		if _es_objetivo_permitido(candidato):
			candidatos.append(candidato)

	var mejor: Node2D = null
	var mejor_distancia: float = INF
	for candidato in candidatos:
		if "is_alive" in candidato and not bool(candidato.get("is_alive")):
			continue
		var distancia := criatura.global_position.distance_to(candidato.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = candidato
	objetivo = mejor


func _es_objetivo_permitido(candidato: Node2D) -> bool:
	var objetivos := str(
		configuracion_ia.get("objetivos", "")
	).strip_edges().to_lower()

	match objetivos:
		"todo":
			return true
		"presa":
			return _es_objetivo_ecologico_valido(candidato)
		_:
			return _es_objetivo_ecologico_valido(candidato)


func _es_objetivo_ecologico_valido(candidato: Node2D) -> bool:
	if candidato is Creature:
		var tipo_relacion := _obtener_relacion_ecologica(
			candidato as Creature
		)

		return tipo_relacion in [
			"depredacion",
			"parasitismo"
		]

	return false


func _obtener_relacion_ecologica(
	candidato: Creature
) -> String:
	if criatura == null or candidato == null:
		return ""

	var origen_id := criatura.criatura_id
	var destino_id := candidato.criatura_id

	if origen_id.is_empty() or destino_id.is_empty():
		return ""

	var ecosistema_id := str(
		criatura.datos.get("ecosistema_id", "")
	)

	var mejor_tipo := ""
	var mejor_prioridad := -1

	for relacion_variant in relaciones_ecologicas:
		if not relacion_variant is Dictionary:
			continue

		var relacion := relacion_variant as Dictionary

		if str(relacion.get("criatura_origen_id", "")) != origen_id:
			continue
		if str(relacion.get("criatura_destino_id", "")) != destino_id:
			continue

		var relacion_ecosistema := str(
			relacion.get("ecosistema_id", "")
		)

		var prioridad := 0
		if not ecosistema_id.is_empty() and relacion_ecosistema == ecosistema_id:
			prioridad = 2
		elif relacion_ecosistema.is_empty():
			prioridad = 1
		else:
			continue

		if prioridad > mejor_prioridad:
			mejor_prioridad = prioridad
			mejor_tipo = str(
				relacion.get("tipo_relacion", "")
			).strip_edges().to_lower()

	return mejor_tipo



func _al_recibir_relaciones_ecologicas(
	relaciones: Array
) -> void:
	relaciones_ecologicas = relaciones.duplicate(true)


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
		perfil = Perfil.GENERICO
		return

	perfil = _perfil_desde_texto(comportamiento)


func _perfil_desde_texto(texto: String) -> Perfil:
	match texto:
		"dramarias":
			return Perfil.DRAMARIAS
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
		"guardian":
			return Perfil.GUARDIAN
		"cazador":
			return Perfil.CAZADOR

	return Perfil.GENERICO


func _obtener_respuesta_a_objetivo() -> String:
	if _es_objetivo_refugio():
		return "perseguir"

	if objetivo is Creature:
		var relacion := _obtener_relacion_ecologica(
			objetivo as Creature
		)

		match relacion:
			"depredacion", "parasitismo":
				return "atacar"

			_:
				pass

	match perfil:
		Perfil.DRAMARIAS:
			return "atacar"

		Perfil.ZLISH:
			return "huir"

		Perfil.FLAXIS:
			return "atacar"

		Perfil.LIGNIANOS:
			return "atacar"

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



# ============================================================
# RUTINAS Y RELOJ BIOLÓGICO
# ============================================================

func _actualizar_rutina() -> void:
	var horario_variant: Variant = configuracion_ia.get("horario", {})
	if not horario_variant is Dictionary:
		actividad_horaria = "explorar"
		_actualizar_atraccion_refugio(false)
		return

	var horario := horario_variant as Dictionary
	var actividad_por_defecto := str(horario.get("actividad_por_defecto", "explorar")).strip_edges().to_lower()
	actividad_horaria = actividad_por_defecto if not actividad_por_defecto.is_empty() else "explorar"

	if world_atmosphere != null and is_instance_valid(world_atmosphere):
		var tiempo := world_atmosphere.obtener_tiempo()
		var hora := float(tiempo.get("hora_del_dia", 0.0))
		var bloques_variant: Variant = horario.get("bloques", [])
		if bloques_variant is Array:
			for bloque_variant in bloques_variant as Array:
				if not bloque_variant is Dictionary:
					continue
				var bloque := bloque_variant as Dictionary
				var inicio := clampf(float(bloque.get("inicio", 0.0)), 0.0, 24.0)
				var fin := clampf(float(bloque.get("fin", 24.0)), 0.0, 24.0)
				if _hora_en_bloque(hora, inicio, fin):
					actividad_horaria = str(bloque.get("actividad", actividad_horaria)).strip_edges().to_lower()
					break

	criatura.set_meta("actividad_horaria", actividad_horaria)
	_actualizar_atraccion_refugio(actividad_horaria in ["proteger", "atraer"])


func _hora_en_bloque(hora: float, inicio: float, fin: float) -> bool:
	if is_equal_approx(inicio, fin):
		return true
	if inicio < fin:
		return hora >= inicio and hora < fin
	return hora >= inicio or hora < fin

func _debe_buscar_refugio() -> bool:
	var horario_variant: Variant = configuracion_ia.get("horario", {})
	if not horario_variant is Dictionary:
		return false
	var horario := horario_variant as Dictionary
	return bool(horario.get("buscar_refugio", false)) and actividad_horaria not in ["dormir", "reposar", "cazar"]


func _es_objetivo_refugio() -> bool:
	if objetivo == null or not is_instance_valid(objetivo) or not objetivo is Creature:
		return false
	return bool((objetivo as Creature).get_meta("atractor_refugio", false))


func _buscar_refugio() -> Creature:
	# Durante el descanso nocturno, Zlish y Feerin buscan a los
	# Lignianos como refugio social/ecológico.
	if _es_refugio_ligniano():
		return _buscar_criatura_por_nombre("Lignianos")
func _es_refugio_ligniano() -> bool:
	var nombre := str(criatura.datos.get("nombre", "")).strip_edges().to_lower()
	if nombre not in ["zlish", "feerín", "feerin"]:
		return false
	return actividad_horaria in ["dormir", "reposar", "buscar_refugio"]


func _buscar_criatura_por_nombre(nombre_buscado: String) -> Creature:
	if entity_manager == null or not is_instance_valid(entity_manager):
		return null
	var mejor: Creature = null
	var mejor_distancia := INF
	var radio := 180.0
	var horario_variant: Variant = configuracion_ia.get("horario", {})
	if horario_variant is Dictionary:
		radio = maxf(float((horario_variant as Dictionary).get("radio_refugio", 180.0)), 1.0)

	for entidad_variant in entity_manager.obtener_entidades_activas():
		if not entidad_variant is Creature:
			continue
		var candidata := entidad_variant as Creature
		if candidata == criatura or not candidata.is_alive:
			continue
		var nombre := str(candidata.datos.get("nombre", "")).strip_edges().to_lower()
		if nombre != nombre_buscado.strip_edges().to_lower():
			continue
		var distancia := criatura.global_position.distance_to(candidata.global_position)
		if distancia <= radio and distancia < mejor_distancia:
			mejor = candidata
			mejor_distancia = distancia
	return mejor



	if entity_manager == null or not is_instance_valid(entity_manager):
		return null
	var horario_variant: Variant = configuracion_ia.get("horario", {})
	var radio := 180.0
	if horario_variant is Dictionary:
		radio = maxf(float((horario_variant as Dictionary).get("radio_refugio", 180.0)), 1.0)

	var mejor: Creature = null
	var mejor_distancia := INF
	for entidad_variant in entity_manager.obtener_entidades_activas():
		if not entidad_variant is Creature:
			continue
		var candidata := entidad_variant as Creature
		if candidata == criatura or not is_instance_valid(candidata) or not candidata.is_alive:
			continue
		if not bool(candidata.get_meta("atractor_refugio", false)):
			continue
		var distancia := criatura.global_position.distance_to(candidata.global_position)
		if distancia <= radio and distancia < mejor_distancia:
			mejor = candidata
			mejor_distancia = distancia
	return mejor


func _buscar_amenaza_para_refugio() -> Creature:
	if entity_manager == null or not is_instance_valid(entity_manager):
		return null
	var horario_variant: Variant = configuracion_ia.get("horario", {})
	var radio := 180.0
	if horario_variant is Dictionary:
		radio = maxf(float((horario_variant as Dictionary).get("radio_proteccion", 180.0)), 1.0)

	var criaturas_activas: Array[Creature] = []
	for entidad_variant in entity_manager.obtener_entidades_activas():
		if entidad_variant is Creature:
			var candidata := entidad_variant as Creature
			if candidata != criatura and is_instance_valid(candidata) and candidata.is_alive:
				criaturas_activas.append(candidata)

	var mejor: Creature = null
	var mejor_distancia := INF
	for presa in criaturas_activas:
		if criatura.global_position.distance_to(presa.global_position) > radio:
			continue
		for depredador in criaturas_activas:
			if depredador == presa:
				continue
			var actividad_depredador := str(
				depredador.get_meta("actividad_horaria", "explorar")
			).to_lower()
			if actividad_depredador in ["dormir", "reposar"]:
				continue
			if _es_cazador_por_configuracion(depredador):
				var distancia_cazador := depredador.global_position.distance_to(presa.global_position)
				if distancia_cazador <= radio and distancia_cazador < mejor_distancia:
					mejor = depredador
					mejor_distancia = distancia_cazador
				continue
			if depredador.global_position.distance_to(presa.global_position) > radio:
				continue
			if _obtener_relacion_ecologica_ids(depredador, presa) not in ["depredacion", "parasitismo"]:
				continue
			var distancia := depredador.global_position.distance_to(presa.global_position)
			if distancia < mejor_distancia:
				mejor = depredador
				mejor_distancia = distancia
	return mejor


func _obtener_relacion_ecologica_ids(origen: Creature, destino: Creature) -> String:
	if origen == null or destino == null:
		return ""
	var origen_id := origen.criatura_id
	var destino_id := destino.criatura_id
	if origen_id.is_empty() or destino_id.is_empty():
		return ""
	var ecosistema_id := str(origen.datos.get("ecosistema_id", ""))
	var mejor_tipo := ""
	var mejor_prioridad := -1
	for relacion_variant in relaciones_ecologicas:
		if not relacion_variant is Dictionary:
			continue
		var relacion := relacion_variant as Dictionary
		if str(relacion.get("criatura_origen_id", "")) != origen_id:
			continue
		if str(relacion.get("criatura_destino_id", "")) != destino_id:
			continue
		var relacion_ecosistema := str(relacion.get("ecosistema_id", ""))
		var prioridad := 0
		if not ecosistema_id.is_empty() and relacion_ecosistema == ecosistema_id:
			prioridad = 2
		elif relacion_ecosistema.is_empty():
			prioridad = 1
		else:
			continue
		if prioridad > mejor_prioridad:
			mejor_prioridad = prioridad
			mejor_tipo = str(relacion.get("tipo_relacion", "")).strip_edges().to_lower()
	return mejor_tipo



func _es_cazador_por_configuracion(candidato: Creature) -> bool:
	if candidato == null:
		return false

	var config := candidato.obtener_config_ia()
	if config.is_empty():
		return false

	var perfil_texto := str(config.get("perfil", "")).strip_edges().to_lower()
	if perfil_texto in ["cazador", "flaxis"]:
		return true

	var objetivos := str(config.get("objetivos", "")).strip_edges().to_lower()
	return objetivos == "presa"


func _procesar_proteccion(delta: float) -> void:
	criatura.detener_movimiento()
	var amenaza := _buscar_amenaza_para_refugio()
	if amenaza == null:
		objetivo = null
		objetivo_detectado = false
		return
	objetivo = amenaza
	objetivo_detectado = true
	ultima_posicion_objetivo = amenaza.global_position
	var distancia := criatura.global_position.distance_to(amenaza.global_position)
	if distancia <= _obtener_distancia_contacto():
		_procesar_atacando(delta)
	else:
		_establecer_velocidad(_obtener_velocidad_persecucion())
		criatura.tomar_control_movimiento()
		criatura.establecer_direccion_movimiento(criatura.global_position.direction_to(amenaza.global_position))


func _actualizar_atraccion_refugio(activa: bool) -> void:
	if criatura == null or not is_instance_valid(criatura):
		return
	criatura.set_meta("atractor_refugio", activa)
	criatura.set_meta("brillo_horario", activa)
	if _brillo_horario_activo != activa:
		_brillo_horario_activo = activa
		criatura.modulate = Color(1.0, 0.92, 0.55) if activa else Color.WHITE


func _obtener_config_movimiento() -> Dictionary:
	var valor: Variant = configuracion_ia.get(
		"movimiento",
		{}
	)

	if valor is Dictionary:
		return valor as Dictionary

	return {}


func _obtener_float_movimiento(
	clave: String,
	por_defecto: float
) -> float:
	var movimiento := _obtener_config_movimiento()
	var valor: Variant = movimiento.get(
		clave,
		por_defecto
	)

	if valor is int or valor is float:
		return maxf(float(valor), 0.0)

	return por_defecto


func _aplicar_configuracion_movimiento() -> void:
	if _movimiento == null:
		_encontrar_movimiento()

	if _movimiento == null:
		return

	var movimiento := _obtener_config_movimiento()

	if movimiento.is_empty():
		_velocidad_normal = maxf(
			_movimiento.move_speed,
			0.0
		)
		return

	_velocidad_normal = _obtener_float_movimiento(
		"velocidad",
		_movimiento.move_speed
	)

	_movimiento.move_speed = _velocidad_normal
	_movimiento.min_move_time = _obtener_float_movimiento(
		"exploracion_min",
		_movimiento.min_move_time
	)
	_movimiento.max_move_time = maxf(
		_obtener_float_movimiento(
			"exploracion_max",
			_movimiento.max_move_time
		),
		_movimiento.min_move_time
	)


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


func _obtener_enfriamiento_ataque() -> float:	var ataque := _obtener_config_ataque()
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


func _movimiento_permitido() -> bool:
	var valor: Variant = configuracion_ia.get(
		"movimiento_permitido",
		true
	)

	if valor is bool:
		return bool(valor)

	return true


func _obtener_distancia_maxima_persecucion() -> float:
	if perfil == Perfil.LIGNIANOS:
		var distancia_lignianos: Variant = _obtener_config_ataque().get("distancia_maxima_persecucion", null)
		if distancia_lignianos is int or distancia_lignianos is float:
			return maxf(float(distancia_lignianos), 0.0)
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

		Perfil.CAMBIAFORMAS:
			criatura.tomar_control_movimiento()
			_establecer_velocidad(
				_obtener_velocidad_ataque()
			)

		Perfil.ESPIRITU_ESTELAR:
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

	if distancia > _obtener_distancia_contacto():
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

	_aplicar_danio_objetivo(objetivo, danio, "CreatureAI/Contacto")

	if copiar_skin:
		criatura.copiar_skin_de(objetivo)

	_iniciar_recuperacion(enfriamiento)


func _obtener_velocidad_ataque() -> float:
	return _obtener_velocidad_persecucion()


func _iniciar_ataque_generico_contacto() -> void:
	_cambiar_estado(Estado.ATACANDO)


func _obtener_distancia_ataque_dramarias() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"distancia_ataque",
		dramarias_distancia_ataque
	)

	if valor is int or valor is float:
		return maxf(float(valor), 1.0)

	return dramarias_distancia_ataque


func _obtener_danio_dramarias() -> int:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"danio",
		dramarias_dano_contacto
	)

	if valor is int or valor is float:
		return maxi(int(valor), 0)

	return dramarias_dano_contacto


func _obtener_distancia_contacto() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"distancia_contacto",
		distancia_contacto
	)

	if perfil == Perfil.DRAMARIAS:
		valor = ataque.get(
			"distancia_ataque",
			valor
		)

	if valor is int or valor is float:
		return maxf(float(valor), 1.0)

	return distancia_contacto


func _obtener_enfriamiento_fallido() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"enfriamiento_fallido",
		enfriamiento_fallido
	)

	if valor is int or valor is float:
		return maxf(float(valor), 0.0)

	return enfriamiento_fallido


func _obtener_enfriamiento_dramarias() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"enfriamiento",
		dramarias_enfriamiento
	)

	if valor is int or valor is float:
		return maxf(float(valor), 0.0)

	return dramarias_enfriamiento


# ============================================================
# DRAMARIAS
# ============================================================

func _procesar_ataque_dramarias() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	var distancia := criatura.global_position.distance_to(
		objetivo.global_position
	)
	var alcance := _obtener_distancia_ataque_dramarias()

	if distancia > alcance:
		_establecer_velocidad(_obtener_velocidad_persecucion())
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

	_aplicar_danio_objetivo(
		objetivo,
		_obtener_danio_dramarias(),
		"CreatureAI/Dramarias"
	)

	_iniciar_recuperacion(_obtener_enfriamiento_dramarias())


# ============================================================
# FLAXIS
# ============================================================

func _iniciar_ataque_flaxis() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	_tiempo_accion = maxf(
		_obtener_float_movimiento("duracion_lanzamiento", duracion_lanzamiento),
		0.01
	)

	_objetivo_ataque = objetivo.global_position
	ultima_posicion_objetivo = _objetivo_ataque

	criatura.tomar_control_movimiento()
	_establecer_velocidad(
		_obtener_float_movimiento("velocidad_lanzamiento", velocidad_lanzamiento)
	)

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

	if distancia_punto <= _obtener_distancia_contacto():
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

	if objetivo != null and is_instance_valid(objetivo):
		var distancia_impacto := criatura.global_position.distance_to(
			objetivo.global_position
		)

		if distancia_impacto <= _obtener_distancia_contacto():
			_aplicar_danio_objetivo(
				objetivo,
				_obtener_danio_ataque(),
				"CreatureAI/Flaxis"
			)

			_iniciar_recuperacion(_obtener_enfriamiento_ataque())
			return

	_iniciar_recuperacion(_obtener_enfriamiento_fallido())


# ============================================================
# LIGNIANOS
# ============================================================

func _iniciar_ataque_ligniano() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	criatura.detener_movimiento()
	criatura.tomar_control_movimiento()

	var distancia: float = criatura.global_position.distance_to(
		objetivo.global_position
	)

	if distancia > _obtener_distancia_contacto():
		_iniciar_recuperacion(
			_obtener_float_ataque(
				"enfriamiento",
				ligniano_enfriamiento
			)
		)
		return

	if _puede_recibir_danio(objetivo):
		_aplicar_danio_objetivo(
			objetivo,
			_obtener_danio_ataque(),
			"CreatureAI/Lignianos"
		)

		var jugador_objetivo := objetivo as Player
		if jugador_objetivo != null:
			jugador_objetivo.aplicar_efecto_slow(
				_obtener_float_ataque(
					"duracion_slow",
					ligniano_duracion_slow
				)
			)

	_iniciar_recuperacion(
		_obtener_float_ataque(
			"enfriamiento",
			ligniano_enfriamiento
		)
	)


func _procesar_ataque_lignianos() -> void:
	if not _ataque_resuelto:
		_ataque_resuelto = true

	_cambiar_estado(Estado.RECUPERANDO)


# ============================================================
# CAMBIAFORMAS
# ============================================================

func _procesar_ataque_cambiaformas() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	if _ataque_resuelto:
		return

	var arma: Dictionary = _obtener_arma_cambiaformas()

	if arma.is_empty():
		_iniciar_recuperacion(_obtener_enfriamiento_ataque())
		return

	var alcance: float = _obtener_alcance_arma_combate(arma)
	var distancia: float = criatura.global_position.distance_to(
		objetivo.global_position
	)

	if distancia > alcance:
		criatura.tomar_control_movimiento()
		_establecer_velocidad(
			_obtener_velocidad_ataque()
		)

		var direccion: Vector2 = criatura.global_position.direction_to(
			objetivo.global_position
		)

		criatura.establecer_direccion_movimiento(direccion)
		return

	_ataque_resuelto = true
	criatura.detener_movimiento()

	var combate: CombatSystem = _obtener_combat_system()

	if combate == null:
		_iniciar_recuperacion(_obtener_enfriamiento_ataque())
		return

	var ataque_realizado: bool = combate.atacar_objetivo_con_arma(
		criatura,
		objetivo,
		arma
	)

	if ataque_realizado and _copiar_skin_configurado():
		criatura.copiar_skin_de(objetivo)
		criatura.ocultar_nombre_debug()

	_iniciar_recuperacion(_obtener_enfriamiento_ataque())


func _obtener_arma_cambiaformas() -> Dictionary:
	var ataque: Dictionary = _obtener_config_ataque()

	var tipo: String = str(
		ataque.get("tipo", "")	).strip_edges().to_lower()

	if tipo != "arma":
		return {}

	var item_id: String = str(
		ataque.get("item_id", "")
	).strip_edges()

	if item_id.is_empty():
		return {}

	if world_items != null and is_instance_valid(world_items):
		var item: Dictionary = world_items.buscar_item_por_id(item_id)

		if not item.is_empty():
			return item

	return {
		"item_id": item_id,
		"tipo": "arma"
	}


func _copiar_skin_configurado() -> bool:
	var reaccion_variant: Variant = configuracion_ia.get(
		"al_golpear",
		{}
	)

	if not reaccion_variant is Dictionary:
	if entity_manager == null or not is_instance_valid(entity_manager):
		return null
	var horario_variant: Variant = configuracion_ia.get("horario", {})
	var radio := 180.0
	if horario_variant is Dictionary:
		radio = maxf(float((horario_variant as Dictionary).get("radio_refugio", 180.0)), 1.0)

	var mejor: Creature = null
	var mejor_distancia := INF
	for entidad_variant in entity_manager.obtener_entidades_activas():
		if not entidad_variant is Creature:
			continue
		var candidata := entidad_variant as Creature
		if candidata == criatura or not is_instance_valid(candidata) or not candidata.is_alive:
			continue
		if not bool(candidata.get_meta("atractor_refugio", false)):
			continue
		var distancia := criatura.global_position.distance_to(candidata.global_position)
		if distancia <= radio and distancia < mejor_distancia:
			mejor = candidata
			mejor_distancia = distancia
	return mejor


func _buscar_amenaza_para_refugio() -> Creature:
	if entity_manager == null or not is_instance_valid(entity_manager):
		return null
	var horario_variant: Variant = configuracion_ia.get("horario", {})
	var radio := 180.0
	if horario_variant is Dictionary:
		radio = maxf(float((horario_variant as Dictionary).get("radio_proteccion", 180.0)), 1.0)

	var criaturas_activas: Array[Creature] = []
	for entidad_variant in entity_manager.obtener_entidades_activas():
		if entidad_variant is Creature:
			var candidata := entidad_variant as Creature
			if candidata != criatura and is_instance_valid(candidata) and candidata.is_alive:
				criaturas_activas.append(candidata)

	var mejor: Creature = null
	var mejor_distancia := INF
	for presa in criaturas_activas:
		if criatura.global_position.distance_to(presa.global_position) > radio:
			continue
		for depredador in criaturas_activas:
			if depredador == presa:
				continue
			var actividad_depredador := str(
				depredador.get_meta("actividad_horaria", "explorar")
			).to_lower()
			if actividad_depredador in ["dormir", "reposar"]:
				continue
			if _es_cazador_por_configuracion(depredador):
				var distancia_cazador := depredador.global_position.distance_to(presa.global_position)
				if distancia_cazador <= radio and distancia_cazador < mejor_distancia:
					mejor = depredador
					mejor_distancia = distancia_cazador
				continue
			if depredador.global_position.distance_to(presa.global_position) > radio:
				continue
			if _obtener_relacion_ecologica_ids(depredador, presa) not in ["depredacion", "parasitismo"]:
				continue
			var distancia := depredador.global_position.distance_to(presa.global_position)
			if distancia < mejor_distancia:
				mejor = depredador
				mejor_distancia = distancia
	return mejor


func _obtener_relacion_ecologica_ids(origen: Creature, destino: Creature) -> String:
	if origen == null or destino == null:
		return ""
	var origen_id := origen.criatura_id
	var destino_id := destino.criatura_id
	if origen_id.is_empty() or destino_id.is_empty():
		return ""
	var ecosistema_id := str(origen.datos.get("ecosistema_id", ""))
	var mejor_tipo := ""
	var mejor_prioridad := -1
	for relacion_variant in relaciones_ecologicas:
		if not relacion_variant is Dictionary:
			continue
		var relacion := relacion_variant as Dictionary
		if str(relacion.get("criatura_origen_id", "")) != origen_id:
			continue
		if str(relacion.get("criatura_destino_id", "")) != destino_id:
			continue
		var relacion_ecosistema := str(relacion.get("ecosistema_id", ""))
		var prioridad := 0
		if not ecosistema_id.is_empty() and relacion_ecosistema == ecosistema_id:
			prioridad = 2
		elif relacion_ecosistema.is_empty():
			prioridad = 1
		else:
			continue
		if prioridad > mejor_prioridad:
			mejor_prioridad = prioridad
			mejor_tipo = str(relacion.get("tipo_relacion", "")).strip_edges().to_lower()
	return mejor_tipo



func _es_cazador_por_configuracion(candidato: Creature) -> bool:
	if candidato == null:
		return false

	var config := candidato.obtener_config_ia()
	if config.is_empty():
		return false

	var perfil_texto := str(config.get("perfil", "")).strip_edges().to_lower()
	if perfil_texto in ["cazador", "flaxis"]:
		return true

	var objetivos := str(config.get("objetivos", "")).strip_edges().to_lower()
	return objetivos == "presa"


func _procesar_proteccion(delta: float) -> void:
	criatura.detener_movimiento()
	var amenaza := _buscar_amenaza_para_refugio()
	if amenaza == null:
		objetivo = null
		objetivo_detectado = false
		return
	objetivo = amenaza
	objetivo_detectado = true
	ultima_posicion_objetivo = amenaza.global_position
	var distancia := criatura.global_position.distance_to(amenaza.global_position)
	if distancia <= _obtener_distancia_contacto():
		_procesar_atacando(delta)
	else:
		_establecer_velocidad(_obtener_velocidad_persecucion())
		criatura.tomar_control_movimiento()
		criatura.establecer_direccion_movimiento(criatura.global_position.direction_to(amenaza.global_position))


func _actualizar_atraccion_refugio(activa: bool) -> void:
	if criatura == null or not is_instance_valid(criatura):
		return
	criatura.set_meta("atractor_refugio", activa)
	criatura.set_meta("brillo_horario", activa)
	if _brillo_horario_activo != activa:
		_brillo_horario_activo = activa
		criatura.modulate = Color(1.0, 0.92, 0.55) if activa else Color.WHITE


func _obtener_config_movimiento() -> Dictionary:
	var valor: Variant = configuracion_ia.get(
		"movimiento",
		{}
	)

	if valor is Dictionary:
		return valor as Dictionary

	return {}


func _obtener_float_movimiento(
	clave: String,
	por_defecto: float
) -> float:
	var movimiento := _obtener_config_movimiento()
	var valor: Variant = movimiento.get(
		clave,
		por_defecto
	)

	if valor is int or valor is float:
		return maxf(float(valor), 0.0)

	return por_defecto


func _aplicar_configuracion_movimiento() -> void:
	if _movimiento == null:
		_encontrar_movimiento()

	if _movimiento == null:
		return

	var movimiento := _obtener_config_movimiento()

	if movimiento.is_empty():
		_velocidad_normal = maxf(
			_movimiento.move_speed,
			0.0
		)
		return

	_velocidad_normal = _obtener_float_movimiento(
		"velocidad",
		_movimiento.move_speed
	)

	_movimiento.move_speed = _velocidad_normal
	_movimiento.min_move_time = _obtener_float_movimiento(
		"exploracion_min",
		_movimiento.min_move_time
	)
	_movimiento.max_move_time = maxf(
		_obtener_float_movimiento(
			"exploracion_max",
			_movimiento.max_move_time
		),
		_movimiento.min_move_time
	)


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


func _obtener_enfriamiento_ataque() -> float:	var ataque := _obtener_config_ataque()
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


func _movimiento_permitido() -> bool:
	var valor: Variant = configuracion_ia.get(
		"movimiento_permitido",
		true
	)

	if valor is bool:
		return bool(valor)

	return true


func _obtener_distancia_maxima_persecucion() -> float:
	if perfil == Perfil.LIGNIANOS:
		var distancia_lignianos: Variant = _obtener_config_ataque().get("distancia_maxima_persecucion", null)
		if distancia_lignianos is int or distancia_lignianos is float:
			return maxf(float(distancia_lignianos), 0.0)
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

		Perfil.CAMBIAFORMAS:
			criatura.tomar_control_movimiento()
			_establecer_velocidad(
				_obtener_velocidad_ataque()
			)

		Perfil.ESPIRITU_ESTELAR:
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

	if distancia > _obtener_distancia_contacto():
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

	_aplicar_danio_objetivo(objetivo, danio, "CreatureAI/Contacto")

	if copiar_skin:
		criatura.copiar_skin_de(objetivo)

	_iniciar_recuperacion(enfriamiento)


func _obtener_velocidad_ataque() -> float:
	return _obtener_velocidad_persecucion()


func _iniciar_ataque_generico_contacto() -> void:
	_cambiar_estado(Estado.ATACANDO)


func _obtener_distancia_ataque_dramarias() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"distancia_ataque",
		dramarias_distancia_ataque
	)

	if valor is int or valor is float:
		return maxf(float(valor), 1.0)

	return dramarias_distancia_ataque


func _obtener_danio_dramarias() -> int:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"danio",
		dramarias_dano_contacto
	)

	if valor is int or valor is float:
		return maxi(int(valor), 0)

	return dramarias_dano_contacto


func _obtener_distancia_contacto() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"distancia_contacto",
		distancia_contacto
	)

	if perfil == Perfil.DRAMARIAS:
		valor = ataque.get(
			"distancia_ataque",
			valor
		)

	if valor is int or valor is float:
		return maxf(float(valor), 1.0)

	return distancia_contacto


func _obtener_enfriamiento_fallido() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"enfriamiento_fallido",
		enfriamiento_fallido
	)

	if valor is int or valor is float:
		return maxf(float(valor), 0.0)

	return enfriamiento_fallido


func _obtener_enfriamiento_dramarias() -> float:
	var ataque := _obtener_config_ataque()
	var valor: Variant = ataque.get(
		"enfriamiento",
		dramarias_enfriamiento
	)

	if valor is int or valor is float:
		return maxf(float(valor), 0.0)

	return dramarias_enfriamiento


# ============================================================
# DRAMARIAS
# ============================================================

func _procesar_ataque_dramarias() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	var distancia := criatura.global_position.distance_to(
		objetivo.global_position
	)
	var alcance := _obtener_distancia_ataque_dramarias()

	if distancia > alcance:
		_establecer_velocidad(_obtener_velocidad_persecucion())
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

	_aplicar_danio_objetivo(
		objetivo,
		_obtener_danio_dramarias(),
		"CreatureAI/Dramarias"
	)

	_iniciar_recuperacion(_obtener_enfriamiento_dramarias())


# ============================================================
# FLAXIS
# ============================================================

func _iniciar_ataque_flaxis() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	_tiempo_accion = maxf(
		_obtener_float_movimiento("duracion_lanzamiento", duracion_lanzamiento),
		0.01
	)

	_objetivo_ataque = objetivo.global_position
	ultima_posicion_objetivo = _objetivo_ataque

	criatura.tomar_control_movimiento()
	_establecer_velocidad(
		_obtener_float_movimiento("velocidad_lanzamiento", velocidad_lanzamiento)
	)

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

	if distancia_punto <= _obtener_distancia_contacto():
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

	if objetivo != null and is_instance_valid(objetivo):
		var distancia_impacto := criatura.global_position.distance_to(
			objetivo.global_position
		)

		if distancia_impacto <= _obtener_distancia_contacto():
			_aplicar_danio_objetivo(
				objetivo,
				_obtener_danio_ataque(),
				"CreatureAI/Flaxis"
			)

			_iniciar_recuperacion(_obtener_enfriamiento_ataque())
			return

	_iniciar_recuperacion(_obtener_enfriamiento_fallido())


# ============================================================
# LIGNIANOS
# ============================================================

func _iniciar_ataque_ligniano() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	criatura.detener_movimiento()
	criatura.tomar_control_movimiento()

	var distancia: float = criatura.global_position.distance_to(
		objetivo.global_position
	)

	if distancia > _obtener_distancia_contacto():
		_iniciar_recuperacion(
			_obtener_float_ataque(
				"enfriamiento",
				ligniano_enfriamiento
			)
		)
		return

	if _puede_recibir_danio(objetivo):
		_aplicar_danio_objetivo(
			objetivo,
			_obtener_danio_ataque(),
			"CreatureAI/Lignianos"
		)

		var jugador_objetivo := objetivo as Player
		if jugador_objetivo != null:
			jugador_objetivo.aplicar_efecto_slow(
				_obtener_float_ataque(
					"duracion_slow",
					ligniano_duracion_slow
				)
			)

	_iniciar_recuperacion(
		_obtener_float_ataque(
			"enfriamiento",
			ligniano_enfriamiento
		)
	)


func _procesar_ataque_lignianos() -> void:
	if not _ataque_resuelto:
		_ataque_resuelto = true

	_cambiar_estado(Estado.RECUPERANDO)


# ============================================================
# CAMBIAFORMAS
# ============================================================

func _procesar_ataque_cambiaformas() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		_cambiar_estado(Estado.EXPLORANDO)
		return

	if _ataque_resuelto:
		return

	var arma: Dictionary = _obtener_arma_cambiaformas()

	if arma.is_empty():
		_iniciar_recuperacion(_obtener_enfriamiento_ataque())
		return

	var alcance: float = _obtener_alcance_arma_combate(arma)
	var distancia: float = criatura.global_position.distance_to(
		objetivo.global_position
	)

	if distancia > alcance:
		criatura.tomar_control_movimiento()
		_establecer_velocidad(
			_obtener_velocidad_ataque()
		)

		var direccion: Vector2 = criatura.global_position.direction_to(
			objetivo.global_position
		)

		criatura.establecer_direccion_movimiento(direccion)
		return

	_ataque_resuelto = true
	criatura.detener_movimiento()

	var combate: CombatSystem = _obtener_combat_system()

	if combate == null:
		_iniciar_recuperacion(_obtener_enfriamiento_ataque())
		return

	var ataque_realizado: bool = combate.atacar_objetivo_con_arma(
		criatura,
		objetivo,
		arma
	)

	if ataque_realizado and _copiar_skin_configurado():
		criatura.copiar_skin_de(objetivo)
		criatura.ocultar_nombre_debug()

	_iniciar_recuperacion(_obtener_enfriamiento_ataque())


func _obtener_arma_cambiaformas() -> Dictionary:
	var ataque: Dictionary = _obtener_config_ataque()

	var tipo: String = str(
		ataque.get("tipo", "")	).strip_edges().to_lower()

	if tipo != "arma":
		return {}

	var item_id: String = str(
		ataque.get("item_id", "")
	).strip_edges()

	if item_id.is_empty():
		return {}

	if world_items != null and is_instance_valid(world_items):
		var item: Dictionary = world_items.buscar_item_por_id(item_id)

		if not item.is_empty():
			return item

	return {
		"item_id": item_id,
		"tipo": "arma"
	}


func _copiar_skin_configurado() -> bool:
	var reaccion_variant: Variant = configuracion_ia.get(
		"al_golpear",
		{}
	)

	if not reaccion_variant is Dictionary: