extends Node
class_name NPCScheduleSystem

const INTERVALO_ACTUALIZACION := 0.5
const TAMANO_CELDA := 32.0
const ORIGEN_MAPA := Vector2(-1152.0, -672.0)
const TAMANO_MALLA := Vector2i(72, 42)
const RADIO_COLISION_NPC := 14.0
const DISTANCIA_LLEGADA := 7.0

# Puntos de actividad en coordenadas locales de ReinoTorres.
# Se definen por ubicación, nunca por nombre de personaje.
const ENTRADAS_INTERIORES: Dictionary = {
	"panaderia": {"id": "panaderia", "pos": Vector2(-245.0, -117.0)},
	"forja": {"id": "forja", "pos": Vector2(-360.0, -159.0)},
	"cuartel": {"id": "cuartel", "pos": Vector2(730.0, -310.0)},
	"registro": {"id": "registro", "pos": Vector2(730.0, -210.0)},
	"casa_comercio": {"id": "casa_comercio", "pos": Vector2(930.0, -310.0)},
	"archivo_real": {"id": "archivo_real", "pos": Vector2(-170.0, -610.0)},
	"casa_estudio": {"id": "casa_estudio", "pos": Vector2(-410.0, -520.0)},
	"casa_elian": {"id": "casa_oriente_a", "pos": Vector2(220.0, -117.0)},
	"casa_bruna": {"id": "vivienda_mason", "pos": Vector2(-235.0, 193.0)},
	"casa_darven": {"id": "casa_oriente_b", "pos": Vector2(385.0, -108.0)},
	"casa_saira": {"id": "casa_oriente_c", "pos": Vector2(385.0, 173.0)},
	"casa_narel": {"id": "vivienda_oeste_09", "pos": Vector2(-520.0, -213.0)},
	"castillo": {"id": "castillo", "pos": Vector2(0.0, -125.0)}
}

const POSICIONES: Dictionary = {
	"plaza": Vector2(0.0, 0.0),
	"panaderia": Vector2(-205.0, -78.0),
	"forja": Vector2(-320.0, -122.0),
	"cuartel": Vector2(690.0, -248.0),
	"registro": Vector2(690.0, -170.0),
	"casa_comercio": Vector2(890.0, -260.0),
	"casa_estudio": Vector2(-370.0, -482.0),
	"archivo_real": Vector2(-130.0, -572.0),
	"casa_elian": Vector2(220.0, -117.0),
	"casa_bruna": Vector2(-235.0, 193.0),
	"casa_darven": Vector2(385.0, -108.0),
	"casa_saira": Vector2(385.0, 173.0),
	"casa_narel": Vector2(-520.0, -213.0),
	"castillo": Vector2(0.0, -125.0)
}

var _world_atmosphere: WorldAtmosphere = null
var _zone_manager: Node = null
var _zona: Node2D = null
var _malla: AStarGrid2D = null
var _malla_lista := false
var _construyendo_malla := false
var _tiempo_actualizacion := 0.0


func configurar(atmosfera: WorldAtmosphere, zone_manager: Node) -> void:
	_world_atmosphere = atmosfera
	_zone_manager = zone_manager
	add_to_group("npc_schedule_system")


static func tiene_ubicacion(clave: String) -> bool:
	return POSICIONES.has(clave.strip_edges().to_lower())


static func obtener_posicion_inicial(clave: String) -> Vector2:
	var buscada := clave.strip_edges().to_lower()
	var posicion: Variant = POSICIONES.get(buscada, POSICIONES["plaza"])
	if posicion is Vector2:
		return posicion
	return Vector2.ZERO


static func obtener_clave_hogar(nombre_npc: String, ubicacion_respaldo: String = "plaza") -> String:
	var clave := nombre_npc.strip_edges().to_lower()
	var hogares: Dictionary = {
		"elian": "casa_elian",
		"bruna": "casa_bruna",
		"darven": "casa_darven",
		"saira": "casa_saira",
		"narel": "casa_narel",
		"abel": "castillo",
		"liam": "castillo"
	}
	var ubicacion := str(hogares.get(clave, ubicacion_respaldo)).strip_edges().to_lower()
	return ubicacion if POSICIONES.has(ubicacion) else "plaza"


static func obtener_posicion_hogar(nombre_npc: String, ubicacion_respaldo: String = "plaza") -> Vector2:
	return obtener_posicion_inicial(obtener_clave_hogar(nombre_npc, ubicacion_respaldo))


func actualizar(delta: float = INTERVALO_ACTUALIZACION) -> void:
	_tiempo_actualizacion += delta
	if _tiempo_actualizacion < INTERVALO_ACTUALIZACION:
		return
	_tiempo_actualizacion = 0.0

	if not is_instance_valid(_zone_manager):
		return
	if str(_zone_manager.obtener_tipo_actual()) != "reino_torres":
		_invalidar_malla()
		return
	if not is_instance_valid(_world_atmosphere):
		return

	var zona_actual := _zone_manager.obtener_zona_actual() as Node2D
	if not is_instance_valid(zona_actual):
		return
	if zona_actual != _zona:
		_zona = zona_actual
		_malla = null
		_malla_lista = false
		_construyendo_malla = false
		call_deferred("_construir_malla", zona_actual)
		return
	if not _malla_lista or _malla == null:
		return

	var tiempo := _world_atmosphere.obtener_tiempo()
	if not bool(tiempo.get("calendario_cargado", false)):
		return

	var dia_semana := posmod(int(tiempo.get("dia", 1)) - 1, 5)
	var minutos := clampi(int(floor(float(tiempo.get("hora_del_dia", 0.0)) * 60.0)), 0, 1439)

	for npc_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not npc_variant is Creature or not is_instance_valid(npc_variant):
			continue
		var npc := npc_variant as Creature
		if _actualizar_actividad_social(npc, delta):
			continue
		# Los NPC exteriores pueden estar ocultos porque el jugador está dentro
		# de otro edificio. Sus horarios siguen avanzando en segundo plano.
		_aplicar_rutina(npc, dia_semana, minutos)


## Reserva temporalmente el movimiento de un NPC para que pueda acercarse
## al jugador usando la misma malla AStar de sus rutinas habituales.
func iniciar_acercamiento_social(npc: Creature, jugador: Node2D) -> bool:
	if not is_instance_valid(npc) or not is_instance_valid(jugador):
		return false
	if not _malla_lista or _malla == null:
		return false
	if bool(npc.get_meta("rutina_en_transito", false)) or bool(npc.get_meta("rutina_en_edificio", false)):
		return false
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		return false

	var hacia_npc := jugador.global_position.direction_to(npc.global_position)
	if hacia_npc.length_squared() <= 0.001:
		hacia_npc = Vector2.RIGHT
	var direcciones: Array[Vector2] = [
		hacia_npc,
		Vector2.RIGHT,
		Vector2.DOWN,
		Vector2.LEFT,
		Vector2.UP,
		Vector2(1.0, 1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(-1.0, -1.0).normalized(),
		Vector2(1.0, -1.0).normalized()
	]
	for direccion in direcciones:
		var destino := jugador.global_position + direccion * 48.0
		var ruta := _crear_ruta(npc.global_position, destino)
		if ruta.is_empty():
			continue
		npc.set_meta("acercamiento_social_activo", true)
		movimiento.establecer_ruta(ruta)
		return true
	return false



## Envía temporalmente a un NPC a una actividad cotidiana. Al terminar,
## recupera su rutina desde la posición alcanzada.
func iniciar_actividad_social(npc: Creature, destino_local: Vector2, duracion: float = 5.0) -> bool:
	if not is_instance_valid(npc) or not _malla_lista or _malla == null or not is_instance_valid(_zona):
		return false
	if bool(npc.get_meta("rutina_en_transito", false)) or bool(npc.get_meta("rutina_en_edificio", false)):
		return false
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		return false
	var destino_global := _zona.to_global(destino_local)
	var ruta := _crear_ruta(npc.global_position, destino_global)
	if ruta.is_empty():
		return false
	npc.set_meta("actividad_social_activa", true)
	npc.set_meta("actividad_social_tiempo", maxf(duracion, 1.0))
	npc.set_meta("acercamiento_social_activo", true)
	npc.set_meta("rutina_en_transito", true)
	movimiento.establecer_ruta(ruta)
	return true


func _actualizar_actividad_social(npc: Creature, delta: float) -> bool:
	if not bool(npc.get_meta("actividad_social_activa", false)):
		return false
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		_finalizar_actividad_social(npc)
		return false
	if movimiento.rutina_terminada():
		var restante := float(npc.get_meta("actividad_social_tiempo", 5.0)) - delta
		npc.set_meta("actividad_social_tiempo", restante)
		if restante <= 0.0:
			_finalizar_actividad_social(npc)
	return true


func _finalizar_actividad_social(npc: Creature) -> void:
	if not is_instance_valid(npc):
		return
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento != null:
		movimiento.detener_por_rutina()
	npc.remove_meta("actividad_social_activa")
	npc.remove_meta("actividad_social_tiempo")
	npc.remove_meta("acercamiento_social_activo")
	npc.set_meta("rutina_en_transito", false)
	npc.set_meta("rutina_firma", "")


## Al terminar o cancelar la iniciativa, el NPC retoma su destino canónico
## desde la posición actual, sin perder su horario.
func finalizar_acercamiento_social(npc: Creature) -> void:
	if not is_instance_valid(npc):
		return
	npc.remove_meta("acercamiento_social_activo")
	if not is_instance_valid(_world_atmosphere) or not is_instance_valid(_zone_manager):
		return
	if str(_zone_manager.obtener_tipo_actual()) != "reino_torres" or not _malla_lista:
		var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento != null:
			movimiento.detener_por_rutina()
		npc.set_meta("rutina_firma", "")
		return
	var tiempo := _world_atmosphere.obtener_tiempo()
	if not bool(tiempo.get("calendario_cargado", false)):
		return
	var dia_semana := posmod(int(tiempo.get("dia", 1)) - 1, 5)
	var minutos := clampi(int(floor(float(tiempo.get("hora_del_dia", 0.0)) * 60.0)), 0, 1439)
	npc.set_meta("rutina_firma", "")
	_aplicar_rutina(npc, dia_semana, minutos)


func _invalidar_malla() -> void:
	_zona = null
	_malla = null
	_malla_lista = false
	_construyendo_malla = false


func _construir_malla(zona: Node2D) -> void:
	if _construyendo_malla:
		return
	_construyendo_malla = true
	await get_tree().physics_frame

	if not is_instance_valid(zona) or zona != _zona:
		_construyendo_malla = false
		return

	var nueva_malla := AStarGrid2D.new()
	nueva_malla.region = Rect2i(Vector2i.ZERO, TAMANO_MALLA)
	nueva_malla.cell_size = Vector2(TAMANO_CELDA, TAMANO_CELDA)
	nueva_malla.offset = zona.to_global(ORIGEN_MAPA + Vector2(TAMANO_CELDA * 0.5, TAMANO_CELDA * 0.5))
	nueva_malla.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nueva_malla.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nueva_malla.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nueva_malla.update()

	var forma := CircleShape2D.new()
	forma.radius = RADIO_COLISION_NPC
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false

	var espacio := zona.get_world_2d().direct_space_state
	for y in range(TAMANO_MALLA.y):
		for x in range(TAMANO_MALLA.x):
			var id := Vector2i(x, y)
			var centro_local := ORIGEN_MAPA + Vector2(
				(float(x) + 0.5) * TAMANO_CELDA,
				(float(y) + 0.5) * TAMANO_CELDA
			)
			# El CollisionShape2D de Creature está desplazado 12 px hacia arriba.
			var centro_global := zona.to_global(centro_local + Vector2(0.0, -12.0))
			consulta.transform = Transform2D(0.0, centro_global)
			if not espacio.intersect_shape(consulta, 1).is_empty():
				nueva_malla.set_point_solid(id, true)

	if not is_instance_valid(zona) or zona != _zona:
		_construyendo_malla = false
		return

	_malla = nueva_malla
	_malla_lista = true
	_construyendo_malla = false
	print("NPCScheduleSystem: navegación de Torres lista (", TAMANO_MALLA.x * TAMANO_MALLA.y, " celdas).")


func _aplicar_rutina(npc: Creature, dia_semana: int, minutos: int) -> void:
	if bool(npc.get_meta("acercamiento_social_activo", false)) or bool(npc.get_meta("actividad_social_activa", false)):
		return
	var rutinas_variant: Variant = npc.datos.get("rutinas", [])
	var rutina: Dictionary
	if dia_semana == 4:
		rutina = _seleccionar_rutina_dia_libre(npc, minutos)
	else:
		rutina = _seleccionar_rutina(rutinas_variant, dia_semana, minutos, npc.get_nombre_visual())

	# Las rutinas de trabajo y los horarios canónicos permanecen intactos.
	# Sólo se matizan los momentos libres en la plaza con una actividad diaria
	# estable y una pequeña variación de posición.
	rutina = _aplicar_variacion_tiempo_libre(npc, rutina, dia_semana, minutos)

	var nombre_npc := npc.get_nombre_visual().strip_edges().to_lower()
	if nombre_npc in ["abel", "liam"] and (not rutinas_variant is Array or (rutinas_variant as Array).is_empty()) and dia_semana != 4:
		rutina = _seleccionar_rutina_respaldo_castillo(minutos)

	var ubicacion_respaldo := str(npc.datos.get("ubicacion_clave", "plaza")).strip_edges().to_lower()
	var hogar := str(npc.datos.get("hogar_clave", obtener_clave_hogar(npc.get_nombre_visual(), "plaza"))).strip_edges().to_lower()
	if not POSICIONES.has(hogar):
		hogar = obtener_clave_hogar(npc.get_nombre_visual(), "plaza")
	var esta_en_horario := not rutina.is_empty()
	if rutinas_variant is Array and (rutinas_variant as Array).is_empty() and nombre_npc not in ["abel", "liam"] and dia_semana != 4:
		var firma_aviso := "rutinas_vacias:" + nombre_npc
		if str(npc.get_meta("rutina_error_firma", "")) != firma_aviso:
			push_warning("NPCScheduleSystem: " + npc.get_nombre_visual() + " no recibió rutinas desde WorldData; ubicación de trabajo=" + ubicacion_respaldo + ". No se confundirá ese campo con su hogar.")
			npc.set_meta("rutina_error_firma", firma_aviso)
	var clave_rutina := str(rutina.get("clave", "regreso_hogar")).strip_edges()
	var ubicacion := str(rutina.get("ubicacion_clave", hogar)).strip_edges().to_lower()
	if ubicacion.is_empty() or ubicacion == "null" or not POSICIONES.has(ubicacion):
		ubicacion = hogar
	var actividad := str(rutina.get("actividad_clave", "volver_a_casa" if not esta_en_horario else "descansar")).strip_edges()
	if actividad.is_empty():
		actividad = "descansar"

	# La lluvia modifica temporalmente las actividades al aire libre.
	# Los NPC que ya están dentro o cuyo trabajo ocurre en un edificio continúan allí.
	var clima_lluvioso := _esta_lloviendo_en_posicion(npc.global_position)
	var esta_en_edificio := bool(npc.get_meta("rutina_en_edificio", false))
	if not clima_lluvioso:
		npc.remove_meta("refugio_lluvia_clave")
		npc.remove_meta("reaccion_climatica")
	elif esta_en_edificio:
		# Si ya encontró techo, permanece allí mientras siga lloviendo,
		# aunque su horario habitual indique una actividad exterior.
		var edificio_actual_meta := str(npc.get_meta("rutina_edificio_id", ""))
		for clave_refugio_variant in ENTRADAS_INTERIORES:
			var entrada_refugio: Dictionary = ENTRADAS_INTERIORES[clave_refugio_variant]
			if str(entrada_refugio.get("id", "")) == edificio_actual_meta:
				ubicacion = str(clave_refugio_variant)
				actividad = "resguardarse_de_la_lluvia"
				clave_rutina = "refugio_lluvia"
				esta_en_horario = true
				npc.set_meta("reaccion_climatica", "resguardarse_de_la_lluvia")
				break
	elif not ENTRADAS_INTERIORES.has(ubicacion):
		var refugio_guardado := str(npc.get_meta("refugio_lluvia_clave", "")).strip_edges()
		var refugio := refugio_guardado if ENTRADAS_INTERIORES.has(refugio_guardado) else _seleccionar_refugio_lluvia(npc, hogar)
		if not refugio.is_empty():
			npc.set_meta("refugio_lluvia_clave", refugio)
			npc.set_meta("reaccion_climatica", "resguardarse_de_la_lluvia")
			ubicacion = refugio
			actividad = "resguardarse_de_la_lluvia"
			clave_rutina = "refugio_lluvia"
			esta_en_horario = true

	var firma_anterior := str(npc.get_meta("rutina_firma", ""))
	var firma_diagnostico := str(npc.get_meta("rutina_diagnostico", ""))
	var diagnostico_actual := "%s|%s|%s|%d" % [clave_rutina, ubicacion, actividad, dia_semana]
	if firma_diagnostico != diagnostico_actual:
		print("NPCScheduleSystem: ", npc.get_nombre_visual(), " | día=", dia_semana + 1, " | minuto=", minutos, " | rutina=", clave_rutina, " | destino=", ubicacion, " | hogar=", hogar, " | rutinas_cargadas=", rutinas_variant.size() if rutinas_variant is Array else -1)
		npc.set_meta("rutina_diagnostico", diagnostico_actual)
	var variacion_posicion: Vector2 = rutina.get("variacion_posicion", Vector2.ZERO)
	var firma_nueva := clave_rutina + "|" + ubicacion + "|" + actividad + "|" + str(variacion_posicion)
	var edificio_variant: Variant = ENTRADAS_INTERIORES.get(ubicacion, {})
	var edificio: Dictionary = edificio_variant if edificio_variant is Dictionary else {}
	var edificio_id := str(edificio.get("id", ""))
	var esta_dentro := bool(npc.get_meta("rutina_en_edificio", false))
	var edificio_actual := str(npc.get_meta("rutina_edificio_id", ""))

	# Si cambió de destino mientras estaba dentro, sale desde la puerta antes
	# de comenzar la nueva ruta. El nodo sigue siendo la misma instancia.
	if esta_dentro and edificio_id != edificio_actual:
		if is_instance_valid(_zona) and _zona.has_method("sacar_npc_del_interior"):
			_zona.call("sacar_npc_del_interior", npc)
		var salida_variant: Variant = ENTRADAS_INTERIORES.get(edificio_actual, {})
		if salida_variant is Dictionary:
			var salida: Dictionary = salida_variant
			npc.global_position = _zona.to_global(salida.get("pos", Vector2.ZERO) + Vector2(0.0, 28.0))
		npc.set_meta("rutina_en_edificio", false)
		npc.set_meta("rutina_edificio_id", "")
		npc.visible = not (is_instance_valid(_zona) and bool(_zona.get("_interior_activo")))

	# Si la actividad cambia pero sigue en el mismo edificio, permanece dentro.
	if esta_dentro and edificio_id == edificio_actual:
		npc.set_meta("rutina_firma", firma_nueva)
		npc.set_meta("rutina_actual", clave_rutina)
		npc.set_meta("rutina_ubicacion", ubicacion)
		npc.datos["actividad_actual"] = actividad
		return

	if firma_anterior == firma_nueva:
		var movimiento_actual := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if not esta_dentro and movimiento_actual != null:
			if movimiento_actual.rutina_terminada():
				npc.set_meta("rutina_en_transito", false)
				if not edificio_id.is_empty():
					_marcar_npc_dentro_edificio(npc, edificio_id)
			elif movimiento_actual.rutina_en_ejecucion():
				npc.set_meta("rutina_en_transito", true)
				# Mantener activo el cuerpo que procesa el movimiento incluso si
				# otra rutina o transición pausó temporalmente al NPC.
				npc.set_process(true)
				npc.set_physics_process(true)
			else:
				# Si otra acción detuvo la ruta antes de llegar, se recupera el
				# recorrido en vez de dejar al NPC abandonado fuera del trabajo.
				var destino_reintento: Vector2 = edificio.get("pos", POSICIONES[ubicacion]) + Vector2(0.0, 28.0)
				var destino_reintento_global := _zona.to_global(destino_reintento)
				if npc.global_position.distance_to(destino_reintento_global) <= DISTANCIA_LLEGADA:
					npc.set_meta("rutina_en_transito", false)
					if not edificio_id.is_empty():
						_marcar_npc_dentro_edificio(npc, edificio_id)
				else:
					var ruta_reintento := _crear_ruta(npc.global_position, destino_reintento_global)
					if not ruta_reintento.is_empty():
						movimiento_actual.establecer_ruta(ruta_reintento)
						npc.set_meta("rutina_en_transito", true)
					elif str(npc.get_meta("rutina_error_firma", "")) != firma_nueva:
						push_warning("NPCScheduleSystem: no se pudo reanudar la ruta de " + npc.get_nombre_visual() + " hacia " + ubicacion + ".")
						npc.set_meta("rutina_error_firma", firma_nueva)
		return

	# Sin actividad programada, el destino siempre es su casa.
	var destino_local: Vector2 = POSICIONES[ubicacion]
	var hogar_variant: Variant = npc.datos.get("posicion_hogar_local", null)
	if not esta_en_horario and hogar_variant is Vector2:
		destino_local = hogar_variant
	elif not edificio_id.is_empty():
		# El punto de rutina debe quedar justo fuera del umbral. Usar el
		# centro de la puerta puede caer dentro de la colisión de fachada y
		# hacer que AStar termine varias celdas antes del edificio.
		destino_local = edificio.get("pos", destino_local) + Vector2(0.0, 28.0)

	# La plaza es un punto de encuentro, no un único punto de llegada.
	# Cada NPC ocupa un lugar estable alrededor del centro.
	if ubicacion == "plaza":
		var posiciones_plaza: Dictionary = {
			"elian": Vector2(-72.0, 24.0),
			"bruna": Vector2(64.0, 32.0),
			"darven": Vector2(-24.0, -64.0),
			"saira": Vector2(76.0, -52.0),
			"narel": Vector2(-88.0, -48.0),
			"abel": Vector2(12.0, 76.0),
			"liam": Vector2(104.0, 20.0)
		}
		destino_local += posiciones_plaza.get(npc.get_nombre_visual().strip_edges().to_lower(), Vector2.ZERO)
		destino_local += variacion_posicion
	var destino_global := _zona.to_global(destino_local)
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		push_warning("NPCScheduleSystem: " + npc.get_nombre_visual() + " no tiene CreatureMovement.")
		return

	npc.visible = not (is_instance_valid(_zona) and bool(_zona.get("_interior_activo")))
	if npc.global_position.distance_to(destino_global) > DISTANCIA_LLEGADA:
		var ruta := _crear_ruta(npc.global_position, destino_global)
		if ruta.is_empty():
			if str(npc.get_meta("rutina_error_firma", "")) != firma_nueva:
				push_warning("NPCScheduleSystem: no se encontró una ruta transitable para " + npc.get_nombre_visual() + " hacia " + ubicacion + ".")
				npc.set_meta("rutina_error_firma", firma_nueva)
			movimiento.detener_por_rutina()
			npc.set_meta("rutina_firma", "")
			return
		npc.set_meta("rutina_error_firma", "")
		movimiento.establecer_ruta(ruta)
		npc.set_meta("rutina_en_transito", true)
		print("NPCScheduleSystem: ", npc.get_nombre_visual(), " -> ", ubicacion, " (", actividad, ") | puntos de ruta: ", ruta.size())
	else:
		movimiento.detener_por_rutina()
		npc.set_meta("rutina_en_transito", false)
		if not edificio_id.is_empty():
			_marcar_npc_dentro_edificio(npc, edificio_id)

	npc.set_meta("rutina_firma", firma_nueva)
	npc.set_meta("rutina_actual", clave_rutina)
	npc.set_meta("rutina_ubicacion", ubicacion)
	npc.datos["actividad_actual"] = actividad


func _esta_lloviendo_en_posicion(posicion: Vector2) -> bool:
	if not is_instance_valid(_world_atmosphere):
		return false
	var sistema := _world_atmosphere.get_node_or_null("ClimateSystem")
	if sistema == null or not sistema.has_method("obtener_estado_para_posicion"):
		return false
	var estado_variant: Variant = sistema.call("obtener_estado_para_posicion", posicion, "")
	if not estado_variant is Dictionary:
		return false
	var clima_variant: Variant = (estado_variant as Dictionary).get("clima", {})
	if not clima_variant is Dictionary:
		return false
	var clima := clima_variant as Dictionary
	var tipo := str(clima.get("tipo", "despejado"))
	return tipo in ["lluvia", "tormenta"] and float(clima.get("precipitacion", 0.0)) >= 0.18


func _seleccionar_refugio_lluvia(npc: Creature, hogar: String) -> String:
	if not is_instance_valid(npc) or not is_instance_valid(_zona):
		return ""
	var mejor_clave := ""
	var mejor_puntuacion := INF
	for clave_variant in ENTRADAS_INTERIORES.keys():
		var clave := str(clave_variant)
		var entrada_variant: Variant = ENTRADAS_INTERIORES.get(clave, {})
		if not entrada_variant is Dictionary:
			continue
		var entrada := entrada_variant as Dictionary
		var posicion_local: Vector2 = entrada.get("pos", Vector2.ZERO)
		var distancia := npc.global_position.distance_to(_zona.to_global(posicion_local + Vector2(0.0, 28.0)))
		# Su propia casa tiene preferencia moderada, sin obligarlo a cruzar
		# todo el pueblo cuando hay un refugio cercano.
		var puntuacion := distancia * (0.78 if clave == hogar else 1.0)
		if puntuacion < mejor_puntuacion:
			mejor_puntuacion = puntuacion
			mejor_clave = clave
	return mejor_clave


func _marcar_npc_dentro_edificio(npc: Creature, edificio_id: String) -> void:
	# La llegada al umbral representa que el NPC entró. Se mantiene la misma
	# instancia y se oculta del exterior hasta que se abra ese interior.
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento != null:
		movimiento.detener_por_rutina()
	npc.set_meta("rutina_en_edificio", true)
	npc.set_meta("rutina_en_transito", false)
	npc.set_meta("rutina_edificio_id", edificio_id)
	npc.visible = false
	npc.remove_from_group("interactable")


## Añade variedad ambiental sin sustituir horarios ni destinos de trabajo.
## La elección depende del día del mundo y del tramo horario, por lo que no
## cambia en cada actualización del sistema.
func _aplicar_variacion_tiempo_libre(
	npc: Creature,
	rutina_base: Dictionary,
	dia_semana: int,
	minutos: int
) -> Dictionary:
	if rutina_base.is_empty():
		return rutina_base

	var clave_base := str(rutina_base.get("clave", ""))
	var ubicacion_base := str(rutina_base.get("ubicacion_clave", ""))
	if not clave_base.begins_with("dia_libre") or ubicacion_base != "plaza":
		return rutina_base

	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	var actividades_por_personaje: Dictionary = {
		"elian": ["acomodar_pedidos", "conversar_con_vecinos", "compartir_pan"],
		"bruna": ["revisar_herramientas", "observar_trabajos", "descansar_un_rato"],
		"darven": ["vigilar_plaza", "revisar_avisos", "conversar_con_habitantes"],
		"saira": ["saludar_comerciantes", "compartir_noticias", "escuchar_historias"],
		"narel": ["tomar_notas", "observar_entorno", "leer_apuntes"]
	}
	if not actividades_por_personaje.has(nombre):
		return rutina_base

	var tramo := 0
	if minutos >= 840 and minutos < 1020:
		tramo = 1
	elif minutos >= 1020:
		tramo = 2

	var tiempo := _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var clave_dia := "%s:%s:%s" % [
		str(tiempo.get("anio", 0)),
		str(tiempo.get("mes", 0)),
		str(tiempo.get("dia", dia_semana))
	]
	var actividades: Array = actividades_por_personaje[nombre]
	var indice := absi(hash(nombre + "|" + clave_dia + "|" + str(tramo))) % actividades.size()

	var resultado := rutina_base.duplicate(true)
	resultado["actividad_clave"] = str(actividades[indice])
	resultado["variacion_posicion"] = _obtener_desplazamiento_ocio(nombre, clave_dia, tramo)
	resultado["variacion_diaria"] = clave_dia
	return resultado


func _obtener_desplazamiento_ocio(nombre: String, clave_dia: String, tramo: int) -> Vector2:
	# Desplazamientos cortos alrededor del punto habitual de cada habitante.
	# Se conservan dentro de la plaza y no alteran rutas de trabajo.
	var desplazamientos: Array[Vector2] = [
		Vector2(-20.0, -12.0),
		Vector2(16.0, -16.0),
		Vector2(20.0, 12.0),
		Vector2(-16.0, 16.0),
		Vector2(0.0, -20.0)
	]
	var indice := absi(hash(nombre + "|" + clave_dia + "|" + str(tramo) + "|pos")) % desplazamientos.size()
	return desplazamientos[indice]


func _seleccionar_rutina_respaldo_castillo(minutos: int) -> Dictionary:
	# Abel y Liam residen en el castillo: salen durante el día y regresan
	# al anochecer para dormir allí. Este respaldo sólo se usa mientras
	# todavía no tienen horarios propios cargados desde sus datos.
	if minutos >= 480 and minutos < 1200:
		return {
			"clave": "salida_diurna_castillo",
			"ubicacion_clave": "plaza",
			"actividad_clave": "recorrer_torres",
			"activo": true
		}
	return {
		"clave": "regreso_nocturno_castillo",
		"ubicacion_clave": "castillo",
		"actividad_clave": "dormir",
		"activo": true
	}


func _seleccionar_rutina_dia_libre(npc: Creature, minutos: int) -> Dictionary:
	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	var hogares: Dictionary = {
		"elian": "casa_elian",
		"bruna": "casa_bruna",
		"darven": "casa_darven",
		"saira": "casa_saira",
		"narel": "casa_narel",
		"abel": "castillo",
		"liam": "castillo"
	}
	var hogar := str(hogares.get(nombre, "plaza"))
	var ubicacion := hogar
	var actividad := "descansar"
	var clave := "dia_libre_casa"

	if minutos >= 540 and minutos < 720:
		clave = "dia_libre_manana"
		actividad = "pasear"
		match nombre:
			"darven":
				ubicacion = "cuartel"
				actividad = "recorrer_alrededores"
			"narel":
				ubicacion = "archivo_real"
				actividad = "leer"
			_:
				ubicacion = "plaza"
	elif minutos >= 840 and minutos < 1020:
		clave = "dia_libre_tarde"
		actividad = "pasear"
		match nombre:
			"saira":
				ubicacion = "casa_comercio"
				actividad = "visitar_comerciantes"
			"narel":
				ubicacion = "casa_estudio"
				actividad = "visitar_estudio"
			"darven":
				ubicacion = "plaza"
				actividad = "descansar"
			_:
				ubicacion = "plaza"
	elif minutos >= 1020 and minutos < 1200:
		clave = "dia_libre_encuentro"
		ubicacion = "plaza"
		actividad = "conversar"
	elif minutos >= 1200:
		clave = "dia_libre_regreso"
		ubicacion = hogar
		actividad = "volver_a_casa"

	return {
		"clave": clave,
		"ubicacion_clave": ubicacion,
		"actividad_clave": actividad,
		"activo": true
	}


func _seleccionar_rutina(rutinas_variant: Variant, dia_semana: int, minutos: int, nombre_npc: String = "?") -> Dictionary:
	if not rutinas_variant is Array:
		return {}

	var mejor: Dictionary = {}
	var prioridad_mejor := -2147483648
	var inicio_mejor := -1
	var diagnostico_rechazos: Array[String] = []

	for indice in range((rutinas_variant as Array).size()):
		var rutina_variant: Variant = (rutinas_variant as Array)[indice]
		if not rutina_variant is Dictionary:
			diagnostico_rechazos.append("[" + str(indice) + "] no_es_diccionario")
			continue
		var rutina := rutina_variant as Dictionary
		var clave := str(rutina.get("clave", "sin_clave"))
		var activo := bool(rutina.get("activo", true))
		if not activo:
			diagnostico_rechazos.append(clave + ": inactiva")
			continue

		var inicio_raw: Variant = rutina.get("hora_inicio", "")
		var fin_raw: Variant = rutina.get("hora_fin", "")
		var inicio := _hora_a_minutos(inicio_raw)
		var fin := _hora_a_minutos(fin_raw)
		if inicio < 0 or fin < 0 or inicio == fin:
			diagnostico_rechazos.append(clave + ": hora_invalida inicio=" + str(inicio_raw) + " fin=" + str(fin_raw) + " parseadas=" + str(inicio) + "/" + str(fin))
			continue

		var dia_referencia := dia_semana
		var esta_activa := false
		if fin > inicio:
			esta_activa = minutos >= inicio and minutos < fin
		elif minutos >= inicio:
			esta_activa = true
		elif minutos < fin:
			esta_activa = true
			dia_referencia = posmod(dia_semana - 1, 5)

		var dias_variant: Variant = rutina.get("dias_semana", [])
		var coincide_dia := _coincide_dia(dias_variant, dia_referencia)
		if not esta_activa or not coincide_dia:
			diagnostico_rechazos.append(clave + ": " + ("fuera_de_hora" if not esta_activa else "dia_no_coincide") + " ahora=" + str(minutos) + " rango=" + str(inicio) + "-" + str(fin) + " dia=" + str(dia_referencia) + " dias=" + str(dias_variant))
			continue

		var prioridad := int(rutina.get("prioridad", 0))
		if mejor.is_empty() or prioridad > prioridad_mejor or (prioridad == prioridad_mejor and inicio > inicio_mejor):
			mejor = rutina.duplicate(true)
			prioridad_mejor = prioridad
			inicio_mejor = inicio

	if mejor.is_empty():
		var firma_fallo := "%s|%d|%d|%s" % [nombre_npc, dia_semana, minutos, str(diagnostico_rechazos)]
		if str(get_meta("ultimo_diagnostico_selector", "")) != firma_fallo:
			print("NPCScheduleSystem: SELECTOR SIN COINCIDENCIA | npc=", nombre_npc, " dia=", dia_semana, " minuto=", minutos, " total=", (rutinas_variant as Array).size(), " | ", str(diagnostico_rechazos))
			set_meta("ultimo_diagnostico_selector", firma_fallo)

	return mejor


func _coincide_dia(dias_variant: Variant, dia: int) -> bool:
	if not dias_variant is Array or (dias_variant as Array).is_empty():
		return true

	# WorldData llega desde JSON/RPC y sus números pueden venir como float
	# (por ejemplo 0.0). No usar "in" aquí: la comparación Variant puede
	# distinguir tipos numéricos aunque representen el mismo día.
	for dia_variant in dias_variant as Array:
		if dia_variant is int or dia_variant is float:
			if is_equal_approx(float(dia_variant), float(dia)):
				return true
		elif dia_variant is String:
			var dia_texto := str(dia_variant).strip_edges()
			if dia_texto.is_valid_int() and int(dia_texto) == dia:
				return true
	return false


func _hora_a_minutos(valor: Variant) -> int:
	var partes := str(valor).strip_edges().split(":")
	if partes.size() < 2:
		return -1
	if not partes[0].is_valid_int() or not partes[1].is_valid_int():
		return -1
	var hora := int(partes[0])
	var minuto := int(partes[1])
	if hora < 0 or hora > 23 or minuto < 0 or minuto > 59:
		return -1
	return hora * 60 + minuto


func _crear_ruta(origen: Vector2, destino: Vector2) -> PackedVector2Array:
	if _malla == null or not _malla_lista:
		return PackedVector2Array()

	var inicio_id := _posicion_a_celda(origen)
	var destino_id := _posicion_a_celda(destino)
	inicio_id = _buscar_celda_transitable_cercana(inicio_id)
	destino_id = _buscar_celda_transitable_cercana(destino_id)
	if inicio_id.x < 0 or destino_id.x < 0:
		return PackedVector2Array()

	var puntos := _malla.get_point_path(inicio_id, destino_id)
	if puntos.is_empty():
		return PackedVector2Array()

	var ruta := PackedVector2Array()
	for punto in puntos:
		if ruta.is_empty() and origen.distance_to(punto) <= DISTANCIA_LLEGADA:
			continue
		ruta.append(punto)
	if ruta.is_empty() and origen.distance_to(destino) > DISTANCIA_LLEGADA:
		ruta.append(destino)
	return ruta


func _posicion_a_celda(posicion: Vector2) -> Vector2i:
	# AStarGrid2D.offset ya apunta al centro de la celda (0, 0).
	# Restar otra media celda desplazaba cada consulta una celda.
	return Vector2i(
		roundi((posicion.x - _malla.offset.x) / TAMANO_CELDA),
		roundi((posicion.y - _malla.offset.y) / TAMANO_CELDA)
	)


func _buscar_celda_transitable_cercana(celda: Vector2i) -> Vector2i:
	if _malla == null:
		return Vector2i(-1, -1)
	for radio in range(0, 6):
		for y in range(-radio, radio + 1):
			for x in range(-radio, radio + 1):
				if radio > 0 and maxi(absi(x), absi(y)) != radio:
					continue
				var candidata := celda + Vector2i(x, y)
				if not _malla.is_in_boundsv(candidata):
					continue
				if not _malla.is_point_solid(candidata):
					return candidata
	return Vector2i(-1, -1)
