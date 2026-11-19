extends Node
class_name NPCScheduleSystem

const NPC_SCHEDULE_RULES = preload("res://scripts/world/npc_schedule_rules.gd")

const INTERVALO_ACTUALIZACION := 0.5
const TAMANO_CELDA := 32.0
# Debe coincidir con el mapa de Torres: 104 x 68 celdas de 32 px.
const ORIGEN_MAPA := Vector2(-1664.0, -1088.0)
const TAMANO_MALLA := Vector2i(104, 68)
const RADIO_COLISION_NPC := 14.0
const DISTANCIA_LLEGADA := 7.0
const DISTANCIA_MAXIMA_UMBRAL := 36.0
# Coste de desplazamiento: Tierra (zona 1) conserva el coste base y los demás
# terrenos cuestan más. Mantener el mínimo en 1 preserva la heurística AStar.
const COSTE_CAMINO_TIERRA := 1.0
const COSTE_OTRO_TERRENO := 1.55
# Espera breve para agrupar varios cambios de posición/tamaño en una sola reconstrucción.
const ESPERA_RECONSTRUCCION_NAVEGACION := 1.0
# Saira coordina el mercado; dos de los otros vendedores se turnan por franja.
const VENDEDORES_MERCADO_ROTATIVOS: Array[String] = ["bruna", "elian", "darven", "narel", "nima", "mara", "ivo"]
const INICIO_TURNO_MERCADO := 9 * 60
const CAMBIO_TURNO_MERCADO := 14 * 60
const FIN_TURNO_MERCADO := 18 * 60

# Coordenadas locales relativas al origen de cada edificio. El destino real
# se sitúa 28 px al sur de este punto, en el umbral de la entrada.
# Se mantienen sincronizadas con ReinoTorres.ENTRADAS y SPRITE_BUILDINGS.
const ENTRADAS_INTERIORES: Dictionary = {
	"panaderia": {"id": "panaderia", "pos": Vector2(-360.0, -86.0)},
	"posada": {"id": "posada", "pos": Vector2(360.0, -81.0)},
	"forja": {"id": "forja", "pos": Vector2(-500.0, 214.0)},
	"cuartel": {"id": "cuartel", "pos": Vector2(520.0, -390.0)},
	"registro": {"id": "registro", "pos": Vector2(1480.0, 33.0)},
	"casa_comercio": {"id": "casa_comercio", "pos": Vector2(500.0, 218.0)},
	"archivo_real": {"id": "archivo_real", "pos": Vector2(-170.0, -245.0)},
	"sala_consejo": {"id": "sala_consejo", "pos": Vector2(170.0, -240.0)},
	"casa_estudio": {"id": "casa_estudio", "pos": Vector2(-520.0, -393.0)},
	"casa_elian": {"id": "casa_elian", "pos": Vector2(700.0, -324.0)},
	"casa_bruna": {"id": "casa_bruna", "pos": Vector2(-1000.0, -324.0)},
	"casa_darven": {"id": "casa_darven", "pos": Vector2(850.0, -324.0)},
	"casa_saira": {"id": "casa_saira", "pos": Vector2(1000.0, -324.0)},
	"casa_narel": {"id": "casa_narel", "pos": Vector2(-850.0, -324.0)},
	"castillo": {"id": "castillo", "pos": Vector2(0.0, -766.0)},
	"vivienda_oeste_01": {"id": "casa_vacia_01", "pos": Vector2(-700.0, -324.0)},
	"vivienda_oeste_02": {"id": "casa_vacia_02", "pos": Vector2(-1000.0, -74.0)},
	"vivienda_oeste_03": {"id": "casa_vacia_03", "pos": Vector2(-850.0, -74.0)},
	"vivienda_oeste_04": {"id": "casa_vacia_04", "pos": Vector2(-700.0, -74.0)},
	"vivienda_oeste_05": {"id": "casa_vacia_05", "pos": Vector2(-1000.0, 176.0)},
	"vivienda_oeste_06": {"id": "casa_vacia_06", "pos": Vector2(-850.0, 176.0)},
	"vivienda_oeste_07": {"id": "casa_vacia_07", "pos": Vector2(700.0, -74.0)},
	"vivienda_oeste_08": {"id": "casa_vacia_08", "pos": Vector2(850.0, -74.0)},
	"vivienda_oeste_10": {"id": "casa_vacia_10", "pos": Vector2(1000.0, -74.0)},
	"vivienda_oeste_11": {"id": "casa_vacia_11", "pos": Vector2(850.0, 176.0)},
	"casa_granjeros": {"id": "casa_granjeros", "pos": Vector2(950.0, 870.0)}
}

const POSICIONES: Dictionary = {
	"plaza": Vector2(0.0, 0.0),
	"panaderia": Vector2(-360.0, -86.0),
	"posada": Vector2(360.0, -81.0),
	"forja": Vector2(-500.0, 214.0),
	"cuartel": Vector2(520.0, -390.0),
	"registro": Vector2(1480.0, 33.0),
	"casa_comercio": Vector2(500.0, 218.0),
	"archivo_real": Vector2(-170.0, -245.0),
	"sala_consejo": Vector2(170.0, -240.0),
	"casa_estudio": Vector2(-520.0, -393.0),
	"casa_elian": Vector2(700.0, -324.0),
	"casa_bruna": Vector2(-1000.0, -324.0),
	"casa_darven": Vector2(850.0, -324.0),
	"casa_saira": Vector2(1000.0, -324.0),
	"casa_narel": Vector2(-850.0, -324.0),
	"castillo": Vector2(0.0, -766.0),
	"vivienda_oeste_01": Vector2(-700.0, -324.0),
	"vivienda_oeste_02": Vector2(-1000.0, -74.0),
	"vivienda_oeste_03": Vector2(-850.0, -74.0),
	"vivienda_oeste_04": Vector2(-700.0, -74.0),
	"vivienda_oeste_05": Vector2(-1000.0, 176.0),
	"vivienda_oeste_06": Vector2(-850.0, 176.0),
	"vivienda_oeste_07": Vector2(700.0, -74.0),
	"vivienda_oeste_08": Vector2(850.0, -74.0),
	"vivienda_oeste_10": Vector2(1000.0, -74.0),
	"vivienda_oeste_11": Vector2(850.0, 176.0),
	"casa_granjeros": Vector2(950.0, 870.0)
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
		# Un NPC muerto conserva su instancia para que el estado visual no se
		# confunda con una baja del catálogo, pero nunca debe reanudar rutinas.
		if not npc.is_alive:
			continue
		_actualizar_mente_npc(npc, minutos, tiempo)
		var es_hora_de_dormir := minutos >= 21 * 60 or minutos < 6 * 60
		if es_hora_de_dormir:
			# Las conversaciones ambientales también podían retener al NPC antes
			# de que el planificador aplicara su rutina de regreso al hogar.
			if bool(npc.get_meta("_conversacion_ambiental_activa", false)):
				npc.remove_meta("_conversacion_ambiental_activa")
				var movimiento_nocturno := npc.get_node_or_null("CreatureMovement") as CreatureMovement
				if is_instance_valid(movimiento_nocturno):
					movimiento_nocturno.detener_por_rutina()
				npc.set_meta("rutina_en_transito", false)
				npc.set_meta("rutina_firma", "")
			if bool(npc.get_meta("actividad_social_activa", false)) or bool(npc.get_meta("acercamiento_social_activo", false)):
				_finalizar_actividad_social(npc)
		if _actualizar_actividad_social(npc, delta):
			continue
		if _actualizar_objetivo_social_npc(npc, delta, minutos):
			continue
		# Los NPC exteriores pueden estar ocultos porque el jugador está dentro
		# de otro edificio. Sus horarios siguen avanzando en segundo plano.
		_aplicar_rutina(npc, dia_semana, minutos)
		_actualizar_paseo_ambiental_exterior(npc, minutos)
	_separar_npcs_superpuestos()
	# Si el jugador cargó una partida dentro de un edificio, algunos NPC
	# pueden materializarse después de reconstruir la habitación. Una vez que
	# sus rutinas están actualizadas, incorporar a los que trabajan allí.
	if is_instance_valid(_zona) and _zona.has_method("sincronizar_npcs_del_interior"):
		_zona.call("sincronizar_npcs_del_interior")
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
		if not npc.is_alive:
			continue
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
	var horario_nocturno := minutos >= 21 * 60 or minutos < 6 * 60
	if horario_nocturno and (bool(npc.get_meta("acercamiento_social_activo", false)) or bool(npc.get_meta("actividad_social_activa", false))):
		# Cancela acercamientos y charlas iniciadas antes de la hora de dormir.
		_finalizar_actividad_social(npc)
	elif bool(npc.get_meta("acercamiento_social_activo", false)) or bool(npc.get_meta("actividad_social_activa", false)):
		return
	var rutinas_variant: Variant = npc.datos.get("rutinas", [])
	var rutina: Dictionary
	var nombre_para_descanso := npc.get_nombre_visual().strip_edges().to_lower()
	# Elian mantiene la panadería abierta durante la última hora de compras.
	# Es un ajuste local de la simulación: no modifica horarios canónicos en Supabase.
	if nombre_para_descanso == "elian" and rutinas_variant is Array:
		var rutinas_elian: Array = (rutinas_variant as Array).duplicate(true)
		for indice_rutina in range(rutinas_elian.size()):
			var rutina_variant: Variant = rutinas_elian[indice_rutina]
			if rutina_variant is Dictionary and str(rutina_variant.get("clave", "")) == "cerrar_panaderia":
				var cierre: Dictionary = rutina_variant.duplicate(true)
				cierre["hora_fin"] = "17:00"
				rutinas_elian[indice_rutina] = cierre
		rutinas_variant = rutinas_elian
	# El índice 4 representa el día número 5 del calendario: descanso para
	# todos los NPC con oficio. Los habitantes sin oficio conservan sus rutinas.
	if dia_semana == 4 and (not bool(npc.get_meta("habitante_sin_oficio", false)) or nombre_para_descanso in ["mara", "ivo", "nima"]):
		rutina = _seleccionar_rutina_dia_libre(npc, minutos)
	else:
		rutina = _seleccionar_rutina(rutinas_variant, dia_semana, minutos, npc.get_nombre_visual())

	# La reunión nocturna se añade después como actividad social opcional
	# para grupos disponibles; trabajo, invitaciones y eventos conservan prioridad.

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
		npc.set_meta("evento_comunitario_datos", evento_comunitario.duplicate(true))
		_notificar_evento_comunitario(evento_comunitario)
	else:
		npc.set_meta("evento_comunitario_actual", "")
		npc.remove_meta("evento_comunitario_datos")

	# El encuentro de tres sólo puede usar tiempo libre que no esté reservado
	# por invitaciones ni acontecimientos comunitarios.
	var encuentro_trio := _obtener_rutina_encuentro_trio(npc, dia_semana, minutos, rutina)
	if not encuentro_trio.is_empty():
		rutina = encuentro_trio

	# En horario comercial, algunos vecinos cubren puestos por turnos.
	# Los trabajos esenciales y los eventos comunitarios conservan prioridad.
	rutina = _aplicar_turno_comercio_rotativo(npc, rutina, dia_semana, minutos)

	var nombre_npc := npc.get_nombre_visual().strip_edges().to_lower()
	if nombre_npc in ["abel", "liam"] and (not rutinas_variant is Array or (rutinas_variant as Array).is_empty()) and dia_semana != 4:
		rutina = _seleccionar_rutina_respaldo_castillo(minutos)

	# Prioridad nocturna global: ninguna rutina de ocio, evento comunitario,
	# invitación o encuentro puede concentrar habitantes en la plaza/castillo.
	# Cada NPC vuelve a su hogar para dormir; los turnos laborales explícitos
	# se mantienen únicamente si están marcados como trabajo/guardia.
	var hora_nocturna := minutos >= 21 * 60 or minutos < 6 * 60
	if hora_nocturna:
		var actividad_previa := str(rutina.get("actividad_clave", "")).strip_edges().to_lower()
		var es_turno_esencial := (
			actividad_previa.contains("trabaj")
			or actividad_previa.contains("guard")
			or actividad_previa.contains("vigilar")
			or actividad_previa.contains("investig")
		)
		if not es_turno_esencial:
			var hogar_nocturno := str(npc.datos.get("hogar_clave", obtener_clave_hogar(npc.get_nombre_visual(), "plaza"))).strip_edges().to_lower()
			if not POSICIONES.has(hogar_nocturno):
				hogar_nocturno = obtener_clave_hogar(npc.get_nombre_visual(), "plaza")
			rutina = {
				"clave": "dormir_en_hogar",
				"ubicacion_clave": hogar_nocturno,
				"actividad_clave": "dormir"
			}
			npc.set_meta("evento_comunitario_actual", "")
			npc.remove_meta("evento_comunitario_datos")
			npc.remove_meta("grupo_social_castillo_id")
			npc.remove_meta("grupo_social_castillo_nombres")
			npc.remove_meta("puesto_social_castillo")
			npc.remove_meta("reunion_castillo_fase")
			npc.remove_meta("reunion_castillo_firma_asistentes")
			npc.remove_meta("reunion_castillo_dia")

	# Las reuniones nocturnas automáticas están desactivadas: al llegar la noche,
	# los habitantes libres deben regresar a sus hogares para dormir.

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
	if clave_rutina != "reunion_nocturna_castillo":
		for clave_social_castillo in [
			"grupo_social_castillo_id", "grupo_social_castillo_nombres",
			"puesto_social_castillo", "reunion_castillo_fase",
			"reunion_castillo_firma_asistentes", "reunion_castillo_dia"
		]:
			npc.remove_meta(clave_social_castillo)
	var ubicacion := str(rutina.get("ubicacion_clave", hogar)).strip_edges().to_lower()
	var actividad := str(rutina.get("actividad_clave", "volver_a_casa" if not esta_en_horario else "descansar")).strip_edges()
	if actividad.is_empty():
		actividad = "descansar"
	# Cuando termina el horario y no hay una actividad especial, cada habitante
	# regresa a su hogar al comenzar la noche. Las reuniones, invitaciones y
	# turnos activos conservan prioridad porque ya producen una rutina propia.
	if not esta_en_horario and (minutos >= 21 * 60 or minutos < 6 * 60):
		clave_rutina = "dormir_en_hogar"
		ubicacion = hogar
		actividad = "dormir"
	# Ivo sólo va a comprar pan si Elian tiene turno en la panadería en
	# este mismo tramo. Si no coincide, aprovecha ese rato en la plaza.
	if nombre_npc == "ivo" and ubicacion == "panaderia" and not _el_npc_tiene_rutina_en_ubicacion("elian", "panaderia", dia_semana, minutos):
		clave_rutina = "ivo_paseo_sin_panadero"
		ubicacion = "plaza"
		actividad = "pasear_y_saludar"
		rutina["actividad_clave"] = actividad
		rutina["variacion_posicion"] = Vector2(18.0, 132.0)

	# Conserva una actividad significativa del día para que las charlas
	# nocturnas puedan comentar trabajo, paseos o investigaciones recientes.
	var tiempo_resumen: Dictionary = _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var dia_resumen := "%s:%s" % [str(tiempo_resumen.get("anio", 0)), str(tiempo_resumen.get("dia", 1))]
	if str(npc.get_meta("resumen_dia_reunion_clave", "")) != dia_resumen:
		npc.set_meta("resumen_dia_reunion_clave", dia_resumen)
		npc.set_meta("resumen_dia_reunion_actividad", "")
		npc.set_meta("resumen_dia_reunion_rutina", "")
		npc.set_meta("resumen_dia_reunion_ubicacion", "")
	if clave_rutina != "reunion_nocturna_castillo":
		var actividad_resumen := actividad.strip_edges().to_lower()
		var es_descanso := (
			actividad_resumen.is_empty()
			or actividad_resumen.contains("descans")
			or actividad_resumen.contains("dorm")
			or actividad_resumen.contains("volver")
		)
		if not es_descanso:
			npc.set_meta("resumen_dia_reunion_actividad", actividad)
			npc.set_meta("resumen_dia_reunion_rutina", clave_rutina)
			npc.set_meta("resumen_dia_reunion_ubicacion", ubicacion)
	elif str(npc.get_meta("resumen_dia_reunion_actividad", "")).strip_edges().is_empty():
		npc.set_meta("resumen_dia_reunion_actividad", str(npc.get_meta("actividad_actual", npc.datos.get("actividad_actual", ""))))
		npc.set_meta("resumen_dia_reunion_rutina", str(npc.get_meta("rutina_actual", "")))
		npc.set_meta("resumen_dia_reunion_ubicacion", str(npc.get_meta("rutina_ubicacion", "")))

	if ubicacion.is_empty() or ubicacion == "null" or not POSICIONES.has(ubicacion):
		ubicacion = hogar

	# La lluvia modifica temporalmente las actividades al aire libre.
	# Los NPC que ya están dentro o cuyo trabajo ocurre en un edificio continúan allí.
	var clima_lluvioso := _esta_lloviendo_en_posicion(npc.global_position)
	var esta_en_edificio := bool(npc.get_meta("rutina_en_edificio", false))
	if not clima_lluvioso:
		npc.remove_meta("refugio_lluvia_clave")
		npc.remove_meta("reaccion_climatica")
	elif esta_en_edificio and clave_rutina != "reunion_nocturna_castillo":
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
	elif clave_rutina != "reunion_nocturna_castillo" and not ENTRADAS_INTERIORES.has(ubicacion):
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
	if firma_anterior != firma_nueva:
		if not _esperar_desfase_cambio_rutina(npc, firma_nueva):
			return
		npc.remove_meta("rutina_paseo_exterior_activo")
		npc.remove_meta("rutina_paseo_exterior_siguiente")
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
		if (
			is_instance_valid(_zona)
			and not bool(_zona.get("_interior_activo"))
			and _zona.has_method("restaurar_colision_npc")
		):
			_zona.call("restaurar_colision_npc", npc)
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
		_actualizar_rutina_interior(npc, edificio_actual, minutos, actividad)
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
		npc.set_meta("rutina_destino_es_edificio", not edificio_id.is_empty())
		npc.set_meta("rutina_edificio_objetivo", edificio_id)
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
	npc.set_meta("rutina_destino_es_edificio", not edificio_id.is_empty())
	npc.set_meta("rutina_edificio_objetivo", edificio_id)
	npc.datos["actividad_actual"] = actividad
	# La observación se intenta después de resolver el desplazamiento y actualizar
	# la rutina; así sólo cuenta cuando el NPC ya llegó al punto del evento.
	if (
		not evento_comunitario.is_empty()
		and str(rutina.get("clave", "")) == str(evento_comunitario.get("clave", ""))
	):
		_registrar_observacion_evento_comunitario(npc, evento_comunitario)


## Agrupa a los asistentes según sus vínculos reales y distribuye sus
## desplazamientos durante la fase para que no abandonen todos la conversación.
func _actualizar_movimiento_reunion_castillo(npc: Creature, minutos: int) -> void:
	if not is_instance_valid(npc) or not is_instance_valid(_zona) or not _malla_lista:
		return
	var fase := maxi(0, int((minutos - 1260) / 45))
	var inicio_fase := 1260 + fase * 45
	var id_npc := npc.get_personaje_game_id().strip_edges()
	var retraso := posmod(hash(id_npc if not id_npc.is_empty() else npc.get_nombre_visual()), 9)
	if minutos < inicio_fase + retraso:
		return

	var habitantes: Array[Creature] = []
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if nodo is Creature and is_instance_valid(nodo) and not nodo.is_queued_for_deletion():
			var asistente := nodo as Creature
			var asiste_reunion := (
				asistente.is_alive
				and (
					asistente == npc
					or str(asistente.get_meta("rutina_actual", "")) == "reunion_nocturna_castillo"
				)
			)
			if asiste_reunion:
				habitantes.append(asistente)
	habitantes.sort_custom(func(a: Creature, b: Creature) -> bool:
		var id_a := a.get_personaje_game_id().strip_edges()
		var id_b := b.get_personaje_game_id().strip_edges()
		return id_a < id_b if id_a != id_b else a.get_nombre_visual() < b.get_nombre_visual()
	)
	var ids_asistentes: Array[String] = []
	for asistente in habitantes:
		var id_asistente := asistente.get_personaje_game_id().strip_edges()
		ids_asistentes.append(id_asistente if not id_asistente.is_empty() else asistente.get_nombre_visual().to_lower())
	var firma_asistentes := "|".join(ids_asistentes)
	if (
		int(npc.get_meta("reunion_castillo_fase", -1)) == fase
		and str(npc.get_meta("reunion_castillo_firma_asistentes", "")) == firma_asistentes
	):
		return
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

	# Doce sectores separados para hasta 36 asistentes en grupos de tres.
	# Si el elenco crece, las filas adicionales se calculan sin reutilizar plazas.
	var centros: Array[Vector2] = []
	for fila in range(3):
		for columna in range(4):
			centros.append(Vector2(-165.0 + columna * 110.0, -100.0 + fila * 100.0))
	var centro_grupo: Vector2
	if grupo_npc < centros.size():
		centro_grupo = centros[grupo_npc]
	else:
		var fila_extra := int(grupo_npc / 4)
		var columna_extra := posmod(grupo_npc, 4)
		centro_grupo = Vector2(-165.0 + columna_extra * 110.0, -100.0 + fila_extra * 100.0)
	var offsets: Array[Vector2] = [
		Vector2(-24.0, 0.0), Vector2(24.0, 0.0), Vector2(0.0, 22.0)
	]
	var contenedor_npc := npc.get_parent() as Node2D
	if not is_instance_valid(contenedor_npc):
		return
	var cantidad_integrantes := maxi(1, (grupos[grupo_npc] as Array).size())
	var puesto_destino := posmod(puesto_npc + fase, cantidad_integrantes)
	puesto_destino = mini(puesto_destino, offsets.size() - 1)
	var destino_global := contenedor_npc.to_global(centro_grupo + offsets[puesto_destino])
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
	var nombres_grupo: Array[String] = []
	for integrante_variant in grupos[grupo_npc]:
		if integrante_variant is Creature and is_instance_valid(integrante_variant):
			nombres_grupo.append((integrante_variant as Creature).get_nombre_visual())
	for integrante_variant in grupos[grupo_npc]:
		if integrante_variant is Creature and is_instance_valid(integrante_variant):
			var integrante := integrante_variant as Creature
			integrante.set_meta("grupo_social_castillo_id", grupo_npc)
			integrante.set_meta("grupo_social_castillo_nombres", nombres_grupo.duplicate())
			integrante.set_meta("puesto_social_castillo", grupos[grupo_npc].find(integrante))
			integrante.set_meta("reunion_castillo_dia", str(_world_atmosphere.obtener_tiempo().get("anio", 0)) + ":" + str(_world_atmosphere.obtener_tiempo().get("dia", 1)))
	npc.set_meta("reunion_castillo_fase", fase)
	npc.set_meta("reunion_castillo_firma_asistentes", firma_asistentes)


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
		# El quinto día ya tiene mercado y comida comunitaria en esta franja;
		# no se debe elegir como fecha para una reunión privada del trío.
		if dia_candidato == 4:
			continue
		var todos_libres := true
		for nombre in nombres:
			var participante := participantes[nombre] as Creature
			var base: Dictionary
			var lista: Variant = participante.datos.get("rutinas", [])
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
		# El día 5 está excluido de los candidatos del encuentro privado;
		# aquí sólo se evalúan horarios ordinarios de los días 1 a 4.
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


## Traduce la intención de una actividad a tipos de mobiliario disponibles.
## Se usa para escoger un puesto físico y probar la regla sin escenas.
static func obtener_preferencias_mueble_actividad(actividad: String) -> Array[String]:
	var texto := actividad.strip_edges().to_lower()
	if texto.contains("dorm") or texto.contains("descans"):
		return ["cama", "litera"]
	if texto.contains("sentar"):
		return ["silla", "asiento"]
	if texto.contains("leer") or texto.contains("estudi") or texto.contains("investig") or texto.contains("observar") or texto.contains("nota") or texto.contains("informe"):
		return ["mesa", "consulta", "estudio", "muestra"]
	if texto.contains("hornear") or texto.contains("cocinar") or texto.contains("preparar") or texto.contains("forj") or texto.contains("repar") or texto.contains("herramient") or texto.contains("trabaj"):
		return ["horno", "hogar", "banco", "mesa", "mostrador"]
	if texto.contains("atender_puesto_comercio"):
		return ["puesto"]
	if texto.contains("comer") or texto.contains("servir") or texto.contains("atender") or texto.contains("convers") or texto.contains("reunir"):
		return ["mesa", "mostrador"]
	return []


## Pequeños recorridos dentro del edificio: los NPC no quedan congelados
## durante toda una franja horaria. Se activan sólo al abrir ese interior.
func _actualizar_rutina_interior(npc: Creature, edificio_id: String, minutos: int, actividad: String) -> void:
	if not is_instance_valid(npc):
		return
	if bool(npc.get_meta("cinematica_npc_activa", false)) or bool(npc.get_meta("_conversacion_ambiental_activa", false)):
		_detener_animacion_actividad_interior(npc)
		return
	if edificio_id == "castillo":
		return
	var interior_activo := bool(_zona.get("_interior_activo")) if is_instance_valid(_zona) else false
	var interior_actual := str(_zona.get("_entrada_interior_id")) if is_instance_valid(_zona) else ""
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	var padre_npc := npc.get_parent()
	var esta_en_cuarto := is_instance_valid(padre_npc) and str(padre_npc.name) == "Habitacion_" + edificio_id
	if not interior_activo or interior_actual != edificio_id or not esta_en_cuarto:
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
	# Primero busca un puesto junto al mueble que corresponde a la tarea.
	# Si el edificio no tiene ese mueble, conserva los puntos de paseo generales.
	var puntos: Array[Vector2] = []
	var hora_de_dormir := minutos >= 21 * 60 or minutos < 6 * 60
	var postura := ""
	if actividad.to_lower().contains("dorm") or (actividad.to_lower().contains("descans") and hora_de_dormir):
		postura = "dormir"
	elif actividad.to_lower().contains("sentar") or actividad.to_lower().contains("descans"):
		postura = "sentado"
	npc.set_meta("postura_npc", postura)
	if npc.has_method("_actualizar_sprite_direccional_npc"):
		npc.call("_actualizar_sprite_direccional_npc")
	var preferencias := obtener_preferencias_mueble_actividad(
		"dormir" if postura == "dormir" else ("sentarse" if postura == "sentado" else actividad)
	)
	if not preferencias.is_empty():
		for hijo in npc.get_parent().get_children():
			if not hijo is Sprite2D:
				continue
			var mueble := hijo as Sprite2D
			var nombre_mueble := mueble.name.strip_edges().to_lower()
			var coincide := false
			for preferencia in preferencias:
				if nombre_mueble.contains(preferencia):
					coincide = true
					break
			if not coincide or not is_instance_valid(mueble.texture):
				continue
			var semiancho := mueble.texture.get_width() * absf(mueble.scale.x) * 0.5
			var semialto := mueble.texture.get_height() * absf(mueble.scale.y) * 0.5
			var puesto := mueble.position + Vector2(0.0, semialto + 12.0)
			if nombre_mueble.contains("cama") or nombre_mueble.contains("litera"):
				puesto = mueble.position + Vector2(semiancho + 12.0, 0.0)
			puntos.append(puesto)
	if puntos.is_empty():
		puntos = [
			Vector2(-42.0, 12.0), Vector2(42.0, 12.0),
			Vector2(0.0, -18.0), Vector2(0.0, 38.0)
		]
	# Cada personaje usa un orden distinto y no todos parten al mismo tiempo.
	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	var indice := posmod(hash(nombre + "|" + edificio_id + "|" + str(minutos / 5)), puntos.size())
	var destino_local := Vector2.ZERO
	var destino_disponible := false
	for desplazamiento_punto in range(puntos.size()):
		var candidato: Vector2 = puntos[posmod(indice + desplazamiento_punto, puntos.size())]
		var ocupado := false
		for otro_variant in get_tree().get_nodes_in_group("torres_game_npc"):
			if not otro_variant is Creature or otro_variant == npc or not is_instance_valid(otro_variant):
				continue
			var otro := otro_variant as Creature
			if otro.get_parent() != npc.get_parent():
				continue
			if otro.position.distance_to(candidato) < 38.0:
				ocupado = true
				break
		if not ocupado:
			destino_local = candidato
			destino_disponible = true
			break
	if not destino_disponible:
		npc.set_meta("rutina_paseo_interior_siguiente", posmod(minutos + 3, 1440))
		return
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
	if bool(npc.get_meta("rutina_en_transito", false)) or bool(npc.get_meta("animacion_panaderia_activa", false)) or bool(npc.get_meta("cinematica_npc_activa", false)) or bool(npc.get_meta("_conversacion_ambiental_activa", false)):
		_detener_animacion_actividad_interior(npc)
		return
	var actividad := str(npc.get_meta("actividad_actual", npc.datos.get("actividad_actual", ""))).to_lower()
	var postura_actual := str(npc.get_meta("postura_npc", ""))
	var clave_animacion := actividad + "|" + postura_actual
	if bool(npc.get_meta("animacion_actividad_interior_activa", false)):
		if str(npc.get_meta("animacion_actividad_interior_clave", "")) == clave_animacion:
			return
		_detener_animacion_actividad_interior(npc)
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(sprite):
		return
	npc.set_meta("animacion_actividad_interior_activa", true)
	npc.set_meta("animacion_actividad_interior_clave", clave_animacion)
	npc.set_meta("animacion_actividad_interior_posicion", sprite.position)
	npc.set_meta("animacion_actividad_interior_rotacion", sprite.rotation)
	npc.set_meta("animacion_actividad_interior_escala", sprite.scale)
	var tween := npc.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var postura := str(npc.get_meta("postura_npc", ""))
	if postura == "dormir" or postura == "sentado":
		var padre := npc.get_parent()
		var tokens := ["cama", "litera"] if postura == "dormir" else ["silla", "asiento"]
		var mueble_objetivo: Sprite2D = null
		if is_instance_valid(padre):
			for hijo in padre.get_children():
				if not hijo is Sprite2D:
					continue
				var nombre_mueble := str(hijo.name).to_lower()
				for token in tokens:
					if nombre_mueble.contains(token):
						mueble_objetivo = hijo as Sprite2D
						break
				if is_instance_valid(mueble_objetivo):
					break
		var destino_sprite := sprite.position
		if is_instance_valid(mueble_objetivo):
			destino_sprite = mueble_objetivo.position - npc.position
			destino_sprite.y -= 5.0 if postura == "sentado" else 0.0
		var origen_sprite := sprite.position
		tween.tween_property(sprite, "position", origen_sprite + Vector2(0.0, -10.0), 0.16)
		tween.tween_property(sprite, "position", destino_sprite, 0.18)
		tween.tween_callback(Callable(self, "_iniciar_idle_postura_npc").bind(npc, sprite, postura, destino_sprite))
	elif actividad.contains("leer") or actividad.contains("nota") or actividad.contains("estudi") or actividad.contains("investig"):
		tween.tween_property(sprite, "rotation", 0.035, 0.9)
		tween.tween_interval(0.8)
		tween.tween_property(sprite, "rotation", 0.0, 0.45)
		tween.tween_interval(1.0)
	elif actividad.contains("vigilar") or actividad.contains("observar") or actividad.contains("recorrer"):
		tween.tween_property(sprite, "rotation", -0.025, 0.8)
		tween.tween_interval(0.55)
		tween.tween_property(sprite, "rotation", 0.025, 0.8)
		tween.tween_property(sprite, "rotation", 0.0, 0.45)
		tween.tween_interval(0.7)
	elif actividad.contains("forj") or actividad.contains("herramient") or actividad.contains("hornear") or actividad.contains("atender") or actividad.contains("trabaj") or actividad.contains("limpiar") or actividad.contains("ordenar") or actividad.contains("revisar") or actividad.contains("preparar") or actividad.contains("organizar") or actividad.contains("cuidar") or actividad.contains("reparar") or actividad.contains("comerci") or actividad.contains("comprar"):
		tween.tween_property(sprite, "position:y", sprite.position.y - 1.0, 0.28)
		tween.tween_property(sprite, "position:y", sprite.position.y, 0.32)
		tween.tween_interval(0.4)
	else:
		tween.tween_property(sprite, "position:y", sprite.position.y - 0.7, 0.8)
		tween.tween_property(sprite, "position:y", sprite.position.y, 0.8)
		tween.tween_interval(0.7)
	npc.set_meta("animacion_actividad_interior_tween", tween)




func _iniciar_idle_postura_npc(npc: Creature, sprite: Sprite2D, postura: String, destino: Vector2) -> void:
	if not is_instance_valid(npc) or not is_instance_valid(sprite):
		return
	var tween := npc.create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if postura == "dormir":
		tween.tween_property(sprite, "scale:y", sprite.scale.y * 1.025, 1.1)
		tween.tween_property(sprite, "scale:y", sprite.scale.y / 1.025, 1.1)
	else:
		tween.tween_property(sprite, "position:y", destino.y - 0.8, 0.65)
		tween.tween_property(sprite, "position:y", destino.y, 0.65)
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
	npc.remove_meta("postura_npc")
	if npc.has_method("_actualizar_sprite_direccional_npc"):
		npc.call("_actualizar_sprite_direccional_npc")
	for clave in ["animacion_actividad_interior_activa", "animacion_actividad_interior_clave", "animacion_actividad_interior_posicion", "animacion_actividad_interior_rotacion", "animacion_actividad_interior_escala", "animacion_actividad_interior_tween"]:
		npc.remove_meta(clave)


## Idle exterior con variaciones pequeñas por personaje. Se detiene durante
## conversaciones, desplazamientos y cinemáticas para no competir con sus gestos.
func _actualizar_animacion_ocio_exterior(npc: Creature) -> void:
	if not is_instance_valid(npc) or bool(npc.get_meta("animacion_ocio_exterior_activa", false)):
		return
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if not is_instance_valid(sprite):
		return
	npc.set_meta("animacion_ocio_exterior_activa", true)
	npc.set_meta("animacion_ocio_exterior_posicion", sprite.position)
	npc.set_meta("animacion_ocio_exterior_rotacion", sprite.rotation)
	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	var posicion_base := sprite.position
	var rotacion_base := sprite.rotation
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	match nombre:
		"mara":
			# Mira brevemente alrededor y vuelve a una postura reservada.
			tween.tween_property(sprite, "rotation", rotacion_base + 0.025, 1.1)
			tween.tween_interval(1.0)
			tween.tween_property(sprite, "rotation", rotacion_base, 0.55)
			tween.tween_interval(1.4)
		"nima", "narel":
			# Pequeñas inclinaciones, como si observaran algo con curiosidad.
			tween.tween_property(sprite, "rotation", rotacion_base - 0.025, 0.75)
			tween.tween_property(sprite, "rotation", rotacion_base, 0.5)
			tween.tween_interval(1.1)
		"bruna":
			# Cambia el peso de un lado a otro, sin abandonar su sitio.
			tween.tween_property(sprite, "position:x", posicion_base.x + 0.45, 0.8)
			tween.tween_property(sprite, "rotation", rotacion_base - 0.018, 0.45)
			tween.tween_property(sprite, "position:x", posicion_base.x, 0.8)
			tween.tween_property(sprite, "rotation", rotacion_base, 0.45)
			tween.tween_interval(0.9)
		"darven":
			# Una mirada breve a ambos lados, propia de alguien atento al entorno.
			tween.tween_property(sprite, "rotation", rotacion_base + 0.018, 0.65)
			tween.tween_interval(0.45)
			tween.tween_property(sprite, "rotation", rotacion_base - 0.018, 0.65)
			tween.tween_property(sprite, "rotation", rotacion_base, 0.45)
			tween.tween_interval(1.0)
		"saira":
			# Se acomoda suavemente antes de continuar observando la plaza.
			tween.tween_property(sprite, "position:x", posicion_base.x - 0.45, 0.9)
			tween.tween_property(sprite, "position:x", posicion_base.x, 0.9)
			tween.tween_interval(1.0)
		"ivo":
			# Movimiento más lento y pausado para sus descansos.
			tween.tween_property(sprite, "position:y", posicion_base.y - 0.35, 1.6)
			tween.tween_property(sprite, "position:y", posicion_base.y, 1.6)
			tween.tween_interval(1.4)
		"elian":
			# Una animación tranquila mientras descansa fuera de la panadería.
			tween.tween_property(sprite, "position:y", posicion_base.y - 0.5, 1.1)
			tween.tween_property(sprite, "position:y", posicion_base.y, 1.1)
			tween.tween_interval(1.0)
		_:
			tween.tween_property(sprite, "position:y", posicion_base.y - 0.45, 1.0)
			tween.tween_property(sprite, "position:y", posicion_base.y, 1.0)
			tween.tween_interval(0.8)
	npc.set_meta("animacion_ocio_exterior_tween", tween)


func _detener_animacion_ocio_exterior(npc: Creature) -> void:
	if not is_instance_valid(npc) or not bool(npc.get_meta("animacion_ocio_exterior_activa", false)):
		return
	var tween_variant: Variant = npc.get_meta("animacion_ocio_exterior_tween", null)
	if tween_variant is Tween and is_instance_valid(tween_variant):
		(tween_variant as Tween).kill()
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if is_instance_valid(sprite):
		var posicion: Variant = npc.get_meta("animacion_ocio_exterior_posicion", sprite.position)
		sprite.position = posicion if posicion is Vector2 else sprite.position
		sprite.rotation = float(npc.get_meta("animacion_ocio_exterior_rotacion", sprite.rotation))
	for clave in ["animacion_ocio_exterior_activa", "animacion_ocio_exterior_posicion", "animacion_ocio_exterior_rotacion", "animacion_ocio_exterior_tween"]:
		npc.remove_meta(clave)


## Separación suave de seguridad para NPC quietos que coinciden en el mismo espacio.
## No interfiere con rutas, conversaciones, cinemáticas ni actividades sociales.
func _separar_npcs_superpuestos() -> void:
	var npcs: Array[Creature] = []
	for nodo in get_tree().get_nodes_in_group("torres_game_npc"):
		if nodo is Creature and is_instance_valid(nodo) and not nodo.is_queued_for_deletion():
			var npc := nodo as Creature
			if npc.is_alive and npc.is_inside_tree():
				npcs.append(npc)
	for indice_a in range(npcs.size()):
		var a := npcs[indice_a]
		if not _npc_puede_ajustar_separacion(a):
			continue
		for indice_b in range(indice_a + 1, npcs.size()):
			var b := npcs[indice_b]
			if a.get_parent() != b.get_parent() or not _npc_puede_ajustar_separacion(b):
				continue
			var diferencia := a.global_position - b.global_position
			var distancia := diferencia.length()
			var distancia_minima := RADIO_COLISION_NPC * 2.0
			if distancia >= distancia_minima:
				continue
			var direccion := diferencia.normalized()
			if distancia < 0.01:
				var clave := a.get_nombre_visual() + "|" + b.get_nombre_visual()
				var angulo := float(posmod(hash(clave), 360)) * PI / 180.0
				direccion = Vector2.RIGHT.rotated(angulo)
			var ajuste := (distancia_minima - distancia + 1.0) * 0.5
			a.global_position += direccion * ajuste
			b.global_position -= direccion * ajuste


func _npc_puede_ajustar_separacion(npc: Creature) -> bool:
	if (
		not is_instance_valid(npc)
		or not npc.is_alive
		or not npc.visible
		or bool(npc.get_meta("rutina_en_edificio", false))
		or npc.velocity.length() > 5.0
	):
		return false
	for clave in [
		"rutina_en_transito",
		"actividad_social_activa",
		"acercamiento_social_activo",
		"conversacion_npc_bloqueada",
		"_conversacion_ambiental_activa",
		"cinematica_npc_activa"
	]:
		if bool(npc.get_meta(clave, false)):
			return false
	return true


## Pequeños paseos alrededor del punto asignado. Mantienen al NPC en su
## zona de actividad y usan rutas reales, con pausas individuales y sin sincronía.
func _actualizar_paseo_ambiental_exterior(npc: Creature, minutos: int) -> void:
	if not is_instance_valid(npc):
		return
	# En días laborales, un NPC con oficio no hace paseos ambientales al azar.
	# Sus desplazamientos sólo proceden de la rutina laboral (por ejemplo,
	# la ronda de Darven); el día 5 sí puede disfrutar de su descanso.
	if not bool(npc.get_meta("habitante_sin_oficio", false)):
		var tiempo_trabajo: Dictionary = _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
		var dia_trabajo := posmod(int(tiempo_trabajo.get("dia", 1)) - 1, 5)
		if dia_trabajo != 4:
			_detener_animacion_ocio_exterior(npc)
			return
	if bool(npc.get_meta("rutina_en_edificio", false)):
		_detener_animacion_ocio_exterior(npc)
		return
	if (
		bool(npc.get_meta("rutina_en_transito", false))
		or bool(npc.get_meta("actividad_social_activa", false))
		or bool(npc.get_meta("acercamiento_social_activo", false))
		or bool(npc.get_meta("_conversacion_ambiental_activa", false))
		or bool(npc.get_meta("cinematica_npc_activa", false))
	):
		_detener_animacion_ocio_exterior(npc)
		return
	if str(npc.get_meta("rutina_ubicacion", "")) != "plaza":
		_detener_animacion_ocio_exterior(npc)
		return
	_actualizar_animacion_ocio_exterior(npc)
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
		and not bool(ivo.get_meta("cinematica_npc_activa", false))
		and not bool(elian.get_meta("cinematica_npc_activa", false))
		and not bool(ivo.get_meta("_conversacion_ambiental_activa", false))
		and not bool(elian.get_meta("_conversacion_ambiental_activa", false))
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
	if is_instance_valid(_zona) and _zona.has_method("desactivar_colision_npc_exterior"):
		_zona.call("desactivar_colision_npc_exterior", npc)
	npc.set_meta("rutina_en_edificio", true)
	npc.set_meta("rutina_en_transito", false)
	npc.set_meta("rutina_edificio_id", edificio_id)
	npc.visible = false
	npc.remove_from_group("interactable")


## Añade variedad ambiental sin sustituir horarios ni destinos de trabajo.
## La elección depende del día del mundo y del tramo horario, por lo que no
## cambia en cada actualización del sistema.
## Descarta opciones mal formadas o con destinos que no existen.
## Una ubicación desconocida nunca debe convertirse silenciosamente en la plaza.
static func filtrar_opciones_ocio_validas(opciones: Array) -> Array:
	var validas: Array = []
	for opcion_variant in opciones:
		if not opcion_variant is Dictionary:
			continue
		var opcion: Dictionary = (opcion_variant as Dictionary).duplicate(true)
		var actividad := str(opcion.get("id", "")).strip_edges().to_lower()
		var ubicacion := str(opcion.get("ubicacion_clave", "plaza")).strip_edges().to_lower()
		if actividad.is_empty() or not tiene_ubicacion(ubicacion):
			continue
		opcion["id"] = actividad
		opcion["ubicacion_clave"] = ubicacion
		validas.append(opcion)
	return validas


## Además de validar el catálogo, comprueba que el destino sea alcanzable
## desde la posición actual cuando la malla de navegación ya está preparada.
func _filtrar_opciones_ocio_alcanzables(npc: Creature, opciones: Array) -> Array:
	var validas := filtrar_opciones_ocio_validas(opciones)
	if not _malla_lista or _malla == null or not is_instance_valid(_zona):
		return validas
	var alcanzables: Array = []
	for opcion_variant in validas:
		var opcion: Dictionary = opcion_variant
		var ubicacion := str(opcion.get("ubicacion_clave", "plaza"))
		var destino_local: Vector2 = POSICIONES[ubicacion]
		var destino_global := _zona.to_global(destino_local)
		if npc.global_position.distance_to(destino_global) <= DISTANCIA_LLEGADA:
			alcanzables.append(opcion)
			continue
		if _crear_ruta(npc.global_position, destino_global).is_empty():
			continue
		alcanzables.append(opcion)
	return alcanzables


func _aplicar_variacion_tiempo_libre(
	npc: Creature,
	rutina_base: Dictionary,
	dia_semana: int,
	minutos: int
) -> Dictionary:
	var es_intervalo_libre := false
	var minutos_hasta_compromiso := 0
	if rutina_base.is_empty():
		var rutinas_variant: Variant = npc.datos.get("rutinas", [])
		if not rutinas_variant is Array or (rutinas_variant as Array).is_empty():
			return rutina_base
		minutos_hasta_compromiso = _obtener_minutos_hasta_siguiente_rutina(
			rutinas_variant, dia_semana, minutos
		)
		# Sólo se ocupa un hueco real con margen suficiente. Una rutina activa
		# (trabajo, guardia, cita o traslado) nunca llega a esta rama.
		if minutos_hasta_compromiso < 60:
			return rutina_base
		es_intervalo_libre = true
	else:
		var clave_base := str(rutina_base.get("clave", ""))
		var ubicacion_base := str(rutina_base.get("ubicacion_clave", ""))
		if not clave_base.begins_with("dia_libre") or ubicacion_base != "plaza":
			return rutina_base

	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	var actividades_por_personaje: Dictionary = _obtener_opciones_ocio_npc(nombre)
	if actividades_por_personaje.is_empty():
		return rutina_base

	var tramo := 0
	if es_intervalo_libre:
		# Los huecos de días laborables se vuelven a evaluar por hora, sin
		# cambiar de actividad en cada tick de navegación.
		tramo = 10 + int(minutos / 60)
	elif minutos >= 840 and minutos < 1020:
		tramo = 1
	elif minutos >= 1020:
		tramo = 2

	var tiempo := _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var clave_dia := "%s:%s:%s" % [
		str(tiempo.get("anio", 0)),
		str(tiempo.get("mes", 0)),
		str(tiempo.get("dia", dia_semana))
	]
	var clave_decision := clave_dia + "|" + str(tramo)
	var decision_guardada: Variant = npc.get_meta("npc_mind_rutina_decidida", {})
	if (
		str(npc.get_meta("npc_mind_decision_key", "")) == clave_decision
		and decision_guardada is Dictionary
		and not (decision_guardada as Dictionary).is_empty()
	):
		return (decision_guardada as Dictionary).duplicate(true)

	var mind := get_node_or_null("/root/NPCMind")
	var personaje_id := npc.get_personaje_game_id().strip_edges()
	if personaje_id.is_empty():
		personaje_id = nombre

	var opciones: Array = _filtrar_opciones_ocio_alcanzables(
		npc,
		(actividades_por_personaje.get("opciones", []) as Array)
	)
	if opciones.is_empty():
		return rutina_base
	var contexto_habito := "ocio_intervalo_laboral" if es_intervalo_libre else "ocio_tramo_%s" % tramo
	for opcion_variant in opciones:
		if opcion_variant is Dictionary:
			(opcion_variant as Dictionary)["contexto_habito"] = contexto_habito
	var elegida: Dictionary = {}
	if is_instance_valid(mind) and mind.has_method("elegir_actividad"):
		var perfil: Dictionary = {}
		# No aplicar valores neutrales mientras Supabase carga ni para NPC
		# que carecen de una fila propia en el catálogo social.
		if (
			is_instance_valid(_relationship_system)
			and _relationship_system.has_method("esta_cargado")
			and _relationship_system.esta_cargado()
			and _relationship_system.has_method("obtener_reglas_sociales")
		):
			var reglas_sociales: Dictionary = _relationship_system.obtener_reglas_sociales()
			if reglas_sociales.has(personaje_id):
				var personalidad: Dictionary = _relationship_system.obtener_personalidad(personaje_id)
				var rasgos: Dictionary = {}
				for rasgo in ["sociabilidad", "curiosidad", "prudencia", "generosidad", "agresividad"]:
					if personalidad.has(rasgo):
						rasgos[rasgo] = float(personalidad[rasgo])
				perfil["rasgos"] = rasgos
		mind.call("registrar_personaje", personaje_id, perfil)

		# La experiencia del tramo anterior modifica las próximas elecciones.
		var clave_anterior := str(npc.get_meta("npc_mind_decision_key", ""))
		if not clave_anterior.is_empty():
			var actividad_anterior := str(npc.get_meta("npc_mind_actividad", ""))
			var necesidad_anterior := str(npc.get_meta("npc_mind_necesidad_clave", ""))
			var presion_inicial := float(npc.get_meta("npc_mind_necesidad_inicio", 0.0))
			var resultado := 0.0
			if not actividad_anterior.is_empty() and not necesidad_anterior.is_empty():
				var necesidades_actuales: Dictionary = mind.call("obtener_necesidades", personaje_id)
				var presion_final := float(necesidades_actuales.get(necesidad_anterior, presion_inicial))
				resultado = clampf((presion_inicial - presion_final) / 25.0, -1.0, 1.0)
				mind.call("registrar_resultado_actividad", personaje_id, actividad_anterior, resultado, str(npc.get_meta("npc_mind_contexto_habito", "general")), clave_dia)
			var ubicacion_anterior := str(npc.get_meta("npc_mind_ubicacion", "")).strip_edges().to_lower()
			if not ubicacion_anterior.is_empty() and mind.has_method("registrar_resultado_lugar"):
				mind.call("registrar_resultado_lugar", personaje_id, ubicacion_anterior, resultado)

		var resultado_eleccion: Dictionary = mind.call("elegir_actividad", personaje_id, opciones)
		var actividad_elegida := str(resultado_eleccion.get("actividad", ""))
		for opcion_variant in opciones:
			if opcion_variant is Dictionary and str(opcion_variant.get("id", "")) == actividad_elegida:
				elegida = (opcion_variant as Dictionary).duplicate(true)
				break

	if elegida.is_empty():
		# Respaldo determinista si el servicio mental no está disponible.
		var indice := absi(hash(nombre + "|" + clave_dia + "|" + str(tramo))) % opciones.size()
		elegida = (opciones[indice] as Dictionary).duplicate(true)

	var resultado := rutina_base.duplicate(true)
	if es_intervalo_libre:
		resultado = {
			"clave": "ocio_intervalo_libre",
			"activo": true,
			"limite_intervalo_minutos": minutos_hasta_compromiso
		}
	var actividad := str(elegida.get("id", ""))
	var ubicacion_elegida := str(elegida.get("ubicacion_clave", "plaza")).strip_edges().to_lower()
	if not POSICIONES.has(ubicacion_elegida):
		return rutina_base
	resultado["actividad_clave"] = actividad
	resultado["ubicacion_clave"] = ubicacion_elegida
	resultado["variacion_posicion"] = (
		_obtener_desplazamiento_ocio(nombre, clave_dia, tramo)
		if ubicacion_elegida == "plaza"
		else Vector2.ZERO
	)
	resultado["variacion_diaria"] = clave_dia
	npc.set_meta("npc_mind_decision_key", clave_decision)
	npc.set_meta("npc_mind_actividad", actividad)
	npc.set_meta("npc_mind_contexto_habito", contexto_habito)
	npc.set_meta("npc_mind_ubicacion", ubicacion_elegida)
	var necesidades_actividad: Dictionary = elegida.get("necesidades", {})
	var necesidad_principal := ""
	var mayor_peso := -1.0
	for necesidad_variant in necesidades_actividad:
		var peso := float(necesidades_actividad[necesidad_variant])
		if peso > mayor_peso:
			mayor_peso = peso
			necesidad_principal = str(necesidad_variant)
	npc.set_meta("npc_mind_necesidad_clave", necesidad_principal)
	var mind_actual := get_node_or_null("/root/NPCMind")
	if is_instance_valid(mind_actual) and mind_actual.has_method("obtener_necesidades"):
		var necesidades_inicio: Dictionary = mind_actual.call("obtener_necesidades", personaje_id)
		npc.set_meta("npc_mind_necesidad_inicio", float(necesidades_inicio.get(necesidad_principal, 0.0)))
	npc.set_meta("npc_mind_rutina_decidida", resultado.duplicate(true))
	return resultado


## Devuelve el tiempo real hasta el próximo inicio de rutina del calendario.
## Recorre el ciclo de cinco días y no confunde un hueco con un horario inexistente.
func _obtener_minutos_hasta_siguiente_rutina(
	rutinas_variant: Variant,
	dia_semana: int,
	minutos: int
) -> int:
	return NPC_SCHEDULE_RULES.obtener_minutos_hasta_siguiente_rutina(
		rutinas_variant,
		dia_semana,
		minutos
	)


func _obtener_opciones_ocio_npc(nombre: String) -> Dictionary:
	var opciones_por_personaje: Dictionary = {
		"elian": [
			{"id":"acomodar_pedidos","ubicacion_clave":"panaderia","necesidades":{"autonomia":0.45,"curiosidad":0.25},"afinidad_rasgos":{"curiosidad":0.65},"coste":8.0},
			{"id":"conversar_con_vecinos","necesidades":{"socializacion":0.9,"diversion":0.3},"afinidad_rasgos":{"sociabilidad":0.85},"coste":5.0},
			{"id":"compartir_pan","ubicacion_clave":"panaderia","necesidades":{"socializacion":0.65,"diversion":0.7},"afinidad_rasgos":{"generosidad":0.85,"sociabilidad":0.65},"coste":8.0}
		],
		"bruna": [
			{"id":"revisar_herramientas","ubicacion_clave":"forja","necesidades":{"curiosidad":0.8,"autonomia":0.3},"afinidad_rasgos":{"curiosidad":0.7,"prudencia":0.7},"coste":8.0},
			{"id":"observar_trabajos","necesidades":{"curiosidad":0.55,"socializacion":0.2},"afinidad_rasgos":{"curiosidad":0.65},"coste":5.0},
			{"id":"descansar_un_rato","ubicacion_clave":"casa_bruna","necesidades":{"descanso":0.95,"diversion":0.2},"coste":2.0}
		],
		"darven": [
			{"id":"vigilar_plaza","necesidades":{"seguridad":0.8,"autonomia":0.25},"afinidad_rasgos":{"prudencia":0.8},"coste":5.0},
			{"id":"revisar_avisos","necesidades":{"curiosidad":0.6,"autonomia":0.2},"afinidad_rasgos":{"prudencia":0.65},"coste":4.0},
			{"id":"conversar_con_habitantes","necesidades":{"socializacion":0.8,"diversion":0.2},"afinidad_rasgos":{"sociabilidad":0.75},"coste":5.0}
		],
		"saira": [
			{"id":"saludar_comerciantes","necesidades":{"socializacion":0.8,"autonomia":0.25},"afinidad_rasgos":{"sociabilidad":0.85},"coste":5.0},
			{"id":"compartir_noticias","necesidades":{"socializacion":0.55,"curiosidad":0.6},"afinidad_rasgos":{"curiosidad":0.75,"sociabilidad":0.65},"coste":6.0},
			{"id":"escuchar_historias","necesidades":{"socializacion":0.7,"diversion":0.5},"afinidad_rasgos":{"sociabilidad":0.7},"coste":4.0}
		],
		"narel": [
			{"id":"tomar_notas","ubicacion_clave":"archivo_real","necesidades":{"curiosidad":0.95,"autonomia":0.2},"afinidad_rasgos":{"curiosidad":0.9},"coste":7.0},
			{"id":"observar_entorno","necesidades":{"curiosidad":0.8,"diversion":0.15},"afinidad_rasgos":{"curiosidad":0.8,"prudencia":0.6},"coste":5.0},
			{"id":"leer_apuntes","ubicacion_clave":"archivo_real","necesidades":{"curiosidad":0.75,"descanso":0.1},"afinidad_rasgos":{"curiosidad":0.85},"coste":3.0}
		],
		"mara": [
			{"id":"pasear_sin_prisa","necesidades":{"autonomia":0.75,"diversion":0.45},"afinidad_rasgos":{"independencia":0.8},"coste":4.0},
			{"id":"observar_la_plaza","necesidades":{"curiosidad":0.55,"seguridad":0.15},"afinidad_rasgos":{"prudencia":0.6},"coste":3.0},
			{"id":"visitar_un_puesto","ubicacion_clave":"casa_comercio","necesidades":{"diversion":0.65,"socializacion":0.35},"afinidad_rasgos":{"sociabilidad":0.55},"coste":6.0}
		],
		"ivo": [
			{"id":"descansar_y_saludar","ubicacion_clave":"plaza","necesidades":{"descanso":0.8,"socializacion":0.35},"afinidad_rasgos":{"sociabilidad":0.45},"coste":2.0},
			{"id":"sentarse_un_rato","ubicacion_clave":"vivienda_oeste_02","necesidades":{"descanso":0.95,"autonomia":0.2},"coste":1.0},
			{"id":"pasear_a_su_ritmo","necesidades":{"autonomia":0.65,"diversion":0.35},"afinidad_rasgos":{"independencia":0.75},"coste":3.0}
		],
		"nima": [
			{"id":"tomar_notas","necesidades":{"curiosidad":0.95,"autonomia":0.2},"afinidad_rasgos":{"curiosidad":0.9},"coste":7.0},
			{"id":"observar_fenomenos","ubicacion_clave":"casa_estudio","necesidades":{"curiosidad":0.9,"diversion":0.2},"afinidad_rasgos":{"curiosidad":0.85},"coste":5.0},
			{"id":"conversar_con_vecinos","necesidades":{"socializacion":0.65,"diversion":0.25},"afinidad_rasgos":{"sociabilidad":0.65},"coste":4.0}
		],
		"abel": [
			{"id":"revisar_asuntos","ubicacion_clave":"castillo","necesidades":{"seguridad":0.55,"autonomia":0.4},"afinidad_rasgos":{"prudencia":0.8},"coste":5.0},
			{"id":"leer_informes","ubicacion_clave":"castillo","necesidades":{"curiosidad":0.7,"autonomia":0.25},"afinidad_rasgos":{"curiosidad":0.65},"coste":4.0},
			{"id":"conversar_con_guardias","ubicacion_clave":"castillo","necesidades":{"socializacion":0.65,"seguridad":0.25},"afinidad_rasgos":{"sociabilidad":0.55},"coste":5.0}
		],
		"liam": [
			{"id":"ordenar_documentos","ubicacion_clave":"castillo","necesidades":{"curiosidad":0.45,"autonomia":0.35},"afinidad_rasgos":{"prudencia":0.65},"coste":4.0},
			{"id":"recorrer_el_castillo","ubicacion_clave":"castillo","necesidades":{"seguridad":0.5,"autonomia":0.4},"afinidad_rasgos":{"prudencia":0.7},"coste":5.0},
			{"id":"descansar_un_rato","necesidades":{"descanso":0.85,"diversion":0.15},"coste":2.0}
		]
	}
	return {"opciones": opciones_por_personaje.get(nombre, [])}


func _actualizar_mente_npc(npc: Creature, minutos: int, tiempo: Dictionary) -> void:
	var mind := get_node_or_null("/root/NPCMind")
	if not is_instance_valid(mind) or not mind.has_method("procesar_intervalo"):
		return
	var personaje_id := npc.get_personaje_game_id().strip_edges()
	if personaje_id.is_empty():
		personaje_id = npc.get_nombre_visual().strip_edges().to_lower()
	if personaje_id.is_empty():
		return

	var personalidad: Dictionary = {}
	if is_instance_valid(_relationship_system) and _relationship_system.has_method("obtener_personalidad"):
		personalidad = _relationship_system.obtener_personalidad(personaje_id)
	var rasgos: Dictionary = {}
	for rasgo in ["sociabilidad", "curiosidad", "prudencia", "generosidad", "agresividad"]:
		if personalidad.has(rasgo):
			rasgos[rasgo] = float(personalidad[rasgo])
	mind.call("registrar_personaje", personaje_id, {"rasgos": rasgos})

	var fecha := "%s:%s:%s" % [
		str(tiempo.get("anio", 0)),
		str(tiempo.get("mes", 0)),
		str(tiempo.get("dia", 1))
	]
	var fecha_anterior := str(npc.get_meta("npc_mind_fecha_procesada", ""))
	if fecha_anterior.is_empty():
		npc.set_meta("npc_mind_fecha_procesada", fecha)
		npc.set_meta("npc_mind_minuto_procesado", minutos)
		return
	var minuto_anterior := int(npc.get_meta("npc_mind_minuto_procesado", minutos))
	var delta_minutos := minutos - minuto_anterior
	if fecha != fecha_anterior and delta_minutos < 0:
		delta_minutos += 1440
	if delta_minutos <= 0:
		return
	# Limita cada lote a dos horas. Si el salto fue mayor, el siguiente tick
	# continúa desde el minuto realmente procesado.
	delta_minutos = mini(delta_minutos, 120)
	if delta_minutos < 5:
		return

	var actividad := str(npc.get_meta("actividad_actual", npc.datos.get("actividad_actual", ""))).strip_edges().to_lower()
	var satisfacciones := _obtener_satisfaccion_actividad(actividad)
	mind.call("procesar_intervalo", personaje_id, float(delta_minutos) / 60.0, satisfacciones)
	npc.set_meta("npc_mind_fecha_procesada", fecha)
	npc.set_meta("npc_mind_minuto_procesado", posmod(minuto_anterior + delta_minutos, 1440))


## Genera y ejecuta objetivos sociales a partir de necesidades y vínculos.
## El NPC elige a quién acercarse; el objetivo no se impone desde el horario.
func _actualizar_objetivo_social_npc(npc: Creature, delta: float, minutos: int) -> bool:
	var mind := get_node_or_null("/root/NPCMind")
	if not is_instance_valid(mind) or not is_instance_valid(_relationship_system):
		return false
	if not mind.has_method("obtener_necesidades") or not mind.has_method("establecer_objetivo"):
		return false
	if bool(npc.get_meta("_conversacion_ambiental_activa", false)):
		return false
	if bool(npc.get_meta("rutina_en_edificio", false)):
		return false

	var personaje_id := npc.get_personaje_game_id().strip_edges()
	if personaje_id.is_empty():
		return false
	var objetivo: Dictionary = npc.get_meta("npc_objetivo_social", {})
	if minutos < 540 or minutos >= 1200:
		if not objetivo.is_empty():
			_cancelar_objetivo_social_npc(npc, mind, personaje_id)
		return false
	if objetivo.is_empty():
		var rutina_actual := str(npc.get_meta("rutina_actual", "")).strip_edges().to_lower()
		if not rutina_actual.begins_with("dia_libre"):
			return false
		if str(npc.get_meta("npc_social_siguiente_intento", "")) == _clave_fecha_actual():
			return false
		var necesidades: Dictionary = mind.call("obtener_necesidades", personaje_id)
		var presion_social := float(necesidades.get("socializacion", 0.0))
		# La sociabilidad del perfil Supabase regula la frecuencia de iniciativa.
		# Una necesidad alta no convierte por sí sola a un NPC reservado en sociable.
		if presion_social < _obtener_umbral_social(personaje_id):
			return false
		var pareja := _seleccionar_companero_social(npc, presion_social)
		if pareja == null:
			return false
		var pareja_id := pareja.get_personaje_game_id().strip_edges()
		var relacion: Dictionary = _relationship_system.obtener_relacion_entre_npc(personaje_id, pareja_id)
		var motivo := _seleccionar_motivo_encuentro_social(personaje_id, pareja_id, relacion)
		var tipo := str(motivo.get("tipo", "visitar_amigo" if (
			float(relacion.get("amistad", 0.0)) >= 18.0
			or float(relacion.get("afecto", 0.0)) >= 12.0
		) else "buscar_compania"))
		var objetivo_id := "%s:%s:%s" % [tipo, pareja_id.to_lower(), _clave_fecha_actual()]
		objetivo = {
			"id": objetivo_id,
			"tipo": tipo,
			"motivo": motivo.duplicate(true),
			"objetivo_personaje": pareja_id,
			"nombre_objetivo": pareja.get_nombre_visual(),
			"prioridad": clampf(presion_social / 100.0, 0.55, 0.95),
			"creado_dia": _clave_fecha_actual(),
			"estado": "activo"
		}
		if not bool(mind.call("establecer_objetivo", personaje_id, objetivo)):
			return false
		npc.set_meta("npc_objetivo_social", objetivo.duplicate(true))
		npc.set_meta("npc_objetivo_social_tiempo", 0.0)
		npc.set_meta("npc_objetivo_social_espera", 0.0)
		npc.set_meta("npc_objetivo_social_en_curso", false)

	var pareja_actual := _buscar_npc_por_id_social(str(objetivo.get("objetivo_personaje", "")))
	if not is_instance_valid(pareja_actual) or not pareja_actual.is_alive:
		_cancelar_objetivo_social_npc(npc, mind, personaje_id)
		return false
	if bool(pareja_actual.get_meta("rutina_en_edificio", false)) or bool(pareja_actual.get_meta("_conversacion_ambiental_activa", false)):
		_cancelar_objetivo_social_npc(npc, mind, personaje_id)
		return false
	if bool(pareja_actual.get_meta("rutina_en_transito", false)):
		var espera := float(npc.get_meta("npc_objetivo_social_espera", 0.0)) + maxf(delta, 0.0)
		npc.set_meta("npc_objetivo_social_espera", espera)
		if espera >= 45.0:
			_cancelar_objetivo_social_npc(npc, mind, personaje_id)
			return false
		return true
	npc.set_meta("npc_objetivo_social_espera", 0.0)

	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		return false
	var distancia := npc.global_position.distance_to(pareja_actual.global_position)
	if movimiento.rutina_terminada():
		npc.set_meta("rutina_en_transito", false)
		npc.set_meta("npc_objetivo_social_en_curso", false)
	if distancia > 78.0:
		npc.set_meta("npc_objetivo_social_tiempo", 0.0)
		npc.set_meta("npc_objetivo_social_en_curso", false)
		if not bool(npc.get_meta("rutina_en_transito", false)):
			var ruta := _crear_ruta(npc.global_position, _obtener_punto_encuentro_social(npc, pareja_actual))
			if ruta.is_empty():
				_cancelar_objetivo_social_npc(npc, mind, personaje_id)
				return false
			npc.set_meta("rutina_en_transito", true)
			npc.set_meta("npc_objetivo_social_en_curso", true)
			movimiento.establecer_ruta(ruta)
		return true

	if movimiento.rutina_terminada():
		npc.set_meta("npc_objetivo_social_en_curso", false)
		var tiempo_social := float(npc.get_meta("npc_objetivo_social_tiempo", 0.0)) + maxf(delta, 0.0)
		npc.set_meta("npc_objetivo_social_tiempo", tiempo_social)
		if tiempo_social >= 12.0:
			_finalizar_objetivo_social_npc(npc, pareja_actual, mind, personaje_id, objetivo)
	return true


func _seleccionar_motivo_encuentro_social(personaje_id: String, pareja_id: String, relacion: Dictionary) -> Dictionary:
	if not is_instance_valid(_relationship_system):
		return {"tipo": "visitar_amigo"}
	for conocimiento_promesa_variant in _relationship_system.obtener_conocimientos_npc(personaje_id):
		if not conocimiento_promesa_variant is Dictionary:
			continue
		var conocimiento_promesa := conocimiento_promesa_variant as Dictionary
		if str(conocimiento_promesa.get("promesa_para", "")) != pareja_id:
			continue
		var clave_promesa := str(conocimiento_promesa.get("clave_promesa", conocimiento_promesa.get("clave", ""))).strip_edges()
		if not clave_promesa.is_empty():
			_relationship_system.registrar_promesa_entre_npc(personaje_id, pareja_id, {
				"id": "promesa_memoria:%s:%s" % [personaje_id, clave_promesa],
				"clave": clave_promesa,
				"descripcion": str(conocimiento_promesa.get("promesa", conocimiento_promesa.get("titulo", clave_promesa))),
				"clave_conocimiento": str(conocimiento_promesa.get("clave_conocimiento", ""))
			})
	var promesas: Array = _relationship_system.obtener_promesas_pendientes_npc(personaje_id, pareja_id)
	if not promesas.is_empty():
		var promesa: Dictionary = promesas[0]
		return {
			"tipo": "cumplir_promesa",
			"promesa_id": str(promesa.get("id", "")),
			"clave_conocimiento": str(promesa.get("clave_conocimiento", "")),
			"descripcion": str(promesa.get("descripcion", promesa.get("titulo", "")))
		}
	for conocimiento_variant in _relationship_system.obtener_conocimientos_npc(personaje_id):
		if not conocimiento_variant is Dictionary:
			continue
		var conocimiento_asunto := conocimiento_variant as Dictionary
		if not bool(conocimiento_asunto.get("requiere_ayuda", false)):
			continue
		if str(conocimiento_asunto.get("personaje_relacionado", "")) != pareja_id:
			continue
		var clave_asunto := str(conocimiento_asunto.get("clave", "")).strip_edges()
		if not clave_asunto.is_empty():
			_relationship_system.registrar_asunto_pendiente_npc(personaje_id, {
				"id": "asunto_memoria:%s:%s" % [personaje_id, clave_asunto],
				"clave": clave_asunto,
				"personaje_relacionado": pareja_id,
				"descripcion": str(conocimiento_asunto.get("asunto", conocimiento_asunto.get("titulo", clave_asunto))),
				"origen": "conocimiento_npc"
			})
	var asuntos: Array = _relationship_system.obtener_asuntos_pendientes_npc(personaje_id, pareja_id)
	if not asuntos.is_empty():
		var asunto: Dictionary = asuntos[0]
		return {
			"tipo": "resolver_asunto",
			"asunto_id": str(asunto.get("id", "")),
			"clave": str(asunto.get("clave", "")),
			"descripcion": str(asunto.get("descripcion", asunto.get("asunto", "")))
		}
	for conocimiento_variant in _relationship_system.obtener_conocimientos_compartibles_npc(personaje_id, pareja_id):
		if not conocimiento_variant is Dictionary:
			continue
		var conocimiento := conocimiento_variant as Dictionary
		var clave := str(conocimiento.get("clave", "")).strip_edges()
		if clave.is_empty() or _relationship_system.conoce_conocimiento_npc(pareja_id, clave):
			continue
		return {
			"tipo": "compartir_noticia",
			"clave_conocimiento": clave,
			"titulo": str(conocimiento.get("titulo", conocimiento.get("descripcion", "")))
		}
	if float(relacion.get("tension", 0.0)) >= 18.0:
		return {"tipo": "resolver_desacuerdo"}
	return {
		"tipo": "visitar_amigo" if (
			float(relacion.get("amistad", 0.0)) >= 18.0
			or float(relacion.get("afecto", 0.0)) >= 12.0
		) else "buscar_compania"
	}


func _seleccionar_companero_social(npc: Creature, presion_social: float) -> Creature:
	var mejor: Creature = null
	var mejor_puntuacion := -INF
	var id_npc := npc.get_personaje_game_id().strip_edges()
	for candidato_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not candidato_variant is Creature or not is_instance_valid(candidato_variant):
			continue
		var candidato := candidato_variant as Creature
		if candidato == npc or not candidato.is_alive:
			continue
		if bool(candidato.get_meta("rutina_en_edificio", false)):
			continue
		if bool(candidato.get_meta("rutina_en_transito", false)):
			continue
		var objetivo_candidato: Variant = candidato.get_meta("npc_objetivo_social", {})
		if objetivo_candidato is Dictionary and not (objetivo_candidato as Dictionary).is_empty():
			continue
		if bool(candidato.get_meta("_conversacion_ambiental_activa", false)):
			continue
		if bool(candidato.get_meta("actividad_social_activa", false)):
			continue
		var movimiento_candidato := candidato.get_node_or_null("CreatureMovement") as CreatureMovement
		if movimiento_candidato == null:
			continue
		var id_candidato := candidato.get_personaje_game_id().strip_edges()
		if id_candidato.is_empty() or id_candidato == id_npc:
			continue
		if npc.global_position.distance_to(candidato.global_position) > 520.0:
			continue
		var relacion: Dictionary = _relationship_system.obtener_relacion_entre_npc(id_npc, id_candidato)
		var amistad := float(relacion.get("amistad", 0.0))
		var afecto := float(relacion.get("afecto", 0.0))
		var confianza := float(relacion.get("confianza", 0.0))
		var tension := float(relacion.get("tension", 0.0))
		var colaboracion := float(relacion.get("colaboracion", 0.0))
		var motivo_concreto := (
			_hay_motivo_social_concreto(id_npc, id_candidato)
			or _hay_motivo_social_concreto(id_candidato, id_npc)
		)
		# Ambos perfiles cuentan: una persona muy sociable tampoco debe imponer
		# encuentros casuales a alguien reservado con quien apenas tiene vínculo.
		if not _puede_iniciar_encuentro_social(id_npc, relacion, motivo_concreto, id_candidato):
			continue
		if not _puede_iniciar_encuentro_social(id_candidato, relacion, motivo_concreto, id_npc):
			continue
		var distancia := npc.global_position.distance_to(candidato.global_position)
		var puntuacion := (
			amistad * 0.22 + afecto * 0.18 + confianza * 0.08
			+ colaboracion * 0.06 - tension * 0.2
			+ clampf(520.0 - distancia, 0.0, 520.0) * 0.025
			+ presion_social * 0.08
		)
		# Las experiencias recientes pueden reforzar o enfriar un vínculo,
		# incluso antes de que sus valores sociales cambien mucho.
		# La evaluación es bilateral: importa tanto cómo ve el iniciador al
		# candidato como la experiencia que el candidato conserva del iniciador.
		puntuacion += _calcular_influencia_recuerdos_sociales(id_npc, id_candidato) * 0.7
		puntuacion += _calcular_influencia_recuerdos_sociales(id_candidato, id_npc) * 0.45
		if bool(candidato.get_meta("npc_objetivo_social_en_curso", false)):
			puntuacion -= 8.0
		if not _relationship_system.obtener_promesas_pendientes_npc(id_npc, id_candidato).is_empty():
			puntuacion += 16.0
		if not _relationship_system.obtener_asuntos_pendientes_npc(id_npc, id_candidato).is_empty():
			puntuacion += 12.0
		if _hay_noticia_compartible(id_npc, id_candidato):
			puntuacion += 8.0
		if puntuacion > mejor_puntuacion:
			mejor_puntuacion = puntuacion
			mejor = candidato
	return mejor


## La sociabilidad se consulta desde personaje_social_v1 en Supabase.
## NPC reservados requieren un vínculo o un motivo concreto para buscar/aceptar compañía.
func _obtener_sociabilidad_social(personaje_id: String) -> float:
	if not is_instance_valid(_relationship_system) or not _relationship_system.has_method("obtener_personalidad"):
		return 50.0
	var personalidad: Dictionary = _relationship_system.obtener_personalidad(personaje_id)
	return clampf(float(personalidad.get("sociabilidad", 50.0)), 0.0, 100.0)


func _obtener_umbral_social(personaje_id: String) -> float:
	# 0 sociabilidad -> 84 de presión; 100 -> 58.
	return lerpf(84.0, 58.0, _obtener_sociabilidad_social(personaje_id) / 100.0)


func _puede_iniciar_encuentro_social(
	personaje_id: String,
	relacion: Dictionary,
	motivo_concreto: bool = false,
	pareja_id: String = ""
) -> bool:
	if motivo_concreto:
		return true
	var sociabilidad := _obtener_sociabilidad_social(personaje_id)
	var vinculo := maxf(
		float(relacion.get("amistad", 0.0)),
		maxf(float(relacion.get("afecto", 0.0)), float(relacion.get("confianza", 0.0)))
	)
	var memoria_personal := 0.0
	if not pareja_id.strip_edges().is_empty():
		memoria_personal = _calcular_influencia_recuerdos_sociales(personaje_id, pareja_id)
	# Un rechazo reiterado o una experiencia muy negativa puede frenar un
	# encuentro casual incluso en alguien sociable. Los motivos concretos
	# (promesas, ayuda o noticias) siguen permitiendo resolver la situación.
	if memoria_personal <= -8.0:
		return false
	# Una experiencia positiva repetida puede crear familiaridad antes de que
	# los valores generales de amistad/confianza hayan subido mucho.
	var vinculo_efectivo := maxf(vinculo, maxf(0.0, memoria_personal * 0.8))
	if sociabilidad < 40.0:
		return vinculo_efectivo >= 12.0
	if sociabilidad < 60.0:
		return vinculo_efectivo >= 5.0
	return true


func _hay_motivo_social_concreto(personaje_id: String, pareja_id: String) -> bool:
	if not is_instance_valid(_relationship_system):
		return false
	if not _relationship_system.obtener_promesas_pendientes_npc(personaje_id, pareja_id).is_empty():
		return true
	if not _relationship_system.obtener_asuntos_pendientes_npc(personaje_id, pareja_id).is_empty():
		return true
	return _hay_noticia_compartible(personaje_id, pareja_id)


## Resume las últimas experiencias compartidas con una persona.
## Los recuerdos recientes pesan más; la influencia queda acotada para que
## una mala experiencia no borre por sí sola una relación consolidada.
func _calcular_influencia_recuerdos_sociales(
	personaje_id: String,
	pareja_id: String,
	fecha_actual: String = ""
) -> float:
	if not is_instance_valid(_relationship_system) or not _relationship_system.has_method("obtener_recuerdos"):
		return 0.0
	var recuerdos: Array = _relationship_system.obtener_recuerdos(personaje_id)
	var fecha_referencia := fecha_actual if not fecha_actual.strip_edges().is_empty() else _clave_fecha_actual()
	var influencia := 0.0
	var consideradas := 0
	for indice in range(recuerdos.size() - 1, -1, -1):
		var recuerdo_variant: Variant = recuerdos[indice]
		if not recuerdo_variant is Dictionary:
			continue
		var recuerdo := recuerdo_variant as Dictionary
		if str(recuerdo.get("tipo", "")) != "experiencia_npc":
			continue
		if str(recuerdo.get("con_personaje", "")).strip_edges().to_lower() != pareja_id.strip_edges().to_lower():
			continue
		var resultado := clampf(float(recuerdo.get("resultado", 0.0)), -1.0, 1.0)
		var importancia := clampf(float(recuerdo.get("importancia", 1.0)) / 3.0, 0.25, 1.0)
		var antiguedad := _calcular_antiguedad_recuerdo_dias(
			str(recuerdo.get("momento", "")),
			fecha_referencia
		)
		# Sin fecha válida conservamos el peso por orden de memoria; con fecha
		# válida la influencia disminuye gradualmente, con semivida aproximada de 14 días.
		var vigencia := 1.0 / (1.0 + antiguedad / 14.0)
		influencia += (
			resultado * importancia * vigencia
			* pow(0.65, float(consideradas)) * 5.0
		)
		consideradas += 1
		if consideradas >= 6:
			break
	return clampf(influencia, -15.0, 15.0)


func _calcular_antiguedad_recuerdo_dias(momento: String, fecha_actual: String) -> float:
	var fecha_recuerdo := _convertir_fecha_mundo_a_unix(momento)
	var fecha_referencia := _convertir_fecha_mundo_a_unix(fecha_actual)
	if fecha_recuerdo < 0.0 or fecha_referencia < 0.0:
		return 0.0
	return maxf(0.0, (fecha_referencia - fecha_recuerdo) / 86400.0)


func _convertir_fecha_mundo_a_unix(fecha: String) -> float:
	var partes := fecha.strip_edges().split(":")
	if partes.size() != 3:
		return -1.0
	var anio := int(partes[0])
	var mes := int(partes[1])
	var dia := int(partes[2])
	if anio < 1 or mes < 1 or mes > 12 or dia < 1 or dia > 31:
		return -1.0
	var fecha_dict := {
		"year": anio,
		"month": mes,
		"day": dia,
		"hour": 12,
		"minute": 0,
		"second": 0
	}
	return float(Time.get_unix_time_from_datetime_dict(fecha_dict))


func _registrar_experiencia_social_npc(
	personaje_id: String,
	pareja_id: String,
	tipo_experiencia: String,
	objetivo_id: String,
	resultado: float
) -> void:
	if not is_instance_valid(_relationship_system) or not _relationship_system.has_method("registrar_recuerdo"):
		return
	for participante in [personaje_id, pareja_id]:
		var otro := pareja_id if participante == personaje_id else personaje_id
		_relationship_system.registrar_recuerdo(participante, {
			"tipo": "experiencia_npc",
			"evento": tipo_experiencia,
			"actividad": tipo_experiencia,
			"evento_id": objetivo_id,
			"con_personaje": otro,
			"resultado": clampf(resultado, -1.0, 1.0),
			"importancia": 2.5,
			"momento": _clave_fecha_actual()
		})


func _hay_noticia_compartible(personaje_id: String, pareja_id: String) -> bool:
	if not is_instance_valid(_relationship_system):
		return false
	for conocimiento_variant in _relationship_system.obtener_conocimientos_compartibles_npc(personaje_id, pareja_id):
		if not conocimiento_variant is Dictionary:
			continue
		var clave := str((conocimiento_variant as Dictionary).get("clave", "")).strip_edges()
		if not clave.is_empty() and not _relationship_system.conoce_conocimiento_npc(pareja_id, clave):
			return true
	return false


func _obtener_punto_encuentro_social(npc: Creature, pareja: Creature) -> Vector2:
	var direccion := pareja.global_position.direction_to(npc.global_position)
	if direccion.length_squared() < 0.001:
		direccion = Vector2.RIGHT
	var candidatos: Array[Vector2] = [
		pareja.global_position + direccion * 58.0,
		pareja.global_position + Vector2.RIGHT * 58.0,
		pareja.global_position + Vector2.DOWN * 58.0,
		pareja.global_position + Vector2.LEFT * 58.0,
		pareja.global_position + Vector2.UP * 58.0
	]
	for punto in candidatos:
		var ruta := _crear_ruta(npc.global_position, punto)
		if not ruta.is_empty():
			return punto
	return pareja.global_position


func _buscar_npc_por_id_social(personaje_id: String) -> Creature:
	var buscado := personaje_id.strip_edges().to_lower()
	if buscado.is_empty():
		return null
	for candidato_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if candidato_variant is Creature and is_instance_valid(candidato_variant):
			var candidato := candidato_variant as Creature
			if candidato.get_personaje_game_id().strip_edges().to_lower() == buscado:
				return candidato
	return null


func _finalizar_objetivo_social_npc(
	npc: Creature,
	pareja: Creature,
	mind: Node,
	personaje_id: String,
	objetivo: Dictionary
) -> void:
	var pareja_id := pareja.get_personaje_game_id().strip_edges()
	var objetivo_id := str(objetivo.get("id", ""))
	var motivo: Dictionary = objetivo.get("motivo", {})
	mind.call("aplicar_satisfaccion", personaje_id, {"socializacion": 22.0, "diversion": 8.0})
	mind.call("registrar_resultado_actividad", personaje_id, str(objetivo.get("tipo", "buscar_compania")), 0.65)
	mind.call("completar_objetivo", personaje_id, objetivo_id, true)
	if is_instance_valid(_relationship_system) and not pareja_id.is_empty():
		var tipo_motivo := str(motivo.get("tipo", objetivo.get("tipo", "buscar_compania")))
		var cambios := {"amistad": 0.6, "confianza": 0.25, "afecto": 0.35}
		var recuerdo := {
			"tipo": tipo_motivo,
			"objetivo": objetivo_id,
			"momento": _clave_fecha_actual()
		}
		var interaccion_registrada := false
		var evento_memoria := ""
		match tipo_motivo:
			"cumplir_promesa":
				var promesa_id := str(motivo.get("promesa_id", ""))
				if not promesa_id.is_empty():
					interaccion_registrada = _relationship_system.resolver_promesa_entre_npc(promesa_id, true)
				var clave_promesa := str(motivo.get("clave_conocimiento", ""))
				if not clave_promesa.is_empty():
					_relationship_system.transmitir_conocimiento_npc(personaje_id, pareja_id, clave_promesa, {"motivo": "promesa_cumplida"})
			"resolver_asunto":
				var asunto_id := str(motivo.get("asunto_id", ""))
				if not asunto_id.is_empty():
					_relationship_system.resolver_asunto_pendiente_npc(asunto_id, true)
				cambios["amistad"] = 1.0
				cambios["confianza"] = 0.8
				evento_memoria = "ayudar"
			"compartir_noticia":
				var clave_noticia := str(motivo.get("clave_conocimiento", ""))
				if not clave_noticia.is_empty() and _relationship_system.transmitir_conocimiento_npc(personaje_id, pareja_id, clave_noticia, {"motivo": "charla_entre_habitantes"}):
					cambios["amistad"] = 1.1
					cambios["respeto"] = 0.7
					recuerdo["evento"] = "compartir_conocimiento"
					evento_memoria = "compartir_conocimiento"
				else:
					cambios["amistad"] = 0.2
			"resolver_desacuerdo":
				cambios["amistad"] = 0.8
				cambios["confianza"] = 0.6
				cambios["tension"] = -4.0
				evento_memoria = "apoyar"
			_:
				pass
		recuerdo["tipo"] = tipo_motivo
		if not interaccion_registrada:
			_relationship_system.registrar_interaccion_entre_npc(personaje_id, pareja_id, cambios, recuerdo)
		if not evento_memoria.is_empty():
			for participante_id in [personaje_id, pareja_id]:
				_relationship_system.registrar_recuerdo(participante_id, {
					"tipo": "evento_social",
					"evento": evento_memoria,
					"evento_id": objetivo_id,
					"con_personaje": pareja_id if participante_id == personaje_id else personaje_id,
					"importancia": 3.0,
					"momento": _clave_fecha_actual()
				})
		var resultado_experiencia := 0.35
		match tipo_motivo:
			"cumplir_promesa":
				resultado_experiencia = 0.65
			"resolver_asunto":
				resultado_experiencia = 0.8
			"compartir_noticia":
				resultado_experiencia = 0.45
			"resolver_desacuerdo":
				resultado_experiencia = 0.15
		_registrar_experiencia_social_npc(
			personaje_id, pareja_id, tipo_motivo, objetivo_id, resultado_experiencia
		)
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento != null:
		movimiento.detener_por_rutina()
	npc.remove_meta("npc_objetivo_social")
	npc.remove_meta("npc_objetivo_social_tiempo")
	npc.remove_meta("npc_objetivo_social_espera")
	npc.remove_meta("npc_objetivo_social_en_curso")
	npc.set_meta("rutina_en_transito", false)
	npc.set_meta("rutina_firma", "")
	npc.set_meta("npc_social_siguiente_intento", _clave_fecha_actual())
	if is_instance_valid(pareja):
		var sistema_conversaciones := get_tree().get_first_node_in_group("npc_conversation_system")
		if is_instance_valid(sistema_conversaciones) and sistema_conversaciones.has_method("iniciar_conversacion_social_autonoma"):
			sistema_conversaciones.call("iniciar_conversacion_social_autonoma", npc, pareja, motivo)


func _cancelar_objetivo_social_npc(npc: Creature, mind: Node, personaje_id: String) -> void:
	var objetivo: Dictionary = npc.get_meta("npc_objetivo_social", {})
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento != null:
		movimiento.detener_por_rutina()
	if not objetivo.is_empty():
		mind.call("completar_objetivo", personaje_id, str(objetivo.get("id", "")), false)
	npc.remove_meta("npc_objetivo_social")
	npc.remove_meta("npc_objetivo_social_tiempo")
	npc.remove_meta("npc_objetivo_social_en_curso")
	npc.set_meta("rutina_en_transito", false)
	npc.set_meta("rutina_firma", "")


func _clave_fecha_actual() -> String:
	if not is_instance_valid(_world_atmosphere):
		return ""
	var tiempo := _world_atmosphere.obtener_tiempo()
	return "%s:%s:%s" % [
		str(tiempo.get("anio", 0)),
		str(tiempo.get("mes", 0)),
		str(tiempo.get("dia", 1))
	]


func _obtener_satisfaccion_actividad(actividad: String) -> Dictionary:
	return NPC_SCHEDULE_RULES.obtener_satisfaccion_actividad(actividad)

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
	return NPC_SCHEDULE_RULES.obtener_evento_comunitario(
		int(tiempo.get("dia_de_estacion", 0)),
		dia_semana,
		minutos
	)


func _puede_participar_en_evento(rutina: Dictionary) -> bool:
	return NPC_SCHEDULE_RULES.puede_participar_en_evento(rutina)


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


func _registrar_observacion_evento_comunitario(npc: Creature, evento: Dictionary) -> void:
	if not is_instance_valid(npc) or not is_instance_valid(_relationship_system):
		return
	if not _relationship_system.has_method("registrar_observacion_evento_npc"):
		return
	var clave_evento := str(evento.get("clave", "")).strip_edges()
	# La asignación de una rutina no equivale a haber presenciado el evento.
	# Sólo se registra cuando el NPC ya llegó a su punto de reunión.
	if clave_evento.is_empty() or str(npc.get_meta("rutina_actual", "")) != clave_evento:
		return
	if bool(npc.get_meta("rutina_en_transito", true)):
		return
	var ancla_variant: Variant = npc.get_meta("rutina_ancla_ocio", null)
	if not ancla_variant is Vector2:
		return
	if npc.global_position.distance_to(ancla_variant as Vector2) > DISTANCIA_LLEGADA:
		return
	var personaje_id := npc.get_personaje_game_id().strip_edges()
	if personaje_id.is_empty():
		return
	var tiempo: Dictionary = _world_atmosphere.obtener_tiempo() if is_instance_valid(_world_atmosphere) else {}
	var anio := int(tiempo.get("anio", 0))
	var dia := int(tiempo.get("dia", 0))
	if anio <= 0 or dia <= 0:
		return
	var evento_con_fecha := evento.duplicate(true)
	evento_con_fecha["evento_id"] = "%s:%d:%d" % [clave_evento, anio, dia]
	var momento := "%d:%d" % [anio, dia]
	_relationship_system.call("registrar_observacion_evento_npc", personaje_id, evento_con_fecha, momento)


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


func _aplicar_turno_comercio_rotativo(
	npc: Creature,
	rutina_actual: Dictionary,
	dia_semana: int,
	minutos: int
) -> Dictionary:
	if not is_instance_valid(npc) or minutos < INICIO_TURNO_MERCADO or minutos >= FIN_TURNO_MERCADO:
		return rutina_actual
	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	if nombre == "saira" or not VENDEDORES_MERCADO_ROTATIVOS.has(nombre):
		return rutina_actual

	# No apartar a nadie de un oficio, guardia, investigación o compromiso.
	var clave_actual := str(rutina_actual.get("clave", "")).strip_edges().to_lower()
	var actividad_actual := str(rutina_actual.get("actividad_clave", "")).strip_edges().to_lower()
	var actividad_libre := (
		rutina_actual.is_empty()
		or clave_actual.begins_with("dia_libre")
		or actividad_actual.contains("descans")
		or actividad_actual.contains("pase")
		or actividad_actual.contains("convers")
		or actividad_actual.contains("visitar")
		or actividad_actual.contains("saludar")
		or actividad_actual.contains("volver")
	)
	if not actividad_libre:
		return rutina_actual
	if (
		clave_actual.begins_with("evento_")
		or clave_actual == "mercado_vecinal"
		or clave_actual == "celebracion_estacional"
		or clave_actual.begins_with("invitacion_")
		or clave_actual.begins_with("encuentro_")
	):
		return rutina_actual

	var franja := 0 if minutos < CAMBIO_TURNO_MERCADO else 1
	var inicio := posmod(dia_semana * 2 + franja * 3, VENDEDORES_MERCADO_ROTATIVOS.size())
	var asignados: Array[String] = [
		VENDEDORES_MERCADO_ROTATIVOS[inicio],
		VENDEDORES_MERCADO_ROTATIVOS[posmod(inicio + 1, VENDEDORES_MERCADO_ROTATIVOS.size())]
	]
	if not asignados.has(nombre):
		return rutina_actual

	return {
		"clave": "turno_puesto_comercio",
		"ubicacion_clave": "casa_comercio",
		"actividad_clave": "atender_puesto_comercio",
		"activo": true
	}


func _seleccionar_rutina_dia_libre(npc: Creature, minutos: int) -> Dictionary:
	return NPC_SCHEDULE_RULES.seleccionar_rutina_dia_libre(
		npc.get_nombre_visual(),
		minutos
	)


func _seleccionar_rutina(rutinas_variant: Variant, dia_semana: int, minutos: int, nombre_npc: String = "?") -> Dictionary:
	var resultado := NPC_SCHEDULE_RULES.seleccionar_rutina(rutinas_variant, dia_semana, minutos)
	var mejor: Dictionary = resultado.get("rutina", {})
	if mejor.is_empty() and rutinas_variant is Array:
		var diagnostico_rechazos: Array[String] = resultado.get("rechazos", [])
		var firma_fallo := "%s|%d|%d|%s" % [nombre_npc, dia_semana, minutos, str(diagnostico_rechazos)]
		if str(get_meta("ultimo_diagnostico_selector", "")) != firma_fallo:
			print("NPCScheduleSystem: SELECTOR SIN COINCIDENCIA | npc=", nombre_npc, " dia=", dia_semana, " minuto=", minutos, " total=", (rutinas_variant as Array).size(), " | ", str(diagnostico_rechazos))
			set_meta("ultimo_diagnostico_selector", firma_fallo)
	return mejor


func _crear_ruta(origen: Vector2, destino: Vector2) -> PackedVector2Array:
	if _malla == null or not _malla_lista:
		return PackedVector2Array()

	var inicio_id := _posicion_a_celda(origen)
	var destino_id := _posicion_a_celda(destino)
	inicio_id = _buscar_celda_transitable_cercana(inicio_id)
	destino_id = _buscar_celda_transitable_cercana(destino_id)
	if inicio_id.x < 0 or destino_id.x < 0:
		return PackedVector2Array()

	# No aceptar una celda de llegada arbitrariamente alejada de la puerta.
	# Una búsqueda amplia podía escoger una celda libre al otro lado del muro
	# y el sistema ocultaba al NPC como si ya hubiera entrado.
	var posicion_final := _malla.get_point_position(destino_id)
	if posicion_final.distance_to(destino) > DISTANCIA_MAXIMA_UMBRAL:
		return PackedVector2Array()

	var puntos := _malla.get_point_path(inicio_id, destino_id)
	if puntos.is_empty():
		# AStar no devuelve puntos cuando origen y destino están en la misma
		# celda. En ese caso aún puede faltar el pequeño tramo hasta el umbral.
		if inicio_id == destino_id and origen.distance_to(destino) <= DISTANCIA_MAXIMA_UMBRAL:
			return PackedVector2Array([_malla.get_point_position(destino_id)])
		return PackedVector2Array()

	var ruta := PackedVector2Array()
	for punto in puntos:
		if ruta.is_empty() and origen.distance_to(punto) <= DISTANCIA_LLEGADA:
			continue
		ruta.append(punto)
	if ruta.is_empty() and origen.distance_to(posicion_final) > DISTANCIA_LLEGADA:
		ruta.append(posicion_final)
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
	var mejor := Vector2i(-1, -1)
	var mejor_distancia := INF
	for y in range(-5, 6):
		for x in range(-5, 6):
			var candidata := celda + Vector2i(x, y)
			if not _malla.is_in_boundsv(candidata) or _malla.is_point_solid(candidata):
				continue
			var distancia := Vector2(candidata - celda).length_squared()
			if distancia < mejor_distancia:
				mejor = candidata
				mejor_distancia = distancia
	return mejor
