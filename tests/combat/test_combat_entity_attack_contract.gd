extends Node

const EntityScript = preload("res://scripts/characters/entity.gd")
const CombatSystemScript = preload("res://scripts/gameplay/combat_system.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	await _probar_solicitud_generica(errores)

	if not errores.is_empty():
		for error in errores:
			push_error("CombatEntityAttackContract: FAIL: " + error)
		get_tree().quit(1)
		return

	print("CombatEntityAttackContract: PASS")
	get_tree().quit(0)


func _probar_solicitud_generica(errores: Array[String]) -> void:
	var atacante := EntityScript.new() as Entity
	var objetivo := EntityScript.new() as Entity
	var combate := CombatSystemScript.new() as CombatSystem

	atacante.name = "EntityAttackContractAttacker"
	objetivo.name = "EntityAttackContractTarget"
	get_tree().root.add_child(atacante)
	get_tree().root.add_child(objetivo)
	get_tree().root.add_child(combate)
	await get_tree().process_frame

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
	var resultado_cero: CombatAttackResult = combate.solicitar_danio_desde_entidad(
		atacante,
		objetivo,
		0,
		"Prueba/Entidad/Cero"
	)
	if not resultado_cero.solicitud_aceptada:
		errores.append("No aceptó una solicitud válida de daño cero.")
	if not resultado_cero.contacto_registrado:
		errores.append("No registró el contacto válido con daño cero.")
	if resultado_cero.danio_aplicado:
		errores.append("Declaró daño aplicado cuando la cantidad era cero.")
	if objetivo.health != salud_inicial:
		errores.append("La solicitud de daño cero modificó la salud.")
	if int(contactos["cantidad"]) != 1:
		errores.append("La solicitud cero no emitió exactamente un contacto.")
	if int(ataques_con_danio["cantidad"]) != 0:
		errores.append("La solicitud cero emitió el evento de ataque con daño.")

	var resultado_real: CombatAttackResult = combate.solicitar_danio_desde_entidad(
		atacante,
		objetivo,
		9,
		"Prueba/Entidad/Real"
	)
	if not resultado_real.solicitud_aceptada or not resultado_real.contacto_registrado:
		errores.append("La solicitud real no informó aceptación y contacto.")
	if not resultado_real.danio_aplicado:
		errores.append("La solicitud real no informó daño aplicado.")
	if objetivo.health != salud_inicial - 9:
		errores.append("La solicitud real no redujo la salud exactamente en nueve.")
	if int(contactos["cantidad"]) != 2:
		errores.append("Las dos solicitudes válidas no emitieron dos contactos.")
	if int(ataques_con_danio["cantidad"]) != 1:
		errores.append("El daño real no emitió exactamente un evento de ataque.")

	# La API booleana anterior se conserva: false con daño cero y true
	# únicamente cuando la salud disminuye.
	var compatibilidad_cero: bool = combate.aplicar_danio_desde_entidad(
		atacante,
		objetivo,
		0,
		"Prueba/Compatibilidad/Cero"
	)
	if compatibilidad_cero:
		errores.append("El wrapper booleano declaró daño aplicado con cero.")
	var compatibilidad_real: bool = combate.aplicar_danio_desde_entidad(
		atacante,
		objetivo,
		3,
		"Prueba/Compatibilidad/Real"
	)
	if not compatibilidad_real:
		errores.append("El wrapper booleano no devolvió true tras daño real.")
	if objetivo.health != salud_inicial - 12:
		errores.append("El wrapper booleano alteró incorrectamente la salud.")
	if int(contactos["cantidad"]) != 4:
		errores.append("El wrapper de compatibilidad no conservó el evento de contacto.")
	if int(ataques_con_danio["cantidad"]) != 2:
		errores.append("El wrapper de compatibilidad no conservó el evento de daño.")

	var contactos_antes_rechazo := int(contactos["cantidad"])
	var resultado_atacante_invalido: CombatAttackResult = combate.solicitar_danio_desde_entidad(
		null,
		objetivo,
		5,
		"Prueba/AtacanteNulo"
	)
	if resultado_atacante_invalido.solicitud_aceptada:
		errores.append("Aceptó un atacante nulo.")
	if resultado_atacante_invalido.motivo_rechazo != &"atacante_invalido":
		errores.append("El rechazo no identificó al atacante inválido.")

	objetivo.restaurar_estado_vital(0, false)
	var resultado_objetivo_derrotado: CombatAttackResult = combate.solicitar_danio_desde_entidad(
		atacante,
		objetivo,
		5,
		"Prueba/ObjetivoDerrotado"
	)
	if resultado_objetivo_derrotado.solicitud_aceptada:
		errores.append("Aceptó un objetivo derrotado.")
	if resultado_objetivo_derrotado.motivo_rechazo != &"objetivo_derrotado":
		errores.append("El rechazo no identificó al objetivo derrotado.")
	if int(contactos["cantidad"]) != contactos_antes_rechazo:
		errores.append("Una solicitud rechazada emitió contacto.")

	combate.queue_free()
	atacante.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame
