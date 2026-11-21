extends RefCounted
class_name CreaturePerception

## Descubre entidades que la IA puede percibir.
## No decide si una especie debe atacar, huir, perseguir o ignorar al candidato.
# Todas las criaturas consultan el grupo en sus ticks de percepción. La
# membresía del grupo cambia poco; compartir el snapshot por physics frame
# evita recorrer el SceneTree una vez por criatura.
static var _jugadores_cache_frame: int = -1
static var _jugadores_cache_tree_id: int = 0
static var _jugadores_cache: Array[Node2D] = []


static func _obtener_jugadores_del_grupo(arbol: SceneTree) -> Array[Node2D]:
	var frame_actual := Engine.get_physics_frames()
	var tree_id := arbol.get_instance_id()
	if frame_actual != _jugadores_cache_frame or tree_id != _jugadores_cache_tree_id:
		_jugadores_cache.clear()
		for jugador_variant in arbol.get_nodes_in_group("player"):
			if jugador_variant is Node2D:
				_jugadores_cache.append(jugador_variant as Node2D)
		_jugadores_cache_frame = frame_actual
		_jugadores_cache_tree_id = tree_id
	return _jugadores_cache


static func obtener_candidatos(
	criatura: Creature,
	jugador: Node2D,
	entity_manager: WorldEntityManager
) -> Array[Node2D]:
	var candidatos: Array[Node2D] = []
	var vistos: Dictionary = {}

	# La referencia explícita permite percibir al jugador antes de que se
	# registre en el grupo global, pero nunca conserva nodos muertos o retirados.
	if _es_candidato_activo(jugador):
		candidatos.append(jugador)
		vistos[jugador.get_instance_id()] = true

	# Los jugadores conectados se descubren por grupo. La referencia explícita
	# puede apuntar al ancla del mundo, por eso no sustituye esta búsqueda.
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol != null:
		for jugador_actual in _obtener_jugadores_del_grupo(arbol):
			if not _es_candidato_activo(jugador_actual):
				continue
			var jugador_id := jugador_actual.get_instance_id()
			if not vistos.has(jugador_id):
				vistos[jugador_id] = true
				candidatos.append(jugador_actual)

	if entity_manager == null or not is_instance_valid(entity_manager):
		return candidatos

	for entidad_variant in entity_manager.obtener_entidades_activas():
		if not entidad_variant is Entity:
			continue
		var entidad := entidad_variant as Entity
		if entidad == criatura or not _es_candidato_activo(entidad):
			continue
		var entidad_id := entidad.get_instance_id()
		if not vistos.has(entidad_id):
			vistos[entidad_id] = true
			candidatos.append(entidad)

	return candidatos


static func _es_candidato_activo(candidato: Node2D) -> bool:
	if candidato == null or not is_instance_valid(candidato):
		return false
	if not candidato.is_inside_tree() or candidato.is_queued_for_deletion():
		return false
	if "is_alive" in candidato and not bool(candidato.get("is_alive")):
		return false
	return true
