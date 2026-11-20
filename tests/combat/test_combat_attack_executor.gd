extends Node

const PlayerScene = preload("res://scenes/characters/player.tscn")
const Executor = preload("res://scripts/gameplay/combat/combat_attack_executor.gd")
const EntityScript = preload("res://scripts/characters/entity.gd")
const CombatSystemScript = preload("res://scripts/gameplay/combat_system.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	await _probar_creacion_melee(errores)
	await _probar_creacion_proyectil(errores)
	await _probar_melee_con_multiples_objetivos(errores)
	await _probar_colision_melee_fisica(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatAttackExecutor: FAIL: " + error)
		get_tree().quit(1)
		return

	print("CombatAttackExecutor: PASS")
	get_tree().quit(0)


func _probar_creacion_melee(errores: Array[String]) -> void:
	var jugador := PlayerScene.instantiate() as Player
	get_tree().root.add_child(jugador)
	await get_tree().process_frame

	var objeto := {
		"tipo": "herramienta",
		"nombre": "Martillo de prueba",
		"propiedades_game": {"danio": 0}
	}
	var direccion := Vector2.LEFT
	var ataque: CombatAttackArea = Executor.crear_ataque_melee(
		jugador,
		direccion,
		52.0,
		28.0,
		objeto,
		0.25,
		Color(0.8, 0.6, 0.4, 0.5),
		7,
		Callable(self, "_al_detectar_objetivo_melee")
	)

	if ataque == null:
		errores.append("No creó un CombatAttackArea para un Player válido.")
	else:
		if ataque.get_parent() != jugador:
			errores.append("El hitbox melee no quedó como hijo del atacante.")
		if not is_equal_approx(ataque.rotation, direccion.angle()):
			errores.append("El hitbox melee no conservó la dirección recibida.")
		if not is_equal_approx(ataque.duracion, 0.25):
			errores.append("El hitbox melee no conservó su duración.")
		if int(ataque.objeto_ataque.get("_damage_override", -1)) != 7:
			errores.append("El hitbox melee no conservó el daño directo.")
		if ataque.objetivo_detectado.get_connections().size() != 1:
			errores.append("El hitbox melee no conectó su callback de objetivo.")

	jugador.queue_free()
	await get_tree().process_frame


func _probar_creacion_proyectil(errores: Array[String]) -> void:
	var jugador := PlayerScene.instantiate() as Player
	var raiz_proyectiles := Node2D.new()
	get_tree().root.add_child(jugador)
	get_tree().root.add_child(raiz_proyectiles)
	await get_tree().process_frame

	jugador.global_position = Vector2(30.0, 45.0)
	var direccion := Vector2.RIGHT
	var objeto := {
		"tipo": "arma",
		"nombre": "Arco de prueba",
		"categoria": "arco"
	}
	var proyectil: CombatProjectile = Executor.disparar_proyectil(
		jugador,
		raiz_proyectiles,
		direccion,
		objeto,
		240.0,
		2.5,
		8.0,
		13,
		Callable(self, "_al_detectar_contacto_proyectil"),
		Callable(self, "_al_recibir_impacto_proyectil")
	)

	if proyectil == null:
		errores.append("No creó un CombatProjectile con dependencias válidas.")
	else:
		if proyectil.get_parent() != raiz_proyectiles:
			errores.append("El proyectil no quedó dentro del root inyectado.")
		if proyectil.attack == null:
			errores.append("El proyectil no recibió su instancia CombatAttack.")
		else:
			if proyectil.attack.attacker != jugador:
				errores.append("El ataque del proyectil perdió al atacante.")
			if proyectil.attack.object_data != objeto:
				errores.append("El ataque del proyectil alteró los datos del objeto.")
			if proyectil.attack.damage != 13:
				errores.append("El ataque del proyectil no conservó el daño.")
			if proyectil.attack.mode != "distancia":
				errores.append("El ataque no quedó marcado como distancia.")
		if not proyectil.global_position.is_equal_approx(jugador.global_position + direccion * 14.0):
			errores.append("El proyectil no conservó su posición inicial.")
		if not proyectil.velocity.is_equal_approx(direccion * 240.0):
			errores.append("El proyectil no conservó velocidad/dirección.")
		if not is_equal_approx(proyectil.lifetime, 2.5):
			errores.append("El proyectil no conservó su tiempo de vida.")
		if proyectil.contacto_detectado.get_connections().size() != 1:
			errores.append("El proyectil no conectó el callback de contacto.")
		if proyectil.objetivo_impactado.get_connections().size() != 1:
			errores.append("El proyectil no conectó el callback de impacto.")

	jugador.queue_free()
	raiz_proyectiles.queue_free()
	await get_tree().process_frame


func _probar_melee_con_multiples_objetivos(errores: Array[String]) -> void:
	var jugador := PlayerScene.instantiate() as Player
	var combate := CombatSystemScript.new() as CombatSystem
	var objetivo_a := EntityScript.new() as Entity
	var objetivo_b := EntityScript.new() as Entity
	jugador.name = "MeleeMultiTargetAttacker"
	objetivo_a.name = "MeleeMultiTargetA"
	objetivo_b.name = "MeleeMultiTargetB"
	combate.player = jugador
	get_tree().root.add_child(jugador)
	get_tree().root.add_child(combate)
	get_tree().root.add_child(objetivo_a)
	get_tree().root.add_child(objetivo_b)
	await get_tree().process_frame

	var arma := {
		"tipo": "arma",
		"nombre": "Espada de prueba",
		"propiedades_game": {"danio": 7}
	}
	var area := CombatAttackArea.new()
	area.configurar(
		jugador,
		Vector2.RIGHT,
		64.0,
		40.0,
		arma,
		0.1,
		Color(0.8, 0.6, 0.4, 0.5)
	)
	area.objetivo_detectado.connect(
		func(objetivo: Entity) -> void:
			combate._al_recibir_objetivo_de_ataque(objetivo, area)
	)
	jugador.add_child(area)

	var salud_a := objetivo_a.health
	var salud_b := objetivo_b.health
	area._procesar_objetivo(objetivo_a)
	area._procesar_objetivo(objetivo_b)
	area._procesar_objetivo(objetivo_a)

	if objetivo_a.health != salud_a - 7:
		errores.append("El ataque melee no dañó exactamente una vez al primer objetivo.")
	if objetivo_b.health != salud_b - 7:
		errores.append("El mismo ataque melee no pudo afectar a un segundo objetivo válido.")
	if area._afectados.size() != 2:
		errores.append("El hitbox no deduplicó objetivos sin bloquear objetivos distintos.")

	combate.queue_free()
	jugador.queue_free()
	objetivo_a.queue_free()
	objetivo_b.queue_free()
	await get_tree().process_frame


func _al_detectar_objetivo_melee(_objetivo: Entity, _ataque: CombatAttackArea) -> void:
	pass


func _al_detectar_contacto_proyectil(_objetivo: Entity, _ataque: CombatAttack) -> void:
	pass


func _al_recibir_impacto_proyectil(_objetivo: Entity, _ataque: CombatAttack) -> void:
	pass


func _probar_colision_melee_fisica(errores: Array[String]) -> void:
	var jugador := PlayerScene.instantiate() as Player
	var objetivo := EntityScript.new() as Entity
	jugador.name = "MeleePhysicsAttacker"
	jugador.global_position = Vector2.ZERO
	objetivo.name = "MeleePhysicsTarget"
	var colision := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(12.0, 12.0)
	colision.shape = forma
	objetivo.add_child(colision)
	objetivo.position = Vector2(40.0, 0.0)
	get_tree().root.add_child(jugador)
	get_tree().root.add_child(objetivo)
	await get_tree().physics_frame

	var combate := CombatSystemScript.new() as CombatSystem
	combate.player = jugador
	get_tree().root.add_child(combate)
	var area := CombatAttackArea.new()
	area.configurar(
		jugador,
		Vector2.RIGHT,
		64.0,
		32.0,
		{"nombre": "Melee físico", "propiedades_game": {"danio": 0}},
		0.2,
		Color(0.8, 0.6, 0.4, 0.5)
	)
	area.objetivo_detectado.connect(
		func(entidad: Entity) -> void:
			combate._al_recibir_objetivo_de_ataque(entidad, area)
	)
	jugador.add_child(area)
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("MeleePhysics debug: player=", jugador.global_position, " target=", objetivo.global_position, " hitbox=", area.global_position, " target_children=", objetivo.get_children(), " collision=", objetivo.get_node_or_null("CollisionShape2D"), " overlapping=", area._area.get_overlapping_areas(), " hurtbox=", objetivo.get_node_or_null("Hurtbox"))

	if objetivo.health != objetivo.max_health - combate.danio_desarmado:
		errores.append("El hitbox melee no detectó el hurtbox real durante la simulación física.")

	combate.queue_free()
	jugador.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame
