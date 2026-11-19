extends Node

const NPCSchedule = preload("res://scripts/world/npc_schedule_system.gd")
const NPCNavigation = preload("res://scripts/world/npc_navigation_system.gd")


func _ready() -> void:
	var errores: Array[String] = []
	if NPCNavigation.ORIGEN_MAPA != Vector2(-1664.0, -1088.0):
		errores.append("El origen de navegación no coincide con el mapa ampliado de Torres.")
	if NPCNavigation.TAMANO_MALLA != Vector2i(104, 68):
		errores.append("La malla de navegación no cubre las 104 x 68 celdas de Torres.")

	# Cada punto de rutina más el desplazamiento de 28 px debe coincidir
	# con la posición real de la entrada publicada por ReinoTorres.
	var puertas_esperadas: Dictionary = {
		"panaderia": Vector2(-360.0, -58.0),
		"posada": Vector2(360.0, -53.0),
		"forja": Vector2(-500.0, 242.0),
		"cuartel": Vector2(520.0, -362.0),
		"registro": Vector2(1480.0, 61.0),
		"casa_comercio": Vector2(500.0, 246.0),
		"archivo_real": Vector2(-170.0, -217.0),
		"sala_consejo": Vector2(170.0, -212.0),
		"casa_estudio": Vector2(-520.0, -365.0),
		"casa_elian": Vector2(700.0, -296.0),
		"casa_bruna": Vector2(-1000.0, -296.0),
		"casa_darven": Vector2(850.0, -296.0),
		"casa_saira": Vector2(1000.0, -296.0),
		"casa_narel": Vector2(-850.0, -296.0),
		"castillo": Vector2(0.0, -738.0)
	}
	for clave in puertas_esperadas:
		var entrada_variant: Variant = NPCSchedule.ENTRADAS_INTERIORES.get(clave, {})
		if not entrada_variant is Dictionary:
			errores.append("Falta la entrada de rutina: " + clave)
			continue
		var entrada: Dictionary = entrada_variant
		var destino: Vector2 = entrada.get("pos", Vector2.ZERO) + Vector2(0.0, 28.0)
		if destino.distance_to(puertas_esperadas[clave]) > 0.1:
			errores.append("La ruta de " + clave + " no termina en su puerta real.")

	if errores.is_empty():
		print("NPCScheduleTorresNavigationBounds: PASS")
		get_tree().quit(0)
		return

	for error in errores:
		push_error("NPCScheduleTorresNavigationBounds: FAIL: " + error)
	get_tree().quit(1)
