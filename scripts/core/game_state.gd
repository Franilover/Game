extends Node
class_name GameStateService
## GameState — estado de la partida y guardado local.
##
## Las partidas NO se guardan en Supabase.
## Cada partida corresponde a un JSON independiente en user://partidas/.

const SAVE_DIRECTORY := "user://partidas"
const STORY_SAVE_DIRECTORY := "user://historia"
const STORY_SAVE_ID := "reserva_carmesi"
const SAVE_VERSION: int = 3
const AUTOSAVE_INTERVAL: float = 10.0
const GUARDADO_RAPIDO_ESPERA_S: float = 1.0
# Supabase puede no responder (modo offline/error de red). No permitir que una
# configuración remota pendiente bloquee indefinidamente la restauración vital
# ni, por consecuencia, todos los guardados locales.
const RESTAURACION_VITAL_TIMEOUT_S: float = 5.0
const MAIN_SCENE_PATH: String = "res://scenes/world/main.tscn"

var player_state := PlayerState.new()
var world_state := WorldState.new()
var discovery_state := DiscoveryState.new()

var active_save_id: String = ""
var active_save_name: String = ""
# Cabecera pequeña de la partida activa; evita releer y duplicar el JSON completo en cada autosave.
var _active_save_header: Dictionary = {}

var save_repository := SaveFileRepository.new()
var story_save_repository := SaveFileRepository.new()
var _partidas_metadata_cache: Array[Dictionary] = []
var _partidas_metadata_cache_valida: bool = false
var _partidas_metadata_precalentando: bool = false
signal partidas_metadata_precalentadas

var _historia_reserva_activa: bool = false
var _historia_requiere_aplicar: bool = false

var _autosave_timer: float = 0.0
var _primer_guardado_pendiente: bool = false
var _primer_guardado_elapsed: float = 0.0
var _ultimo_motivo_fallo_guardado: String = ""
var _partida_aplicada_en_escena: bool = false
var _guardado_en_curso: bool = false
var _runtime_no_detectado_reportado: bool = false
var _guardado_rapido_conectado: bool = false
var _guardado_rapido_pendiente: bool = false
var _esperando_configuracion_eterium_jugador: bool = false
var _estado_vital_restaurado_en_escena: bool = false
var _espera_restauracion_vital_elapsed: float = 0.0
var _inventory: GarliaInventory = null
var _player: Player = null
var _world_context: WorldContext = null
var _world_atmosphere: WorldAtmosphere = null
var _mission_manager: MissionManagerService = null
var _world_data: WorldDataService = null

signal enciclopedia_actualizada(criatura_id: String)
signal mapa_exploracion_actualizada
signal descubrimientos_mundo_actualizados
signal descubrimiento_mundo(nivel: String, id: String)
signal garumis_vinculados_actualizados
signal garumis_amigos_actualizados
signal dinero_cambiado(cantidad: int)


func configurar_dependencias(
	inventory: GarliaInventory = null,
	player: Player = null,
	world_context: WorldContext = null,
	world_atmosphere: WorldAtmosphere = null,
	mission_manager: MissionManagerService = null,
	world_data: WorldDataService = null
) -> void:
	_inventory = inventory
	if _player != player:
		_esperando_configuracion_eterium_jugador = false
		_estado_vital_restaurado_en_escena = false
		_espera_restauracion_vital_elapsed = 0.0
	_player = player
	_world_context = world_context
	_world_atmosphere = world_atmosphere
	_mission_manager = mission_manager
	_world_data = world_data

	if active_save_id.is_empty() and not _historia_reserva_activa:
		return

	_guardado_rapido_conectado = false
	_conectar_guardado_rapido()
	_primer_guardado_pendiente = true
	_primer_guardado_elapsed = 0.0
	call_deferred("_revisar_escena_actual")
	# El primer intento puede coincidir con la restauración vital asíncrona.
	# Se mantiene pendiente y se reintenta hasta que el runtime sea guardable.
	call_deferred("_guardar_progreso_diferido")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	save_repository.configurar(SAVE_DIRECTORY)
	save_repository.asegurar_directorio()
	story_save_repository.configurar(STORY_SAVE_DIRECTORY)
	story_save_repository.asegurar_directorio()

	get_tree().scene_changed.connect(
		_al_cambiar_escena
	)

	call_deferred("_revisar_escena_actual")



func _process(delta: float) -> void:
	# Diagnóstico temporal de congelaciones: sólo registra frames anormalmente largos.
	# No realiza escaneos, asignaciones ni consultas adicionales en cada frame.
	if delta >= 0.20:
		push_warning(
			"PERF_FRAME: pausa/frame largo → %.0f ms | escena=%s | nodos=%d | objetos=%d"
			% [
				delta * 1000.0,
				str(get_tree().current_scene.scene_file_path) if is_instance_valid(get_tree().current_scene) else "<sin escena>",
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_COUNT)
			]
		)
	if not _hay_runtime_partida_activo():
		if (_historia_reserva_activa or not active_save_id.is_empty()) and not _runtime_no_detectado_reportado:
			var escena := get_tree().current_scene
			push_warning(
				"GameState: hay una partida activa, pero el runtime no se detectó; "
				+ "escena=" + str(escena.scene_file_path if is_instance_valid(escena) else "<sin escena>")
				+ ", jugador_valido=" + str(is_instance_valid(_player))
			)
			_runtime_no_detectado_reportado = true
		return
	_runtime_no_detectado_reportado = false
	if not get_tree().paused:
		world_state.elapsed_time += delta
	_autosave_timer += delta

	_actualizar_timeout_restauracion_vital(delta)

	if _primer_guardado_pendiente:
		_primer_guardado_elapsed += delta
		if _primer_guardado_elapsed >= 0.5:
			_primer_guardado_elapsed = 0.0
			_guardar_progreso_diferido()

	if _autosave_timer >= AUTOSAVE_INTERVAL:
		print("GameState: autosave solicitado.")
		var guardado := false
		if _historia_reserva_activa:
			guardado = guardar_progreso_historia()
		elif not active_save_id.is_empty():
			guardado = guardar_partida()
		# Si el runtime aún no está listo, reintentar en un segundo en vez de
		# esperar otros diez segundos tras una tentativa que no pudo guardarse.
		_autosave_timer = 0.0 if guardado else maxf(AUTOSAVE_INTERVAL - 1.0, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		print("PERF_FOCUS: ventana perdió el foco")
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		print("PERF_FOCUS: ventana recuperó el foco")
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		guardar_progreso_actual("suspensión de la aplicación")
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var guardado := guardar_progreso_actual("cierre de la aplicación")
		if not guardado and (_historia_reserva_activa or not active_save_id.is_empty()):
			push_error("GameState: no se pudo confirmar el guardado al cerrar. Motivo: " + _ultimo_motivo_fallo_guardado)
		# Desactivar el cierre automático permite completar la escritura síncrona.
		get_tree().quit()


func guardar_progreso_actual(motivo: String = "guardado manual") -> bool:
	var escena_log := get_tree().current_scene
	print(
		"GameState: solicitud de guardado → ", motivo,
		" | escena=", escena_log.scene_file_path if is_instance_valid(escena_log) else "<sin escena>",
		" | runtime=", _hay_runtime_partida_activo(),
		" | save_id=", active_save_id,
		" | jugador_valido=", is_instance_valid(_player)
	)
	# El menú principal no es una sesión jugable. La sesión ya se confirma
	# antes de abandonar Main; no intentes capturar un Player que ya fue liberado.
	if not _hay_runtime_partida_activo():
		if _historia_reserva_activa or not active_save_id.is_empty():
			return _rechazar_guardado(
				"hay una partida activa, pero no se reconoce el runtime. Escena: "
				+ str(get_tree().current_scene.scene_file_path if is_instance_valid(get_tree().current_scene) else "<sin escena>")
			)
		return true
	print("GameState: solicitando guardado → ", motivo)
	var resultado := true
	if _historia_reserva_activa:
		resultado = guardar_progreso_historia()
	elif not active_save_id.is_empty():
		resultado = guardar_partida()
	if not resultado and (_historia_reserva_activa or not active_save_id.is_empty()):
		push_error("GameState: guardado fallido (" + motivo + "). " + _ultimo_motivo_fallo_guardado)
	return resultado


func _hay_runtime_partida_activo() -> bool:
	var escena := get_tree().current_scene
	if not is_instance_valid(escena):
		return false
	if str(escena.scene_file_path) == MAIN_SCENE_PATH:
		return true
	# Main puede estar dentro de una escena contenedora (por ejemplo, un
	# runtime integrado). Buscar ZoneManager de forma recursiva evita que
	# el guardado confunda esa sesión con el menú principal.
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	if not escena.is_ancestor_of(_player):
		return false
	return is_instance_valid(escena.find_child("ZoneManager", true, false))


func _rechazar_guardado(motivo: String) -> bool:
	if _ultimo_motivo_fallo_guardado != motivo:
		push_warning("GameState: guardado rechazado: " + motivo)
	else:
		print("GameState: guardado sigue rechazado → ", motivo)
	_ultimo_motivo_fallo_guardado = motivo
	return false


# ============================================================
# HISTORIA
# ============================================================

func historia_reserva_tiene_progreso() -> bool:
	var datos := story_save_repository.leer_partida(STORY_SAVE_ID)
	return not datos.is_empty() and datos.get("estado", {}) is Dictionary


func preparar_historia_reserva_carmesi(nueva: bool = false) -> bool:
	# Si se llega desde una partida normal, conservarla antes de cambiar el
	# estado en memoria. Historia utiliza un archivo independiente.
	if not active_save_id.is_empty() and not _historia_reserva_activa:
		guardar_partida()

	_historia_reserva_activa = true
	_historia_requiere_aplicar = false
	_guardado_rapido_conectado = false
	_partida_aplicada_en_escena = false
	_estado_vital_restaurado_en_escena = false
	_espera_restauracion_vital_elapsed = 0.0
	_autosave_timer = 0.0

	# Una llamada de inicio nueva nunca debe borrar silenciosamente una partida
	# narrativa existente. Si ya hay progreso, prevalece la reanudación.
	var iniciar_nueva := nueva and not historia_reserva_tiene_progreso()
	if iniciar_nueva:
		player_state = PlayerState.new()
		world_state = WorldState.new()
		discovery_state = DiscoveryState.new()
	else:
		var datos := story_save_repository.leer_partida(STORY_SAVE_ID)
		var estado_variant: Variant = datos.get("estado", {})
		if estado_variant is Dictionary:
			_aplicar_estado_memoria(estado_variant as Dictionary)
			_historia_requiere_aplicar = true
		else:
			# Si el archivo no existe o está dañado, iniciar una partida narrativa
			# limpia en lugar de heredar accidentalmente el estado de Aventura.
			player_state = PlayerState.new()
			world_state = WorldState.new()
			discovery_state = DiscoveryState.new()

	world_state.flags["historia_iniciar_reserva_carmesi"] = true
	return true


func guardar_progreso_historia() -> bool:
	if not _historia_reserva_activa:
		return _rechazar_guardado("la sesión narrativa no está activa")
	if _guardado_en_curso:
		return _rechazar_guardado("ya hay una escritura en curso")
	if _historia_requiere_aplicar:
		return _rechazar_guardado("el snapshot anterior aún no se ha restaurado")
	if _partida_aplicada_en_escena and not _estado_vital_restaurado_en_escena:
		return _rechazar_guardado("el estado vital del jugador aún se está restaurando")
	var jugador: Player = _player
	if jugador == null or not is_instance_valid(jugador):
		return _rechazar_guardado("el jugador todavía no está conectado a GameState")
	if jugador.get("is_alive") == false:
		return _rechazar_guardado("el jugador está en estado de muerte")
	var escena := get_tree().current_scene
	if not is_instance_valid(escena):
		return _rechazar_guardado("no hay una escena activa")
	var zone_manager := escena.get_node_or_null("World/ZoneManager")
	if not is_instance_valid(zone_manager) or not zone_manager.has_method("obtener_tipo_actual"):
		return _rechazar_guardado("la escena activa no contiene un ZoneManager listo")
	var tipo_zona_actual := str(zone_manager.call("obtener_tipo_actual")).strip_edges()
	if tipo_zona_actual.is_empty():
		return _rechazar_guardado("el ZoneManager todavía no ha establecido una zona activa")

	_guardado_en_curso = true
	capturar_estado_desde_juego(jugador)
	_sincronizar_garumis_vinculados_desde_escena()
	var datos := {
		"version": 1,
		"id": STORY_SAVE_ID,
		"nombre": "La Reserva Carmesí",
		"actualizado_en": _ahora(),
		"estado": _serializar_estado()
	}
	var resultado := story_save_repository.escribir_partida(STORY_SAVE_ID, datos)
	_guardado_en_curso = false
	if resultado:
		_active_save_header = datos.duplicate(false)
		_active_save_header.erase("estado")
		_ultimo_motivo_fallo_guardado = ""
		_primer_guardado_pendiente = false
		print("GameState: progreso de Historia guardado → La Reserva Carmesí")
	else:
		_rechazar_guardado("el repositorio no pudo escribir historia/reserva_carmesi.json")
	return resultado


# ============================================================
# PARTIDAS
# ============================================================

func precalentar_indice_metadata_partidas() -> void:
	if _partidas_metadata_cache_valida:
		return
	if _partidas_metadata_precalentando:
		await partidas_metadata_precalentadas
		return
	_partidas_metadata_precalentando = true
	var inicio_ms := Time.get_ticks_msec()
	var ids := save_repository.listar_ids_partidas()
	var indice := _leer_indice_metadata_partidas()
	if _indice_metadata_coincide_con_ids(indice, ids):
		_partidas_metadata_cache = indice
	else:
		var resultado: Array[Dictionary] = []
		for i in range(ids.size()):
			var id := ids[i]
			var datos := save_repository.leer_metadata_partida(id)
			if _datos_partida_cargables(id, datos):
				resultado.append(_extraer_metadata_partida(datos))
			# Repartir la lectura de saves entre frames: el menú permanece
			# interactivo mientras se prepara el índice inicial.
			if i % 2 == 1:
				await get_tree().process_frame
		_ordenar_metadata_partidas(resultado)
		_partidas_metadata_cache = resultado
		_guardar_indice_metadata_partidas(resultado)
	_partidas_metadata_cache_valida = true
	_partidas_metadata_precalentando = false
	print("GameState: precalentamiento de partidas → ", _partidas_metadata_cache.size(), " | ", Time.get_ticks_msec() - inicio_ms, " ms")
	partidas_metadata_precalentadas.emit()


func obtener_partidas() -> Array[Dictionary]:
	var inicio_ms := Time.get_ticks_msec()
	if _partidas_metadata_cache_valida:
		print("GameState: metadatos de partidas desde RAM → ", _partidas_metadata_cache.size(), " | ", Time.get_ticks_msec() - inicio_ms, " ms")
		return _partidas_metadata_cache.duplicate(true)

	var ids := save_repository.listar_ids_partidas()
	var indice := _leer_indice_metadata_partidas()
	if _indice_metadata_coincide_con_ids(indice, ids):
		_partidas_metadata_cache = indice
		_partidas_metadata_cache_valida = true
		print("GameState: metadatos de partidas desde índice → ", indice.size(), " | ", Time.get_ticks_msec() - inicio_ms, " ms")
		return _partidas_metadata_cache.duplicate(true)

	# Primera ejecución tras incorporar el índice, o si cambió el conjunto de
	# archivos fuera de GameState: construirlo una vez y reutilizarlo después.
	var resultado: Array[Dictionary] = []
	for id in ids:
		var datos := save_repository.leer_metadata_partida(id)
		if not _datos_partida_cargables(id, datos):
			continue
		resultado.append(_extraer_metadata_partida(datos))

	_ordenar_metadata_partidas(resultado)
	_partidas_metadata_cache = resultado.duplicate(true)
	_partidas_metadata_cache_valida = true
	_guardar_indice_metadata_partidas(resultado)
	print("GameState: índice de metadatos reconstruido → ", resultado.size(), " partidas | ", Time.get_ticks_msec() - inicio_ms, " ms")
	return resultado


func _leer_indice_metadata_partidas() -> Array[Dictionary]:
	if not FileAccess.file_exists("user://partidas_index.json"):
		return []
	var archivo := FileAccess.open("user://partidas_index.json", FileAccess.READ)
	if archivo == null:
		return []
	var parser := JSON.new()
	var error := parser.parse(archivo.get_as_text())
	archivo.close()
	if error != OK or not parser.data is Dictionary:
		return []
	var partidas_variant: Variant = (parser.data as Dictionary).get("partidas", [])
	if not partidas_variant is Array:
		return []
	var resultado: Array[Dictionary] = []
	for entrada in partidas_variant:
		if not entrada is Dictionary:
			return []
		var metadata := (entrada as Dictionary).duplicate(true)
		var id := str(metadata.get("id", ""))
		if id.is_empty() or not metadata.has("nombre"):
			return []
		resultado.append(metadata)
	return resultado


func _indice_metadata_coincide_con_ids(indice: Array[Dictionary], ids: Array[String]) -> bool:
	if indice.size() != ids.size():
		return false
	var ids_indice: Dictionary = {}
	for metadata in indice:
		ids_indice[str(metadata.get("id", ""))] = true
	for id in ids:
		if not ids_indice.has(id):
			return false
	return true


func _ordenar_metadata_partidas(partidas: Array[Dictionary]) -> void:
	partidas.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("actualizado_en", "")) > str(b.get("actualizado_en", ""))
	)


func _guardar_indice_metadata_partidas(partidas: Array[Dictionary]) -> void:
	var archivo := FileAccess.open("user://partidas_index.json.tmp", FileAccess.WRITE)
	if archivo == null:
		push_warning("GameState: no se pudo escribir el índice de metadatos de partidas.")
		return
	archivo.store_string(JSON.stringify({"version": 1, "partidas": partidas}))
	archivo.close()
	var temporal := ProjectSettings.globalize_path("user://partidas_index.json.tmp")
	var destino := ProjectSettings.globalize_path("user://partidas_index.json")
	if FileAccess.file_exists("user://partidas_index.json"):
		DirAccess.remove_absolute(destino)
	var error := DirAccess.rename_absolute(temporal, destino)
	if error != OK:
		push_warning("GameState: no se pudo confirmar el índice de metadatos (error %d)." % error)


func _actualizar_indice_metadata_partida(id: String, datos: Dictionary) -> void:
	var metadata := _extraer_metadata_partida(datos)
	if _partidas_metadata_cache_valida:
		var encontrada := false
		for i in range(_partidas_metadata_cache.size()):
			if str(_partidas_metadata_cache[i].get("id", "")) == id:
				_partidas_metadata_cache[i] = metadata
				encontrada = true
				break
		if not encontrada:
			_partidas_metadata_cache.append(metadata)
		_ordenar_metadata_partidas(_partidas_metadata_cache)
		_guardar_indice_metadata_partidas(_partidas_metadata_cache)
		return

	var indice := _leer_indice_metadata_partidas()
	if indice.is_empty():
		indice.append(metadata)
	else:
		var encontrada := false
		for i in range(indice.size()):
			if str(indice[i].get("id", "")) == id:
				indice[i] = metadata
				encontrada = true
				break
		if not encontrada:
			indice.append(metadata)
	_ordenar_metadata_partidas(indice)
	_guardar_indice_metadata_partidas(indice)


func crear_partida(
	nombre: String,
	semilla_texto: String = "",
	personaje: Dictionary = {}
) -> String:
	var nombre_limpio := nombre.strip_edges()

	if nombre_limpio.is_empty():
		nombre_limpio = _nombre_partida_por_defecto()

	var ahora := Time.get_datetime_string_from_system(
		true
	)

	var semilla: int
	if semilla_texto.strip_edges().is_empty():
		semilla = _generar_semilla_mundo()
	else:
		if not _texto_es_semilla_valida(semilla_texto):
			print(
				"GameState: semilla inválida → ",
				semilla_texto
			)
			return ""
		semilla = int(semilla_texto.strip_edges())

	var id := "save_" + str(
		Time.get_unix_time_from_system()
	).replace(".", "_") + "_" + str(
		randi_range(1000, 9999)
	)

	var datos := _estado_base_partida(
		id,
		nombre_limpio,
		ahora,
		ahora,
		semilla,
		personaje
	)

	if not _escribir_archivo_partida(id, datos):
		return ""

	print(
		"GameState: partida creada → ",
		nombre_limpio,
		" [",
		id,
		"]"
	)

	return id


func iniciar_partida(id: String) -> bool:
	var datos_originales := _leer_archivo_partida(id)
	var datos := _migrar_datos_partida(id, datos_originales)

	if datos.is_empty():
		push_warning("GameState: partida ausente, incompatible o con estructura inválida → " + id)
		return false

	_historia_reserva_activa = false
	_historia_requiere_aplicar = false
	_guardado_rapido_conectado = false
	var metadata := _extraer_metadata_partida(datos)

	var mundo: Dictionary = datos.get("mundo", {}) as Dictionary
	world_state.world_seed = int(mundo.get("semilla", 0))
	world_state.world_seed_valida = true
	if datos != datos_originales:
		if not _escribir_archivo_partida(id, datos):
			push_warning("GameState: no se pudo persistir la migración; la partida se abrirá con los datos normalizados.")

	active_save_id = id
	# Conserva campos superiores desconocidos por compatibilidad, sin retener
	# ni duplicar el bloque grande "estado" en cada guardado.
	_active_save_header = datos.duplicate(false)
	_active_save_header.erase("estado")
	active_save_name = str(
		metadata.get(
			"nombre",
			"Partida"
		)
	)

	var estado_variant: Variant = datos.get(
		"estado",
		{}
	)

	if estado_variant is Dictionary:
		_aplicar_estado_memoria(
			estado_variant as Dictionary
		)

	world_state.current_scene = MAIN_SCENE_PATH
	_partida_aplicada_en_escena = false
	_estado_vital_restaurado_en_escena = false
	_autosave_timer = 0.0

	_abrir_escena_principal()

	return true


## Sincroniza únicamente la zona de entrada del mundo global en el save local.
## El estado de personaje, inventario y progreso privado permanece local.
func establecer_zona_mundo_global(id: String, tipo_zona: String, reinos_globales: Dictionary = {}, tiempo_mundo: Dictionary = {}) -> bool:
	var tipo := tipo_zona.strip_edges()
	if id.is_empty() or tipo.is_empty():
		return false
	var datos := _leer_archivo_partida(id)
	if datos.is_empty():
		return false
	var estado_variant: Variant = datos.get("estado", {})
	var estado: Dictionary = estado_variant as Dictionary if estado_variant is Dictionary else {}
	var flags_variant: Variant = estado.get("flags", {})
	var flags: Dictionary = (flags_variant as Dictionary).duplicate(true) if flags_variant is Dictionary else {}
	flags["zona_actual_tipo"] = tipo
	if not reinos_globales.is_empty():
		var desbloqueados := {"torres": true}
		for clave_variant in reinos_globales.keys():
			var clave := str(clave_variant).strip_edges().to_lower()
			if not clave.is_empty() and bool(reinos_globales.get(clave_variant, false)):
				desbloqueados[clave] = true
		flags["reinos_desbloqueados"] = desbloqueados
	if not tiempo_mundo.is_empty():
		flags["tiempo_mundo"] = tiempo_mundo.duplicate(true)
	estado["flags"] = flags
	datos["estado"] = estado
	datos["actualizado_en"] = _ahora()
	return _escribir_archivo_partida(id, datos)


func eliminar_partida(id: String) -> bool:
	if not save_repository.eliminar_partida(id):
		return false
	if _partidas_metadata_cache_valida:
		_partidas_metadata_cache = _partidas_metadata_cache.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) != id)
		_guardar_indice_metadata_partidas(_partidas_metadata_cache)
	else:
		var indice := _leer_indice_metadata_partidas()
		if not indice.is_empty():
			indice = indice.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) != id)
			_guardar_indice_metadata_partidas(indice)

	if active_save_id == id:
		active_save_id = ""
		active_save_name = ""

	return true


func renombrar_partida(
	id: String,
	nuevo_nombre: String
) -> bool:
	var datos := _leer_archivo_partida(id)

	if datos.is_empty():
		return false

	var nombre_limpio := nuevo_nombre.strip_edges()

	if nombre_limpio.is_empty():
		return false

	datos["nombre"] = nombre_limpio
	datos["actualizado_en"] = _ahora()

	return _escribir_archivo_partida(
		id,
		datos
	)


func obtener_datos_edicion_partida(id: String) -> Dictionary:
	var datos := _leer_archivo_partida(id)
	if datos.is_empty():
		return {}
	var estado: Dictionary = {}
	var estado_variant: Variant = datos.get("estado", {})
	if estado_variant is Dictionary:
		estado = estado_variant as Dictionary
	var flags: Dictionary = {}
	var flags_variant: Variant = estado.get("flags", {})
	if flags_variant is Dictionary:
		flags = flags_variant as Dictionary
	var personaje: Dictionary = {}
	var personaje_variant: Variant = flags.get("personaje", {})
	if personaje_variant is Dictionary:
		personaje = (personaje_variant as Dictionary).duplicate(true)
	var mundo: Dictionary = {}
	var mundo_variant: Variant = datos.get("mundo", {})
	if mundo_variant is Dictionary:
		mundo = mundo_variant as Dictionary
	return {
		"id": id,
		"nombre_mundo": str(datos.get("nombre", "Partida")),
		"semilla": str(mundo.get("semilla", "—")),
		"personaje": personaje
	}


func actualizar_personaje_partida(
	id: String,
	nuevo_nombre_mundo: String,
	nombre_personaje: String,
	genero: String,
	skin_path: String
) -> bool:
	var datos := _leer_archivo_partida(id)
	if datos.is_empty():
		return false
	var mundo_limpio := nuevo_nombre_mundo.strip_edges()
	var personaje_limpio := nombre_personaje.strip_edges()
	if mundo_limpio.is_empty() or personaje_limpio.is_empty():
		return false

	var estado: Dictionary = {}
	var estado_variant: Variant = datos.get("estado", {})
	if estado_variant is Dictionary:
		estado = (estado_variant as Dictionary).duplicate(true)
	var flags: Dictionary = {}
	var flags_variant: Variant = estado.get("flags", {})
	if flags_variant is Dictionary:
		flags = (flags_variant as Dictionary).duplicate(true)
	var personaje: Dictionary = {}
	var personaje_variant: Variant = flags.get("personaje", {})
	if personaje_variant is Dictionary:
		personaje = (personaje_variant as Dictionary).duplicate(true)
	if personaje.is_empty():
		return false

	# La especie y la semilla nunca se toman desde el formulario: se conserva
	# la información existente y solo se modifican los campos permitidos.
	personaje["nombre"] = personaje_limpio
	personaje["genero"] = genero.strip_edges()
	if not skin_path.strip_edges().is_empty():
		personaje["skin"] = skin_path
		personaje["skin_nombre"] = skin_path.get_file().get_basename()
	flags["personaje"] = personaje
	estado["flags"] = flags
	datos["estado"] = estado
	datos["nombre"] = mundo_limpio
	datos["actualizado_en"] = _ahora()
	if not _escribir_archivo_partida(id, datos):
		return false
	if active_save_id == id:
		active_save_name = mundo_limpio
		world_state.flags["personaje"] = personaje.duplicate(true)
	return true


# ============================================================
# GUARDADO
# ============================================================

func guardar_partida() -> bool:
	if _historia_reserva_activa:
		return _rechazar_guardado("la sesión activa usa el archivo narrativo, no una partida normal")
	if _guardado_en_curso:
		return _rechazar_guardado("ya hay una escritura en curso")
	if _partida_aplicada_en_escena and not _estado_vital_restaurado_en_escena:
		return _rechazar_guardado("el estado vital del jugador aún se está restaurando")
	if active_save_id.is_empty():
		return _rechazar_guardado("no hay un identificador de partida activa")
	var jugador: Player = _player
	if jugador == null or not is_instance_valid(jugador):
		return _rechazar_guardado("el jugador todavía no está conectado a GameState")
	if jugador.get("is_alive") == false:
		return _rechazar_guardado("el jugador está en estado de muerte")
	if get_tree().current_scene == null:
		return _rechazar_guardado("no hay una escena activa")

	_guardado_en_curso = true
	var diagnostico_inicio_usec := Time.get_ticks_usec()

	capturar_estado_desde_juego(jugador)
	var captura_ms := float(Time.get_ticks_usec() - diagnostico_inicio_usec) / 1000.0
	_sincronizar_garumis_vinculados_desde_escena()

	# La cabecera se carga y valida al iniciar_partida(). Releer el JSON
	# completo aquí hacía una lectura + parseo + copia profunda en cada autosave.
	if _active_save_header.is_empty():
		_guardado_en_curso = false
		return _rechazar_guardado("no hay cabecera validada para la partida activa: " + active_save_id)
	var datos := _active_save_header.duplicate(false)
	datos["version"] = SAVE_VERSION
	datos["id"] = active_save_id
	datos["nombre"] = active_save_name
	datos["actualizado_en"] = _ahora()
	datos["mundo"] = {
		"semilla": world_state.world_seed,
		"generador_version": 1
	}
	var lectura_ms := float(Time.get_ticks_usec() - diagnostico_inicio_usec) / 1000.0 - captura_ms
	var serializacion_inicio_usec := Time.get_ticks_usec()
	datos["estado"] = _serializar_estado()
	var serializacion_ms := float(Time.get_ticks_usec() - serializacion_inicio_usec) / 1000.0

	var escritura_inicio_usec := Time.get_ticks_usec()
	var resultado := _escribir_archivo_partida(
		active_save_id,
		datos
	)
	var escritura_ms := float(Time.get_ticks_usec() - escritura_inicio_usec) / 1000.0
	var total_ms := float(Time.get_ticks_usec() - diagnostico_inicio_usec) / 1000.0
	if total_ms >= 80.0:
		push_warning(
			"PERF_SAVE: total=%.1f ms | captura=%.1f ms | lectura=%.1f ms | serializacion=%.1f ms | escritura_validacion=%.1f ms | resultado=%s"
			% [total_ms, captura_ms, lectura_ms, serializacion_ms, escritura_ms, str(resultado)]
		)

	_guardado_en_curso = false

	if resultado:
		_active_save_header = datos.duplicate(false)
		_active_save_header.erase("estado")
		_ultimo_motivo_fallo_guardado = ""
		_primer_guardado_pendiente = false
		print(
			"GameState: partida guardada → ",
			active_save_name
		)
	else:
		_rechazar_guardado("el repositorio no pudo escribir partidas/" + active_save_id + ".json")

	return resultado


## Local worlds keep their runtime entity deltas in the private save.
func capturar_estado_entidades_mundo_local(zona_tipo: String, entity_manager: Node) -> bool:
	var tipo := zona_tipo.strip_edges()
	if tipo.is_empty() or not is_instance_valid(entity_manager):
		return false
	if not entity_manager.has_method("capturar_estado_persistente_mundo"):
		return false
	var estado_variant: Variant = entity_manager.call("capturar_estado_persistente_mundo")
	if not estado_variant is Dictionary:
		return false
	var por_zona_variant: Variant = world_state.flags.get("entidades_mundo_local_por_zona", {})
	var por_zona: Dictionary = (por_zona_variant as Dictionary).duplicate(true) if por_zona_variant is Dictionary else {}
	por_zona[tipo] = _serializar_variante_guardado(estado_variant as Dictionary)
	world_state.flags["entidades_mundo_local_por_zona"] = por_zona
	return true


func obtener_estado_entidades_mundo_local(zona_tipo: String) -> Dictionary:
	var por_zona_variant: Variant = world_state.flags.get("entidades_mundo_local_por_zona", {})
	if not por_zona_variant is Dictionary:
		return {}
	var estado_variant: Variant = (por_zona_variant as Dictionary).get(zona_tipo.strip_edges(), {})
	if not estado_variant is Dictionary:
		return {}
	var decodificado: Variant = _deserializar_variante_guardado(estado_variant)
	return decodificado as Dictionary if decodificado is Dictionary else {}


func _serializar_variante_guardado(valor: Variant) -> Variant:
	if valor is Vector2:
		var vector := valor as Vector2
		return {"__garlia_type": "Vector2", "x": vector.x, "y": vector.y}
	if valor is Vector2i:
		var vector_i := valor as Vector2i
		return {"__garlia_type": "Vector2i", "x": vector_i.x, "y": vector_i.y}
	if valor is Array:
		var resultado: Array = []
		for elemento in valor as Array:
			resultado.append(_serializar_variante_guardado(elemento))
		return resultado
	if valor is Dictionary:
		var resultado: Dictionary = {}
		for clave in (valor as Dictionary).keys():
			resultado[str(clave)] = _serializar_variante_guardado((valor as Dictionary)[clave])
		return resultado
	return valor


func _deserializar_variante_guardado(valor: Variant) -> Variant:
	if valor is Array:
		var resultado: Array = []
		for elemento in valor as Array:
			resultado.append(_deserializar_variante_guardado(elemento))
		return resultado
	if valor is Dictionary:
		var diccionario := valor as Dictionary
		match str(diccionario.get("__garlia_type", "")):
			"Vector2":
				return Vector2(float(diccionario.get("x", 0.0)), float(diccionario.get("y", 0.0)))
			"Vector2i":
				return Vector2i(int(diccionario.get("x", 0)), int(diccionario.get("y", 0)))
		var resultado: Dictionary = {}
		for clave in diccionario.keys():
			resultado[str(clave)] = _deserializar_variante_guardado(diccionario[clave])
		return resultado
	return valor


func capturar_estado_desde_juego(jugador: Player) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return

	player_state.health = int(jugador.get("health"))
	player_state.mana = int(jugador.get("mana"))
	var reservas_capturadas := player_state.normalizar_reservas_vitales(
		int(jugador.get("max_health")),
		int(jugador.get("max_mana")),
		jugador.eterium.vida_eterium_compartidos()
	)
	player_state.health = int(reservas_capturadas.get("health", 0))
	player_state.mana = int(reservas_capturadas.get("mana", 0))

	player_state.position = jugador.global_position
	player_state.position_valida = true
	player_state.tile_valido = false

	# Persistir también la zona activa y el estado del interior, no solo
	# las coordenadas globales del jugador.
	var escena_actual := get_tree().current_scene
	if is_instance_valid(escena_actual):
		var zone_manager := escena_actual.get_node_or_null("World/ZoneManager")
		if is_instance_valid(zone_manager):
			var tipo_zona := str(zone_manager.call("obtener_tipo_actual"))
			world_state.flags["zona_actual_tipo"] = tipo_zona
			var zona := zone_manager.call("obtener_zona_actual") as Node
			if not GarliaMultiplayer.es_servidor_dedicado() and not GarliaWorldNetwork.es_cliente_en_mundo_global():
				var world_generator: WorldGenerator = zone_manager.call("obtener_world_generator") as WorldGenerator
				if is_instance_valid(world_generator) and is_instance_valid(world_generator.entity_manager):
					capturar_estado_entidades_mundo_local(tipo_zona, world_generator.entity_manager)
			if is_instance_valid(zona) and zona.has_method("obtener_estado_guardado"):
				var estado_zona_variant: Variant = zona.call("obtener_estado_guardado")
				if estado_zona_variant is Dictionary:
					var estado_zona := (estado_zona_variant as Dictionary).duplicate(true)
					world_state.flags["estado_zona_actual"] = estado_zona
					# HogarZone actualiza su posición en segundo plano cada 0.35 s.
					# Un guardado manual/cierre puede ocurrir antes de ese tick;
					# sincronizarla aquí evita reanudar en una posición antigua.
					if tipo_zona == "hogar":
						estado_zona["jugador"] = {
							"x": jugador.global_position.x,
							"y": jugador.global_position.y
						}
						world_state.flags["hogar_estado"] = estado_zona.duplicate(true)
				else:
					world_state.flags.erase("estado_zona_actual")
			else:
				world_state.flags.erase("estado_zona_actual")

	var world_context: WorldContext = _world_context

	if world_context != null:
		player_state.tile = world_context.get_tile_at(player_state.position)
		player_state.tile_valido = true

	var stamina_variant: Variant = jugador.get(
		"stamina"
	)

	if stamina_variant != null:
		player_state.stamina = float(stamina_variant)

	var facing_variant: Variant = jugador.get(
		"facing"
	)

	if facing_variant is Vector2:
		player_state.facing = facing_variant as Vector2

	var player_flags: Dictionary = jugador.obtener_estado_ium()
	world_state.flags["proceso_ium_equipado"] = player_flags.duplicate(true)


	var atmosphere: WorldAtmosphere = _world_atmosphere
	if atmosphere != null:
		world_state.flags["tiempo_mundo"] = atmosphere.obtener_estado_guardado().duplicate(true)

	var inventario: GarliaInventory = _inventory

	if inventario != null and is_instance_valid(inventario):
		var estado_inventario: Dictionary = {}
		estado_inventario = inventario.serializar_estado_partida().duplicate(true)

		var rol_partida := "explorador"
		var admin_variant: Variant = world_state.flags.get("personaje_admin", {})
		if admin_variant is Dictionary:
			rol_partida = str(
				(admin_variant as Dictionary).get("rol", "explorador")
			).to_lower()

		estado_inventario["rol_partida"] = rol_partida
		world_state.flags["inventario_estado"] = estado_inventario

	_capturar_estado_misiones()


func _capturar_estado_misiones() -> void:
	if _mission_manager == null or not is_instance_valid(_mission_manager):
		return
	world_state.flags["misiones_estado"] = _mission_manager.serializar_estado_partida()


func _aplicar_estado_misiones() -> void:
	if _mission_manager == null or not is_instance_valid(_mission_manager):
		return
	var datos_variant: Variant = world_state.flags.get("misiones_estado", {})
	if datos_variant is Dictionary:
		_mission_manager.cargar_estado_partida((datos_variant as Dictionary).duplicate(true))


func _conectar_guardado_rapido() -> void:
	if _guardado_rapido_conectado or (active_save_id.is_empty() and not _historia_reserva_activa):
		return

	var inventario: GarliaInventory = _inventory
	if inventario != null and inventario.has_signal("inventory_changed"):
		var inventario_callback := Callable(self, "_al_cambio_guardable")
		if not inventario.inventory_changed.is_connected(inventario_callback):
			inventario.inventory_changed.connect(inventario_callback)

	for nombre in ["mision_aceptada", "progreso_actualizado", "mision_completada"]:
		if _mission_manager == null or not _mission_manager.has_signal(nombre):
			continue
		var callback := Callable(self, "_al_cambio_guardable")
		var senal: Signal = _mission_manager.get(nombre)
		if not senal.is_connected(callback):
			senal.connect(callback)

	if not enciclopedia_actualizada.is_connected(_al_cambio_guardable):
		enciclopedia_actualizada.connect(_al_cambio_guardable)
	if not descubrimientos_mundo_actualizados.is_connected(_al_cambio_guardable):
		descubrimientos_mundo_actualizados.connect(_al_cambio_guardable)

	_guardado_rapido_conectado = true


func _al_cambio_guardable(_a = null, _b = null, _c = null, _d = null) -> void:
	if active_save_id.is_empty() and not _historia_reserva_activa:
		return
	if _guardado_rapido_pendiente:
		return
	_guardado_rapido_pendiente = true
	call_deferred("_ejecutar_guardado_rapido")


func _ejecutar_guardado_rapido() -> void:
	# Agrupa varios cambios consecutivos (inventario, misiones, vínculos, etc.)
	# en una sola escritura. Antes cada señal disparaba un guardado síncrono.
	await get_tree().create_timer(GUARDADO_RAPIDO_ESPERA_S).timeout
	_guardado_rapido_pendiente = false
	if _historia_reserva_activa:
		guardar_progreso_historia()
	elif not active_save_id.is_empty():
		guardar_partida()


func _guardar_progreso_diferido() -> void:
	if not _hay_runtime_partida_activo():
		_primer_guardado_pendiente = false
		return
	# Nunca escribir encima de un snapshot que todavía está pendiente de
	# aplicarse al Player real. Los intentos se repiten mientras la escena termina
	# de conectar al jugador y restaurar su estado vital.
	if _historia_reserva_activa:
		if _historia_requiere_aplicar:
			return
		if _partida_aplicada_en_escena and not _estado_vital_restaurado_en_escena:
			return
		guardar_progreso_historia()
		return
	if active_save_id.is_empty():
		_primer_guardado_pendiente = false
		return
	if not _partida_aplicada_en_escena or not _estado_vital_restaurado_en_escena:
		return
	guardar_partida()


func _serializar_estado() -> Dictionary:
	_sincronizar_descubrimientos()
	return {
		"player": player_state.to_dictionary(),
		"elapsed_time": world_state.elapsed_time,
		"flags": world_state.flags.duplicate(true),
		"scene": world_state.current_scene
	}

func _estado_base_partida(
	id: String,
	nombre: String,
	creado_en: String,
	actualizado_en: String,
	semilla: int,
	personaje: Dictionary = {}
) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"id": id,
		"nombre": nombre,
		"creado_en": creado_en,
		"actualizado_en": actualizado_en,
		"mundo_version": _obtener_version_mundo(),
		"mundo": {
			"semilla": semilla,
			"generador_version": 1
		},
		"estado": {
			"player": PlayerState.new().to_dictionary(),
			"elapsed_time": 0.0,
			"flags": {
				"personaje": personaje.duplicate(true)
			} if not personaje.is_empty() else {},
			"scene": "res://scenes/world/main.tscn"
		}
	}


func _aplicar_estado_memoria(
	estado: Dictionary
) -> void:
	var player_variant: Variant = estado.get("player", {})
	if player_variant is Dictionary:
		player_state.from_dictionary(player_variant as Dictionary)
	else:
		player_state = PlayerState.new()

	world_state.elapsed_time = float(
		estado.get("elapsed_time", 0.0)
	)

	var flags_variant: Variant = estado.get("flags", {})
	if flags_variant is Dictionary:
		world_state.flags = (
			flags_variant as Dictionary
		).duplicate(true)
	else:
		world_state.flags = {}

	var descubrimientos_variant: Variant = world_state.flags.get("descubrimientos_mundo", {})
	var datos_descubrimientos: Dictionary = {}
	if descubrimientos_variant is Dictionary:
		datos_descubrimientos = (descubrimientos_variant as Dictionary).duplicate(true)
	else:
		# Compatibilidad con partidas antiguas que guardaban los registros
		# directamente en flags.
		for clave in ["criaturas", "biomas", "ecosistemas", "habitats"]:
			if world_state.flags.has(clave):
				datos_descubrimientos[clave] = world_state.flags[clave]
	datos_descubrimientos["mapa_terreno_explorado"] = world_state.flags.get("mapa_terreno_explorado", {})
	discovery_state.from_dictionary(datos_descubrimientos)


# ============================================================
# ENCICLOPEDIA
# ============================================================

func registrar_criatura_derrotada(criatura: Node) -> bool:
	if criatura == null or not is_instance_valid(criatura):
		return false

	if not criatura.is_in_group("creatures"):
		return false

	var criatura_id := str(criatura.get("criatura_id"))
	if criatura_id.is_empty() and criatura is Creature:
		criatura_id = (criatura as Creature).get_id()

	if criatura_id.is_empty():
		return false

	var registros_variant: Variant = world_state.flags.get(
		"enciclopedia_criaturas",
		{}
	)

	var registros: Dictionary = {}
	if registros_variant is Dictionary:
		registros = (registros_variant as Dictionary).duplicate(true)

	var derrotas := int(registros.get(criatura_id, 0)) + 1
	registros[criatura_id] = derrotas
	world_state.flags["enciclopedia_criaturas"] = registros

	enciclopedia_actualizada.emit(criatura_id)

	print(
		"GameState: criatura descubierta → ",
		criatura_id,
		" | derrotas = ",
		derrotas
	)

	return true


func registrar_garumi_descubierto(garumi_id: String) -> bool:
	var id := garumi_id.strip_edges()
	if id.is_empty():
		return false
	var registros_variant: Variant = world_state.flags.get("enciclopedia_garumis", {})
	var registros: Dictionary = {}
	if registros_variant is Dictionary:
		registros = (registros_variant as Dictionary).duplicate(true)
	if registros.has(id):
		return false
	registros[id] = true
	world_state.flags["enciclopedia_garumis"] = registros
	enciclopedia_actualizada.emit(id)
	print("GameState: Garumi descubierto → ", id)
	return true


func ha_descubierto_criatura_o_garumi() -> bool:
	# El desbloqueo se conserva en el estado de la partida: no depende de
	# llevar un Garumi vinculado ni de mantener viva a la criatura.
	return (
		not obtener_criaturas_descubiertas().is_empty()
		or not obtener_garumis_descubiertos().is_empty()
		or not discovery_state.creatures.is_empty()
	)


func obtener_garumis_descubiertos() -> Dictionary:
	var registros_variant: Variant = world_state.flags.get("enciclopedia_garumis", {})
	if registros_variant is Dictionary:
		return (registros_variant as Dictionary).duplicate(true)
	return {}


func obtener_criaturas_descubiertas() -> Dictionary:
	var registros_variant: Variant = world_state.flags.get(
		"enciclopedia_criaturas",
		{}
	)

	if registros_variant is Dictionary:
		return (registros_variant as Dictionary).duplicate(true)

	return {}

# ============================================================
# MAPA / EXPLORACION
# ============================================================

func registrar_terreno_explorado(
	tile: Vector2i,
	radio: int = 6
) -> bool:
	var nuevo := false
	var radio_efectivo := maxi(radio, 0)

	for dy in range(-radio_efectivo, radio_efectivo + 1):
		for dx in range(-radio_efectivo, radio_efectivo + 1):
			if (dx * dx + dy * dy) > (
				radio_efectivo * radio_efectivo
			):
				continue

			if discovery_state.explorar(
				tile + Vector2i(dx, dy)
			):
				nuevo = true

	if not nuevo:
		return false

	_sincronizar_descubrimientos()
	mapa_exploracion_actualizada.emit()
	return true


func registrar_descubrimiento_mundo(
	bioma: Dictionary,
	ecosistema: Dictionary,
	habitats: Array,
	criaturas: Array
) -> bool:
	var nuevos: Array[Dictionary] = []

	var bioma_id := str(bioma.get("id", ""))
	if discovery_state.registrar_bioma(bioma_id):
		nuevos.append({"nivel": "bioma", "id": bioma_id})

	var ecosistema_id := str(ecosistema.get("id", ""))
	if discovery_state.registrar_ecosistema(ecosistema_id):
		nuevos.append({"nivel": "ecosistema", "id": ecosistema_id})

	for habitat_variant in habitats:
		if not habitat_variant is Dictionary:
			continue
		var habitat_id := str(
			(habitat_variant as Dictionary).get("id", "")
		)
		if discovery_state.registrar_habitat(habitat_id):
			nuevos.append({"nivel": "habitat", "id": habitat_id})

	for criatura_variant in criaturas:
		if not criatura_variant is Dictionary:
			continue
		var criatura_id := str(
			(criatura_variant as Dictionary).get("id", "")
		)
		if discovery_state.registrar_criatura(criatura_id):
			nuevos.append({"nivel": "criatura", "id": criatura_id})

	if nuevos.is_empty():
		return false

	_sincronizar_descubrimientos()

	for descubrimiento_variant in nuevos:
		if not descubrimiento_variant is Dictionary:
			continue
		var descubrimiento: Dictionary = descubrimiento_variant
		descubrimiento_mundo.emit(
			str(descubrimiento.get("nivel", "")),
			str(descubrimiento.get("id", ""))
		)

	descubrimientos_mundo_actualizados.emit()
	return true


func debe_iniciar_en_reino_torres() -> bool:
	return not bool(world_state.flags.get("reino_torres_visitado", false))


func marcar_reino_torres_visitado() -> void:
	world_state.flags["reino_torres_visitado"] = true
	desbloquear_reino("torres")


## Reinos desbloqueados por esta partida. Torres siempre está disponible.
func obtener_reinos_desbloqueados() -> Dictionary:
	var resultado: Dictionary = {"torres": true}
	var variante: Variant = world_state.flags.get("reinos_desbloqueados", {})
	if variante is Dictionary:
		for clave_variant in (variante as Dictionary).keys():
			var clave := str(clave_variant).strip_edges().to_lower()
			if not clave.is_empty() and bool((variante as Dictionary).get(clave_variant, false)):
				resultado[clave] = true
	return resultado


## Registra el descubrimiento en el guardado local sin modificar el canon de Supabase.
func desbloquear_reino(clave_reino: String) -> bool:
	var clave := clave_reino.strip_edges().to_lower()
	if clave.is_empty():
		return false
	var desbloqueados := obtener_reinos_desbloqueados()
	if bool(desbloqueados.get(clave, false)):
		return false
	desbloqueados[clave] = true
	world_state.flags["reinos_desbloqueados"] = desbloqueados
	print("GameState: reino descubierto → ", clave)
	if not active_save_id.is_empty():
		call_deferred("guardar_partida")
	return true


func obtener_configuracion_personaje() -> Dictionary:
	var personaje_variant: Variant = world_state.flags.get("personaje", {})
	if personaje_variant is Dictionary:
		return (personaje_variant as Dictionary).duplicate(true)
	return {}


func obtener_configuracion_personaje_admin() -> Dictionary:
	var admin_variant: Variant = world_state.flags.get("personaje_admin", {})
	if admin_variant is Dictionary:
		return (admin_variant as Dictionary).duplicate(true)
	return {}


func establecer_configuracion_personaje(personaje: Dictionary) -> void:
	world_state.flags["personaje"] = personaje.duplicate(true)


func establecer_configuracion_personaje_admin(configuracion: Dictionary) -> void:
	world_state.flags["personaje_admin"] = configuracion.duplicate(true)


func obtener_relaciones_sociales() -> Dictionary:
	var relaciones_variant: Variant = world_state.flags.get("relaciones_sociales", {})
	if relaciones_variant is Dictionary:
		return (relaciones_variant as Dictionary).duplicate(true)
	return {}


## Lee la relación jugador-NPC solicitada sin copiar las relaciones de los demás.
func obtener_relacion_social_jugador_npc(personaje_id: String) -> Dictionary:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return {}
	var relaciones_variant: Variant = world_state.flags.get("relaciones_sociales", {})
	if not relaciones_variant is Dictionary:
		return {}
	var relacion_variant: Variant = (relaciones_variant as Dictionary).get(id, {})
	return (relacion_variant as Dictionary).duplicate(true) if relacion_variant is Dictionary else {}


## Actualiza una relación jugador-NPC sin reconstruir el diccionario completo.
func guardar_relacion_social_jugador_npc(personaje_id: String, relacion: Dictionary) -> void:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return
	var relaciones_variant: Variant = world_state.flags.get("relaciones_sociales", {})
	var relaciones: Dictionary = relaciones_variant if relaciones_variant is Dictionary else {}
	var actualizadas := relaciones.duplicate()
	actualizadas[id] = relacion.duplicate(true)
	world_state.flags["relaciones_sociales"] = actualizadas
	_al_cambio_guardable()


func guardar_relaciones_sociales(relaciones: Dictionary) -> void:
	world_state.flags["relaciones_sociales"] = relaciones.duplicate(true)
	_al_cambio_guardable()


## Estado interno, aprendizaje y objetivos persistentes de los habitantes.
func obtener_mentes_npc() -> Dictionary:
	var mentes_variant: Variant = world_state.flags.get("npc_mentes", {})
	if mentes_variant is Dictionary:
		return (mentes_variant as Dictionary).duplicate(true)
	return {}


func guardar_mentes_npc(mentes: Dictionary) -> void:
	world_state.flags["npc_mentes"] = mentes.duplicate(true)
	_al_cambio_guardable()


func _sincronizar_garumis_vinculados_desde_escena() -> void:
	var por_id: Dictionary = {}
	for registro in obtener_garumis_vinculados():
		var id_existente := str(registro.get("garumi_instancia_id", "")).strip_edges()
		if not id_existente.is_empty():
			por_id[id_existente] = registro
	for nodo in get_tree().get_nodes_in_group("garumis"):
		if not is_instance_valid(nodo) or not nodo.has_method("obtener_datos_persistencia_vinculo"):
			continue
		var registro_variant: Variant = nodo.call("obtener_datos_persistencia_vinculo")
		if not registro_variant is Dictionary:
			continue
		var registro := registro_variant as Dictionary
		var id_instancia := str(registro.get("garumi_instancia_id", "")).strip_edges()
		if not id_instancia.is_empty():
			por_id[id_instancia] = registro
	var resultado: Array[Dictionary] = []
	for registro_variant in por_id.values():
		if registro_variant is Dictionary:
			resultado.append((registro_variant as Dictionary).duplicate(true))
	world_state.flags["garumis_vinculados"] = resultado


## Registro persistente de Garumis vinculados a esta partida.
## Se almacena dentro de flags para mantener compatibilidad con el formato JSON actual.
func obtener_garumis_amigos() -> Array[Dictionary]:
	var amigos: Array[Dictionary] = []
	var variant: Variant = world_state.flags.get("garumis_amigos", [])
	if not variant is Array:
		return amigos
	for item in variant as Array:
		if item is Dictionary:
			amigos.append((item as Dictionary).duplicate(true))
	return amigos


func es_garumi_amigo(id_instancia: String) -> bool:
	var id_limpio := id_instancia.strip_edges()
	if id_limpio.is_empty():
		return false
	for amigo in obtener_garumis_amigos():
		if str(amigo.get("garumi_instancia_id", "")) == id_limpio:
			return true
	return false


func guardar_garumi_amigo(datos_garumi: Dictionary) -> bool:
	var id_instancia := str(datos_garumi.get("garumi_instancia_id", "")).strip_edges()
	if id_instancia.is_empty():
		return false
	var lista := obtener_garumis_amigos()
	for i in range(lista.size()):
		if str(lista[i].get("garumi_instancia_id", "")) == id_instancia:
			lista[i] = datos_garumi.duplicate(true)
			world_state.flags["garumis_amigos"] = lista
			garumis_amigos_actualizados.emit()
			_al_cambio_guardable()
			return true
	lista.append(datos_garumi.duplicate(true))
	world_state.flags["garumis_amigos"] = lista
	garumis_amigos_actualizados.emit()
	_al_cambio_guardable()
	return true


func eliminar_garumi_amigo(id_instancia: String) -> bool:
	var id_limpio := id_instancia.strip_edges()
	if id_limpio.is_empty():
		return false
	var nueva_lista: Array[Dictionary] = []
	var eliminado := false
	for amigo in obtener_garumis_amigos():
		if str(amigo.get("garumi_instancia_id", "")) == id_limpio:
			eliminado = true
		else:
			nueva_lista.append(amigo)
	if eliminado:
		world_state.flags["garumis_amigos"] = nueva_lista
		garumis_amigos_actualizados.emit()
		_al_cambio_guardable()
	return eliminado


func obtener_garumis_vinculados() -> Array[Dictionary]:
	var guardados: Array[Dictionary] = []
	var variant: Variant = world_state.flags.get("garumis_vinculados", [])
	if not variant is Array:
		return guardados
	for item in variant as Array:
		if item is Dictionary:
			guardados.append((item as Dictionary).duplicate(true))
	return guardados


func contar_garumis_vinculados() -> int:
	return obtener_garumis_vinculados().size()


func puede_vincular_garumi() -> bool:
	return contar_garumis_vinculados() < 3


func guardar_garumi_vinculado(datos_garumi: Dictionary) -> bool:
	var id_instancia := str(datos_garumi.get("garumi_instancia_id", "")).strip_edges()
	if id_instancia.is_empty():
		push_warning("GameState: no se guardó un Garumi vinculado sin garumi_instancia_id.")
		return false
	var lista := obtener_garumis_vinculados()
	for i in range(lista.size()):
		if str(lista[i].get("garumi_instancia_id", "")) == id_instancia:
			lista[i] = datos_garumi.duplicate(true)
			world_state.flags["garumis_vinculados"] = lista
			garumis_vinculados_actualizados.emit()
			_al_cambio_guardable()
			return true
	if lista.size() >= 3:
		push_warning("GameState: límite de 3 Garumis vinculados alcanzado; rompe un vínculo antes de añadir otro.")
		return false
	lista.append(datos_garumi.duplicate(true))
	world_state.flags["garumis_vinculados"] = lista
	garumis_vinculados_actualizados.emit()
	_al_cambio_guardable()
	return true


func eliminar_garumi_vinculado(id_instancia: String) -> bool:
	var id_limpio := id_instancia.strip_edges()
	if id_limpio.is_empty():
		return false
	var lista := obtener_garumis_vinculados()
	var nueva_lista: Array[Dictionary] = []
	var eliminado := false
	for registro in lista:
		if str(registro.get("garumi_instancia_id", "")) == id_limpio:
			eliminado = true
			continue
		nueva_lista.append(registro)
	if eliminado:
		world_state.flags["garumis_vinculados"] = nueva_lista
		garumis_vinculados_actualizados.emit()
		_al_cambio_guardable()
	return eliminado


func obtener_recuerdos_sociales() -> Dictionary:
	var recuerdos_variant: Variant = world_state.flags.get("recuerdos_sociales", {})
	if recuerdos_variant is Dictionary:
		return (recuerdos_variant as Dictionary).duplicate(true)
	return {}


func guardar_recuerdos_sociales(recuerdos: Dictionary) -> void:
	world_state.flags["recuerdos_sociales"] = recuerdos.duplicate(true)
	_al_cambio_guardable()


## Lee los recuerdos de un solo habitante sin duplicar el historial de los demás.
func obtener_recuerdos_sociales_npc(personaje_id: String) -> Array:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return []
	var recuerdos_variant: Variant = world_state.flags.get("recuerdos_sociales", {})
	if not recuerdos_variant is Dictionary:
		return []
	var lista_variant: Variant = (recuerdos_variant as Dictionary).get(id, [])
	return (lista_variant as Array).duplicate(true) if lista_variant is Array else []


## Reemplaza sólo el historial social del habitante indicado.
func guardar_recuerdos_sociales_npc(personaje_id: String, recuerdos: Array) -> void:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return
	var todos_variant: Variant = world_state.flags.get("recuerdos_sociales", {})
	var todos: Dictionary = todos_variant if todos_variant is Dictionary else {}
	var actualizados := todos.duplicate()
	actualizados[id] = recuerdos.duplicate(true)
	world_state.flags["recuerdos_sociales"] = actualizados
	_al_cambio_guardable()


func establecer_proceso_ium_equipado(proceso: Dictionary) -> void:
	world_state.flags["proceso_ium_equipado"] = proceso.duplicate(true)


func obtener_descubrimientos_mundo() -> Dictionary:
	return {
		"biomas": discovery_state.biomes.duplicate(true),
		"ecosistemas": discovery_state.ecosystems.duplicate(true),
		"habitats": discovery_state.habitats.duplicate(true),
		"criaturas": discovery_state.creatures.duplicate(true)
	}


func obtener_terreno_explorado() -> Dictionary:
	return discovery_state.explored_tiles.duplicate(true)


func esta_explorado(tile: Vector2i) -> bool:
	var clave := str(tile.x) + "," + str(tile.y)
	return discovery_state.explored_tiles.has(clave)


func _sincronizar_descubrimientos() -> void:
	var datos := discovery_state.to_dictionary()
	world_state.flags["descubrimientos_mundo"] = {
		"biomas": datos.get("biomas", {}),
		"ecosistemas": datos.get("ecosistemas", {}),
		"habitats": datos.get("habitats", {}),
		"criaturas": datos.get("criaturas", {})
	}
	world_state.flags["mapa_terreno_explorado"] = datos.get(
		"mapa_terreno_explorado",
		{}
	)


# ============================================================
# APLICAR A LA ESCENA
# ============================================================

func _revisar_escena_actual() -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return

	if _historia_reserva_activa:
		if not _historia_requiere_aplicar or _partida_aplicada_en_escena:
			return
	elif active_save_id.is_empty() or _partida_aplicada_en_escena:
		return

	_aplicar_estado_al_juego()


func _al_mundo_generado_para_aplicar() -> void:
	call_deferred("_revisar_escena_actual")


func jugador_listo_para_restaurar() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if not _player.has_method("esta_listo_para_restaurar_estado"):
		return true
	if bool(_player.call("esta_listo_para_restaurar_estado")):
		_esperando_configuracion_eterium_jugador = false
		return true
	if not _esperando_configuracion_eterium_jugador and _player.has_signal("configuracion_eterium_lista"):
		_esperando_configuracion_eterium_jugador = true
		var callback := Callable(self, "_al_estar_lista_configuracion_eterium")
		if not _player.is_connected("configuracion_eterium_lista", callback):
			_player.connect("configuracion_eterium_lista", callback, CONNECT_ONE_SHOT)
	return false


func _al_estar_lista_configuracion_eterium() -> void:
	_esperando_configuracion_eterium_jugador = false
	call_deferred("_restaurar_estado_vital_pendiente")


func _actualizar_timeout_restauracion_vital(delta: float) -> void:
	if not _partida_aplicada_en_escena or _estado_vital_restaurado_en_escena:
		return
	_espera_restauracion_vital_elapsed += maxf(delta, 0.0)
	if _espera_restauracion_vital_elapsed < RESTAURACION_VITAL_TIMEOUT_S:
		return
	push_warning(
		"GameState: Supabase no terminó de configurar Eterium tras "
		+ str(RESTAURACION_VITAL_TIMEOUT_S)
		+ " s; restaurando vida y Eterium con las capacidades locales disponibles."
	)
	_restaurar_estado_vital_jugador(_player)


func _restaurar_estado_vital_pendiente() -> void:
	if _estado_vital_restaurado_en_escena or not _partida_aplicada_en_escena:
		return
	if not jugador_listo_para_restaurar():
		return
	_restaurar_estado_vital_jugador(_player)


func _restaurar_estado_vital_jugador(jugador: Player) -> void:
	if (
		_estado_vital_restaurado_en_escena
		or jugador == null
		or not is_instance_valid(jugador)
	):
		return
	var reservas_guardadas := player_state.normalizar_reservas_vitales(
		int(jugador.get("max_health")),
		int(jugador.get("max_mana")),
		jugador.eterium.vida_eterium_compartidos()
	)
	var vida_guardada := int(reservas_guardadas.get("health", 0))
	var mana_guardado := int(reservas_guardadas.get("mana", 0))
	# Un snapshot con salud cero nunca se restaura como vivo.
	jugador.restaurar_estado_vital(
		vida_guardada,
		vida_guardada > 0,
		mana_guardado
	)
	_estado_vital_restaurado_en_escena = true
	_espera_restauracion_vital_elapsed = 0.0
	_primer_guardado_pendiente = true
	_primer_guardado_elapsed = 0.0
	call_deferred("_guardar_progreso_diferido")


func _aplicar_estado_al_juego() -> void:
	var jugador: Player = _player

	if jugador == null or not is_instance_valid(jugador):
		return

	if jugador is Node2D and player_state.position_valida:
		(jugador as Node2D).global_position = player_state.position

	# Reconstruir la habitación después de posicionar al jugador.
	var escena_actual := get_tree().current_scene
	if is_instance_valid(escena_actual):
		var zone_manager := escena_actual.get_node_or_null("World/ZoneManager")
		if is_instance_valid(zone_manager):
			var zona := zone_manager.call("obtener_zona_actual") as Node
			var estado_zona: Variant = world_state.flags.get("estado_zona_actual", {})
			if is_instance_valid(zona) and zona.has_method("restaurar_estado_guardado") and estado_zona is Dictionary:
				zona.call("restaurar_estado_guardado", (estado_zona as Dictionary).duplicate(true))

	if jugador_listo_para_restaurar():
		_restaurar_estado_vital_jugador(jugador)

	if jugador.get("stamina") != null:
		var stamina_guardada := clampf(
			player_state.stamina,
			0.0,
			float(jugador.get("max_stamina"))
		)
		var stamina_controller: Variant = jugador.get("stamina_controller")
		if stamina_controller != null and stamina_controller.has_method("establecer_actual"):
			# El controlador es la fuente de verdad; su señal sincroniza Player.stamina y el HUD.
			stamina_controller.call("establecer_actual", stamina_guardada)
		else:
			jugador.set("stamina", stamina_guardada)

	if jugador.get("facing") is Vector2:
		jugador.set("facing", player_state.facing)

	if jugador.has_signal("stamina_changed"):
		jugador.stamina_changed.emit(
			float(jugador.get("stamina")),
			float(jugador.get("max_stamina"))
		)

	var inventario: Node = _inventory

	if inventario != null and is_instance_valid(inventario):
		_cargar_inventario_al_juego(
			inventario
		)

	_aplicar_estado_misiones()

	var proceso_variant: Variant = world_state.flags.get(
		"proceso_ium_equipado",
		{}
	)

	if proceso_variant is Dictionary and not (
		proceso_variant as Dictionary
	).is_empty():
		jugador.cargar_estado_ium((proceso_variant as Dictionary).duplicate(true))

	var atmosphere: WorldAtmosphere = _world_atmosphere
	var tiempo_variant: Variant = world_state.flags.get(
		"tiempo_mundo",
		{}
	)

	if atmosphere != null and tiempo_variant is Dictionary:
		atmosphere.establecer_estado_guardado((tiempo_variant as Dictionary).duplicate(true))

	_partida_aplicada_en_escena = true
	_guardado_rapido_conectado = false
	_conectar_guardado_rapido()

	if _historia_reserva_activa:
		_historia_requiere_aplicar = false
		print("GameState: progreso narrativo restaurado → La Reserva Carmesí")
	else:
		print(
			"GameState: partida cargada → ",
			active_save_name
		)


func _cargar_inventario_al_juego(
	inventario: GarliaInventory
) -> void:
	var estado_variant: Variant = world_state.flags.get(
		"inventario_estado",
		{}
	)

	if not estado_variant is Dictionary:
		return

	var estado := estado_variant as Dictionary

	var rol_guardado := str(
		estado.get("rol_partida", "")
	).to_lower()
	if rol_guardado == "admin" or rol_guardado == "explorador":
		var admin_guardado: Dictionary = {}
		var admin_actual: Variant = world_state.flags.get("personaje_admin", {})
		if admin_actual is Dictionary:
			admin_guardado = (admin_actual as Dictionary).duplicate(true)
		admin_guardado["rol"] = rol_guardado
		if rol_guardado == "explorador":
			admin_guardado["capacidades"] = []
		world_state.flags["personaje_admin"] = admin_guardado

	inventario.cargar_estado_partida(estado.duplicate(true))


func _abrir_escena_principal() -> void:
	# La partida entra al runtime canónico. Reino Torres es una zona
	# inicial del mismo runtime, no una escena paralela.
	print("GameState: entrando al runtime canónico.")
	SceneManager.go_to(MAIN_SCENE_PATH)


func _al_cambiar_escena() -> void:
	_partida_aplicada_en_escena = false
	_estado_vital_restaurado_en_escena = false
	_espera_restauracion_vital_elapsed = 0.0
	_primer_guardado_pendiente = _hay_runtime_partida_activo() and (_historia_reserva_activa or not active_save_id.is_empty())
	_primer_guardado_elapsed = 0.0
	var escena := get_tree().current_scene
	if escena != null:
		world_state.current_scene = str(escena.scene_file_path)
	call_deferred("_revisar_escena_actual")


# ============================================================
# ARCHIVOS
# ============================================================


func _leer_archivo_partida(id: String) -> Dictionary:
	return save_repository.leer_partida(id)


## El repositorio garantiza JSON válido; GameState valida el contrato del save.
## Versiones antiguas sin campo version se interpretan como versión 1.
## Normaliza versiones antiguas sin descartar campos desconocidos del progreso.
## La semilla ausente se genera una sola vez y se guarda con el resto de la migración.
func _migrar_datos_partida(id: String, datos: Dictionary) -> Dictionary:
	if not _datos_partida_cargables(id, datos):
		return {}
	var migrados := datos.duplicate(true)
	var mundo_variant: Variant = migrados.get("mundo", {})
	var mundo: Dictionary = (mundo_variant as Dictionary).duplicate(true) if mundo_variant is Dictionary else {}
	if not mundo.has("semilla"):
		mundo["semilla"] = _generar_semilla_mundo()
	if not mundo.has("generador_version"):
		mundo["generador_version"] = 1
	migrados["mundo"] = mundo
	migrados["version"] = SAVE_VERSION
	return migrados


func _datos_partida_cargables(id: String, datos: Dictionary) -> bool:
	if id.strip_edges().is_empty() or datos.is_empty():
		return false
	var id_guardado := str(datos.get("id", id)).strip_edges()
	if id_guardado != id:
		return false
	var version_variant: Variant = datos.get("version", 1)
	if not (version_variant is int or version_variant is float):
		return false
	if version_variant is float and not is_equal_approx(
		float(version_variant),
		roundf(float(version_variant))
	):
		return false
	var version := int(version_variant)
	if version < 1 or version > SAVE_VERSION:
		return false
	if datos.has("mundo") and not datos.get("mundo") is Dictionary:
		return false
	if datos.has("mundo_version"):
		var mundo_version: Variant = datos.get("mundo_version")
		if not (mundo_version is int or mundo_version is float):
			return false
	var mundo_variant: Variant = datos.get("mundo", {})
	if mundo_variant is Dictionary:
		var mundo := mundo_variant as Dictionary
		if mundo.has("semilla") and not (mundo.get("semilla") is int or mundo.get("semilla") is float):
			return false
		if mundo.has("generador_version") and not (mundo.get("generador_version") is int or mundo.get("generador_version") is float):
			return false
	var estado_variant: Variant = datos.get("estado", null)
	if not estado_variant is Dictionary:
		return false
	var estado := estado_variant as Dictionary
	if estado.has("elapsed_time"):
		var tiempo: Variant = estado.get("elapsed_time")
		if not (tiempo is int or tiempo is float):
			return false
	if estado.has("scene") and not estado.get("scene") is String:
		return false
	if estado.has("player") and not _player_guardado_valido(estado.get("player")):
		return false
	if estado.has("flags") and not estado.get("flags") is Dictionary:
		return false
	var flags_variant: Variant = estado.get("flags", {})
	var flags := flags_variant as Dictionary
	if flags.has("inventario_estado") and not _inventario_guardado_valido(flags.get("inventario_estado")):
		return false
	return true


func _player_guardado_valido(valor: Variant) -> bool:
	if not valor is Dictionary:
		return false
	var jugador := valor as Dictionary
	for clave in ["health", "mana", "stamina"]:
		if jugador.has(clave):
			var reserva: Variant = jugador.get(clave)
			if not (reserva is int or reserva is float):
				return false
	for clave in ["position_valid", "tile_valid"]:
		if jugador.has(clave) and not jugador.get(clave) is bool:
			return false
	for clave in ["position", "tile", "facing"]:
		if jugador.has(clave):
			var vector_variant: Variant = jugador.get(clave)
			if not vector_variant is Dictionary:
				return false
			var vector := vector_variant as Dictionary
			for componente in ["x", "y"]:
				if vector.has(componente):
					var numero: Variant = vector.get(componente)
					if not (numero is int or numero is float):
						return false
	return true


func _inventario_guardado_valido(valor: Variant) -> bool:
	if not valor is Dictionary:
		return false
	var inventario := valor as Dictionary
	var items_variant: Variant = inventario.get("items", [])
	if not items_variant is Array:
		return false
	for item_variant in items_variant as Array:
		if not item_variant is Dictionary:
			return false

	var hotbar_variant: Variant = inventario.get("hotbar_indices", [])
	if not hotbar_variant is Array:
		return false
	for indice_variant in hotbar_variant as Array:
		if not (indice_variant is int or indice_variant is float):
			return false

	if inventario.has("equipo"):
		var equipo_variant: Variant = inventario.get("equipo")
		if not equipo_variant is Dictionary:
			return false
		for item_equipo_variant in (equipo_variant as Dictionary).values():
			if not item_equipo_variant is Dictionary:
				return false

	for clave in ["mano_izquierda_activa", "mano_derecha_activa", "indice_hotbar_activo"]:
		if inventario.has(clave):
			var indice: Variant = inventario.get(clave)
			if not (indice is int or indice is float):
				return false
	return true


func _escribir_archivo_partida(
	id: String,
	datos: Dictionary
) -> bool:
	var escrito := save_repository.escribir_partida(id, datos)
	if escrito:
		_actualizar_indice_metadata_partida(id, datos)
	return escrito


func _extraer_metadata_partida(
	datos: Dictionary
) -> Dictionary:
	return {
		"id": str(datos.get("id", "")),
		"nombre": str(
			datos.get("nombre", "Partida")
		),
		"creado_en": str(
			datos.get("creado_en", "")
		),
		"actualizado_en": str(
			datos.get("actualizado_en", "")
		),
		"semilla": int(
			datos.get("mundo", {}).get(
				"semilla",
				0
			)
		),
		"mundo_version": int(
			datos.get("mundo_version", 0)
		),
		"play_time": float(
			datos.get("estado", {}).get(
				"elapsed_time",
				0.0
			)
		)
	}




func obtener_dinero() -> int:
	# Las partidas antiguas reciben un saldo inicial al adoptar el sistema.
	if not world_state.flags.has("dinero"):
		world_state.flags["dinero"] = 100
	return maxi(0, int(world_state.flags.get("dinero", 0)))


func establecer_dinero(cantidad: int) -> void:
	var nuevo_saldo := maxi(0, cantidad)
	if obtener_dinero() == nuevo_saldo:
		return
	world_state.flags["dinero"] = nuevo_saldo
	dinero_cambiado.emit(nuevo_saldo)
	call_deferred("_ejecutar_guardado_rapido")


func modificar_dinero(cambio: int) -> bool:
	var saldo_actual := obtener_dinero()
	if cambio < 0 and saldo_actual < -cambio:
		return false
	establecer_dinero(saldo_actual + cambio)
	return true


func tiene_semilla_mundo() -> bool:
	return world_state.world_seed_valida


func obtener_semilla_mundo() -> int:
	return world_state.world_seed


func establecer_semilla_mundo(semilla: int) -> void:
	world_state.world_seed = semilla
	world_state.world_seed_valida = true


func _generar_semilla_mundo() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()


func _texto_es_semilla_valida(texto: String) -> bool:
	var limpio := texto.strip_edges()
	if limpio.is_empty():
		return false

	var regex := RegEx.new()
	regex.compile("^-?\\d+$")
	return regex.search(limpio) != null


func _obtener_version_mundo() -> int:
	if _world_data == null:
		return 0
	return int(_world_data.mundo.get("version", 0))


func _ahora() -> String:
	return Time.get_datetime_string_from_system(
		true
	)


func _nombre_partida_por_defecto() -> String:
	var existentes := obtener_partidas()
	var numero := existentes.size() + 1

	while true:
		var candidato := "Partida " + str(numero)
		var encontrado := false

		for partida in existentes:
			if str(partida.get("nombre", "")) == candidato:
				encontrado = true
				break

		if not encontrado:
			return candidato

		numero += 1

	return "Partida " + str(numero)


## Progreso narrativo de conversaciones entre NPC.
func obtener_conversaciones_npc() -> Dictionary:
	var progreso_variant: Variant = world_state.flags.get("conversaciones_npc", {})
	if progreso_variant is Dictionary:
		return (progreso_variant as Dictionary).duplicate(true)
	return {}


## Lee una sola relación entre habitantes sin copiar el registro completo de conversaciones.
func obtener_relacion_npc_entre(clave: String) -> Dictionary:
	var progreso_variant: Variant = world_state.flags.get("conversaciones_npc", {})
	if not progreso_variant is Dictionary:
		return {}
	var relaciones_variant: Variant = (progreso_variant as Dictionary).get("_relaciones_npc", {})
	if not relaciones_variant is Dictionary:
		return {}
	var relacion_variant: Variant = (relaciones_variant as Dictionary).get(clave, {})
	return (relacion_variant as Dictionary).duplicate(true) if relacion_variant is Dictionary else {}


## Lee los conocimientos de un habitante sin copiar los datos de los demás.
func obtener_conocimientos_npc(personaje_id: String) -> Array:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return []
	var progreso_variant: Variant = world_state.flags.get("conversaciones_npc", {})
	if not progreso_variant is Dictionary:
		return []
	var conocimientos_variant: Variant = (progreso_variant as Dictionary).get("_conocimientos_npc", {})
	if not conocimientos_variant is Dictionary:
		return []
	var lista_variant: Variant = (conocimientos_variant as Dictionary).get(id, [])
	return (lista_variant as Array).duplicate(true) if lista_variant is Array else []


## Lee sólo la lista de asuntos pendientes de los habitantes.
func obtener_asuntos_pendientes_npc() -> Array:
	return _obtener_lista_conversaciones_npc("_asuntos_pendientes_npc")


## Lee sólo la lista de promesas entre habitantes.
func obtener_promesas_npc() -> Array:
	return _obtener_lista_conversaciones_npc("_promesas_npc")


func _obtener_lista_conversaciones_npc(clave: String) -> Array:
	var progreso_variant: Variant = world_state.flags.get("conversaciones_npc", {})
	if not progreso_variant is Dictionary:
		return []
	var lista_variant: Variant = (progreso_variant as Dictionary).get(clave, [])
	return (lista_variant as Array).duplicate(true) if lista_variant is Array else []


func guardar_conversaciones_npc(progreso: Dictionary) -> void:
	world_state.flags["conversaciones_npc"] = progreso.duplicate(true)
	_al_cambio_guardable()


## Actualiza una sola relación sin reconstruir el registro social completo.
func guardar_relacion_npc_entre(clave: String, relacion: Dictionary) -> void:
	var registro_variant: Variant = world_state.flags.get("conversaciones_npc", {})
	var registro: Dictionary = registro_variant if registro_variant is Dictionary else {}
	var relaciones_variant: Variant = registro.get("_relaciones_npc", {})
	var relaciones: Dictionary = relaciones_variant if relaciones_variant is Dictionary else {}
	var actualizadas := relaciones.duplicate()
	actualizadas[clave] = relacion.duplicate(true)
	var actualizado := registro.duplicate()
	actualizado["_relaciones_npc"] = actualizadas
	world_state.flags["conversaciones_npc"] = actualizado
	_al_cambio_guardable()


## Actualiza los conocimientos de un único habitante.
func guardar_conocimientos_npc(personaje_id: String, conocimientos: Array) -> void:
	var id := personaje_id.strip_edges()
	if id.is_empty():
		return
	var registro_variant: Variant = world_state.flags.get("conversaciones_npc", {})
	var registro: Dictionary = registro_variant if registro_variant is Dictionary else {}
	var todos_variant: Variant = registro.get("_conocimientos_npc", {})
	var todos: Dictionary = todos_variant if todos_variant is Dictionary else {}
	var actualizados := todos.duplicate()
	actualizados[id] = conocimientos.duplicate(true)
	var actualizado := registro.duplicate()
	actualizado["_conocimientos_npc"] = actualizados
	world_state.flags["conversaciones_npc"] = actualizado
	_al_cambio_guardable()


## Actualiza sólo la lista de asuntos pendientes.
func guardar_asuntos_pendientes_npc(asuntos: Array) -> void:
	_guardar_lista_conversaciones_npc("_asuntos_pendientes_npc", asuntos)


## Actualiza sólo la lista de promesas.
func guardar_promesas_npc(promesas: Array) -> void:
	_guardar_lista_conversaciones_npc("_promesas_npc", promesas)


func _guardar_lista_conversaciones_npc(clave: String, lista: Array) -> void:
	var registro_variant: Variant = world_state.flags.get("conversaciones_npc", {})
	var registro: Dictionary = registro_variant if registro_variant is Dictionary else {}
	var actualizado := registro.duplicate()
	actualizado[clave] = lista.duplicate(true)
	world_state.flags["conversaciones_npc"] = actualizado
	_al_cambio_guardable()
