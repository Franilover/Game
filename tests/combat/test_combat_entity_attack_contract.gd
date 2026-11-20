extends Node

const EntityScript = preload("res://scripts/characters/entity.gd")
const GarumiScript = preload("res://scripts/creatures/garumi.gd")
const CombatSystemScript = preload("res://scripts/gameplay/combat_system.gd")
const IUMManagerScript = preload("res://scripts/gameplay/ium_manager.gd")
const IUMRepositoryScript = preload("res://scripts/core/ium_repository.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	await _probar_solicitud_generica(errores)
	await _probar_danio_ium_por_combate(errores)

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
	var garumi := GarumiScript.new() as Entity

	atacante.name = "EntityAttackContractAttacker"
	objetivo.name = "EntityAttackContractTarget"
	garumi.name = "EntityAttackContractGarumi"
	get_tree().root.add_child(atacante)
	get_tree().root.add_child(objetivo)
	get_tree().root.add_child(garumi)
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
	if garumi.is_in_group("damageable"):
		errores.append("El Garumi de prueba quedó registrado como objetivo dañable.")
	var contactos_antes_garumi := int(contactos["cantidad"])
	var resultado_garumi: CombatAttackResult = combate.solicitar_danio_desde_entidad(
		atacante,
		garumi,
		9,
		"Prueba/Entidad/Garumi"
	)
	if resultado_garumi.solicitud_aceptada or resultado_garumi.motivo_rechazo != &"objetivo_no_daniable":
		errores.append("CombatSystem aceptó daño dirigido a un Garumi no combatiente.")
	if int(contactos["cantidad"]) != contactos_antes_garumi:
		errores.append("El rechazo de un Garumi emitió un contacto de combate.")

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
	garumi.queue_free()
	await get_tree().process_frame



func _probar_danio_ium_por_combate(errores: Array[String]) -> void:
	var atacante := EntityScript.new() as Entity
	var objetivo := EntityScript.new() as Entity
	var combate := CombatSystemScript.new() as CombatSystem
	var repositorio := IUMRepositoryScript.new() as IUMRepository
	var manager := IUMManagerScript.new() as IUMManager
	atacante.name = "IUMContractAttacker"
	objetivo.name = "IUMContractTarget"
	get_tree().root.add_child(atacante)
	get_tree().root.add_child(objetivo)
	get_tree().root.add_child(combate)
	get_tree().root.add_child(repositorio)
	get_tree().root.add_child(manager)
	await get_tree().process_frame

	manager.configurar(repositorio, atacante, combate)
	manager.proceso_equipado = {
		"nombre": "Proceso de prueba",
		"efecto_tipo": "daño",
		"magnitud": 7.0
	}
	var contactos := {"cantidad": 0}
	combate.contacto_efectivo.connect(
		func(_atacante: Node, _objetivo: Entity, origen: String) -> void:
			if origen.begins_with("IUM/Proceso:"):
				contactos["cantidad"] = int(contactos["cantidad"]) + 1
	)
	var salud_inicial := objetivo.health
	manager.usar_proceso_equipado(objetivo)
	if objetivo.health != salud_inicial - 7:
		errores.append("El proceso IUM no aplicó daño mediante CombatSystem.")
	if int(contactos["cantidad"]) != 1:
		errores.append("El proceso IUM no registró un único contacto centralizado.")

	manager.queue_free()
	repositorio.queue_free()
	combate.queue_free()
	atacante.queue_free()
	objetivo.queue_free()
	await get_tree().process_frame
