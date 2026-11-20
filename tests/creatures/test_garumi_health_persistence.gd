extends Node

const GarumiScript = preload("res://scripts/creatures/garumi.gd")


func _ready() -> void:
	call_deferred("_run")


func _crear_garumi(datos: Dictionary) -> Garumi:
	var garumi: Garumi = GarumiScript.new() as Garumi
	garumi.configurar(datos)
	return garumi


func _run() -> void:
	var errores: Array[String] = []
	var base := {
		"id": "garumi_prueba",
		"nombre": "Garumi de prueba",
		"estadisticas_combate": {
			"vida_maxima": 80,
			"eterium_maximo": 40
		}
	}

	var garumi_guardado := _crear_garumi(base.merged({
		"health": 23,
		"eterium_actual": 17,
		"experiencia_total": 150
	}, true))
	if garumi_guardado.health != 23:
		errores.append("La configuración descartó la vida guardada.")
	if garumi_guardado.max_health != 80:
		errores.append("La restauración cambió la vida máxima calculada.")
	if garumi_guardado.eterium_actual != 17:
		errores.append("La restauración alteró el Eterium guardado.")
	if garumi_guardado.experiencia_total != 150:
		errores.append("La restauración alteró la experiencia acumulada.")

	var registro := garumi_guardado.obtener_datos_amistad()
	if int(registro.get("health", -1)) != 23:
		errores.append("El registro de amistad no incluye la vida actual.")

	garumi_guardado._vinculado = true
	var registro_vinculo := garumi_guardado.obtener_datos_persistencia_vinculo()
	if int(registro_vinculo.get("health", -1)) != 23:
		errores.append("El registro de vínculo no incluye la vida actual.")

	var garumi_legacy := _crear_garumi(base)
	if garumi_legacy.health != garumi_legacy.max_health:
		errores.append("Un guardado antiguo sin health no inicia con vida máxima.")

	var garumi_derrotado := _crear_garumi(base.merged({"health": 0}, true))
	if garumi_derrotado.health != 0 or garumi_derrotado.is_alive:
		errores.append("Un Garumi con cero vida guardada se restauró como vivo.")

	garumi_guardado.free()
	garumi_legacy.free()
	garumi_derrotado.free()

	if not errores.is_empty():
		for error in errores:
			push_error("GarumiHealthPersistence: FAIL: " + error)
		get_tree().quit(1)
		return
	print("GarumiHealthPersistence: PASS")
	get_tree().quit(0)
