extends Node

const EntityScript = preload("res://scripts/characters/entity.gd")
const ProjectileScript = preload("res://scripts/gameplay/combat/combat_projectile.gd")
const AttackScript = preload("res://scripts/gameplay/combat/combat_attack.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	await _probar_impacto_real_y_unico(errores)
	await _probar_contacto_con_danio_cero(errores)
	await _probar_barrido_fisico(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatProjectileContract: FAIL: " + error)
		get_tree().quit(1)
		return

	print("CombatProjectileContract: PASS")
	get_tree().quit(0)


func _crear_entidades() -> Array[Entity]:
	var atacante := EntityScript.new() as Entity
	var objetivo := EntityScript.new() as Entity
	atacante.name = "ProjectileContractAttacker"
	objetivo.name = "ProjectileContractTarget"
	get_tree().root.add_child(atacante)
	get_tree().root.add_child(objetivo)
	await get_tree().process_frame
	return [atacante, objetivo]


func _crear_proyectil(atacante: Entity, danio: int) -> CombatProjectile:
	var ataque := AttackScript.new()
	ataque.configurar(
		atacante,
		Vector2.RIGHT,
		{"nombre": "Proyectil de prueba"},
		"distancia",
		danio,
		"Prueba/Proyectil"
	)
	var proyectil := ProjectileScript.new() as CombatProjectile
	proyectil.configurar(ataque, Vector2.RIGHT, 100.0, 2.0, 5.0)
	get_tree().root.add_child(proyectil)
	return proyectil


func _probar_impacto_real_y_unico(errores: Array[String]) -> void:
	var entidades := await _crear_entidades()
	var atacante := entidades[0]
	var objetivo := entidades[1]
	var proyectil := _crear_proyectil(atacante, 12)
	await get_tree().process_frame

	var eventos := {"contactos": 0, "impactos": 0}
	proyectil.contacto_detectado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			eventos["contactos"] = int(eventos["contactos"]) + 1
	)
	proyectil.objetivo_impactado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			eventos["impactos"] = int(eventos["impactos"]) + 1
	)

	var salud_inicial := objetivo.health
	proyectil._procesar_objetivo(objetivo)
	if objetivo.health != salud_inicial - 12:
		errores.append("El impacto no aplicó exactamente el daño configurado.")
	if int(eventos["contactos"]) != 1:
		errores.append("El contacto válido no se notificó exactamente una vez.")
	if int(eventos["impactos"]) != 1:
		errores.append("El impacto efectivo no se notificó exactamente una vez.")

	proyectil._procesar_objetivo(objetivo)
	if objetivo.health != salud_inicial - 12:
		errores.append("El mismo proyectil pudo dañar dos veces al mismo objetivo.")
	if int(eventos["contactos"]) != 1 or int(eventos["impactos"]) != 1:
		errores.append("El proyectil repitió señales después de quedar impactado.")

	proyectil.queue_free()
	atacante.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame


func _probar_contacto_con_danio_cero(errores: Array[String]) -> void:
	var entidades := await _crear_entidades()
	var atacante := entidades[0]
	var objetivo := entidades[1]
	var proyectil := _crear_proyectil(atacante, 0)
	await get_tree().process_frame

	var eventos := {"contactos": 0, "impactos": 0}
	proyectil.contacto_detectado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			eventos["contactos"] = int(eventos["contactos"]) + 1
	)
	proyectil.objetivo_impactado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			eventos["impactos"] = int(eventos["impactos"]) + 1
	)

	var salud_inicial := objetivo.health
	proyectil._procesar_objetivo(objetivo)
	if objetivo.health != salud_inicial:
		errores.append("Un proyectil con daño cero modificó la salud.")
	if int(eventos["contactos"]) != 1:
		errores.append("El proyectil de daño cero no registró el contacto.")
	if int(eventos["impactos"]) != 0:
		errores.append("El proyectil de daño cero informó un impacto efectivo.")

	proyectil.queue_free()
	atacante.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame


func _probar_barrido_fisico(errores: Array[String]) -> void:
	var atacante := EntityScript.new() as Entity
	var objetivo := EntityScript.new() as Entity
	atacante.name = "ProjectileSweepAttacker"
	objetivo.name = "ProjectileSweepTarget"

	var colision := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(12.0, 12.0)
	colision.shape = forma
	objetivo.add_child(colision)
	objetivo.position = Vector2(50.0, 0.0)

	get_tree().root.add_child(atacante)
	get_tree().root.add_child(objetivo)
	await get_tree().physics_frame

	var proyectil := _crear_proyectil(atacante, 9)
	proyectil.global_position = Vector2.ZERO
	proyectil.velocity = Vector2(1000.0, 0.0)
	await get_tree().physics_frame

	var impactos := {"cantidad": 0}
	proyectil.objetivo_impactado.connect(
		func(_objetivo: Entity, _ataque: CombatAttack) -> void:
			impactos["cantidad"] = int(impactos["cantidad"]) + 1
	)

	var salud_inicial := objetivo.health
	var hurtbox := objetivo.get_node_or_null("Hurtbox") as Area2D
	var consulta_prueba := PhysicsRayQueryParameters2D.create(
		Vector2(16.0, 0.0),
		Vector2(116.0, 0.0),
		2
	)
	consulta_prueba.collide_with_areas = true
	consulta_prueba.collide_with_bodies = true
	print("ProjectileSweep debug: hurtbox=", hurtbox, " layer=", hurtbox.collision_layer if hurtbox != null else -1, " ray=", get_viewport().world_2d.direct_space_state.intersect_ray(consulta_prueba))
	# El proyectil recorre 100 px en un solo paso: el volumen de colisión del
	# objetivo mide 12 px. Sin barrido, el movimiento discreto lo atravesaría.
	proyectil._physics_process(0.1)
	if objetivo.health != salud_inicial - 9:
		errores.append("El barrido físico no detectó un hurtbox atravesado a alta velocidad.")
	if int(impactos["cantidad"]) != 1:
		errores.append("El barrido físico no emitió exactamente un impacto confirmado.")

	if is_instance_valid(proyectil) and not proyectil.is_queued_for_deletion():
		proyectil.queue_free()
	atacante.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame
