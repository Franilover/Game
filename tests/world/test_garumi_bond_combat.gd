extends SceneTree

const GARUMI_SCENE: PackedScene = preload("res://scenes/creatures/garumi.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var router := GameplayInputRouter.new()
	root.add_child(router)
	var interfaz_modal := CanvasLayer.new()
	interfaz_modal.add_to_group("modal_ui")
	root.add_child(interfaz_modal)
	_expect(router.esta_entrada_bloqueada(router.get_tree()), "Una interfaz modal debe impedir que el gameplay consuma sus clics.", errores)
	interfaz_modal.remove_from_group("modal_ui")
	_expect(not router.esta_entrada_bloqueada(router.get_tree()), "Sin una interfaz modal, el router no debe quedar bloqueado por ella.", errores)
	interfaz_modal.queue_free()
	router.queue_free()
	var arena_script: Script = load("res://scripts/gameplay/garumi_combat_arena.gd")
	var arena := Node2D.new()
	arena.set_script(arena_script)
	var jugador_arena := CharacterBody2D.new()
	var rival_arena := Node2D.new()
	root.add_child(arena)
	root.add_child(jugador_arena)
	root.add_child(rival_arena)
	arena.call("iniciar", jugador_arena, rival_arena)
	var limites: Rect2 = arena.get("limites_globales")
	jugador_arena.global_position = Vector2(limites.position.x + 12.0, limites.get_center().y)
	_expect(bool(arena.call("esta_activa")), "La arena debe seguir activa aunque el jugador haga dash cerca del borde; huir se controla desde el botón.", errores)
	_expect(not arena.has_method("intentar_escapar"), "La arena ya no debe exponer escape mediante dash.", errores)
	arena.queue_free()
	jugador_arena.queue_free()
	rival_arena.queue_free()

	var jugador := Node2D.new()
	jugador.name = "JugadorPrueba"
	root.add_child(jugador)

	var garumi := GARUMI_SCENE.instantiate() as Garumi
	root.add_child(garumi)
	await process_frame
	garumi.configurar({"id": "garumi-prueba", "nombre": "Garumi de prueba", "salud_combate": 40, "defensa": 0})
	var cerebro_garumi := garumi.get_node_or_null("GarumiBrain") as GarumiBrain
	_expect(cerebro_garumi != null, "Cada Garumi debe crear su cerebro reutilizable.", errores)
	if cerebro_garumi != null:
		_expect(bool(garumi._movimiento.get("_usar_direccion_externa")), "Sin perfil de Supabase, el cerebro debe bloquear la patrulla genérica y no inventar conducta.", errores)
		_expect(not garumi.has_meta("relaciones_garumi"), "El cerebro no debe inventar relaciones persistentes en metadatos.", errores)
		garumi.configurar({"id": "garumi-perfil", "nombre": "Garumi perfil", "defensa": 0, "ia_config": {"garumi": {"movimiento": {"perfil": "quieto"}}}})
		cerebro_garumi.configurar(garumi)
		_expect(bool(garumi._movimiento.get("_usar_direccion_externa")), "Un perfil explícito de configuración debe activar el intérprete.", errores)
		garumi.configurar({"id": "garumi-perfil-desconocido", "nombre": "Garumi perfil desconocido", "defensa": 0, "ia_config": {"garumi": {"movimiento": {"perfil": "perfil_no_registrado"}}}})
		cerebro_garumi.configurar(garumi)
		_expect(bool(garumi._movimiento.get("_usar_direccion_externa")), "Un perfil desconocido debe bloquear la patrulla genérica, no convertirse en errante.", errores)

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
	garumi_voluntario.configurar({"id": "garumi-voluntario", "nombre": "Garumi voluntario", "aceptacion_vinculo": 1.0})
	_expect(garumi_voluntario.ofrecer_vinculo(jugador), "Debe poder ofrecerse un vínculo fuera del combate.", errores)
	_expect(garumi_voluntario.obtener_tipo_vinculo() == "voluntario", "El vínculo voluntario debe distinguirse del forzado.", errores)
	_expect(not garumi_voluntario.es_dialogable(), "Un Garumi ya vinculado no debe volver a aparecer como objetivo contextual.", errores)

	var garumi_menu := GARUMI_SCENE.instantiate() as Garumi
	root.add_child(garumi_menu)
	await process_frame
	garumi_menu.configurar({"id": "garumi-menu", "nombre": "Garumi menú"})
	garumi_menu.interact(jugador)
	await process_frame
	_expect(is_instance_valid(garumi_menu._menu_contextual), "Interactuar debe abrir el menú contextual.", errores)
	var boton_cerrar := _buscar_boton_texto(garumi_menu._menu_contextual, "Cerrar")
	_expect(boton_cerrar != null, "El menú debe contener un botón Cerrar.", errores)
	if boton_cerrar != null:
		boton_cerrar.pressed.emit()
	await process_frame
	_expect(garumi_menu._menu_contextual == null, "El botón Cerrar debe cerrar el menú contextual.", errores)
	garumi_menu.interact(jugador)
	await process_frame
	var boton_enfrentar := _buscar_boton_texto(garumi_menu._menu_contextual, "Enfrentar")
	_expect(boton_enfrentar != null, "El menú debe contener la opción Enfrentar.", errores)
	if boton_enfrentar != null:
		boton_enfrentar.pressed.emit()
	await process_frame
	_expect(garumi_menu._menu_contextual == null, "Elegir Enfrentar debe cerrar el menú.", errores)
	_expect(garumi_menu.esta_enfrentamiento(), "Elegir Enfrentar debe iniciar el estado de combate.", errores)
	garumi_menu.finalizar_enfrentamiento()
	garumi_menu.queue_free()

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


func _buscar_boton_texto(nodo: Node, texto: String) -> Button:
	if nodo is Button and (nodo as Button).text == texto:
		return nodo as Button
	for hijo in nodo.get_children():
		var encontrado := _buscar_boton_texto(hijo, texto)
		if encontrado != null:
			return encontrado
	return null
