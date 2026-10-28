extends SceneTree

const EntityScript = preload("res://scripts/characters/entity.gd")
const CombatAttackScript = preload("res://scripts/gameplay/combat/combat_attack.gd")
const CombatProjectileScript = preload("res://scripts/gameplay/combat/combat_projectile.gd")
const CombatAttackAreaScript = preload("res://scripts/gameplay/combat/combat_attack_area.gd")
const CombatSystemScript = preload("res://scripts/gameplay/combat_system.gd")
const EteriumRuntimeScript = preload("res://scripts/gameplay/player/player_eterium_runtime.gd")
const VitalStateScript = preload("res://scripts/state/vital_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	await _probar_contacto_independiente_del_danio(errores)
	_probar_pausa_recuperacion_eterium(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatTemporalContract: FAIL: " + error)
		quit(1)
		return

	print("CombatTemporalContract: PASS")
	quit(0)


func _probar_contacto_independiente_del_danio(errores: Array[String]) -> void:
	var atacante := EntityScript.new() as Entity
	atacante.name = "CombatTestAttacker"
	root.add_child(atacante)

	var objetivo := EntityScript.new() as Entity
	objetivo.name = "CombatTestTarget"
	root.add_child(objetivo)
	await process_frame

	var combate := CombatSystemScript.new() as CombatSystem
	root.add_child(combate)

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
	root.add_child(proyectil_cero)
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
	root.add_child(proyectil_daniador)
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
