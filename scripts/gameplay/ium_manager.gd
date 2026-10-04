extends Node
## IUMManager — dominio/runtime de IUM.
## No conoce HTTP ni URLs: delega persistencia al IUMRepository.

signal iums_cargados(iums: Array)
signal procesos_cargados(procesos: Array)
signal proceso_descubierto(proceso: Dictionary)
signal proceso_equipado_signal(proceso: Dictionary)
signal error_ium(mensaje: String)

var iums_disponibles: Array = []
var procesos_conocidos: Array = []
var proceso_equipado: Dictionary = {}

var _jugador_id: String = ""
var _repository: IUMRepository = null


func configurar(repository: IUMRepository) -> void:
	_repository = repository
	if _repository == null:
		push_error("IUMManager: IUMRepository no configurado.")
		return

	if not _repository.iums_cargados.is_connected(_al_cargar_iums):
		_repository.iums_cargados.connect(_al_cargar_iums)
	if not _repository.procesos_cargados.is_connected(_al_cargar_procesos):
		_repository.procesos_cargados.connect(_al_cargar_procesos)
	if not _repository.simulacion_completada.is_connected(_al_simulacion_completada):
		_repository.simulacion_completada.connect(_al_simulacion_completada)
	if not _repository.simulacion_fallida.is_connected(_al_simulacion_fallida):
		_repository.simulacion_fallida.connect(_al_simulacion_fallida)


func inicializar(jugador_id: String) -> void:
	_jugador_id = jugador_id
	cargar_iums()
	cargar_procesos_descubiertos()


func cargar_iums() -> void:
	if _repository == null:
		error_ium.emit("Repositorio IUM no configurado.")
		return
	_repository.cargar_iums()


func cargar_procesos_descubiertos() -> void:
	if _jugador_id.is_empty() or _repository == null:
		return
	_repository.cargar_procesos(_jugador_id)


func _al_cargar_iums(datos: Array) -> void:
	iums_disponibles = datos
	iums_cargados.emit(iums_disponibles)


func _al_cargar_procesos(datos: Array) -> void:
	procesos_conocidos = datos
	procesos_cargados.emit(procesos_conocidos)


func simular_organizacion(nodos: Array, enlaces: Array) -> void:
	if nodos.is_empty():
		error_ium.emit("No hay IUMs en la configuración.")
		return
	if _repository == null:
		error_ium.emit("Repositorio IUM no configurado.")
		return
	_repository.simular(_jugador_id, nodos, enlaces)


func _al_simulacion_completada(proceso: Dictionary) -> void:
	_registrar_descubrimiento(proceso)
	proceso_descubierto.emit(proceso)


func _al_simulacion_fallida(mensaje: String) -> void:
	error_ium.emit(mensaje)


func _registrar_descubrimiento(proceso: Dictionary) -> void:
	var proceso_id := str(
		proceso.get("proceso_id", proceso.get("id", ""))
	)
	if _jugador_id.is_empty() or proceso_id.is_empty():
		return

	if _repository != null:
		_repository.registrar_intento(_jugador_id, proceso_id)

	for conocido_variant in procesos_conocidos:
		if not conocido_variant is Dictionary:
			continue
		var conocido := conocido_variant as Dictionary
		if str(conocido.get("id", conocido.get("proceso_id", ""))) == proceso_id:
			return

	procesos_conocidos.append(proceso)


func equipar_proceso(proceso: Dictionary) -> void:
	proceso_equipado = proceso
	proceso_equipado_signal.emit(proceso)


func usar_proceso_equipado(objetivo: Node = null) -> void:
	if proceso_equipado.is_empty():
		error_ium.emit("No hay proceso equipado.")
		return

	var nombre: String = str(proceso_equipado.get("nombre", "Proceso desconocido"))
	var efecto: String = str(proceso_equipado.get("efecto_tipo", ""))
	var magnitud: float = float(proceso_equipado.get("magnitud", 10.0))

	match efecto:
		"daño", "damage":
			if objetivo != null and objetivo.has_method("take_damage"):
				objetivo.call("take_damage", int(magnitud))
		"curar", "heal":
			var player := get_tree().get_first_node_in_group("player")
			if player != null and player.has_method("heal"):
				player.call("heal", int(magnitud))
		"slow":
			if objetivo != null and objetivo.has_method("aplicar_efecto_slow"):
				objetivo.call("aplicar_efecto_slow", magnitud)

	Events.notification_pushed.emit("Proceso usado: " + nombre)
