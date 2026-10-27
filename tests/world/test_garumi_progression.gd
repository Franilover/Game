extends SceneTree

const PROGRESSION_SCRIPT: Script = preload("res://scripts/creatures/garumi_progression.gd")
const GARUMI_SCENE: PackedScene = preload("res://scenes/creatures/garumi.tscn")


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

	var garumi := GARUMI_SCENE.instantiate() as Garumi
	root.add_child(garumi)
	await process_frame
	var xp_nivel_30 := progresion.xp_total_para_nivel(30)
	garumi.configurar({
		"id": "orumi-inicial-test",
		"nombre": "Forma inicial de prueba",
		"original_id": "orumi-test",
		"categoria_garumi": "normal",
		"estado_evolutivo": "inicial",
		"estado_documentacion": "canon",
		"experiencia_total": xp_nivel_30
	})
	var destino := {
		"id": "orumi-final-test",
		"nombre": "Forma evolucionada de prueba",
		"original_id": "orumi-test",
		"categoria_garumi": "normal",
		"estado_evolutivo": "final",
		"estado_documentacion": "canon"
	}
	var relacion_borrador := {
		"especie_origen_id": "orumi-inicial-test",
		"especie_destino_id": "orumi-final-test",
		"estado_documentacion": "borrador"
	}
	var relacion_canon := relacion_borrador.duplicate(true)
	relacion_canon["estado_documentacion"] = "canon"
	_expect(garumi.nivel == 30, "La experiencia acumulada debe calcular el nivel real.")
	_expect(not garumi.puede_evolucionar_a(destino, relacion_borrador), "Una relación evolutiva en borrador no debe habilitar evolución.")
	_expect(garumi.puede_evolucionar_a(destino, relacion_canon), "Una relación canónica debe habilitar evolución desde nivel 30.")
	_expect(garumi.evolucionar_a(destino, relacion_canon), "Debe poder transformar una instancia existente en su forma final.")
	_expect(garumi.criatura_id == "orumi-final-test" and garumi.nivel == 30, "La evolución debe cambiar la forma y conservar el nivel.")
	garumi.queue_free()

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
