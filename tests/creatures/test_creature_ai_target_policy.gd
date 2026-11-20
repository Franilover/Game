extends Node

const CreatureScript = preload("res://scripts/creatures/creature.gd")
const GarumiScript = preload("res://scripts/creatures/garumi.gd")
const AIScript = preload("res://scripts/creatures/creature_ai.gd")
const PerceptionScript = preload("res://scripts/creatures/creature_perception.gd")
const TargetSelectorScript = preload("res://scripts/creatures/creature_target_selector.gd")
const StateDecisionScript = preload("res://scripts/creatures/creature_state_decision.gd")
const UtilityAIScript = preload("res://scripts/creatures/creature_utility_ai.gd")
const InteractionMemoryScript = preload("res://scripts/creatures/creature_interaction_memory.gd")
const WorldItemScript = preload("res://scripts/world/world_item.gd")
const WorldPropScript = preload("res://scripts/world/world_prop.gd")
const WorldEntityManagerScript = preload("res://scripts/world/world_entity_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor := CreatureScript.new() as Creature
	actor.criatura_id = "target-policy-actor"
	actor.criatura_nombre = "Criatura neutral"
	actor.comportamiento = ""
	actor.datos = {"id": actor.criatura_id, "nombre": actor.criatura_nombre}

	var player := Node2D.new()
	get_tree().root.add_child(player)

	var ai := AIScript.new() as CreatureAI
	ai.criatura = actor
	ai.jugador = player
	ai.configuracion_ia = {}
	ai.actividad_horaria = "explorar"
	ai.perfil = AIScript.Perfil.GENERICO

	# La política de estados clasifica intenciones sin ejecutar conductas.
	if StateDecisionScript.resolver("atacar") != StateDecisionScript.Decision.ATACAR:
		_fail("La política no reconoció la intención de atacar.")
		return
	if StateDecisionScript.resolver("HUir") != StateDecisionScript.Decision.HUIR:
		_fail("La política no normalizó la respuesta de huida.")
		return
	if StateDecisionScript.resolver("perseguir", false) != StateDecisionScript.Decision.SIN_CAMBIO:
		_fail("La política ignoró la restricción de persecución del estado.")
		return
	if StateDecisionScript.resolver("investigar", true, false) != StateDecisionScript.Decision.SIN_CAMBIO:
		_fail("La política permitió investigar cuando el estado lo prohíbe.")
		return
	if StateDecisionScript.resolver("respuesta_desconocida") != StateDecisionScript.Decision.SIN_CAMBIO:
		_fail("Una respuesta desconocida produjo una conducta.")
		return

	# Utility AI puntúa necesidades comparables y conserva desempates deterministas.
	if not is_equal_approx(UtilityAIScript.puntuar_urgencia(50.0, 50.0), 0.01):
		_fail("Una necesidad en su umbral no produjo una urgencia mínima válida.")
		return
	if UtilityAIScript.puntuar_urgencia(40.0, 50.0) != 0.0:
		_fail("Una necesidad bajo su umbral produjo urgencia.")
		return
	if UtilityAIScript.seleccionar_accion({"descansar": 0.4, "alimentarse": 0.8}) != "alimentarse":
		_fail("Utility AI no seleccionó la acción con mayor puntuación.")
		return
	if UtilityAIScript.seleccionar_accion({"descansar": 0.8, "alimentarse": 0.8}) != "descansar":
		_fail("Utility AI no resolvió el empate de forma determinista.")
		return
	if not is_equal_approx(UtilityAIScript.leer_numero({"peso": 1.5}, "peso", 1.0), 1.5):
		_fail("Utility AI no leyó un peso numérico válido.")
		return
	if not is_equal_approx(UtilityAIScript.leer_numero({"peso": "alto"}, "peso", 1.0), 1.0):
		_fail("Utility AI no aplicó el valor por defecto ante un peso mal formado.")
		return
	if not is_equal_approx(UtilityAIScript.leer_numero({"peso": true}, "peso", 1.0), 1.0):
		_fail("Utility AI convirtió un booleano en un peso numérico.")
		return

	# La memoria es individual, temporal y no confunde actores distintos.
	var memoria := InteractionMemoryScript.new() as CreatureInteractionMemory
	var otro_actor := Node2D.new()
	get_tree().root.add_child(otro_actor)
	memoria.registrar_agresion(player, 1.0, 8.0)
	memoria.registrar_agresion(player, 1.0, 8.0)
	if not is_equal_approx(memoria.obtener_agresion(player), 2.0):
		_fail("La memoria no acumuló agresiones del mismo actor.")
		return
	if memoria.obtener_agresion(otro_actor) != 0.0:
		_fail("La memoria atribuyó a otro actor una agresión ajena.")
		return
	memoria.actualizar(2.0, 0.25)
	if not is_equal_approx(memoria.obtener_agresion(player), 1.5):
		_fail("La memoria no redujo gradualmente la agresión.")
		return
	memoria.actualizar(6.0, 0.0)
	if memoria.obtener_agresion(player) != 0.0 or memoria.cantidad_recuerdos() != 0:
		_fail("La memoria no expiró al terminar su duración.")
		return
	memoria.registrar_agresion(player, 1.0, 8.0)
	memoria.registrar_agresion(player, 1.0, 8.0)
	memoria.actualizar(1.0, 0.5)
	if not is_equal_approx(memoria.obtener_agresion(player), 1.5):
		_fail("La memoria no aplicó decaimiento sin expirar.")
		return
	memoria.registrar_agresion(otro_actor, 1.0, 8.0)
	memoria.registrar_agresion(otro_actor, 1.0, 8.0)
	if memoria.obtener_agresion(otro_actor) != 2.0:
		_fail("La memoria no mantuvo recuerdos independientes.")
		return

	# La intensidad tiene un límite y los Garumis no se convierten en amenazas recordadas.
	for _i in range(8):
		memoria.registrar_agresion(player, 1.0, 8.0)
	if memoria.obtener_agresion(player) != 5.0:
		_fail("La intensidad acumulada superó su límite de seguridad.")
		return
	var garumi_recordado := Node2D.new()
	garumi_recordado.add_to_group("garumis")
	get_tree().root.add_child(garumi_recordado)
	memoria.registrar_agresion(garumi_recordado, 1.0, 8.0)
	if memoria.obtener_agresion(garumi_recordado) != 0.0:
		_fail("La memoria registró a un Garumi como agresor.")
		return
	memoria.registrar_agresion(otro_actor, 1.0, 0.0)
	if memoria.obtener_agresion(otro_actor) != 2.0:
		_fail("La memoria aceptó una duración nula.")
		return

	memoria.actualizar(8.0, 0.0)
	if memoria.cantidad_recuerdos() != 0:
		_fail("La memoria conservó recuerdos después de expirar.")
		return
	otro_actor.queue_free()
	garumi_recordado.queue_free()

	# Un jugador cercano no debe ser un objetivo implícito de una criatura
	# neutral sin una respuesta definida.
	ai._refrescar_objetivo()
	if ai.objetivo != null:
		_fail("Una criatura neutral eligió al jugador sin respuesta definida.")
		return
	if ai._es_objetivo_ecologico_valido(player):
		_fail("Una entidad que no es Creature fue aceptada como objetivo ecológico.")
		return

	# El comportamiento agresivo sí define una reacción ejecutable.
	actor.comportamiento = "agresivo"
	ai._refrescar_objetivo()
	if ai.objetivo != player:
		_fail("Una criatura agresiva no seleccionó al jugador.")
		return
	if ai._obtener_respuesta_a_objetivo() != "perseguir":
		_fail("La conducta agresiva debe traducirse en perseguir.")
		return

	# La memoria optativa modifica sólo la respuesta hacia quien agredió.
	ai.configuracion_ia = {"memoria_interaccion": {
		"activo": true,
		"intensidad_agresion": 1.0,
		"duracion_segundos": 30.0,
		"decaimiento_por_segundo": 0.2,
		"umbral_agresion": 1.0,
		"respuesta_agresion": "huir"
	}}
	ai.al_recibir_danio(1, player)
	if ai._obtener_respuesta_para_objetivo(player) != "huir":
		_fail("La criatura no recordó al actor que la agredió.")
		return
	if ai._obtener_respuesta_para_objetivo(otro_actor) != "perseguir":
		_fail("La memoria alteró la reacción hacia un actor que no la agredió.")
		return
	ai._actualizar_memoria_interaccion(6.0)
	if ai._obtener_respuesta_para_objetivo(player) != "perseguir":
		_fail("La respuesta de memoria no volvió al comportamiento base tras decaer.")
		return
	# Las reacciones ecológicas/específicas de especie prevalecen sobre recuerdos genéricos.
	ai.perfil = AIScript.Perfil.LIGNIANOS
	ai.configuracion_ia = {"memoria_interaccion": {
		"activo": true,
		"respuesta_agresion": "huir"
	}}
	ai.al_recibir_danio(1, player)
	if ai._obtener_respuesta_para_objetivo(player) != "":
		_fail("La memoria genérica sobrescribió la política específica de Lignianos.")
		return
	ai.perfil = AIScript.Perfil.GENERICO
	ai.configuracion_ia = {}
	ai._memoria_interaccion = InteractionMemoryScript.new()
	if ai._obtener_respuesta_para_objetivo(player) != "perseguir":
		_fail("La memoria cambió el comportamiento cuando estaba desactivada.")
		return

	# Lignianos debe fallar de forma segura: si Supabase/snapshot no
	# entrega la clave, la IA no puede interpretar la ausencia como permiso.
	actor.criatura_nombre = "Lignianos"
	actor.comportamiento = ""
	actor.datos = {"id": actor.criatura_id, "nombre": "Lignianos", "ia_config": {}}
	ai.perfil = AIScript.Perfil.GENERICO
	ai.configuracion_ia = {}
	ai._refrescar_configuracion()
	if ai.perfil != AIScript.Perfil.LIGNIANOS:
		_fail("La IA no identificó Lignianos por su nombre cuando faltaba el perfil.")
		return
	if ai._movimiento_permitido():
		_fail("Lignianos permitió movimiento al faltar ia_config.")
		return

	# Una decisión explícita y válida de la configuración canónica prevalece.
	ai.configuracion_ia = {"movimiento_permitido": true}
	if not ai._movimiento_permitido():
		_fail("La IA ignoró movimiento_permitido=true explícito.")
		return
	ai.configuracion_ia = {"movimiento_permitido": false}
	if ai._movimiento_permitido():
		_fail("La IA ignoró movimiento_permitido=false explícito.")
		return

	ai.configuracion_ia = {}
	ai._refrescar_objetivo()
	if ai.objetivo != null:
		_fail("Lignianos reaccionó al jugador sin la marca de asesino.")
		return

	player.set_meta("garlia_bosque_asesino", true)
	ai._refrescar_objetivo()
	if ai.objetivo != player:
		_fail("Lignianos no detectó al jugador marcado como asesino.")
		return
	if ai._obtener_respuesta_a_objetivo() != "atacar":
		_fail("La respuesta al asesino del bosque debe ser atacar.")
		return

	# Una política explícita de inmovilidad también debe respetarse en
	# perfiles genéricos, sin alterar su comportamiento cuando falta la clave.
	ai.perfil = AIScript.Perfil.GENERICO
	ai.configuracion_ia = {"movimiento_permitido": false}
	if ai._movimiento_permitido():
		_fail("La política explícita de inmovilidad no se aplicó al perfil genérico.")
		return
	ai.configuracion_ia = {}
	if not ai._movimiento_permitido():
		_fail("El perfil genérico perdió el comportamiento compatible por defecto.")
		return

	# Las relaciones ecológicas adicionales sólo producen conductas cuando
	# la configuración de esa especie define una respuesta explícita.
	var presa := CreatureScript.new() as Creature
	presa.criatura_id = "target-policy-presa"
	presa.criatura_nombre = "Presa de prueba"
	presa.datos = {"id": presa.criatura_id, "nombre": presa.criatura_nombre}
	actor.datos["ecosistema_id"] = "ecosistema-prueba"
	ai.relaciones_ecologicas = [{
		"criatura_origen_id": actor.criatura_id,
		"criatura_destino_id": presa.criatura_id,
		"ecosistema_id": "ecosistema-prueba",
		"tipo_relacion": "competencia"
	}]
	ai.configuracion_ia = {"respuestas_ecologicas": {"competencia": "huir"}}
	if ai._obtener_respuesta_para_objetivo(presa) != "huir":
		_fail("La regla ecológica configurable no aplicó la respuesta de huida.")
		return
	ai.configuracion_ia = {}
	if not ai._obtener_respuesta_para_objetivo(presa).is_empty():
		_fail("Una relación ecológica sin respuesta explícita inventó una conducta.")
		return
	ai.relaciones_ecologicas[0]["tipo_relacion"] = "depredacion"
	if ai._obtener_respuesta_para_objetivo(presa) != "atacar":
		_fail("La depredación perdió su respuesta histórica por defecto.")
		return
	presa.free()

	# La alimentación sólo reconoce IDs declarados por la configuración.
	var refugio_prop := WorldPropScript.new() as WorldProp
	refugio_prop.configurar("cueva", "bosque", 0, 1, {
		"atractor_refugio": true,
		"refugio_clave": "cueva-segura"
	})
	if not bool(refugio_prop.get_meta("atractor_refugio", false)):
		_fail("Un WorldProp configurado como refugio no publicó su atributo.")
		return
	if str(refugio_prop.get_meta("refugio_clave", "")) != "cueva-segura":
		_fail("El refugio no conservó su clave de búsqueda.")
		return
	var refugio_root := Node2D.new()
	get_tree().root.add_child(refugio_root)
	var refugio_manager := WorldEntityManagerScript.new() as WorldEntityManager
	refugio_manager.configurar(refugio_root)
	refugio_prop.position = Vector2(40.0, 0.0)
	if not refugio_manager.registrar_global(refugio_prop):
		_fail("No se pudo registrar el refugio de prueba.")
		return
	ai.entity_manager = refugio_manager
	ai.configuracion_ia = {"horario": {
		"buscar_refugio": true,
		"refugio_objetivo": "refugio-alternativo",
		"refugio_objetivos": ["cueva"],
		"radio_refugio": 100.0
	}}
	ai.actividad_horaria = "reposar"
	if ai._buscar_refugio() != refugio_prop:
		_fail("La IA no encontró un WorldProp configurado como refugio.")
		return
	ai.objetivo = refugio_prop
	if not ai._es_objetivo_refugio():
		_fail("La IA no reconoció el WorldProp como destino de refugio.")
		return
	ai.objetivo = null

	# Garumis nunca son objetivos de combate ni de persecución, incluso si
	# la especie tiene objetivos="todo" o una respuesta ecológica agresiva.
	var garumi := GarumiScript.new() as Garumi
	garumi.criatura_id = "target-policy-garumi"
	garumi.criatura_nombre = "Garumi de prueba"
	garumi.position = Vector2(1.0, 0.0)
	if not refugio_manager.registrar_global(garumi):
		_fail("No se pudo registrar el Garumi de prueba.")
		return

	# La percepción descubre entidades vivas, pero no decide cuáles son
	# objetivos hostiles. Garumis pueden estar presentes en la percepción.
	var criatura_percibida := CreatureScript.new() as Creature
	criatura_percibida.criatura_id = "target-policy-perceived"
	criatura_percibida.criatura_nombre = "Criatura percibida"
	if not refugio_manager.registrar_global(criatura_percibida):
		_fail("No se pudo registrar la criatura percibida.")
		return
	var candidatos_percibidos := PerceptionScript.obtener_candidatos(actor, player, refugio_manager)
	if player not in candidatos_percibidos or criatura_percibida not in candidatos_percibidos:
		_fail("La percepción no descubrió al jugador y a una criatura activa.")
		return
	if garumi not in candidatos_percibidos:
		_fail("La percepción omitió al Garumi como entidad presente en el mundo.")
		return
	criatura_percibida.position = Vector2(20.0, 0.0)
	var selector_cercano := TargetSelectorScript.seleccionar_mas_cercano(
		actor,
		candidatos_percibidos,
		func(candidato: Node2D) -> bool:
			return candidato == player or candidato == criatura_percibida
	)
	if selector_cercano != player:
		_fail("El selector no escogió al candidato permitido más cercano.")
		return
	player.position = Vector2(1000.0, 0.0)
	selector_cercano = TargetSelectorScript.seleccionar_mas_cercano(
		actor,
		candidatos_percibidos,
		func(candidato: Node2D) -> bool:
			return candidato == player or candidato == criatura_percibida
	)
	if selector_cercano != criatura_percibida:
		_fail("El selector no actualizó el objetivo al cambiar las distancias.")
		return
	ai.entity_manager = refugio_manager
	if garumi in ai._obtener_candidatos_entidad() and ai._es_objetivo_ecologico_valido(garumi):
		_fail("La separación percepción/política permitió al Garumi como objetivo ecológico.")
		return

	var criatura_pendiente := CreatureScript.new() as Creature
	if not refugio_manager.registrar_global(criatura_pendiente):
		_fail("No se pudo registrar la criatura pendiente de eliminación.")
		return
	criatura_pendiente.queue_free()
	if criatura_pendiente in PerceptionScript.obtener_candidatos(actor, player, refugio_manager):
		_fail("La percepción conservó una entidad pendiente de queue_free().")
		return

	player.position = Vector2(1000.0, 0.0)
	ai.entity_manager = refugio_manager
	ai.configuracion_ia = {"objetivos": "todo"}
	ai.perfil = AIScript.Perfil.CAMBIAFORMAS
	ai._refrescar_objetivo()
	if ai.objetivo == garumi:
		_fail("Una criatura agresiva seleccionó un Garumi para perseguirlo.")
		return
	if ai._es_objetivo_ecologico_valido(garumi) or ai._es_seguimiento_ecologico(garumi):
		_fail("Un Garumi fue aceptado como objetivo ecológico o de seguimiento.")
		return
	actor.set_meta("garlia_objetivo_liberacion", garumi)
	ai._refrescar_objetivo()
	if ai.objetivo == garumi or actor.has_meta("garlia_objetivo_liberacion"):
		_fail("La protección de liberación conservó un Garumi como objetivo hostil.")
		return
	player.position = Vector2.ZERO

	# Si el objetivo desaparece durante la persecución, la criatura investiga
	# la última posición conocida en vez de abandonar la pista inmediatamente.
	var objetivo_memoria := CreatureScript.new() as Creature
	get_tree().root.add_child(objetivo_memoria)
	objetivo_memoria.position = Vector2(64.0, 0.0)
	ai.objetivo = objetivo_memoria
	ai.objetivo_detectado = true
	ai.ultima_posicion_objetivo = objetivo_memoria.global_position
	ai._hay_ultima_posicion_objetivo = true
	ai.estado = AIScript.Estado.PERSIGUIENDO
	objetivo_memoria.queue_free()
	await get_tree().process_frame
	ai.objetivo_detectado = false
	ai._procesar_persiguiendo()
	if ai.estado != AIScript.Estado.INVESTIGANDO:
		_fail("La pérdida del objetivo no conservó la investigación de su última posición.")
		return
	ai._procesar_investigando()
	if ai.estado != AIScript.Estado.INVESTIGANDO:
		_fail("La criatura abandonó la última posición conocida antes de llegar.")
		return
	actor.position = Vector2(64.0, 0.0)
	ai._procesar_investigando()
	if ai.estado != AIScript.Estado.EXPLORANDO or ai._hay_ultima_posicion_objetivo:
		_fail("La criatura no cerró la investigación al alcanzar la última posición.")
		return
	actor.position = Vector2.ZERO

	ai.objetivo = null
	ai.entity_manager = null
	refugio_root.queue_free()
	refugio_manager.free()

	var alimento := WorldItemScript.new() as WorldItem
	alimento.configurar({"item_id": "recurso-test", "cantidad": 1})
	ai.configuracion_ia = {"alimentacion": {"item_ids": ["recurso-test"]}}
	if not ai._es_alimento_configurado(alimento):
		_fail("La IA no reconoció un alimento declarado explícitamente.")
		return
	if not alimento.consumir_por_criatura(ai._obtener_ids_alimento()):
		_fail("Un alimento permitido no pudo ser consumido.")
		return
	if not alimento.is_queued_for_deletion():
		_fail("El recurso consumido no se retiró del mundo.")
		return
	var pila := WorldItemScript.new() as WorldItem
	pila.configurar({"item_id": "recurso-test", "cantidad": 3})
	if not pila.consumir_por_criatura(["recurso-test"]) or int(pila.obtener_datos().get("cantidad", 0)) != 2:
		_fail("La alimentación debe consumir una unidad, no destruir toda la pila.")
		return
	pila.free()
	var alimento_no_permitido := WorldItemScript.new() as WorldItem
	alimento_no_permitido.configurar({"item_id": "recurso-ajeno", "cantidad": 1})
	if ai._es_alimento_configurado(alimento_no_permitido):
		_fail("La IA aceptó un recurso que no figura en su dieta.")
		return
	if alimento_no_permitido.consumir_por_criatura(["otro-id"]):
		_fail("Una criatura consumió un recurso fuera de su lista permitida.")
		return
	alimento_no_permitido.free()

	# Las necesidades son opt-in y los valores se limitan al intervalo 0..100.
	ai.configuracion_ia = {"necesidades": {
		"hambre_por_segundo": 10.0,
		"fatiga_por_segundo": 20.0,
		"recuperacion_fatiga_por_segundo": 5.0,
		"umbral_hambre": 50.0,
		"umbral_fatiga": 60.0
	}}
	ai.actividad_horaria = "explorar"
	ai._hambre_actual = 0.0
	ai._fatiga_actual = 0.0
	ai._actualizar_necesidades(2.0)
	var necesidades_estado := ai._obtener_estado_necesidades()
	if not is_equal_approx(float(necesidades_estado.get("hambre", -1.0)), 20.0):
		_fail("El hambre no aumentó según su tasa configurada.")
		return
	if not is_equal_approx(float(necesidades_estado.get("fatiga", -1.0)), 40.0):
		_fail("La fatiga no aumentó según su tasa configurada.")
		return
	ai.actividad_horaria = "reposar"
	ai._actualizar_necesidades(2.0)
	if not is_equal_approx(float(ai._obtener_estado_necesidades().get("fatiga", -1.0)), 30.0):
		_fail("El descanso no recuperó fatiga correctamente.")
		return
	ai.configuracion_ia = {"horario": {"buscar_refugio": true, "refugio_objetivo": "Refugio de prueba"}}
	ai.actividad_horaria = "reposar"
	if not ai._debe_buscar_refugio():
		_fail("La criatura no pudo buscar refugio durante el descanso.")
		return
	ai.configuracion_ia = {"necesidades": {"umbral_fatiga": 60.0, "recuperacion_fatiga_por_segundo": 5.0}}
	ai._fatiga_actual = 70.0
	actor.datos["necesidades_runtime"] = {"hambre": 42.0, "fatiga": 70.0}
	ai._hambre_actual = 0.0
	ai._fatiga_actual = 0.0
	ai._restaurar_necesidades_runtime()
	if not is_equal_approx(ai._hambre_actual, 42.0) or not is_equal_approx(ai._fatiga_actual, 70.0):
		_fail("Las necesidades fisiológicas no se restauraron desde el estado runtime.")
		return
	if not is_equal_approx(float(ai._obtener_estado_necesidades().get("hambre", -1.0)), 42.0):
		_fail("El estado de necesidades no quedó disponible para el guardado.")
		return
	ai.actividad_horaria = "explorar"
	ai._aplicar_prioridad_necesidades()
	if ai.actividad_horaria != "reposar":
		_fail("La fatiga alta no activó el descanso configurado.")
		return
	ai._actualizar_necesidades(2.0)
	if float(ai._obtener_estado_necesidades().get("fatiga", 100.0)) >= 70.0:
		_fail("La actividad de descanso seleccionada no recuperó la fatiga.")
		return
	ai._fatiga_actual = 31.0
	ai.actividad_horaria = "explorar"
	ai._aplicar_prioridad_necesidades()
	if ai.actividad_horaria != "reposar":
		_fail("El descanso terminó antes de alcanzar el umbral de salida.")
		return
	ai._fatiga_actual = 30.0
	ai.actividad_horaria = "explorar"
	ai._aplicar_prioridad_necesidades()
	if ai.actividad_horaria == "reposar":
		_fail("El descanso no terminó al alcanzar el umbral de salida.")
		return

	# Si ambas necesidades superan sus umbrales, la urgencia relativa decide.
	# La configuración heredada sigue usando pesos iguales por defecto.
	ai._descanso_por_fatiga = false
	ai.configuracion_ia = {"necesidades": {
		"umbral_fatiga": 60.0,
		"umbral_hambre": 50.0,
		"recuperacion_fatiga_por_segundo": 5.0,
		"peso_prioridad_fatiga": 1.0,
		"peso_prioridad_hambre": 1.0,
		"actividad_descanso": "reposar",
		"actividad_alimentacion": "alimentarse"
	}, "alimentacion": {"item_ids": ["fruta-test"]}}
	ai._fatiga_actual = 65.0
	ai._hambre_actual = 90.0
	ai.actividad_horaria = "explorar"
	ai._aplicar_prioridad_necesidades()
	if ai.actividad_horaria != "alimentarse":
		_fail("Utility AI no priorizó el hambre cuando su urgencia era mayor.")
		return
	ai._fatiga_actual = 95.0
	ai._hambre_actual = 60.0
	ai.actividad_horaria = "explorar"
	ai._aplicar_prioridad_necesidades()
	if ai.actividad_horaria != "reposar" or not ai._descanso_por_fatiga:
		_fail("Utility AI no priorizó la fatiga cuando su urgencia era mayor.")
		return
	ai._fatiga_actual = 30.0
	ai._hambre_actual = 30.0
	ai.actividad_horaria = "explorar"
	ai._aplicar_prioridad_necesidades()
	if ai._descanso_por_fatiga:
		_fail("La histéresis de descanso no se liberó al alcanzar el umbral de salida.")
		return

	# Una configuración mal formada debe usar valores seguros, no detener la IA.
	ai.configuracion_ia["necesidades"]["peso_prioridad_hambre"] = "urgente"
	ai._fatiga_actual = 95.0
	ai._hambre_actual = 60.0
	ai.actividad_horaria = "explorar"
	ai._aplicar_prioridad_necesidades()
	if ai.actividad_horaria != "reposar":
		_fail("Un peso de hambre mal formado impidió evaluar la fatiga con el valor seguro.")
		return
	ai._descanso_por_fatiga = false

	# Seguir una especie no debe convertirse automáticamente en un ataque al contacto.
	ai.configuracion_ia = {"respuestas_ecologicas": {"competencia": "perseguir"}}
	ai.relaciones_ecologicas = [{
		"criatura_origen_id": actor.criatura_id,
		"criatura_destino_id": "objetivo-seguimiento",
		"ecosistema_id": "ecosistema-prueba",
		"tipo_relacion": "competencia"
	}]
	var seguidor := CreatureScript.new() as Creature
	seguidor.criatura_id = "objetivo-seguimiento"
	seguidor.datos = {"id": seguidor.criatura_id, "nombre": "Objetivo"}
	seguidor.position = Vector2(5.0, 0.0)
	ai.objetivo = seguidor
	ai.objetivo_detectado = true
	ai.perfil = AIScript.Perfil.GENERICO
	ai._cambiar_estado(AIScript.Estado.PERSIGUIENDO)
	ai._procesar_persiguiendo()
	if ai.estado == AIScript.Estado.ATACANDO:
		_fail("Una relación de seguimiento inició combate.")
		return
	if not ai._es_seguimiento_ecologico(seguidor):
		_fail("La IA no identificó la relación de seguimiento explícita.")
		return
	# Un perfil que usa persecución agresiva conserva el ataque al llegar.
	ai.objetivo = player
	ai.perfil = AIScript.Perfil.CAMBIAFORMAS
	ai.configuracion_ia = {}
	ai._cambiar_estado(AIScript.Estado.PERSIGUIENDO)
	ai._procesar_persiguiendo()
	if ai.estado != AIScript.Estado.ATACANDO:
		_fail("La persecución agresiva perdió su transición histórica a combate.")
		return
	seguidor.free()

	# Los ataques de contacto deben acercarse antes de iniciar el golpe.
	player.remove_meta("garlia_bosque_asesino")
	actor.criatura_nombre = "Depredador de prueba"
	actor.comportamiento = ""
	ai.perfil = AIScript.Perfil.GENERICO
	player.position = Vector2(140.0, 0.0)
	ai.objetivo = player
	ai._cambiar_a_respuesta_atacar()
	if ai.estado != AIScript.Estado.PERSIGUIENDO:
		_fail("Un ataque genérico fuera de alcance debe pasar a persecución.")
		return

	# GENÉRICO, GUARDIAN y CAZADOR ya tienen un manejador de contacto;
	# entrar en ATACANDO no debe enviarlos directamente a RECUPERANDO.
	for perfil_prueba in [
		AIScript.Perfil.GENERICO,
		AIScript.Perfil.GUARDIAN,
		AIScript.Perfil.CAZADOR
	]:
		ai.perfil = perfil_prueba
		ai._cambiar_estado(AIScript.Estado.ATACANDO)
		if ai.estado != AIScript.Estado.ATACANDO:
			_fail("Un perfil con ataque de contacto saltó a recuperación al entrar.")
			return
		ai._procesar_atacando(0.016)
		if ai.estado != AIScript.Estado.ATACANDO:
			_fail("Un perfil con ataque de contacto no mantuvo la aproximación.")
			return
		ai._cambiar_estado(AIScript.Estado.RECUPERANDO)

	print("CreatureAITargetPolicy: PASS - selección y contacto.")
	get_tree().root.remove_child(player)
	player.free()
	actor.free()
	ai.free()
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("CreatureAITargetPolicy: FAIL: " + message)
	get_tree().quit(1)
