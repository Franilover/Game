extends Node
class_name NPCScheduleSystem

const INTERVALO_ACTUALIZACION := 0.5
const TAMANO_CELDA := 32.0
const ORIGEN_MAPA := Vector2(-1152.0, -672.0)
const TAMANO_MALLA := Vector2i(72, 42)
const RADIO_COLISION_NPC := 14.0
const DISTANCIA_LLEGADA := 7.0
# Coste de desplazamiento: Tierra (zona 1) conserva el coste base y los demás
# terrenos cuestan más. Mantener el mínimo en 1 preserva la heurística AStar.
const COSTE_CAMINO_TIERRA := 1.0
const COSTE_OTRO_TERRENO := 1.55
# Espera breve para agrupar varios cambios de posición/tamaño en una sola reconstrucción.
const ESPERA_RECONSTRUCCION_NAVEGACION := 1.0

# Puntos de actividad en coordenadas locales de ReinoTorres.
# Se definen por ubicación, nunca por nombre de personaje.
const ENTRADAS_INTERIORES: Dictionary = {
	"panaderia": {"id": "panaderia", "pos": Vector2(-220.0, -20.0)},
	"forja": {"id": "forja", "pos": Vector2(-360.0, -190.0)},
	"cuartel": {"id": "cuartel", "pos": Vector2(250.0, -305.0)},
	"registro": {"id": "registro", "pos": Vector2(420.0, -255.0)},
	"casa_comercio": {"id": "casa_comercio", "pos": Vector2(420.0, -95.0)},
	"archivo_real": {"id": "archivo_real", "pos": Vector2(-150.0, 70.0)},
	"casa_estudio": {"id": "casa_estudio", "pos": Vector2(-420.0, -55.0)},
	"casa_elian": {"id": "casa_elian", "pos": Vector2(820.0, -320.0)},
	"casa_bruna": {"id": "casa_bruna", "pos": Vector2(-820.0, -320.0)},
	"casa_darven": {"id": "casa_darven", "pos": Vector2(1080.0, -320.0)},
	"casa_saira": {"id": "casa_saira", "pos": Vector2(820.0, -60.0)},
	"casa_narel": {"id": "casa_narel", "pos": Vector2(-1080.0, -320.0)},
	"castillo": {"id": "castillo", "pos": Vector2(0.0, -125.0)},
	"posada": {"id": "posada", "pos": Vector2(-400.0, 110.0)},
	"vivienda_oeste_01": {"id": "casa_vacia_01", "pos": Vector2(-820.0, -60.0)},
	"vivienda_oeste_02": {"id": "casa_vacia_02", "pos": Vector2(-1080.0, -60.0)},
	"vivienda_oeste_03": {"id": "casa_vacia_03", "pos": Vector2(-820.0, 220.0)},
	"vivienda_oeste_04": {"id": "casa_vacia_04", "pos": Vector2(-1080.0, 220.0)},
	"vivienda_oeste_05": {"id": "casa_vacia_05", "pos": Vector2(-820.0, 540.0)},
	"vivienda_oeste_06": {"id": "casa_vacia_06", "pos": Vector2(-1080.0, 540.0)},
	"vivienda_oeste_07": {"id": "casa_vacia_07", "pos": Vector2(1080.0, -60.0)},
	"vivienda_oeste_08": {"id": "casa_vacia_08", "pos": Vector2(820.0, 220.0)},
	"vivienda_oeste_10": {"id": "casa_vacia_10", "pos": Vector2(1080.0, 220.0)},
	"vivienda_oeste_11": {"id": "casa_vacia_11", "pos": Vector2(820.0, 540.0)},
	"casa_granjeros": {"id": "casa_granjeros", "pos": Vector2(1080.0, 540.0)}
}

const POSICIONES: Dictionary = {
	"plaza": Vector2(0.0, 0.0),
	"panaderia": Vector2(-220.0, -20.0),
	"forja": Vector2(-360.0, -190.0),
	"cuartel": Vector2(250.0, -305.0),
	"registro": Vector2(420.0, -255.0),
	"casa_comercio": Vector2(420.0, -95.0),
	"casa_estudio": Vector2(-420.0, -55.0),
	"archivo_real": Vector2(-150.0, 70.0),
	"casa_elian": Vector2(820.0, -320.0),
	"casa_bruna": Vector2(-820.0, -320.0),
	"casa_darven": Vector2(1080.0, -320.0),
	"casa_saira": Vector2(820.0, -60.0),
	"casa_narel": Vector2(-1080.0, -320.0),
	"castillo": Vector2(0.0, -125.0),
	"posada": Vector2(-400.0, 110.0),
	"vivienda_oeste_01": Vector2(-820.0, -60.0),
	"vivienda_oeste_02": Vector2(-1080.0, -60.0),
	"vivienda_oeste_03": Vector2(-820.0, 220.0),
	"vivienda_oeste_04": Vector2(-1080.0, 220.0),
	"vivienda_oeste_05": Vector2(-820.0, 540.0),
	"vivienda_oeste_06": Vector2(-1080.0, 540.0),
	"vivienda_oeste_07": Vector2(1080.0, -60.0),
	"vivienda_oeste_08": Vector2(820.0, 220.0),
	"vivienda_oeste_10": Vector2(1080.0, 220.0),
	"vivienda_oeste_11": Vector2(820.0, 540.0),
	"casa_granjeros": Vector2(1080.0, 540.0)
}

var _world_atmosphere: WorldAtmosphere = null
var _zone_manager: Node = null
var _relationship_system: RelationshipSystemService = null
var _zona: Node2D = null
var _terreno_visual: Node = null
var _malla: AStarGrid2D = null
var _malla_lista := false
var _construyendo_malla := false
var _tiempo_actualizacion := 0.0
var _firma_colisiones := ""
var _tiempo_cambio_colisiones := -1.0
var _ultimo_aviso_evento_comunitario := ""


func configurar(
	atmosfera: WorldAtmosphere,
	zone_manager: Node,
	relationship_system: RelationshipSystemService = null
) -> void:
	_world_atmosphere = atmosfera
	_zone_manager = zone_manager
	_relationship_system = relationship_system
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
		"liam": "castillo",
		"mara": "vivienda_oeste_01",
		"ivo": "vivienda_oeste_02",
		"nima": "vivienda_oeste_03",
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

	# Los edificios pueden moverse o cambiar sus colisiones durante la sesión.
	# Comprobar cada medio segundo evita trabajo por frame y agrupa cambios.
	if _detectar_cambios_geometria(zona_actual, delta):
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
		_actualizar_paseo_ambiental_exterior(npc, minutos)
	_actualizar_interaccion_panaderia()


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
	if _esta_lloviendo_en_posicion(npc.global_position):
		# La actividad al aire libre se interrumpe para que la rutina normal
		# pueda enviarlo a un edificio cercano.
		_finalizar_actividad_social(npc)
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
	_terreno_visual = null
	_malla = null
	_malla_lista = false
	_construyendo_malla = false
	_firma_colisiones = ""
	_tiempo_cambio_colisiones = -1.0


## Detecta cambios en cuerpos y formas físicas de Torres, sin inspeccionar
## los NPC ni al jugador. Devuelve true mientras espera o reconstruye.
func _detectar_cambios_geometria(zona: Node2D, delta: float) -> bool:
	if _construyendo_malla:
		return true
	# Al entrar a un edificio, ReinoTorres desactiva temporalmente las
	# colisiones exteriores. No debemos interpretar ese cambio técnico como
	# una mudanza de edificios; al salir se restauran y se retoma la vigilancia.
	var interior := zona.get_node_or_null("InteriorActivo")
	if interior is CanvasItem and (interior as CanvasItem).visible:
		return false
	var firma_actual := _obtener_firma_colisiones(zona)
	if _firma_colisiones.is_empty():
		_firma_colisiones = firma_actual
		return false
	if firma_actual != _firma_colisiones:
		_firma_colisiones = firma_actual
		_tiempo_cambio_colisiones = 0.0
		return true
	if _tiempo_cambio_colisiones < 0.0:
		return false
	_tiempo_cambio_colisiones += maxf(delta, INTERVALO_ACTUALIZACION)
	if _tiempo_cambio_colisiones < ESPERA_RECONSTRUCCION_NAVEGACION:
		return true
	_tiempo_cambio_colisiones = -1.0
	_malla_lista = false
	call_deferred("_construir_malla", zona)
	return true


func _obtener_firma_colisiones(raiz: Node) -> String:
	var partes: PackedStringArray = []
	_agregar_firma_colisiones(raiz, partes)
	return "|".join(partes)


func _agregar_firma_colisiones(nodo: Node, partes: PackedStringArray) -> void:
	if nodo is StaticBody2D or nodo is AnimatableBody2D:
		var cuerpo := nodo as CollisionObject2D
		partes.append("BODY:%s:%s:%d:%d" % [
			str(cuerpo.get_path()),
			str(cuerpo.global_transform),
			cuerpo.collision_layer,
			cuerpo.collision_mask
		])
	elif nodo is CollisionShape2D:
		var forma := nodo as CollisionShape2D
		var geometria := "sin_forma"
		if forma.shape != null:
			geometria = "%d:%s" % [forma.shape.get_instance_id(), str(forma.shape.get_rect())]
		partes.append("SHAPE:%s:%s:%s:%s" % [
			str(forma.get_path()),
			str(forma.global_transform),
			str(forma.disabled),
			geometria
		])
	elif nodo is CollisionPolygon2D:
		var poligono := nodo as CollisionPolygon2D
		partes.append("POLYGON:%s:%s:%s:%s" % [
			str(poligono.get_path()),
			str(poligono.global_transform),
			str(poligono.disabled),
			str(poligono.polygon)
		])
	for hijo in nodo.get_children():
		_agregar_firma_colisiones(hijo, partes)


func _construir_malla(zona: Node2D) -> void:
	if _construyendo_malla:
		return
	_construyendo_malla = true
	await get_tree().physics_frame

	if not is_instance_valid(zona) or zona != _zona:
		_construyendo_malla = false
		return

	_terreno_visual = get_tree().get_first_node_in_group("world_terrain_visual")
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
			else:
				_aplicar_preferencia_terreno(nueva_malla, id, centro_global)

	if not is_instance_valid(zona) or zona != _zona:
		_construyendo_malla = false
		return

	_malla = nueva_malla
	_malla_lista = true
	_construyendo_malla = false
	_firma_colisiones = _obtener_firma_colisiones(zona)
	_tiempo_cambio_colisiones = -1.0
	_reiniciar_rutas_npc_tras_reconstruccion()
	print("NPCScheduleSystem: navegación de Torres lista (", TAMANO_MALLA.x * TAMANO_MALLA.y, " celdas).")


## Tras mover un edificio, las rutas activas se invalidan para que el
## siguiente ciclo de horarios las calcule sobre la nueva geometría.
func _reiniciar_rutas_npc_tras_reconstruccion() -> void:
	for npc_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not npc_variant is Creature or not is_instance_valid(npc_variant):
			continue
		var npc := npc_variant as Creature
		if bool(npc.get_meta("actividad_social_activa", false)) or bool(npc.get_meta("acercamiento_social_activo", false)):
			continue
		if not bool(npc.get_meta("rutina_en_transito", false)):
			continue
		var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento != null:
			movimiento.detener_por_rutina()
		npc.set_meta("rutina_en_transito", false)
		npc.set_meta("rutina_firma", "")


## Aplica un coste menor a las celdas del atlas Tierra (zona 1).
## Los demás terrenos conservan su coste normal y siguen disponibles como
## desvíos o atajos cuando el camino de tierra no resulte conveniente.
func _aplicar_preferencia_terreno(malla: AStarGrid2D, celda: Vector2i, posicion_global: Vector2) -> void:
	if not is_instance_valid(_terreno_visual) or not _terreno_visual.has_method("obtener_zona_en_posicion"):
		return
	var zona_terreno: int = int(_terreno_visual.call("obtener_zona_en_posicion", posicion_global))
	var coste: float = COSTE_CAMINO_TIERRA if zona_terreno == 1 else COSTE_OTRO_TERRENO
	malla.set_point_weight_scale(celda, coste)


func _aplicar_rutina(npc: Creature, dia_semana: int, minutos: int) -> void:
	if bool(npc.get_meta("acercamiento_social_activo", false)) or bool(npc.get_meta("actividad_social_activa", false)):
		return
	var rutinas_variant: Variant = npc.datos.get("rutinas", [])
	var rutina: Dictionary
	var nombre_para_descanso := npc.get_nombre_visual().strip_edges().to_lower()
	if dia_semana == 4 and (not bool(npc.get_meta("habitante_sin_oficio", false)) or nombre_para_descanso in ["mara", "ivo", "nima"]):
		rutina = _seleccionar_rutina_dia_libre(npc, minutos)
	else:
		rutina = _seleccionar_rutina(rutinas_variant, dia_semana, minutos, npc.get_nombre_visual())

	# Las reuniones nocturnas ya no desplazan a toda la población.
	# Cada personaje conserva su horario y sólo acude si su propia rutina lo indica.

	# Las rutinas de trabajo y los horarios canónicos permanecen intactos.
	# Sólo se matizan los momentos libres con actividades propias.
	rutina = _aplicar_variacion_tiempo_libre(npc, rutina, dia_semana, minutos)

	# Una invitación aceptada ocupa únicamente una franja libre del día acordado.
	var invitacion := _obtener_rutina_invitacion(npc, rutina, minutos)
	if not invitacion.is_empty():
		rutina = invitacion

	# Los acontecimientos comunitarios sólo ocupan horas libres o días de
	# descanso. Nunca desplazan a un NPC de su trabajo, guardia o investigación.
	var evento_comunitario: Dictionary = _obtener_evento_comunitario(dia_semana, minutos)
	if not evento_comunitario.is_empty() and _puede_participar_en_evento(rutina):
		var clave_evento := str(evento_comunitario.get("clave", ""))
		var desplazamiento_evento := _obtener_desplazamiento_evento(
			npc.get_nombre_visual(), clave_evento
		)
		rutina = {
			"clave": clave_evento,
			"ubicacion_clave": "plaza",
			"actividad_clave": str(evento_comunitario.get("actividad", "participar_en_evento")),
			"variacion_posicion": desplazamiento_evento,
			"activo": true
		}
		npc.set_meta("evento_comunitario_actual", clave_evento)
		_notificar_evento_comunitario(evento_comunitario)
	else:
		npc.set_meta("evento_comunitario_actual", "")

	# El encuentro de tres sólo puede usar tiempo libre que no esté reservado
	# por invitaciones ni acontecimientos comunitarios.
	var encuentro_trio := _obtener_rutina_encuentro_trio(npc, dia_semana, minutos, rutina)
	if not encuentro_trio.is_empty():
		rutina = encuentro_trio

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
	var actividad := str(rutina.get("actividad_clave", "volver_a_casa" if not esta_en_horario else "descansar")).strip_edges()
	if actividad.is_empty():
		actividad = "descansar"
	# Ivo sólo va a comprar pan si Elian tiene turno en la panadería en
	# este mismo tramo. Si no coincide, aprovecha ese rato en la plaza.
	if nombre_npc == "ivo" and ubicacion == "panaderia" and not _el_npc_tiene_rutina_en_ubicacion("elian", "panaderia", dia_semana, minutos):
		clave_rutina = "ivo_paseo_sin_panadero"
		ubicacion = "plaza"
		actividad = "pasear_y_saludar"
		rutina["actividad_clave"] = actividad
		rutina["variacion_posicion"] = Vector2(18.0, 132.0)
	if ubicacion.is_empty() or ubicacion == "null" or not POSICIONES.has(ubicacion):
		ubicacion = hogar

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
	if firma_anterior != firma_nueva and not _esperar_desfase_cambio_rutina(npc, firma_nueva):
		return
	var edificio_variant: Variant = ENTRADAS_INTERIORES.get(ubicacion, {})
	var edificio: Dictionary = edificio_variant if edificio_variant is Dictionary else {}
	var edificio_id := str(edificio.get("id", ""))
	var esta_dentro := bool(npc.get_meta("rutina_en_edificio", false))
	var edificio_actual := str(npc.get_meta("rutina_edificio_id", ""))

	# Si cambió de destino mientras estaba dentro, sale desde la puerta antes
	# de comenzar la nueva ruta. El nodo sigue siendo la misma instancia.
	if esta_dentro and edificio_id != edificio_actual:
		_detener_animacion_actividad_interior(npc)
		if bool(npc.get_meta("rutina_paseo_interior_activo", false)):
			var movimiento_interior := npc.get_node_or_null("CreatureMovement") as CreatureMovement
			if is_instance_valid(movimiento_interior):
				movimiento_interior.detener_por_rutina()
			npc.remove_meta("rutina_paseo_interior_activo")
			npc.remove_meta("rutina_paseo_interior_siguiente")
			npc.set_meta("rutina_en_transito", false)
		if is_instance_valid(_zona) and _zona.has_method("sacar_npc_del_interior"):
			_zona.call("sacar_npc_del_interior", npc)
		var salida_variant: Variant = ENTRADAS_INTERIORES.get(edificio_actual, {})
		if salida_variant is Dictionary:
			var salida: Dictionary = salida_variant
			npc.global_position = _zona.to_global(salida.get("pos", Vector2.ZERO) + Vector2(0.0, 28.0))
		npc.set_meta("rutina_en_edificio", false)
		npc.set_meta("rutina_edificio_id", "")
		npc.visible = not (is_instance_valid(_zona) and (_zona.get("_interior_activo") == true))

	# Si la actividad cambia pero sigue en el mismo edificio, permanece dentro.
	# Durante la reunión nocturna, además rota entre pequeños grupos del salón.
	if esta_dentro and edificio_id == edificio_actual:
		_actualizar_rutina_interior(npc, edificio_actual, minutos)
		npc.set_meta("actividad_actual", actividad)
		_actualizar_animacion_actividad_interior(npc)
		if clave_rutina == "reunion_nocturna_castillo":
			_actualizar_movimiento_reunion_castillo(npc, minutos)
			npc.datos["actividad_actual"] = "conversando con los demás"
			npc.set_meta("actividad_actual", "conversando con los demás")
			npc.set_meta("rutina_en_transito", false)
			npc.remove_meta("viajando")
		else:
			npc.datos["actividad_actual"] = actividad
		npc.set_meta("rutina_firma", firma_nueva)
		npc.set_meta("rutina_actual", clave_rutina)
		npc.set_meta("rutina_ubicacion", ubicacion)
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
		var posicion_absoluta_variant: Variant = rutina.get("posicion_absoluta_plaza", null)
		if posicion_absoluta_variant is Vector2:
			destino_local = posicion_absoluta_variant
		else:
			var posiciones_plaza: Dictionary = {
				"elian": Vector2(-72.0, 24.0),
				"bruna": Vector2(64.0, 32.0),
				"darven": Vector2(-24.0, -64.0),
				"saira": Vector2(76.0, -52.0),
				"narel": Vector2(-88.0, -48.0),
				"abel": Vector2(12.0, 76.0),
				"liam": Vector2(104.0, 20.0),
				# Los tres habitantes locales ocupan sectores distintos del borde
				# de la plaza; ninguno usa el punto central como destino por defecto.
				"mara": Vector2(-132.0, -28.0),
				"ivo": Vector2(18.0, 132.0),
				"nima": Vector2(132.0, -18.0)
			}
			var nombre_plaza := npc.get_nombre_visual().strip_edges().to_lower()
			var posicion_plaza: Vector2
			if posiciones_plaza.has(nombre_plaza):
				posicion_plaza = posiciones_plaza[nombre_plaza]
			else:
				# Los NPC adicionales también se reparten alrededor del perímetro,
				# en vez de acumularse en el centro de la plaza.
				var indice_perimetro := posmod(hash(nombre_plaza), 12)
				var angulo_perimetro := TAU * float(indice_perimetro) / 12.0
				posicion_plaza = Vector2(cos(angulo_perimetro) * 118.0, sin(angulo_perimetro) * 118.0)
			destino_local += posicion_plaza
			destino_local += variacion_posicion
	var destino_global := _zona.to_global(destino_local)
	if clave_rutina.begins_with("encuentro_trio_"):
		npc.remove_meta("rutina_paseo_exterior_activo")
		npc.set_meta("rutina_paseo_exterior_siguiente", posmod(minutos + 7 + posmod(hash(npc.get_nombre_visual()), 5), 1440))
	if ubicacion == "plaza":
		npc.set_meta("rutina_ancla_ocio", destino_global)
	else:
		npc.remove_meta("rutina_ancla_ocio")
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		push_warning("NPCScheduleSystem: " + npc.get_nombre_visual() + " no tiene CreatureMovement.")
		return

	npc.visible = not (is_instance_valid(_zona) and (_zona.get("_interior_activo") == true))
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


## Agrupa a los asistentes según sus vínculos reales y distribuye sus
## desplazamientos durante la fase para que no abandonen todos la conversación.
func _actualizar_movimiento_reunion_castillo(npc: Creature, minutos: int) -> void:
	if not is_instance_valid(npc) or not is_instance_valid(_zona) or not _malla_lista:
		return
	var fase := maxi(0, int((minutos - 1260) / 45))
	if int(npc.get_meta("reunion_castillo_fase", -1)) == fase:
		return
	var inicio_fase := 1260 + fase * 45
	var id_npc := npc.get_personaje_game_id().strip_edges()
	var retraso := posmod(hash(id_npc if not id_npc.is_empty() else npc.get_nombre_visual()), 9)
	if minutos < inicio_fase + retraso:
		return

	var habitantes: Array[Creature] = []
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if nodo is Creature and is_instance_valid(nodo):
			var asistente := nodo as Creature
			if bool(asistente.get_meta("rutina_en_edificio", false)) and str(asistente.get_meta("rutina_edificio_id", "")) == "castillo":
				habitantes.append(asistente)
	habitantes.sort_custom(func(a: Creature, b: Creature) -> bool:
		var id_a := a.get_personaje_game_id().strip_edges()
		var id_b := b.get_personaje_game_id().strip_edges()
		return id_a < id_b if id_a != id_b else a.get_nombre_visual() < b.get_nombre_visual()
	)
	var grupos := _formar_grupos_sociales_castillo(habitantes)
	var grupo_npc := -1
	var puesto_npc := -1
	for indice_grupo in range(grupos.size()):
		var grupo: Array = grupos[indice_grupo]
		var indice_puesto := grupo.find(npc)
		if indice_puesto >= 0:
			grupo_npc = indice_grupo
			puesto_npc = indice_puesto
			break
	if grupo_npc < 0:
		return

	var centros: Array[Vector2] = [
		Vector2(-170.0, -105.0), Vector2(-55.0, -105.0),
		Vector2(55.0, -105.0), Vector2(170.0, -105.0),
		Vector2(-170.0, 105.0), Vector2(-55.0, 105.0),
		Vector2(55.0, 105.0), Vector2(170.0, 105.0)
	]
	var offsets: Array[Vector2] = [
		Vector2(-24.0, 0.0), Vector2(24.0, 0.0), Vector2(0.0, 22.0)
	]
	var contenedor_npc := npc.get_parent() as Node2D
	if not is_instance_valid(contenedor_npc):
		return
	var centro: Vector2 = centros[posmod(grupo_npc, centros.size())]
	var destino_global := contenedor_npc.to_global(centro + offsets[puesto_npc])
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		return
	if npc.global_position.distance_to(destino_global) > DISTANCIA_LLEGADA:
		var ruta := _crear_ruta(npc.global_position, destino_global)
		if not ruta.is_empty():
			movimiento.establecer_ruta(ruta)
			npc.set_meta("rutina_en_transito", true)
		else:
			movimiento.detener_por_rutina()
			npc.set_meta("rutina_en_transito", false)
	else:
		movimiento.detener_por_rutina()
		npc.set_meta("rutina_en_transito", false)
	npc.set_meta("reunion_castillo_fase", fase)


## Construye grupos de hasta tres personas priorizando amistades y vínculos
## positivos. Los NPC sin una relación destacable conservan un espacio propio.
func _formar_grupos_sociales_castillo(habitantes: Array[Creature]) -> Array:
	var grupos: Array = []
	var disponibles: Array[Creature] = habitantes.duplicate()
	while not disponibles.is_empty():
		var primero: Creature = disponibles.pop_front()
		var grupo: Array[Creature] = [primero]
		var mejor_indice := -1
		var mejor_puntuacion := 8.0
		for indice in range(disponibles.size()):
			var puntuacion := _puntuacion_vinculo_castillo(primero, disponibles[indice])
			if puntuacion > mejor_puntuacion:
				mejor_puntuacion = puntuacion
				mejor_indice = indice
		if mejor_indice >= 0:
			grupo.append(disponibles.pop_at(mejor_indice))
			var mejor_tercero := -1
			var mejor_media := 6.0
			for indice in range(disponibles.size()):
				var candidato: Creature = disponibles[indice]
				var media := (
					_puntuacion_vinculo_castillo(grupo[0], candidato)
					+ _puntuacion_vinculo_castillo(grupo[1], candidato)
				) * 0.5
				if media > mejor_media:
					mejor_media = media
					mejor_tercero = indice
			if mejor_tercero >= 0:
				grupo.append(disponibles.pop_at(mejor_tercero))
		grupos.append(grupo)
	return grupos


## La puntuación combina amistad, confianza, afecto, colaboración y respeto;
## la tensión reduce la afinidad. No crea vínculos cuando los datos son neutros.
func _puntuacion_vinculo_castillo(a: Creature, b: Creature) -> float:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return -100.0
	var id_a := a.get_personaje_game_id().strip_edges()
	var id_b := b.get_personaje_game_id().strip_edges()
	if id_a.is_empty() or id_b.is_empty() or id_a == id_b:
		return -100.0
	var relacion: Dictionary = RelationshipSystem.obtener_relacion_entre_npc(id_a, id_b)
	if relacion.is_empty():
		return 0.0
	return (
		float(relacion.get("amistad", 0.0)) * 0.35
		+ float(relacion.get("confianza", 0.0)) * 0.20
		+ float(relacion.get("afecto", 0.0)) * 0.20
		+ float(relacion.get("colaboracion", 0.0)) * 0.15
		+ float(relacion.get("respeto", 0.0)) * 0.10
		- float(relacion.get("tension", 0.0)) * 0.35
	)


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


func _registrar_compra_habitante(npc: Creature, edificio_id: String) -> void:
	if not is_instance_valid(npc) or not bool(npc.get_meta("habitante_sin_oficio", false)):
		return
	var actividad := str(npc.get_meta("rutina_actual", ""))
	if not actividad.begins_with("comprar_"):
		return
	if not is_instance_valid(_world_atmosphere):
		return
	var tiempo := _world_atmosphere.obtener_tiempo()
	var clave_dia := "%s-%s-%s" % [
		str(tiempo.get("anio", 0)),
		str(tiempo.get("mes", 0)),
		str(tiempo.get("dia", 0))
	]
	var compras_variant: Variant = npc.get_meta("compras_realizadas", {})
	var compras: Dictionary = compras_variant.duplicate(true) if compras_variant is Dictionary else {}
	var clave_compra := clave_dia + "|" + actividad
	if compras.has(clave_compra):
		return
	var articulos := {
		"comprar_pan": "pan",
		"comprar_comida": "comida preparada",
		"comprar_mercaderia": "artículos de uso diario",
		"comprar_articulos": "artículos variados"
	}
	compras[clave_compra] = {
		"dia": clave_dia,
		"tienda": edificio_id,
		"actividad": actividad,
		"articulo": str(articulos.get(actividad, "provisiones"))
	}
	npc.set_meta("compras_realizadas", compras)
	npc.datos["ultima_compra_ambiental"] = compras[clave_compra]


## Evita que Ivo programe la compra de pan cuando Elian no trabaja
## en la panadería en ese tramo. No modifica la rutina del panadero.
func _el_npc_tiene_rutina_en_ubicacion(nombre_buscado: String, ubicacion_buscada: String, _dia_semana: int, _minutos: int) -> bool:
	for candidato_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not candidato_variant is Creature or not is_instance_valid(candidato_variant):
			continue
		var candidato := candidato_variant as Creature
		if candidato.get_nombre_visual().strip_edges().to_lower() != nombre_buscado:
			continue
		# Para sincronizar una compra compartida exigimos presencia física,
		# no basta con que el horario diga que el NPC va camino al local.
		return bool(candidato.get_meta("rutina_en_edificio", false)) and str(candidato.get_meta("rutina_edificio_id", "")) == ubicacion_buscada
	return false


func _buscar_npc_por_nombre(nombre_buscado: String) -> Creature:
	for candidato_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if candidato_variant is Creature and is_instance_valid(candidato_variant):
			var candidato := candidato_variant as Creature
			if candidato.get_nombre_visual().strip_edges().to_lower() == nombre_buscado:
				return candidato
	return null


## Cuando Ivo y Elian coinciden realmente dentro de la panadería, se anima
## una interacción ambiental discreta. No se crea ninguna copia ni se fuerza
## a ninguno a cambiar su horario.
## Reunión ocasional de Mara, Ivo y Nima. Sólo ocurre cuando la historia y
## los tres vínculos individuales ya justifican que compartan tiempo.
func _obtener_rutina_encuentro_trio(
	npc_actual: Creature,
	dia_semana: int,
	minutos: int,
	rutina_actual: Dictionary
) -> Dictionary:
	if minutos < 1020 or minutos >= 1140 or not is_instance_valid(_relationship_system):
		return {}
	if not _obtener_evento_comunitario(dia_semana, minutos).is_empty():
		return {}
	var nombres: Array[String] = ["mara", "ivo", "nima"]
	if npc_actual.get_nombre_visual().strip_edges().to_lower() not in nombres:
		return {}
	var progreso: Dictionary = {}
	if GameState.has_method("obtener_conversaciones_npc"):
		var progreso_variant: Variant = GameState.call("obtener_conversaciones_npc")
		if progreso_variant is Dictionary:
			progreso = progreso_variant
	var apoyo_variant: Variant = progreso.get("mara_ivo_apoyo", {})
	var investigacion_variant: Variant = progreso.get("nima_ivo_investigacion", {})
	if not apoyo_variant is Dictionary or not investigacion_variant is Dictionary:
		return {}
	if int((apoyo_variant as Dictionary).get("etapa", 0)) < 1 or int((investigacion_variant as Dictionary).get("etapa", 0)) < 1:
		return {}
	var participantes: Dictionary = {}
	for nombre in nombres:
		var participante := _buscar_npc_por_nombre(nombre)
		if not is_instance_valid(participante) or not participante.is_alive:
			return {}
		participantes[nombre] = participante
	var pares: Array[Array] = [["mara", "ivo"], ["mara", "nima"], ["ivo", "nima"]]
	for par in pares:
		var a := participantes[str(par[0])] as Creature
		var b := participantes[str(par[1])] as Creature
		var relacion := _relationship_system.obtener_relacion_entre_npc(
			a.get_personaje_game_id(), b.get_personaje_game_id()
		)
		if int(relacion.get("interacciones", 0)) < 1:
			return {}
		var cercania := float(relacion.get("amistad", 0.0)) + float(relacion.get("confianza", 0.0)) + float(relacion.get("afecto", 0.0)) + float(relacion.get("colaboracion", 0.0))
		if cercania < 0.5 or float(relacion.get("tension", 0.0)) >= 4.0:
			return {}
	var tiempo: Dictionary = _world_atmosphere.obtener_tiempo()
	var anio := int(tiempo.get("anio", 0))
	var semana := int((int(tiempo.get("dia", 1)) - 1) / 5)
	# Busca primero los días en que los tres tienen tiempo libre real. Luego
	# elige uno de forma estable para esa semana, sin interrumpir sus oficios.
	var dias_disponibles: Array[int] = []
	for dia_candidato in range(5):
		var todos_libres := true
		for nombre in nombres:
			var participante := participantes[nombre] as Creature
			var base: Dictionary
			var lista: Variant = participante.datos.get("rutinas", [])
			if dia_candidato == 4 and (not bool(participante.get_meta("habitante_sin_oficio", false)) or nombre in ["mara", "ivo", "nima"]):
				base = _seleccionar_rutina_dia_libre(participante, minutos)
			else:
				base = _seleccionar_rutina(lista, dia_candidato, minutos, participante.get_nombre_visual())
			if not _puede_participar_en_evento(base):
				todos_libres = false
				break
		if todos_libres:
			dias_disponibles.append(dia_candidato)
	if dias_disponibles.is_empty():
		return {}
	var indice_dia := posmod(hash("mara_ivo_nima|" + str(anio) + "|" + str(semana)), dias_disponibles.size())
	var dia_elegido := dias_disponibles[indice_dia]
	if dia_semana != dia_elegido or not _puede_participar_en_evento(rutina_actual):
		return {}
	# Comprueba también las invitaciones ya aceptadas de los otros dos.
	for nombre in nombres:
		var participante := participantes[nombre] as Creature
		var base_actual: Dictionary
		var lista_actual: Variant = participante.datos.get("rutinas", [])
		if dia_semana == 4 and (not bool(participante.get_meta("habitante_sin_oficio", false)) or nombre in ["mara", "ivo", "nima"]):
			base_actual = _seleccionar_rutina_dia_libre(participante, minutos)
		else:
			base_actual = _seleccionar_rutina(lista_actual, dia_semana, minutos, participante.get_nombre_visual())
		if not _obtener_rutina_invitacion(participante, base_actual, minutos).is_empty():
			return {}
	var posiciones: Dictionary = {
		"mara": Vector2(-42.0, 18.0),
		"ivo": Vector2(42.0, 18.0),
		"nima": Vector2(0.0, -32.0)
	}
	var posicion: Vector2 = posiciones[npc_actual.get_nombre_visual().strip_edges().to_lower()]
	return {
		"clave": "encuentro_trio_mara_ivo_nima",
		"ubicacion_clave": "plaza",
		"actividad_clave": "reunirse_con_amigos",
		"posicion_absoluta_plaza": posicion,
		"activo": true
	}


## Escalona los cambios de horario para que los habitantes no salgan todos a la vez.
func _esperar_desfase_cambio_rutina(npc: Creature, firma: String) -> bool:
	var tiempo: Dictionary = _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var dias_por_anio := maxi(1, int(_world_atmosphere.dias_por_anio)) if is_instance_valid(_world_atmosphere) else 365
	var dia_global := int(tiempo.get("anio", 0)) * dias_por_anio + int(tiempo.get("dia", 1))
	var minuto_global := dia_global * 1440 + int(tiempo.get("hora_del_dia", 0.0) * 60.0)
	var firma_pendiente := str(npc.get_meta("rutina_cambio_pendiente", ""))
	if firma_pendiente != firma:
		npc.set_meta("rutina_cambio_pendiente", firma)
		npc.set_meta("rutina_cambio_inicio", minuto_global)
	var id := npc.get_personaje_game_id().strip_edges()
	if id.is_empty():
		id = npc.get_nombre_visual().strip_edges().to_lower()
	var espera := posmod(hash(id + "|" + firma), 9)
	var inicio := int(npc.get_meta("rutina_cambio_inicio", minuto_global))
	if minuto_global - inicio < espera:
		return false
	npc.remove_meta("rutina_cambio_pendiente")
	npc.remove_meta("rutina_cambio_inicio")
	return true


## Pequeños recorridos dentro del edificio: los NPC no quedan congelados
## durante toda una franja horaria. Se activan sólo al abrir ese interior.
func _actualizar_rutina_interior(npc: Creature, edificio_id: String, minutos: int) -> void:
	if not is_instance_valid(npc):
		return
	if edificio_id == "castillo":
		return
	var interior_activo := bool(_zona.get("_interior_activo")) if is_instance_valid(_zona) else false
	var interior_actual := str(_zona.get("_entrada_interior_id")) if is_instance_valid(_zona) else ""
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if not interior_activo or interior_actual != edificio_id or npc.get_parent() == _zona:
		_detener_animacion_actividad_interior(npc)
		if bool(npc.get_meta("rutina_paseo_interior_activo", false)):
			if is_instance_valid(movimiento):
				movimiento.detener_por_rutina()
			npc.remove_meta("rutina_paseo_interior_activo")
			npc.set_meta("rutina_en_transito", false)
		return
	if not is_instance_valid(movimiento):
		return
	if bool(npc.get_meta("animacion_panaderia_activa", false)):
		return
	if bool(npc.get_meta("rutina_paseo_interior_activo", false)):
		if movimiento.rutina_terminada():
			npc.remove_meta("rutina_paseo_interior_activo")
			npc.set_meta("rutina_en_transito", false)
			var pausa := 3 + posmod(hash(npc.get_nombre_visual() + "|" + edificio_id + "|" + str(minutos / 5)), 8)
			npc.set_meta("rutina_paseo_interior_siguiente", posmod(minutos + pausa, 1440))
		return
	var siguiente := int(npc.get_meta("rutina_paseo_interior_siguiente", -1))
	if siguiente < 0:
		var espera_inicial := 1 + posmod(hash(npc.get_nombre_visual() + "|" + edificio_id), 6)
		npc.set_meta("rutina_paseo_interior_siguiente", posmod(minutos + espera_inicial, 1440))
		return
	if posmod(minutos - siguiente, 1440) > 720:
		return
	# Puntos compactos para que funcionen en interiores pequeños y grandes.
	# Cada personaje usa un orden distinto y no todos parten al mismo tiempo.
	var puntos: Array[Vector2] = [
		Vector2(-42.0, 12.0), Vector2(42.0, 12.0),
		Vector2(0.0, -18.0), Vector2(0.0, 38.0)
	]
	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	var indice := posmod(hash(nombre + "|" + edificio_id + "|" + str(minutos / 5)), puntos.size())
	var destino_local: Vector2 = puntos[indice]
	for otro_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not otro_variant is Creature or otro_variant == npc or not is_instance_valid(otro_variant):
			continue
		var otro := otro_variant as Creature
		if otro.get_parent() == npc.get_parent() and otro.position.distance_to(destino_local) < 38.0:
			destino_local = puntos[posmod(indice + 1, puntos.size())]
			break
	var contenedor := npc.get_parent() as Node2D
	if not is_instance_valid(contenedor):
		return
	var destino_global := contenedor.to_global(destino_local)
	if npc.global_position.distance_to(destino_global) <= DISTANCIA_LLEGADA:
		npc.set_meta("rutina_paseo_interior_siguiente", posmod(minutos + 3, 1440))
		return
	var ruta := PackedVector2Array([destino_global])
	movimiento.establecer_ruta(ruta)
	npc.set_meta("rutina_paseo_interior_activo", true)
	npc.set_meta("rutina_en_transito", true)


## Animaciones discretas según la tarea actual. No sustituyen sprites ni
## inventan gestos complejos: dan vida a las tareas mientras el NPC trabaja.
func _actualizar_animacion_actividad_interior(npc: Creature) -> void:
	if not is_instance_valid(npc):
		return
	if bool(npc.get_meta("rutina_en_transito", false)) or bool(npc.get_meta("animacion_panaderia_activa", false)):
		_detener_animacion_actividad_interior(npc)
		return
	var actividad := str(npc.get_meta("actividad_actual", npc.datos.get("actividad_actual", ""))).to_lower()
	if bool(npc.get_meta("animacion_actividad_interior_activa", false)):
		if str(npc.get_meta("animacion_actividad_interior_clave", "")) == actividad:
			return
		_detener_animacion_actividad_interior(npc)
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(sprite):
		return
	npc.set_meta("animacion_actividad_interior_activa", true)
	npc.set_meta("animacion_actividad_interior_clave", actividad)
	npc.set_meta("animacion_actividad_interior_posicion", sprite.position)
	npc.set_meta("animacion_actividad_interior_rotacion", sprite.rotation)
	npc.set_meta("animacion_actividad_interior_escala", sprite.scale)
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if actividad.contains("leer") or actividad.contains("nota") or actividad.contains("estudi") or actividad.contains("investig"):
		tween.tween_property(sprite, "rotation", 0.035, 0.9)
		tween.tween_interval(0.8)
		tween.tween_property(sprite, "rotation", 0.0, 0.45)
		tween.tween_interval(1.0)
	elif actividad.contains("forj") or actividad.contains("herramient") or actividad.contains("hornear") or actividad.contains("atender") or actividad.contains("trabaj"):
		tween.tween_property(sprite, "position:y", sprite.position.y - 1.0, 0.28)
		tween.tween_property(sprite, "position:y", sprite.position.y, 0.32)
		tween.tween_interval(0.4)
	else:
		tween.tween_property(sprite, "position:y", sprite.position.y - 0.7, 0.8)
		tween.tween_property(sprite, "position:y", sprite.position.y, 0.8)
		tween.tween_interval(0.7)
	npc.set_meta("animacion_actividad_interior_tween", tween)


func _detener_animacion_actividad_interior(npc: Creature) -> void:
	if not is_instance_valid(npc) or not bool(npc.get_meta("animacion_actividad_interior_activa", false)):
		return
	var tween_variant: Variant = npc.get_meta("animacion_actividad_interior_tween", null)
	if tween_variant is Tween and is_instance_valid(tween_variant):
		(tween_variant as Tween).kill()
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(sprite):
		var posicion: Variant = npc.get_meta("animacion_actividad_interior_posicion", sprite.position)
		var escala: Variant = npc.get_meta("animacion_actividad_interior_escala", sprite.scale)
		sprite.position = posicion if posicion is Vector2 else sprite.position
		sprite.scale = escala if escala is Vector2 else sprite.scale
		sprite.rotation = float(npc.get_meta("animacion_actividad_interior_rotacion", sprite.rotation))
	for clave in ["animacion_actividad_interior_activa", "animacion_actividad_interior_clave", "animacion_actividad_interior_posicion", "animacion_actividad_interior_rotacion", "animacion_actividad_interior_escala", "animacion_actividad_interior_tween"]:
		npc.remove_meta(clave)


## Pequeños paseos alrededor del punto asignado. Mantienen al NPC en su
## zona de actividad y usan rutas reales, con pausas individuales y sin sincronía.
func _actualizar_paseo_ambiental_exterior(npc: Creature, minutos: int) -> void:
	if not is_instance_valid(npc):
		return
	if (
		bool(npc.get_meta("rutina_en_edificio", false))
		or bool(npc.get_meta("rutina_en_transito", false))
		or bool(npc.get_meta("actividad_social_activa", false))
		or bool(npc.get_meta("acercamiento_social_activo", false))
		or bool(npc.get_meta("_conversacion_ambiental_activa", false))
		or bool(npc.get_meta("cinematica_npc_activa", false))
	):
		return
	if str(npc.get_meta("rutina_ubicacion", "")) != "plaza":
		return
	if str(npc.get_meta("rutina_actual", "")).begins_with("encuentro_trio_"):
		return
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if not is_instance_valid(movimiento):
		return
	if bool(npc.get_meta("rutina_paseo_exterior_activo", false)):
		if movimiento.rutina_terminada():
			npc.remove_meta("rutina_paseo_exterior_activo")
			npc.set_meta("rutina_en_transito", false)
			var nombre_pausa := npc.get_nombre_visual().strip_edges().to_lower()
			var pausa_base := 4
			var rango_pausa := 11
			match nombre_pausa:
				"ivo":
					pausa_base = 9
					rango_pausa = 12
				"mara", "darven", "bruna":
					pausa_base = 7
					rango_pausa = 10
				"nima", "saira", "elian":
					pausa_base = 3
					rango_pausa = 9
			var pausa := pausa_base + posmod(hash(nombre_pausa + "|exterior|" + str(minutos / 5)), rango_pausa)
			npc.set_meta("rutina_paseo_exterior_siguiente", posmod(minutos + pausa, 1440))
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(jugador) and jugador.global_position.distance_to(npc.global_position) < 58.0:
		npc.set_meta("rutina_paseo_exterior_siguiente", posmod(minutos + 1, 1440))
		return
	var siguiente := int(npc.get_meta("rutina_paseo_exterior_siguiente", -1))
	if siguiente < 0:
		var espera := 1 + posmod(hash(npc.get_nombre_visual() + "|plaza"), 8)
		npc.set_meta("rutina_paseo_exterior_siguiente", posmod(minutos + espera, 1440))
		return
	if posmod(minutos - siguiente, 1440) > 720:
		return
	if not is_instance_valid(_zona) or not _malla_lista:
		return
	if not npc.has_meta("rutina_ancla_ocio"):
		npc.set_meta("rutina_ancla_ocio", npc.global_position)
	var ancla: Vector2 = npc.get_meta("rutina_ancla_ocio", npc.global_position)
	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	var desplazamientos_por_personaje: Dictionary = {
		# Elian suele volver hacia el acceso de la panadería y detenerse a saludar.
		"elian": [Vector2(-24.0, -8.0), Vector2(-12.0, 22.0), Vector2(18.0, 12.0), Vector2(8.0, -24.0)],
		# Bruna hace recorridos cortos; no suele alejarse demasiado de su punto.
		"bruna": [Vector2(-14.0, 8.0), Vector2(12.0, -10.0), Vector2(18.0, 18.0)],
		# Darven mantiene una vuelta más amplia y ordenada por el perímetro.
		"darven": [Vector2(-30.0, -18.0), Vector2(28.0, -16.0), Vector2(30.0, 20.0), Vector2(-26.0, 24.0)],
		# Saira se mueve entre distintos sectores, como si revisara puestos y saludara.
		"saira": [Vector2(26.0, -22.0), Vector2(34.0, 8.0), Vector2(-18.0, 26.0), Vector2(-30.0, -8.0)],
		# Narel se detiene cerca de puntos de observación y cambia de dirección.
		"narel": [Vector2(-22.0, -26.0), Vector2(8.0, -34.0), Vector2(24.0, 6.0)],
		# Mara prefiere bordear la plaza y evitar el centro.
		"mara": [Vector2(-34.0, -12.0), Vector2(-26.0, 22.0), Vector2(12.0, 32.0)],
		# Ivo recorre distancias menores y descansa más entre paseos.
		"ivo": [Vector2(-12.0, 8.0), Vector2(12.0, -8.0), Vector2(18.0, 12.0)],
		# Nima alterna observación y pequeños cambios de posición.
		"nima": [Vector2(0.0, -30.0), Vector2(24.0, -18.0), Vector2(-18.0, -20.0), Vector2(12.0, 24.0)]
	}
	var desplazamientos: Array = desplazamientos_por_personaje.get(nombre, [
		Vector2(-28.0, -12.0), Vector2(24.0, -18.0),
		Vector2(32.0, 10.0), Vector2(-18.0, 28.0),
		Vector2(4.0, -34.0), Vector2(18.0, 32.0),
		Vector2(-34.0, 12.0)
	])
	var tiempo: Dictionary = _world_atmosphere.obtener_tiempo()
	var fecha := "%s|%s" % [str(tiempo.get("anio", 0)), str(tiempo.get("dia", 1))]
	var indice := posmod(hash(nombre + "|" + fecha + "|" + str(minutos / 5)), desplazamientos.size())
	var desplazamiento: Vector2 = desplazamientos[indice]
	var destino := ancla + desplazamiento
	for otro_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not otro_variant is Creature or otro_variant == npc or not is_instance_valid(otro_variant):
			continue
		var otro := otro_variant as Creature
		if not bool(otro.get_meta("rutina_en_edificio", false)) and otro.global_position.distance_to(destino) < 28.0:
			destino = ancla + desplazamientos[posmod(indice + 1, desplazamientos.size())]
			break
	var ruta := _crear_ruta(npc.global_position, destino)
	if ruta.is_empty():
		npc.set_meta("rutina_paseo_exterior_siguiente", posmod(minutos + 2, 1440))
		return
	movimiento.establecer_ruta(ruta)
	npc.set_meta("rutina_paseo_exterior_activo", true)
	npc.set_meta("rutina_en_transito", true)


func _actualizar_interaccion_panaderia() -> void:
	var ivo := _buscar_npc_por_nombre("ivo")
	var elian := _buscar_npc_por_nombre("elian")
	var coinciden := (
		is_instance_valid(ivo)
		and is_instance_valid(elian)
		and bool(ivo.get_meta("rutina_en_edificio", false))
		and bool(elian.get_meta("rutina_en_edificio", false))
		and str(ivo.get_meta("rutina_edificio_id", "")) == "panaderia"
		and str(elian.get_meta("rutina_edificio_id", "")) == "panaderia"
	)
	if coinciden:
		_iniciar_animacion_compartida_panaderia(ivo, "cliente")
		_iniciar_animacion_compartida_panaderia(elian, "panadero")
	else:
		_detener_animacion_compartida_panaderia(ivo)
		_detener_animacion_compartida_panaderia(elian)


func _iniciar_animacion_compartida_panaderia(npc: Creature, rol: String) -> void:
	if not is_instance_valid(npc) or bool(npc.get_meta("animacion_panaderia_activa", false)):
		return
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(sprite):
		return
	npc.set_meta("animacion_panaderia_activa", true)
	npc.set_meta("animacion_panaderia_rol", rol)
	npc.set_meta("animacion_panaderia_posicion", sprite.position)
	npc.set_meta("animacion_panaderia_rotacion", sprite.rotation)
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if rol == "cliente":
		# El cliente se inclina hacia el mostrador, espera y asiente como al recibir el pedido.
		tween.tween_property(sprite, "position:x", sprite.position.x - 2.0, 0.35)
		tween.tween_property(sprite, "position:y", sprite.position.y - 1.4, 0.28)
		tween.tween_property(sprite, "position:y", sprite.position.y, 0.28)
		tween.tween_property(sprite, "position:x", sprite.position.x, 0.35)
		tween.tween_interval(0.7)
	else:
		# El panadero responde con una inclinación y vuelve a su postura de trabajo.
		tween.tween_property(sprite, "rotation", 0.045, 0.35)
		tween.tween_property(sprite, "position:y", sprite.position.y - 1.0, 0.3)
		tween.tween_property(sprite, "position:y", sprite.position.y, 0.3)
		tween.tween_property(sprite, "rotation", -0.025, 0.35)
		tween.tween_property(sprite, "rotation", 0.0, 0.3)
		tween.tween_interval(0.65)
	npc.set_meta("animacion_panaderia_tween", tween)


func _detener_animacion_compartida_panaderia(npc: Creature) -> void:
	if not is_instance_valid(npc) or not bool(npc.get_meta("animacion_panaderia_activa", false)):
		return
	var tween_variant: Variant = npc.get_meta("animacion_panaderia_tween", null)
	if tween_variant is Tween and is_instance_valid(tween_variant):
		(tween_variant as Tween).kill()
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(sprite):
		var posicion: Variant = npc.get_meta("animacion_panaderia_posicion", sprite.position)
		sprite.position = posicion if posicion is Vector2 else sprite.position
		sprite.rotation = float(npc.get_meta("animacion_panaderia_rotacion", sprite.rotation))
	for clave in ["animacion_panaderia_activa", "animacion_panaderia_rol", "animacion_panaderia_posicion", "animacion_panaderia_rotacion", "animacion_panaderia_tween"]:
		npc.remove_meta(clave)


func _marcar_npc_dentro_edificio(npc: Creature, edificio_id: String) -> void:
	_registrar_compra_habitante(npc, edificio_id)
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
		"narel": ["tomar_notas", "observar_entorno", "leer_apuntes"],
		"mara": ["pasear_sin_prisa", "observar_la_plaza", "visitar_un_puesto"],
		"ivo": ["descansar_y_saludar", "sentarse_un_rato", "pasear_a_su_ritmo"],
		"nima": ["tomar_notas", "observar_fenomenos", "conversar_con_vecinos"],
		"abel": ["revisar_asuntos", "leer_informes", "conversar_con_guardias"],
		"liam": ["ordenar_documentos", "recorrer_el_castillo", "descansar_un_rato"]
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


## Convierte una invitación aceptada en una visita breve a la plaza.
## Sólo desplaza una rutina libre; nunca sustituye trabajo, guardia o descanso.
func _obtener_rutina_invitacion(npc: Creature, rutina_actual: Dictionary, minutos: int) -> Dictionary:
	if not is_instance_valid(npc) or not _puede_participar_en_evento(rutina_actual):
		return {}
	if minutos < 1020 or minutos >= 1140:
		return {}
	var personaje_id := npc.get_personaje_game_id().strip_edges()
	if personaje_id.is_empty():
		return {}
	var invitaciones_variant: Variant = GameState.world_state.flags.get("invitaciones_npc", {})
	if not invitaciones_variant is Dictionary:
		return {}
	var invitaciones: Dictionary = invitaciones_variant.duplicate(true)
	var invitacion_variant: Variant = invitaciones.get(personaje_id, {})
	if not invitacion_variant is Dictionary:
		return {}
	var invitacion := (invitacion_variant as Dictionary).duplicate(true)
	var tiempo: Dictionary = _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var anio_actual := int(tiempo.get("anio", 0))
	var dia_actual := int(tiempo.get("dia", 1))
	var anio_objetivo := int(invitacion.get("anio", -1))
	var dia_objetivo := int(invitacion.get("dia", -1))
	if anio_actual > anio_objetivo or (anio_actual == anio_objetivo and dia_actual > dia_objetivo):
		invitacion["estado"] = "caducada"
		invitaciones[personaje_id] = invitacion
		GameState.world_state.flags["invitaciones_npc"] = invitaciones
		if GameState.has_method("guardar_partida"):
			GameState.call_deferred("guardar_partida")
		return {}
	if (
		anio_objetivo != anio_actual
		or dia_objetivo != dia_actual
		or str(invitacion.get("estado", "")) != "aceptada"
	):
		return {}
	var hora_inicio := float(invitacion.get("hora_inicio", 17.0))
	var hora_fin := float(invitacion.get("hora_fin", 19.0))
	var hora_actual := float(minutos) / 60.0
	if hora_actual < hora_inicio or hora_actual >= hora_fin:
		return {}
	var ubicacion := str(invitacion.get("ubicacion_clave", "plaza")).strip_edges().to_lower()
	if not POSICIONES.has(ubicacion):
		ubicacion = "plaza"
	npc.set_meta("invitacion_npc_activa", true)
	return {
		"clave": "invitacion_aceptada",
		"ubicacion_clave": ubicacion,
		"actividad_clave": "esperar_encuentro_con_el_jugador",
		"activo": true
	}


## Calendario comunitario local de Torres. Usa el ciclo de cinco días que
## ya emplean las rutinas y el primer día de cada estación del calendario.
func _obtener_evento_comunitario(dia_semana: int, minutos: int) -> Dictionary:
	if not is_instance_valid(_world_atmosphere):
		return {}
	var tiempo: Dictionary = _world_atmosphere.obtener_tiempo()
	var dia_estacion := int(tiempo.get("dia_de_estacion", 0))
	if dia_estacion == 1 and minutos >= 840 and minutos < 1200:
		return {
			"clave": "celebracion_estacional",
			"nombre": "Celebración de temporada",
			"actividad": "celebrar_el_cambio_de_estacion",
			"aviso": "Hoy los vecinos celebran el comienzo de una nueva estación en la plaza."
		}
	if dia_semana != 4:
		return {}
	if minutos >= 540 and minutos < 1020:
		return {
			"clave": "mercado_vecinal",
			"nombre": "Mercado vecinal",
			"actividad": "visitar_el_mercado",
			"aviso": "Hoy hay mercado vecinal en la plaza de Torres."
		}
	if minutos >= 1020 and minutos < 1200:
		return {
			"clave": "comida_comunitaria",
			"nombre": "Comida comunitaria",
			"actividad": "compartir_comida_con_vecinos",
			"aviso": "Los vecinos se reúnen en la plaza para compartir comida."
		}
	return {}


func _puede_participar_en_evento(rutina: Dictionary) -> bool:
	if rutina.is_empty():
		return true
	var clave := str(rutina.get("clave", "")).strip_edges().to_lower()
	return clave.begins_with("dia_libre")


func _obtener_desplazamiento_evento(
	nombre_npc: String,
	clave_evento: String
) -> Vector2:
	var posiciones: Array[Vector2] = [
		Vector2(-112.0, -72.0), Vector2(-72.0, -104.0),
		Vector2(-24.0, -112.0), Vector2(32.0, -108.0),
		Vector2(88.0, -80.0), Vector2(112.0, -24.0),
		Vector2(96.0, 48.0), Vector2(48.0, 96.0),
		Vector2(-16.0, 112.0), Vector2(-80.0, 88.0),
		Vector2(-120.0, 32.0), Vector2(-48.0, -40.0),
		Vector2(16.0, -48.0), Vector2(64.0, 16.0),
		Vector2(8.0, 56.0), Vector2(-64.0, 8.0)
	]
	var tiempo: Dictionary = _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var fecha := "%s|%s|%s" % [
		str(tiempo.get("anio", 0)),
		str(tiempo.get("dia", 0)),
		str(tiempo.get("estacion_id", ""))
	]
	var indice := posmod(hash(nombre_npc.strip_edges().to_lower() + "|" + clave_evento + "|" + fecha), posiciones.size())
	return posiciones[indice]


func _notificar_evento_comunitario(evento: Dictionary) -> void:
	var tiempo: Dictionary = _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var firma := "%s|%s|%s" % [
		str(tiempo.get("anio", 0)),
		str(tiempo.get("dia", 0)),
		str(evento.get("clave", ""))
	]
	if firma == _ultimo_aviso_evento_comunitario:
		return
	_ultimo_aviso_evento_comunitario = firma
	var aviso := str(evento.get("aviso", evento.get("nombre", "Hay una actividad comunitaria en la plaza.")))
	Events.notification_pushed.emit(aviso)


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
		"liam": "castillo",
		"mara": "vivienda_oeste_01",
		"ivo": "vivienda_oeste_02",
		"nima": "vivienda_oeste_03"
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
			"mara":
				ubicacion = hogar
				actividad = "ordenar_sus_espacios"
			"ivo":
				ubicacion = hogar
				actividad = "descansar"
			"nima":
				ubicacion = "casa_estudio"
				actividad = "revisar_apuntes"
			"abel", "liam":
				ubicacion = "castillo"
				actividad = "atender_asuntos_del_castillo"
			_:
				ubicacion = "plaza"
	elif minutos >= 840 and minutos < 1020:
		clave = "dia_libre_tarde"
		actividad = "pasear"
		match nombre:
			"saira":
				ubicacion = "casa_comercio"
				actividad = "visitar_comerciantes"
			"narel", "nima":
				ubicacion = "casa_estudio"
				actividad = "visitar_estudio"
			"darven":
				ubicacion = "plaza"
				actividad = "descansar"
			"mara":
				ubicacion = "plaza"
				actividad = "pasear_sin_prisa"
			"ivo":
				ubicacion = "plaza"
				actividad = "descansar_y_saludar"
			"elian":
				ubicacion = hogar
				actividad = "descansar_del_trabajo"
			"bruna":
				ubicacion = hogar
				actividad = "revisar_sus_herramientas"
			"abel", "liam":
				ubicacion = "castillo"
				actividad = "organizar_asuntos_internos"
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
