extends Node

const ROUTE_SCRIPT = preload("res://scripts/world/expedition_route_controller.gd")

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var flags_originales: Dictionary = GameState.world_state.flags.duplicate(true)
	var ruta := ROUTE_SCRIPT.new() as Node2D
	add_child(ruta)
	await get_tree().process_frame

	ruta.procesar_posicion_jugador(Vector2(1800.0, -160.0))
	var estado: Dictionary = ruta.obtener_estado_ruta()
	if int(estado.get("hito_actual", -1)) != 0:
		_fail("La ruta permitió saltarse el primer hito.")
		return

	ruta.procesar_posicion_jugador(Vector2(1080.0, 120.0))
	estado = ruta.obtener_estado_ruta()
	if int(estado.get("hito_actual", -1)) != 1 or str(estado.get("ultimo_hito", "")) != "borde_bosque":
		_fail("No se registró el borde del bosque.")
		return

	ruta.procesar_posicion_jugador(Vector2(1980.0, -560.0))
	estado = ruta.obtener_estado_ruta()
	if not bool(estado.get("secreto_descubierto", false)):
		_fail("No se registró el refugio opcional.")
		return

	ruta.procesar_posicion_jugador(Vector2(1800.0, -160.0))
	ruta.procesar_posicion_jugador(Vector2(2680.0, 120.0))
	ruta.procesar_posicion_jugador(Vector2(3600.0, 120.0))
	ruta.procesar_posicion_jugador(Vector2(4480.0, 120.0))
	estado = ruta.obtener_estado_ruta()
	if not bool(estado.get("completada", false)) or int(estado.get("hito_actual", 0)) != 5:
		_fail("La ruta principal no se completó tras recorrer sus cinco hitos.")
		return
	if GameState.world_state.flags.get("expedicion_ruta", {}).is_empty():
		_fail("El progreso de la ruta no se persistió en GameState.")
		return

	GameState.world_state.flags = flags_originales
	print("ExpeditionRouteContract: PASS")
	get_tree().quit(0)


func _fail(mensaje: String) -> void:
	GameState.world_state.flags.erase("expedicion_ruta")
	push_error("ExpeditionRouteContract: FAIL: " + mensaje)
	get_tree().quit(1)
