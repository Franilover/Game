extends Node
class_name WorldSpawnRules

## Reglas puras de selección de entidades.
## No instancia nodos y no administra su ciclo de vida.

var _terrain: WorldTerrain
# Los candidatos de un ecosistema son datos canónicos estables durante una
# partida. Cachearlos evita reconstruir arrays/diccionarios en cada intento
# de selección DATA.
var _candidatos_por_ecosistema: Dictionary = {}

func configurar(terrain: WorldTerrain) -> void:
	_terrain = terrain
	_candidatos_por_ecosistema.clear()


func elegir_criatura(
	candidatos: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	var validos: Array = []
	for candidato_variant in candidatos:
		if not candidato_variant is Dictionary:
			continue
		var candidato := candidato_variant as Dictionary
		var criatura_variant: Variant = candidato.get("criatura", {})
		if not criatura_variant is Dictionary:
			continue
		var criatura := criatura_variant as Dictionary
		if str(criatura.get("id", "")).is_empty():
			continue
		validos.append(candidato)

	if validos.is_empty():
		return {}

	var peso_total := 0.0
	for candidato in validos:
		peso_total += maxf(obtener_peso_criatura(candidato), 0.0)

	if peso_total <= 0.0:
		return {}

	var objetivo := rng.randf_range(0.0, peso_total)
	var acumulado := 0.0
	for candidato in validos:
		var peso := maxf(obtener_peso_criatura(candidato), 0.0)
		acumulado += peso
		if objetivo <= acumulado:
			return candidato

	return validos.back()


func obtener_peso_criatura(candidato: Dictionary) -> float:
	# El peso de aparición no se decide por nombres hardcodeados en Godot.
	# Si la fuente canónica aporta un peso, SpawnRules lo respeta; de lo
	# contrario, cada candidato válido tiene el mismo peso.
	var peso_variant: Variant = candidato.get("peso_spawn", 1.0)
	if peso_variant is int or peso_variant is float:
		return maxf(float(peso_variant), 0.0)
	return 1.0


func obtener_candidatos(ecosistema: Dictionary) -> Array:
	var ecosistema_id := str(ecosistema.get("id", "")).strip_edges()
	if not ecosistema_id.is_empty() and _candidatos_por_ecosistema.has(ecosistema_id):
		return _candidatos_por_ecosistema[ecosistema_id]

	var resultado: Array = []
	var habitats_variant: Variant = ecosistema.get("habitats", [])
	if not habitats_variant is Array:
		return resultado

	var vistos: Dictionary = {}
	for habitat_variant in habitats_variant:
		if not habitat_variant is Dictionary:
			continue

		var habitat := habitat_variant as Dictionary
		var tipo_variant: Variant = habitat.get("tipo_habitat", {})
		var habitat_clave := "general"
		if tipo_variant is Dictionary:
			habitat_clave = str((tipo_variant as Dictionary).get("clave", "general")).to_lower()

		var criaturas_variant: Variant = habitat.get("criaturas", [])
		if not criaturas_variant is Array:
			continue

		for criatura_variant in criaturas_variant:
			if not criatura_variant is Dictionary:
				continue
			var criatura := criatura_variant as Dictionary
			var criatura_id := str(criatura.get("id", ""))
			if criatura_id.is_empty() or vistos.has(criatura_id):
				continue
			vistos[criatura_id] = true
			resultado.append({
				"criatura": criatura,
				"habitat_clave": habitat_clave
			})

	if not ecosistema_id.is_empty():
		_candidatos_por_ecosistema[ecosistema_id] = resultado
	return resultado

## Filtro de aparición inicial.
## "numero_origen" numera registros dentro del linaje; no es un nivel ni una
## generación. Sólo pueden aparecer formas normales iniciales del Original
## habilitado y aprobadas en canon. Las formas finales se alcanzan evolucionando.
func garumi_cumple_filtro_generacional(
	garumi: Dictionary,
	original_id_permitido: String,
	generacion_permitida: int
) -> bool:
	if garumi.is_empty() or original_id_permitido.strip_edges().is_empty() or generacion_permitida != 1:
		return false
	var categoria := str(garumi.get("categoria_garumi", "")).strip_edges().to_lower()
	if categoria != "normal":
		return false
	# El mundo sólo genera la forma inicial. Las formas evolucionadas se
	# obtienen mediante la progresión de una instancia existente, nunca como
	# encuentros independientes. Si falta el estado, se rechaza por seguridad.
	var estado_evolutivo := str(garumi.get("estado_evolutivo", "")).strip_edges().to_lower()
	if estado_evolutivo != "inicial":
		return false
	var evoluciona_de_id := str(garumi.get("evoluciona_de_id", "")).strip_edges()
	if not evoluciona_de_id.is_empty() or bool(garumi.get("es_evolucion", false)):
		return false
	# Si el snapshot incluye estado documental, nunca permitir borradores.
	# Si lo omite, el exportador debe garantizar que sólo entrega canon aprobado.
	if garumi.has("estado_documentacion"):
		var estado := str(garumi.get("estado_documentacion", "")).strip_edges().to_lower()
		if estado not in ["aprobado", "canon"]:
			return false
	var original_id := str(garumi.get("original_id", "")).strip_edges()
	if original_id != original_id_permitido.strip_edges():
		return false
	# El parámetro se conserva por compatibilidad con la configuración del
	# spawner, pero no se compara con numero_origen: no representa generación.
	return true

## Un Garumi sólo puede aparecer si su registro trae una regla ecológica
## explícita en "aparicion". Los selectores presentes se combinan por AND;
## los valores de cada selector se combinan por OR.
func garumi_puede_aparecer(
	garumi: Dictionary,
	bioma: Dictionary,
	ecosistema: Dictionary,
	habitats: Array
) -> bool:
	var aparicion_variant: Variant = garumi.get("aparicion", {})
	if not aparicion_variant is Dictionary:
		return false
	var aparicion := aparicion_variant as Dictionary
	if aparicion.is_empty():
		return false

	var bioma_ids := _normalizar_selector_ids(aparicion.get("bioma_ids", []))
	if bioma_ids.is_empty():
		bioma_ids = _normalizar_selector_ids(aparicion.get("bioma_id", ""))
	var ecosistema_ids := _normalizar_selector_ids(aparicion.get("ecosistema_ids", []))
	if ecosistema_ids.is_empty():
		ecosistema_ids = _normalizar_selector_ids(aparicion.get("ecosistema_id", ""))
	var habitat_ids := _normalizar_selector_ids(aparicion.get("habitat_ids", []))
	if habitat_ids.is_empty():
		habitat_ids = _normalizar_selector_ids(aparicion.get("habitat_id", ""))
	var habitat_claves := _normalizar_selector_ids(aparicion.get("habitat_claves", []))
	if habitat_claves.is_empty():
		habitat_claves = _normalizar_selector_ids(aparicion.get("habitat_clave", ""))

	# No permitir que un registro sin anclas ecológicas aparezca por todo el mundo.
	if bioma_ids.is_empty() and ecosistema_ids.is_empty() and habitat_ids.is_empty() and habitat_claves.is_empty():
		return false

	if not bioma_ids.is_empty() and str(bioma.get("id", "")) not in bioma_ids:
		return false
	if not ecosistema_ids.is_empty() and str(ecosistema.get("id", "")) not in ecosistema_ids:
		return false

	var ids_habitats_presentes: Array[String] = []
	var claves_habitats_presentes: Array[String] = []
	for habitat_variant in habitats:
		if not habitat_variant is Dictionary:
			continue
		var habitat := habitat_variant as Dictionary
		var habitat_id := str(habitat.get("id", "")).strip_edges()
		if not habitat_id.is_empty() and habitat_id not in ids_habitats_presentes:
			ids_habitats_presentes.append(habitat_id)
		var tipo_variant: Variant = habitat.get("tipo_habitat", {})
		if tipo_variant is Dictionary:
			var clave := str((tipo_variant as Dictionary).get("clave", "")).strip_edges().to_lower()
			if not clave.is_empty() and clave not in claves_habitats_presentes:
				claves_habitats_presentes.append(clave)
		if not habitat.has("tipo_habitat"):
			var clave_directa := str(habitat.get("clave", "")).strip_edges().to_lower()
			if not clave_directa.is_empty() and clave_directa not in claves_habitats_presentes:
				claves_habitats_presentes.append(clave_directa)

	if not habitat_ids.is_empty():
		var coincide_habitat := false
		for habitat_id in habitat_ids:
			if habitat_id in ids_habitats_presentes:
				coincide_habitat = true
				break
		if not coincide_habitat:
			return false
	if not habitat_claves.is_empty():
		# "general" describe un alcance ecológico amplio, no un hábitat literal.
		# Por ello admite cualquier hábitat del bioma/ecosistema que ya pasó
		# los selectores más específicos del registro.
		var selector_general := "general" in habitat_claves
		var coincide_clave := selector_general
		if not coincide_clave:
			for clave in habitat_claves:
				if clave.to_lower() in claves_habitats_presentes:
					coincide_clave = true
					break
		if not coincide_clave:
			return false
	return true


func obtener_probabilidad_spawn_garumi(garumi: Dictionary, probabilidad_predeterminada: float) -> float:
	var aparicion_variant: Variant = garumi.get("aparicion", {})
	if not aparicion_variant is Dictionary:
		return 0.0
	var aparicion := aparicion_variant as Dictionary
	var valor: Variant = aparicion.get("probabilidad_chunk", probabilidad_predeterminada)
	if not (valor is int or valor is float):
		return clampf(probabilidad_predeterminada, 0.0, 1.0)
	return clampf(float(valor), 0.0, 1.0)


func elegir_garumi(candidatos: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if candidatos.is_empty():
		return {}
	var peso_total := 0.0
	for garumi in candidatos:
		var aparicion_variant: Variant = garumi.get("aparicion", {})
		var aparicion: Dictionary = aparicion_variant if aparicion_variant is Dictionary else {}
		var peso_variant: Variant = aparicion.get("peso_spawn", garumi.get("peso_spawn", 1.0))
		if peso_variant is int or peso_variant is float:
			peso_total += maxf(float(peso_variant), 0.0)
	if peso_total <= 0.0:
		return {}
	var objetivo := rng.randf_range(0.0, peso_total)
	var acumulado := 0.0
	for garumi in candidatos:
		var aparicion_variant: Variant = garumi.get("aparicion", {})
		var aparicion: Dictionary = aparicion_variant if aparicion_variant is Dictionary else {}
		var peso_variant: Variant = aparicion.get("peso_spawn", garumi.get("peso_spawn", 1.0))
		var peso := maxf(float(peso_variant), 0.0) if peso_variant is int or peso_variant is float else 0.0
		acumulado += peso
		if objetivo <= acumulado:
			return garumi
	return candidatos.back()


func _normalizar_selector_ids(valor: Variant) -> Array[String]:
	var resultado: Array[String] = []
	if valor is String:
		var clave := (valor as String).strip_edges()
		if not clave.is_empty():
			resultado.append(clave)
	elif valor is Array:
		for elemento in valor as Array:
			var clave := str(elemento).strip_edges()
			if not clave.is_empty() and clave not in resultado:
				resultado.append(clave)
	return resultado


func ubicacion_valida(
	bioma: Dictionary,
	habitat_clave: String,
	zona: int
) -> bool:
	var acuatico := _bioma_es_acuatico(bioma)
	var tierra := zona != WorldTerrain.Zone.WATER and zona != WorldTerrain.Zone.DEEP_WATER
	var agua := not tierra

	if acuatico:
		match habitat_clave:
			"pelagico", "bentonico", "litoral":
				return agua
			"ribera":
				return tierra
			"aereo", "general":
				return true
			_:
				return agua

	match habitat_clave:
		"pelagico", "bentonico", "litoral":
			return false
		"aereo":
			return true
		_:
			return tierra


func _bioma_es_acuatico(bioma: Dictionary) -> bool:
	var generacion_variant: Variant = bioma.get("generacion", {})
	if not generacion_variant is Dictionary:
		return false

	var zonas_variant: Variant = (generacion_variant as Dictionary).get("zonas", [])
	if not zonas_variant is Array:
		return false

	for zona_variant in zonas_variant:
		if not zona_variant is Dictionary:
			continue

		var terreno := str(
			(zona_variant as Dictionary).get("terreno", "")
		).to_lower()

		if terreno == "water" or terreno == "deep_water":
			return true

	return false


func buscar_tile_para_personaje(
	chunk_coord: Vector2i,
	bioma_ids: Array,
	rng: RandomNumberGenerator
) -> Vector2i:
	if _terrain == null:
		return Vector2i(2147483647, 2147483647)

	var origen_x := chunk_coord.x * _terrain.chunk_size_tiles
	var origen_y := chunk_coord.y * _terrain.chunk_size_tiles
	var candidatos: Array[Vector2i] = []

	for y in range(_terrain.chunk_size_tiles):
		for x in range(_terrain.chunk_size_tiles):
			var tile := Vector2i(origen_x + x, origen_y + y)
			if not _terrain.is_walkable(tile):
				continue
			var bioma := _terrain.get_bioma_at(tile)
			if not bioma.is_empty() and str(bioma.get("id", "")) in bioma_ids:
				candidatos.append(tile)

	if candidatos.is_empty():
		return Vector2i(2147483647, 2147483647)

	return candidatos[rng.randi_range(0, candidatos.size() - 1)]


func elegir_prop(candidatos: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if candidatos.is_empty():
		return {}

	var peso_total := 0.0
	for prop in candidatos:
		peso_total += maxf(float(prop.get("peso", 1.0)), 0.0)

	if peso_total <= 0.0:
		return {}

	var objetivo := rng.randf_range(0.0, peso_total)
	var acumulado := 0.0
	for prop in candidatos:
		acumulado += maxf(float(prop.get("peso", 1.0)), 0.0)
		if objetivo <= acumulado:
			return prop

	return candidatos.back()


func construir_asset_path_prop(prop: Dictionary) -> String:
	var nombre := str(prop.get("nombre", "")).strip_edges()
	if nombre.is_empty():
		return ""

	# Los registros especializados de Supabase pueden llamarse
	# "Árbol (Bosque húmedo)" o "Flor Azul (Bosque interior)", pero el asset
	# visual reutilizable es el prop base. El nombre canónico sigue siendo el
	# de Supabase; sólo resolvemos aquí su representación visual.
	var nombre_base := nombre
	var parentesis := nombre_base.find(" (")
	if parentesis >= 0:
		nombre_base = nombre_base.substr(0, parentesis).strip_edges()

	var candidatos: Array[String] = [
		"res://assets/art/props/" + nombre + ".png",
		"res://assets/art/props/" + nombre + ".PNG",
		"res://assets/art/props/" + quitar_acentos(nombre) + ".png",
		"res://assets/art/props/" + quitar_acentos(nombre) + ".PNG",
		"res://assets/art/props/" + nombre_base + ".png",
		"res://assets/art/props/" + nombre_base + ".PNG",
		"res://assets/art/props/" + quitar_acentos(nombre_base) + ".png",
		"res://assets/art/props/" + quitar_acentos(nombre_base) + ".PNG"
	]

	var clave := str(prop.get("clave", "")).strip_edges()
	if not clave.is_empty():
		var clave_base := clave
		var separador_entorno := clave_base.find("_bosque_")
		if separador_entorno >= 0:
			clave_base = clave_base.substr(0, separador_entorno)

		var claves_visuales: Array[String] = [
			clave,
			clave_base
		]
		for clave_candidata in claves_visuales:
			var clave_visual := clave_candidata.capitalize()
			candidatos.append("res://assets/art/props/" + clave_visual + ".png")
			candidatos.append("res://assets/art/props/" + clave_visual + ".PNG")
			candidatos.append("res://assets/art/props/" + quitar_acentos(clave_visual) + ".png")
			candidatos.append("res://assets/art/props/" + quitar_acentos(clave_visual) + ".PNG")

	for ruta in candidatos:
		if FileAccess.file_exists(ruta):
			return ruta

	return ""


func quitar_acentos(texto: String) -> String:
	var resultado := texto
	resultado = resultado.replace("á", "a").replace("Á", "A")
	resultado = resultado.replace("é", "e").replace("É", "E")
	resultado = resultado.replace("í", "i").replace("Í", "I")
	resultado = resultado.replace("ó", "o").replace("Ó", "O")
	resultado = resultado.replace("ú", "u").replace("Ú", "U")
	return resultado.replace("ñ", "n").replace("Ñ", "N")
