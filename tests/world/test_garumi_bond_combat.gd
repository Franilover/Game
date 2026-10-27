extends SceneTree

const GARUMI_SCENE: PackedScene = preload("res://scenes/creatures/garumi.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var jugador := Node2D.new()
	jugador.name = "JugadorPrueba"
	root.add_child(jugador)

	var garumi := GARUMI_SCENE.instantiate() as Garumi
	root.add_child(garumi)
	await process_frame
	garumi.configurar({"id": "garumi-prueba", "nombre": "Garumi de prueba", "salud_combate": 40})

	_expect(not garumi.is_in_group("damageable"), "El Garumi no debe recibir daño antes de iniciar un enfrentamiento.", errores)
	garumi.take_damage(20, "test/sin-enfrentamiento")
	_expect(garumi.health == garumi.max_health, "El daño común no debe alterar la salud del Garumi fuera del combate.", errores)

	_expect(garumi.iniciar_enfrentamiento(jugador), "Debe poder iniciarse un enfrentamiento con un Garumi libre.", errores)
	_expect(garumi.is_in_group("damageable"), "El Garumi debe ser objetivo de combate durante el encuentro.", errores)
	garumi.take_damage(30, "test/ataque")
	_expect(garumi.health == 10, "El daño del enfrentamiento debe reducir la salud.", errores)
	_expect(garumi.puede_forzar_vinculo(), "Debe habilitarse el vínculo forzado al alcanzar el umbral de salud.", errores)
	garumi.take_damage(999, "test/golpe-final")
	_expect(garumi.health == 1 and garumi.is_alive, "El Garumi no debe morir por ataques durante el enfrentamiento.", errores)
	_expect(garumi.forzar_vinculo(jugador), "Debe poder forzarse el vínculo con el Garumi debilitado.", errores)
	_expect(garumi.esta_vinculado(), "El vínculo forzado debe quedar registrado en la instancia.", errores)
	_expect(garumi.obtener_tipo_vinculo() == "forzado", "El vínculo debe conservar su tipo.", errores)
	_expect(not garumi.is_in_group("damageable"), "Un Garumi vinculado debe dejar de ser objetivo de daño.", errores)
	_expect(not garumi.esta_enfrentamiento(), "El vínculo debe terminar el enfrentamiento.", errores)

	var garumi_voluntario := GARUMI_SCENE.instantiate() as Garumi
	root.add_child(garumi_voluntario)
	await process_frame
	garumi_voluntario.configurar({"id": "garumi-voluntario", "nombre": "Garumi voluntario"})
	_expect(garumi_voluntario.ofrecer_vinculo(jugador), "Debe poder ofrecerse un vínculo fuera del combate.", errores)
	_expect(garumi_voluntario.obtener_tipo_vinculo() == "voluntario", "El vínculo voluntario debe distinguirse del forzado.", errores)
	_expect(not garumi_voluntario.es_dialogable(), "Un Garumi ya vinculado no debe volver a aparecer como objetivo contextual.", errores)

	jugador.queue_free()
	garumi.queue_free()
	garumi_voluntario.queue_free()

	if not errores.is_empty():
		for error in errores:
			push_error("GarumiBondCombat: FAIL: " + error)
		quit(1)
		return
	print("GarumiBondCombat: PASS")
	quit(0)


func _expect(condicion: bool, mensaje: String, errores: Array[String]) -> void:
	if not condicion:
		errores.append(mensaje)
