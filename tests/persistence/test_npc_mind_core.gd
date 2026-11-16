extends Node

const MindScript = preload("res://scripts/gameplay/npc_mind.gd")
const ScheduleScript = preload("res://scripts/world/npc_schedule_system.gd")
const RelationshipScript = preload("res://scripts/gameplay/relationship_system.gd")


class FakeGameState:
	extends Node
	var saved: Dictionary = {}
	var conversations: Dictionary = {}
	var memories: Dictionary = {}
	var social_relations: Dictionary = {}

	func obtener_mentes_npc() -> Dictionary:
		return saved.duplicate(true)

	func guardar_mentes_npc(mentes: Dictionary) -> void:
		saved = mentes.duplicate(true)

	func obtener_conversaciones_npc() -> Dictionary:
		return conversations.duplicate(true)

	func guardar_conversaciones_npc(value: Dictionary) -> void:
		conversations = value.duplicate(true)

	func obtener_recuerdos_sociales() -> Dictionary:
		return memories.duplicate(true)

	func guardar_recuerdos_sociales(value: Dictionary) -> void:
		memories = value.duplicate(true)

	func obtener_relaciones_sociales() -> Dictionary:
		return social_relations.duplicate(true)

	func guardar_relaciones_sociales(value: Dictionary) -> void:
		social_relations = value.duplicate(true)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var game_state := FakeGameState.new()
	var mind := MindScript.new() as NPCMindService
	mind.configurar(game_state)

	var perfil := {
		"rasgos": {"sociabilidad": 0.9, "curiosidad": 0.8},
		"necesidades": {"socializacion": 70.0, "descanso": 15.0}
	}
	var estado := mind.registrar_personaje("Ivo", perfil)

	var perfil_social := mind.registrar_personaje("Narel", {"rasgos": {"sociabilidad": 80.0}})
	if not is_equal_approx(float(perfil_social.get("rasgos", {}).get("sociabilidad", 0.0)), 0.8):
		errores.append("Los rasgos sociales en escala 0-100 no se normalizaron.")
	if not is_equal_approx(float(estado.get("necesidades", {}).get("socializacion", 0.0)), 70.0):
		errores.append("El perfil inicial no aplicó sus necesidades.")
	if not is_equal_approx(float(estado.get("rasgos", {}).get("sociabilidad", 0.0)), 0.9):
		errores.append("El perfil inicial no aplicó sus rasgos.")
	if estado.get("aprendizaje", {}) != {}:
		errores.append("Un personaje nuevo debe empezar sin preferencias aprendidas.")

	mind.avanzar_tiempo("ivo", 2.0)
	var tras_tiempo := mind.obtener_necesidades("ivo")
	if float(tras_tiempo.get("descanso", 0.0)) <= 15.0:
		errores.append("El descanso no aumentó con el paso del tiempo.")

	mind.aplicar_satisfaccion("ivo", {"descanso": 12.0, "socializacion": 20.0})
	var tras_descanso := mind.obtener_necesidades("ivo")
	if float(tras_descanso.get("descanso", 100.0)) >= float(tras_tiempo.get("descanso", 0.0)):
		errores.append("La satisfacción no redujo la necesidad.")

	var antes_intervalo := mind.obtener_necesidades("ivo")
	mind.procesar_intervalo("ivo", 1.0, {"descanso": 2.0, "socializacion": 1.0})
	var despues_intervalo := mind.obtener_necesidades("ivo")
	if float(despues_intervalo.get("descanso", 0.0)) >= float(antes_intervalo.get("descanso", 100.0)):
		errores.append("La actividad de descanso no redujo la presión durante el intervalo.")
	if float(despues_intervalo.get("curiosidad", 0.0)) <= float(antes_intervalo.get("curiosidad", 0.0)):
		errores.append("Las necesidades sin satisfacción no evolucionaron con el tiempo.")
	var emociones: Dictionary = mind.obtener_estado("ivo").get("estado_emocional", {})
	if not emociones.has("animo") or not emociones.has("estres") or not emociones.has("energia"):
		errores.append("El estado emocional no se actualizó con las necesidades.")

	var actividades: Array = [
		{"id": "leer", "necesidades": {"curiosidad": 1.0}, "afinidad_rasgos": {"curiosidad": 0.8}},
		{"id": "charlar", "necesidades": {"socializacion": 1.0}, "afinidad_rasgos": {"sociabilidad": 0.9}},
		{"id": "trabajar", "prioridad": 10.0, "coste": 20.0}
	]
	var eleccion := mind.elegir_actividad("ivo", actividades)
	if str(eleccion.get("actividad", "")) != "charlar":
		errores.append("La selección no priorizó la necesidad social y la personalidad.")

	var preferencia_inicial := mind.registrar_resultado_actividad("ivo", "charlar", 1.0)
	if preferencia_inicial <= 0.0 or preferencia_inicial >= 1.0:
		errores.append("Una experiencia positiva no produjo aprendizaje gradual.")
	var preferencia_negativa := mind.registrar_resultado_actividad("ivo", "charlar", -1.0)
	if preferencia_negativa >= preferencia_inicial:
		errores.append("Una experiencia negativa no modificó la preferencia aprendida.")

	if not mind.establecer_objetivo("ivo", {"id": "visitar_mara", "prioridad": 0.8, "tipo": "social"}):
		errores.append("No se pudo establecer un objetivo.")
	if mind.obtener_objetivos_activos("ivo").size() != 1:
		errores.append("El objetivo activo no se conservó.")
	if not mind.completar_objetivo("ivo", "visitar_mara"):
		errores.append("No se pudo completar el objetivo.")
	if not mind.obtener_objetivos_activos("ivo").is_empty():
		errores.append("Un objetivo completado siguió activo.")
	for indice_objetivo in range(7):
		var id_objetivo := "objetivo_social_%s" % indice_objetivo
		if not mind.establecer_objetivo("ivo", {"id": id_objetivo, "tipo": "social", "prioridad": 0.6}):
			errores.append("No se pudo registrar el objetivo social %s." % indice_objetivo)
			break
		if not mind.completar_objetivo("ivo", id_objetivo):
			errores.append("No se pudo cerrar el objetivo social %s." % indice_objetivo)
			break
	if not mind.establecer_objetivo("ivo", {"id": "visitar_ivo_amigo", "tipo": "visitar_amigo", "prioridad": 0.8}):
		errores.append("Los objetivos completados bloquearon nuevos objetivos sociales.")

	var persistido: Dictionary = game_state.saved.get("ivo", {})
	if persistido.is_empty():
		errores.append("El estado mental no se escribió en GameState.")

	var mind_recargada := MindScript.new() as NPCMindService
	mind_recargada.configurar(game_state)
	var estado_recargado := mind_recargada.obtener_estado("ivo")
	if estado_recargado != mind.obtener_estado("ivo"):
		errores.append("El estado mental no sobrevivió a la recarga desde GameState.")

	var cantidad_preferencias := (estado_recargado.get("aprendizaje", {}) as Dictionary).size()
	if cantidad_preferencias != 1:
		errores.append("Las preferencias aprendidas no se persistieron correctamente.")

	var relationship := RelationshipScript.new() as RelationshipSystemService
	relationship._game_state = game_state
	relationship.registrar_conocimiento_npc("ivo", {
		"clave": "festival_plaza",
		"tipo": "noticia",
		"compartible": true,
		"titulo": "Preparativos del festival",
		"fuente": "ivo"
	})
	if relationship.conoce_conocimiento_npc("mara", "festival_plaza"):
		errores.append("Un NPC conoció una noticia que nunca recibió.")
	if not relationship.transmitir_conocimiento_npc("ivo", "mara", "festival_plaza", {"motivo": "test"}):
		errores.append("No se pudo transmitir una noticia entre habitantes.")
	if not relationship.conoce_conocimiento_npc("mara", "festival_plaza"):
		errores.append("La noticia compartida no quedó registrada en la memoria del destinatario.")

	var promesa_id := relationship.registrar_promesa_entre_npc("ivo", "mara", {
		"clave": "devolver_libro",
		"descripcion": "Devolver el libro prestado"
	})
	if promesa_id.is_empty() or relationship.obtener_promesas_pendientes_npc("ivo", "mara").size() != 1:
		errores.append("La promesa entre habitantes no quedó pendiente.")
	if not relationship.resolver_promesa_entre_npc(promesa_id, true):
		errores.append("No se pudo cumplir una promesa entre habitantes.")
	if not relationship.obtener_promesas_pendientes_npc("ivo", "mara").is_empty():
		errores.append("Una promesa cumplida siguió pendiente.")

	var asunto_id := relationship.registrar_asunto_pendiente_npc("ivo", {
		"clave": "reparar_carro",
		"personaje_relacionado": "mara",
		"descripcion": "Necesita ayuda con una rueda"
	})
	if asunto_id.is_empty() or relationship.obtener_asuntos_pendientes_npc("ivo", "mara").size() != 1:
		errores.append("El asunto pendiente no se conservó.")
	if not relationship.resolver_asunto_pendiente_npc(asunto_id):
		errores.append("No se pudo resolver el asunto pendiente.")
	if not relationship.obtener_asuntos_pendientes_npc("ivo", "mara").is_empty():
		errores.append("Un asunto resuelto siguió pendiente.")

	var schedule := ScheduleScript.new() as NPCScheduleSystem
	schedule._relationship_system = relationship
	var promesa_motivo_id := relationship.registrar_promesa_entre_npc("ivo", "mara", {
		"clave": "contar_noticia",
		"descripcion": "Contar una noticia pendiente"
	})
	var relacion_social: Dictionary = relationship.obtener_relacion_entre_npc("ivo", "mara")
	var motivo_promesa: Dictionary = schedule.call("_seleccionar_motivo_encuentro_social", "ivo", "mara", relacion_social)
	if str(motivo_promesa.get("tipo", "")) != "cumplir_promesa" or str(motivo_promesa.get("promesa_id", "")) != promesa_motivo_id:
		errores.append("El NPC no priorizó una promesa pendiente con su destinataria.")

	relationship.registrar_asunto_pendiente_npc("ivo", {
		"clave": "ayuda_herramienta",
		"personaje_relacionado": "mara",
		"descripcion": "Necesita ayuda con una herramienta"
	})
	relationship.resolver_promesa_entre_npc(promesa_motivo_id, true)
	var motivo_asunto: Dictionary = schedule.call("_seleccionar_motivo_encuentro_social", "ivo", "mara", relacion_social)
	if str(motivo_asunto.get("tipo", "")) != "resolver_asunto":
		errores.append("El NPC no eligió resolver un asunto pendiente con la persona indicada.")

	relationship.registrar_conocimiento_npc("ivo", {
		"clave": "mercado_cerrado",
		"tipo": "noticia",
		"compartible": true,
		"titulo": "El mercado cerrará temprano",
		"fuente": "ivo"
	})
	relationship.resolver_asunto_pendiente_npc(str(motivo_asunto.get("asunto_id", "")), true)
	var motivo_noticia: Dictionary = schedule.call("_seleccionar_motivo_encuentro_social", "ivo", "mara", relacion_social)
	if str(motivo_noticia.get("tipo", "")) != "compartir_noticia" or str(motivo_noticia.get("clave_conocimiento", "")) != "mercado_cerrado":
		errores.append("El NPC no eligió compartir una noticia que la otra persona desconoce.")

	relationship.registrar_interaccion_entre_npc("ivo", "mara", {"tension": 22.0})
	relationship.transmitir_conocimiento_npc("ivo", "mara", "mercado_cerrado", {"motivo": "test"})
	var relacion_tensa: Dictionary = relationship.obtener_relacion_entre_npc("ivo", "mara")
	var motivo_desacuerdo: Dictionary = schedule.call("_seleccionar_motivo_encuentro_social", "ivo", "mara", relacion_tensa)
	if str(motivo_desacuerdo.get("tipo", "")) != "resolver_desacuerdo":
		errores.append("Los NPC no detectaron un desacuerdo cuando no quedaban noticias pendientes.")

	var ocio_ivo: Dictionary = schedule.call("_obtener_opciones_ocio_npc", "ivo")
	var ocio_mara: Dictionary = schedule.call("_obtener_opciones_ocio_npc", "mara")
	var opciones_ivo: Array = ocio_ivo.get("opciones", [])
	var opciones_mara: Array = ocio_mara.get("opciones", [])
	if opciones_ivo.size() != 3 or opciones_mara.size() != 3:
		errores.append("No se registraron tres alternativas de ocio para cada habitante.")
	else:
		var actividades_ivo: Array[String] = []
		for opcion in opciones_ivo:
			actividades_ivo.append(str((opcion as Dictionary).get("id", "")))
		if actividades_ivo.has("pasear_sin_prisa") or not actividades_ivo.has("sentarse_un_rato"):
			errores.append("El perfil de ocio de Ivo no conserva sus alternativas propias.")
		var actividades_mara: Array[String] = []
		for opcion in opciones_mara:
			actividades_mara.append(str((opcion as Dictionary).get("id", "")))
		if not actividades_mara.has("pasear_sin_prisa") or actividades_mara.has("sentarse_un_rato"):
			errores.append("El perfil de ocio de Mara no conserva sus alternativas propias.")
	schedule.free()
	relationship.free()
	mind.free()
	mind_recargada.free()
	if not errores.is_empty():
		for error in errores:
			push_error("NPCMindCore: FAIL: " + error)
		get_tree().quit(1)
		return
	print("NPCMindCore: PASS")
	get_tree().quit(0)
