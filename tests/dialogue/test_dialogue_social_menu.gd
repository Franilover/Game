extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const DialogueSystemScript = preload("res://scripts/gameplay/dialogue_system.gd")
const NPCVoiceProfileScript = preload("res://scripts/gameplay/npc_voice_profile.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []

	# Las voces se adaptan por personaje, sin imponer el mismo registro a todos.
	var voz_mara := NPCVoiceProfileScript.adaptar("Podemos quedarnos aquí. No hay ninguna prisa.", "Mara")
	if voz_mara != "Si quieres, nos quedamos aquí. No tenemos apuro.":
		errores.append("Mara no conserva su tono tranquilo y reservado.")
	var voz_ivo := NPCVoiceProfileScript.adaptar("Se me acabó la energía antes de llegar a la otra punta de la plaza.", "Ivo")
	if voz_ivo != "Me quedé sin fuerzas antes de llegar al otro lado de la plaza.":
		errores.append("Ivo no conserva su forma directa y cotidiana de hablar.")
	var voz_nima := NPCVoiceProfileScript.adaptar("No quiero inventar una explicación. Sólo reunir observaciones y ver si aparece algún patrón.", "Nima")
	if voz_nima != "No quiero sacar conclusiones sin pruebas. Quiero juntar observaciones y ver si aparece algún patrón.":
		errores.append("Nima no conserva su curiosidad cuidadosa sin sonar como un informe.")
	var voz_darven := NPCVoiceProfileScript.adaptar("¿Te apetece hablar?", "Darven")
	if voz_darven != "¿Te apetece hablar?":
		errores.append("El perfil común impuso un modismo que no corresponde a todas las voces.")

	var npc := CreatureScene.instantiate() as Creature
	var dialogo := DialogueSystemScript.new() as DialogueSystem
	if npc == null or dialogo == null:
		_fail(["No se pudieron crear los objetos de prueba."])
		return

	add_child(npc)
	add_child(dialogo)
	npc.set_meta("rutina_en_transito", true)
	dialogo._fuente = npc

	# Las respuestas de rutina también deben distinguir a los habitantes,
	# incluso cuando no tienen un tema narrativo cargado desde los datos.
	npc.nombre_individual = "Mara"
	if not dialogo._obtener_reaccion_pregunta_rutina().contains("hablar con todo el mundo"):
		errores.append("Mara recibió una respuesta genérica al preguntarle cómo está.")
	if not dialogo._obtener_reaccion_apoyo_rutina().contains("dejar que alguien se acerque"):
		errores.append("Mara recibió una respuesta de apoyo que no refleja su carácter reservado.")
	npc.nombre_individual = "Ivo"
	if not dialogo._obtener_reaccion_pregunta_rutina().contains("me pasé con el paseo"):
		errores.append("Ivo recibió una respuesta genérica al preguntarle cómo está.")
	if not dialogo._obtener_reaccion_conocimiento_rutina().contains("no siempre pueda ir a comprobarlas"):
		errores.append("Ivo recibió una respuesta de conocimiento que no considera su propio ritmo.")
	npc.nombre_individual = "Nima"
	if not dialogo._obtener_reaccion_pregunta_rutina().contains("descansar la cabeza"):
		errores.append("Nima recibió una respuesta genérica al preguntarle cómo está.")
	if not dialogo._obtener_reaccion_conocimiento_rutina().contains("antes de sacar conclusiones"):
		errores.append("Nima recibió una respuesta de conocimiento que no refleja su cautela.")
	npc.nombre_individual = "Bruna"


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
	if not despedida_caminando.contains("Voy a seguir hacia la plaza"):
		errores.append("La despedida de un NPC que camina no reconoce que sólo está desplazándose.")
	if not dialogo._obtener_frase_despedida_jugador_rutina().contains("sigue con tu camino"):
		errores.append("La despedida del jugador sigue tratando como ocupado a un NPC que sólo camina.")
	if not dialogo._actividad_es_desplazamiento("caminar") or not dialogo._actividad_es_desplazamiento("caminando") or not dialogo._actividad_es_desplazamiento("paseando") or not dialogo._actividad_es_desplazamiento("recorriendo") or dialogo._actividad_impide_una_conversacion_larga("caminar"):
		errores.append("Caminar se clasificó como una actividad que impide conversar.")
	var saludo_en_transito := dialogo._obtener_texto_rutina_personaje("bruna", "rutina", "caminar", "la plaza", true, false, false)
	if saludo_en_transito.contains("no puedo parar") or saludo_en_transito.contains("ocupado") or not (saludo_en_transito.contains("¿Qué necesitas?") or saludo_en_transito.contains("¿qué pasa?")):
		errores.append("El saludo de tránsito de Bruna no suena como una interrupción natural.")
	var saludo_en_edificio := dialogo._obtener_texto_rutina_personaje("bruna", "rutina", "caminar", "la plaza", true, true, false)
	if saludo_en_edificio.contains("plaza") or saludo_en_edificio.contains("Voy hacia") or saludo_en_edificio.contains("Tengo que llegar"):
		errores.append("Un NPC que camina dentro de un edificio anunció un destino exterior.")

	if not dialogo._dialogo_requiere_lectura_lenta():
		errores.append("Un NPC que camina no activa el ritmo de lectura pausado.")
	dialogo._contexto_rutina_conversacion["actividad"] = "trabajar"
	if dialogo._dialogo_requiere_lectura_lenta():
		errores.append("Un NPC que trabaja recibió el ajuste de lectura reservado al desplazamiento.")
	dialogo._contexto_rutina_conversacion["actividad"] = "caminar"

	dialogo._contexto_rutina_conversacion = {
		"actividad": "",
		"destino": "la plaza",
		"en_transito": false
	}
	npc.nombre_individual = "Bruna"
	var despedida_bruna_libre := dialogo._obtener_reaccion_despedida_rutina()
	if despedida_bruna_libre.contains("terminar esto") or despedida_bruna_libre.contains("tengo que"):
		errores.append("Bruna afirma que debe terminar un trabajo aunque no tiene una actividad laboral activa.")
	npc.nombre_individual = "Elian"
	var despedida_elian_libre := dialogo._obtener_reaccion_despedida_rutina()
	if despedida_elian_libre.contains("No interrumpes") or despedida_elian_libre.contains("vuelva a tener un momento"):
		errores.append("Elian responde como si estuviera ocupado aunque no tiene una tarea activa.")

	dialogo._contexto_rutina_conversacion = {
		"actividad": "forjar",
		"destino": "la forja",
		"en_transito": false
	}
	npc.nombre_individual = "Bruna"
	var despedida_trabajando := dialogo._obtener_reaccion_despedida_rutina()
	if not despedida_trabajando.contains("terminar esta pieza") or despedida_trabajando.contains("No interrumpes"):
		errores.append("La despedida contradice el contexto de Bruna mientras trabaja en una pieza.")

	dialogo._contexto_rutina_conversacion = {
		"actividad": "caminar",
		"destino": "la plaza",
		"en_transito": true
	}
	var despedida_en_transito := dialogo._obtener_reaccion_despedida_rutina()
	if not despedida_en_transito.contains("Voy a seguir hacia la plaza"):
		errores.append("La despedida de un NPC que camina en tránsito no debe cambiar a un encargo laboral.")
	dialogo._contexto_rutina_conversacion["dentro_edificio"] = true
	var despedida_en_edificio := dialogo._obtener_reaccion_despedida_rutina()
	if despedida_en_edificio.contains("plaza") or despedida_en_edificio.contains("Voy a seguir hacia"):
		errores.append("La despedida de un NPC que camina dentro del edificio anunció un destino exterior.")
	if not dialogo._obtener_frase_despedida_jugador_rutina().contains("por aquí"):
		errores.append("La despedida del jugador no reconoce que el NPC camina dentro del edificio.")

	# Las opciones sociales no deben presentar caminar o pasear como trabajo.
	npc.nombre_individual = "Bruna"
	npc.datos["actividad_actual"] = "caminar"
	dialogo._fuente = npc
	var trabajo_caminando := dialogo._crear_opcion_trabajo_social()
	if str(trabajo_caminando.get("respuesta", "")).contains("caminar") or str(trabajo_caminando.get("respuesta", "")).contains("pasear"):
		errores.append("La pregunta por el trabajo presenta un desplazamiento como una obligación.")
	var ayuda_caminando := dialogo._obtener_respuesta_ayuda_npc()
	if ayuda_caminando.contains("estoy con caminar") or ayuda_caminando.contains("estoy con pasear"):
		errores.append("La respuesta sobre ayuda presenta caminar como una tarea laboral.")
	npc.datos["actividad_actual"] = "forjar"
	var trabajo_forjando := dialogo._crear_opcion_trabajo_social()
	if not str(trabajo_forjando.get("respuesta", "")).contains("trabajando en la forja"):
		errores.append("La pregunta por el trabajo no traduce la actividad de forjar a una frase natural.")
	var ayuda_forjando := dialogo._obtener_respuesta_ayuda_npc()
	if not ayuda_forjando.contains("trabajando en la forja"):
		errores.append("La respuesta sobre ayuda no conserva la actividad laboral real.")
	# Preguntar por el día debe reflejar la actividad actual y el momento.
	npc.nombre_individual = "Bruna"
	npc.datos["actividad_actual"] = "forjar"
	var dia_forjando := dialogo._crear_opcion_dia_social()
	if not str(dia_forjando.get("respuesta", "")).contains("trabajando en la forja"):
		errores.append("La respuesta sobre el día ignora que Bruna está trabajando en la forja.")
	npc.datos["actividad_actual"] = "caminar"
	var dia_caminando := dialogo._crear_opcion_dia_social()
	if str(dia_caminando.get("respuesta", "")).contains("estoy caminando"):
		errores.append("La respuesta sobre el día presenta caminar como una tarea laboral.")
	npc.datos["actividad_actual"] = "pasear"
	if not dialogo._obtener_descripcion_actividad_dialogo("pasear").is_empty():
		errores.append("Pasear debe quedar fuera de las descripciones de trabajo.")
	if dialogo._obtener_descripcion_actividad_dialogo("descansar") != "":
		errores.append("Descansar no debe presentarse como una tarea laboral.")


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
