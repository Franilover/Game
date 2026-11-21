extends Node
class_name WorldEntityManager

## Dueño del ciclo de vida de entidades del mundo.
## No decide qué debe aparecer: registra, agrupa, activa y elimina nodos.

var _entities_root: Node = null
var _entity_factory: WorldEntityFactory = null

var _by_chunk: Dictionary = {}
var _chunk_by_entity: Dictionary = {}
var _active_chunks: Dictionary = {}
var _active_creature_chunks: Dictionary = {}
var _active_prop_chunks: Dictionary = {}
var _persistent_by_key: Dictionary = {}
var _persistent_keys_by_entity: Dictionary = {}
var _global_entities: Array = []
var _runtime_state_by_key: Dictionary = {}
var _runtime_prop_state_by_key: Dictionary = {}
var _replicas_red_by_key: Dictionary = {}
var _replicas_red_props_by_key: Dictionary = {}
var _replica_keys_by_entity: Dictionary = {}
var _replica_prop_keys_by_entity: Dictionary = {}
var _data_by_chunk: Dictionary = {}
var _despawn_jobs: Dictionary = {}
var _active_entities_cache: Array = []
var _active_entities_cache_dirty: bool = true

var _diag_despawn_creature_count: int = 0
var _diag_despawn_prop_count: int = 0
var _diag_despawn_creature_last_ms: float = 0.0
var _diag_despawn_creature_max_ms: float = 0.0
var _diag_despawn_prop_last_ms: float = 0.0
var _diag_despawn_prop_max_ms: float = 0.0


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


func obtener_datos_chunk(
	chunk_coord: Vector2i,
	tipo: String,
	duplicar_profundo: bool = true
) -> Array:
	var bucket_variant: Variant = _data_by_chunk.get(chunk_coord, {})
	if not bucket_variant is Dictionary:
		return []
	var datos_variant: Variant = (bucket_variant as Dictionary).get(tipo, [])
	if not datos_variant is Array:
		return []
	# Los consumidores que sólo leen el array y duplican cada Dictionary
	# antes de modificarlo pueden evitar una segunda copia profunda completa.
	return (datos_variant as Array).duplicate(duplicar_profundo)


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

	# Estas métricas sólo se calculan al abrir F4. Permiten distinguir el
	# número de estados persistentes del número de chunks que los originaron.
	var chunks_runtime_criaturas: Dictionary = {}
	var chunks_runtime_props: Dictionary = {}
	var aliases_criaturas := 0
	for clave_variant in _runtime_state_by_key.keys():
		var partes := str(clave_variant).split(":", true, 2)
		if partes.size() < 3:
			continue
		var chunk_key := partes[0] + ":" + partes[1]
		chunks_runtime_criaturas[chunk_key] = int(chunks_runtime_criaturas.get(chunk_key, 0)) + 1
		var estado_variant: Variant = _runtime_state_by_key.get(clave_variant, {})
		if estado_variant is Dictionary:
			var criatura_id := str((estado_variant as Dictionary).get("criatura_id", ""))
			if not criatura_id.is_empty() and partes[2] != criatura_id and not partes[2].begins_with("personaje:"):
				aliases_criaturas += 1
	for clave_variant in _runtime_prop_state_by_key.keys():
		var partes := str(clave_variant).split(":", true, 2)
		if partes.size() < 3:
			continue
		var chunk_key := partes[0] + ":" + partes[1]
		chunks_runtime_props[chunk_key] = int(chunks_runtime_props.get(chunk_key, 0)) + 1

	var max_criaturas_por_chunk := 0
	for cantidad_variant in chunks_runtime_criaturas.values():
		max_criaturas_por_chunk = maxi(max_criaturas_por_chunk, int(cantidad_variant))
	var max_props_por_chunk := 0
	for cantidad_variant in chunks_runtime_props.values():
		max_props_por_chunk = maxi(max_props_por_chunk, int(cantidad_variant))

	return {
		"chunks": _data_by_chunk.size(),
		"props": props,
		"criaturas": criaturas,
		"runtime_criaturas": _runtime_state_by_key.size(),
		"runtime_props": _runtime_prop_state_by_key.size(),
		"runtime_criaturas_chunks": chunks_runtime_criaturas.size(),
		"runtime_props_chunks": chunks_runtime_props.size(),
		"runtime_criaturas_aliases": aliases_criaturas,
		"runtime_criaturas_max_por_chunk": max_criaturas_por_chunk,
		"runtime_props_max_por_chunk": max_props_por_chunk
	}


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
	_active_entities_cache_dirty = true

	# Una entidad persistente no pertenece al ciclo de vida del chunk.
	# Se registra como global para que el streaming nunca la destruya.
	if not persistent_key.is_empty():
		if not entity in _global_entities:
			_global_entities.append(entity)
		_registrar_clave_persistente(entity, persistent_key)
		return true

	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	var bucket: Array = bucket_variant if bucket_variant is Array else []
	if not entity in bucket:
		bucket.append(entity)
	_by_chunk[chunk_coord] = bucket
	_chunk_by_entity[entity] = chunk_coord

	return true


func registrar_replica_red(datos: Dictionary, chunk_coord: Vector2i, instance_key: String, limites_chunk: Rect2 = Rect2()) -> Creature:
	if instance_key.is_empty() or _entity_factory == null:
		return null
	var existente_variant: Variant = _replicas_red_by_key.get(instance_key)
	if existente_variant is Creature and is_instance_valid(existente_variant):
		return existente_variant as Creature
	var criatura_variant: Variant = _entity_factory.crear_criatura(datos)
	if not criatura_variant is Creature:
		return null
	var criatura := criatura_variant as Creature
	var partes_clave := instance_key.split("|")
	var runtime_key := str(partes_clave[partes_clave.size() - 1]) if not partes_clave.is_empty() else instance_key
	criatura.set_meta("runtime_instance_key", runtime_key)
	if not registrar(criatura, chunk_coord):
		criatura.queue_free()
		return null
	criatura.configurar_chunk(chunk_coord, limites_chunk)
	_registrar_clave_replica(_replicas_red_by_key, _replica_keys_by_entity, criatura, instance_key)
	return criatura


func registrar_replica_prop_red(datos: Dictionary, chunk_coord: Vector2i, instance_key: String) -> WorldProp:
	if instance_key.is_empty() or _entity_factory == null:
		return null
	var existente_variant: Variant = _replicas_red_props_by_key.get(instance_key)
	if existente_variant is WorldProp and is_instance_valid(existente_variant):
		return existente_variant as WorldProp
	var prop_variant: Variant = _entity_factory.crear_prop(datos)
	if not prop_variant is WorldProp:
		return null
	var prop := prop_variant as WorldProp
	var partes_clave := instance_key.split("|")
	var runtime_key := str(partes_clave[partes_clave.size() - 1]) if not partes_clave.is_empty() else instance_key
	prop.set_meta("runtime_instance_key", runtime_key)
	if not registrar(prop, chunk_coord):
		prop.queue_free()
		return null
	var limite := Rect2()
	var limite_variant: Variant = datos.get("limite_chunk", Rect2())
	if limite_variant is Rect2:
		limite = limite_variant
	prop.configurar_chunk(chunk_coord, limite)
	_registrar_clave_replica(_replicas_red_props_by_key, _replica_prop_keys_by_entity, prop, instance_key)
	return prop


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
	_active_entities_cache_dirty = true
	if not persistent_key.is_empty():
		_registrar_clave_persistente(entity, persistent_key)
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
	_active_entities_cache_dirty = true
	# Una recolección elimina el prop del árbol antes de descargar el chunk.
	# Registrar el tombstone aquí evita que los datos originales lo regeneren.
	if entity is WorldProp and entity.is_queued_for_deletion() and not bool(entity.get_meta("world_manager_unloading", false)):
		var chunk_recolectado: Variant = _obtener_chunk_de_entidad(entity)
		if chunk_recolectado is Vector2i:
			_guardar_tombstone_prop_recolectado(entity as WorldProp, chunk_recolectado as Vector2i)

	_global_entities.erase(entity)
	var chunk_variant: Variant = _chunk_by_entity.get(entity, null)
	if chunk_variant is Vector2i:
		var chunk_coord := chunk_variant as Vector2i
		var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
		if bucket_variant is Array:
			var bucket := bucket_variant as Array
			bucket.erase(entity)
			if bucket.is_empty():
				_by_chunk.erase(chunk_coord)
			else:
				_by_chunk[chunk_coord] = bucket
	_chunk_by_entity.erase(entity)
	_limpiar_referencias_replica(_replicas_red_by_key, _replica_keys_by_entity, entity)
	_limpiar_referencias_replica(_replicas_red_props_by_key, _replica_prop_keys_by_entity, entity)
	_remover_persistencia(entity)


func _obtener_chunk_de_entidad(entity: Node) -> Variant:
	return _chunk_by_entity.get(entity, null)


func _guardar_tombstone_prop_recolectado(prop: WorldProp, chunk_coord: Vector2i) -> void:
	var datos_prop := prop.obtener_datos()
	var prop_key := str(prop.get_meta("runtime_instance_key", "")).strip_edges()
	if prop_key.is_empty():
		prop_key = str(datos_prop.get("id", datos_prop.get("clave", datos_prop.get("nombre", "")))).strip_edges()
	if prop_key.is_empty():
		return
	datos_prop["runtime_instance_key"] = prop_key
	datos_prop["chunk"] = chunk_coord
	datos_prop["is_present"] = false
	_runtime_prop_state_by_key[_runtime_key(chunk_coord, prop_key)] = {
		"runtime_instance_key": prop_key,
		"is_present": false,
		"datos": datos_prop
	}
	# Actualizar sólo una entrada DATA ya existente. No obtener/reemplazar
	# el Array completo: esas funciones hacen copias profundas de todos los
	# props del chunk para cambiar un único booleano.
	var bucket_variant: Variant = _data_by_chunk.get(chunk_coord, {})
	if not bucket_variant is Dictionary:
		return
	var bucket := bucket_variant as Dictionary
	var datos_variant: Variant = bucket.get("props", [])
	if not datos_variant is Array:
		return
	var datos := datos_variant as Array
	for indice in range(datos.size()):
		var dato_variant: Variant = datos[indice]
		if not dato_variant is Dictionary:
			continue
		var dato := dato_variant as Dictionary
		if str(dato.get("runtime_instance_key", "")) != prop_key:
			continue
		# Copia superficial: sólo cambia is_present y conserva aislado el
		# diccionario original sin duplicar estructuras anidadas.
		var dato_actualizado := dato.duplicate()
		dato_actualizado["is_present"] = false
		datos[indice] = dato_actualizado
		bucket["props"] = datos
		_data_by_chunk[chunk_coord] = bucket
		break


func _registrar_clave_replica(
	registro: Dictionary,
	indice_por_entidad: Dictionary,
	entity: Node,
	instance_key: String
) -> void:
	# Mantener un índice inverso evita recorrer todas las réplicas cuando una
	# entidad sale del árbol. También limpia una asociación anterior si una
	# clave de red se reasigna a otra instancia.
	var anterior_variant: Variant = registro.get(instance_key, null)
	if anterior_variant is Node and anterior_variant != entity:
		var claves_anteriores_variant: Variant = indice_por_entidad.get(anterior_variant, [])
		if claves_anteriores_variant is Array:
			(claves_anteriores_variant as Array).erase(instance_key)
			if (claves_anteriores_variant as Array).is_empty():
				indice_por_entidad.erase(anterior_variant)

	registro[instance_key] = entity
	var claves_variant: Variant = indice_por_entidad.get(entity, [])
	var claves: Array = claves_variant if claves_variant is Array else []
	if instance_key not in claves:
		claves.append(instance_key)
	indice_por_entidad[entity] = claves


func _limpiar_referencias_replica(
	registro: Dictionary,
	indice_por_entidad: Dictionary,
	entity: Node
) -> void:
	# El coste queda limitado a las claves asociadas a esta entidad (normalmente
	# una), en lugar de recorrer todas las réplicas materializadas en la sesión.
	var claves_variant: Variant = indice_por_entidad.get(entity, [])
	if not claves_variant is Array:
		return
	for clave_variant in claves_variant as Array:
		var clave := str(clave_variant)
		if registro.get(clave, null) == entity:
			registro.erase(clave)
	indice_por_entidad.erase(entity)



func _invalidar_cache_entidades_activas() -> void:
	_active_entities_cache_dirty = true


func obtener_entidades_activas() -> Array:
	# La percepción de cada criatura consulta este conjunto varias veces por
	# segundo. Reconstruirlo por IA recorría todos los chunks y asignaba un
	# Array/Dictionary por consulta. Se conserva hasta un cambio de membresía.
	if _active_entities_cache_dirty:
		_active_entities_cache.clear()
		var vistos: Dictionary = {}
		for bucket_variant in _by_chunk.values():
			if not bucket_variant is Array:
				continue
			for entity_variant in bucket_variant as Array:
				if entity_variant is Node and is_instance_valid(entity_variant) and not vistos.has(entity_variant):
					vistos[entity_variant] = true
					_active_entities_cache.append(entity_variant)
		for entity_variant in _global_entities:
			if entity_variant is Node and is_instance_valid(entity_variant) and not vistos.has(entity_variant):
				vistos[entity_variant] = true
				_active_entities_cache.append(entity_variant)
		_active_entities_cache_dirty = false
	return _active_entities_cache


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


func capturar_estado_persistente_mundo() -> Dictionary:
	# Capturamos también las criaturas que siguen materializadas: el guardado
	# normal por chunk ocurre al descargarlas, pero el servidor puede pausarse
	# con muchos chunks todavía activos.
	for entidad_variant in obtener_entidades_activas():
		if not is_instance_valid(entidad_variant):
			continue
		if entidad_variant is WorldProp:
			var prop := entidad_variant as WorldProp
			var chunk_variant: Variant = prop.datos.get("chunk", Vector2i.ZERO)
			var chunk_coord := Vector2i.ZERO
			if chunk_variant is Vector2i:
				chunk_coord = chunk_variant
			elif chunk_variant is Dictionary:
				var chunk_data := chunk_variant as Dictionary
				chunk_coord = Vector2i(int(chunk_data.get("x", 0)), int(chunk_data.get("y", 0)))
			guardar_estado_entidad(prop, chunk_coord)
			continue
		if not entidad_variant is Creature:
			continue
		var criatura := entidad_variant as Creature
		# Los Garumis vinculados pertenecen al guardado privado del jugador.
		# Sólo se conserva el tombstone del spawn salvaje original para impedir
		# que vuelva a aparecer al regenerar el chunk.
		if criatura is Garumi and (criatura as Garumi).esta_vinculado():
			_guardar_tombstone_garumi_vinculado(criatura as Garumi)
			continue
		guardar_estado_entidad(criatura, criatura.chunk_coord)
	return {
		"criaturas": _runtime_state_by_key.duplicate(true),
		"props": _runtime_prop_state_by_key.duplicate(true)
	}


func _guardar_tombstone_garumi_vinculado(garumi: Garumi) -> void:
	var instancia := str(garumi.get_meta("runtime_instance_key", "")).strip_edges()
	if not (instancia.begins_with("garumi:") or instancia.begins_with("natural:")):
		return
	var criatura_id := garumi.get_id().strip_edges()
	if criatura_id.is_empty():
		return
	var chunk := garumi.chunk_coord
	var tombstone := {
		"criatura_id": criatura_id,
		"categoria_entidad": "garumi",
		"runtime_instance_key": instancia,
		"position": garumi.global_position,
		"velocity": Vector2.ZERO,
		"estado": "vinculado"
	}
	_runtime_state_by_key[_runtime_key(chunk, instancia)] = tombstone
	# El ID del Garumi es único por chunk en la generación natural.
	_runtime_state_by_key[_runtime_key(chunk, criatura_id)] = tombstone.duplicate(true)


func restaurar_estado_persistente_mundo(estado: Dictionary) -> void:
	var criaturas_variant: Variant = estado.get("criaturas", {})
	var props_variant: Variant = estado.get("props", {})
	_runtime_state_by_key = (criaturas_variant as Dictionary).duplicate(true) if criaturas_variant is Dictionary else {}
	_runtime_prop_state_by_key = (props_variant as Dictionary).duplicate(true) if props_variant is Dictionary else {}
	print(
		"WorldEntityManager: estado global recuperado → criaturas=",
		_runtime_state_by_key.size(),
		" | props=",
		_runtime_prop_state_by_key.size()
	)


func guardar_estado_entidad(entity: Node, chunk_coord: Vector2i) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	if entity is WorldProp:
		var prop := entity as WorldProp
		if prop.is_queued_for_deletion():
			var chunk_variant: Variant = _obtener_chunk_de_entidad(prop)
			if chunk_variant is Vector2i:
				_guardar_tombstone_prop_recolectado(prop, chunk_variant as Vector2i)
			return
		var prop_key := str(prop.get_meta("runtime_instance_key", "")).strip_edges()
		if prop_key.is_empty():
			var datos_prop := prop.obtener_datos()
			prop_key = str(datos_prop.get("id", "prop")).strip_edges()
		var prop_state_key := _runtime_key(chunk_coord, prop_key)
		var datos_prop := prop.obtener_datos()
		_runtime_prop_state_by_key[prop_state_key] = {
			"position": prop.global_position,
			"runtime_instance_key": prop_key,
			"is_present": true,
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
		# _runtime_key añade las coordenadas una sola vez al construir la clave.
		# Guardar aquí una clave ya expandida duplicaría el prefijo del chunk y
		# haría imposible recuperar el estado usando el ID natural de la criatura.
		instance_key = criatura_id
	var key := _runtime_key(chunk_coord, instance_key)
	var categoria_entidad := str(criatura.datos.get("categoria_entidad", "criatura")).strip_edges().to_lower()
	var datos_criatura := {
		"criatura_id": criatura_id,
		"categoria_entidad": categoria_entidad,
		"asset_key": str(criatura.datos.get("asset_key", "")),
		"habitat_clave": criatura.entorno,
		"nombre": criatura.criatura_nombre,
		"garumi_debug_preview": bool(criatura.datos.get("garumi_debug_preview", false)),
		"position": criatura.global_position,
		"velocity": criatura.velocity,
		"estado": criatura.get_meta("estado_mundo", "")
	}
	if criatura is Garumi:
		# Garumis son entidades de exploración: su estado de mundo no contiene
		# vitalidad, nivel ni experiencia del sistema de criaturas combatientes.
		var garumi := criatura as Garumi
		datos_criatura["garumi_datos"] = garumi.datos.duplicate(true)
		datos_criatura["eterium_actual"] = garumi.eterium_actual
	else:
		datos_criatura["health"] = criatura.health
		datos_criatura["max_health"] = criatura.max_health
		datos_criatura["is_alive"] = criatura.is_alive
	var ai := criatura.get_node_or_null("AIController") as CreatureAI
	if ai != null:
		var necesidades_runtime := ai._obtener_estado_necesidades()
		if not necesidades_runtime.is_empty():
			datos_criatura["necesidades_runtime"] = necesidades_runtime
	_runtime_state_by_key[key] = datos_criatura
	# FULL y DATA pueden materializar el mismo spawn con claves técnicas
	# diferentes. La especie es única por chunk en los spawns naturales.
	# No se crea alias para personajes de reinos, que sí pueden repetirse.
	if not instance_key.begins_with("personaje:") and instance_key != criatura_id:
		# La instancia natural más reciente de esa especie en el chunk actualiza
		# el alias usado por el materializador DATA.
		var key_por_especie := _runtime_key(chunk_coord, criatura_id)
		_runtime_state_by_key[key_por_especie] = datos_criatura.duplicate(true)
	var registro_criatura := datos_criatura.duplicate(true)
	registro_criatura["runtime_instance_key"] = instance_key
	guardar_dato_chunk(chunk_coord, "criaturas", registro_criatura)


func obtener_estado_criatura(chunk_coord: Vector2i, criatura_id: String, instance_key: String = "") -> Dictionary:
	var clave_instancia := instance_key.strip_edges()
	if clave_instancia.is_empty():
		clave_instancia = criatura_id
	var key := _runtime_key(chunk_coord, clave_instancia)
	var estado: Variant = _runtime_state_by_key.get(key, {})
	if estado is Dictionary and not (estado as Dictionary).is_empty():
		return (estado as Dictionary).duplicate(true)
	# Compatibilidad entre la clave natural usada por FULL y la clave de slot
	# usada por DATA. Los personajes quedan aislados bajo su ID de instancia.
	if not clave_instancia.begins_with("personaje:"):
		var key_por_especie := _runtime_key(chunk_coord, criatura_id)
		estado = _runtime_state_by_key.get(key_por_especie, {})
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
	_despawn_chunk_entities(chunk_coord, true, false)


func despawn_props_chunk(chunk_coord: Vector2i) -> void:
	_despawn_chunk_entities(chunk_coord, false, true)


func despawn_chunk(chunk_coord: Vector2i) -> void:
	# Una sola pasada sobre el bucket evita recorrerlo dos veces y, sobre todo,
	# evita que tree_exiting modifique el Array que estamos iterando cuando la
	# fábrica retira nodos para reciclarlos.
	_despawn_chunk_entities(chunk_coord, true, true)


func iniciar_despawn_chunk(chunk_coord: Vector2i) -> bool:
	if _despawn_jobs.has(chunk_coord):
		return true
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	var entidades: Array = (bucket_variant as Array).duplicate() if bucket_variant is Array else []
	_despawn_jobs[chunk_coord] = {
		"entities": entidades,
		"snapshot_ids": _crear_set_instancias(entidades),
		"cursor": 0,
		"remaining": [],
		"creatures": true,
		"props": true
	}
	return true


func procesar_despawn_chunk(chunk_coord: Vector2i, max_entities: int = 8) -> bool:
	if not _despawn_jobs.has(chunk_coord):
		return true
	var job: Dictionary = _despawn_jobs[chunk_coord]
	var entidades: Array = job.get("entities", [])
	var restantes: Array = job.get("remaining", [])
	var cursor := int(job.get("cursor", 0))
	var limite := mini(cursor + maxi(max_entities, 1), entidades.size())
	var creature_elapsed_usec: int = 0
	var prop_elapsed_usec: int = 0
	var creature_count: int = 0
	var prop_count: int = 0

	while cursor < limite:
		var entity_variant: Variant = entidades[cursor]
		cursor += 1
		if not entity_variant is Node:
			continue
		var entity := entity_variant as Node
		if not is_instance_valid(entity):
			continue

		var es_criatura := entity is Creature
		var es_prop := entity is WorldProp
		if not es_criatura and not es_prop:
			restantes.append(entity)
			continue

		if es_prop and entity.is_queued_for_deletion():
			_guardar_tombstone_prop_recolectado(entity as WorldProp, chunk_coord)
			prop_count += 1
			continue

		var entity_despawn_start_usec := Time.get_ticks_usec()
		guardar_estado_entidad(entity, chunk_coord)
		_remover_persistencia(entity)
		if es_criatura:
			creature_count += 1
		elif es_prop:
			prop_count += 1
		if es_criatura and _entity_factory != null and is_instance_valid(_entity_factory):
			_entity_factory.reciclar_criatura(entity as Creature)
		elif es_prop and _entity_factory != null and is_instance_valid(_entity_factory):
			_entity_factory.reciclar_prop(entity as WorldProp)
		else:
			if es_prop:
				entity.set_meta("world_manager_unloading", true)
			entity.queue_free()
		var entity_elapsed_usec := Time.get_ticks_usec() - entity_despawn_start_usec
		if es_criatura:
			creature_elapsed_usec += entity_elapsed_usec
		elif es_prop:
			prop_elapsed_usec += entity_elapsed_usec

	job["cursor"] = cursor
	job["remaining"] = restantes
	_despawn_jobs[chunk_coord] = job

	if creature_count > 0:
		var creature_ms := float(creature_elapsed_usec) / 1000.0
		_diag_despawn_creature_count += creature_count
		_diag_despawn_creature_last_ms = creature_ms
		_diag_despawn_creature_max_ms = maxf(_diag_despawn_creature_max_ms, creature_ms)
	if prop_count > 0:
		var prop_ms := float(prop_elapsed_usec) / 1000.0
		_diag_despawn_prop_count += prop_count
		_diag_despawn_prop_last_ms = prop_ms
		_diag_despawn_prop_max_ms = maxf(_diag_despawn_prop_max_ms, prop_ms)

	if cursor < entidades.size():
		return false

	# Conservar entidades registradas durante el trabajo que no pertenecían
	# al snapshot inicial. Los spawns del chunk ya fueron cancelados antes
	# de iniciar este proceso, pero esta comprobación evita perder registros
	# ajenos ante callbacks o altas externas.
	var snapshot_ids: Dictionary = job.get("snapshot_ids", {})
	var bucket_actual_variant: Variant = _by_chunk.get(chunk_coord, [])
	if bucket_actual_variant is Array:
		for nuevo_variant in bucket_actual_variant as Array:
			if not nuevo_variant is Node:
				continue
			var entidad_nueva := nuevo_variant as Node
			if is_instance_valid(entidad_nueva) and not snapshot_ids.has(entidad_nueva.get_instance_id()) and not entidad_nueva in restantes:
				restantes.append(entidad_nueva)

	if restantes.is_empty():
		_by_chunk.erase(chunk_coord)
	else:
		_by_chunk[chunk_coord] = restantes
	_invalidar_cache_entidades_activas()
	_active_creature_chunks.erase(chunk_coord)
	_active_prop_chunks.erase(chunk_coord)
	_active_chunks.erase(chunk_coord)
	_despawn_jobs.erase(chunk_coord)
	return true


func _crear_set_instancias(entidades: Array) -> Dictionary:
	var resultado: Dictionary = {}
	for entity_variant in entidades:
		if entity_variant is Node and is_instance_valid(entity_variant):
			resultado[(entity_variant as Node).get_instance_id()] = true
	return resultado


func _despawn_chunk_entities(
	chunk_coord: Vector2i,
	retirar_criaturas: bool,
	retirar_props: bool
) -> void:
	# Un ajuste LOD selectivo no puede cancelar un unload completo que ya está
	# avanzando. Una limpieza administrativa completa sí termina ese trabajo.
	if _despawn_jobs.has(chunk_coord):
		if retirar_criaturas and retirar_props:
			while not procesar_despawn_chunk(chunk_coord, 64):
				pass
		return
	# API síncrona de compatibilidad para limpiezas globales y herramientas.
	# El streaming usa iniciar/procesar_despawn_chunk para repartir el trabajo.
	var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
	var entidades: Array = (bucket_variant as Array).duplicate() if bucket_variant is Array else []
	var restantes: Array = []
	for entity_variant in entidades:
		if not entity_variant is Node:
			continue
		var entity := entity_variant as Node
		if not is_instance_valid(entity):
			continue
		var retirar := (entity is Creature and retirar_criaturas) or (entity is WorldProp and retirar_props)
		if not retirar:
			restantes.append(entity)
			continue
		if entity is WorldProp and entity.is_queued_for_deletion():
			_guardar_tombstone_prop_recolectado(entity as WorldProp, chunk_coord)
			continue
		guardar_estado_entidad(entity, chunk_coord)
		_remover_persistencia(entity)
		if entity is Creature and _entity_factory != null and is_instance_valid(_entity_factory):
			_entity_factory.reciclar_criatura(entity as Creature)
		elif entity is WorldProp and _entity_factory != null and is_instance_valid(_entity_factory):
			_entity_factory.reciclar_prop(entity as WorldProp)
		else:
			if entity is WorldProp:
				entity.set_meta("world_manager_unloading", true)
			entity.queue_free()
	if restantes.is_empty():
		_by_chunk.erase(chunk_coord)
	else:
		_by_chunk[chunk_coord] = restantes
	_invalidar_cache_entidades_activas()
	if retirar_criaturas:
		_active_creature_chunks.erase(chunk_coord)
	if retirar_props:
		_active_prop_chunks.erase(chunk_coord)
	_recalcular_chunk_activo(chunk_coord)
	if retirar_criaturas and retirar_props:
		_active_chunks.erase(chunk_coord)


func obtener_diagnostico_despawn() -> Dictionary:
	return {
		"creatures": {
			"entities": _diag_despawn_creature_count,
			"last_ms": _diag_despawn_creature_last_ms,
			"max_ms": _diag_despawn_creature_max_ms
		},
		"props": {
			"entities": _diag_despawn_prop_count,
			"last_ms": _diag_despawn_prop_last_ms,
			"max_ms": _diag_despawn_prop_max_ms
		}
	}

## Retira las entidades generadas por chunks cuando una zona procedural se descarga.
## Las entidades globales/persistentes (por ejemplo, personajes registrados por ID)
## quedan fuera de esta limpieza y conservan su ciclo de vida. Aquí se usa queue_free
## en vez de reciclar: la fábrica y sus pools también se destruyen al salir de la zona.
func despawn_entidades_de_chunks() -> void:
	var chunks: Array = _by_chunk.keys()
	for chunk_variant in chunks:
		if not chunk_variant is Vector2i:
			continue
		var chunk_coord: Vector2i = chunk_variant
		var bucket_variant: Variant = _by_chunk.get(chunk_coord, [])
		if bucket_variant is Array:
			for entity_variant in bucket_variant as Array:
				if not entity_variant is Node or not is_instance_valid(entity_variant):
					continue
				var entity := entity_variant as Node
				if entity is WorldProp and entity.is_queued_for_deletion():
					_guardar_tombstone_prop_recolectado(entity as WorldProp, chunk_coord)
				else:
					guardar_estado_entidad(entity, chunk_coord)
				entity.set_meta("world_manager_unloading", true)
				_remover_persistencia(entity)
				entity.queue_free()
		_by_chunk.erase(chunk_coord)
	_invalidar_cache_entidades_activas()
	_chunk_by_entity.clear()
	_active_chunks.clear()
	_active_creature_chunks.clear()
	_active_prop_chunks.clear()
	_despawn_jobs.clear()



func limpiar_todo() -> void:
	_invalidar_cache_entidades_activas()
	var chunks := _by_chunk.keys()
	for chunk_variant in chunks:
		if chunk_variant is Vector2i:
			despawn_chunk(chunk_variant)
	for entity_variant in _global_entities:
		if entity_variant is Node and is_instance_valid(entity_variant):
			(entity_variant as Node).queue_free()
	_persistent_by_key.clear()
	_persistent_keys_by_entity.clear()
	_global_entities.clear()
	_chunk_by_entity.clear()
	_active_chunks.clear()
	_active_creature_chunks.clear()
	_active_prop_chunks.clear()
	_replicas_red_by_key.clear()
	_replicas_red_props_by_key.clear()
	_replica_keys_by_entity.clear()
	_replica_prop_keys_by_entity.clear()
	_runtime_state_by_key.clear()
	_runtime_prop_state_by_key.clear()
	_data_by_chunk.clear()
	_despawn_jobs.clear()


func _registrar_clave_persistente(entity: Node, persistent_key: String) -> void:
	if persistent_key.is_empty():
		return
	var anterior_variant: Variant = _persistent_by_key.get(persistent_key, null)
	if anterior_variant is Node and anterior_variant != entity:
		var claves_anteriores_variant: Variant = _persistent_keys_by_entity.get(anterior_variant, [])
		if claves_anteriores_variant is Array:
			(claves_anteriores_variant as Array).erase(persistent_key)
			if (claves_anteriores_variant as Array).is_empty():
				_persistent_keys_by_entity.erase(anterior_variant)
	_persistent_by_key[persistent_key] = entity
	var claves_variant: Variant = _persistent_keys_by_entity.get(entity, null)
	var claves: Array = claves_variant if claves_variant is Array else []
	if persistent_key not in claves:
		claves.append(persistent_key)
	_persistent_keys_by_entity[entity] = claves


func _remover_persistencia(entity: Node) -> void:
	var claves_variant: Variant = _persistent_keys_by_entity.get(entity, [])
	if not claves_variant is Array:
		return
	for clave_variant in claves_variant as Array:
		var clave := str(clave_variant)
		if _persistent_by_key.get(clave, null) == entity:
			_persistent_by_key.erase(clave)
	_persistent_keys_by_entity.erase(entity)
