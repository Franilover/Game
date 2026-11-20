extends Node

const EntityScript = preload("res://scripts/characters/entity.gd")
const CombatAttackScript = preload("res://scripts/gameplay/combat/combat_attack.gd")
const CombatProjectileScript = preload("res://scripts/gameplay/combat/combat_projectile.gd")
const CombatAttackAreaScript = preload("res://scripts/gameplay/combat/combat_attack_area.gd")
const CombatSystemScript = preload("res://scripts/gameplay/combat_system.gd")
const PlayerScene = preload("res://scenes/characters/player.tscn")
const InventoryScene = preload("res://scenes/ui/inventory.tscn")
const InventoryControllerScript = preload("res://scripts/gameplay/inventory/inventory_controller.gd")
const EteriumRuntimeScript = preload("res://scripts/gameplay/player/player_eterium_runtime.gd")
const VitalStateScript = preload("res://scripts/state/vital_state.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	_probar_durabilidad_en_mano_correcta(errores)
	await _probar_direccion_de_ataque_recibida(errores)
	await _probar_contacto_independiente_del_danio(errores)
	await _probar_cancelacion_al_morir_atacante(errores)
	await _probar_impactos_simultaneos_y_atacante_invalido(errores)
	await _probar_danio_jugador_con_armadura(errores)
	_probar_pausa_recuperacion_eterium(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatTemporalContract: FAIL: " + error)
		get_tree().quit(1)
		return

	print("CombatTemporalContract: PASS")
	get_tree().quit(0)


func _probar_direccion_de_ataque_recibida(errores: Array[String]) -> void:
	var jugador := PlayerScene.instantiate() as Player
	var combate := CombatSystemScript.new() as CombatSystem
	combate.player = jugador
	get_tree().root.add_child(jugador)
	get_tree().root.add_child(combate)
	await get_tree().process_frame

	jugador.facing = Vector2.DOWN
	if not combate.combat_controller.solicitar_ataque(
		Vector2.LEFT,
		{},
		"desarmado"
	):
		errores.append("CombatController rechazó una solicitud de prueba válida.")
	else:
		var ataque: CombatAttackArea = null
		for hijo in jugador.get_children():
			if hijo is CombatAttackArea:
				ataque = hijo as CombatAttackArea
				break

		if ataque == null:
			errores.append("La solicitud no creó el hitbox melee esperado.")
		elif not is_equal_approx(ataque.rotation, Vector2.LEFT.angle()):
			errores.append("CombatSystem ignoró la dirección entregada por CombatController.")

	combate.queue_free()
	jugador.queue_free()
	await get_tree().process_frame


func _probar_durabilidad_en_mano_correcta(errores: Array[String]) -> void:
	var inventario := InventoryControllerScript.new() as InventoryController
	var combate := CombatSystemScript.new() as CombatSystem
	get_tree().root.add_child(inventario)
	get_tree().root.add_child(combate)
	var items: Array = []
	for _indice in range(18):
		items.append({})

	var herramienta := {
		"tipo": "herramienta",
		"nombre": "Herramienta de prueba",
		"durabilidad_actual": 3,
		"propiedades_game": {"durabilidad": 3}
	}
	items[0] = herramienta.duplicate(true)
	items[12] = herramienta.duplicate(true)
	inventario.configurar_items(items)
	combate.inventory = inventario

	# La acción primaria toma la mano izquierda.
	combate._accion_en_mano_derecha = false
	combate._consumir_durabilidad_herramienta()
	var izquierda := inventario.obtener_objeto_mano_activa("izquierda")
	var derecha := inventario.obtener_objeto_mano_activa("derecha")
	if int(izquierda.get("durabilidad_actual", -1)) != 2:
		errores.append("La acción primaria no consumió durabilidad de la mano izquierda.")
	if int(derecha.get("durabilidad_actual", -1)) != 3:
		errores.append("La acción primaria consumió durabilidad de la mano derecha.")

	# La acción secundaria toma la mano derecha.
	combate._accion_en_mano_derecha = true
	combate._consumir_durabilidad_herramienta()
	izquierda = inventario.obtener_objeto_mano_activa("izquierda")
	derecha = inventario.obtener_objeto_mano_activa("derecha")
	if int(izquierda.get("durabilidad_actual", -1)) != 2:
		errores.append("La acción secundaria alteró la durabilidad de la mano izquierda.")
	if int(derecha.get("durabilidad_actual", -1)) != 2:
		errores.append("La acción secundaria no consumió durabilidad de la mano derecha.")

	combate.free()
	inventario.free()


func _probar_contacto_independiente_del_danio(errores: Array[String]) -> void:
	var atacante := EntityScript.new() as Entity
	atacante.name = "CombatTestAttacker"
	get_tree().root.add_child(atacante)

	var objetivo := EntityScript.new() as Entity
	objetivo.name = "CombatTestTarget"
	get_tree().root.add_child(objetivo)
	await get_tree().process_frame

	var combate := CombatSystemScript.new() as CombatSystem
	get_tree().root.add_child(combate)

	var contactos_sistema: Dictionary = {"cantidad": 0}
	combate.contacto_efectivo.connect(
		func(_atacante: Node, _objetivo: Entity, _origen: String) -> void:
			contactos_sistema["cantidad"] = int(contactos_sistema["cantidad"]) + 1
	)

	var ataque_cero := CombatAttackScript.new() as CombatAttack
	ataque_cero.configurar(
		atacante,
		Vector2.RIGHT,
		{},
		"distancia",
		0,
		"Prueba/DanioCero"
	)

	var proyectil_cero := CombatProjectileScript.new() as CombatProjectile
	proyectil_cero.configurar(ataque_cero, Vector2.RIGHT, 100.0, 1.0, 2.0)
	get_tree().root.add_child(proyectil_cero)
	var contactos_proyectil: Dictionary = {"cantidad": 0}
	var impactos_con_danio: Dictionary = {"cantidad": 0}
	proyectil_cero.contacto_detectado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			contactos_proyectil["cantidad"] = int(contactos_proyectil["cantidad"]) + 1
	)
	proyectil_cero.objetivo_impactado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			impactos_con_danio["cantidad"] = int(impactos_con_danio["cantidad"]) + 1
	)
	proyectil_cero.contacto_detectado.connect(combate._al_detectar_contacto_proyectil)

	var salud_inicial := objetivo.health
	proyectil_cero._procesar_objetivo(objetivo)

	if int(contactos_proyectil["cantidad"]) != 1:
		errores.append("El proyectil con daño cero no registró exactamente un contacto.")
	if int(contactos_sistema["cantidad"]) != 1:
		errores.append("CombatSystem no recibió el contacto de daño cero.")
	if int(impactos_con_danio["cantidad"]) != 0:
		errores.append("Un contacto sin daño emitió objetivo_impactado.")
	if objetivo.health != salud_inicial:
		errores.append("El proyectil de daño cero alteró la salud.")

	# El hitbox melee publica contacto aunque una herramienta no tenga daño.
	var area_melee := CombatAttackAreaScript.new() as CombatAttackArea
	area_melee.atacante = atacante
	area_melee.objeto_ataque = {
		"tipo": "herramienta",
		"nombre": "Herramienta de prueba",
		"propiedades_game": {"danio": 0}
	}
	combate._al_recibir_objetivo_de_ataque(objetivo, area_melee)
	if int(contactos_sistema["cantidad"]) != 2:
		errores.append("El contacto melee sin daño no se publicó.")
	if objetivo.health != salud_inicial:
		errores.append("El contacto melee sin daño alteró la salud.")
	area_melee.free()

	# La entrada de ataques de la IA también comunica contacto cero-daño.
	var danio_ia_aplicado := combate.aplicar_danio_desde_entidad(
		atacante,
		objetivo,
		0,
		"Prueba/IA"
	)
	if danio_ia_aplicado:
		errores.append("La ruta de daño de IA declaró daño aplicado con cantidad cero.")
	if int(contactos_sistema["cantidad"]) != 3:
		errores.append("La ruta de ataque de IA no publicó el contacto de daño cero.")
	if objetivo.health != salud_inicial:
		errores.append("La ruta de IA con daño cero alteró la salud.")

	var ataque_daniador := CombatAttackScript.new() as CombatAttack
	ataque_daniador.configurar(
		atacante,
		Vector2.RIGHT,
		{},
		"distancia",
		5,
		"Prueba/DanioReal"
	)
	var proyectil_daniador := CombatProjectileScript.new() as CombatProjectile
	proyectil_daniador.configurar(ataque_daniador, Vector2.RIGHT, 100.0, 1.0, 2.0)
	get_tree().root.add_child(proyectil_daniador)
	var impactos_reales: Dictionary = {"cantidad": 0}
	proyectil_daniador.objetivo_impactado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			impactos_reales["cantidad"] = int(impactos_reales["cantidad"]) + 1
	)
	proyectil_daniador.contacto_detectado.connect(combate._al_detectar_contacto_proyectil)
	proyectil_daniador._procesar_objetivo(objetivo)

	if int(impactos_reales["cantidad"]) != 1:
		errores.append("Un impacto con daño real no emitió objetivo_impactado.")
	if objetivo.health != salud_inicial - 5:
		errores.append("El daño real del proyectil no se aplicó exactamente una vez.")
	if int(contactos_sistema["cantidad"]) != 4:
		errores.append("El proyectil con daño real no publicó exactamente un contacto.")

	objetivo.restaurar_estado_vital(0, false)
	var contactos_antes_objetivo_muerto := int(contactos_sistema["cantidad"])
	combate.aplicar_danio_desde_entidad(atacante, objetivo, 5, "Prueba/ObjetivoMuerto")
	if int(contactos_sistema["cantidad"]) != contactos_antes_objetivo_muerto:
		errores.append("Un objetivo muerto generó un contacto nuevo.")

	atacante.queue_free()
	objetivo.queue_free()
	combate.queue_free()
	await get_tree().process_frame


func _probar_cancelacion_al_morir_atacante(errores: Array[String]) -> void:
	var atacante := EntityScript.new() as Entity
	var objetivo := EntityScript.new() as Entity
	atacante.name = "CombatTemporalDeadAttacker"
	objetivo.name = "CombatTemporalDeadAttackerTarget"
	get_tree().root.add_child(atacante)
	get_tree().root.add_child(objetivo)
	await get_tree().process_frame

	var contactos_melee := {"cantidad": 0}
	var area_melee := CombatAttackAreaScript.new() as CombatAttackArea
	area_melee.configurar(
		atacante,
		Vector2.RIGHT,
		32.0,
		24.0,
		{},
		0.5,
		Color.WHITE
	)
	area_melee.objetivo_detectado.connect(
		func(_objetivo: Entity) -> void:
			contactos_melee["cantidad"] = int(contactos_melee["cantidad"]) + 1
	)
	get_tree().root.add_child(area_melee)
	await get_tree().process_frame

	var ataque := CombatAttackScript.new() as CombatAttack
	ataque.configurar(
		atacante,
		Vector2.RIGHT,
		{},
		"distancia",
		8,
		"Prueba/AtacanteMuerto"
	)
	var proyectil := CombatProjectileScript.new() as CombatProjectile
	proyectil.configurar(ataque, Vector2.RIGHT, 100.0, 2.0, 2.0)
	get_tree().root.add_child(proyectil)
	var contactos_proyectil := {"cantidad": 0}
	var impactos_proyectil := {"cantidad": 0}
	proyectil.contacto_detectado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			contactos_proyectil["cantidad"] = int(contactos_proyectil["cantidad"]) + 1
	)
	proyectil.objetivo_impactado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			impactos_proyectil["cantidad"] = int(impactos_proyectil["cantidad"]) + 1
	)

	var salud_inicial := objetivo.health
	atacante.restaurar_estado_vital(0, false)
	area_melee._physics_process(0.016)
	area_melee._procesar_objetivo(objetivo)
	proyectil._physics_process(0.016)
	proyectil._procesar_objetivo(objetivo)

	if not area_melee.is_queued_for_deletion():
		errores.append("El hitbox melee no se canceló al morir su atacante.")
	if int(contactos_melee["cantidad"]) != 0:
		errores.append("El hitbox melee emitió contacto después de morir su atacante.")
	if not proyectil.is_queued_for_deletion():
		errores.append("El proyectil no se canceló al morir su atacante.")
	if int(contactos_proyectil["cantidad"]) != 0:
		errores.append("El proyectil emitió contacto después de morir su atacante.")
	if int(impactos_proyectil["cantidad"]) != 0:
		errores.append("El proyectil emitió impacto confirmado después de morir su atacante.")
	if objetivo.health != salud_inicial:
		errores.append("Un ataque pendiente aplicó daño después de morir su atacante.")

	area_melee.queue_free()
	proyectil.queue_free()
	atacante.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame


func _probar_impactos_simultaneos_y_atacante_invalido(errores: Array[String]) -> void:
	var atacante := EntityScript.new() as Entity
	var objetivo := EntityScript.new() as Entity
	atacante.name = "CombatSimultaneousAttacker"
	objetivo.name = "CombatSimultaneousTarget"
	get_tree().root.add_child(atacante)
	get_tree().root.add_child(objetivo)
	await get_tree().process_frame

	objetivo.restaurar_estado_vital(5, true)
	var combate := CombatSystemScript.new() as CombatSystem
	get_tree().root.add_child(combate)
	var contactos := {"cantidad": 0}
	var impactos := {"cantidad": 0}
	combate.contacto_efectivo.connect(
		func(_atacante: Node, _objetivo: Entity, _origen: String) -> void:
			contactos["cantidad"] = int(contactos["cantidad"]) + 1
	)
	combate.ataque_realizado.connect(
		func(_atacante: Node, _objetivo: Entity, _danio: int) -> void:
			impactos["cantidad"] = int(impactos["cantidad"]) + 1
	)

	var proyectiles: Array[CombatProjectile] = []
	for indice in range(2):
		var ataque := CombatAttackScript.new() as CombatAttack
		ataque.configurar(
			atacante,
			Vector2.RIGHT,
			{},
			"distancia",
			5,
			"Prueba/ImpactoSimultaneo" + str(indice)
		)
		var proyectil := CombatProjectileScript.new() as CombatProjectile
		proyectil.configurar(ataque, Vector2.RIGHT, 100.0, 1.0, 2.0)
		proyectil.contacto_detectado.connect(combate._al_detectar_contacto_proyectil)
		proyectil.objetivo_impactado.connect(combate._al_recibir_impacto_proyectil)
		get_tree().root.add_child(proyectil)
		proyectiles.append(proyectil)

	proyectiles[0]._procesar_objetivo(objetivo)
	proyectiles[1]._procesar_objetivo(objetivo)
	if objetivo.is_alive or objetivo.health != 0:
		errores.append("Los impactos simultáneos no dejaron al objetivo derrotado.")
	if int(contactos["cantidad"]) != 1:
		errores.append("Un segundo proyectil registró contacto contra un objetivo ya derrotado.")
	if int(impactos["cantidad"]) != 1:
		errores.append("Los efectos confirmados se ejecutaron más de una vez para una sola derrota.")

	var salud_antes := objetivo.health
	var contactos_antes := int(contactos["cantidad"])
	var impactos_antes := int(impactos["cantidad"])
	atacante.restaurar_estado_vital(0, false)
	var resultado := combate.solicitar_danio_desde_entidad(
		atacante,
		objetivo,
		10,
		"Prueba/AtacanteDerrotado"
	)
	if resultado.solicitud_aceptada:
		errores.append("La IA pudo solicitar daño con un atacante derrotado.")
	if objetivo.health != salud_antes:
		errores.append("Un atacante derrotado modificó la salud del objetivo.")
	if int(contactos["cantidad"]) != contactos_antes or int(impactos["cantidad"]) != impactos_antes:
		errores.append("Un atacante derrotado generó contacto o efectos.")

	var atacante_fuera_arbol := EntityScript.new() as Entity
	if CombatTargeting.es_atacante_valido(atacante_fuera_arbol):
		errores.append("Se aceptó un atacante Entity que todavía no pertenece al árbol.")
	if CombatTargeting.es_objetivo_valido(atacante_fuera_arbol, objetivo):
		errores.append("La validación de objetivo ignoró un atacante fuera del árbol.")
	objetivo.restaurar_estado_vital(5, true)
	var resultado_fuera_arbol := combate.solicitar_danio_desde_entidad(
		atacante_fuera_arbol,
		objetivo,
		5,
		"Prueba/AtacanteFueraDelArbol"
	)
	if resultado_fuera_arbol.solicitud_aceptada:
		errores.append("La ruta de IA aceptó un atacante fuera del árbol.")
	if objetivo.health != 5:
		errores.append("Un atacante fuera del árbol alteró la salud del objetivo.")
	atacante_fuera_arbol.free()

	# Un listener de contacto puede derrotar al atacante en la misma emisión.
	atacante.restaurar_estado_vital(100, true)
	var ataque_interrumpido := CombatAttackScript.new() as CombatAttack
	ataque_interrumpido.configurar(
		atacante,
		Vector2.RIGHT,
		{},
		"distancia",
		5,
		"Prueba/MuerteDuranteContacto"
	)
	var proyectil_interrumpido := CombatProjectileScript.new() as CombatProjectile
	proyectil_interrumpido.configurar(ataque_interrumpido, Vector2.RIGHT, 100.0, 1.0, 2.0)
	proyectil_interrumpido.contacto_detectado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			atacante.restaurar_estado_vital(0, false)
	)
	var impactos_interrumpidos := {"cantidad": 0}
	proyectil_interrumpido.objetivo_impactado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			impactos_interrumpidos["cantidad"] = int(impactos_interrumpidos["cantidad"]) + 1
	)
	get_tree().root.add_child(proyectil_interrumpido)
	var salud_antes_interrupcion := objetivo.health
	proyectil_interrumpido._procesar_objetivo(objetivo)
	if objetivo.health != salud_antes_interrupcion:
		errores.append("El proyectil aplicó daño después de que el atacante murió durante el contacto.")
	if int(impactos_interrumpidos["cantidad"]) != 0:
		errores.append("El proyectil emitió impacto confirmado tras morir el atacante durante el contacto.")
	if not proyectil_interrumpido.is_queued_for_deletion():
		errores.append("El proyectil interrumpido no finalizó su ciclo de vida.")

	# La expiración también debe cerrar el proyectil y bloquear colisiones tardías.
	atacante.restaurar_estado_vital(100, true)
	var ataque_expirado := CombatAttackScript.new() as CombatAttack
	ataque_expirado.configurar(
		atacante,
		Vector2.RIGHT,
		{},
		"distancia",
		5,
		"Prueba/Expiracion"
	)
	var proyectil_expirado := CombatProjectileScript.new() as CombatProjectile
	proyectil_expirado.configurar(ataque_expirado, Vector2.RIGHT, 100.0, 0.05, 2.0)
	get_tree().root.add_child(proyectil_expirado)
	proyectil_expirado._physics_process(0.1)
	if not proyectil_expirado.is_queued_for_deletion():
		errores.append("El proyectil no se liberó al expirar su vida útil.")
	proyectil_expirado._procesar_objetivo(objetivo)
	if objetivo.health != salud_antes_interrupcion:
		errores.append("Un proyectil expirado todavía pudo aplicar daño.")

	proyectil_interrumpido.queue_free()
	proyectil_expirado.queue_free()
	for proyectil in proyectiles:
		proyectil.queue_free()
	combate.queue_free()
	atacante.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame


func _probar_danio_jugador_con_armadura(errores: Array[String]) -> void:
	# La escena real de inventario alimenta el mismo contrato que usa Player.
	var jugador := PlayerScene.instantiate() as Player
	var inventario := InventoryScene.instantiate() as GarliaInventory
	get_tree().root.add_child(jugador)
	get_tree().root.add_child(inventario)
	await get_tree().process_frame
	jugador.configurar_dependencias(inventario)

	var armadura := {
		"id": "armor_test",
		"tipo": "armadura",
		"propiedades_game": {"ranura_equipamiento": "torso", "durabilidad": 5},
		"durabilidad_actual": 5,
		"estadisticas": {"defensa": 3}
	}
	inventario.inventory_controller.runtime.equipar("torso", armadura)

	var muertes_normales := {"cantidad": 0}
	jugador.died.connect(func() -> void:
		muertes_normales["cantidad"] = int(muertes_normales["cantidad"]) + 1
	)

	# El dash concede invulnerabilidad solo durante su estado activo.
	var vida_antes_dash := jugador.health
	jugador.state = Player.State.DASH
	jugador.take_damage(10, "Prueba/Dash")
	if jugador.health != vida_antes_dash:
		errores.append("El jugador recibió daño durante el dash.")
	jugador.state = Player.State.IDLE

	jugador.take_damage(10, "Prueba/Armadura")
	if jugador.health != 93:
		errores.append("Player no aplicó la defensa equipada al daño normal.")
	if int(muertes_normales["cantidad"]) != 0:
		errores.append("Un impacto no letal emitió la muerte del jugador.")
	var armadura_despues_golpe := inventario.inventory_controller.runtime.obtener_equipo("torso")
	if int(armadura_despues_golpe.get("durabilidad_actual", -1)) != 5:
		errores.append("Recibir daño consumió durabilidad de la armadura.")

	# Un golpe letal debe sincronizar el estado y emitir la muerte una sola vez.
	jugador.locomotion.actions.dash_cooldown_timer = 4.0
	jugador.restaurar_estado_vital(4, true)
	jugador.take_damage(10, "Prueba/MuerteNormal")
	jugador.take_damage(10, "Prueba/MuerteRepetida")
	if jugador.health != 0 or jugador.is_alive:
		errores.append("El daño letal no dejó al jugador normal en estado muerto.")
	if int(muertes_normales["cantidad"]) != 1:
		errores.append("La ruta de vida normal emitió la muerte más de una vez.")

	# Una reaparición inmediata debe cancelar la animación de muerte anterior.
	jugador.reaparecer()
	if not jugador.is_alive or jugador.health != jugador.max_health:
		errores.append("La reaparición no restauró la vida del jugador.")
	if not jugador.is_physics_processing() or jugador.state != Player.State.IDLE:
		errores.append("La reaparición no restauró el procesamiento y el estado de movimiento.")
	if jugador.locomotion.procesando_accion():
		errores.append("La reaparición conservó una acción temporal activa.")
	if jugador.locomotion.actions.dash_cooldown_timer != 0.0:
		errores.append("La reaparición conservó el cooldown del dash.")
	await get_tree().create_timer(0.4).timeout
	if not is_equal_approx(jugador.visual.modulate.a, 1.0):
		errores.append("El tween de muerte anterior ocultó al jugador después de reaparecer.")
	if not jugador.visual.scale.is_equal_approx(Vector2.ONE):
		errores.append("El tween de muerte anterior alteró la escala tras reaparecer.")

	jugador.queue_free()
	inventario.queue_free()
	await get_tree().process_frame

	# Repetir el recorrido con vida y Eterium compartidos.
	var jugador_compartido := PlayerScene.instantiate() as Player
	var inventario_compartido := InventoryScene.instantiate() as GarliaInventory
	get_tree().root.add_child(jugador_compartido)
	get_tree().root.add_child(inventario_compartido)
	await get_tree().process_frame
	jugador_compartido.configurar_dependencias(inventario_compartido)
	jugador_compartido.eterium.aplicar_runtime(
		{"limite_estable_s": 100.0, "escala_runtime": 1.0},
		[]
	)
	if not jugador_compartido.eterium.aplicar_especie(
		{
			"especie_eterium_v1": {
				"especie_id": "shared_test",
				"capacidad_base": 100
			},
			"vida_eterium_compartidos": true
		},
		"shared_test"
	):
		errores.append("No pudo configurar la fisiología de vida/Eterium compartidos.")
		jugador_compartido.queue_free()
		inventario_compartido.queue_free()
		await get_tree().process_frame
		return

	inventario_compartido.inventory_controller.runtime.equipar("torso", armadura)
	var muertes_compartidas := {"cantidad": 0}
	jugador_compartido.died.connect(func() -> void:
		muertes_compartidas["cantidad"] = int(muertes_compartidas["cantidad"]) + 1
	)

	jugador_compartido.eterium.establecer_mana(20)
	jugador_compartido.take_damage(10, "Prueba/ArmaduraEterium")
	if jugador_compartido.mana != 13 or jugador_compartido.health != 13:
		errores.append("La armadura no mitigó el daño con vida/Eterium compartidos.")

	jugador_compartido.eterium.establecer_mana(4)
	jugador_compartido.take_damage(10, "Prueba/MuerteEterium")
	jugador_compartido.take_damage(10, "Prueba/MuerteEteriumRepetida")
	if jugador_compartido.mana != 0 or jugador_compartido.health != 0:
		errores.append("La ruta compartida no sincronizó Eterium y vida al recibir daño.")
	if jugador_compartido.is_alive:
		errores.append("La ruta compartida no marcó muerto al agotar Eterium.")
	if int(muertes_compartidas["cantidad"]) != 1:
		errores.append("La ruta compartida emitió la muerte más de una vez.")

	jugador_compartido.queue_free()
	inventario_compartido.queue_free()
	await get_tree().process_frame


func _probar_pausa_recuperacion_eterium(errores: Array[String]) -> void:
	var vital := VitalStateScript.new() as VitalState
	var runtime := EteriumRuntimeScript.new() as PlayerEteriumRuntime
	runtime.configurar_vital(vital)
	runtime.aplicar_runtime(
		{
			"limite_estable_s": 10.0,
			"escala_runtime": 1.0,
			"recuperacion_pasiva_s_por_segundo": 1.0
		},
		[]
	)

	# Si otra fuente llena el recurso, el progreso que existía se pausa.
	runtime.establecer_mana(9)
	runtime.recovery_accumulator = 0.25
	if runtime.absorber(1) != 1:
		errores.append("La absorción de prueba no completó la unidad de Eterium.")
	if not is_equal_approx(runtime.recovery_accumulator, 0.25):
		errores.append("La absorción borró el progreso previo de recuperación.")
		return

	runtime.actualizar_recuperacion(3.0, true)
	if not is_equal_approx(runtime.recovery_accumulator, 0.25):
		errores.append("El reloj avanzó o se reinició mientras el recurso lleno estaba pausado.")
		return

	if not runtime.gastar(1):
		errores.append("No se pudo gastar Eterium para probar la reanudación.")
		return
	runtime.actualizar_recuperacion(0.74, true)
	if runtime.mana() != 9:
		errores.append("El progreso conservado se consumió antes de completar una unidad.")
		return
	var recuperadas := runtime.actualizar_recuperacion(0.02, true)
	if recuperadas != 1 or runtime.mana() != 10:
		errores.append("La recuperación no reanudó el progreso conservado tras gastar Eterium.")
		return
	if not is_equal_approx(runtime.recovery_accumulator, 0.0):
		errores.append("El tick pasivo que alcanza el máximo dejó tiempo acumulado después del llenado.")

	# Si la recuperación pasiva llena el recurso, el tick termina en el máximo
	# y el tiempo restante del mismo delta no debe quedar almacenado.
	runtime.establecer_mana(9)
	runtime.recovery_accumulator = 0.5
	recuperadas = runtime.actualizar_recuperacion(0.75, true)
	if recuperadas != 1 or runtime.mana() != 10:
		errores.append("La recuperación pasiva no alcanzó el máximo.")
	if not is_equal_approx(runtime.recovery_accumulator, 0.0):
		errores.append("Se conservó tiempo que correspondía al periodo posterior al llenado.")

	# Un delta largo no debe almacenar turnos completos ocurridos después
	# de que la recuperación alcanzó el máximo.
	runtime.establecer_mana(9)
	runtime.recovery_accumulator = 0.0
	runtime.actualizar_recuperacion(5.0, true)
	if runtime.mana() != 10:
		errores.append("Un delta grande no llenó el recurso hasta su máximo.")
	if not is_equal_approx(runtime.recovery_accumulator, 0.0):
		errores.append("Se acumularon turnos completos después de alcanzar el máximo.")
