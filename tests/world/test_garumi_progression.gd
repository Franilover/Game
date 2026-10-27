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

	_expect(progresion.xp_para_siguiente_nivel(1) == 100, "Nivel 1 debe requerir 100 XP para subir.", errores)
	_expect(progresion.nivel_desde_experiencia(99) == 1, "99 XP no debe subir desde nivel 1.", errores)
	_expect(progresion.nivel_desde_experiencia(100) == 2, "100 XP debe subir a nivel 2.", errores)
	_expect(progresion.nivel_desde_experiencia(progresion.xp_total_para_nivel(100)) == 100, "La curva debe alcanzar nivel 100 con su umbral acumulado.", errores)
	var base: Dictionary = progresion.obtener_estadisticas(1)
	var superior: Dictionary = progresion.obtener_estadisticas(10)
	_expect(int(base["vida"]) == 40 and int(base["ataque"]) == 10, "Nivel 1 debe respetar las estadísticas base suministradas.", errores)
	_expect(int(superior["vida"]) > int(base["vida"]) and int(superior["ataque"]) > int(base["ataque"]), "Las estadísticas deben crecer con el nivel.", errores)
	_expect(progresion.calcular_danio(10, 0, 100.0) == 10, "Defensa cero no debe reducir el daño base.", errores)
	_expect(progresion.calcular_danio(10, 100, 100.0) == 5, "Defensa alta debe reducir el daño sin anularlo.", errores)
	_expect(progresion.calcular_danio(10, 0, 200.0) == 20, "La potencia del movimiento debe escalar el daño.", errores)

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
		"tipo_relacion": "directa",
		"estado_documentacion": "borrador"
	}
	var relacion_canon := relacion_borrador.duplicate(true)
	relacion_canon["estado_documentacion"] = "canon"
	_expect(garumi.nivel == 30, "La experiencia acumulada debe calcular el nivel real.", errores)
	_expect(not garumi.puede_evolucionar_a(destino, relacion_borrador), "Una relación evolutiva en borrador no debe habilitar evolución.", errores)
	_expect(garumi.puede_evolucionar_a(destino, relacion_canon), "Una relación canónica debe habilitar evolución desde nivel 30.", errores)
	_expect(garumi.evolucionar_a(destino, relacion_canon), "Debe poder transformar una instancia existente en su forma final.", errores)
	_expect(garumi.criatura_id == "orumi-final-test" and garumi.nivel == 30, "La evolución debe cambiar la forma y conservar el nivel.", errores)
	var manager := WorldEntityManager.new()
	manager.configurar(root)
	garumi.set_meta("runtime_instance_key", "garumi:0:orumi-inicial-test")
	manager.guardar_estado_entidad(garumi, Vector2i.ZERO)
	var estado_guardado: Dictionary = manager.obtener_estado_criatura(Vector2i.ZERO, "orumi-inicial-test", "garumi:0:orumi-inicial-test")
	var datos_guardados_variant: Variant = estado_guardado.get("garumi_datos", {})
	var datos_guardados: Dictionary = datos_guardados_variant if datos_guardados_variant is Dictionary else {}
	_expect(str(datos_guardados.get("id", "")) == "orumi-final-test", "El streaming debe conservar la forma evolucionada.", errores)
	_expect(int(estado_guardado.get("nivel", 0)) == 30 and int(estado_guardado.get("experiencia_total", 0)) == xp_nivel_30, "El streaming debe conservar nivel y experiencia.", errores)
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
