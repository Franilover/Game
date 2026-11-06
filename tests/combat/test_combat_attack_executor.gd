extends SceneTree

const PlayerScene = preload("res://scenes/characters/player.tscn")
const Executor = preload("res://scripts/gameplay/combat/combat_attack_executor.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	await _probar_creacion_melee(errores)
	await _probar_creacion_proyectil(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatAttackExecutor: FAIL: " + error)
		quit(1)
		return

	print("CombatAttackExecutor: PASS")
	quit(0)


func _probar_creacion_melee(errores: Array[String]) -> void:
	var jugador := PlayerScene.instantiate() as Player
	get_root().add_child(jugador)
	await process_frame

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
	await process_frame


func _probar_creacion_proyectil(errores: Array[String]) -> void:
	var jugador := PlayerScene.instantiate() as Player
	var raiz_proyectiles := Node2D.new()
	get_root().add_child(jugador)
	get_root().add_child(raiz_proyectiles)
	await process_frame

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
	await process_frame


func _al_detectar_objetivo_melee(_objetivo: Entity, _ataque: CombatAttackArea) -> void:
	pass


func _al_detectar_contacto_proyectil(_objetivo: Entity, _ataque: CombatAttack) -> void:
	pass


func _al_recibir_impacto_proyectil(_objetivo: Entity, _ataque: CombatAttack) -> void:
	pass
