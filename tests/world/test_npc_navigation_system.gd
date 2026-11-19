extends Node

const NavigationScript = preload("res://scripts/world/npc_navigation_system.gd")

var _malla_construida := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var zona := Node2D.new()
	zona.name = "TorresTestZone"
	add_child(zona)

	var navegacion := NavigationScript.new() as NPCNavigationSystem
	add_child(navegacion)
	navegacion.malla_reconstruida.connect(_al_construir_malla)

	if navegacion.actualizar(zona, 0.5):
		errores.append("La navegación no debe estar lista antes de construir la malla.")

	var limite := get_tree().create_timer(10.0)
	while not _malla_construida and limite.time_left > 0.0:
		await get_tree().process_frame

	if not _malla_construida or not navegacion.esta_lista():
		errores.append("La malla de Torres no terminó de construirse.")
	else:
		var origen := zona.to_global(Vector2(-1500.0, -1000.0))
		var destino := zona.to_global(Vector2(-1400.0, -1000.0))
		var ruta := navegacion.crear_ruta(origen, destino)
		if ruta.is_empty():
			errores.append("La navegación no encontró una ruta entre dos puntos libres.")
			
	navegacion.invalidar()
	if navegacion.esta_lista():
		errores.append("Invalidar la navegación no limpió el estado de la malla.")

	if errores.is_empty():
		print("NPCNavigationSystemIntegration: PASS")
		get_tree().quit(0)
		return
	for error in errores:
		push_error("NPCNavigationSystemIntegration: FAIL: " + error)
	get_tree().quit(1)


func _al_construir_malla() -> void:
	_malla_construida = true
