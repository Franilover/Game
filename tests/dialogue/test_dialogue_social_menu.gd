extends Node

const CreatureScene = preload("res://scenes/creatures/creature.tscn")
const DialogueSystemScript = preload("res://scripts/gameplay/dialogue_system.gd")
const NPCVoiceProfileScript = preload("res://scripts/gameplay/npc_voice_profile.gd")
const NPCConversationSystemScript = preload("res://scripts/world/npc_conversation_system.gd")
const CutsceneDirectorScript = preload("res://scripts/gameplay/cutscene_director.gd")
const PlayerScene = preload("res://scenes/characters/player.tscn")


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

	# Las escenas de Ivo y Nima deben avanzar por consentimiento y hechos,
	# no por amenazas o conflictos que ninguno de los dos ha provocado.
	var conversaciones: Array = NPCConversationSystemScript.CONVERSACIONES_HABITANTES
	var investigacion_ivo: Dictionary = {}
	var contacto_saira_ivo: Dictionary = {}
	for conversacion_variant in conversaciones:
		if not conversacion_variant is Dictionary:
			continue
		var conversacion := conversacion_variant as Dictionary
		match str(conversacion.get("clave", "")):
			"nima_ivo_investigacion":
				investigacion_ivo = conversacion
			"saira_ivo_contacto":
				contacto_saira_ivo = conversacion
	if investigacion_ivo.is_empty() or contacto_saira_ivo.is_empty():
		errores.append("No se encontraron las conversaciones de Ivo con Nima y Saira.")
	else:
		for etapa_clave in ["lineas", "lineas_siguientes", "lineas_tercera_etapa"]:
			var etapa_variant: Variant = investigacion_ivo.get(etapa_clave, [])
			if not etapa_variant is Array:
				continue
			var textos: Array[String] = []
			for linea_variant in etapa_variant as Array:
				if linea_variant is Dictionary:
					textos.append(str((linea_variant as Dictionary).get("texto", "")))
			var intercambio := " ".join(textos).to_lower()
			if intercambio.contains("caso de estudio") or intercambio.contains("me voy"):
				errores.append("La etapa %s de Nima e Ivo inventa una amenaza o una ofensa." % etapa_clave)
		if not str(investigacion_ivo.get("lineas", [])).contains("te cuento lo que recuerde"):
			errores.append("Ivo no responde con naturalidad a la petición respetuosa de Nima.")
		var contacto_lineas: Array = contacto_saira_ivo.get("lineas", [])
		var contacto_texto := ""
		for linea_variant in contacto_lineas:
			if linea_variant is Dictionary:
				contacto_texto += " " + str((linea_variant as Dictionary).get("texto", ""))
		if contacto_texto.contains("todo Torres está hablando de mí"):
			errores.append("Ivo supone que todo el pueblo habla de él sin que la escena lo justifique.")
		if not contacto_texto.contains("¿Quién te lo comentó?"):
			errores.append("Ivo no pregunta de forma concreta por el origen de la información.")

	# Las cinemáticas también deben evitar frases grandilocuentes que no
	# corresponden a la situación concreta.
	var reuniones: Array = NPCConversationSystemScript.CONVERSACIONES_REUNION_CASTILLO
	var escena_mara_darven: Dictionary = {}
	var escena_ivo_elian: Dictionary = {}
	for reunion_variant in reuniones:
		if not reunion_variant is Dictionary:
			continue
		var reunion := reunion_variant as Dictionary
		match str(reunion.get("clave", "")):
			"noche_mara_darven_puerta":
				escena_mara_darven = reunion
			"noche_ivo_elian_mesa":
				escena_ivo_elian = reunion
	if escena_mara_darven.is_empty() or escena_ivo_elian.is_empty():
		errores.append("No se encontraron las cinemáticas de Mara-Darven e Ivo-Elian.")
	else:
		var escena_mara_texto := str(escena_mara_darven.get("lineas", []))
		if escena_mara_texto.contains("entregues la vida de alguien") or escena_mara_texto.contains("No te pediré que mientas"):
			errores.append("La escena de Mara y Darven dramatiza innecesariamente una petición de información.")
		var escena_ivo_texto := str(escena_ivo_elian.get("lineas", []))
		if escena_ivo_texto.contains("todos cambiaran sus planes por mí") or escena_ivo_texto.contains("la comida no se va a marchar"):
			errores.append("La escena de Ivo y Elian conserva una respuesta demasiado escrita para la situación.")

	# Las cadenas con etapas son historia; reuniones y sucesos diarios
	# siguen siendo opcionales y pueden volver a aparecer.
	var historia_principal: Dictionary = NPCConversationSystemScript.CONVERSACIONES[0]
	var historia_local: Dictionary = NPCConversationSystemScript.CONVERSACIONES_HABITANTES[0]
	var charla_reunion: Dictionary = NPCConversationSystemScript.CONVERSACIONES_REUNION_CASTILLO[0]
	var acontecimiento: Dictionary = NPCConversationSystemScript.ACONTECIMIENTOS_DIARIOS[0]
	if not NPCConversationSystemScript.es_conversacion_historia(historia_principal):
		errores.append("Las cadenas principales deben clasificarse como historia.")
	if not NPCConversationSystemScript.es_conversacion_historia(historia_local):
		errores.append("Las historias locales de habitantes deben clasificarse como historia.")
	# Las historias de Ivo forman una cadena: cada hilo debe terminar sus
	# tres etapas antes de desbloquear el siguiente, no basta con iniciarlo.
	var requisito_nima: Dictionary = investigacion_ivo.get("requiere_progreso", {})
	var requisito_saira: Dictionary = contacto_saira_ivo.get("requiere_progreso", {})
	if str(requisito_nima.get("clave", "")) != "mara_ivo_apoyo" or int(requisito_nima.get("etapa", 0)) != 3:
		errores.append("La investigación de Nima debe esperar a que concluya la historia de apoyo de Mara e Ivo.")
	if str(requisito_saira.get("clave", "")) != "nima_ivo_investigacion" or int(requisito_saira.get("etapa", 0)) != 3:
		errores.append("El contacto de Saira debe esperar a que concluya la investigación de Nima e Ivo.")
	if not NPCConversationSystemScript.es_conversacion_opcional(charla_reunion):
		errores.append("Las reuniones ambientales deben ser opcionales.")
	if not NPCConversationSystemScript.es_conversacion_opcional(acontecimiento):
		errores.append("Los acontecimientos diarios deben ser opcionales.")

	# Las historias pueden esperar a un día y una franja concretos.
	var historia_programada := historia_local.duplicate(true)
	historia_programada["activacion_historia"] = {"anio": 2, "dia": 7, "hora_desde": 9.0, "hora_hasta": 12.0}
	if not NPCConversationSystemScript.cumple_activacion_historia(historia_programada, {"anio": 2, "dia": 7, "hora_del_dia": 10.0}):
		errores.append("La historia programada no se activa dentro de su día y horario.")
	if NPCConversationSystemScript.cumple_activacion_historia(historia_programada, {"anio": 2, "dia": 8, "hora_del_dia": 10.0}):
		errores.append("La historia programada se activa fuera del día acordado.")

	var npc := CreatureScene.instantiate() as Creature
	var dialogo := DialogueSystemScript.new() as DialogueSystem
	if npc == null or dialogo == null:
		_fail(["No se pudieron crear los objetos de prueba."])
		return

	add_child(npc)
	add_child(dialogo)
	var conversacion_visual := NPCConversationSystemScript.new() as NPCConversationSystem
	add_child(conversacion_visual)
	conversacion_visual._npc_por_nombre = {"mara": npc}
	conversacion_visual._conversacion_activa = {
		"clave": "historia_dialogo_compartido_test",
		"tipo_contenido": "historia",
		"lineas": [
			{"npc": "mara", "texto": "Esta escena debe usar el diálogo normal."},
			{"npc": "ivo", "texto": "Y conservar el cambio de hablante."}
		],
		"fondo": "res://assets/art/backgrounds/historia_test.png"
	}
	var datos_historia := conversacion_visual.obtener_dialogo_historia("historia_dialogo_compartido_test")
	var lineas_historia: Array = datos_historia.get("lineas", [])
	if lineas_historia.size() != 2:
		errores.append("La historia no se convirtió en una secuencia completa de diálogo compartido.")
	elif str(lineas_historia[0].get("hablante", "")) != "Mara" or str(lineas_historia[1].get("hablante", "")) != "ivo":
		errores.append("La conversión de historia no conservó los hablantes de cada intervención.")
	if str(datos_historia.get("fondo", "")) != "res://assets/art/backgrounds/historia_test.png":
		errores.append("La conversión de historia perdió la referencia opcional a su imagen de fondo.")
	conversacion_visual._conversacion_activa.clear()
	var burbuja_prueba := conversacion_visual._obtener_burbuja(npc)
	var texto_burbuja := burbuja_prueba.get_node_or_null("Text") as Label
	if texto_burbuja == null or texto_burbuja.has_theme_font_override("font"):
		errores.append("Las burbujas ambientales deben heredar la tipografía normal, no Pixelgrafia.")
	if ResourceLoader.exists("res://assets/art/UI/Menus/button_normal.png"):
		if not burbuja_prueba.get_theme_stylebox("panel") is StyleBoxTexture:
			errores.append("Las burbujas ambientales no usan el fondo button_normal.")
	npc.nombre_individual = "Ivo"
	dialogo._fuente = npc
	var recuerdo_ivo := dialogo._crear_dialogo_recuerdo_social({
		"tipo": "tema_conversacion",
		"titulo": "los viajes de Saira",
		"frase_jugador": "¿Crees que Saira debería viajar menos?",
		"respuesta_npc": "No quiero decidir eso por ella."
	})
	var texto_recuerdo_ivo := str(recuerdo_ivo.get("lineas", [{}])[0].get("texto", ""))
	if not texto_recuerdo_ivo.contains("los viajes de Saira") or not texto_recuerdo_ivo.contains("¿Cómo te fue con eso al final?"):
		errores.append("Ivo no retoma el tema anterior con una pregunta cotidiana.")
	if texto_recuerdo_ivo.contains("Dijiste:") or texto_recuerdo_ivo.contains("¿Crees que Saira debería viajar menos?"):
		errores.append("Ivo repite literalmente la frase anterior en vez de continuar la charla.")
	npc.nombre_individual = "Mara"
	var recuerdo_mara := dialogo._crear_dialogo_recuerdo_social({
		"tipo": "tema_conversacion",
		"titulo": "su vida en Torres",
		"frase_jugador": "Me gusta este pueblo.",
		"respuesta_npc": "Me alegra que te sientas a gusto."
	})
	var texto_recuerdo_mara := str(recuerdo_mara.get("lineas", [{}])[0].get("texto", ""))
	if not texto_recuerdo_mara.contains("Si todavía quieres hablar de eso, te escucho"):
		errores.append("Mara no conserva su forma prudente de retomar un tema personal.")
	npc.nombre_individual = "Nima"
	var recuerdo_nima := dialogo._crear_dialogo_recuerdo_social({
		"tipo": "tema_conversacion",
		"titulo": "las observaciones Oris",
		"frase_jugador": "Vi algo extraño cerca del río.",
		"respuesta_npc": "Habría que comprobarlo."
	})
	var texto_recuerdo_nima := str(recuerdo_nima.get("lineas", [{}])[0].get("texto", ""))
	if not texto_recuerdo_nima.contains("¿Averiguaste algo más?"):
		errores.append("Nima no formula una continuación coherente con su curiosidad.")
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
	npc.nombre_individual = "Nima"
	npc.datos["actividad_actual"] = "caminar"
	var trabajo_nima_caminando := dialogo._crear_opcion_trabajo_social()
	if str(trabajo_nima_caminando.get("respuesta", "")).contains("observando algunos fenómenos Oris"):
		errores.append("Nima afirma estar observando fenómenos Oris aunque sólo está caminando.")
	npc.datos["actividad_actual"] = "investigar_oris"
	var trabajo_nima_investigando := dialogo._crear_opcion_trabajo_social()
	if not str(trabajo_nima_investigando.get("respuesta", "")).contains("investigando fenómenos Oris"):
		errores.append("Nima no refleja su investigación actual al hablar de sus estudios.")
	npc.nombre_individual = "Bruna"
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

	# Una escena debe devolver la cámara, el estado de locomoción y el bloqueo modal.
	var jugador_prueba := PlayerScene.instantiate() as Player
	var camara_prueba := Camera2D.new()
	var director_prueba := CutsceneDirectorScript.new() as CutsceneDirector
	add_child(jugador_prueba)
	add_child(camara_prueba)
	add_child(director_prueba)
	await get_tree().process_frame
	camara_prueba.zoom = Vector2(2.0, 2.0)
	director_prueba.configurar(jugador_prueba, dialogo, camara_prueba)
	# Un NPC sin la metadata opcional cinematica_npc_activa debe poder
	# congelarse y restaurarse sin provocar errores de Object.get_meta().
	if npc.has_meta("cinematica_npc_activa"):
		npc.remove_meta("cinematica_npc_activa")
	director_prueba._guardar_estado_npc(npc)
	if not npc.has_meta("cinematica_npc_activa"):
		errores.append("La captura no marcó al NPC durante la cinemática.")
	director_prueba._restaurar_estado_temporal()
	if npc.has_meta("cinematica_npc_activa"):
		errores.append("La restauración dejó metadata cinematica_npc_activa que antes no existía.")
	if not npc.has_meta("rutina_en_transito") or not bool(npc.get_meta("rutina_en_transito")):
		errores.append("La restauración no conservó la metadata previa de la rutina del NPC.")
	# Incluso si un recurso antiguo solicita el modo en vivo, se normaliza a escena congelada.
	if director_prueba._normalizar_modo_cinematica("en_vivo") != "planeada":
		errores.append("El director todavía permite cinematográficas en tiempo real.")
	for ruta_recurso in [
		"res://resources/cutscenes/intercambio_social.tres",
		"res://resources/cutscenes/intercambio_interrumpido.tres",
		"res://resources/cutscenes/intercambio_con_tercero.tres",
		"res://resources/cutscenes/reunion_trio.tres"
	]:
		var secuencia := load(ruta_recurso) as CutsceneSequence
		if not is_instance_valid(secuencia) or secuencia.modo != "planeada":
			errores.append("La secuencia %s no está configurada como reproducción congelada." % ruta_recurso)
	jugador_prueba.velocity = Vector2(25.0, 0.0)
	jugador_prueba.state = Player.State.RUN
	camara_prueba.global_position = Vector2(600.0, 400.0)
	camara_prueba.zoom = Vector2(0.7, 0.7)
	director_prueba._ocupado = true
	director_prueba._clave_actual = "test_restauracion"
	director_prueba._modo_cinematica = "en_vivo"
	director_prueba.add_to_group("modal_ui")
	director_prueba._finalizar()
	if director_prueba.esta_activo() or director_prueba.is_in_group("modal_ui"):
		errores.append("La finalización de la cinemática dejó activo el bloqueo modal.")
	if camara_prueba.global_position.distance_to(jugador_prueba.global_position) > 0.01 or camara_prueba.zoom.distance_to(Vector2(2.0, 2.0)) > 0.01:
		errores.append("La finalización no devolvió la cámara y su zoom al jugador.")
	if jugador_prueba.velocity.length_squared() > 0.01 or jugador_prueba.state != Player.State.IDLE:
		errores.append("La finalización no restableció la locomoción del jugador.")

	conversacion_visual.queue_free()
	director_prueba.queue_free()
	camara_prueba.queue_free()
	jugador_prueba.queue_free()
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
