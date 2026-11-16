extends Node

const MindScript = preload("res://scripts/gameplay/npc_mind.gd")
const ScheduleScript = preload("res://scripts/world/npc_schedule_system.gd")


class FakeGameState:
	extends Node
	var saved: Dictionary = {}

	func obtener_mentes_npc() -> Dictionary:
		return saved.duplicate(true)

	func guardar_mentes_npc(mentes: Dictionary) -> void:
		saved = mentes.duplicate(true)


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

	var schedule := ScheduleScript.new() as NPCScheduleSystem
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
	mind.free()
	mind_recargada.free()
	if not errores.is_empty():
		for error in errores:
			push_error("NPCMindCore: FAIL: " + error)
		get_tree().quit(1)
		return
	print("NPCMindCore: PASS")
	get_tree().quit(0)
