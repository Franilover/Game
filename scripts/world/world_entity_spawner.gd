extends Node
class_name WorldEntitySpawner


@export_category("Aparición de criaturas")
@export var max_creatures_per_chunk: int = 5

@export_category("Aparición de Garumis")
@export_range(0, 4, 1) var max_garumis_per_chunk: int = 1
@export_range(0.0, 1.0, 0.01) var garumi_spawn_probability_per_chunk: float = 0.15
@export var mostrar_prototipo_garumi_en_debug_sin_catalogo: bool = false
@export_range(0.0, 1.0, 0.05) var probabilidad_prototipo_garumi_debug: float = 0.35
## Fase inicial: únicamente Garumis normales de la primera generación de Orumi.
## ID de public.garumi_originales confirmado por consulta de sólo lectura.
@export var garumi_original_id_habilitado: String = "24f86486-aced-4a23-bd1b-f025561a8aa3"
@export_range(1, 100, 1) var garumi_generacion_habilitada: int = 1

var _terrain: WorldTerrain
var _entity_manager: WorldEntityManager = null
var _entity_factory: WorldEntityFactory = null
var _spawn_rules: WorldSpawnRules = null
var _world_data: WorldDataService = null
var _spawn_queue: Array[Vector2i] = []
var _spawn_queued: Dictionary = {}
var _prop_spawn_queue: Array[Vector2i] = []
var _prop_spawn_queued: Dictionary = {}
var _prop_spawn_tasks: Dictionary = {}
var _render_manager: Node = null

var _props_por_bioma: Dictionary = {}
var _asset_path_por_prop: Dictionary = {}
var _data_context_por_chunk: Dictionary = {}
const MAX_DATA_CONTEXT_CHUNKS: int = 64

# Diagnóstico universal del pipeline de entidades. No decide el spawn;
# sólo deja visible en F4 dónde se está descartando el trabajo.
var _diag_chunks_iniciados: int = 0
var _diag_prop_intentos: int = 0
var _diag_prop_creados: int = 0
var _diag_prop_sin_datos: int = 0
var _diag_prop_sin_contexto: int = 0
var _diag_prop_sin_candidato: int = 0
var _diag_prop_factory: int = 0
var _diag_prop_registro: int = 0


func configurar(
	terrain: WorldTerrain,
	entity_manager: WorldEntityManager = null,
	entity_factory: WorldEntityFactory = null,
	spawn_rules: WorldSpawnRules = null,
	world_data: WorldDataService = null
) -> void:
	_terrain = terrain
	_entity_manager = entity_manager
	_entity_factory = entity_factory
	_spawn_rules = spawn_rules
	_world_data = world_data
	_props_por_bioma.clear()
	_asset_path_por_prop.clear()
	_data_context_por_chunk.clear()
	if _world_data != null:
		var props_catalogo := _world_data.obtener_props_game()
		for prop_variant in props_catalogo:
			if not prop_variant is Dictionary:
				continue
			var prop := prop_variant as Dictionary
			var bioma_id := str(prop.get("bioma_id", "")).strip_edges()
			var prop_id := str(prop.get("id", prop.get("clave", prop.get("nombre", "")))).strip_edges()
			if bioma_id.is_empty() or prop_id.is_empty():
				continue
			if not _props_por_bioma.has(bioma_id):
				_props_por_bioma[bioma_id] = []
			(_props_por_bioma[bioma_id] as Array).append(prop)
			_asset_path_por_prop[prop_id] = ""

	if _entity_manager == null:
		push_error("WorldEntitySpawner: Entity manager inválido.")
	if _entity_factory == null:
		push_error("WorldEntitySpawner: Entity factory inválido.")
	if _spawn_rules == null:
		push_error("WorldEntitySpawner: Spawn rules inválidas.")
	if _world_data == null:
		push_error("WorldEntitySpawner: WorldDataService inválido.")


func configurar_render_manager(render_manager: Node) -> void:
	_render_manager = render_manager

func obtener_entity_manager() -> WorldEntityManager:
	return _entity_manager



func obtener_diagnostico() -> Dictionary:
	return {
		"cola_chunks": _spawn_queue.size(),
		"tareas_props": _prop_spawn_tasks.size(),
		"cola_props_chunks": _prop_spawn_queue.size(),
		"chunks_iniciados": _diag_chunks_iniciados,
		"prop_intentos": _diag_prop_intentos,
		"prop_creados": _diag_prop_creados,
		"prop_sin_datos": _diag_prop_sin_datos,
		"prop_sin_contexto": _diag_prop_sin_contexto,
		"prop_sin_candidato": _diag_prop_sin_candidato,
		"prop_factory_fallo": _diag_prop_factory,
		"prop_registro_fallo": _diag_prop_registro
	}


func _ready() -> void:
	var debug: Node = get_node_or_null("/root/GarliaDebug")
	if debug != null and debug.has_method("registrar_proveedor"):
		debug.registrar_proveedor(
			"world_entity_spawner",
			"WorldEntitySpawner",
			self,
			"Spawn de props y criaturas por chunk."
		)


func materializar_criaturas_datos_chunk(chunk_coord: Vector2i) -> bool:
	if _entity_manager == null or _entity_factory == null or _world_data == null:
		return false
	if _entity_manager.tiene_criaturas_chunk(chunk_coord):
		return true
	var datos := _entity_manager.obtener_datos_chunk(chunk_coord, "criaturas")
	if datos.is_empty():
		return false

	var limite_chunk := Rect2(
		float(chunk_coord.x * _terrain.chunk_size_tiles * _terrain.tile_size),
		float(chunk_coord.y * _terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size)
	)

	for dato_variant in datos:
		if not dato_variant is Dictionary:
			continue
		var dato := (dato_variant as Dictionary).duplicate(true)
		var criatura_id := str(dato.get("criatura_id", "")).strip_edges()
		if criatura_id.is_empty():
			continue
		var instance_key := str(dato.get("runtime_instance_key", criatura_id)).strip_edges()
		if _entity_manager.has_method("obtener_estado_criatura"):
			var estado_runtime := _entity_manager.obtener_estado_criatura(chunk_coord, criatura_id, instance_key)
			if not estado_runtime.is_empty():
				for clave in estado_runtime.keys():
					dato[clave] = estado_runtime[clave]
		var categoria_entidad := str(dato.get("categoria_entidad", "criatura")).strip_edges().to_lower()
		var criatura_data: Dictionary
		if categoria_entidad == "garumi":
			if bool(dato.get("garumi_debug_preview", false)):
				criatura_data = dato.duplicate(true)
			else:
				criatura_data = _world_data.obtener_garumi_game(criatura_id).duplicate(true)
		else:
			criatura_data = _world_data.obtener_criatura(criatura_id).duplicate(true)
		if criatura_data.is_empty():
			continue
		if categoria_entidad == "garumi":
			criatura_data["categoria_entidad"] = "garumi"
			criatura_data["asset_key"] = str(criatura_data.get("asset_key", criatura_data.get("nombre", "")))
		var criatura_variant: Variant = _entity_factory.crear_criatura(criatura_data)
		if not criatura_variant is Creature:
			continue
		var criatura := criatura_variant as Creature
		instance_key = str(dato.get("runtime_instance_key", criatura_id))
		criatura.set_meta("runtime_instance_key", instance_key)
		if bool(dato.get("garumi_debug_preview", false)):
			criatura.set_meta("garumi_debug_preview", true)
		if not _entity_manager.registrar(criatura, chunk_coord):
			criatura.queue_free()
			continue
		criatura.global_position = dato.get("position", criatura.global_position)
		if criatura is Creature:
			var creature_node := criatura as Creature
			creature_node.configurar_chunk(chunk_coord, limite_chunk)
			creature_node.configurar_entorno(str(dato.get("habitat_clave", "general")).strip_edges().to_lower())
			if bool(dato.get("garumi_debug_preview", false)):
				print("WorldEntitySpawner: Garumi prototipo DEBUG materializado desde DATA -> chunk=", chunk_coord, " | sprite=", "cargado" if not bool(criatura.get_meta("garumi_sprite_missing", false)) else "pendiente")
			var health := float(dato.get("health", creature_node.health))
			creature_node.health = clampf(health, 0.0, creature_node.max_health)
			if dato.has("velocity") and dato["velocity"] is Vector2:
				creature_node.velocity = dato["velocity"]

	_entity_manager.activar_criaturas_chunk(chunk_coord)
	return true


func spawn_chunk(chunk_coord: Vector2i) -> void:
	if _entity_manager == null:
		return
	if _entity_manager.tiene_criaturas_chunk(chunk_coord):
		return
	if _spawn_queued.has(chunk_coord):
		return
	_spawn_queue.append(chunk_coord)
	_spawn_queued[chunk_coord] = true


func preparar_datos_criaturas_chunk(chunk_coord: Vector2i) -> void:
	if _entity_manager == null or _terrain == null or _world_data == null or _spawn_rules == null:
		return
	if _entity_manager.tiene_datos_chunk(chunk_coord, "criaturas"):
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = abs(_terrain.map_seed + chunk_coord.x * 92837111 + chunk_coord.y * 689287499) + 1
	var datos: Array = []
	var especies: Dictionary = {}
	for slot in range(max_creatures_per_chunk):
		var creado := false
		for intento in range(32):
			var tile := Vector2i(
				chunk_coord.x * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1),
				chunk_coord.y * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1)
			)
			var contexto := _obtener_contexto_data_cacheado(chunk_coord, tile)
			if not bool(contexto.get("walkable", false)):
				continue
			var ecosistema_variant: Variant = contexto.get("ecosistema", {})
			if not ecosistema_variant is Dictionary:
				continue
			var ecosistema := ecosistema_variant as Dictionary
			if ecosistema.is_empty():
				continue
			var candidatos := _spawn_rules.obtener_candidatos(ecosistema)
			if candidatos.is_empty():
				continue
			var validos: Array[Dictionary] = []
			for candidato_variant in candidatos:
				if not candidato_variant is Dictionary:
					continue
				var candidato := candidato_variant as Dictionary
				var criatura_variant: Variant = candidato.get("criatura", {})
				if not criatura_variant is Dictionary:
					continue
				var criatura := criatura_variant as Dictionary
				var criatura_id := str(criatura.get("id", criatura.get("criatura_id", ""))).strip_edges()
				var habitat_clave := str(candidato.get("habitat_clave", "general")).to_lower()
				if criatura_id.is_empty() or especies.has(criatura_id):
					continue
				if not _spawn_rules.ubicacion_valida(
					contexto.get("bioma", {}),
					habitat_clave,
					int(contexto.get("zona", -1))
				):
					continue
				validos.append(candidato)
			if validos.is_empty():
				continue
			var candidato_elegido := validos[rng.randi_range(0, validos.size() - 1)] as Dictionary
			var criatura_elegida: Variant = candidato_elegido.get("criatura", {})
			if not criatura_elegida is Dictionary:
				continue
			var elegido := (criatura_elegida as Dictionary).duplicate(true)
			elegido["habitat_clave"] = str(candidato_elegido.get("habitat_clave", "general")).to_lower()
			var criatura_id := str(elegido.get("id", elegido.get("criatura_id", ""))).strip_edges()
			if criatura_id.is_empty():
				continue
			especies[criatura_id] = true
			var registro := elegido.duplicate(true)
			registro["criatura_id"] = criatura_id
			registro["runtime_instance_key"] = "criatura:" + str(slot) + ":" + criatura_id
			registro["chunk"] = chunk_coord
			registro["position"] = Vector2((float(tile.x) + 0.5) * _terrain.tile_size, (float(tile.y) + 0.5) * _terrain.tile_size)
			datos.append(registro)
			creado = true
			break
		if not creado:
			continue
	# DATA LOD prepara también Garumis; de lo contrario, al entrar a FULL,
	# el materializador devolvería los datos de criaturas normales y nunca
	# ejecutaría el spawner de fallback.
	for garumi_dato in _preparar_datos_garumis_en_chunk(chunk_coord, rng):
		datos.append(garumi_dato)

	_entity_manager.reemplazar_datos_chunk(chunk_coord, "criaturas", datos)


func _preparar_datos_garumis_en_chunk(
	chunk_coord: Vector2i,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if _terrain == null or _world_data == null or _spawn_rules == null:
		return resultado
	if max_garumis_per_chunk <= 0:
		return resultado

	var catalogo := _world_data.obtener_garumis_game()
	if catalogo.is_empty():
		return _preparar_datos_garumi_debug(chunk_coord, rng)

	var candidatos_probables: Array[Dictionary] = []
	for garumi in catalogo:
		var garumi_id := str(garumi.get("id", "")).strip_edges()
		var garumi_nombre := str(garumi.get("nombre", "")).strip_edges()
		if garumi_id.is_empty() or garumi_nombre.is_empty():
			continue
		if not _spawn_rules.garumi_cumple_filtro_generacional(
			garumi,
			garumi_original_id_habilitado,
			garumi_generacion_habilitada
		):
			continue
		var probabilidad := _spawn_rules.obtener_probabilidad_spawn_garumi(
			garumi,
			garumi_spawn_probability_per_chunk
		)
		if probabilidad <= 0.0 or rng.randf() > probabilidad:
			continue
		candidatos_probables.append(garumi)

	if candidatos_probables.is_empty():
		return resultado

	var elegidos: Dictionary = {}
	for slot in range(max_garumis_per_chunk):
		for intento in range(32):
			var tile := Vector2i(
				chunk_coord.x * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1),
				chunk_coord.y * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1)
			)
			var contexto := _obtener_contexto_data_cacheado(chunk_coord, tile)
			if not bool(contexto.get("walkable", false)):
				continue
			var bioma_variant: Variant = contexto.get("bioma", {})
			var ecosistema_variant: Variant = contexto.get("ecosistema", {})
			var habitats_variant: Variant = contexto.get("habitats", [])
			if not bioma_variant is Dictionary or not ecosistema_variant is Dictionary or not habitats_variant is Array:
				continue
			var bioma := bioma_variant as Dictionary
			var ecosistema := ecosistema_variant as Dictionary
			var habitats := habitats_variant as Array
			if bioma.is_empty() or ecosistema.is_empty():
				continue

			var validos: Array[Dictionary] = []
			for garumi in candidatos_probables:
				var garumi_id := str(garumi.get("id", "")).strip_edges()
				if garumi_id.is_empty() or elegidos.has(garumi_id):
					continue
				if not _spawn_rules.garumi_puede_aparecer(garumi, bioma, ecosistema, habitats):
					continue
				validos.append(garumi)
			if validos.is_empty():
				continue

			var elegido := _spawn_rules.elegir_garumi(validos, rng)
			if elegido.is_empty():
				continue
			var garumi_id := str(elegido.get("id", "")).strip_edges()
			if garumi_id.is_empty():
				continue
			var registro := elegido.duplicate(true)
			registro["criatura_id"] = garumi_id
			registro["categoria_entidad"] = "garumi"
			registro["asset_key"] = str(registro.get("asset_key", registro.get("nombre", "")))
			var aparicion_variant: Variant = registro.get("aparicion", {})
			var aparicion: Dictionary = aparicion_variant if aparicion_variant is Dictionary else {}
			registro["habitat_clave"] = str(aparicion.get("habitat_clave", "general")).strip_edges().to_lower()
			registro["runtime_instance_key"] = "garumi:" + str(slot) + ":" + garumi_id
			registro["chunk"] = chunk_coord
			registro["position"] = Vector2(
				(float(tile.x) + 0.5) * _terrain.tile_size,
				(float(tile.y) + 0.5) * _terrain.tile_size
			)
			resultado.append(registro)
			elegidos[garumi_id] = true
			break
	return resultado


func _preparar_datos_garumi_debug(
	chunk_coord: Vector2i,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if not mostrar_prototipo_garumi_en_debug_sin_catalogo or not OS.is_debug_build():
		return resultado
	if max_garumis_per_chunk <= 0:
		return resultado
	if rng.randf() > clampf(probabilidad_prototipo_garumi_debug, 0.0, 1.0):
		return resultado
	for _intento in range(32):
		var tile := Vector2i(
			chunk_coord.x * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1),
			chunk_coord.y * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1)
		)
		var contexto := _obtener_contexto_data_cacheado(chunk_coord, tile)
		if not bool(contexto.get("walkable", false)):
			continue
		var id_instancia := "garumi:debug:%d:%d" % [chunk_coord.x, chunk_coord.y]
		resultado.append({
			"id": "__garumi_debug_preview__",
			"criatura_id": "__garumi_debug_preview__",
			"nombre": "Garumi prototipo (DEBUG)",
			"asset_key": "Garumi_Prototipo",
			"categoria_entidad": "garumi",
			"garumi_debug_preview": true,
			"habitat_clave": "general",
			"aparicion": {"habitat_clave": "general"},
			"runtime_instance_key": id_instancia,
			"chunk": chunk_coord,
			"position": Vector2(
				(float(tile.x) + 0.5) * _terrain.tile_size,
				(float(tile.y) + 0.5) * _terrain.tile_size
			)
		})
		return resultado
	return resultado

func preparar_datos_props_chunk(chunk_coord: Vector2i) -> void:
	if _entity_manager == null or _terrain == null or _world_data == null or _spawn_rules == null:
		return
	if _entity_manager.tiene_datos_chunk(chunk_coord, "props"):
		return

	var datos: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(_terrain.map_seed + chunk_coord.x * 92837111 + chunk_coord.y * 689287499) + 1

	for slot in range(6):
		var encontrado := false
		for intento in range(48):
			var tile := Vector2i(
				chunk_coord.x * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1),
				chunk_coord.y * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1)
			)
			var contexto: Dictionary = _terrain.obtener_contexto_data_at(tile)
			if not bool(contexto.get("walkable", false)):
				continue
			var bioma_variant: Variant = contexto.get("bioma", {})
			var ecosistema_variant: Variant = contexto.get("ecosistema", {})
			var habitats_variant: Variant = contexto.get("habitats", [])
			if not bioma_variant is Dictionary or not ecosistema_variant is Dictionary or not habitats_variant is Array:
				continue
			var bioma := bioma_variant as Dictionary
			var ecosistema := ecosistema_variant as Dictionary
			var habitats := habitats_variant as Array
			if bioma.is_empty() or ecosistema.is_empty() or habitats.is_empty():
				continue
			var bioma_id := str(bioma.get("id", ""))
			var ecosistema_id := str(ecosistema.get("id", ""))
			var habitat_ids: Array[String] = []
			for habitat_variant in habitats:
				if habitat_variant is Dictionary:
					var habitat_id := str((habitat_variant as Dictionary).get("id", ""))
					if not habitat_id.is_empty() and habitat_id not in habitat_ids:
						habitat_ids.append(habitat_id)
			if bioma_id.is_empty() or ecosistema_id.is_empty() or habitat_ids.is_empty():
				continue

			var candidatos: Array[Dictionary] = []
			var candidatos_bioma: Array = _props_por_bioma.get(bioma_id, [])
			for prop_variant in candidatos_bioma:
				if not prop_variant is Dictionary:
					continue
				var prop := prop_variant as Dictionary
				var nombre := str(prop.get("nombre", "")).strip_edges()
				if nombre.is_empty():
					continue
				var coincide := str(prop.get("ecosistema_id", "")) == ecosistema_id and str(prop.get("habitat_id", "")) in habitat_ids
				if coincide:
					candidatos.append(prop)

			if candidatos.is_empty():
				for prop_variant in candidatos_bioma:
					if prop_variant is Dictionary and not str((prop_variant as Dictionary).get("nombre", "")).strip_edges().is_empty():
						candidatos.append(prop_variant as Dictionary)
			if candidatos.is_empty():
				continue
			var elegido_base := _spawn_rules.elegir_prop(candidatos, rng)
			if elegido_base.is_empty():
				continue
			var elegido := elegido_base.duplicate(true)
			var prop_id := str(elegido.get("id", elegido.get("clave", elegido.get("nombre", "")))).strip_edges()
			var asset_path := str(_asset_path_por_prop.get(prop_id, ""))
			if asset_path.is_empty():
				asset_path = _spawn_rules.construir_asset_path_prop(elegido)
				_asset_path_por_prop[prop_id] = asset_path
			if asset_path.is_empty():
				continue
			elegido["asset_path"] = asset_path
			if str(elegido.get("asset_path", "")).is_empty():
				continue
			elegido["runtime_instance_key"] = "prop:" + str(slot) + ":" + str(elegido.get("id", ""))
			elegido["chunk"] = chunk_coord
			elegido["position"] = Vector2((float(tile.x) + 0.5) * _terrain.tile_size, (float(tile.y) + 0.5) * _terrain.tile_size)
			datos.append(elegido)
			encontrado = true
			break
		if not encontrado:
			continue

	_entity_manager.reemplazar_datos_chunk(chunk_coord, "props", datos)


func _obtener_contexto_data_cacheado(
	chunk_coord: Vector2i,
	tile: Vector2i
) -> Dictionary:
	var cache_variant: Variant = _data_context_por_chunk.get(chunk_coord, null)
	var cache: Dictionary
	if cache_variant is Dictionary:
		cache = cache_variant as Dictionary
	else:
		cache = {}
		_data_context_por_chunk[chunk_coord] = cache
		if _data_context_por_chunk.size() > MAX_DATA_CONTEXT_CHUNKS:
			var claves := _data_context_por_chunk.keys()
			if not claves.is_empty():
				_data_context_por_chunk.erase(claves[0])
	if cache.has(tile):
		return cache[tile]
	var contexto := _terrain.obtener_contexto_data_at(tile)
	cache[tile] = contexto
	return contexto


func materializar_props_datos_chunk(chunk_coord: Vector2i) -> bool:
	if _entity_manager == null or _entity_factory == null:
		return false
	if _entity_manager.tiene_props_chunk(chunk_coord):
		return true
	var datos := _entity_manager.obtener_datos_chunk(chunk_coord, "props")
	if datos.is_empty():
		return false
	var limite_chunk := Rect2(
		float(chunk_coord.x * _terrain.chunk_size_tiles * _terrain.tile_size),
		float(chunk_coord.y * _terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size)
	)
	for dato_variant in datos:
		if not dato_variant is Dictionary:
			continue
		var dato := dato_variant as Dictionary
		var prop_variant: Variant = _entity_factory.call("crear_prop", dato)
		if not prop_variant is Node:
			continue
		var prop := prop_variant as Node
		prop.set_meta("runtime_instance_key", str(dato.get("runtime_instance_key", "")))
		if not _entity_manager.registrar(prop, chunk_coord):
			prop.queue_free()
			continue
		var estado := _entity_manager.obtener_estado_prop(
			chunk_coord,
			str(dato.get("runtime_instance_key", ""))
		)
		if not estado.is_empty():
			prop.global_position = estado.get("position", dato.get("position", prop.global_position))
		else:
			prop.global_position = dato.get("position", prop.global_position)
		if prop.has_method("configurar_chunk"):
			prop.call("configurar_chunk", chunk_coord, limite_chunk)
	_entity_manager.activar_props_chunk(chunk_coord)
	return true


func spawn_props_chunk(chunk_coord: Vector2i) -> void:
	if _entity_manager == null:
		return
	if _entity_manager.tiene_props_chunk(chunk_coord):
		return
	if _prop_spawn_queued.has(chunk_coord) or _prop_spawn_tasks.has(chunk_coord):
		return
	_prop_spawn_queue.append(chunk_coord)
	_prop_spawn_queued[chunk_coord] = true


func procesar_spawn_queue(max_chunks: int = 1) -> void:
	var limite := maxi(max_chunks, 1)
	var procesados := 0
	while procesados < limite and not _spawn_queue.is_empty():
		var chunk_coord: Vector2i = _spawn_queue.pop_front()
		_spawn_queued.erase(chunk_coord)
		if _entity_manager != null and _entity_manager.tiene_criaturas_chunk(chunk_coord):
			continue
		_iniciar_tarea_spawn(chunk_coord)
		procesados += 1


func procesar_prop_spawn_queue(max_chunks: int = 1) -> void:
	var limite := maxi(max_chunks, 1)
	var procesados := 0
	for chunk_variant in _prop_spawn_tasks.keys():
		if procesados >= limite:
			break
		if chunk_variant is Vector2i:
			_procesar_tarea_prop_spawn(chunk_variant as Vector2i)
			procesados += 1
	while procesados < limite and not _prop_spawn_queue.is_empty():
		var chunk_coord: Vector2i = _prop_spawn_queue.pop_front()
		_prop_spawn_queued.erase(chunk_coord)
		if _entity_manager != null and _entity_manager.tiene_props_chunk(chunk_coord):
			continue
		_iniciar_tarea_prop_spawn(chunk_coord)
		procesados += 1


func cancelar_spawn_chunk(chunk_coord: Vector2i) -> void:
	_spawn_queued.erase(chunk_coord)
	_spawn_queue.erase(chunk_coord)


func cancelar_prop_spawn_chunk(chunk_coord: Vector2i) -> void:
	_prop_spawn_queued.erase(chunk_coord)
	_prop_spawn_queue.erase(chunk_coord)
	_prop_spawn_tasks.erase(chunk_coord)


func _spawn_chunk_interno(
	chunk_coord: Vector2i
) -> void:
	_diag_chunks_iniciados += 1
	if _terrain == null or not is_instance_valid(_terrain):
		push_error("WorldEntitySpawner: Terrain no configurado.")
		return
	if _entity_manager == null or _entity_factory == null or _spawn_rules == null or _world_data == null:
		return
	if _entity_manager.tiene_criaturas_chunk(chunk_coord):
		return

	var rng := RandomNumberGenerator.new()

	rng.seed = abs(
		_terrain.map_seed
		+ chunk_coord.x * 92837111
		+ chunk_coord.y * 689287499
	) + 1

	var creadas: Array = []

	var origin_x: int = (
		chunk_coord.x
		* _terrain.chunk_size_tiles
	)

	var origin_y: int = (
		chunk_coord.y
		* _terrain.chunk_size_tiles
	)

	var limite_chunk := Rect2(
		float(
			origin_x
			* _terrain.tile_size
		),
		float(
			origin_y
			* _terrain.tile_size
		),
		float(
			_terrain.chunk_size_tiles
			* _terrain.tile_size
		),
		float(
			_terrain.chunk_size_tiles
			* _terrain.tile_size
		)
	)

	var especies_creadas: Dictionary = {}

	for intento in range(32):
		if (
			creadas.size()
			>= max_creatures_per_chunk
		):
			break

		var local_x: int = rng.randi_range(
			0,
			_terrain.chunk_size_tiles - 1
		)

		var local_y: int = rng.randi_range(
			0,
			_terrain.chunk_size_tiles - 1
		)

		var tile := Vector2i(
			origin_x + local_x,
			origin_y + local_y
		)

		var bioma: Dictionary = (
			_terrain.get_bioma_at(tile)
		)

		if bioma.is_empty():
			continue

		var ecosistema: Dictionary = (
			_terrain.get_ecosistema_at(tile)
		)

		if ecosistema.is_empty():
			continue

		var candidatos: Array = (
			_spawn_rules.obtener_candidatos(ecosistema)
		)

		if candidatos.is_empty():
			continue

		var validos: Array = []

		for i in range(candidatos.size()):
			var candidato_variant: Variant = (
				candidatos[i]
			)

			if not candidato_variant is Dictionary:
				continue

			var candidato: Dictionary = (
				candidato_variant
			)

			var criatura_variant: Variant = (
				candidato.get(
					"criatura",
					{}
				)
			)

			if not criatura_variant is Dictionary:
				continue

			var criatura_data: Dictionary = (
				criatura_variant
			)

			var criatura_id: String = str(
				criatura_data.get(
					"id",
					""
				)
			)

			if criatura_id.is_empty():
				continue

			if especies_creadas.has(
				criatura_id
			):
				continue

			var habitat_clave: String = str(
				candidato.get(
					"habitat_clave",
					"general"
				)
			)

			var zona: int = (
				_terrain.get_zona_at(tile)
			)

			if not _spawn_rules.ubicacion_valida(bioma, habitat_clave, zona):
				continue

			validos.append(
				candidato
			)

		if validos.is_empty():
			continue

		var elegido: Dictionary = (
			_spawn_rules.elegir_criatura(validos, rng)
		)

		if elegido.is_empty():
			continue

		var criatura_variant: Variant = (
			elegido.get(
				"criatura",
				{}
			)
		)

		if not criatura_variant is Dictionary:
			continue

		var criatura_data: Dictionary = (
			criatura_variant.duplicate(true)
		)
		criatura_data["ecosistema_id"] = str(
			ecosistema.get("id", "")
		)

		var criatura_id_actual := str(criatura_data.get("id", "")).strip_edges()
		var instancia_key := "natural:" + str(creadas.size()) + ":" + criatura_id_actual
		var estado_previo: Dictionary = _entity_manager.obtener_estado_criatura(
			chunk_coord,
			criatura_id_actual,
			instancia_key
		)
		if not estado_previo.is_empty() and not bool(estado_previo.get("is_alive", true)):
			continue

		var criatura: Node = _entity_factory.crear_criatura(criatura_data)

		if criatura == null:
			continue

		criatura.set_meta("runtime_instance_key", instancia_key)

		if _entity_manager != null:
			if not _entity_manager.registrar(criatura, chunk_coord):
				continue

		criatura.global_position = Vector2(
			(float(tile.x) + 0.5)
			* _terrain.tile_size,
			(float(tile.y) + 0.5)
			* _terrain.tile_size
		)

		if not estado_previo.is_empty():
			criatura.global_position = estado_previo.get("position", criatura.global_position)
			criatura.velocity = estado_previo.get("velocity", Vector2.ZERO)
			if criatura is Entity:
				var entidad := criatura as Entity
				entidad.restaurar_estado_vital(
					int(estado_previo.get("health", entidad.health)),
					bool(estado_previo.get("is_alive", true))
				)
				if estado_previo.has("estado"):
					criatura.set_meta("estado_mundo", estado_previo.get("estado", ""))

		if criatura is Creature:
			var creature_node: Creature = criatura
			creature_node.configurar_chunk(
				chunk_coord,
				limite_chunk
			)

			creature_node.configurar_entorno(
				str(
					elegido.get(
						"habitat_clave",
						"general"
					)
				)
			)

		especies_creadas[
			str(
				criatura_data.get(
					"id",
					""
				)
			)
		] = true

		creadas.append(
			criatura
		)

	_spawn_garumis_en_chunk(chunk_coord, limite_chunk, rng)

	_spawn_characters_in_chunk(
		chunk_coord,
		limite_chunk,
		rng
	)
	_entity_manager.activar_criaturas_chunk(chunk_coord)
	return

func _spawn_garumis_en_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2,
	rng: RandomNumberGenerator
) -> void:
	if _terrain == null or _entity_manager == null or _entity_factory == null or _spawn_rules == null or _world_data == null:
		return
	if max_garumis_per_chunk <= 0:
		return

	var catalogo := _world_data.obtener_garumis_game()
	if catalogo.is_empty():
		var datos_debug := _preparar_datos_garumi_debug(chunk_coord, rng)
		if datos_debug.is_empty():
			return
		var garumi_debug: Dictionary = datos_debug[0]
		var instancia_debug: Variant = _entity_factory.crear_criatura(garumi_debug)
		if not instancia_debug is Creature:
			return
		var node_debug := instancia_debug as Creature
		node_debug.set_meta("runtime_instance_key", str(garumi_debug.get("runtime_instance_key", "")))
		node_debug.set_meta("entidad_categoria", "garumi")
		if not _entity_manager.registrar(node_debug, chunk_coord):
			node_debug.queue_free()
			return
		node_debug.global_position = garumi_debug.get("position", Vector2.ZERO)
		if node_debug is Creature:
			(node_debug as Creature).configurar_chunk(chunk_coord, limite_chunk)
			(node_debug as Creature).configurar_entorno("general")
		print("WorldEntitySpawner: Garumi prototipo DEBUG -> chunk=", chunk_coord, " | sprite=", "cargado" if not bool(node_debug.get_meta("garumi_sprite_missing", false)) else "pendiente")
		return

	# La selección depende de los datos ecológicos del snapshot, no del nombre
	# ni de una lista de especies codificada dentro del motor.
	var candidatos_probables: Array[Dictionary] = []
	for garumi in catalogo:
		var garumi_id := str(garumi.get("id", "")).strip_edges()
		var garumi_nombre := str(garumi.get("nombre", "")).strip_edges()
		if garumi_id.is_empty() or garumi_nombre.is_empty():
			continue
		var probabilidad := _spawn_rules.obtener_probabilidad_spawn_garumi(
			garumi,
			garumi_spawn_probability_per_chunk
		)
		if probabilidad <= 0.0 or rng.randf() > probabilidad:
			continue
		candidatos_probables.append(garumi)

	if candidatos_probables.is_empty():
		return

	var creados_ids: Dictionary = {}
	var creados := 0
	var origen_x := chunk_coord.x * _terrain.chunk_size_tiles
	var origen_y := chunk_coord.y * _terrain.chunk_size_tiles
	for slot in range(max_garumis_per_chunk):
		if creados >= max_garumis_per_chunk:
			break
		var materializado := false
		for intento in range(32):
			var tile := Vector2i(
				origen_x + rng.randi_range(0, _terrain.chunk_size_tiles - 1),
				origen_y + rng.randi_range(0, _terrain.chunk_size_tiles - 1)
			)
			if not _terrain.is_walkable(tile):
				continue
			var bioma := _terrain.get_bioma_at(tile)
			var ecosistema := _terrain.get_ecosistema_at(tile)
			var habitats := _terrain.get_habitats_at(tile)
			if bioma.is_empty() or ecosistema.is_empty():
				continue

			var validos: Array[Dictionary] = []
			for garumi in candidatos_probables:
				var garumi_id := str(garumi.get("id", "")).strip_edges()
				if garumi_id.is_empty() or creados_ids.has(garumi_id):
					continue
				if not _spawn_rules.garumi_puede_aparecer(garumi, bioma, ecosistema, habitats):
					continue
				validos.append(garumi)
			if validos.is_empty():
				continue

			var elegido := _spawn_rules.elegir_garumi(validos, rng)
			if elegido.is_empty():
				continue
			var garumi_id := str(elegido.get("id", "")).strip_edges()
			var instancia_key := "garumi:" + str(slot) + ":" + garumi_id
			var estado_previo := _entity_manager.obtener_estado_criatura(
				chunk_coord,
				garumi_id,
				instancia_key
			)
			if not estado_previo.is_empty() and not bool(estado_previo.get("is_alive", true)):
				creados_ids[garumi_id] = true
				continue

			var garumi_data := elegido.duplicate(true)
			garumi_data["categoria_entidad"] = "garumi"
			garumi_data["asset_key"] = str(garumi_data.get("asset_key", garumi_data.get("nombre", "")))
			var criatura_variant: Variant = _entity_factory.crear_criatura(garumi_data)
			if not criatura_variant is Creature:
				continue
			var criatura := criatura_variant as Creature
			criatura.set_meta("runtime_instance_key", instancia_key)
			criatura.set_meta("entidad_categoria", "garumi")
			if not _entity_manager.registrar(criatura, chunk_coord):
				criatura.queue_free()
				continue

			criatura.global_position = Vector2(
				(float(tile.x) + 0.5) * _terrain.tile_size,
				(float(tile.y) + 0.5) * _terrain.tile_size
			)
			if not estado_previo.is_empty():
				criatura.global_position = estado_previo.get("position", criatura.global_position)
				if criatura is CharacterBody2D and estado_previo.get("velocity", Vector2.ZERO) is Vector2:
					(criatura as CharacterBody2D).velocity = estado_previo.get("velocity", Vector2.ZERO)
				if criatura is Entity:
					(criatura as Entity).restaurar_estado_vital(
						int(estado_previo.get("health", (criatura as Entity).health)),
						bool(estado_previo.get("is_alive", true))
					)
			if criatura is Creature:
				var criatura_node := criatura as Creature
				criatura_node.configurar_chunk(chunk_coord, limite_chunk)
				var aparicion_variant: Variant = elegido.get("aparicion", {})
				var aparicion: Dictionary = aparicion_variant if aparicion_variant is Dictionary else {}
				criatura_node.configurar_entorno(str(aparicion.get("habitat_clave", "general")).to_lower())

			print(
				"WorldEntitySpawner: Garumi materializado → ",
				str(garumi_data.get("nombre", garumi_id)),
				" | chunk=",
				chunk_coord,
				" | sprite=",
				"pendiente" if bool(criatura.get_meta("garumi_sprite_missing", false)) else "cargado"
			)
			creados_ids[garumi_id] = true
			creados += 1
			materializado = true
			break
		if not materializado:
			continue


func _iniciar_tarea_spawn(chunk_coord: Vector2i) -> void:
	if _terrain == null or _entity_manager == null or _entity_factory == null:
		return
	if _entity_manager.tiene_criaturas_chunk(chunk_coord):
		return
	_spawn_chunk_interno(chunk_coord)


func _iniciar_tarea_prop_spawn(chunk_coord: Vector2i) -> void:
	if _terrain == null or _entity_manager == null or _entity_factory == null:
		return
	if _entity_manager.tiene_props_chunk(chunk_coord) or _prop_spawn_tasks.has(chunk_coord):
		return

	var origin_x: int = chunk_coord.x * _terrain.chunk_size_tiles
	var origin_y: int = chunk_coord.y * _terrain.chunk_size_tiles
	var limite_chunk := Rect2(
		float(origin_x * _terrain.tile_size),
		float(origin_y * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size)
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(
		_terrain.map_seed
		+ chunk_coord.x * 92837111
		+ chunk_coord.y * 689287499
	) + 1
	_prop_spawn_tasks[chunk_coord] = {
		"limite_chunk": limite_chunk,
		"rng": rng,
		"intento": 0,
		"creados": 0,
		"max_props": 6,
		"intentos_maximos": 48
	}


func _procesar_tarea_prop_spawn(chunk_coord: Vector2i) -> void:
	var tarea_variant: Variant = _prop_spawn_tasks.get(chunk_coord, {})
	if not tarea_variant is Dictionary:
		_prop_spawn_tasks.erase(chunk_coord)
		return
	var tarea := tarea_variant as Dictionary
	if _entity_manager == null or _entity_manager.tiene_props_chunk(chunk_coord):
		_prop_spawn_tasks.erase(chunk_coord)
		return
	var rng_variant: Variant = tarea.get("rng", null)
	if not rng_variant is RandomNumberGenerator:
		_prop_spawn_tasks.erase(chunk_coord)
		return
	var rng := rng_variant as RandomNumberGenerator
	var intento := int(tarea.get("intento", 0))
	var creados := int(tarea.get("creados", 0))
	var max_props := int(tarea.get("max_props", 6))
	var max_intentos := int(tarea.get("intentos_maximos", 48))
	var limite_chunk: Rect2 = tarea.get("limite_chunk", Rect2())
	if creados >= max_props or intento >= max_intentos:
		_prop_spawn_tasks.erase(chunk_coord)
		_entity_manager.activar_props_chunk(chunk_coord)
		return
	var inicio_usec := Time.get_ticks_usec()
	var creado := _intentar_crear_prop(chunk_coord, limite_chunk, rng, creados)
	if _render_manager != null and is_instance_valid(_render_manager):
		_render_manager.call("registrar_trabajo", "prop_spawn", float(Time.get_ticks_usec() - inicio_usec) / 1000.0, 1)
	if creado:
		creados += 1
	tarea["creados"] = creados
	tarea["intento"] = intento + 1
	if creados >= max_props or int(tarea["intento"]) >= max_intentos:
		_prop_spawn_tasks.erase(chunk_coord)
		_entity_manager.activar_props_chunk(chunk_coord)
	else:
		_prop_spawn_tasks[chunk_coord] = tarea


func _intentar_crear_prop(chunk_coord: Vector2i, limite_chunk: Rect2, rng: RandomNumberGenerator, slot: int) -> bool:
	_diag_prop_intentos += 1
	if _props_por_bioma.is_empty():
		_diag_prop_sin_datos += 1
		return false
	var tile := Vector2i(chunk_coord.x * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1), chunk_coord.y * _terrain.chunk_size_tiles + rng.randi_range(0, _terrain.chunk_size_tiles - 1))
	if not _terrain.is_walkable(tile):
		return false
	var bioma := _terrain.get_bioma_at(tile)
	var ecosistema := _terrain.get_ecosistema_at(tile)
	var habitats := _terrain.get_habitats_at(tile)
	if bioma.is_empty() or ecosistema.is_empty() or habitats.is_empty():
		_diag_prop_sin_contexto += 1
		return false
	var bioma_id := str(bioma.get("id", ""))
	var ecosistema_id := str(ecosistema.get("id", ""))
	if bioma_id.is_empty() or ecosistema_id.is_empty():
		return false
	var habitat_ids: Array[String] = []
	for habitat_variant in habitats:
		if habitat_variant is Dictionary:
			var habitat := habitat_variant as Dictionary
			var habitat_id := str(habitat.get("id", ""))
			if not habitat_id.is_empty() and habitat_id not in habitat_ids:
				habitat_ids.append(habitat_id)
	if habitat_ids.is_empty():
		return false
	var candidatos: Array[Dictionary] = []
	var candidatos_bioma: Array = _props_por_bioma.get(bioma_id, [])
	for prop_variant in candidatos_bioma:
		if not prop_variant is Dictionary:
			continue
		var prop := prop_variant as Dictionary
		var nombre := str(prop.get("nombre", "")).strip_edges()
		if nombre.is_empty():
			continue
		var coincide_contexto := (
			str(prop.get("ecosistema_id", "")) == ecosistema_id
			and str(prop.get("habitat_id", "")) in habitat_ids
		)
		if coincide_contexto:
			candidatos.append(prop)

	if candidatos.is_empty():
		for prop_variant in candidatos_bioma:
			if prop_variant is Dictionary and not str((prop_variant as Dictionary).get("nombre", "")).strip_edges().is_empty():
				candidatos.append(prop_variant as Dictionary)
	if candidatos.is_empty():
		_diag_prop_sin_candidato += 1
		return false
	var elegido_base := _spawn_rules.elegir_prop(candidatos, rng)
	if elegido_base.is_empty() or not _entity_factory.has_method("crear_prop"):
		_diag_prop_factory += 1
		return false
	var elegido := elegido_base.duplicate(true)
	var prop_id := str(elegido.get("id", elegido.get("clave", elegido.get("nombre", "")))).strip_edges()
	var asset_path := str(_asset_path_por_prop.get(prop_id, ""))
	if asset_path.is_empty():
		asset_path = _spawn_rules.construir_asset_path_prop(elegido)
		_asset_path_por_prop[prop_id] = asset_path
	if asset_path.is_empty():
		_diag_prop_factory += 1
		return false
	elegido["asset_path"] = asset_path
	var prop_instance_key := "prop:" + str(slot) + ":" + prop_id
	var estado := _entity_manager.obtener_estado_prop(chunk_coord, prop_instance_key)
	var prop_variant: Variant = _entity_factory.call("crear_prop", elegido)
	if not prop_variant is Node:
		return false
	var prop_node := prop_variant as Node
	prop_node.set_meta("runtime_instance_key", prop_instance_key)
	if not _entity_manager.registrar(prop_node, chunk_coord):
		_diag_prop_registro += 1
		return false
	prop_node.global_position = Vector2((float(tile.x) + 0.5) * _terrain.tile_size, (float(tile.y) + 0.5) * _terrain.tile_size)
	if not estado.is_empty():
		prop_node.global_position = estado.get("position", prop_node.global_position)
	if prop_node.has_method("configurar_chunk"):
		prop_node.call("configurar_chunk", chunk_coord, limite_chunk)
	_diag_prop_creados += 1
	return true

func summon_criatura(
	nombre: String,
	posicion: Vector2
) -> Dictionary:
	var nombre_solicitado: String = nombre.strip_edges()

	if nombre_solicitado.is_empty():
		return {
			"ok": false,
			"mensaje": "Debes indicar una criatura o personaje."
		}

	var personaje_game: Dictionary = (
		_world_data.buscar_personaje_game_por_nombre(
			nombre_solicitado
		)
	)

	var criatura_data: Dictionary = {}
	var nombre_inicial: String = nombre_solicitado

	if not personaje_game.is_empty():
		var criatura_id: String = str(
			personaje_game.get(
				"criatura_id",
				""
			)
		)

		criatura_data = _world_data.obtener_criatura(
			criatura_id
		).duplicate(true)

		if criatura_data.is_empty():
			return {
				"ok": false,
				"mensaje": (
					"El personaje "
					+ str(personaje_game.get("nombre", nombre_solicitado))
					+ " apunta a una criatura que no está en el mundo."
				)
			}

		criatura_data["nombre_individual"] = str(
			personaje_game.get(
				"nombre",
				nombre_solicitado
			)
		)
		var personaje_id := str(
			personaje_game.get(
				"id",
				""
			)
		)

		criatura_data["personaje_game_id"] = personaje_id

		var dialogo_personaje := _world_data.obtener_dialogo_game(
			personaje_id
		)
		if not dialogo_personaje.is_empty():
			criatura_data["dialogo"] = dialogo_personaje
		else:
			criatura_data.erase("dialogo")

		nombre_inicial = str(
			personaje_game.get(
				"nombre",
				nombre_solicitado
			)
		)
	else:
		criatura_data = _world_data.buscar_criatura_por_nombre(
			nombre_solicitado
		)

		if criatura_data.is_empty():
			return {
				"ok": false,
				"mensaje": (
					"No existe una criatura o personaje llamado "
					+ nombre_solicitado
				)
			}

		if str(
			criatura_data.get(
				"nombre",
				""
			)
		).strip_edges().to_lower() == "humano":
			var personajes_humanos: Array[Dictionary] = (
				_world_data.obtener_personajes_game_de_criatura(
					str(
						criatura_data.get(
							"id",
							""
						)
					)
				)
			)

			if not personajes_humanos.is_empty():
				var rng_personaje := RandomNumberGenerator.new()
				rng_personaje.randomize()

				var elegido: Dictionary = personajes_humanos[
					rng_personaje.randi_range(
						0,
						personajes_humanos.size() - 1
					)
				]

				criatura_data = criatura_data.duplicate(true)
				criatura_data["nombre_individual"] = str(
					elegido.get(
						"nombre",
						""
					)
				)
				var personaje_id := str(
					elegido.get(
						"id",
						""
					)
				)

				criatura_data["personaje_game_id"] = personaje_id

				var dialogo_personaje := _world_data.obtener_dialogo_game(
					personaje_id
				)
				if not dialogo_personaje.is_empty():
					criatura_data["dialogo"] = dialogo_personaje
				else:
					criatura_data.erase("dialogo")

				nombre_inicial = str(
					elegido.get(
						"nombre",
						"Humano"
					)
				)

	if _entity_manager == null:
		return {
			"ok": false,
			"mensaje": "Entity manager no configurado."
		}

	var criatura: Node = _entity_factory.crear_criatura(criatura_data)

	if criatura == null:
		return {
			"ok": false,
			"mensaje": (
				"No se pudo crear la escena "
				+ "de la criatura."
			)
		}

	if not _entity_manager.registrar_global(criatura):
		return {"ok": false, "mensaje": "No se pudo registrar la criatura."}

	criatura.global_position = (
		posicion
	)

	if criatura is Creature:
		var creature_node: Creature = (
			criatura
		)

		if _terrain != null:
			var tile_size := maxi(
				_terrain.tile_size,
				1
			)

			var posicion_local := (
				_terrain.to_local(
					posicion
				)
			)

			var tile := Vector2i(
				floori(
					posicion_local.x
					/ float(tile_size)
				),
				floori(
					posicion_local.y
					/ float(tile_size)
				)
			)

			var chunk_coord := Vector2i(
				floori(
					float(tile.x)
					/ float(
						_terrain.chunk_size_tiles
					)
				),
				floori(
					float(tile.y)
					/ float(
						_terrain.chunk_size_tiles
					)
				)
			)

			var origin_x := (
				chunk_coord.x
				* _terrain.chunk_size_tiles
			)

			var origin_y := (
				chunk_coord.y
				* _terrain.chunk_size_tiles
			)

			var limites_chunk := Rect2(
				float(
					origin_x
					* _terrain.tile_size
				),
				float(
					origin_y
					* _terrain.tile_size
				),
				float(
					_terrain.chunk_size_tiles
					* _terrain.tile_size
				),
				float(
					_terrain.chunk_size_tiles
					* _terrain.tile_size
				)
			)

			creature_node.configurar_chunk(
				chunk_coord,
				limites_chunk
			)

			creature_node.configurar_entorno(
				"general"
			)

	return {
		"ok": true,
		"nombre": nombre_inicial,
		"es_personaje_game": not personaje_game.is_empty(),
		"criatura": criatura
	}


func despawn_chunk(chunk_coord: Vector2i) -> void:
	cancelar_spawn_chunk(chunk_coord)
	cancelar_prop_spawn_chunk(chunk_coord)
	if _entity_manager != null:
		_entity_manager.despawn_criaturas_chunk(chunk_coord)
		_entity_manager.despawn_props_chunk(chunk_coord)


func despawn_criaturas_chunk(chunk_coord: Vector2i) -> void:
	cancelar_spawn_chunk(chunk_coord)
	if _entity_manager != null:
		_entity_manager.despawn_criaturas_chunk(chunk_coord)


func despawn_props_chunk(chunk_coord: Vector2i) -> void:
	cancelar_prop_spawn_chunk(chunk_coord)
	if _entity_manager != null:
		_entity_manager.despawn_props_chunk(chunk_coord)




func _spawn_characters_in_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2,
	rng: RandomNumberGenerator
) -> void:
	var personajes := _world_data.obtener_personajes_game()
	if personajes.is_empty():
		return

	var creados: Array = []

	for personaje_variant in personajes:
		if not personaje_variant is Dictionary:
			continue

		var personaje := personaje_variant as Dictionary
		var personaje_id := str(personaje.get("id", ""))
		var reino_game_id := str(personaje.get("reino_game_id", ""))
		var bioma_ids_variant: Variant = personaje.get("bioma_ids", [])

		if personaje_id.is_empty() or reino_game_id.is_empty():
			continue
		if _entity_manager != null and _entity_manager.existe_persistente(personaje_id):
			continue
		if not bioma_ids_variant is Array:
			continue

		var bioma_ids := bioma_ids_variant as Array
		if bioma_ids.is_empty():
			continue

		var tile := _spawn_rules.buscar_tile_para_personaje(chunk_coord, bioma_ids, rng)
		if tile == Vector2i(2147483647, 2147483647):
			continue

		var criatura_id := str(personaje.get("criatura_id", ""))
		if criatura_id.is_empty():
			continue

		var criatura_data := _world_data.obtener_criatura(criatura_id).duplicate(true)
		if criatura_data.is_empty():
			continue

		criatura_data["nombre_individual"] = str(personaje.get("nombre", ""))
		criatura_data["personaje_game_id"] = personaje_id
		criatura_data["reino_game_id"] = reino_game_id
		criatura_data["reino_nombre"] = str(personaje.get("reino_nombre", ""))

		var dialogo := _world_data.obtener_dialogo_game(personaje_id)
		if not dialogo.is_empty():
			criatura_data["dialogo"] = dialogo
		else:
			criatura_data.erase("dialogo")

		var criatura: Node = _entity_factory.crear_criatura(criatura_data)
		if criatura == null:
			continue

		criatura.set_meta("runtime_instance_key", "personaje:" + personaje_id)
		if not _entity_manager.registrar(criatura, chunk_coord, personaje_id):
			continue
		criatura.global_position = Vector2(
			(float(tile.x) + 0.5) * _terrain.tile_size,
			(float(tile.y) + 0.5) * _terrain.tile_size
		)
		criatura.set_meta("personaje_game_id", personaje_id)

		if criatura is Creature:
			var creature_node := criatura as Creature
			creature_node.configurar_chunk(chunk_coord, limite_chunk)
			creature_node.configurar_entorno("general")

		creados.append(criatura)

	if not creados.is_empty():
		print("WorldEntitySpawner: personajes en reino → chunk ", chunk_coord, " → ", creados.size())
