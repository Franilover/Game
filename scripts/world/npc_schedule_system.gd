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
	"casa_narel": Vector2(-520.0, -213.0)
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


static func tiene_ubicacion(clave: String) -> bool:
	return POSICIONES.has(clave.strip_edges().to_lower())


static func obtener_posicion_inicial(clave: String) -> Vector2:
	var buscada := clave.strip_edges().to_lower()
	var posicion: Variant = POSICIONES.get(buscada, POSICIONES["plaza"])
	if posicion is Vector2:
		return posicion
	return Vector2.ZERO


static func obtener_posicion_hogar(nombre_npc: String, ubicacion_respaldo: String = "plaza") -> Vector2:
	var clave := nombre_npc.strip_edges().to_lower()
	var hogares: Dictionary = {
		"elian": "casa_elian",
		"bruna": "casa_bruna",
		"darven": "casa_darven",
		"saira": "casa_saira",
		"narel": "casa_narel"
	}
	var ubicacion := str(hogares.get(clave, ubicacion_respaldo)).to_lower()
	return obtener_posicion_inicial(ubicacion)


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
		# Al entrar a un edificio, los NPC exteriores quedan ocultos. También
		# pausamos sus rutinas para que no avancen mientras el jugador está dentro.
		if not npc.visible:
			var movimiento_oculto := npc.get_node_or_null("CreatureMovement") as CreatureMovement
			if movimiento_oculto != null:
				movimiento_oculto.detener_por_rutina()
			npc.set_meta("rutina_firma", "")
			continue
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
	var rutinas_variant: Variant = npc.datos.get("rutinas", [])
	var rutina: Dictionary
	if dia_semana == 4:
		rutina = _seleccionar_rutina_dia_libre(npc, minutos)
	else:
		rutina = _seleccionar_rutina(rutinas_variant, dia_semana, minutos)

	var clave_rutina := str(rutina.get("clave", "descanso_base")).strip_edges()
	var ubicacion := str(rutina.get("ubicacion_clave", npc.datos.get("ubicacion_clave", ""))).strip_edges().to_lower()
	if ubicacion.is_empty() or ubicacion == "null" or not POSICIONES.has(ubicacion):
		ubicacion = str(npc.datos.get("ubicacion_clave", "")).strip_edges().to_lower()
	if ubicacion.is_empty() or ubicacion == "null" or not POSICIONES.has(ubicacion):
		ubicacion = "plaza"
	var actividad := str(rutina.get("actividad_clave", "descansar")).strip_edges()
	if actividad.is_empty():
		actividad = "descansar"

	var firma_anterior := str(npc.get_meta("rutina_firma", ""))
	var firma_nueva := clave_rutina + "|" + ubicacion + "|" + actividad
	if firma_anterior == firma_nueva:
		return

	var destino_local: Vector2 = POSICIONES[ubicacion]
	if rutina.is_empty():
		var hogar_variant: Variant = npc.datos.get("posicion_hogar_local", null)
		if hogar_variant is Vector2:
			destino_local = hogar_variant
	var destino_global := _zona.to_global(destino_local)
	var movimiento := npc.get_node_or_null("CreatureMovement") as CreatureMovement
	if movimiento == null:
		push_warning("NPCScheduleSystem: " + npc.get_nombre_visual() + " no tiene CreatureMovement.")
		return

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
	else:
		movimiento.detener_por_rutina()

	npc.set_meta("rutina_firma", firma_nueva)
	npc.set_meta("rutina_actual", clave_rutina)
	npc.set_meta("rutina_ubicacion", ubicacion)
	npc.datos["actividad_actual"] = actividad


func _seleccionar_rutina_dia_libre(npc: Creature, minutos: int) -> Dictionary:
	var nombre := npc.get_nombre_visual().strip_edges().to_lower()
	var hogares: Dictionary = {
		"elian": "casa_elian",
		"bruna": "casa_bruna",
		"darven": "casa_darven",
		"saira": "casa_saira",
		"narel": "casa_narel"
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


func _seleccionar_rutina(rutinas_variant: Variant, dia_semana: int, minutos: int) -> Dictionary:
	if not rutinas_variant is Array:
		return {}

	var mejor: Dictionary = {}
	var prioridad_mejor := -2147483648
	var inicio_mejor := -1

	for rutina_variant in rutinas_variant as Array:
		if not rutina_variant is Dictionary:
			continue
		var rutina := rutina_variant as Dictionary
		if not bool(rutina.get("activo", true)):
			continue

		var inicio := _hora_a_minutos(rutina.get("hora_inicio", ""))
		var fin := _hora_a_minutos(rutina.get("hora_fin", ""))
		if inicio < 0 or fin < 0 or inicio == fin:
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

		if not esta_activa or not _coincide_dia(rutina.get("dias_semana", []), dia_referencia):
			continue

		var prioridad := int(rutina.get("prioridad", 0))
		if mejor.is_empty() or prioridad > prioridad_mejor or (prioridad == prioridad_mejor and inicio > inicio_mejor):
			mejor = rutina.duplicate(true)
			prioridad_mejor = prioridad
			inicio_mejor = inicio

	return mejor


func _coincide_dia(dias_variant: Variant, dia: int) -> bool:
	if not dias_variant is Array or (dias_variant as Array).is_empty():
		return true
	return dia in (dias_variant as Array)


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
