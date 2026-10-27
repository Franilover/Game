extends Node
class_name WorldDataService



signal mundo_listo
signal mundo_actualizado
signal error_mundo(mensaje: String)


const BUNDLED_WORLD_PATH := (
	"res://data/world_initial.json"
)

const USER_CACHE_PATH := (
	"user://cache/world_initial.json"
)


var mundo: Dictionary = {}
var cargado: bool = false

var _mundo_bloqueado: bool = false
var _mundo_pendiente: Dictionary = {}
var _firma_actual: String = ""
var _supabase_client: GarliaSupabaseClient = null


# Índices rápidos.
var _biomas_por_id: Dictionary = {}
var _ecosistemas_por_id: Dictionary = {}
var _habitats_por_id: Dictionary = {}
var _criaturas_por_id: Dictionary = {}
var _personajes_game: Array[Dictionary] = []
var _dialogos_game: Array[Dictionary] = []
var _misiones_game: Array[Dictionary] = []
var _reinos_game: Array[Dictionary] = []
var _props_game: Array[Dictionary] = []
var _lugares_game: Array[Dictionary] = []
var _garumis_game: Array[Dictionary] = []
var _garumis_por_id: Dictionary = {}


func configurar_dependencias(supabase_client: GarliaSupabaseClient) -> void:
	_supabase_client = supabase_client
	if _supabase_client == null:
		return
	if not _supabase_client.mundo_cargado.is_connected(_al_mundo_remoto):
		_supabase_client.mundo_cargado.connect(_al_mundo_remoto)
	if not _supabase_client.error_conexion.is_connected(_al_error_remoto):
		_supabase_client.error_conexion.connect(_al_error_remoto)

func _ready() -> void:

	_cargar_fuente_local()

	call_deferred(
		"_solicitar_actualizacion_remota"
	)


func _cargar_fuente_local() -> void:
	var cache := _leer_mundo_local(
		USER_CACHE_PATH,
		true
	)

	var incluido := _leer_mundo_local(
		BUNDLED_WORLD_PATH,
		false
	)

	if cache.is_empty() and incluido.is_empty():
		print(
			"WorldData: no existe snapshot local. "
			+ "Esperando Supabase."
		)
		return

	var elegido: Dictionary = incluido
	var origen := "snapshot incluido en el build"

	if elegido.is_empty():
		elegido = cache
		origen = "cache del jugador"
	elif not cache.is_empty():
		var fecha_cache := str(
			cache.get(
				"generado_en",
				""
			)
		)

		var fecha_incluido := str(
			elegido.get(
				"generado_en",
				""
			)
		)

		if (
			fecha_cache > fecha_incluido
			or fecha_cache == fecha_incluido
		):
			elegido = cache
			origen = "cache del jugador"

	_aplicar_mundo(
		elegido,
		origen,
		false
	)


func _leer_mundo_local(
	ruta: String,
	es_cache: bool
) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}

	var archivo := FileAccess.open(
		ruta,
		FileAccess.READ
	)

	if archivo == null:
		return {}

	var texto := archivo.get_as_text()
	archivo.close()

	var datos = JSON.parse_string(texto)

	if not datos is Dictionary:
		return {}

	var diccionario := datos as Dictionary

	# Los caches nuevos se guardan dentro de {"mundo": ...}.
	# También aceptamos el formato antiguo de cache directo.
	if es_cache and diccionario.has("mundo"):
		var mundo_cache: Variant = diccionario.get(
			"mundo",
			null
		)

		if mundo_cache is Dictionary:
			diccionario = mundo_cache as Dictionary

	if not _mundo_valido(diccionario):
		return {}

	return diccionario.duplicate(true)


func _solicitar_actualizacion_remota() -> void:
	if _supabase_client != null:
		_supabase_client.iniciar_sincronizacion()


func _al_mundo_remoto(
	mundo_remoto: Dictionary
) -> void:
	if not _mundo_valido(mundo_remoto):
		return

	var firma := _calcular_firma(
		mundo_remoto
	)

	# Siempre guardamos una versión remota nueva para que
	# el siguiente arranque pueda usarla incluso offline.
	if firma != _firma_actual:
		_guardar_cache(
			mundo_remoto
		)

	if _mundo_bloqueado or _partida_activa():
		if firma == _firma_actual:
			return

		# La geometría/ecología estructural espera a la próxima sesión, pero
		# la IA necesita recibir ahora las reglas canónicas remotas. De otro
		# modo, un cache antiguo con ia_config={} deja mudas sus habilidades.
		if _partida_activa():
			_actualizar_configuracion_ia_en_vivo(mundo_remoto)

		_mundo_pendiente = mundo_remoto.duplicate(true)

		print(
			"WorldData: actualización remota guardada "
			+ "para la próxima sesión."
		)

		return

	if firma == _firma_actual:
		return

	_aplicar_mundo(
		mundo_remoto,
		"Supabase",
		true
	)


func _partida_activa() -> bool:
	var escena := get_tree().current_scene

	if escena == null:
		return false

	return escena.get_node_or_null("World/WorldGenerator") != null


func _actualizar_configuracion_ia_en_vivo(mundo_remoto: Dictionary) -> void:
	var configuraciones: Dictionary = {}
	_recopilar_configuraciones_ia(mundo_remoto, configuraciones)
	if configuraciones.is_empty():
		return

	# Actualiza el índice usado por los próximos spawns sin reemplazar la
	# topología del mundo que ya está generándose.
	for criatura_id_variant in configuraciones.keys():
		var criatura_id := str(criatura_id_variant)
		var actual_variant: Variant = _criaturas_por_id.get(criatura_id, {})
		if not actual_variant is Dictionary:
			continue
		var actual := (actual_variant as Dictionary).duplicate(true)
		var config: Dictionary = configuraciones[criatura_id]
		actual["ia_config"] = config.get("ia_config", {})
		actual["comportamiento"] = config.get("comportamiento", null)
		actual["magia"] = config.get("magia", null)
		_criaturas_por_id[criatura_id] = actual

	# Las criaturas que ya existen reciben la configuración nueva en caliente.
	for entidad in get_tree().get_nodes_in_group("creatures"):
		if not entidad is Creature or not is_instance_valid(entidad):
			continue
		var criatura := entidad as Creature
		var id := criatura.criatura_id
		if not configuraciones.has(id):
			continue
		var datos_actualizados := criatura.datos.duplicate(true)
		var config: Dictionary = configuraciones[id]
		datos_actualizados["ia_config"] = config.get("ia_config", {})
		datos_actualizados["comportamiento"] = config.get("comportamiento", null)
		datos_actualizados["magia"] = config.get("magia", null)
		criatura.datos = datos_actualizados
		criatura.comportamiento = str(datos_actualizados.get("comportamiento", ""))
		criatura.magia = str(datos_actualizados.get("magia", ""))
		var ai := criatura.get_node_or_null("AIController") as CreatureAI
		if ai != null:
			ai.configurar_criatura()

	print("WorldData: configuraciones de IA canónicas sincronizadas en vivo → ", configuraciones.size(), " especies.")


func _recopilar_configuraciones_ia(valor: Variant, salida: Dictionary) -> void:
	if valor is Dictionary:
		var diccionario := valor as Dictionary
		if diccionario.has("id") and diccionario.has("nombre") and diccionario.has("ia_config"):
			var id := str(diccionario.get("id", "")).strip_edges()
			if not id.is_empty():
				salida[id] = {
					"ia_config": diccionario.get("ia_config", {}),
					"comportamiento": diccionario.get("comportamiento", null),
					"magia": diccionario.get("magia", null)
				}
		for hijo in diccionario.values():
			if hijo is Dictionary or hijo is Array:
				_recopilar_configuraciones_ia(hijo, salida)
	elif valor is Array:
		for hijo in valor as Array:
			if hijo is Dictionary or hijo is Array:
				_recopilar_configuraciones_ia(hijo, salida)


func _al_error_remoto(
	_mensaje: String
) -> void:
	# No se considera error de arranque si ya tenemos
	# un mundo local válido.
	if cargado:
		return

	error_mundo.emit(
		"No existe una copia local del mundo y "
		+ "Supabase no está disponible."
	)


func _aplicar_mundo(
	mundo_nuevo: Dictionary,
	origen: String,
	es_actualizacion: bool
) -> void:
	mundo = mundo_nuevo.duplicate(true)

	_construir_indices()

	_firma_actual = _calcular_firma(
		mundo
	)

	var era_cargado := cargado
	cargado = true

	print(
		"WorldData: mundo cargado desde ",
		origen,
		". Biomas = ",
		_biomas_por_id.size(),
		" | Ecosistemas = ",
		_ecosistemas_por_id.size(),
		" | Habitats = ",
		_habitats_por_id.size(),
		" | Criaturas = ",
		_criaturas_por_id.size()
	)

	if not era_cargado:
		mundo_listo.emit()
	elif es_actualizacion:
		mundo_actualizado.emit()


func _guardar_cache(
	datos: Dictionary
) -> void:
	var directorio := ProjectSettings.globalize_path(
		"user://cache"
	)

	DirAccess.make_dir_recursive_absolute(
		directorio
	)

	var archivo := FileAccess.open(
		USER_CACHE_PATH,
		FileAccess.WRITE
	)

	if archivo == null:
		print(
			"WorldData: no se pudo guardar el cache local."
		)
		return

	var envoltorio := {
		"guardado_en": Time.get_datetime_string_from_system(
			true
		),
		"mundo": datos.duplicate(true)
	}

	archivo.store_string(
		JSON.stringify(envoltorio)
	)

	archivo.close()

	print(
		"WorldData: cache local actualizado."
	)


func _mundo_valido(
	datos: Dictionary
) -> bool:
	if not datos.has("biomas"):
		return false

	if not datos["biomas"] is Array:
		return false

	return true


func _calcular_firma(
	datos: Dictionary
) -> String:
	var copia := datos.duplicate(true)

	copia.erase("generado_en")

	return JSON.stringify(
		copia
	)


func bloquear_actualizaciones() -> void:
	_mundo_bloqueado = true

	print(
		"WorldData: actualizaciones remotas bloqueadas "
		+ "para la sesión actual."
	)


func desbloquear_actualizaciones() -> void:
	_mundo_bloqueado = false

	if _mundo_pendiente.is_empty():
		return

	var pendiente := _mundo_pendiente.duplicate(true)
	_mundo_pendiente.clear()

	var firma := _calcular_firma(
		pendiente
	)

	if firma == _firma_actual:
		return

	_aplicar_mundo(
		pendiente,
		"Supabase pendiente",
		true
	)


func esta_bloqueado() -> bool:
	return _mundo_bloqueado


func _exit_tree() -> void:
	_mundo_bloqueado = false


# =========================================================
# CONSTRUCCIÓN DE ÍNDICES
# =========================================================

func _construir_indices() -> void:
	_biomas_por_id.clear()
	_ecosistemas_por_id.clear()
	_habitats_por_id.clear()
	_criaturas_por_id.clear()
	_personajes_game.clear()
	_dialogos_game.clear()
	_misiones_game.clear()
	_reinos_game.clear()
	_props_game.clear()
	_lugares_game.clear()
	_garumis_game.clear()
	_garumis_por_id.clear()

	# Garumis usan un catálogo raíz independiente de las criaturas de hábitat.
	# Esto conserva su categoría propia sin mezclarlos en _criaturas_por_id.
	var garumis_variant: Variant = mundo.get("garumis_game", [])
	if garumis_variant is Array:
		for garumi_variant in garumis_variant as Array:
			if not garumi_variant is Dictionary:
				continue
			var garumi := (garumi_variant as Dictionary).duplicate(true)
			var garumi_id := str(garumi.get("id", "")).strip_edges()
			var garumi_nombre := str(garumi.get("nombre", "")).strip_edges()
			if garumi_id.is_empty() or garumi_nombre.is_empty() or _garumis_por_id.has(garumi_id):
				continue
			_garumis_game.append(garumi)
			_garumis_por_id[garumi_id] = garumi

	var reinos_variant: Variant = mundo.get(
		"reinos_game",
		[]
	)

	if reinos_variant is Array:
		for reino_variant in reinos_variant:
			if not reino_variant is Dictionary:
				continue

			_reinos_game.append(
				(reino_variant as Dictionary).duplicate(true)
			)

	var props_variant: Variant = mundo.get(
		"props_game",
		[]
	)

	if props_variant is Array:
		for prop_variant in props_variant:
			if not prop_variant is Dictionary:
				continue

			_props_game.append(
				(prop_variant as Dictionary).duplicate(true)
			)

	var lugares_variant: Variant = mundo.get(
		"lugares_game",
		[]
	)

	if lugares_variant is Array:
		for lugar_variant in lugares_variant:
			if not lugar_variant is Dictionary:
				continue
			var lugar := (lugar_variant as Dictionary).duplicate(true)
			var lugar_id := str(lugar.get("lugar_id", "")).strip_edges()
			var asset_key := str(lugar.get("asset_key", "")).strip_edges()
			if lugar_id.is_empty() or asset_key.is_empty():
				continue
			_lugares_game.append(lugar)

	var misiones_variant: Variant = mundo.get(
		"misiones_game",
		[]
	)

	if misiones_variant is Array:
		for mision_variant in misiones_variant:
			if not mision_variant is Dictionary:
				continue

			_misiones_game.append(
				(mision_variant as Dictionary).duplicate(true)
			)

	var personajes_variant: Variant = mundo.get(
		"personajes_game",
		[]
	)

	if personajes_variant is Array:
		for personaje_variant in personajes_variant:
			if not personaje_variant is Dictionary:
				continue

			_personajes_game.append(
				(personaje_variant as Dictionary).duplicate(true)
			)

	var dialogos_variant: Variant = mundo.get(
		"dialogos_game",
		[]
	)

	if dialogos_variant is Array:
		for dialogo_variant in dialogos_variant:
			if not dialogo_variant is Dictionary:
				continue

			_dialogos_game.append(
				(dialogo_variant as Dictionary).duplicate(true)
			)

	for bioma in obtener_biomas():
		if bioma is Dictionary:
			_indexar_bioma(bioma)

	for ecosistema in obtener_ecosistemas_sin_bioma():
		if ecosistema is Dictionary:
			_indexar_ecosistema(ecosistema)


func _indexar_bioma(
	bioma: Dictionary
) -> void:
	var bioma_id: String = str(
		bioma.get("id", "")
	)

	if bioma_id.is_empty():
		return

	_biomas_por_id[bioma_id] = bioma

	var ecosistemas: Array = bioma.get(
		"ecosistemas",
		[]
	)

	for ecosistema in ecosistemas:
		if ecosistema is Dictionary:
			_indexar_ecosistema(ecosistema)


func _indexar_ecosistema(
	ecosistema: Dictionary
) -> void:
	var ecosistema_id: String = str(
		ecosistema.get("id", "")
	)

	if ecosistema_id.is_empty():
		return

	_ecosistemas_por_id[ecosistema_id] = ecosistema

	var habitats: Array = ecosistema.get(
		"habitats",
		[]
	)

	for habitat in habitats:
		if habitat is Dictionary:
			_indexar_habitat(habitat)


func _indexar_habitat(
	habitat: Dictionary
) -> void:
	var habitat_id: String = str(
		habitat.get("id", "")
	)

	if habitat_id.is_empty():
		return

	_habitats_por_id[habitat_id] = habitat

	var criaturas: Array = habitat.get(
		"criaturas",
		[]
	)

	for criatura in criaturas:
		if criatura is Dictionary:
			_indexar_criatura(criatura)


func _indexar_criatura(
	criatura: Dictionary
) -> void:
	var criatura_id: String = str(
		criatura.get("id", "")
	)

	if criatura_id.is_empty():
		return

	_criaturas_por_id[criatura_id] = criatura


# =========================================================
# CONSULTAS
# =========================================================

func obtener_biomas() -> Array:
	return mundo.get(
		"biomas",
		[]
	)


func obtener_ecosistemas_sin_bioma() -> Array:
	return mundo.get(
		"ecosistemas_sin_bioma",
		[]
	)


func obtener_bioma(
	bioma_id: String
) -> Dictionary:
	return _biomas_por_id.get(
		bioma_id,
		{}
	)


func obtener_ecosistema(
	ecosistema_id: String
) -> Dictionary:
	return _ecosistemas_por_id.get(
		ecosistema_id,
		{}
	)


func obtener_habitat(
	habitat_id: String
) -> Dictionary:
	return _habitats_por_id.get(
		habitat_id,
		{}
	)


func obtener_criatura(
	criatura_id: String
) -> Dictionary:
	return _criaturas_por_id.get(
		criatura_id,
		{}
	)


func obtener_criaturas() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for criatura_variant in _criaturas_por_id.values():
		if not criatura_variant is Dictionary:
			continue

		resultado.append(
			(criatura_variant as Dictionary).duplicate(true)
		)

	return resultado


func buscar_criatura_por_nombre(
	nombre: String
) -> Dictionary:
	var buscado := nombre.strip_edges().to_lower()

	if buscado.is_empty():
		return {}

	for criatura_variant in _criaturas_por_id.values():
		if not criatura_variant is Dictionary:
			continue

		var criatura := criatura_variant as Dictionary

		var nombre_criatura := str(
			criatura.get(
				"nombre",
				""
			)
		)

		if nombre_criatura.to_lower() == buscado:
			return criatura.duplicate(true)

	return {}


func obtener_garumis_game() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for garumi in _garumis_game:
		resultado.append(garumi.duplicate(true))
	return resultado


func obtener_garumi_game(garumi_id: String) -> Dictionary:
	var buscado := garumi_id.strip_edges()
	if buscado.is_empty():
		return {}
	var garumi_variant: Variant = _garumis_por_id.get(buscado, {})
	if garumi_variant is Dictionary:
		return (garumi_variant as Dictionary).duplicate(true)
	return {}


func obtener_diagnostico_garumis_game() -> Dictionary:
	var con_aparicion := 0
	var sin_aparicion: Array[String] = []
	var con_sprite := 0
	var sin_sprite: Array[String] = []
	for garumi in _garumis_game:
		var garumi_id := str(garumi.get("id", ""))
		var aparicion_variant: Variant = garumi.get("aparicion", {})
		if aparicion_variant is Dictionary and not (aparicion_variant as Dictionary).is_empty():
			con_aparicion += 1
		else:
			sin_aparicion.append(garumi_id)
		var asset_key := str(garumi.get("asset_key", garumi.get("nombre", ""))).strip_edges()
		var sprite_png := "res://assets/art/garumis/" + asset_key + ".png"
		var sprite_upper := "res://assets/art/garumis/" + asset_key + ".PNG"
		if not asset_key.is_empty() and (FileAccess.file_exists(sprite_png) or FileAccess.file_exists(sprite_upper)):
			con_sprite += 1
		else:
			sin_sprite.append(garumi_id)
	return {
		"catalogo": _garumis_game.size(),
		"con_aparicion": con_aparicion,
		"sin_aparicion": sin_aparicion.size(),
		"ids_sin_aparicion": sin_aparicion,
		"con_sprite": con_sprite,
		"sin_sprite": sin_sprite.size(),
		"ids_sin_sprite": sin_sprite
	}


func obtener_props_game() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for prop in _props_game:
		resultado.append(prop.duplicate(true))

	return resultado

func obtener_lugares_game() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for lugar in _lugares_game:
		resultado.append(lugar.duplicate(true))
	return resultado

## Diagnóstico de preparación espacial. El catálogo por sí solo no autoriza
## a colocar un lugar: necesita un ancla geográfica validada y calibración.
func obtener_diagnostico_lugares_game() -> Dictionary:
	var con_ancla_valida := 0
	var sin_ancla: Array[String] = []
	for lugar_variant in _lugares_game:
		if not lugar_variant is Dictionary:
			continue
		var lugar := lugar_variant as Dictionary
		var ancla_variant: Variant = lugar.get("ancla_espacial", {})
		if not ancla_variant is Dictionary:
			sin_ancla.append(str(lugar.get("lugar_id", "")))
			continue
		var ancla := ancla_variant as Dictionary
		if not ancla.has("latitud_deg") or not ancla.has("longitud_deg"):
			sin_ancla.append(str(lugar.get("lugar_id", "")))
			continue
		var latitud := float(ancla.get("latitud_deg", 999.0))
		var longitud := float(ancla.get("longitud_deg", 999.0))
		if latitud < -90.0 or latitud > 90.0 or longitud < -180.0 or longitud > 180.0:
			sin_ancla.append(str(lugar.get("lugar_id", "")))
			continue
		con_ancla_valida += 1
	return {
		"catalogo_activo": _lugares_game.size(),
		"con_ancla_geografica_valida": con_ancla_valida,
		"sin_ancla_geografica": sin_ancla.size(),
		"ids_sin_ancla": sin_ancla,
		"materializacion_espacial_habilitada": false,
		"motivo": "Requiere ancla geográfica canónica y calibración planetaria confirmada por el motor geográfico."
	}



func obtener_reinos_game() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for reino in _reinos_game:
		resultado.append(reino.duplicate(true))

	return resultado


func buscar_reino_game_por_clave(
	clave: String
) -> Dictionary:
	var buscada := clave.strip_edges().to_lower()

	if buscada.is_empty():
		return {}

	for reino in _reinos_game:
		if str(reino.get("clave", "")).to_lower() == buscada:
			return reino.duplicate(true)

	return {}


func obtener_reinos_game_de_bioma(
	bioma_id: String
) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	if bioma_id.is_empty():
		return resultado

	for reino in _reinos_game:
		var bioma_ids_variant: Variant = reino.get("bioma_ids", [])
		if not bioma_ids_variant is Array:
			continue

		if bioma_id not in (bioma_ids_variant as Array):
			continue

		resultado.append(reino.duplicate(true))

	return resultado


func obtener_misiones_game() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for mision in _misiones_game:
		resultado.append(mision.duplicate(true))

	return resultado


func buscar_mision_game_por_clave(
	clave: String
) -> Dictionary:
	var buscada := clave.strip_edges().to_lower()

	if buscada.is_empty():
		return {}

	for mision in _misiones_game:
		if str(mision.get("clave", "")).to_lower() == buscada:
			return mision.duplicate(true)

	return {}


func obtener_personajes_game() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	for personaje in _personajes_game:
		resultado.append(
			personaje.duplicate(true)
		)

	return resultado


func obtener_personaje_game_por_id(personaje_id: String) -> Dictionary:
	var buscado := personaje_id.strip_edges()
	if buscado.is_empty():
		return {}

	for personaje in _personajes_game:
		if str(personaje.get("id", "")) == buscado:
			return personaje.duplicate(true)

	return {}


func buscar_personaje_game_por_nombre(
	nombre: String
) -> Dictionary:
	var buscado := nombre.strip_edges().to_lower()

	if buscado.is_empty():
		return {}

	for personaje in _personajes_game:
		var nombre_personaje := str(
			personaje.get(
				"nombre",
				""
			)
		)

		if nombre_personaje.to_lower() == buscado:
			return personaje.duplicate(true)

	return {}


func obtener_dialogo_game(
	personaje_id: String,
	clave: String = "principal"
) -> Dictionary:
	if personaje_id.is_empty():
		return {}

	for dialogo in _dialogos_game:
		if str(dialogo.get("personaje_id", "")) != personaje_id:
			continue
		if str(dialogo.get("clave", "principal")) != clave:
			continue

		var contenido: Variant = dialogo.get("dialogo", {})
		if contenido is Dictionary:
			return (contenido as Dictionary).duplicate(true)
		if contenido is Array:
			return {"lineas": (contenido as Array).duplicate(true)}

	return {}


func obtener_dialogos_game_de_personaje(
	personaje_id: String
) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	if personaje_id.is_empty():
		return resultado

	for dialogo in _dialogos_game:
		if str(dialogo.get("personaje_id", "")) != personaje_id:
			continue

		resultado.append(dialogo.duplicate(true))

	return resultado


func obtener_personajes_game_de_criatura(
	criatura_id: String
) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	if criatura_id.is_empty():
		return resultado

	for personaje in _personajes_game:
		if str(
			personaje.get(
				"criatura_id",
				""
			)
		) != criatura_id:
			continue

		resultado.append(
			personaje.duplicate(true)
		)

	return resultado


func obtener_ecosistemas_de_bioma(
	bioma_id: String
) -> Array:
	var bioma := obtener_bioma(bioma_id)

	if bioma.is_empty():
		return []

	return bioma.get(
		"ecosistemas",
		[]
	)


func obtener_habitats_de_ecosistema(
	ecosistema_id: String
) -> Array:
	var ecosistema := obtener_ecosistema(
		ecosistema_id
	)

	if ecosistema.is_empty():
		return []

	return ecosistema.get(
		"habitats",
		[]
	)


func obtener_criaturas_de_habitat(
	habitat_id: String
) -> Array:
	var habitat := obtener_habitat(
		habitat_id
	)

	if habitat.is_empty():
		return []

	return habitat.get(
		"criaturas",
		[]
	)


func obtener_calendario() -> Dictionary:
	var calendario_variant: Variant = mundo.get(
		"calendario",
		{}
	)
	if calendario_variant is Dictionary:
		return (calendario_variant as Dictionary).duplicate(true)

	return {}


func obtener_estaciones() -> Array:
	var calendario := obtener_calendario()
	var estaciones_variant: Variant = calendario.get(
		"estaciones",
		[]
	)
	if estaciones_variant is Array:
		return (estaciones_variant as Array).duplicate(true)

	return []


func obtener_factores_ambientales_ecosistema(
	ecosistema_id: String
) -> Dictionary:
	return _obtener_factores_ambientales(
		"ecosistemas",
		ecosistema_id
	)


func obtener_factores_ambientales_habitat(
	habitat_id: String
) -> Dictionary:
	return _obtener_factores_ambientales(
		"habitats",
		habitat_id
	)


func obtener_factor_ambiental_habitat(
	habitat_id: String,
	clave: String
) -> Dictionary:
	var factores := obtener_factores_ambientales_habitat(
		habitat_id
	)

	var valor_variant: Variant = factores.get(
		clave,
		{}
	)

	if valor_variant is Dictionary:
		return (valor_variant as Dictionary).duplicate(true)

	return {}


func obtener_ambiente_estacional(
	estacion_id: String
) -> Dictionary:
	if estacion_id.is_empty():
		return {}

	var ambiente_variant: Variant = mundo.get(
		"ambiente_estacional",
		{}
	)

	if not ambiente_variant is Dictionary:
		return {}

	var estacion_variant: Variant = (
		(ambiente_variant as Dictionary).get(
			estacion_id,
			{}
		)
	)

	if estacion_variant is Dictionary:
		return (estacion_variant as Dictionary).duplicate(true)

	return {}


func obtener_ambiente_estacional_ecosistema(
	estacion_id: String,
	ecosistema_id: String
) -> Dictionary:
	var estacion := obtener_ambiente_estacional(
		estacion_id
	)

	if estacion.is_empty():
		return {}

	var ecosistemas_variant: Variant = estacion.get(
		"ecosistemas",
		{}
	)

	if not ecosistemas_variant is Dictionary:
		return {}

	var factores_variant: Variant = (
		(ecosistemas_variant as Dictionary).get(
			ecosistema_id,
			{}
		)
	)

	if factores_variant is Dictionary:
		return (factores_variant as Dictionary).duplicate(true)

	return {}


func obtener_ambiente_estacional_habitat(
	estacion_id: String,
	habitat_id: String
) -> Dictionary:
	var estacion := obtener_ambiente_estacional(
		estacion_id
	)

	if estacion.is_empty():
		return {}

	var habitats_variant: Variant = estacion.get(
		"habitats",
		{}
	)

	if not habitats_variant is Dictionary:
		return {}

	var factores_variant: Variant = (
		(habitats_variant as Dictionary).get(
			habitat_id,
			{}
		)
	)

	if factores_variant is Dictionary:
		return (factores_variant as Dictionary).duplicate(true)

	return {}


func obtener_modificadores_estacionales() -> Array:
	var modificadores_variant: Variant = mundo.get(
		"modificadores_estacionales",
		[]
	)

	if modificadores_variant is Array:
		return (modificadores_variant as Array).duplicate(true)

	return []


func obtener_definiciones_factores_abioticos() -> Array:
	var factores_variant: Variant = mundo.get(
		"factores_abioticos",
		{}
	)

	if not factores_variant is Dictionary:
		return []

	var definiciones_variant: Variant = (
		(factores_variant as Dictionary).get(
			"definiciones",
			[]
		)
	)

	if definiciones_variant is Array:
		return (definiciones_variant as Array).duplicate(true)

	return []


func _obtener_factores_ambientales(
	nivel: String,
	id: String
) -> Dictionary:
	if id.is_empty():
		return {}

	var factores_ambientales_variant: Variant = mundo.get(
		"factores_abioticos",
		{}
	)

	if not factores_ambientales_variant is Dictionary:
		return {}

	var niveles_variant: Variant = (
		(factores_ambientales_variant as Dictionary).get(
			nivel,
			{}
		)
	)

	if not niveles_variant is Dictionary:
		return {}

	var factores_variant: Variant = (
		(niveles_variant as Dictionary).get(
			id,
			{}
		)
	)

	if factores_variant is Dictionary:
		return (factores_variant as Dictionary).duplicate(true)

	return {}


func esta_cargado() -> bool:
	return cargado
