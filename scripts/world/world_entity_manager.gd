extends Node
class_name WorldEntityManager

## Dueño del ciclo de vida de entidades del mundo.
## No decide qué debe aparecer: registra, agrupa, activa y elimina nodos.

var _entities_root: Node = null
var _entity_factory: WorldEntityFactory = null

var _by_chunk: Dictionary = {}
var _active_chunks: Dictionary = {}
var _persistent_by_key: Dictionary = {}
var _global_entities: Array = []
var _runtime_state_by_key: Dictionary = {}
var _runtime_prop_state_by_key: Dictionary = {}


func configurar(entities_root: Node, entity_factory: WorldEntityFactory = null) -> void:
	_entities_root = entities_root
	_entity_factory = entity_factory
	if _entities_root == null or not is_instance_valid(_entities_root):
		push_error("WorldEntityManager: Entity root inválido.")


func registrar(
	entity: Node,
	chunk_coord: Vector2i,
	persistent_key: String = ""
) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false

	var entities := _entities_root
	if entities == null or not is_instance_valid(entities):
		push_error("WorldEntityManager: Entity root no configurado.")
		return false

	if entity.get_parent() == null:
		entities.add_child(entity)

	_conectar_lifecycle(entity)

	# Una entidad persistente no pertenece al ciclo de vida del chunk.
	# Se registra como global para que el streaming nunca la destruya.
	if not persistent_key.is_empty():
		if not entity in _global_entities:
			_global_entities.append(entity)
		_persistent_by_key[persistent_key] = entity
		return true

	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	var bucket: Array = bucket_variant if bucket_variant is Array else []
	if not entity in bucket:
		bucket.append(entity)
	_by_chunk[chunk_coord] = bucket

	return true


func registrar_global(entity: Node, persistent_key: String = "") -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	var entities := _entities_root
	if entities == null or not is_instance_valid(entities):
		push_error("WorldEntityManager: Entity root no configurado.")
		return false
	if entity.get_parent() == null:
		entities.add_child(entity)
	if not entity in _global_entities:
		_global_entities.append(entity)
	_conectar_lifecycle(entity)
	if not persistent_key.is_empty():
		_persistent_by_key[persistent_key] = entity
	return true


func registrar_existente(
	entity: Node,
	chunk_coord: Vector2i,
	persistent_key: String = ""
) -> bool:
	return registrar(entity, chunk_coord, persistent_key)


func activar_chunk(chunk_coord: Vector2i) -> void:
	_active_chunks[chunk_coord] = true


func tiene_chunk(chunk_coord: Vector2i) -> bool:
	if _active_chunks.has(chunk_coord):
		return true
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	if not bucket_variant is Array:
		return false
	for entity_variant in bucket_variant:
		if entity_variant is Node and is_instance_valid(entity_variant):
			return true
	return false


func _conectar_lifecycle(entity: Node) -> void:
	if not entity.tree_exiting.is_connected(_al_salir_entidad.bind(entity)):
		entity.tree_exiting.connect(_al_salir_entidad.bind(entity))


func _al_salir_entidad(entity: Node) -> void:
	_global_entities.erase(entity)
	for chunk_variant in _by_chunk.keys():
		var chunk_coord: Vector2i = chunk_variant
		var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
		if not bucket_variant is Array:
			continue
		var bucket: Array = bucket_variant
		bucket.erase(entity)
		if bucket.is_empty():
			_by_chunk.erase(chunk_coord)
		else:
			_by_chunk[chunk_coord] = bucket
	_remover_persistencia(entity)


func obtener_entidades_activas() -> Array:
	var resultado: Array = []
	for bucket_variant in _by_chunk.values():
		if not bucket_variant is Array:
			continue
		for entity_variant in bucket_variant as Array:
			if entity_variant is Node and is_instance_valid(entity_variant):
				resultado.append(entity_variant)
	for entity_variant in _global_entities:
		if entity_variant is Node and is_instance_valid(entity_variant):
			if not entity_variant in resultado:
				resultado.append(entity_variant)
	return resultado


func obtener_por_chunk(chunk_coord: Vector2i) -> Array:
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	if bucket_variant is Array:
		return bucket_variant.duplicate()
	return []


func existe_persistente(key: String) -> bool:
	var entity_variant: Variant = _persistent_by_key.get(key)
	return entity_variant != null and is_instance_valid(entity_variant)


func obtener_persistente(key: String) -> Node:
	var entity_variant: Variant = _persistent_by_key.get(key)
	if entity_variant is Node and is_instance_valid(entity_variant):
		return entity_variant
	_persistent_by_key.erase(key)
	return null


func guardar_estado_entidad(entity: Node, chunk_coord: Vector2i) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	if entity is WorldProp:
		var prop := entity as WorldProp
		var prop_key := str(prop.get_meta("runtime_instance_key", "")).strip_edges()
		if prop_key.is_empty():
			var datos_prop := prop.obtener_datos()
			prop_key = str(datos_prop.get("id", "prop")).strip_edges()
		var prop_state_key := _runtime_key(chunk_coord, prop_key)
		_runtime_prop_state_by_key[prop_state_key] = {
			"position": prop.global_position,
			"runtime_instance_key": prop_key,
			"datos": prop.obtener_datos()
		}
		return
	if not entity is Creature:
		return
	var criatura := entity as Creature
	var criatura_id := criatura.get_id().strip_edges()
	if criatura_id.is_empty():
		return
	var instance_key := str(criatura.get_meta("runtime_instance_key", "")).strip_edges()
	if instance_key.is_empty():
		instance_key = _runtime_key(chunk_coord, criatura_id)
	var key := _runtime_key(chunk_coord, instance_key)
	_runtime_state_by_key[key] = {
		"criatura_id": criatura_id,
		"position": criatura.global_position,
		"velocity": criatura.velocity,
		"health": criatura.health,
		"max_health": criatura.max_health,
		"is_alive": criatura.is_alive,
		"estado": criatura.get_meta("estado_mundo", "")
	}


func obtener_estado_criatura(chunk_coord: Vector2i, criatura_id: String, instance_key: String = "") -> Dictionary:
	var clave_instancia := instance_key.strip_edges()
	if clave_instancia.is_empty():
		clave_instancia = criatura_id
	var key := _runtime_key(chunk_coord, clave_instancia)
	var estado: Variant = _runtime_state_by_key.get(key, {})
	if estado is Dictionary:
		return (estado as Dictionary).duplicate(true)
	return {}


func _runtime_key(chunk_coord: Vector2i, instance_key: String) -> String:
	return str(chunk_coord.x) + ":" + str(chunk_coord.y) + ":" + instance_key


func obtener_estado_prop(chunk_coord: Vector2i, instance_key: String) -> Dictionary:
	var key := _runtime_key(chunk_coord, instance_key)
	var estado: Variant = _runtime_prop_state_by_key.get(key, {})
	if estado is Dictionary:
		return (estado as Dictionary).duplicate(true)
	return {}


func despawn_chunk(chunk_coord: Vector2i) -> void:
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	if not bucket_variant is Array:
		_by_chunk.erase(chunk_coord)
		return

	for entity_variant in bucket_variant:
		if not entity_variant is Node:
			continue
		var entity := entity_variant as Node
		if not is_instance_valid(entity):
			continue

		guardar_estado_entidad(entity, chunk_coord)
		_remover_persistencia(entity)
		if _entity_factory != null and is_instance_valid(_entity_factory):
			if entity is Creature:
				_entity_factory.reciclar_criatura(entity as Creature)
			elif entity is WorldProp:
				_entity_factory.reciclar_prop(entity as WorldProp)
			else:
				entity.queue_free()
		else:
			entity.queue_free()

	_by_chunk.erase(chunk_coord)
	_active_chunks.erase(chunk_coord)


func limpiar_todo() -> void:
	var chunks := _by_chunk.keys()
	for chunk_variant in chunks:
		if chunk_variant is Vector2i:
			despawn_chunk(chunk_variant)
	for entity_variant in _global_entities:
		if entity_variant is Node and is_instance_valid(entity_variant):
			(entity_variant as Node).queue_free()
	_persistent_by_key.clear()
	_global_entities.clear()
	_active_chunks.clear()


func _remover_persistencia(entity: Node) -> void:
	var keys := _persistent_by_key.keys()
	for key_variant in keys:
		var key := str(key_variant)
		var value_variant: Variant = _persistent_by_key.get(key)
		if value_variant == entity:
			_persistent_by_key.erase(key)
