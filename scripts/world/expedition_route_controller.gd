extends Node2D
class_name ExpeditionRouteController

const ROUTE_STATE_KEY := "expedicion_ruta"
const ROUTE_VERSION := 1
const CHECKPOINTS: Array[Dictionary] = [
	{"id": "borde_bosque", "nombre": "Borde del bosque", "posicion": Vector2(1080.0, 120.0), "radio": 112.0, "mensaje": "Has llegado al borde del bosque. Sigue las marcas de piedra hacia el interior."},
	{"id": "bifurcacion", "nombre": "La bifurcación", "posicion": Vector2(1800.0, -160.0), "radio": 112.0, "mensaje": "El sendero se divide. La ruta principal continúa hacia el claro; puedes explorar el desvío del norte."},
	{"id": "claro", "nombre": "Claro del guardabosque", "posicion": Vector2(2680.0, 120.0), "radio": 128.0, "mensaje": "El claro ofrece un respiro antes de las ruinas. Revisa tu equipo y a tus Garumis."},
	{"id": "ruinas", "nombre": "Ruinas exteriores", "posicion": Vector2(3600.0, 120.0), "radio": 128.0, "mensaje": "Has encontrado las ruinas. Explora el recinto y prepárate para lo que aguarda dentro."},
	{"id": "altar", "nombre": "Altar antiguo", "posicion": Vector2(4480.0, 120.0), "radio": 144.0, "mensaje": "Has alcanzado el altar. La primera ruta de la expedición está recorrida; el desafío de las ruinas aún puede ampliarse."}
]
const SECRET_POSITION := Vector2(1980.0, -560.0)
const SECRET_RADIUS := 104.0

var _player: Node2D
var _checkpoint_index: int = 0
var _secret_discovered: bool = false
var _completed: bool = false
var _state_loaded: bool = false


func _ready() -> void:
	_cargar_estado()
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_player):
		return
	procesar_posicion_jugador(_player.global_position)


func procesar_posicion_jugador(posicion: Vector2) -> void:
	if not _state_loaded:
		_cargar_estado()
	if not _secret_discovered and posicion.distance_to(SECRET_POSITION) <= SECRET_RADIUS:
		_secret_discovered = true
		_emitir_notificacion("Has descubierto un refugio oculto entre los árboles.")
		_guardar_estado()
		queue_redraw()
	if _completed or _checkpoint_index >= CHECKPOINTS.size():
		return
	var hito := CHECKPOINTS[_checkpoint_index]
	var centro: Vector2 = hito["posicion"]
	if posicion.distance_to(centro) > float(hito["radio"]):
		return
	_checkpoint_index += 1
	_completed = _checkpoint_index >= CHECKPOINTS.size()
	_emitir_notificacion(str(hito["mensaje"]))
	if _completed:
		_emitir_notificacion("Ruta principal completada. Puedes regresar a Torres o seguir explorando.")
	_guardar_estado()
	queue_redraw()


func obtener_estado_ruta() -> Dictionary:
	return {
		"version": ROUTE_VERSION,
		"hito_actual": _checkpoint_index,
		"ultimo_hito": str(CHECKPOINTS[_checkpoint_index - 1]["id"]) if _checkpoint_index > 0 else "",
		"secreto_descubierto": _secret_discovered,
		"completada": _completed
	}


func _cargar_estado() -> void:
	var flags: Dictionary = GameState.world_state.flags
	var guardado_variant: Variant = flags.get(ROUTE_STATE_KEY, {})
	if guardado_variant is Dictionary:
		var guardado := guardado_variant as Dictionary
		if int(guardado.get("version", 0)) == ROUTE_VERSION:
			_checkpoint_index = clampi(int(guardado.get("hito_actual", 0)), 0, CHECKPOINTS.size())
			_secret_discovered = bool(guardado.get("secreto_descubierto", false))
			_completed = bool(guardado.get("completada", false)) or _checkpoint_index >= CHECKPOINTS.size()
	_state_loaded = true


func _guardar_estado() -> void:
	var flags: Dictionary = GameState.world_state.flags
	flags[ROUTE_STATE_KEY] = obtener_estado_ruta()
	if not GameState.active_save_id.is_empty():
		GameState.call_deferred("guardar_partida")


func _emitir_notificacion(mensaje: String) -> void:
	print("ExpeditionRoute: ", mensaje)
	Events.notification_pushed.emit(mensaje)


func _draw() -> void:
	var camino := PackedVector2Array([
		Vector2(560.0, 120.0),
		Vector2(1080.0, 120.0),
		Vector2(1800.0, -160.0),
		Vector2(2680.0, 120.0),
		Vector2(3600.0, 120.0),
		Vector2(4480.0, 120.0)
	])
	draw_polyline(camino, Color(0.43, 0.36, 0.25, 0.62), 7.0, true)
	draw_polyline(camino, Color(0.76, 0.66, 0.46, 0.48), 2.0, true)
	draw_line(Vector2(1800.0, -160.0), SECRET_POSITION, Color(0.38, 0.48, 0.31, 0.48), 4.0, true)
	for i in range(CHECKPOINTS.size()):
		var hito := CHECKPOINTS[i]
		var centro: Vector2 = hito["posicion"]
		var activo := i == _checkpoint_index and not _completed
		var color := Color(0.83, 0.72, 0.49, 0.9) if activo else Color(0.35, 0.31, 0.24, 0.72)
		draw_arc(centro, 42.0, 0.0, TAU, 32, color, 5.0, true)
		draw_circle(centro, 7.0, color)
		if activo:
			draw_string(ThemeDB.fallback_font, centro + Vector2(-100.0, -58.0), str(hito["nombre"]), HORIZONTAL_ALIGNMENT_CENTER, 200.0, 18, Color(0.94, 0.88, 0.72, 0.96))
	if _secret_discovered:
		draw_arc(SECRET_POSITION, 30.0, 0.0, TAU, 24, Color(0.53, 0.69, 0.43, 0.9), 4.0, true)
