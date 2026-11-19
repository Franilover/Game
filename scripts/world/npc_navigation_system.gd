extends Node
class_name NPCNavigationSystem

signal malla_reconstruida

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
# Espera breve para agrupar varios cambios de posición/tamaño en una reconstrucción.
const ESPERA_RECONSTRUCCION_NAVEGACION := 1.0

var _zona: Node2D = null
var _terreno_visual: Node = null
var _malla: AStarGrid2D = null
var _malla_lista := false
var _construyendo_malla := false
var _firma_colisiones := ""
var _tiempo_cambio_colisiones := -1.0


func esta_lista() -> bool:
	return _malla_lista and _malla != null


## Sincroniza la malla con la zona activa. Devuelve true cuando las rutas
## pueden calcularse con la geometría actual.
func actualizar(zona_actual: Node2D, delta: float) -> bool:
	if not is_instance_valid(zona_actual):
		invalidar()
		return false
	if zona_actual != _zona:
		_zona = zona_actual
		_malla = null
		_malla_lista = false
		_construyendo_malla = false
		call_deferred("_construir_malla", zona_actual)
		return false
	if not esta_lista():
		return false
	if _detectar_cambios_geometria(zona_actual, delta):
		return false
	return esta_lista()


func invalidar() -> void:
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
	malla_reconstruida.emit()
	print("NPCNavigationSystem: navegación de Torres lista (", TAMANO_MALLA.x * TAMANO_MALLA.y, " celdas).")


## Aplica un coste menor a las celdas del atlas Tierra (zona 1).
## Los demás terrenos conservan su coste normal y siguen disponibles como
## desvíos o atajos cuando el camino de tierra no resulte conveniente.
func _aplicar_preferencia_terreno(malla: AStarGrid2D, celda: Vector2i, posicion_global: Vector2) -> void:
	if not is_instance_valid(_terreno_visual) or not _terreno_visual.has_method("obtener_zona_en_posicion"):
		return
	var zona_terreno: int = int(_terreno_visual.call("obtener_zona_en_posicion", posicion_global))
	var coste: float = COSTE_CAMINO_TIERRA if zona_terreno == 1 else COSTE_OTRO_TERRENO
	malla.set_point_weight_scale(celda, coste)


func crear_ruta(origen: Vector2, destino: Vector2) -> PackedVector2Array:
	if not esta_lista():
		return PackedVector2Array()

	var inicio_id := _posicion_a_celda(origen)
	var destino_id := _posicion_a_celda(destino)
	inicio_id = buscar_celda_transitable_cercana(_malla, inicio_id)
	destino_id = buscar_celda_transitable_cercana(_malla, destino_id)
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


static func buscar_celda_transitable_cercana(malla: AStarGrid2D, celda: Vector2i) -> Vector2i:
	if malla == null:
		return Vector2i(-1, -1)
	var mejor := Vector2i(-1, -1)
	var mejor_distancia := INF
	for y in range(-5, 6):
		for x in range(-5, 6):
			var candidata := celda + Vector2i(x, y)
			if not malla.is_in_boundsv(candidata) or malla.is_point_solid(candidata):
				continue
			var distancia := Vector2(candidata - celda).length_squared()
			if distancia < mejor_distancia:
				mejor = candidata
				mejor_distancia = distancia
	return mejor
