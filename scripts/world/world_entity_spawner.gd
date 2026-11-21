extends Node
class_name WorldEntitySpawner


@export_category("Aparición de criaturas")
@export var max_creatures_per_chunk: int = 5

@export_category("Aparición de Garumis")
@export_range(0, 4, 1) var max_garumis_per_chunk: int = 1
@export_range(0.0, 1.0, 0.01) var garumi_spawn_probability_per_chunk: float = 0.15
@export var mostrar_prototipo_garumi_en_debug_sin_catalogo: bool = true
@export_range(0.0, 1.0, 0.05) var probabilidad_prototipo_garumi_debug: float = 1.0
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
var _creature_spawn_tasks: Dictionary = {}
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
var _diag_spawn_criaturas_calls: int = 0
var _diag_spawn_criaturas_intentos: int = 0
var _diag_spawn_criaturas_ms_ultimo: float = 0.0
var _diag_spawn_criaturas_ms_maximo: float = 0.0
var _diag_data_materialize_step_last_ms: float = 0.0
var _diag_data_materialize_step_max_ms: float = 0.0
var _diag_data_materialize_step_count: int = 0


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
		if not _world_data.mundo_listo.is_connected(_al_catalogo_props_actualizado):
			_world_data.mundo_listo.connect(_al_catalogo_props_actualizado)
		if not _world_data.mundo_actualizado.is_connected(_al_catalogo_props_actualizado):
			_world_data.mundo_actualizado.connect(_al_catalogo_props_actualizado)
	_actualizar_catalogo_props()

	if _entity_manager == null:
		push_error("WorldEntitySpawner: Entity manager inválido.")
	if _entity_factory == null:
		push_error("WorldEntitySpawner: Entity factory inválido.")
	if _spawn_rules == null:
		push_error("WorldEntitySpawner: Spawn rules inválidas.")
	if _world_data == null:
		push_error("WorldEntitySpawner: WorldDataService inválido.")


func _al_catalogo_props_actualizado() -> void:
	_actualizar_catalogo_props()


func _actualizar_catalogo_props() -> void:
	_props_por_bioma.clear()
	_asset_path_por_prop.clear()
	if _world_data == null or not is_instance_valid(_world_data):
		return

	var props_catalogo := _world_data.obtener_props_game()
	var activos := 0
	for prop_variant in props_catalogo:
		if not prop_variant is Dictionary:
			continue
		var prop := (prop_variant as Dictionary).duplicate(true)
		if not bool(prop.get("activo", true)):
			continue
		var bioma_id := str(prop.get("bioma_id", "")).strip_edges()
		var prop_id := str(prop.get("id", prop.get("clave", prop.get("nombre", "")))).strip_edges()
		if bioma_id.is_empty() or prop_id.is_empty():
			continue
		if not _props_por_bioma.has(bioma_id):
			_props_por_bioma[bioma_id] = []
		(_props_por_bioma[bioma_id] as Array).append(prop)
		_asset_path_por_prop[prop_id] = ""
		activos += 1

	print("WorldEntitySpawner: catálogo de props actualizado → ", activos, " props en ", _props_por_bioma.size(), " biomas.")
	if activos > 0:
		_reintentar_props_en_chunks_cargados()


func _reintentar_props_en_chunks_cargados() -> void:
	if _terrain == null or _entity_manager == null:
		return
	for chunk_variant in _terrain.chunks_cargados():
		if not chunk_variant is Vector2i:
			continue
		var chunk_coord := chunk_variant as Vector2i
		var tiene_prop_real := false
		for entidad in _entity_manager.obtener_por_chunk(chunk_coord):
			if entidad is WorldProp and is_instance_valid(entidad):
				tiene_prop_real = true
				break
		if tiene_prop_real:
			continue
		cancelar_prop_spawn_chunk(chunk_coord)
		_entity_manager.despawn_props_chunk(chunk_coord)
		spawn_props_chunk(chunk_coord)


func configurar_render_manager(render_manager: Node) -> void:
	_render_manager = render_manager

func obtener_entity_manager() -> WorldEntityManager:
	return _entity_manager



func obtener_diagnostico() -> Dictionary:
	return {
		"cola_chunks": _spawn_queue.size(),
		"tareas_props": _prop_spawn_tasks.size(),
		"tareas_criaturas": _creature_spawn_tasks.size(),
		"cola_props_chunks": _prop_spawn_queue.size(),
		"chunks_iniciados": _diag_chunks_iniciados,
		"prop_intentos": _diag_prop_intentos,
		"prop_creados": _diag_prop_creados,
		"prop_sin_datos": _diag_prop_sin_datos,
		"prop_sin_contexto": _diag_prop_sin_contexto,
		"prop_sin_candidato": _diag_prop_sin_candidato,
		"prop_factory_fallo": _diag_prop_factory,
		"prop_registro_fallo": _diag_prop_registro,
		"spawn_criaturas_calls": _diag_spawn_criaturas_calls,
		"spawn_criaturas_intentos": _diag_spawn_criaturas_intentos,
		"spawn_criaturas_ms_ultimo": _diag_spawn_criaturas_ms_ultimo,
		"spawn_criaturas_ms_maximo": _diag_spawn_criaturas_ms_maximo,
		"data_materialize_step_last_ms": _diag_data_materialize_step_last_ms,
		"data_materialize_step_max_ms": _diag_data_materialize_step_max_ms,
		"data_materialize_step_count": _diag_data_materialize_step_count
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
	var datos := _entity_manager.obtener_datos_chunk(chunk_coord, "criaturas", false)
	if datos.is_empty():
		return false

	# El streaming puede haber materializado ya parte del chunk mediante FULL
	# mientras DATA terminaba de prepararse. No se debe abortar el chunk entero:
	# reconciliamos por runtime_instance_key y sólo creamos las apariciones que faltan.
	var claves_existentes: Dictionary = {}
	for entidad_variant in _entity_manager.obtener_por_chunk(chunk_coord):
		if not entidad_variant is Creature or not is_instance_valid(entidad_variant):
			continue
		var entidad_existente := entidad_variant as Creature
		var clave_existente := str(entidad_existente.get_meta("runtime_instance_key", "")).strip_edges()
		if not clave_existente.is_empty():
			claves_existentes[clave_existente] = true
	var hay_criaturas := not claves_existentes.is_empty()

	var limite_chunk := Rect2(
		float(chunk_coord.x * _terrain.chunk_size_tiles * _terrain.tile_size),
		float(chunk_coord.y * _terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size)
	)

	var procesados_desde_yield := 0
	var estados_materializados: Array[Dictionary] = []
	for dato_variant in datos:
		if not dato_variant is Dictionary:
			continue
		var dato_base := dato_variant as Dictionary
		var criatura_id := str(dato_base.get("criatura_id", "")).strip_edges()
		if criatura_id.is_empty():
			continue
		var instance_key := str(dato_base.get("runtime_instance_key", criatura_id)).strip_edges()
		# La mayoría de las llamadas de transición FULL revisitan chunks que ya
		# tienen sus criaturas instanciadas. Comprobar la clave antes de duplicar
		# recursivamente el registro evita copias profundas que se descartan.
		if not instance_key.is_empty() and claves_existentes.has(instance_key):
			continue
		var dato := dato_base.duplicate(true)
		if _entity_manager.has_method("obtener_estado_criatura"):
			var estado_runtime := _entity_manager.obtener_estado_criatura(chunk_coord, criatura_id, instance_key)
			if not estado_runtime.is_empty():
				for clave in estado_runtime.keys():
					dato[clave] = estado_runtime[clave]
		var categoria_entidad := str(dato.get("categoria_entidad", "criatura")).strip_edges().to_lower()
		if categoria_entidad != "garumi" and not bool(dato.get("is_alive", true)):
			continue
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
		# El contexto ecológico del punto de aparición acompaña a la instancia
		# runtime; así la IA consulta el clima de su hábitat real.
		for clave_ambiental in ["bioma_id", "ecosistema_id", "habitat_id", "habitat_clave"]:
			if dato.has(clave_ambiental):
				criatura_data[clave_ambiental] = dato[clave_ambiental]
		if dato.has("necesidades_runtime"):
			criatura_data["necesidades_runtime"] = dato["necesidades_runtime"]
		if categoria_entidad == "garumi":
			criatura_data["categoria_entidad"] = "garumi"
			criatura_data["asset_key"] = str(criatura_data.get("asset_key", criatura_data.get("nombre", "")))
			# La forma viene del catálogo; sólo se restaura el recurso propio del Garumi.
			if dato.has("eterium_actual"):
				criatura_data["eterium_actual"] = dato["eterium_actual"]
		var materialize_step_start_usec := Time.get_ticks_usec()
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
			if not creature_node is Garumi:
				var health := int(dato.get("health", creature_node.health))
				creature_node.restaurar_estado_vital(
					clampi(health, 0, creature_node.max_health),
					bool(dato.get("is_alive", true))
				)
			var posicion_inicial: Vector2 = dato.get("position", criatura.global_position)
			var velocidad_inicial: Vector2 = dato.get("velocity", creature_node.velocity)
			if dato.has("velocity") and dato["velocity"] is Vector2:
				creature_node.velocity = velocidad_inicial
			estados_materializados.append({
				"node": creature_node,
				"position": posicion_inicial,
				"velocity": velocidad_inicial,
				"has_velocity": dato.has("velocity") and dato["velocity"] is Vector2
			})

		claves_existentes[instance_key] = true
		hay_criaturas = true
		_registrar_data_materialize_step(materialize_step_start_usec)
		procesados_desde_yield += 1
		# DATA puede contener varias criaturas. Ceder periódicamente evita que
		# crear/configurar todas las instancias de un chunk ocupe un solo frame.
		if procesados_desde_yield >= 2:
			procesados_desde_yield = 0
			await get_tree().process_frame

	# Las criaturas creadas antes de un yield ya pueden recibir _process/_physics_process.
	# Reaplicar el estado DATA al final evita que su IA altere posición/velocidad
	# durante la materialización del resto del chunk.
	for estado_variant in estados_materializados:
		if not estado_variant is Dictionary:
			continue
		var estado := estado_variant as Dictionary
		var nodo_variant: Variant = estado.get("node", null)
		if not nodo_variant is Creature or not is_instance_valid(nodo_variant):
			continue
		var nodo := nodo_variant as Creature
		nodo.global_position = estado.get("position", nodo.global_position)
		if bool(estado.get("has_velocity", false)):
			nodo.velocity = estado.get("velocity", nodo.velocity)

	if hay_criaturas:
		_entity_manager.activar_criaturas_chunk(chunk_coord)
	return hay_criaturas


func spawn_chunk(chunk_coord: Vector2i) -> void:
	if _entity_manager == null:
		return
	if _entity_manager.tiene_criaturas_chunk(chunk_coord):
		return
	if _creature_spawn_tasks.has(chunk_coord):
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
	var candidatos_validos_por_contexto: Dictionary = {}
	for slot in range(max_creatures_per_chunk):
		var creado := false
		for intento in range(32):
			if intento % 4 == 0:
				await get_tree().process_frame
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
			var bioma_contexto_variant: Variant = contexto.get("bioma", {})
			var bioma_contexto_id := str((bioma_contexto_variant as Dictionary).get("id", "")) if bioma_contexto_variant is Dictionary else ""
			var zona_contexto := int(contexto.get("zona", -1))
			var clave_contexto := bioma_contexto_id + "\u001f" + str(ecosistema.get("id", "")) + "\u001f" + str(zona_contexto)
			var candidatos_contexto: Array[Dictionary]
			if candidatos_validos_por_contexto.has(clave_contexto):
				candidatos_contexto = candidatos_validos_por_contexto[clave_contexto]
			else:
				candidatos_contexto = []
				var candidatos := _spawn_rules.obtener_candidatos(ecosistema)
				if candidatos.is_empty():
					candidatos_validos_por_contexto[clave_contexto] = candidatos_contexto
					continue
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
					if criatura_id.is_empty():
						continue
					if not _spawn_rules.ubicacion_valida(
						bioma_contexto_variant,
						habitat_clave,
						zona_contexto
					):
						continue
					candidatos_contexto.append(candidato)
				candidatos_validos_por_contexto[clave_contexto] = candidatos_contexto
			if candidatos_contexto.is_empty():
				continue
			var validos: Array[Dictionary] = []
			for candidato in candidatos_contexto:
				var criatura_variant: Variant = candidato.get("criatura", {})
				if not criatura_variant is Dictionary:
					continue
				var criatura := criatura_variant as Dictionary
				var criatura_id := str(criatura.get("id", criatura.get("criatura_id", ""))).strip_edges()
				if not criatura_id.is_empty() and not especies.has(criatura_id):
					validos.append(candidato)
			if validos.is_empty():
				continue
			var candidato_elegido := validos[rng.randi_range(0, validos.size() - 1)] as Dictionary
			var criatura_elegida: Variant = candidato_elegido.get("criatura", {})
			if not criatura_elegida is Dictionary:
				continue
			var elegido := (criatura_elegida as Dictionary).duplicate(true)
			var habitat_clave := str(candidato_elegido.get("habitat_clave", "general")).to_lower()
			elegido["habitat_clave"] = habitat_clave
			var bioma_variant: Variant = contexto.get("bioma", {})
			var ecosistema_contexto_variant: Variant = contexto.get("ecosistema", {})
			if bioma_variant is Dictionary:
				elegido["bioma_id"] = str((bioma_variant as Dictionary).get("id", ""))
			if ecosistema_contexto_variant is Dictionary:
				elegido["ecosistema_id"] = str((ecosistema_contexto_variant as Dictionary).get("id", ""))
			var habitats_contexto_variant: Variant = contexto.get("habitats", [])
			if habitats_contexto_variant is Array:
				for habitat_variant in habitats_contexto_variant as Array:
					if not habitat_variant is Dictionary:
						continue
					var habitat := habitat_variant as Dictionary
					var tipo_habitat_variant: Variant = habitat.get("tipo_habitat", {})
					if tipo_habitat_variant is Dictionary and str((tipo_habitat_variant as Dictionary).get("clave", "")).to_lower() == habitat_clave:
						elegido["habitat_id"] = str(habitat.get("id", ""))
						break
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
	var datos_garumis: Array[Dictionary] = await _preparar_datos_garumis_en_chunk(chunk_coord, rng)
	for garumi_dato in datos_garumis:
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
		return await _preparar_datos_garumi_debug(chunk_coord, rng)

	var candidatos_probables: Array[Dictionary] = []
	for indice_garumi in range(catalogo.size()):
		# Filtrar el catálogo en lotes: ceder cada frame por registro alarga
		# innecesariamente DATA cuando el catálogo contiene muchos Garumis.
		if indice_garumi > 0 and indice_garumi % 8 == 0:
			await get_tree().process_frame
		var garumi: Dictionary = catalogo[indice_garumi]
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
			if intento % 4 == 0:
				await get_tree().process_frame
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
		if _intento % 4 == 0:
			await get_tree().process_frame
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
			"nombre": "Oruvan (prueba visual DEBUG sin catálogo)",
			"categoria_garumi": "normal",
			"original_id": garumi_original_id_habilitado,
			"numero_origen": garumi_generacion_habilitada,
			"asset_key": "Oruvan",
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
	var candidatos_props_por_contexto: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(_terrain.map_seed + chunk_coord.x * 92837111 + chunk_coord.y * 689287499) + 1

	for slot in range(6):
		var encontrado := false
		for intento in range(48):
			if intento % 4 == 0:
				await get_tree().process_frame
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
			var bioma_id := str(bioma.get("id", ""))
			var ecosistema_id := str(ecosistema.get("id", ""))
			var habitat_ids: Array[String] = []
			var habitat_id_set: Dictionary = {}
			for habitat_variant in habitats:
				if habitat_variant is Dictionary:
					var habitat_id := str((habitat_variant as Dictionary).get("id", ""))
					if not habitat_id.is_empty() and not habitat_id_set.has(habitat_id):
						habitat_ids.append(habitat_id)
						habitat_id_set[habitat_id] = true
			if bioma_id.is_empty() or ecosistema_id.is_empty():
				continue

			# Los intentos suelen reutilizar combinaciones ecológicas dentro del
			# mismo chunk. Resolver candidatos una vez por contexto evita volver
			# a recorrer todo el catálogo de props en cada intento.
			var clave_contexto := bioma_id + "\u001f" + ecosistema_id
			for habitat_id in habitat_ids:
				clave_contexto += "\u001f" + habitat_id
			var candidatos: Array[Dictionary]
			if candidatos_props_por_contexto.has(clave_contexto):
				candidatos = candidatos_props_por_contexto[clave_contexto]
			else:
				candidatos = []
				var candidatos_bioma: Array = _props_por_bioma.get(bioma_id, [])
				for prop_variant in candidatos_bioma:
					if not prop_variant is Dictionary:
						continue
					var prop := prop_variant as Dictionary
					if str(prop.get("nombre", "")).strip_edges().is_empty():
						continue
					var coincide := (
						str(prop.get("ecosistema_id", "")) == ecosistema_id
						and (habitat_ids.is_empty() or habitat_id_set.has(str(prop.get("habitat_id", ""))))
					)
					if coincide:
						candidatos.append(prop)

				if candidatos.is_empty():
					for prop_variant in candidatos_bioma:
						if prop_variant is Dictionary and not str((prop_variant as Dictionary).get("nombre", "")).strip_edges().is_empty():
							candidatos.append(prop_variant as Dictionary)
				candidatos_props_por_contexto[clave_contexto] = candidatos
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
	var datos := _entity_manager.obtener_datos_chunk(chunk_coord, "props", false)
	if datos.is_empty():
		return false
	var limite_chunk := Rect2(
		float(chunk_coord.x * _terrain.chunk_size_tiles * _terrain.tile_size),
		float(chunk_coord.y * _terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size),
		float(_terrain.chunk_size_tiles * _terrain.tile_size)
	)
	var claves_existentes: Dictionary = {}
	for entidad_variant in _entity_manager.obtener_por_chunk(chunk_coord):
		if entidad_variant is WorldProp and is_instance_valid(entidad_variant):
			var existente := entidad_variant as WorldProp
			var clave_existente := str(existente.get_meta("runtime_instance_key", "")).strip_edges()
			if not clave_existente.is_empty():
				claves_existentes[clave_existente] = true
	var procesados_desde_yield := 0
	for dato_variant in datos:
		if not dato_variant is Dictionary:
			continue
		var dato := dato_variant as Dictionary
		var instance_key := str(dato.get("runtime_instance_key", "")).strip_edges()
		if not instance_key.is_empty() and claves_existentes.has(instance_key):
			continue
		var estado := _entity_manager.obtener_estado_prop_materializacion(chunk_coord, instance_key)
		if not estado.is_empty() and not bool(estado.get("is_present", true)):
			continue
		var materialize_step_start_usec := Time.get_ticks_usec()
		var prop_variant: Variant = _entity_factory.call("crear_prop", dato)
		if not prop_variant is Node:
			continue
		var prop := prop_variant as Node
		prop.set_meta("runtime_instance_key", instance_key)
		if not _entity_manager.registrar(prop, chunk_coord):
			prop.queue_free()
			continue
		if not estado.is_empty():
			prop.global_position = estado.get("position", dato.get("position", prop.global_position))
		else:
			prop.global_position = dato.get("position", prop.global_position)
		if prop.has_method("configurar_chunk"):
			prop.call("configurar_chunk", chunk_coord, limite_chunk)
		claves_existentes[instance_key] = true
		_registrar_data_materialize_step(materialize_step_start_usec)
		procesados_desde_yield += 1
		if procesados_desde_yield >= 2:
			procesados_desde_yield = 0
			await get_tree().process_frame
	_entity_manager.activar_props_chunk(chunk_coord)
	return true


func _registrar_data_materialize_step(inicio_usec: int) -> void:
	var duracion_ms := float(Time.get_ticks_usec() - inicio_usec) / 1000.0
	_diag_data_materialize_step_last_ms = duracion_ms
	_diag_data_materialize_step_max_ms = maxf(_diag_data_materialize_step_max_ms, duracion_ms)
	_diag_data_materialize_step_count += 1


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
	# Un único chunk de criaturas activo evita que varios coroutines reanuden
	# sus intentos simultáneamente y vuelvan a concentrar trabajo en el mismo frame.
	if not _creature_spawn_tasks.is_empty():
		return
	var limite := maxi(max_chunks, 1)
	var procesados := 0
	while procesados < limite and not _spawn_queue.is_empty() and _creature_spawn_tasks.is_empty():
		var chunk_coord: Vector2i = _spawn_queue.pop_front()
		_spawn_queued.erase(chunk_coord)
		if _entity_manager != null and _entity_manager.tiene_criaturas_chunk(chunk_coord):
			continue
		if _creature_spawn_tasks.has(chunk_coord):
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
	_creature_spawn_tasks.erase(chunk_coord)


func cancelar_prop_spawn_chunk(chunk_coord: Vector2i) -> void:
	_prop_spawn_queued.erase(chunk_coord)
	_prop_spawn_queue.erase(chunk_coord)
	_prop_spawn_tasks.erase(chunk_coord)


func _spawn_chunk_interno(chunk_coord: Vector2i, token: RefCounted) -> void:
	var inicio_usec := Time.get_ticks_usec()
	_diag_spawn_criaturas_calls += 1
	await _spawn_chunk_interno_impl(chunk_coord, token)
	var duracion_ms := float(Time.get_ticks_usec() - inicio_usec) / 1000.0
	_diag_spawn_criaturas_ms_ultimo = duracion_ms
	_diag_spawn_criaturas_ms_maximo = maxf(_diag_spawn_criaturas_ms_maximo, duracion_ms)
	# Esta duración incluye los frames de espera del coroutine; no debe
	# registrarse como coste CPU del frame en RenderManager.
	if _creature_spawn_tasks.get(chunk_coord) == token:
		_creature_spawn_tasks.erase(chunk_coord)


func _spawn_chunk_interno_impl(chunk_coord: Vector2i, token: RefCounted) -> void:
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
	var candidatos_validos_por_contexto: Dictionary = {}

	for intento in range(32):
		if intento % 4 == 0:
			await get_tree().process_frame
		if _creature_spawn_tasks.get(chunk_coord) != token:
			return
		_diag_spawn_criaturas_intentos += 1
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

		# Leer bioma, ecosistema y zona desde una única consulta del chunk.
		# obtener_contexto_data_at accede directamente a los arrays compactos
		# cargados; el cache evita repetir esa consulta si un tile se reutiliza.
		var contexto := _obtener_contexto_data_cacheado(chunk_coord, tile)
		var bioma_variant: Variant = contexto.get("bioma", {})
		var ecosistema_variant: Variant = contexto.get("ecosistema", {})
		if not bioma_variant is Dictionary or not ecosistema_variant is Dictionary:
			continue
		var bioma := bioma_variant as Dictionary
		var ecosistema := ecosistema_variant as Dictionary
		if bioma.is_empty() or ecosistema.is_empty():
			continue

		var zona := int(contexto.get("zona", -1))
		var clave_contexto := str(bioma.get("id", "")) + "\u001f" + str(ecosistema.get("id", "")) + "\u001f" + str(zona)
		var candidatos_contexto: Array
		if candidatos_validos_por_contexto.has(clave_contexto):
			candidatos_contexto = candidatos_validos_por_contexto[clave_contexto]
		else:
			candidatos_contexto = []
			var candidatos: Array = _spawn_rules.obtener_candidatos(ecosistema)
			if candidatos.is_empty():
				candidatos_validos_por_contexto[clave_contexto] = candidatos_contexto
				continue
			for candidato_variant in candidatos:
				if not candidato_variant is Dictionary:
					continue
				var candidato := candidato_variant as Dictionary
				var criatura_variant: Variant = candidato.get("criatura", {})
				if not criatura_variant is Dictionary:
					continue
				var criatura_data := criatura_variant as Dictionary
				var criatura_id := str(criatura_data.get("id", "")).strip_edges()
				if criatura_id.is_empty():
					continue
				var habitat_clave := str(candidato.get("habitat_clave", "general"))
				if not _spawn_rules.ubicacion_valida(bioma, habitat_clave, zona):
					continue
				candidatos_contexto.append(candidato)
			candidatos_validos_por_contexto[clave_contexto] = candidatos_contexto

		var validos: Array = []
		for candidato in candidatos_contexto:
			var criatura_variant: Variant = (candidato as Dictionary).get("criatura", {})
			if not criatura_variant is Dictionary:
				continue
			var criatura_data := criatura_variant as Dictionary
			var criatura_id := str(criatura_data.get("id", "")).strip_edges()
			if not criatura_id.is_empty() and not especies_creadas.has(criatura_id):
				validos.append(candidato)
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
		if estado_previo.has("necesidades_runtime"):
			criatura_data["necesidades_runtime"] = estado_previo["necesidades_runtime"]

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

	await _spawn_garumis_en_chunk(chunk_coord, limite_chunk, rng, token)
	if _creature_spawn_tasks.get(chunk_coord) != token:
		return

	await _spawn_characters_in_chunk(
		chunk_coord,
		limite_chunk,
		rng,
		token
	)
	if _creature_spawn_tasks.get(chunk_coord) != token:
		return
	_entity_manager.activar_criaturas_chunk(chunk_coord)
	return

func _spawn_garumis_en_chunk(
	chunk_coord: Vector2i,
	limite_chunk: Rect2,
	rng: RandomNumberGenerator,
	token: RefCounted
) -> void:
	if _terrain == null or _entity_manager == null or _entity_factory == null or _spawn_rules == null or _world_data == null:
		return
	if max_garumis_per_chunk <= 0:
		return

	var catalogo := _world_data.obtener_garumis_game()
	if catalogo.is_empty():
		var datos_debug: Array[Dictionary] = await _preparar_datos_garumi_debug(chunk_coord, rng)
		if _creature_spawn_tasks.get(chunk_coord) != token:
			return
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
	for indice_garumi in range(catalogo.size()):
		if indice_garumi > 0 and indice_garumi % 8 == 0:
			await get_tree().process_frame
		var garumi: Dictionary = catalogo[indice_garumi]
		var garumi_id := str(garumi.get("id", "")).strip_edges()
		var garumi_nombre := str(garumi.get("nombre", "")).strip_edges()
		if garumi_id.is_empty() or garumi_nombre.is_empty():
			continue
		# FULL y DATA deben aplicar el mismo filtro canónico: únicamente
		# Garumis normales de la generación/origen habilitados.
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
			if intento % 4 == 0:
				await get_tree().process_frame
			if _creature_spawn_tasks.get(chunk_coord) != token:
				return
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
			if estado_previo.has("necesidades_runtime"):
				garumi_data["necesidades_runtime"] = estado_previo["necesidades_runtime"]
			# Restaurar datos de instancia sin permitir que una partida antigua
			# reintroduzca identidades de especies retiradas del catálogo.
			var datos_garumi_guardados_variant: Variant = estado_previo.get("garumi_datos", {})
			if datos_garumi_guardados_variant is Dictionary:
				var datos_garumi_guardados := datos_garumi_guardados_variant as Dictionary
				var claves_identidad_catalogo := [
					"id", "nombre", "criatura_id", "original_id", "numero_origen",
					"numero_global", "categoria_garumi", "asset_key",
					"estado_evolutivo", "evoluciona_de_id", "es_evolucion"
				]
				var aparicion_catalogo: Variant = garumi_data.get("aparicion", {})
				for clave_guardada in datos_garumi_guardados.keys():
					if str(clave_guardada) in claves_identidad_catalogo:
						continue
					garumi_data[clave_guardada] = datos_garumi_guardados[clave_guardada]
				if aparicion_catalogo is Dictionary and not (aparicion_catalogo as Dictionary).is_empty():
					garumi_data["aparicion"] = aparicion_catalogo
			for clave_progresion in ["nivel", "experiencia_total", "eterium_actual"]:
				if estado_previo.has(clave_progresion):
					garumi_data[clave_progresion] = estado_previo[clave_progresion]
			garumi_data["categoria_entidad"] = "garumi"
			garumi_data["runtime_instance_key"] = instancia_key
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
	if _entity_manager.tiene_criaturas_chunk(chunk_coord) or _creature_spawn_tasks.has(chunk_coord):
		return
	var token := RefCounted.new()
	_creature_spawn_tasks[chunk_coord] = token
	_spawn_chunk_interno(chunk_coord, token)


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
	if bioma.is_empty() or ecosistema.is_empty():
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
	# Algunos ecosistemas no entregan hábitats en todos los tiles.
	# El bioma y ecosistema siguen siendo suficientes para elegir sus props.
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
			and (habitat_ids.is_empty() or str(prop.get("habitat_id", "")) in habitat_ids)
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
	var estado := _entity_manager.obtener_estado_prop_materializacion(chunk_coord, prop_instance_key)
	if not estado.is_empty() and not bool(estado.get("is_present", true)):
		return false
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

func summon_garumi(
	nombre: String,
	posicion: Vector2
) -> Dictionary:
	var nombre_solicitado := nombre.strip_edges()
	if nombre_solicitado.is_empty():
		return {"ok": false, "mensaje": "Debes indicar el nombre del Garumi."}
	if _world_data == null or _entity_factory == null or _entity_manager == null:
		return {"ok": false, "mensaje": "El sistema de entidades no está configurado."}

	var garumi_data: Dictionary = {}
	for dato_variant in _world_data.obtener_garumis_game():
		if not dato_variant is Dictionary:
			continue
		var dato := dato_variant as Dictionary
		var nombre_catalogo := str(dato.get("nombre", "")).strip_edges()
		if nombre_catalogo.to_lower() == nombre_solicitado.to_lower():
			garumi_data = dato.duplicate(true)
			break

	if garumi_data.is_empty():
		return {
			"ok": false,
			"mensaje": "No existe un Garumi llamado " + nombre_solicitado + " en el catálogo activo."
		}

	garumi_data["categoria_entidad"] = "garumi"
	garumi_data["asset_key"] = str(garumi_data.get("asset_key", garumi_data.get("nombre", "")))
	var garumi_variant: Variant = _entity_factory.crear_criatura(garumi_data)
	if not garumi_variant is Creature:
		return {"ok": false, "mensaje": "No se pudo crear la escena del Garumi."}

	var garumi := garumi_variant as Creature
	var runtime_key := "garumi_admin:" + str(Time.get_ticks_msec())
	garumi.set_meta("runtime_instance_key", runtime_key)
	garumi.set_meta("entidad_categoria", "garumi")
	if not _entity_manager.registrar_global(garumi):
		garumi.queue_free()
		return {"ok": false, "mensaje": "No se pudo registrar el Garumi en el mundo."}

	garumi.global_position = posicion
	if _terrain != null:
		var tile_size := maxi(_terrain.tile_size, 1)
		var posicion_local := _terrain.to_local(posicion)
		var tile := Vector2i(floori(posicion_local.x / float(tile_size)), floori(posicion_local.y / float(tile_size)))
		var chunk_coord := Vector2i(
			floori(float(tile.x) / float(_terrain.chunk_size_tiles)),
			floori(float(tile.y) / float(_terrain.chunk_size_tiles))
		)
		var origin_x := chunk_coord.x * _terrain.chunk_size_tiles
		var origin_y := chunk_coord.y * _terrain.chunk_size_tiles
		var limites_chunk := Rect2(
			Vector2(float(origin_x * _terrain.tile_size), float(origin_y * _terrain.tile_size)),
			Vector2(float(_terrain.chunk_size_tiles * _terrain.tile_size), float(_terrain.chunk_size_tiles * _terrain.tile_size))
		)
		garumi.configurar_chunk(chunk_coord, limites_chunk)
		garumi.configurar_entorno("general")

	return {"ok": true, "nombre": str(garumi_data.get("nombre", nombre_solicitado)), "garumi": garumi}


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


func iniciar_despawn_chunk(chunk_coord: Vector2i) -> bool:
	cancelar_spawn_chunk(chunk_coord)
	cancelar_prop_spawn_chunk(chunk_coord)
	if _entity_manager == null or not is_instance_valid(_entity_manager):
		return true
	return _entity_manager.iniciar_despawn_chunk(chunk_coord)


func procesar_despawn_chunk(chunk_coord: Vector2i, max_entities: int = 6) -> bool:
	if _entity_manager == null or not is_instance_valid(_entity_manager):
		return true
	return _entity_manager.procesar_despawn_chunk(chunk_coord, max_entities)


func despawn_chunk(chunk_coord: Vector2i) -> void:
	# Compatibilidad con llamadas administrativas que requieren limpieza inmediata.
	cancelar_spawn_chunk(chunk_coord)
	cancelar_prop_spawn_chunk(chunk_coord)
	if _entity_manager != null:
		_entity_manager.despawn_chunk(chunk_coord)


func obtener_diagnostico_despawn() -> Dictionary:
	if _entity_manager == null or not is_instance_valid(_entity_manager):
		return {}
	return _entity_manager.obtener_diagnostico_despawn()


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
	rng: RandomNumberGenerator,
	token: RefCounted
) -> void:
	var personajes := _world_data.obtener_personajes_game()
	if personajes.is_empty():
		return

	var creados: Array = []

	for personaje_variant in personajes:
		await get_tree().process_frame
		if _creature_spawn_tasks.get(chunk_coord) != token:
			return
		if not personaje_variant is Dictionary:
			continue

		var personaje := personaje_variant as Dictionary
		var personaje_id := str(personaje.get("id", ""))
		var reino_game_id := str(personaje.get("reino_game_id", ""))
		var bioma_ids_variant: Variant = personaje.get("bioma_ids", [])

		# Los personajes con ubicación fija pertenecen a escenas de reino.
		# No deben aparecer aleatoriamente en chunks del mundo procedural.
		if not str(personaje.get("ubicacion_clave", "")).strip_edges().is_empty():
			continue
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
		criatura_data["ubicacion_clave"] = str(personaje.get("ubicacion_clave", ""))
		var rutinas_variant: Variant = personaje.get("rutinas", [])
		criatura_data["rutinas"] = rutinas_variant.duplicate(true) if rutinas_variant is Array else []

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
