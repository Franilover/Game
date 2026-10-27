extends SceneTree

const PROGRESSION_SCRIPT: Script = preload("res://scripts/creatures/garumi_progression.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var progresion = PROGRESSION_SCRIPT.new()
	progresion.configurar({
		"vida_maxima": 40,
		"ataque": 10,
		"defensa": 5,
		"velocidad": 12,
		"eterium_maximo": 30
	})

	_expect(progresion.xp_para_siguiente_nivel(1) == 100, "Nivel 1 debe requerir 100 XP para subir.")
	_expect(progresion.nivel_desde_experiencia(99) == 1, "99 XP no debe subir desde nivel 1.")
	_expect(progresion.nivel_desde_experiencia(100) == 2, "100 XP debe subir a nivel 2.")
	_expect(progresion.nivel_desde_experiencia(progresion.xp_total_para_nivel(100)) == 100, "La curva debe alcanzar nivel 100 con su umbral acumulado.")
	var base: Dictionary = progresion.obtener_estadisticas(1)
	var superior: Dictionary = progresion.obtener_estadisticas(10)
	_expect(int(base["vida"]) == 40 and int(base["ataque"]) == 10, "Nivel 1 debe respetar las estadísticas base suministradas.")
	_expect(int(superior["vida"]) > int(base["vida"]) and int(superior["ataque"]) > int(base["ataque"]), "Las estadísticas deben crecer con el nivel.")
	_expect(progresion.calcular_danio(10, 0, 100.0) == 10, "Defensa cero no debe reducir el daño base.")
	_expect(progresion.calcular_danio(10, 100, 100.0) == 5, "Defensa alta debe reducir el daño sin anularlo.")
	_expect(progresion.calcular_danio(10, 0, 200.0) == 20, "La potencia del movimiento debe escalar el daño.")

	if errores.is_empty():
		print("test_garumi_progression: OK")
	else:
		for error in errores:
			push_error(error)
		quit(1)
		return
	quit(0)


func _expect(condicion: bool, mensaje: String, errores: Array[String]) -> void:
	if not condicion:
		errores.append(mensaje)
