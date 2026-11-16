extends Node

const MindScript = preload("res://scripts/gameplay/npc_mind.gd")


class FakeGameState:
	extends RefCounted
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

	var persistido := game_state.saved.get("ivo", {})
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

	mind.free()
	mind_recargada.free()
	if not errores.is_empty():
		for error in errores:
			push_error("NPCMindCore: FAIL: " + error)
		get_tree().quit(1)
		return
	print("NPCMindCore: PASS")
	get_tree().quit(0)
