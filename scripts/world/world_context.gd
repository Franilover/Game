extends Node
class_name WorldContext

var terrain: WorldTerrain
var atmosphere: WorldAtmosphere
var _world_data: WorldDataService = null

func configurar(
	nuevo_terrain: WorldTerrain,
	nueva_atmosphere: WorldAtmosphere,
	nuevo_world_data: WorldDataService = null
) -> void:
	terrain = nuevo_terrain
	atmosphere = nueva_atmosphere
	_world_data = nuevo_world_data

func tiene_mundo_activo() -> bool:
	return terrain != null and is_instance_valid(terrain)


func get_tile_at(posicion_global: Vector2) -> Vector2i:
	if terrain == null:
		return Vector2i.ZERO
	var posicion_local := terrain.to_local(posicion_global)
	var tamano := maxi(terrain.tile_size, 1)
	return Vector2i(floori(posicion_local.x / float(tamano)), floori(posicion_local.y / float(tamano)))

func get_chunk_size_tiles() -> int:
	return terrain.chunk_size_tiles if terrain != null else 1

func get_map_seed() -> int:
	return terrain.map_seed if terrain != null else 0

func get_chunks_cargados() -> Array:
	return terrain.chunks_cargados() if terrain != null else []

func obtener_tiempo() -> Dictionary:
	if atmosphere == null:
		return {}
	return atmosphere.obtener_tiempo()

func get_tile_size() -> int:
	return maxi(terrain.tile_size, 1) if terrain != null else 1

func get_spawn_position() -> Vector2:
	return terrain.get_spawn_position() if terrain != null else Vector2.ZERO

func is_walkable(tile: Vector2i) -> bool:
	return terrain != null and terrain.is_walkable(tile)

func get_bioma_at(tile: Vector2i) -> Dictionary:
	return terrain.get_bioma_at(tile) if terrain != null else {}

func get_ecosistema_at(tile: Vector2i) -> Dictionary:
	return terrain.get_ecosistema_at(tile) if terrain != null else {}

func get_habitats_at(tile: Vector2i) -> Array:
	return terrain.get_habitats_at(tile) if terrain != null else []

func get_criaturas_at(tile: Vector2i) -> Array:
	return terrain.get_criaturas_at(tile) if terrain != null else []

func get_zona_at(tile: Vector2i) -> int:
	return terrain.get_zona_at(tile) if terrain != null else -1

func cambiar_zona_at(tile: Vector2i, nueva_zona: int) -> bool:
	return terrain != null and terrain.cambiar_zona_at(tile, nueva_zona)

func get_reinos_at(tile: Vector2i) -> Array[Dictionary]:
	var bioma := get_bioma_at(tile)
	if bioma.is_empty():
		return []
	var bioma_id := str(bioma.get("id", ""))
	return [] if bioma_id.is_empty() or _world_data == null else _world_data.obtener_reinos_game_de_bioma(bioma_id)

func get_reinos_at_position(posicion_global: Vector2) -> Array[Dictionary]:
	return get_reinos_at(get_tile_at(posicion_global))

func buscar_posicion_reino(nombre: String, origen: Vector2) -> Vector2:
	if terrain == null:
		return Vector2.INF
	var buscado := nombre.strip_edges().to_lower()
	if buscado.is_empty():
		return Vector2.INF
	var centro := get_tile_at(origen)
	for distancia in range(65):
		for dy in range(-distancia, distancia + 1):
			for dx in range(-distancia, distancia + 1):
				if maxi(abs(dx), abs(dy)) != distancia:
					continue
				var tile := centro + Vector2i(dx, dy)
				if not terrain.is_walkable(tile):
					continue
				for reino in get_reinos_at(tile):
					if str(reino.get("clave", "")).to_lower() == buscado or str(reino.get("nombre", "")).to_lower() == buscado:
						return (Vector2(tile) + Vector2(0.5, 0.5)) * float(terrain.tile_size)
	return Vector2.INF

func get_contexto_at(posicion_global: Vector2) -> Dictionary:
	if terrain == null:
		return {}
	var tile := get_tile_at(posicion_global)
	var bioma := get_bioma_at(tile)
	var ecosistema := get_ecosistema_at(tile)
	return {
		"bioma": _nombre(bioma),
		"ecosistema": _nombre(ecosistema),
		"habitat": _nombres_habitats(get_habitats_at(tile)),
		"clima": str(ecosistema.get("clima", "")),
		"factores_abioticos": get_factores_ambientales_at(posicion_global)
	}

func get_factores_ambientales_at(posicion_global: Vector2) -> Dictionary:
	if terrain == null:
		return {}
	var tile := get_tile_at(posicion_global)
	var estacion_id := str(atmosphere.obtener_estacion_id()) if atmosphere != null else ""
	for habitat_variant in get_habitats_at(tile):
		if not habitat_variant is Dictionary:
			continue
		var id := str((habitat_variant as Dictionary).get("id", ""))
		if id.is_empty():
			continue
		if not estacion_id.is_empty():
			var estacional: Dictionary = {}
			if _world_data != null:
				estacional = _world_data.obtener_ambiente_estacional_habitat(estacion_id, id)
			if not estacional.is_empty():
				return estacional
		var base: Dictionary = {}
		if _world_data != null:
			base = _world_data.obtener_factores_ambientales_habitat(id)
		if not base.is_empty():
			return base
	var ecosistema := get_ecosistema_at(tile)
	var id := str(ecosistema.get("id", ""))
	if id.is_empty():
		return {}
	if not estacion_id.is_empty():
		var estacional: Dictionary = {}
		if _world_data != null:
			estacional = _world_data.obtener_ambiente_estacional_ecosistema(estacion_id, id)
		if not estacional.is_empty():
			return estacional
	return _world_data.obtener_factores_ambientales_ecosistema(id) if _world_data != null else {}

func _nombre(datos: Dictionary) -> String:
	var nombre := str(datos.get("nombre", ""))
	return nombre if not nombre.is_empty() else "—"

func _nombres_habitats(habitats: Array) -> String:
	var nombres: Array[String] = []
	for variante in habitats:
		if not variante is Dictionary:
			continue
		var habitat := variante as Dictionary
		var nombre := str(habitat.get("nombre", ""))
		if nombre.is_empty():
			var tipo: Variant = habitat.get("tipo_habitat", {})
			if tipo is Dictionary:
				nombre = str((tipo as Dictionary).get("nombre", ""))
				if nombre.is_empty():
					nombre = str((tipo as Dictionary).get("clave", "")).capitalize()
		if not nombre.is_empty() and not nombre in nombres:
			nombres.append(nombre)
	return "—" if nombres.is_empty() else " · ".join(nombres)
