extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const DialogueSystemScript = preload("res://scripts/gameplay/dialogue_system.gd")


func _ready() -> void:
	var errores: Array[String] = []
	var npc := CreatureScene.instantiate() as Creature
	var dialogo := DialogueSystemScript.new() as DialogueSystem
	if npc == null or dialogo == null:
		_fail(["No se pudieron crear los objetos de prueba."])
		return

	get_tree().root.add_child(npc)
	get_tree().root.add_child(dialogo)
	npc.set_meta("rutina_en_transito", true)
	dialogo._fuente = npc

	if dialogo._es_dialogo_en_transito({"clave": "rutina_contextual"}):
		errores.append("Una conversación cotidiana se clasificó como diálogo de tránsito por la marca de movimiento.")
	if not dialogo._es_dialogo_en_transito({"clave": "rutina_en_transito"}):
		errores.append("Un diálogo de tránsito explícito dejó de reconocerse.")

	npc.queue_free()
	dialogo.queue_free()
	await get_tree().process_frame

	if not errores.is_empty():
		_fail(errores)
		return

	print("DialogueSocialMenu: PASS")
	get_tree().quit(0)


func _fail(errores: Array[String]) -> void:
	for error in errores:
		push_error("DialogueSocialMenu: FAIL: " + error)
	get_tree().quit(1)
