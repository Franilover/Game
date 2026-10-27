extends Node
class_name WorldEntityManager

## Dueño del ciclo de vida de entidades del mundo.
## No decide qué debe aparecer: registra, agrupa, activa y elimina nodos.

var _entities_root: Node = null
var _entity_factory: WorldEntityFactory = null

var _by_chunk: Dictionary = {}
var _active_chunks: Dictionary = {}
var _active_creature_chunks: Dictionary = {}
var _active_prop_chunks: Dictionary = {}
var _persistent_by_key: Dictionary = {}
var _global_entities: Array = []
var _runtime_state_by_key: Dictionary = {}
var _runtime_prop_state_by_key: Dictionary = {}
var _data_by_chunk: Dictionary = {}


func registrar_dato_chunk(chunk_coord: Vector2i, tipo: String, datos: Dictionary) -> void:
	var bucket_variant: Variant = _data_by_chunk.get(chunk_coord, {})
	var bucket: Dictionary = bucket_variant if bucket_variant is Dictionary else {}
	var lista_variant: Variant = bucket.get(tipo, [])
	var lista: Array = lista_variant if lista_variant is Array else []
	lista.append(datos.duplicate(true))
	bucket[tipo] = lista
	_data_by_chunk[chunk_coord] = bucket


func guardar_dato_chunk(chunk_coord: Vector2i, tipo: String, datos: Dictionary) -> void:
	var bucket_variant: Variant = _data_by_chunk.get(chunk_coord, {})
	var bucket: Dictionary = bucket_variant if bucket_variant is Dictionary else {}
	var lista_variant: Variant = bucket.get(tipo, [])
	var lista: Array = lista_variant if lista_variant is Array else []
	var instance_key := str(datos.get("runtime_instance_key", ""))
	var reemplazado := false
	if not instance_key.is_empty():
		for i in range(lista.size()):
			var existente_variant: Variant = lista[i]
			if existente_variant is Dictionary and str((existente_variant as Dictionary).get("runtime_instance_key", "")) == instance_key:
				lista[i] = datos.duplicate(true)
				reemplazado = true
				break
	if not reemplazado:
		lista.append(datos.duplicate(true))
	bucket[tipo] = lista
	_data_by_chunk[chunk_coord] = bucket


func reemplazar_datos_chunk(chunk_coord: Vector2i, tipo: String, datos: Array) -> void:
	var bucket_variant: Variant = _data_by_chunk.get(chunk_coord, {})
	var bucket: Dictionary = bucket_variant if bucket_variant is Dictionary else {}
	bucket[tipo] = datos.duplicate(true)
	_data_by_chunk[chunk_coord] = bucket


func obtener_datos_chunk(chunk_coord: Vector2i, tipo: String) -> Array:
	var bucket_variant: Variant = _data_by_chunk.get(chunk_coord, {})
	if not bucket_variant is Dictionary:
		return []
	var datos_variant: Variant = (bucket_variant as Dictionary).get(tipo, [])
	if datos_variant is Array:
		return (datos_variant as Array).duplicate(true)
	return []


func limpiar_datos_chunk(chunk_coord: Vector2i) -> void:
	_data_by_chunk.erase(chunk_coord)


func tiene_datos_chunk(chunk_coord: Vector2i, tipo: String = "") -> bool:
	var bucket_variant: Variant = _data_by_chunk.get(chunk_coord, {})
	if not bucket_variant is Dictionary:
		return false
	if tipo.is_empty():
		return true
	var datos_variant: Variant = (bucket_variant as Dictionary).get(tipo, [])
	return datos_variant is Array and not (datos_variant as Array).is_empty()


func limpiar_datos_fuera_de_radio(centro: Vector2i, radio: int) -> int:
	var eliminados := 0
	var para_borrar: Array[Vector2i] = []
	for coord_variant in _data_by_chunk.keys():
		if not coord_variant is Vector2i:
			continue
		var coord := coord_variant as Vector2i
		var distancia := maxi(abs(coord.x - centro.x), abs(coord.y - centro.y))
		if distancia > radio:
			para_borrar.append(coord)
	for coord in para_borrar:
		_data_by_chunk.erase(coord)
		eliminados += 1
	return eliminados


func obtener_diagnostico_datos() -> Dictionary:
	var props := 0
	var criaturas := 0
	for bucket_variant in _data_by_chunk.values():
		if not bucket_variant is Dictionary:
			continue
		var bucket := bucket_variant as Dictionary
		var props_variant: Variant = bucket.get("props", [])
		var criaturas_variant: Variant = bucket.get("criaturas", [])
		if props_variant is Array:
			props += (props_variant as Array).size()
		if criaturas_variant is Array:
			criaturas += (criaturas_variant as Array).size()
	return {"chunks": _data_by_chunk.size(), "props": props, "criaturas": criaturas, "runtime_criaturas": _runtime_state_by_key.size(), "runtime_props": _runtime_prop_state_by_key.size()}


func configurar(entities_root: Node, entity_factory: WorldEntityFactory = null) -> void:
	_entities_root = entities_root
	# Una configuración posterior puede actualizar sólo el root; no debe
	# borrar la fábrica ya registrada si el argumento opcional viene vacío.
	if entity_factory != null:
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
	_active_creature_chunks[chunk_coord] = true
	_active_prop_chunks[chunk_coord] = true


func activar_criaturas_chunk(chunk_coord: Vector2i) -> void:
	_active_creature_chunks[chunk_coord] = true
	_recalcular_chunk_activo(chunk_coord)


func activar_props_chunk(chunk_coord: Vector2i) -> void:
	_active_prop_chunks[chunk_coord] = true
	_recalcular_chunk_activo(chunk_coord)


func tiene_criaturas_chunk(chunk_coord: Vector2i) -> bool:
	if _active_creature_chunks.has(chunk_coord):
		return true
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	if not bucket_variant is Array:
		return false
	for entity_variant in bucket_variant:
		if entity_variant is Creature and is_instance_valid(entity_variant):
			return true
	return false


func tiene_props_chunk(chunk_coord: Vector2i) -> bool:
	if _active_prop_chunks.has(chunk_coord):
		return true
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	if not bucket_variant is Array:
		return false
	for entity_variant in bucket_variant:
		if entity_variant is WorldProp and is_instance_valid(entity_variant):
			return true
	return false


func tiene_chunk(chunk_coord: Vector2i) -> bool:
	return tiene_criaturas_chunk(chunk_coord) or tiene_props_chunk(chunk_coord)


func _recalcular_chunk_activo(chunk_coord: Vector2i) -> void:
	if _active_creature_chunks.has(chunk_coord) and _active_prop_chunks.has(chunk_coord):
		_active_chunks[chunk_coord] = true
	else:
		_active_chunks.erase(chunk_coord)


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
		var datos_prop := prop.obtener_datos()
		_runtime_prop_state_by_key[prop_state_key] = {
			"position": prop.global_position,
			"runtime_instance_key": prop_key,
			"datos": datos_prop
		}
		var registro_prop := datos_prop.duplicate(true)
		registro_prop["runtime_instance_key"] = prop_key
		registro_prop["position"] = prop.global_position
		guardar_dato_chunk(chunk_coord, "props", registro_prop)
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
	var categoria_entidad := str(criatura.datos.get("categoria_entidad", "criatura")).strip_edges().to_lower()
	var datos_criatura := {
		"criatura_id": criatura_id,
		"categoria_entidad": categoria_entidad,
		"asset_key": str(criatura.datos.get("asset_key", "")),
		"habitat_clave": criatura.entorno,
		"nombre": criatura.criatura_nombre,
		"garumi_debug_preview": bool(criatura.datos.get("garumi_debug_preview", false)),
		"garumi_debug_preview": bool(criatura.datos.get("garumi_debug_preview", false)),
		"position": criatura.global_position,
		"velocity": criatura.velocity,
		"health": criatura.health,
		"max_health": criatura.max_health,
		"is_alive": criatura.is_alive,
		"estado": criatura.get_meta("estado_mundo", "")
	}
	_runtime_state_by_key[key] = datos_criatura
	var registro_criatura := datos_criatura.duplicate(true)
	registro_criatura["runtime_instance_key"] = instance_key
	guardar_dato_chunk(chunk_coord, "criaturas", registro_criatura)


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


func despawn_criaturas_chunk(chunk_coord: Vector2i) -> void:
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	if not bucket_variant is Array:
		_active_creature_chunks.erase(chunk_coord)
		_recalcular_chunk_activo(chunk_coord)
		return

	var restantes: Array = []
	for entity_variant in bucket_variant as Array:
		if not entity_variant is Node:
			continue
		var entity := entity_variant as Node
		if not is_instance_valid(entity):
			continue
		if not entity is Creature:
			restantes.append(entity)
			continue
		guardar_estado_entidad(entity, chunk_coord)
		_remover_persistencia(entity)
		if _entity_factory != null and is_instance_valid(_entity_factory):
			_entity_factory.reciclar_criatura(entity as Creature)
		else:
			entity.queue_free()

	if restantes.is_empty():
		_by_chunk.erase(chunk_coord)
	else:
		_by_chunk[chunk_coord] = restantes
	_active_creature_chunks.erase(chunk_coord)
	_recalcular_chunk_activo(chunk_coord)


func despawn_props_chunk(chunk_coord: Vector2i) -> void:
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	if not bucket_variant is Array:
		_active_prop_chunks.erase(chunk_coord)
		_recalcular_chunk_activo(chunk_coord)
		return

	var restantes: Array = []
	for entity_variant in bucket_variant as Array:
		if not entity_variant is Node:
			continue
		var entity := entity_variant as Node
		if not is_instance_valid(entity):
			continue
		if not entity is WorldProp:
			restantes.append(entity)
			continue
		guardar_estado_entidad(entity, chunk_coord)
		_remover_persistencia(entity)
		if _entity_factory != null and is_instance_valid(_entity_factory):
			_entity_factory.reciclar_prop(entity as WorldProp)
		else:
			entity.queue_free()

	if restantes.is_empty():
		_by_chunk.erase(chunk_coord)
	else:
		_by_chunk[chunk_coord] = restantes
	_active_prop_chunks.erase(chunk_coord)
	_recalcular_chunk_activo(chunk_coord)


func despawn_chunk(chunk_coord: Vector2i) -> void:
	despawn_criaturas_chunk(chunk_coord)
	despawn_props_chunk(chunk_coord)
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
	_active_creature_chunks.clear()
	_active_prop_chunks.clear()
	_data_by_chunk.clear()


func _remover_persistencia(entity: Node) -> void:
	var keys := _persistent_by_key.keys()
	for key_variant in keys:
		var key := str(key_variant)
		var value_variant: Variant = _persistent_by_key.get(key)
		if value_variant == entity:
			_persistent_by_key.erase(key)
