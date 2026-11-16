extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const DialogueSystemScript = preload("res://scripts/gameplay/dialogue_system.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var npc := CreatureScene.instantiate() as Creature
	var dialogo := DialogueSystemScript.new() as DialogueSystem
	if npc == null or dialogo == null:
		_fail(["No se pudieron crear los objetos de prueba."])
		return

	add_child(npc)
	add_child(dialogo)
	npc.set_meta("rutina_en_transito", true)
	dialogo._fuente = npc

	if dialogo._es_dialogo_en_transito({"clave": "rutina_contextual"}):
		errores.append("Una conversación cotidiana se clasificó como diálogo de tránsito por la marca de movimiento.")
	if not dialogo._es_dialogo_en_transito({"clave": "rutina_en_transito"}):
		errores.append("Un diálogo de tránsito explícito dejó de reconocerse.")

	# Las frases de rutina distinguen desplazarse de estar trabajando.
	npc.nombre_individual = "Bruna"
	dialogo._contexto_rutina_conversacion = {
		"actividad": "caminar",
		"destino": "la plaza",
		"en_transito": false
	}
	var despedida_caminando := dialogo._obtener_reaccion_despedida_rutina()
	if not despedida_caminando.contains("No te entretengo más"):
		errores.append("La despedida de un NPC que camina no reconoce que sólo está desplazándose.")
	if not dialogo._actividad_es_desplazamiento("caminar") or dialogo._actividad_impide_una_conversacion_larga("caminar"):
		errores.append("Caminar se clasificó como una actividad que impide conversar.")
	var saludo_en_transito := dialogo._obtener_texto_rutina_personaje("bruna", "rutina", "caminar", "la plaza", true, false, false)
	if saludo_en_transito.contains("no puedo parar") or saludo_en_transito.contains("ocupado") or not (saludo_en_transito.contains("¿Qué necesitas?") or saludo_en_transito.contains("¿qué pasa?")):
		errores.append("El saludo de tránsito de Bruna no suena como una interrupción natural.")

	dialogo._contexto_rutina_conversacion = {
		"actividad": "forjar",
		"destino": "la forja",
		"en_transito": false
	}
	var despedida_trabajando := dialogo._obtener_reaccion_despedida_rutina()
	if not despedida_trabajando.contains("Termina la pieza") or despedida_trabajando.contains("No interrumpes"):
		errores.append("La despedida contradice el contexto de Bruna mientras trabaja en una pieza.")

	dialogo._contexto_rutina_conversacion = {
		"actividad": "caminar",
		"destino": "la plaza",
		"en_transito": true
	}
	var despedida_en_transito := dialogo._obtener_reaccion_despedida_rutina()
	if not despedida_en_transito.contains("encargo") and despedida_en_transito.contains("No te entretengo"):
		errores.append("La despedida de tránsito no mantiene el contexto de la actividad del NPC.")

	# Al cerrar el selector Hablar/Preguntar debe reaparecer el menú social
	# principal, incluso después de una conversación cotidiana.
	dialogo._abierto = true
	dialogo._usa_menu_social = true
	dialogo._lineas = [{"hablante": "Ivo", "texto": "Hola."}]
	dialogo._indice_linea = 0
	dialogo._texto_completo = "Hola."
	dialogo._indice_caracter = dialogo._texto_completo.length()
	dialogo._selector_conversacion = PanelContainer.new()
	dialogo.add_child(dialogo._selector_conversacion)
	dialogo._selector_conversacion.visible = true
	dialogo._selector_conversacion_grid = GridContainer.new()
	dialogo.add_child(dialogo._selector_conversacion_grid)
	dialogo._dialogue_content_row = HBoxContainer.new()
	dialogo.add_child(dialogo._dialogue_content_row)
	dialogo._dialogue_content_row.visible = false
	dialogo._respuestas_container = GridContainer.new()
	dialogo.add_child(dialogo._respuestas_container)
	dialogo.action_button = Button.new()
	dialogo.add_child(dialogo.action_button)
	dialogo.cancel_button = Button.new()
	dialogo.add_child(dialogo.cancel_button)
	dialogo._cerrar_selector_conversacion()

	var claves_menu: Array[String] = []
	for opcion in dialogo._respuestas:
		claves_menu.append(str(opcion.get("clave", "")))
	if claves_menu != ["menu_preguntar", "menu_hablar", "menu_cumplido", "menu_despedirse"]:
		errores.append("No reaparecieron Preguntar, Hablar, Dar cumplido y Despedirse.")
	if dialogo._selector_conversacion.visible or not dialogo._dialogue_content_row.visible:
		errores.append("El selector no devolvió el diálogo a su panel principal.")
	if not dialogo._respuestas_container.visible or dialogo._respuestas_container.get_child_count() != 4:
		errores.append("Los cuatro botones del menú social no se reconstruyeron.")

	# Tras elegir un tema casual, el menú principal debe volver al terminar
	# la respuesta del NPC, no desaparecer después de una sola interacción.
	dialogo.speaker_label = Label.new()
	dialogo.add_child(dialogo.speaker_label)
	dialogo.text_label = Label.new()
	dialogo.add_child(dialogo.text_label)
	dialogo.hint_label = Label.new()
	dialogo.add_child(dialogo.hint_label)
	dialogo._seleccionar_tema_conversacion({
		"clave": "trabajo",
		"texto": "Trabajo",
		"jugador": "¿Cómo va el trabajo?",
		"respuesta": "Todo marcha bien."
	})
	dialogo._indice_caracter = dialogo._texto_completo.length()
	dialogo._actualizar_boton_accion()
	if dialogo._respuestas.size() != 4 or dialogo._respuestas_container.get_child_count() != 4:
		errores.append("El menú social no volvió tras responder a un tema cotidiano.")

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
