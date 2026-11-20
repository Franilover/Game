extends Node

const ZoneManagerScript = preload("res://scripts/world/zone_manager.gd")


func _ready() -> void:
	var errores: Array[String] = []
	var posicion_guardada := Vector2(842.5, -316.25)
	var spawn_inicial := Vector2(120.0, 64.0)

	var reanudada: Vector2 = ZoneManagerScript.resolver_posicion_reanudacion(
		"reino_torres", "reino_torres", true, posicion_guardada, spawn_inicial
	)
	if reanudada != posicion_guardada:
		errores.append("La misma zona no recuperó las coordenadas guardadas.")

	var transicion: Vector2 = ZoneManagerScript.resolver_posicion_reanudacion(
		"reino_torres", "mundo_abierto", true, posicion_guardada, spawn_inicial
	)
	if transicion != spawn_inicial:
		errores.append("Una transición entre zonas reutilizó coordenadas ajenas.")

	var posicion_invalida: Vector2 = ZoneManagerScript.resolver_posicion_reanudacion(
		"mundo_abierto", "mundo_abierto", false, posicion_guardada, spawn_inicial
	)
	if posicion_invalida != spawn_inicial:
		errores.append("Una partida sin posición válida ignoró el spawn inicial.")

	var zona_sin_tipo: Vector2 = ZoneManagerScript.resolver_posicion_reanudacion(
		"", "", true, posicion_guardada, spawn_inicial
	)
	if zona_sin_tipo != spawn_inicial:
		errores.append("Una zona sin identidad aceptó coordenadas persistidas.")

	if not errores.is_empty():
		for error in errores:
			push_error("ZoneSpawnResumeContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("ZoneSpawnResumeContract: PASS")
	get_tree().quit(0)
