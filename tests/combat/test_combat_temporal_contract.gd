extends SceneTree

const EntityScript = preload("res://scripts/characters/entity.gd")
const CombatAttackScript = preload("res://scripts/gameplay/combat/combat_attack.gd")
const CombatProjectileScript = preload("res://scripts/gameplay/combat/combat_projectile.gd")
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
	proyectil_daniador._procesar_objetivo(objetivo)

	if int(impactos_reales["cantidad"]) != 1:
		errores.append("Un impacto con daño real no emitió objetivo_impactado.")
	if objetivo.health != salud_inicial - 5:
		errores.append("El daño real del proyectil no se aplicó exactamente una vez.")

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
	runtime.establecer_mana(9)

	runtime.actualizar_recuperacion(0.5, true)
	var recuperadas := runtime.actualizar_recuperacion(0.75, true)
	if recuperadas != 1 or runtime.mana() != runtime.max_mana():
		errores.append("La recuperación base no alcanzó el máximo como se esperaba.")
	if not is_equal_approx(runtime.recovery_accumulator, 0.25):
		errores.append("La prueba no dejó el progreso fraccionario esperado al llegar al máximo.")
		return

	runtime.actualizar_recuperacion(3.0, true)
	if not is_equal_approx(runtime.recovery_accumulator, 0.25):
		errores.append("El reloj de Eterium acumuló o perdió progreso mientras estaba al máximo.")
		return

	if not runtime.gastar(1):
		errores.append("No se pudo gastar Eterium para probar la reanudación.")
		return
	runtime.actualizar_recuperacion(0.74, true)
	if runtime.mana() != 9:
		errores.append("El progreso conservado se consumió antes de completar una unidad.")
		return
	recuperadas = runtime.actualizar_recuperacion(0.02, true)
	if recuperadas != 1 or runtime.mana() != 10:
		errores.append("La recuperación no reanudó el progreso conservado tras gastar Eterium.")
