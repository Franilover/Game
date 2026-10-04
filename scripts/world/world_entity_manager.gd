extends Node
class_name WorldEntityManager

## Dueño del ciclo de vida de entidades del mundo.
## No decide qué debe aparecer: registra, agrupa, activa y elimina nodos.

var _entities_root: Node = null

var _by_chunk: Dictionary = {}
var _persistent_by_key: Dictionary = {}
var _global_entities: Array = []


func configurar(entities_root: Node) -> void:
	_entities_root = entities_root
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

	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	var bucket: Array = bucket_variant if bucket_variant is Array else []
	if not entity in bucket:
		bucket.append(entity)
	_by_chunk[chunk_coord] = bucket

	if not persistent_key.is_empty():
		_persistent_by_key[persistent_key] = entity

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
	if not persistent_key.is_empty():
		_persistent_by_key[persistent_key] = entity
	return true


func registrar_existente(
	entity: Node,
	chunk_coord: Vector2i,
	persistent_key: String = ""
) -> bool:
	return registrar(entity, chunk_coord, persistent_key)


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

		_remover_persistencia(entity)
		entity.queue_free()

	_by_chunk.erase(chunk_coord)


func limpiar_todo() -> void:
	var chunks := _by_chunk.keys()
	for chunk_variant in chunks:
		if chunk_variant is Vector2i:
			despawn_chunk(chunk_variant)
	_persistent_by_key.clear()
	_global_entities.clear()


func _remover_persistencia(entity: Node) -> void:
	var keys := _persistent_by_key.keys()
	for key_variant in keys:
		var key := str(key_variant)
		var value_variant: Variant = _persistent_by_key.get(key)
		if value_variant == entity:
			_persistent_by_key.erase(key)
