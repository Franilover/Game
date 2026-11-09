extends Node

const EntityScript = preload("res://scripts/characters/entity.gd")
const CombatSystemScript = preload("res://scripts/gameplay/combat_system.gd")
const Validator = preload("res://scripts/gameplay/combat/combat_weapon_attack_validator.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	_probar_validacion(errores)
	await _probar_resultados_de_ejecucion(errores)
	if not errores.is_empty():
		for error in errores:
			push_error("CombatWeaponAttackContract: FAIL: " + error)
		get_tree().quit(1)
		return
	print("CombatWeaponAttackContract: PASS")
	get_tree().quit(0)


func _probar_validacion(errores: Array[String]) -> void:
	var atacante := Node.new()
	var objetivo := EntityScript.new() as Entity
	var arma := {
		"tipo": "arma",
		"nombre": "Arma de prueba",
		"propiedades_game": {"danio": 5}
	}
	if Validator.validar(null, objetivo, arma) != &"atacante_invalido":
		errores.append("No rechazó un atacante nulo.")
	if Validator.validar(atacante, null, arma) != &"objetivo_invalido":
		errores.append("No rechazó un objetivo nulo.")
	if Validator.validar(atacante, objetivo, {}) != &"arma_vacia":
		errores.append("No rechazó una ficha de arma vacía.")
	if Validator.validar(atacante, objetivo, {"tipo": "herramienta"}) != &"objeto_no_es_arma":
		errores.append("No rechazó una herramienta como arma.")
	if Validator.validar(atacante, objetivo, arma) != &"":
		errores.append("Rechazó una solicitud válida.")
	objetivo.is_alive = false
	if Validator.validar(atacante, objetivo, arma) != &"objetivo_derrotado":
		errores.append("No rechazó un objetivo derrotado.")
	atacante.free()
	objetivo.free()


func _probar_resultados_de_ejecucion(errores: Array[String]) -> void:
	var atacante := EntityScript.new() as Entity
	var objetivo := EntityScript.new() as Entity
	var combate := CombatSystemScript.new() as CombatSystem
	atacante.name = "WeaponAttackContractAttacker"
	objetivo.name = "WeaponAttackContractTarget"
	get_tree().root.add_child(atacante)
	get_tree().root.add_child(objetivo)
	get_tree().root.add_child(combate)
	await get_tree().process_frame

	combate.danio_arma_defecto = 0
	var contactos := {"cantidad": 0}
	var ataques_con_danio := {"cantidad": 0}
	combate.contacto_efectivo.connect(
		func(_atacante: Node, _objetivo: Entity, _origen: String) -> void:
			contactos["cantidad"] = int(contactos["cantidad"]) + 1
	)
	combate.ataque_realizado.connect(
		func(_atacante: Node, _objetivo: Entity, _danio: int) -> void:
			ataques_con_danio["cantidad"] = int(ataques_con_danio["cantidad"]) + 1
	)

	var salud_inicial := objetivo.health
	var arma_sin_danio := {
		"tipo": "arma",
		"nombre": "Arma sin daño",
		"propiedades_game": {"danio": 0}
	}
	var resultado_sin_danio: CombatAttackResult = combate.solicitar_ataque_con_arma(atacante, objetivo, arma_sin_danio)
	if not resultado_sin_danio.solicitud_aceptada:
		errores.append("Una solicitud válida de daño cero no fue aceptada.")
	if not resultado_sin_danio.contacto_registrado:
		errores.append("El contacto de daño cero no quedó explícito en el resultado.")
	if resultado_sin_danio.danio_aplicado:
		errores.append("El resultado declaró daño aplicado con una cantidad cero.")
	if objetivo.health != salud_inicial:
		errores.append("La solicitud de daño cero alteró la salud.")
	if int(contactos["cantidad"]) != 1:
		errores.append("La solicitud aceptada no publicó exactamente un contacto.")
	if int(ataques_con_danio["cantidad"]) != 0:
		errores.append("La solicitud de daño cero publicó un ataque con daño.")

	var arma_daniadora := {
		"tipo": "arma",
		"nombre": "Arma de siete puntos",
		"propiedades_game": {"danio": 7}
	}
	var resultado_con_danio: CombatAttackResult = combate.solicitar_ataque_con_arma(atacante, objetivo, arma_daniadora)
	if not resultado_con_danio.solicitud_aceptada:
		errores.append("La solicitud con daño real no fue aceptada.")
	if not resultado_con_danio.contacto_registrado:
		errores.append("El contacto con daño real no quedó registrado.")
	if not resultado_con_danio.danio_aplicado:
		errores.append("El resultado no informó el daño realmente aplicado.")
	if objetivo.health != salud_inicial - 7:
		errores.append("La solicitud con daño real no redujo la salud exactamente en siete.")
	if int(contactos["cantidad"]) != 2:
		errores.append("Las dos solicitudes válidas no publicaron dos contactos.")
	if int(ataques_con_danio["cantidad"]) != 1:
		errores.append("El ataque con daño real no publicó exactamente un evento de daño.")

	objetivo.restaurar_estado_vital(0, false)
	var contactos_antes_objetivo_derrotado := int(contactos["cantidad"])
	var resultado_derrotado: CombatAttackResult = combate.solicitar_ataque_con_arma(atacante, objetivo, arma_daniadora)
	if resultado_derrotado.solicitud_aceptada:
		errores.append("La solicitud contra un objetivo derrotado fue aceptada.")
	if resultado_derrotado.motivo_rechazo != &"objetivo_derrotado":
		errores.append("El rechazo no identificó al objetivo derrotado.")
	if int(contactos["cantidad"]) != contactos_antes_objetivo_derrotado:
		errores.append("Un objetivo derrotado produjo un contacto.")

	combate.queue_free()
	atacante.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame
