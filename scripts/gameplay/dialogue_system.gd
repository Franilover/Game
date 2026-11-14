extends Node
class_name DialogueSystem

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")


signal dialogue_started(speaker: String)
signal dialogue_finished


var player: Player = null
var ui_root: HUD = null
var mission_manager: MissionManagerService = null
var relationship_system: RelationshipSystemService = null

var dialogue_panel: PanelContainer = null
var speaker_label: Label = null
var portrait_rect: TextureRect = null
var text_label: Label = null
var hint_label: Label = null
var action_button: Button = null
var cancel_button: Button = null
var _botones_accion: HBoxContainer = null

var _acciones: Array[Dictionary] = []
var _respuestas: Array[Dictionary] = []
var _respuestas_container: GridContainer = null
var _inventario: InventoryController = null
var _boton_regalo: Button = null
var _boton_preguntar_item: Button = null
var _dialogue_content_row: HBoxContainer = null
var _selector_conversacion: PanelContainer = null
var _selector_conversacion_grid: GridContainer = null
var _selector_items: PanelContainer = null
var _selector_items_grid: GridContainer = null
var _selector_items_titulo: Label = null
var _modo_selector_items: String = ""

var _abierto: bool = false
var _dialogo_en_transito: bool = false
var _lineas: Array[Dictionary] = []
var _indice_linea: int = 0
var _fuente: Creature = null

var _texto_completo: String = ""
var _indice_caracter: int = 0
var _temporizador_texto: float = 0.0
var _intervalo_caracter: float = 0.018
var _recuerdo_pendiente_mostrar: Dictionary = {}
var _personaje_recuerdo_pendiente: String = ""
var _variante_pendiente_mostrar: Dictionary = {}
var _personaje_variante_pendiente: String = ""
var _ciclo_variante_pendiente: String = ""


func _ready() -> void:
	add_to_group("dialogue_system")


func configurar(
	nuevo_player: Player,
	nuevo_ui_root: HUD,
	nuevo_mission_manager: MissionManagerService = null,
	nuevo_relationship_system: RelationshipSystemService = null
) -> void:
	player = nuevo_player
	ui_root = nuevo_ui_root
	mission_manager = nuevo_mission_manager
	relationship_system = nuevo_relationship_system
	_crear_interfaz()


func configurar_inventario(nuevo_inventario: InventoryController) -> void:
	_inventario = nuevo_inventario


func _process(delta: float) -> void:
	if not _abierto:
		return

	if _indice_caracter >= _texto_completo.length():
		return

	_temporizador_texto -= delta
	if _temporizador_texto > 0.0:
		return

	_temporizador_texto = _intervalo_caracter
	_indice_caracter += 1
	text_label.text = _texto_completo.substr(0, _indice_caracter)
	_actualizar_boton_accion()
	if _indice_caracter >= _texto_completo.length():
		_marcar_recuerdo_pendiente_mostrado()
		_marcar_variante_pendiente_mostrada()
		if _dialogo_en_transito and _indice_linea >= _lineas.size() - 1:
			cerrar()
			return


func _input(event: InputEvent) -> void:
	if not _abierto:
		return

	if event.is_action_pressed("primary_action"):
		# Los clics sobre controles de diálogo pertenecen a la interfaz.
		if event is InputEventMouseButton:
			var posicion_mouse := get_viewport().get_mouse_position()
			if _selector_items != null and _selector_items.visible and _selector_items.get_global_rect().has_point(posicion_mouse):
				return
			if _selector_conversacion != null and _selector_conversacion.visible and _selector_conversacion.get_global_rect().has_point(posicion_mouse):
				return
			# Las respuestas también son controles interactivos: el clic no debe
			# convertirse en un avance del diálogo antes de llegar al Button.
			if _respuestas_container != null and _respuestas_container.visible and _respuestas_container.get_global_rect().has_point(posicion_mouse):
				return
			if action_button != null and action_button.visible and action_button.get_global_rect().has_point(posicion_mouse):
				return
			if _boton_regalo != null and _boton_regalo.visible and _boton_regalo.get_global_rect().has_point(posicion_mouse):
				return
			if _boton_preguntar_item != null and _boton_preguntar_item.visible and _boton_preguntar_item.get_global_rect().has_point(posicion_mouse):
				return
		_avanzar()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_ESCAPE:
			if _selector_items != null and _selector_items.visible:
				_cerrar_selector_items()
			elif _selector_conversacion != null and _selector_conversacion.visible:
				_cerrar_selector_conversacion()
			else:
				cerrar()
			get_viewport().set_input_as_handled()


func esta_abierto() -> bool:
	return _abierto


func abrir_desde(fuente: Creature) -> bool:
	print("DialogueSystem: abrir_desde() → ", fuente.name if is_instance_valid(fuente) else "<invalido>")
	if fuente == null or not is_instance_valid(fuente):
		print("DialogueSystem: fuente invalida.")
		return false

	if not fuente is Creature:
		print("DialogueSystem: fuente de diálogo inválida.")
		return false

	var datos_variant: Variant = fuente.get_dialogue_data()
	print("DialogueSystem: datos recibidos = ", datos_variant is Dictionary, " | claves = ", datos_variant.keys() if datos_variant is Dictionary else [])
	if not datos_variant is Dictionary:
		return false

	return abrir(datos_variant as Dictionary, fuente)


func abrir(datos: Dictionary, fuente: Creature = null) -> bool:
	_recuerdo_pendiente_mostrar.clear()
	_personaje_recuerdo_pendiente = ""
	_variante_pendiente_mostrar.clear()
	_personaje_variante_pendiente = ""
	_ciclo_variante_pendiente = ""
	_fuente = fuente
	print("DialogueSystem: abrir() | fuente = ", fuente.name if is_instance_valid(fuente) else "<ninguna>")
	var datos_seleccionados := _seleccionar_dialogo(datos)
	var lineas := _normalizar_lineas(datos_seleccionados)
	var acciones_debug: Array = []
	var acciones_variant_debug: Variant = datos_seleccionados.get("acciones", [])
	if acciones_variant_debug is Array:
		acciones_debug = acciones_variant_debug

	print(
		"DialogueSystem: variante = ",
		str(datos_seleccionados.get("clave", "<sin clave>")),
		" | lineas = ",
		lineas.size(),
		" | acciones = ",
		acciones_debug.size()
	)

	if lineas.is_empty():
		print("DialogueSystem: ABORTADO → no hay lineas normalizadas.")
		return false

	if dialogue_panel == null:
		_crear_interfaz()

	if dialogue_panel == null:
		return false

	_fuente = fuente

	if is_instance_valid(_fuente):
		var personaje_id := _fuente.get_personaje_game_id().strip_edges()
		if not personaje_id.is_empty():
			if mission_manager != null:
				mission_manager.registrar_dialogo_desde_fuente(personaje_id, str(datos_seleccionados.get("clave", "principal")), _fuente)
			var datos_actualizados := _seleccionar_dialogo(datos)
			if str(datos_actualizados.get("clave", "")) != str(datos_seleccionados.get("clave", "")):
				datos_seleccionados = datos_actualizados
				lineas = _normalizar_lineas(datos_seleccionados)
				if lineas.is_empty():
					return false

	var recuerdo_para_mencionar: Dictionary = {}
	if _es_dialogo_cotidiano(datos_seleccionados) and relationship_system != null and is_instance_valid(_fuente):
		var id_recuerdo := _fuente.get_personaje_game_id().strip_edges()
		if not id_recuerdo.is_empty():
			var recuerdo_candidato: Dictionary = relationship_system.obtener_recuerdo_pendiente_mencionar(id_recuerdo)
			var dialogo_recuerdo := _crear_dialogo_recuerdo_social(recuerdo_candidato)
			if not dialogo_recuerdo.is_empty():
				recuerdo_para_mencionar = recuerdo_candidato
				datos_seleccionados = dialogo_recuerdo
				lineas = _normalizar_lineas(datos_seleccionados)

	_preparar_registro_variante(datos_seleccionados)
	_lineas = lineas
	_acciones.clear()
	_respuestas.clear()
	var respuestas_variant: Variant = datos_seleccionados.get("respuestas", datos_seleccionados.get("choices", []))
	if respuestas_variant is Array:
		for respuesta_variant in respuestas_variant as Array:
			if respuesta_variant is Dictionary and _respuestas.size() < 4:
				_respuestas.append((respuesta_variant as Dictionary).duplicate(true))
	_dialogo_en_transito = _es_dialogo_en_transito(datos_seleccionados)
	var clave_dialogo_respuestas := str(datos_seleccionados.get("clave", "principal")).strip_edges().to_lower()
	var acciones_final_variant: Variant = datos_seleccionados.get("acciones", [])
	var tiene_acciones_finales := acciones_final_variant is Array and not (acciones_final_variant as Array).is_empty()
	if not tiene_acciones_finales and is_instance_valid(_fuente) and not _dialogo_en_transito:
		_respuestas = _crear_opciones_conversacion()
	_limpiar_botones_respuesta()

	if is_instance_valid(_fuente):
		var personaje_id_social := _fuente.get_personaje_game_id().strip_edges()
		if not personaje_id_social.is_empty():
			var social: RelationshipSystemService = relationship_system
			if social != null:
				social.registrar_dialogo(personaje_id_social, str(datos_seleccionados.get("clave", "principal")))

	var acciones_variant: Variant = datos_seleccionados.get("acciones", [])
	if acciones_variant is Array:
		for accion_variant in acciones_variant as Array:
			if accion_variant is Dictionary:
				_acciones.append((accion_variant as Dictionary).duplicate(true))

	_indice_linea = 0
	_abierto = true

	if is_instance_valid(_fuente):
		_fuente.pausar_movimiento_temporal()

	dialogue_panel.visible = true
	if _boton_regalo != null:
		_boton_regalo.visible = not _dialogo_en_transito
	if _boton_preguntar_item != null:
		_boton_preguntar_item.visible = not _dialogo_en_transito
	print(
		"DialogueSystem: PANEL VISIBLE → ",
		dialogue_panel.get_path() if dialogue_panel.is_inside_tree() else dialogue_panel.name,
		" | pos=",
		dialogue_panel.position,
		" | size=",
		dialogue_panel.size
	)
	if not recuerdo_para_mencionar.is_empty() and relationship_system != null:
		_recuerdo_pendiente_mostrar = recuerdo_para_mencionar.duplicate(true)
		_personaje_recuerdo_pendiente = _fuente.get_personaje_game_id().strip_edges() if is_instance_valid(_fuente) else ""
	_mostrar_linea_actual()

	var hablante := str(_lineas[0].get("hablante", "")).strip_edges()
	if hablante.is_empty() and is_instance_valid(_fuente):
		hablante = _fuente.get_nombre()

	speaker_label.text = hablante
	dialogue_started.emit(hablante)
	Events.dialog_opened.emit(hablante, _texto_completo)

	return true


func cerrar() -> void:
	if not _abierto:
		return

	_abierto = false
	_lineas.clear()
	_respuestas.clear()
	_limpiar_botones_respuesta()
	_indice_linea = 0
	_texto_completo = ""
	_indice_caracter = 0
	_temporizador_texto = 0.0

	if is_instance_valid(_fuente):
		_fuente.reanudar_movimiento_temporal()

	_fuente = null
	_dialogo_en_transito = false
	_acciones.clear()
	_recuerdo_pendiente_mostrar.clear()
	_personaje_recuerdo_pendiente = ""
	_variante_pendiente_mostrar.clear()
	_personaje_variante_pendiente = ""
	_ciclo_variante_pendiente = ""

	if action_button != null:
		action_button.visible = false
	if cancel_button != null:
		cancel_button.visible = false
	_cerrar_selector_items()
	_cerrar_selector_conversacion()
	if dialogue_panel != null:
		dialogue_panel.visible = false

	dialogue_finished.emit()
	Events.dialog_closed.emit()


func _avanzar() -> void:
	if _indice_caracter < _texto_completo.length():
		_indice_caracter = _texto_completo.length()
		text_label.text = _texto_completo
		_marcar_recuerdo_pendiente_mostrado()
		_marcar_variante_pendiente_mostrada()
		return

	if _indice_linea >= _lineas.size() - 1 and not _respuestas.is_empty():
		_actualizar_boton_accion()
		return

	_indice_linea += 1

	if _indice_linea >= _lineas.size():
		cerrar()
		return

	_mostrar_linea_actual()


## Consume el recuerdo sólo cuando el jugador ha podido ver la primera línea completa.
## Cerrar el diálogo durante el texto progresivo no lo marca como mencionado.
func _marcar_recuerdo_pendiente_mostrado() -> void:
	if _recuerdo_pendiente_mostrar.is_empty() or relationship_system == null:
		return
	if _personaje_recuerdo_pendiente.is_empty():
		return
	var indice := int(_recuerdo_pendiente_mostrar.get("_indice_recuerdo", -1))
	var uid := str(_recuerdo_pendiente_mostrar.get("recuerdo_uid", ""))
	if indice < 0:
		return
	if relationship_system.marcar_recuerdo_mencionado(_personaje_recuerdo_pendiente, indice, uid):
		_recuerdo_pendiente_mostrar.clear()
		_personaje_recuerdo_pendiente = ""


## Prepara el registro de una variante que debe dejar de repetirse tras verla.
func _preparar_registro_variante(datos_dialogo: Dictionary) -> void:
	_variante_pendiente_mostrar.clear()
	_personaje_variante_pendiente = ""
	_ciclo_variante_pendiente = ""
	if relationship_system == null or not is_instance_valid(_fuente):
		return
	var clave := str(datos_dialogo.get("clave", "")).strip_edges()
	var ciclo := _obtener_ciclo_variante(datos_dialogo)
	if clave.is_empty() or ciclo.is_empty():
		return
	var personaje_id := _fuente.get_personaje_game_id().strip_edges()
	if personaje_id.is_empty():
		return
	_variante_pendiente_mostrar = datos_dialogo.duplicate(true)
	_personaje_variante_pendiente = personaje_id
	_ciclo_variante_pendiente = ciclo


## Las variantes sociales y de misión son únicas; las estacionales reaparecen
## sólo en el siguiente año del calendario del mundo.
func _obtener_ciclo_variante(variante: Dictionary) -> String:
	var repeticion := str(variante.get("repeticion", "")).strip_edges().to_lower()
	var contexto: Dictionary = {}
	if relationship_system != null and relationship_system.has_method("obtener_contexto_temporal"):
		var contexto_variant: Variant = relationship_system.call("obtener_contexto_temporal")
		if contexto_variant is Dictionary:
			contexto = contexto_variant
	var anio := int(contexto.get("anio", 0))
	var dia := int(contexto.get("dia", 0))
	var requisito_social_variant: Variant = variante.get("requisito_social", {})
	var requisito_mision_variant: Variant = variante.get("requisito", {})
	var requisito_contextual_variant: Variant = variante.get("requisito_contextual", {})
	if repeticion == "siempre":
		return ""
	if repeticion == "unica":
		return "unica"
	if repeticion == "diaria":
		return "dia:%d:%d" % [anio, dia]
	if repeticion == "anual":
		return "anio:%d" % anio
	if repeticion == "social" or (requisito_social_variant is Dictionary and not (requisito_social_variant as Dictionary).is_empty()):
		return "unica"
	if requisito_mision_variant is Dictionary and not (requisito_mision_variant as Dictionary).is_empty():
		return "unica"
	if requisito_contextual_variant is Dictionary and not (requisito_contextual_variant as Dictionary).is_empty():
		var requisito_contextual := requisito_contextual_variant as Dictionary
		if requisito_contextual.has("dias_del_anio") or requisito_contextual.has("dias_de_estacion") or requisito_contextual.has("dia_de_estacion_min") or requisito_contextual.has("dia_de_estacion_max"):
			return "anio:%d" % anio
		if requisito_contextual.has("estaciones"):
			return "estacion:%d:%s" % [anio, str(contexto.get("estacion_id", ""))]
		if requisito_contextual.has("periodos"):
			return "periodo:%d:%s" % [anio, str(contexto.get("periodo", ""))]
		return "dia:%d:%d" % [anio, dia]
	return ""


func _variante_ya_mostrada(variante: Dictionary, personaje_id: String) -> bool:
	var clave := str(variante.get("clave", "")).strip_edges()
	var ciclo := _obtener_ciclo_variante(variante)
	if clave.is_empty() or ciclo.is_empty() or relationship_system == null:
		return false
	return relationship_system.variante_dialogo_ya_mostrada(personaje_id, clave, ciclo)


func _marcar_variante_pendiente_mostrada() -> void:
	if _variante_pendiente_mostrar.is_empty() or relationship_system == null:
		return
	if _personaje_variante_pendiente.is_empty() or _ciclo_variante_pendiente.is_empty():
		return
	var clave := str(_variante_pendiente_mostrar.get("clave", "")).strip_edges()
	if relationship_system.registrar_variante_dialogo_mostrada(
		_personaje_variante_pendiente,
		clave,
		_ciclo_variante_pendiente
	):
		_variante_pendiente_mostrar.clear()
		_personaje_variante_pendiente = ""
		_ciclo_variante_pendiente = ""


func _mostrar_linea_actual() -> void:
	if _lineas.is_empty() or _indice_linea < 0 or _indice_linea >= _lineas.size():
		return

	var linea: Dictionary = _lineas[_indice_linea]

	var hablante := str(linea.get("hablante", "")).strip_edges()
	if hablante.is_empty() and is_instance_valid(_fuente):
		hablante = _fuente.get_nombre()

	var texto := str(
		linea.get(
			"texto",
			linea.get("text", "")
		)
	).strip_edges()

	speaker_label.text = hablante
	_actualizar_retrato(hablante)
	_texto_completo = texto
	_indice_caracter = 0
	_temporizador_texto = 0.0
	text_label.text = ""
	_actualizar_boton_accion()


func _actualizar_retrato(hablante: String) -> void:
	if portrait_rect == null:
		return

	var nombre := hablante.strip_edges()
	if is_instance_valid(_fuente):
		var nombre_individual := _fuente.nombre_individual.strip_edges()
		if nombre_individual.is_empty():
			nombre_individual = _fuente.get_nombre().strip_edges()
		if nombre.is_empty() or nombre.to_lower() == _fuente.get_nombre().strip_edges().to_lower():
			nombre = nombre_individual

	if nombre.is_empty():
		portrait_rect.texture = null
		portrait_rect.visible = false
		return

	var rutas: Array[String] = [
		"res://assets/art/characters/heads/" + nombre + ".png",
		"res://assets/art/characters/heads/" + nombre + ".PNG"
	]
	var textura: Texture2D = null
	for ruta in rutas:
		if ResourceLoader.exists(ruta):
			textura = load(ruta) as Texture2D
			if textura != null:
				break

	portrait_rect.texture = textura
	portrait_rect.visible = textura != null




## Los encuentros durante un desplazamiento son breves: el NPC no se detiene a conversar.
func _es_dialogo_en_transito(dialogo: Dictionary) -> bool:
	var clave := str(dialogo.get("clave", "")).strip_edges().to_lower()
	if clave == "rutina_en_transito":
		return true
	return is_instance_valid(_fuente) and bool(_fuente.get_meta("rutina_en_transito", false))


func _es_dialogo_cotidiano(dialogo: Dictionary) -> bool:
	var clave := str(dialogo.get("clave", "")).strip_edges().to_lower()
	return clave == "principal" or clave.begins_with("rutina_")


func _crear_dialogo_recuerdo_social(recuerdo: Dictionary) -> Dictionary:
	if recuerdo.is_empty() or not is_instance_valid(_fuente):
		return {}
	var nombre := _fuente.get_nombre_visual().strip_edges()
	var clave_nombre := nombre.to_lower()
	var tipo := str(recuerdo.get("tipo", "")).strip_edges()
	var texto := ""
	if tipo == "regalo":
		var item_nombre := str(recuerdo.get("item_nombre", "")).strip_edges()
		if item_nombre.is_empty():
			return {}
		var reaccion := str(recuerdo.get("reaccion", "neutral")).strip_edges().to_lower()
		match clave_nombre:
			"elian":
				texto = "Por cierto, todavía tengo presente el %s que me regalaste. Me ha alegrado tener ese detalle cerca." % item_nombre if reaccion in ["encanta", "gusta"] else "He estado pensando en el %s que me diste. Gracias por acordarte de mí." % item_nombre
			"bruna":
				texto = "Le encontré utilidad al %s que me trajiste. No suelo decirlo, pero fue un buen regalo." % item_nombre if reaccion in ["encanta", "gusta"] else "Sobre el %s que me diste: gracias por el gesto. Lo tengo presente."
			"darven":
				texto = "El %s que me entregaste me ha resultado útil. Aprecio que hayas pensado en ello." % item_nombre if reaccion in ["encanta", "gusta"] else "Quería agradecerte de nuevo el %s. Fue un gesto considerado." % item_nombre
			"saira":
				texto = "¡Ah! El %s que me regalaste. Me hizo ilusión; estas pequeñas cosas también cuentan historias." % item_nombre if reaccion in ["encanta", "gusta"] else "Me acuerdo del %s que me diste. Gracias, fue un detalle bonito." % item_nombre
			"narel":
				texto = "He conservado el %s que me diste. Es interesante cómo un objeto puede adquirir significado por su contexto." % item_nombre if reaccion in ["encanta", "gusta"] else "Recuerdo el %s que me entregaste. Gracias por el detalle." % item_nombre
			_:
				texto = "Quería agradecerte otra vez el %s que me regalaste." % item_nombre
	elif tipo == "tema_conversacion":
		var titulo_tema := str(recuerdo.get("titulo", "aquella conversación")).strip_edges()
		var frase_jugador := str(recuerdo.get("frase_jugador", "")).strip_edges()
		if frase_jugador.is_empty():
			return {}
		var respuesta_npc := str(recuerdo.get("respuesta_npc", "")).strip_edges()
		match clave_nombre:
			"elian":
				texto = "Me acordé de lo que hablamos sobre %s. Te conté esto: %s ¿Has pensado algo más desde entonces?" % [titulo_tema, respuesta_npc] if not respuesta_npc.is_empty() else "Me he quedado pensando en nuestra conversación sobre %s. Recuerdo que dijiste: %s ¿Cómo lo ves ahora?" % [titulo_tema, frase_jugador]
			"bruna":
				texto = "Sobre lo que hablamos de %s: te expliqué cómo lo veía. %s ¿Has llegado a alguna conclusión?" % [titulo_tema, respuesta_npc] if not respuesta_npc.is_empty() else "Sobre lo que hablamos de %s: recuerdo tu punto de vista. Dijiste: %s ¿Sigues pensando igual?" % [titulo_tema, frase_jugador]
			"darven":
				texto = "Quería retomar lo que hablamos sobre %s. Te comenté: %s ¿Has observado algo nuevo?" % [titulo_tema, respuesta_npc] if not respuesta_npc.is_empty() else "Quería retomar lo que hablamos sobre %s. Recuerdo que comentaste: %s ¿Ha cambiado algo desde entonces?" % [titulo_tema, frase_jugador]
			"saira":
				texto = "¡Me acordé de nuestra charla sobre %s! Te conté: %s ¿Y tú, has descubierto algo más?" % [titulo_tema, respuesta_npc] if not respuesta_npc.is_empty() else "¡Oye! Me acordé de nuestra charla sobre %s. Dijiste algo que se me quedó dando vueltas: %s ¿Todavía lo ves así?" % [titulo_tema, frase_jugador]
			"narel":
				texto = "He vuelto sobre nuestra conversación acerca de %s. Mi respuesta entonces fue: %s ¿Has encontrado algo que cambie nuestra interpretación?" % [titulo_tema, respuesta_npc] if not respuesta_npc.is_empty() else "He vuelto sobre nuestra conversación acerca de %s. Tu comentario fue: %s ¿Mantienes esa conclusión?" % [titulo_tema, frase_jugador]
			_:
				texto = "Recuerdo que hablamos sobre %s y que dijiste: %s" % [titulo_tema, frase_jugador]
	elif tipo == "evento_social":
		var evento := str(recuerdo.get("evento", "")).strip_edges().to_lower()
		var contexto_variant: Variant = recuerdo.get("contexto", {})
		var contexto: Dictionary = contexto_variant if contexto_variant is Dictionary else {}
		var detalle := str(contexto.get("asunto", contexto.get("descripcion", ""))).strip_edges()
		var frase_jugador := str(contexto.get("respuesta_jugador", "")).strip_edges()
		var frase := ""
		match evento:
			"promesa_cumplida":
				frase = "Cumpliste lo que me prometiste. No lo he olvidado."
			"promesa_rota":
				frase = "Sigo recordando que no cumpliste lo que me prometiste. Me cuesta dejarlo atrás."
			"mentir":
				frase = "Todavía tengo presente aquella mentira. Necesitaré tiempo para recuperar la confianza."
			"decir_verdad":
				frase = "He pensado en lo que me dijiste. Aprecio que hayas sido sincero conmigo."
			"traicionar":
				frase = "Lo que ocurrió entre nosotros fue importante. No puedo fingir que la confianza sigue igual."
			"faltar_respeto":
				frase = "No he olvidado cómo me hablaste aquella vez. Espero que podamos tratarnos con más consideración."
			"ayudar":
				frase = "Recuerdo que estuviste ahí para ayudarme. No doy ese gesto por sentado."
			"apoyar":
				frase = "Me acuerdo de que me apoyaste cuando lo necesitaba. Significó bastante."
			"compartir_conocimiento":
				frase = "He seguido pensando en lo que compartiste conmigo. Me resultó útil escucharte."
			"demostrar_habilidad":
				frase = "Recuerdo lo que me demostraste. Has dejado una buena impresión."
			_:
				return {}
		if not detalle.is_empty():
			frase = detalle + ": " + frase
		if not frase_jugador.is_empty():
			frase = "Recuerdo que dijiste: %s %s" % [frase_jugador, frase]
		match clave_nombre:
			"elian":
				texto = "Quería hablarte de algo que todavía recuerdo. " + frase
			"bruna":
				texto = frase + " Prefiero ser clara contigo."
			"darven":
				texto = "Hay algo que considero importante dejar claro. " + frase
			"saira":
				texto = "Oye, hay algo de lo que pasó que todavía me ronda. " + frase
			"narel":
				texto = "He revisado mentalmente lo ocurrido y hay algo que quiero señalar. " + frase
			_:
				texto = frase
	else:
		return {}
	if texto.is_empty():
		return {}
	return {
		"clave": "recuerdo_social",
		"lineas": [{"hablante": nombre, "texto": texto}]
	}


func _seleccionar_dialogo(datos: Dictionary) -> Dictionary:
	var variantes_variant: Variant = datos.get("variantes", [])
	if not variantes_variant is Array:
		var dialogo_rutina_sin_variantes := _crear_dialogo_rutina_contextual()
		return dialogo_rutina_sin_variantes if not dialogo_rutina_sin_variantes.is_empty() else datos.duplicate(true)

	var principal: Dictionary = {}
	var mission_manager_local: MissionManagerService = mission_manager
	for variante_variant in variantes_variant as Array:
		if not variante_variant is Dictionary:
			continue

		var variante := (variante_variant as Dictionary).duplicate(true)
		var requisito_variant: Variant = variante.get("requisito", {})
		if requisito_variant is Dictionary:
			var requisito := requisito_variant as Dictionary
			if not requisito.is_empty():
				if (
					mission_manager_local != null
					and mission_manager_local.cumple_requisito_dialogo(requisito)
					and not _variante_ya_mostrada(variante, _obtener_personaje_id_actual())
				):
					return variante
				continue

		if str(variante.get("clave", "")).strip_edges().to_lower() == "principal":
			principal = variante

	# Los estados de misión y las variantes narrativas específicas conservan prioridad.
	# Si no hay una conversación especial por calendario o relación, habla según su rutina.
	var personaje_id := ""
	if is_instance_valid(_fuente):
		personaje_id = _fuente.get_personaje_game_id().strip_edges()
	if not personaje_id.is_empty():
		# El diálogo raíz puede ser la presentación narrativa o el inicio de una misión.
		# Se muestra antes de las variantes sociales en el primer encuentro.
		if principal.is_empty() and (datos.has("lineas") or datos.has("texto")):
			var estado_inicial := relationship_system.obtener_estado_dialogo(personaje_id) if relationship_system != null else {}
			if bool(estado_inicial.get("primera_vez", false)):
				return datos.duplicate(true)

		var contextual := _seleccionar_variante_contextual(variantes_variant as Array, personaje_id)
		if not contextual.is_empty():
			return contextual

		var social: RelationshipSystemService = relationship_system
		if social != null:
			var variantes_sociales_disponibles: Array = []
			for variante_social_variant in variantes_variant as Array:
				if not variante_social_variant is Dictionary:
					continue
				var variante_social := variante_social_variant as Dictionary
				if not _variante_ya_mostrada(variante_social, personaje_id):
					variantes_sociales_disponibles.append(variante_social)
			var seleccion: Dictionary = social.seleccionar_variante_dialogo(variantes_sociales_disponibles, personaje_id)
			if not seleccion.is_empty() and str(seleccion.get("clave", "")).strip_edges().to_lower() != "principal":
				return seleccion.duplicate(true)

	var dialogo_rutina := _crear_dialogo_rutina_contextual()
	if not dialogo_rutina.is_empty():
		return dialogo_rutina

	if not principal.is_empty():
		return principal
	return datos.duplicate(true)


func _obtener_personaje_id_actual() -> String:
	if not is_instance_valid(_fuente):
		return ""
	return _fuente.get_personaje_game_id().strip_edges()


## Selecciona variantes condicionadas por el calendario del mundo.
## Una variante contextual puede combinar estación/día con requisitos sociales.
func _seleccionar_variante_contextual(variantes: Array, personaje_id: String) -> Dictionary:
	var social: RelationshipSystemService = relationship_system
	if social == null or not social.has_method("obtener_contexto_temporal"):
		return {}

	var contexto_variant: Variant = social.call("obtener_contexto_temporal")
	if not contexto_variant is Dictionary:
		return {}
	var contexto := contexto_variant as Dictionary
	if not bool(contexto.get("calendario_cargado", false)):
		return {}

	var relacion := social.obtener_relacion(personaje_id)
	var mejor: Dictionary = {}
	var mejor_prioridad := -2147483648

	for variante_variant in variantes:
		if not variante_variant is Dictionary:
			continue
		var variante := variante_variant as Dictionary
		var requisito_contextual_variant: Variant = variante.get("requisito_contextual", {})
		if not requisito_contextual_variant is Dictionary:
			continue
		var requisito_contextual := requisito_contextual_variant as Dictionary
		if requisito_contextual.is_empty() or not _cumple_requisito_contextual(requisito_contextual, contexto):
			continue
		if _variante_ya_mostrada(variante, personaje_id):
			continue

		var requisito_social_variant: Variant = variante_variant.get("requisito_social", {})
		if requisito_social_variant is Dictionary:
			var requisito_social := requisito_social_variant as Dictionary
			if not requisito_social.is_empty() and not _cumple_requisito_social_contextual(requisito_social, relacion):
				continue

		var prioridad := int(variante.get("prioridad", 0))
		if mejor.is_empty() or prioridad > mejor_prioridad:
			mejor = variante.duplicate(true)
			mejor_prioridad = prioridad

	return mejor


func _crear_dialogo_rutina_en_transito() -> Dictionary:
	return _crear_dialogo_rutina_contextual()


## Construye una respuesta desde el estado real que publica NPCScheduleSystem.
## El horario y la ubicación siguen siendo responsabilidad del sistema de rutinas;
## aquí sólo se adapta la conversación a ese estado.
func _crear_dialogo_rutina_contextual() -> Dictionary:
	if not is_instance_valid(_fuente):
		return {}

	var rutina_clave := str(_fuente.get_meta("rutina_actual", "")).strip_edges().to_lower()
	var ubicacion := str(_fuente.get_meta("rutina_ubicacion", "")).strip_edges().to_lower()
	var actividad := str(_fuente.datos.get("actividad_actual", "")).strip_edges().to_lower()
	var en_transito := bool(_fuente.get_meta("rutina_en_transito", false))
	var dentro_edificio := bool(_fuente.get_meta("rutina_en_edificio", false))
	if rutina_clave.is_empty() and ubicacion.is_empty() and actividad.is_empty() and not en_transito:
		return {}

	var nombre := _fuente.get_nombre_visual().strip_edges().to_lower()
	var destino := _nombre_ubicacion_rutina(ubicacion)
	var amable := _relacion_amable_actual()
	var texto := _obtener_texto_rutina_personaje(
		nombre,
		rutina_clave,
		actividad,
		destino,
		en_transito,
		dentro_edificio,
		amable
	)
	if texto.is_empty():
		return {}

	var clave_dialogo := "rutina_en_transito" if en_transito else "rutina_contextual"
	return {
		"clave": clave_dialogo,
		"lineas": [{"hablante": _fuente.get_nombre_visual(), "texto": texto}]
	}


func _relacion_amable_actual() -> bool:
	if not is_instance_valid(_fuente) or relationship_system == null:
		return false
	var personaje_id := _fuente.get_personaje_game_id().strip_edges()
	if personaje_id.is_empty():
		return false
	var relacion_actual := relationship_system.obtener_relacion(personaje_id)
	# La confianza y el respeto no equivalen por sí solos a cercanía afectiva.
	# Un NPC puede confiar en el jugador o respetarlo y mantener un trato formal.
	return (
		float(relacion_actual.get("amistad", 0.0)) >= 20.0
		or float(relacion_actual.get("afecto", 0.0)) >= 15.0
	)


func _nombre_ubicacion_rutina(ubicacion: String) -> String:
	var destinos := {
		"plaza": "la plaza",
		"panaderia": "la panadería",
		"forja": "la forja",
		"cuartel": "el cuartel de la guardia",
		"registro": "el registro",
		"casa_comercio": "la casa de comercio",
		"casa_estudio": "la casa de estudio",
		"archivo_real": "el archivo real",
		"casa_elian": "su casa",
		"casa_bruna": "su casa",
		"casa_darven": "su casa",
		"casa_saira": "su casa",
		"casa_narel": "su casa",
		"castillo": "el castillo"
	}
	return str(destinos.get(ubicacion, "su próximo destino"))


func _obtener_texto_rutina_personaje(
	nombre: String,
	rutina_clave: String,
	actividad: String,
	destino: String,
	en_transito: bool,
	dentro_edificio: bool,
	amable: bool
) -> String:
	# Los diálogos de tránsito aprobados conservan la voz individual de cada NPC.
	if en_transito:
		match nombre:
			"elian":
				return ("¡Qué bueno verte! Llevo el pan todavía en la cabeza. Primero tengo que llegar a %s; búscame allí y te guardo un momento para conversar." if amable else "Disculpa, no puedo detenerme ahora. Tengo que llegar a %s antes de que se enfríe el trabajo. Allí podremos hablar.") % destino
			"bruna":
				return ("¡Eh, me alegra encontrarte! Voy a %s a terminar un encargo. Cuando deje las herramientas, hablamos tranquilamente." if amable else "Ahora no puedo parar; tengo un encargo entre manos. Voy a %s. Si necesitas algo, espérame allí.") % destino
			"darven":
				return ("Me alegra verte. Estoy siguiendo mi ronda hacia %s; cuando termine de asegurar la zona, tendrás toda mi atención." if amable else "En servicio. No puedo abandonar mi recorrido: me dirijo a %s. Si es importante, búscame allí.") % destino
			"saira":
				return ("¡Qué casualidad verte! Voy hacia %s, tengo unas cuentas que revisar. Si pasas por allí, podemos ponernos al día." if amable else "Ahora mismo voy con prisa; debo atender un asunto en %s. Allí estaré disponible cuando termine.") % destino
			"narel":
				return ("¡Ah, hola! Justo iba pensando en algo que debo consultar en %s. Acompáñame con la conversación allí; ahora temo perder el hilo." if amable else "Perdona, estoy intentando no olvidar una idea. Debo llegar a %s y dejar mis notas en orden. Hablemos después.") % destino
			"abel":
				return ("Me alegra que hayas venido. Me dirijo a %s; allí podremos hablar sin descuidar mis obligaciones." if amable else "Ahora debo continuar hacia %s. Cuando haya atendido mis responsabilidades, podremos conversar.") % destino
			"liam":
				return ("¡Hola! Voy camino a %s. Si me encuentras allí, podremos conversar un poco más." if amable else "Disculpa, tengo que llegar a %s. Búscame allí cuando termine lo que debo hacer.") % destino
			_:
				return ("Me alegra verte, pero tengo que llegar a %s. Allí podremos conversar." if amable else "Ahora debo continuar hacia %s. Puedes encontrarme allí cuando termine.") % destino

	var es_dia_libre := rutina_clave.begins_with("dia_libre")
	var ubicacion := str(_fuente.get_meta("rutina_ubicacion", "")).strip_edges().to_lower() if is_instance_valid(_fuente) else ""
	var ubicaciones_hogar: Array[String] = ["casa_elian", "casa_bruna", "casa_darven", "casa_saira", "casa_narel", "castillo"]
	var esta_en_hogar := ubicaciones_hogar.has(ubicacion)

	# Los días libres tienen pequeñas actividades propias, incluso cuando el NPC se queda en casa.
	if es_dia_libre:
		if esta_en_hogar:
			match nombre:
				"elian":
					return "Hoy dejé el horno apagado. Estoy en casa disfrutando de una mañana sin pedidos." if not amable else "Hoy no hay hornadas pendientes. Quédate un rato; me alegra compartir contigo un día tranquilo."
				"bruna":
					return "Hoy no hay encargos ni herramientas que revisar. Me quedaré en casa un rato." if not amable else "Me tomé el día libre y estoy descansando en casa. Podemos conversar sin prisas."
				"darven":
					return "Hoy no estoy de guardia. Me quedaré cerca de casa y descansaré antes del siguiente turno." if not amable else "Incluso un guardia necesita un día tranquilo. Me alegra que hayas venido a conversar."
				"saira":
					return "Hoy mantengo el comercio cerrado. Estoy aprovechando para revisar mis asuntos personales." if not amable else "Hoy no hay cuentas del comercio que atender. Quédate un momento, podemos hablar con calma."
				"narel":
					return "Intento no convertir mi día libre en otra jornada de estudio. Por ahora me quedaré en casa." if not amable else "He dejado los documentos a un lado por hoy. Me vendrá bien conversar de algo distinto."
				"abel":
					return "Hoy tengo menos obligaciones y permaneceré en el castillo." if not amable else "He reservado parte del día para descansar aquí. Será agradable conversar sin reuniones pendientes."
				"liam":
					return "Hoy no tengo que salir del castillo. Aprovecharé para descansar." if not amable else "Estoy disfrutando de un día tranquilo en el castillo. Me alegra que hayas pasado."
				_:
					return "Hoy estoy descansando en casa. No tengo prisa por volver a mis obligaciones."
		match nombre:
			"elian":
				return "Hoy no hay hornadas pendientes. Salí a tomar aire y ver qué se cuenta por la plaza." if not amable else "Hoy dejé descansar el horno. Me alegra encontrarte fuera de la rutina; ¿cómo te ha ido?"
			"bruna":
				return "Hoy no tengo encargos. Estoy aprovechando para despejarme y mirar el pueblo con calma." if not amable else "Me tomé el día para mí. Es bueno salir de la forja de vez en cuando; podemos caminar y conversar."
			"darven":
				return "Hoy no estoy de guardia. Aun así, me gusta mantenerme cerca de los accesos." if not amable else "Estoy libre por hoy. Cuesta dejar la costumbre de observarlo todo, pero puedo dedicarte un momento."
			"saira":
				return "Hoy no abrí el comercio. Estoy visitando algunos puestos y viendo qué novedades llegaron." if not amable else "Me concedí un día sin mostrador ni cuentas. Ven, cuéntame qué has descubierto últimamente."
			"narel":
				return "Intento que un día libre no termine convertido en otra jornada de investigación." if not amable else "Hoy quería despejar la cabeza, aunque ya encontré algo interesante que observar. ¿Me acompañas?"
			"abel":
				return "Hoy mis obligaciones son menores, pero sigo pendiente del castillo." if not amable else "Tengo algo más de tiempo libre hoy. Será agradable conversar sin atender una reunión."
			"liam":
				return "Aproveché el día libre para salir un rato del castillo." if not amable else "Hoy no tengo tantas obligaciones. ¿Te apetece dar una vuelta por la plaza?"
			_:
				return "Hoy llevo un ritmo más tranquilo. No tengo prisa por volver a mis obligaciones." if not amable else "Hoy estoy libre y puedo conversar un rato contigo."

	# En días laborables, la casa también tiene conversaciones propias.
	if esta_en_hogar:
		match nombre:
			"elian":
				return "Ya terminé con el horno por hoy. En casa puedo dejar de mirar el reloj y pensar en la próxima tanda." if not amable else "Pasa si quieres. Ya no tengo que vigilar el horno; me viene bien descansar y conversar un rato."
			"bruna":
				return "Por fin puedo dejar las herramientas. Mañana revisaré el trabajo con la cabeza más despejada." if not amable else "Estoy guardando mis cosas. Siéntate un momento; aquí no hace falta hablar por encima del ruido de la forja."
			"darven":
				return "La guardia también necesita descanso. Ya entregué el turno y no estoy de servicio ahora." if not amable else "El turno terminó. Me alegra tener un rato tranquilo; podemos hablar sin que esté pendiente de cada movimiento."
			"saira":
				return "Estoy haciendo cuentas y ordenando algunas notas. No todo el comercio ocurre detrás de un mostrador." if not amable else "Justo estaba cerrando mis cuentas. Quédate un momento; siempre es agradable conversar sin tener clientes esperando."
			"narel":
				return "Estoy intentando ordenar mis apuntes antes de olvidar por qué los escribí." if not amable else "He apartado los documentos por un rato. Si quieres, podemos conversar; quizá una pregunta tuya me ayude a ver algo de otra manera."
			"abel":
				return "Mis responsabilidades en el castillo no terminan cuando cae la noche. Ahora debo atender asuntos internos." if not amable else "He reservado este momento para los asuntos del castillo. Aun así, podemos conversar un poco."
			"liam":
				return "Estoy descansando en el castillo. Si necesitas algo, procura no interrumpir los asuntos de los demás." if not amable else "Aquí estoy tomando un respiro. Me alegra que hayas venido; podemos hablar un rato."
			_:
				return "Estoy en casa por ahora. Cuando termine lo que tengo entre manos, podremos conversar." if not amable else "Estoy descansando un momento en casa. Quédate si quieres, podemos conversar."

	# Diálogos de trabajo: cada actividad tiene una respuesta propia, no sólo un cambio de destino.
	match nombre:
		"elian":
			match actividad:
				"hornear":
					return "Estoy preparando la masa para la primera tanda. Si el horno mantiene bien el calor, tendremos pan listo a tiempo." if not amable else "Llegaste justo cuando empieza lo interesante. Mira cómo cambia la masa antes de entrar al horno."
				"atender":
					return "Estoy atendiendo los pedidos. Si buscas pan, dime qué necesitas y revisaré lo que queda." if not amable else "¡Qué bueno verte! Estoy atendiendo, pero puedo reservarte algo de la tanda que acaba de salir."
				"limpiar":
					return "Estoy limpiando la panadería antes de cerrar. No quiero dejar restos para la mañana." if not amable else "Ya casi termino de ordenar. Cuando acabe, te cuento cómo salió la última hornada."
		"bruna":
			match actividad:
				"forjar":
					return "Estoy trabajando el metal. Necesito mantener el ritmo y la temperatura; hablaré contigo cuando termine esta pieza." if not amable else "Observa el color del metal. No golpeo hasta que está en el punto correcto; es cuestión de paciencia."
				"revisar_herramientas":
					return "Estoy comprobando las herramientas. Una pieza desgastada puede arruinar un trabajo entero." if not amable else "Estoy revisando mis herramientas. Si quieres, puedo enseñarte qué señales busco antes de volver a usarlas."
		"darven":
			match actividad:
				"vigilar_acceso":
					return "Estoy controlando el acceso al registro. Si vienes por un trámite, espera a que termine la inspección." if not amable else "Estoy revisando quién entra y sale. Ya conozco tu rostro, pero debo mantener el procedimiento."
				"vigilar":
					return "Este puesto requiere atención constante. No puedo apartarme mientras estoy de guardia." if not amable else "Todo está tranquilo por ahora. Aun así, no debo descuidar el puesto; podemos hablar mientras mantengo la vigilancia."
				"patrullar":
					return "Estoy recorriendo el camino. Si detecto algo fuera de lugar, debo informar al cuartel." if not amable else "La ronda está tranquila. Puedes acompañarme un tramo, pero mantente atento a los alrededores."
				"recorrer_alrededores":
					return "Aunque hoy esté libre, prefiero conocer bien los alrededores." if not amable else "Estoy dando una vuelta por costumbre. Si quieres, caminamos juntos un trecho."
		"saira":
			match actividad:
				"comerciar":
					return "Estoy atendiendo el comercio. Si buscas algo, dime qué es y revisaré las existencias." if not amable else "¡Llegaste! Estoy atendiendo, pero puedo mostrarte primero algunas mercancías que acaban de llegar."
				"ordenar_mercancia":
					return "Estoy ordenando el inventario. Si no registro bien cada pieza, luego no sabré qué puedo ofrecer." if not amable else "Estoy poniendo en orden las mercancías. Siempre aparece algo interesante entre los cargamentos."
				"visitar_comerciantes":
					return "Estoy visitando a otros comerciantes para conocer sus precios y novedades." if not amable else "Acompáñame si quieres. Siempre se aprende algo escuchando cómo negocian los demás."
		"narel":
			match actividad:
				"investigar_oris":
					return "Estoy comparando observaciones sobre Oris. Necesito terminar esta anotación antes de cambiar de tema." if not amable else "Encontré una diferencia interesante en estas observaciones de Oris. Quiero enseñártela cuando termine de comprobarla."
				"consultar_archivos":
					return "Estoy consultando registros antiguos. Prefiero verificar las fuentes antes de aceptar una conclusión." if not amable else "He encontrado una referencia que podría aclarar una de mis observaciones. ¿Quieres ayudarme a revisarla?"
				"registrar_observaciones":
					return "Estoy pasando mis observaciones al registro. Si no las anoto ahora, los detalles se perderán." if not amable else "Estoy dejando constancia de lo que observé hoy. Después podemos revisar juntos qué significan los resultados."
				"leer":
					return "Estoy leyendo un documento que puede servirme para la investigación." if not amable else "Este texto tiene una referencia curiosa. Cuando termine este apartado, me gustaría comentártela."
				"visitar_estudio":
					return "Estoy pasando por la casa de estudio para consultar unas notas." if not amable else "Voy a revisar unas notas en la casa de estudio. Si te interesa, puedes acompañarme."
		"abel":
			match actividad:
				"recorrer_torres":
					return "Estoy recorriendo Torres para conocer de primera mano cómo marcha el reino." if not amable else "Me gusta escuchar a quienes viven aquí. Si tienes algo que contarme, este recorrido es un buen momento."
				"dormir":
					return "El castillo está en calma. Debo recuperar fuerzas para las responsabilidades de mañana." if not amable else "Por hoy he terminado. Podemos conversar un momento antes de que descanse."
		"liam":
			match actividad:
				"recorrer_torres":
					return "Estoy dando una vuelta por Torres. No quiero pasar todo el día dentro del castillo." if not amable else "Salí a recorrer el pueblo. Si quieres, podemos ver qué está pasando en la plaza."
				"dormir":
					return "Ya es hora de descansar. Mañana habrá más que hacer." if not amable else "Voy a descansar. Me alegra haberte visto antes de terminar el día."

	# Respaldo contextual para actividades nuevas que lleguen desde datos sin
	# necesidad de cambiar el motor de diálogo cada vez.
	var verbo := actividad.replace("_", " ").strip_edges()
	if verbo.is_empty():
		verbo = "atender mis asuntos"
	if dentro_edificio:
		return ("Estoy ocupado con %s aquí. Cuando termine, podremos conversar." if not amable else "Estoy con %s, pero me alegra que hayas venido. Podemos hablar mientras continúo.") % verbo
	return ("Estoy en %s y tengo que ocuparme de %s. Hablemos cuando termine." if not amable else "Estoy en %s con %s. Quédate un momento si quieres; podemos conversar.") % [destino, verbo]


func _cumple_requisito_contextual(requisito: Dictionary, contexto: Dictionary) -> bool:
	var tiene_condicion := false

	if requisito.has("estaciones"):
		tiene_condicion = true
		var estaciones_variant: Variant = requisito.get("estaciones", [])
		var estaciones: Array = estaciones_variant if estaciones_variant is Array else [estaciones_variant]
		if not estaciones.has(str(contexto.get("estacion_id", ""))):
			return false

	if requisito.has("dias_de_estacion"):
		tiene_condicion = true
		var dias_variant: Variant = requisito.get("dias_de_estacion", [])
		var dias: Array = dias_variant if dias_variant is Array else [dias_variant]
		if not dias.has(int(contexto.get("dia_de_estacion", 0))):
			return false

	if requisito.has("dia_de_estacion_min"):
		tiene_condicion = true
		if int(contexto.get("dia_de_estacion", 0)) < int(requisito.get("dia_de_estacion_min", 0)):
			return false

	if requisito.has("dia_de_estacion_max"):
		tiene_condicion = true
		if int(contexto.get("dia_de_estacion", 0)) > int(requisito.get("dia_de_estacion_max", 0)):
			return false

	if requisito.has("dias_del_anio"):
		tiene_condicion = true
		var dias_anio_variant: Variant = requisito.get("dias_del_anio", [])
		var dias_anio: Array = dias_anio_variant if dias_anio_variant is Array else [dias_anio_variant]
		if not dias_anio.has(int(contexto.get("dia", 0))):
			return false

	if requisito.has("periodos"):
		tiene_condicion = true
		var periodos_variant: Variant = requisito.get("periodos", [])
		var periodos: Array = periodos_variant if periodos_variant is Array else [periodos_variant]
		if not periodos.has(str(contexto.get("periodo", ""))):
			return false

	return tiene_condicion


func _cumple_requisito_social_contextual(requisito: Dictionary, relacion: Dictionary) -> bool:
	for eje in ["amistad", "confianza", "respeto", "afecto"]:
		var valor := float(relacion.get(eje, 0.0))
		if requisito.has(eje + "_min") and valor < float(requisito.get(eje + "_min")):
			return false
		if requisito.has(eje + "_max") and valor > float(requisito.get(eje + "_max")):
			return false
	return true


func _actualizar_boton_accion() -> void:
	if action_button == null:
		return

	var texto_terminado := _indice_caracter >= _texto_completo.length()
	var es_ultima_linea := _indice_linea >= _lineas.size() - 1
	var mostrar_respuestas := not _respuestas.is_empty() and es_ultima_linea and texto_terminado
	if _respuestas_container != null:
		_respuestas_container.visible = mostrar_respuestas
	if mostrar_respuestas:
		if _respuestas_container.get_child_count() == 0:
			_crear_botones_respuesta()
		action_button.visible = false
		if cancel_button != null:
			cancel_button.visible = false
		return
	if _respuestas_container != null:
		_respuestas_container.visible = false

	if _acciones.is_empty():
		action_button.visible = false
		if cancel_button != null:
			cancel_button.visible = false
		return

	# La elección se presenta al terminar la conversación, no entre líneas.
	if _indice_linea < _lineas.size() - 1:
		action_button.visible = false
		if cancel_button != null:
			cancel_button.visible = false
		return

	var texto_completo := _texto_completo.length()
	if _indice_caracter < texto_completo:
		action_button.visible = false
		if cancel_button != null:
			cancel_button.visible = false
		return

	var accion: Dictionary = _acciones[0]
	action_button.text = str(accion.get("texto", "Aceptar"))
	action_button.visible = true
	if cancel_button != null:
		cancel_button.visible = true


func _ejecutar_accion_dialogo() -> void:
	if _acciones.is_empty():
		return

	var accion: Dictionary = _acciones[0]
	var tipo := str(accion.get("tipo", "")).strip_edges().to_lower()

	match tipo:
		"evento_social":
			if not is_instance_valid(_fuente) or relationship_system == null:
				return
			var personaje_id := _fuente.get_personaje_game_id().strip_edges()
			var evento := str(accion.get("evento", "")).strip_edges()
			var evento_id := str(accion.get("evento_id", "")).strip_edges()
			var contexto_variant: Variant = accion.get("contexto", {})
			var contexto: Dictionary = contexto_variant.duplicate(true) if contexto_variant is Dictionary else {}
			var resultado: Dictionary = relationship_system.registrar_evento_social(personaje_id, evento, evento_id, contexto)
			if resultado.is_empty():
				return
			_acciones.clear()
			action_button.visible = false
			if cancel_button != null:
				cancel_button.visible = false
			Events.notification_pushed.emit(_obtener_mensaje_reaccion_social(evento, _fuente.get_nombre()))
			return

		"aceptar_mision":
			var clave := str(accion.get("mision_clave", "")).strip_edges()
			if clave.is_empty():
				return

			var mission_manager_local: MissionManagerService = mission_manager
			if mission_manager_local != null and mission_manager_local.aceptar_mision(clave):
				_acciones.clear()
				action_button.visible = false
				Events.notification_pushed.emit(
					"Misión aceptada: "
					+ str(mission_manager_local.buscar_mision_por_clave(clave).get("nombre", clave))
				)
				return

		"seguir_jugador":
			if is_instance_valid(_fuente):
				if _fuente.iniciar_seguimiento_jugador(player):
					_acciones.clear()
					action_button.visible = false
					return


func _crear_respuestas_rutina() -> Array[Dictionary]:
	var respuestas: Array[Dictionary] = [
		{
			"texto": "Preguntar cómo va su trabajo",
			"jugador": "¿Cómo va todo con lo que estás haciendo?",
			"respuesta": _obtener_reaccion_pregunta_rutina(),
			"evento": "interesarse"
		},
		{
			"texto": "Reconocer su esfuerzo",
			"jugador": "Se nota todo el esfuerzo que pones en esto. Gracias por lo que haces.",
			"respuesta": _obtener_reaccion_apoyo_rutina(),
			"evento": "apoyar"
		},
		{
			"texto": "Compartir algo que aprendí",
			"jugador": "He aprendido algo que creo que podría interesarte.",
			"respuesta": _obtener_reaccion_conocimiento_rutina(),
			"evento": "compartir_conocimiento"
		},
		{
			"texto": "Despedirme con amabilidad",
			"jugador": "No quiero interrumpirte más. Nos vemos luego.",
			"respuesta": _obtener_reaccion_despedida_rutina(),
			"evento": "despedida_amable"
		}
	]
	return respuestas


func _obtener_reaccion_pregunta_rutina() -> String:
	var nombre := _fuente.get_nombre_visual().strip_edges() if is_instance_valid(_fuente) else ""
	match nombre.to_lower():
		"elian":
			return "Va bien. Cada tanda tiene sus pequeños problemas, pero ya conozco el ritmo del horno."
		"bruna":
			return "El trabajo avanza. Lo importante es no apresurar una pieza y tener que empezar de nuevo."
		"darven":
			return "Todo está en orden por ahora. Aun así, prefiero comprobarlo personalmente antes de darlo por hecho."
		"saira":
			return "Bastante bien. Siempre hay algo que revisar: precios, encargos o mercancía que todavía no llega."
		"narel":
			return "He avanzado, aunque todavía necesito contrastar algunas observaciones antes de sacar conclusiones."
		"abel":
			return "El reino sigue adelante. Mi tarea consiste en escuchar sus problemas antes de que se vuelvan más grandes."
		"liam":
			return "Todo tranquilo por ahora. A veces viene bien salir y ver qué ocurre fuera del castillo."
	return "Voy avanzando. Gracias por preguntar; no todos se detienen a hacerlo."


func _obtener_reaccion_apoyo_rutina() -> String:
	var nombre := _fuente.get_nombre_visual().strip_edges() if is_instance_valid(_fuente) else ""
	match nombre.to_lower():
		"elian":
			return "Gracias. A veces sólo se ve el pan terminado y no todo el trabajo que hay detrás."
		"bruna":
			return "Lo aprecio. Una pieza bien hecha lleva tiempo, incluso cuando nadie nota los detalles."
		"darven":
			return "Gracias. La guardia suele pasar desapercibida cuando todo marcha bien, y eso también es una buena señal."
		"saira":
			return "Me alegra que lo notes. Mantener un comercio en marcha requiere más cuentas de las que parece."
		"narel":
			return "Gracias. Investigar puede ser solitario; se agradece que alguien valore el esfuerzo."
		"abel":
			return "Te agradezco que lo digas. Gobernar también consiste en atender tareas que casi nadie llega a ver."
		"liam":
			return "Gracias. A veces parece que sólo estoy dando vueltas, pero también intento ayudar a mi manera."
	return "Gracias por decirlo. Significa más de lo que imaginas."


func _obtener_reaccion_conocimiento_rutina() -> String:
	var nombre := _fuente.get_nombre_visual().strip_edges() if is_instance_valid(_fuente) else ""
	match nombre.to_lower():
		"elian":
			return "¿Ah, sí? Cuéntame. Siempre se puede aprender algo nuevo, incluso lejos del horno."
		"bruna":
			return "Eso podría servirme. ¿Tiene que ver con materiales, herramientas o algo completamente distinto?"
		"darven":
			return "Te escucho. Cualquier conocimiento que ayude a prevenir un problema merece atención."
		"saira":
			return "Eso suena interesante. La información también tiene valor; cuéntame qué descubriste."
		"narel":
			return "¡Eso sí que me interesa! ¿Dónde lo aprendiste? Tal vez podamos comprobarlo juntos."
		"abel":
			return "Me interesa conocerlo. Las decisiones del reino mejoran cuando escuchamos nuevas perspectivas."
		"liam":
			return "¿En serio? Me gusta escuchar cosas nuevas. Cuéntame un poco más."
	return "Me interesa lo que dices. Cuéntame más cuando tengamos un momento."


func _obtener_reaccion_despedida_rutina() -> String:
	var nombre := _fuente.get_nombre_visual().strip_edges() if is_instance_valid(_fuente) else ""
	match nombre.to_lower():
		"elian":
			return "No interrumpes. Me alegra que hayas pasado; cuando vuelva a tener un momento, seguimos hablando."
		"bruna":
			return "Está bien. Tengo que terminar esto, pero podemos continuar la conversación otro día."
		"darven":
			return "De acuerdo. Mantente a salvo y avísame si ocurre algo que deba saber."
		"saira":
			return "Hasta luego. Si vuelves a pasar, quizá tenga alguna novedad que contarte."
		"narel":
			return "Gracias por entenderlo. No olvides lo que querías contarme; me interesa escucharlo después."
		"abel":
			return "Hasta pronto. Agradezco que te hayas tomado el tiempo de conversar conmigo."
		"liam":
			return "¡Nos vemos! Espero que volvamos a encontrarnos pronto."
	return "Hasta luego. Me ha gustado conversar contigo."



func _abrir_selector_conversacion() -> void:
	if not _abierto or _selector_conversacion == null or not is_instance_valid(_fuente):
		return
	for hijo in _selector_conversacion_grid.get_children():
		_selector_conversacion_grid.remove_child(hijo)
		hijo.queue_free()
	var opciones := _crear_opciones_conversacion()
	for indice in range(opciones.size()):
		var opcion: Dictionary = opciones[indice]
		var boton := Button.new()
		boton.text = str(opcion.get("texto", "Conversar"))
		boton.custom_minimum_size = Vector2(0, 42)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.add_theme_font_size_override("font_size", 11)
		boton.pressed.connect(_seleccionar_tema_conversacion.bind(opcion))
		_selector_conversacion_grid.add_child(boton)
	_respuestas.clear()
	_limpiar_botones_respuesta()
	if _dialogue_content_row != null:
		_dialogue_content_row.visible = false
	_selector_conversacion.visible = true
	PIXEL_UI_THEME.apply(_selector_conversacion)


func _cerrar_selector_conversacion() -> void:
	if _selector_conversacion != null:
		_selector_conversacion.visible = false
	if _dialogue_content_row != null:
		_dialogue_content_row.visible = true


func _crear_opciones_conversacion() -> Array[Dictionary]:
	# Los temas narrativos proceden de dialogos_game. El fallback mantiene
	# compatibilidad con NPC que todavía no tienen temas propios en Supabase.
	if is_instance_valid(_fuente):
		var personaje_id := _fuente.get_personaje_game_id().strip_edges()
		var datos_dialogo := _fuente.get_dialogue_data()
		var temas_variant: Variant = datos_dialogo.get("temas_conversacion", [])
		if temas_variant is Array and not (temas_variant as Array).is_empty():
			var opciones_datos: Array[Dictionary] = []
			var relacion: Dictionary = relationship_system.obtener_relacion(personaje_id) if relationship_system != null else {}
			var recuerdos: Array = relationship_system.obtener_recuerdos(personaje_id) if relationship_system != null else []
			for tema_variant in temas_variant as Array:
				if not tema_variant is Dictionary:
					continue
				var tema := tema_variant as Dictionary
				if not _cumple_requisitos_tema_conversacion(tema, relacion, recuerdos):
					continue
				var clave_tema := str(tema.get("clave", "")).strip_edges()
				var respuesta := _obtener_respuesta_tema(tema, clave_tema, recuerdos, relacion)
				var texto_jugador := str(tema.get("jugador", "")).strip_edges()
				var titulo := str(tema.get("texto", "")).strip_edges()
				if clave_tema.is_empty() or texto_jugador.is_empty() or respuesta.is_empty() or titulo.is_empty():
					continue
				opciones_datos.append({
					"clave": clave_tema,
					"texto": titulo,
					"jugador": texto_jugador,
					"respuesta": respuesta,
					"evento": str(tema.get("evento", "interesarse")),
					"importancia": _obtener_importancia_tema(tema)
				})
			return _completar_opciones_conversacion(opciones_datos, relacion)

	var nombre := _fuente.get_nombre_visual().strip_edges().to_lower()
	var actividad := str(_fuente.datos.get("actividad_actual", "")).replace("_", " ").strip_edges()
	var planes := "Hoy quiero cumplir con mis responsabilidades y reservar algo de tiempo para descansar."
	var cumplido := "Gracias. Es agradable que alguien se fije en el esfuerzo que pongo."
	var aficiones := "Cuando tengo tiempo libre, intento descansar y hacer algo distinto a mis obligaciones."
	var preocupacion := "Hay asuntos que prefiero ordenar con calma. Gracias por interesarte."
	var consejo := "Mi consejo es que no intentes resolverlo todo de una vez. Da un paso y observa qué cambia."
	var opinion_torres := "Torres es un lugar con personas distintas. Si uno presta atención, siempre descubre algo nuevo."
	match nombre:
		"elian":
			planes = "Quiero terminar la hornada y atender la panadería. Después espero tener un rato tranquilo."
			cumplido = "¡Gracias! A veces uno pasa tantas horas entre harina y hornos que olvida que su trabajo también alegra a los demás."
			aficiones = "Me gusta caminar y probar recetas nuevas. No todo tiene que terminar convertido en pan para vender."
			preocupacion = "A veces me preocupa no llegar a todos los pedidos sin descuidar la calidad."
			consejo = "No apures una buena receta. Es mejor preparar algo bien y a tiempo que entregar cualquier cosa por terminar antes."
			opinion_torres = "Torres tiene buen movimiento. La gente necesita un lugar donde reunirse y compartir algo recién hecho."
		"bruna":
			planes = "Tengo trabajo pendiente con las herramientas y las piezas. Después quiero revisar mis propios proyectos."
			cumplido = "Lo aprecio. No busco reconocimiento, pero se agradece que notes el cuidado que pongo en cada pieza."
			aficiones = "Me gusta reparar cosas por gusto, aunque intento que mis días libres no se conviertan en otra jornada de trabajo."
			preocupacion = "Me preocupa que una pieza falle cuando alguien dependa de ella. Por eso reviso cada detalle."
			consejo = "Antes de dar algo por terminado, comprueba los detalles. La paciencia evita muchos problemas."
			opinion_torres = "Torres necesita buenos caminos, edificios firmes y gente dispuesta a cuidar lo que construye."
		"darven":
			planes = "Hoy seguiré atento a la seguridad de Torres. Cuando acabe mi turno, revisaré los alrededores."
			cumplido = "Gracias. Cumplir con mi deber es lo esperado, aunque escuchar eso hace que la guardia pese menos."
			aficiones = "Disfruto los paseos tranquilos. Incluso fuera de servicio me cuesta dejar de observar los caminos."
			preocupacion = "Me preocupa pasar por alto una señal importante. La tranquilidad del pueblo depende de prestar atención."
			consejo = "Mantén la calma y observa antes de actuar. Una decisión apresurada puede poner a otros en peligro."
			opinion_torres = "Un pueblo seguro permite que todos trabajen y descansen sin miedo. Eso es lo que intento proteger."
		"saira":
			planes = "Tengo que atender el comercio y revisar algunas cuentas. También quiero enterarme de las novedades."
			cumplido = "¡Qué amable! En el comercio una escucha muchas opiniones; no todas son tan agradables como la tuya."
			aficiones = "Me gusta recorrer los puestos y descubrir mercancías curiosas sin tener que pensar en los precios."
			preocupacion = "Me preocupa que un mal cálculo afecte al comercio y a quienes dependen de él."
			consejo = "Escucha, compara y no te quedes con la primera impresión. Siempre conviene conocer varias versiones."
			opinion_torres = "Torres es un punto de encuentro. Las mercancías y las noticias que llegan dicen mucho de lo que ocurre fuera."
		"narel":
			planes = "Quiero avanzar con mis observaciones y consultar algunos documentos. Quizá encuentre algo interesante."
			cumplido = "Gracias. A veces me concentro tanto en investigar que olvido que alguien puede valorar el esfuerzo."
			aficiones = "Leo por placer, aunque a veces termino investigando algo sin darme cuenta."
			preocupacion = "Me preocupa confundir una hipótesis convincente con una conclusión verdadera."
			consejo = "Distingue lo que sabes de lo que supones. Una buena pregunta puede valer más que una respuesta apresurada."
			opinion_torres = "Torres reúne oficios, conocimientos y vidas distintas. Su mayor fortaleza está en sus habitantes."
		"abel":
			planes = "Hoy debo atender varios asuntos del reino. Espero escuchar a los habitantes y dejar un momento para descansar."
			cumplido = "Te agradezco el comentario. Las responsabilidades no suelen venir acompañadas de elogios."
			aficiones = "Aprecio los momentos tranquilos, conversar con los habitantes y conocer el reino sin reuniones."
			preocupacion = "Me preocupa tomar decisiones sin escuchar a quienes vivirán con sus consecuencias."
			consejo = "Antes de decidir, escucha a quienes se verán afectados. La responsabilidad empieza por comprenderlos."
			opinion_torres = "Torres es importante por su gente. Quiero que sea un lugar donde todos puedan construir una vida tranquila."
		"liam":
			planes = "Quiero terminar mis obligaciones y salir un rato del castillo. Siempre ocurre algo interesante en Torres."
			cumplido = "¡Gracias! No sabía que te habías fijado. Me has alegrado el día."
			aficiones = "Me gusta salir del castillo, caminar por la plaza y escuchar las historias de la gente."
			preocupacion = "A veces siento que todavía tengo mucho que aprender. Quiero encontrar una forma de ayudar."
			consejo = "No esperes a saberlo todo para intentar algo bueno. Aprende de cada paso y no tengas miedo de preguntar."
			opinion_torres = "Me gusta que en Torres siempre haya alguien haciendo algo. A veces sólo hace falta salir y conocer mejor el lugar."

	if not actividad.is_empty() and not planes.to_lower().contains(actividad.to_lower()):
		planes += " Ahora mismo estoy con " + actividad + "."
	var opciones_generales: Array[Dictionary] = [
		{"clave": "planes_hoy", "texto": "Preguntar por sus planes de hoy", "jugador": "¿Qué planes tienes para hoy?", "respuesta": planes, "evento": "interesarse", "importancia": 1.0},
		{"clave": "cumplido", "texto": "Dar un cumplido", "jugador": "Quería decirte que haces un buen trabajo. Se nota el esfuerzo que pones.", "respuesta": cumplido, "evento": "apoyar", "importancia": 1.0},
		{"clave": "aficiones", "texto": "Preguntar por sus aficiones", "jugador": "¿Qué te gusta hacer cuando tienes tiempo libre?", "respuesta": aficiones, "evento": "interesarse", "importancia": 1.0},
		{"clave": "preocupaciones", "texto": "Preguntar qué le preocupa", "jugador": "¿Hay algo que te preocupe últimamente?", "respuesta": preocupacion, "evento": "interesarse", "importancia": 1.5},
		{"clave": "consejo", "texto": "Pedirle un consejo", "jugador": "¿Qué consejo me darías?", "respuesta": consejo, "evento": "compartir_conocimiento", "importancia": 1.0},
		{"clave": "opinion_torres", "texto": "Hablar sobre Torres", "jugador": "¿Qué opinas de vivir en Torres?", "respuesta": opinion_torres, "evento": "interesarse", "importancia": 1.0}
	]
	var estado := "Supongo que hoy estoy bien. Ha sido un día bastante normal, aunque siempre hay algo que pensar."
	match nombre:
		"elian":
			estado = "Estoy bien, gracias. Ha sido un día tranquilo y eso me permite llevar el trabajo sin apuros."
		"bruna":
			estado = "Estoy bien. Algo cansada, quizá, pero nada que no se solucione terminando el trabajo pendiente."
		"darven":
			estado = "Me encuentro bien. Mientras todo siga tranquilo y no haya incidentes, puedo decir que es un buen día."
		"saira":
			estado = "Bastante bien. Un poco ocupada, pero siempre aparece algo interesante que anima el día."
		"narel":
			estado = "Diría que bien. He tenido algunas ideas dando vueltas y todavía estoy ordenándolas."
	opciones_generales.append({
		"clave": "estado_animo",
		"texto": "Preguntar cómo se siente",
		"jugador": "¿Cómo te has sentido últimamente?",
		"respuesta": estado,
		"evento": "interesarse",
		"importancia": 2.0
	})
	return _completar_opciones_conversacion(opciones_generales, relationship_system.obtener_relacion(_fuente.get_personaje_game_id()) if relationship_system != null else {})


func _completar_opciones_conversacion(opciones: Array[Dictionary], relacion: Dictionary) -> Array[Dictionary]:
	var candidatas := opciones.duplicate(true)
	var elegidas: Array[Dictionary] = []
	var usadas: Array[String] = []
	var actividad := str(_fuente.datos.get("actividad_actual", "")).replace("_", " ").strip_edges().to_lower() if is_instance_valid(_fuente) else ""
	var nombre := _fuente.get_nombre_visual().strip_edges().to_lower() if is_instance_valid(_fuente) else ""
	var confianza := float(relacion.get("confianza", 0.0))
	var amistad := float(relacion.get("amistad", 0.0))
	var afecto := float(relacion.get("afecto", 0.0))
	var respeto := float(relacion.get("respeto", 0.0))

	var respuesta_estado := "He estado bien, aunque algunos días se hacen más largos que otros."
	var respuesta_consejo := "Te diría que observes bien la situación antes de decidir. A veces ayuda escuchar otra perspectiva."
	var respuesta_cumplido := "Gracias. Es agradable que alguien se haya fijado en el esfuerzo que pongo."
	var respuesta_planes := "Hoy quiero cumplir con mis responsabilidades y reservar algo de tiempo para descansar."
	var respuesta_aficiones := "Cuando tengo tiempo libre, intento descansar y hacer algo distinto a mis obligaciones."
	match nombre:
		"elian":
			respuesta_estado = "Estoy bien. A veces termino cansado, pero me gusta tener una rutina y saber que mi trabajo sirve para alguien."
			respuesta_consejo = "No te exijas terminar todo hoy. Haz las cosas con calma y deja un poco de tiempo para descansar."
			respuesta_cumplido = "Gracias. A veces uno sólo ve el pan terminado y no todo el trabajo que hay detrás. Me alegra que lo valores."
			respuesta_planes = "Quiero terminar la hornada y atender la panadería. Después espero tener un rato tranquilo."
			respuesta_aficiones = "Me gusta caminar y probar recetas nuevas. No todo tiene que terminar convertido en pan para vender."
		"bruna":
			respuesta_estado = "Estoy bien. Si algo me preocupa, prefiero ocuparme de ello en vez de darle vueltas."
			respuesta_consejo = "Asegúrate de entender el problema antes de empezar a arreglarlo. Trabajar dos veces por falta de atención es perder el tiempo."
			respuesta_cumplido = "Lo aprecio. No busco reconocimiento, pero se agradece que notes el cuidado que pongo en cada pieza."
			respuesta_planes = "Tengo trabajo pendiente con las herramientas y las piezas. Después quiero revisar mis propios proyectos."
			respuesta_aficiones = "Me gusta reparar cosas por gusto, aunque intento que mis días libres no se conviertan en otra jornada de trabajo."
		"darven":
			respuesta_estado = "Estoy bien, gracias. Ha sido un día tranquilo, y espero que siga así."
			respuesta_consejo = "No tomes una decisión con información incompleta. Comprueba lo importante y piensa quién podría verse afectado."
			respuesta_cumplido = "Gracias. Cumplir con mi deber es lo esperado, aunque escuchar eso hace que la guardia pese menos."
			respuesta_planes = "Hoy seguiré atento a la seguridad de Torres. Cuando acabe mi turno, revisaré los alrededores."
			respuesta_aficiones = "Disfruto los paseos tranquilos. Incluso fuera de servicio me cuesta dejar de observar los caminos."
		"saira":
			respuesta_estado = "Bastante bien. Hay días agotadores, pero siempre aparece una conversación o una noticia que los vuelve interesantes."
			respuesta_consejo = "Pregunta, compara y escucha más de una versión. La primera historia rara vez cuenta todo."
			respuesta_cumplido = "¡Qué amable! En el comercio una escucha muchas opiniones; no todas son tan agradables como la tuya."
			respuesta_planes = "Tengo que atender el comercio y revisar algunas cuentas. También quiero enterarme de las novedades."
			respuesta_aficiones = "Me gusta recorrer los puestos y descubrir mercancías curiosas sin tener que pensar en los precios."
		"narel":
			respuesta_estado = "Me encuentro bien. He tenido bastante en qué pensar, aunque todavía estoy intentando ordenar algunas ideas."
			respuesta_consejo = "Separa los hechos de tus interpretaciones. Después podrás decidir qué pregunta merece investigarse."
			respuesta_cumplido = "Gracias. A veces me concentro tanto en investigar que olvido que alguien puede valorar el esfuerzo."
			respuesta_planes = "Quiero avanzar con mis observaciones y consultar algunos documentos. Quizá encuentre algo interesante."
			respuesta_aficiones = "Leo por placer, aunque a veces termino investigando algo sin darme cuenta."
	var opciones_generales: Array[Dictionary] = [
		{"clave": "planes_hoy", "texto": "Preguntar por sus planes de hoy", "jugador": "¿Qué planes tienes para hoy?", "respuesta": respuesta_planes, "evento": "interesarse", "importancia": 1.0},
		{"clave": "aficiones", "texto": "Preguntar por sus aficiones", "jugador": "¿Qué te gusta hacer cuando tienes tiempo libre?", "respuesta": respuesta_aficiones, "evento": "interesarse", "importancia": 1.0},
		{"clave": "estado_animo", "texto": "Preguntar cómo se siente", "jugador": "¿Cómo te has sentido últimamente?", "respuesta": respuesta_estado, "evento": "interesarse", "importancia": 2.0},
		{"clave": "consejo_personal", "texto": "Pedir un consejo", "jugador": "¿Qué consejo me darías?", "respuesta": respuesta_consejo, "evento": "compartir_conocimiento", "importancia": 1.0},
		{"clave": "cumplido_personal", "texto": "Dar un cumplido", "jugador": "Quería decirte que valoro lo que haces. Se nota el esfuerzo que pones.", "respuesta": respuesta_cumplido, "evento": "apoyar", "importancia": 1.0}
	]
	for general in opciones_generales:
		var ya_existe := false
		for candidata in candidatas:
			if str(candidata.get("clave", "")) == str(general.get("clave", "")):
				ya_existe = true
				break
		if not ya_existe:
			candidatas.append(general)

	while elegidas.size() < 3 and not candidatas.is_empty():
		var mejor_indice := -1
		var mejor_puntuacion := -INF
		for i in range(candidatas.size()):
			var opcion: Dictionary = candidatas[i]
			var clave := str(opcion.get("clave", "")).strip_edges()
			if clave.is_empty() or usadas.has(clave):
				continue
			var texto := (clave + " " + str(opcion.get("texto", "")) + " " + str(opcion.get("jugador", "")) + " " + str(opcion.get("respuesta", ""))).to_lower()
			var puntuacion := float(opcion.get("importancia", 1.0)) * 1.5
			if not actividad.is_empty():
				for palabra in actividad.split(" ", false):
					if palabra.length() >= 4 and texto.contains(palabra):
						puntuacion += 5.0
			if (confianza >= 20.0 or amistad >= 25.0 or afecto >= 15.0) and (texto.contains("preocup") or texto.contains("siente") or texto.contains("personal") or texto.contains("proyecto")):
				puntuacion += 2.0
			if respeto >= 20.0 and (texto.contains("consejo") or texto.contains("trabajo") or texto.contains("conocimiento")):
				puntuacion += 1.5
			if clave == "estado_animo" and confianza < 10.0:
				puntuacion -= 1.0
			if clave == "cumplido_personal" and (amistad >= 15.0 or afecto >= 10.0):
				puntuacion += 1.5
			if relationship_system != null and is_instance_valid(_fuente):
				puntuacion -= float(_contar_veces_tema(relationship_system.obtener_recuerdos(_fuente.get_personaje_game_id()), clave)) * 2.0
			var dia_rotacion := int(Time.get_unix_time_from_system() / 86400.0)
			if relationship_system != null:
				var tiempo_variant: Variant = relationship_system.obtener_contexto_temporal()
				if tiempo_variant is Dictionary and bool((tiempo_variant as Dictionary).get("calendario_cargado", false)):
					dia_rotacion = int((tiempo_variant as Dictionary).get("anio", 0)) * 1000 + int((tiempo_variant as Dictionary).get("dia", 1))
			puntuacion += float(posmod(hash(clave + str(dia_rotacion)), 100)) / 20.0
			if puntuacion > mejor_puntuacion:
				mejor_puntuacion = puntuacion
				mejor_indice = i
		if mejor_indice < 0:
			break
		var seleccionada: Dictionary = candidatas[mejor_indice]
		elegidas.append(seleccionada)
		usadas.append(str(seleccionada.get("clave", "")))

	elegidas.append({
		"clave": "despedirse",
		"texto": "Despedirse",
		"jugador": "Ha sido bueno hablar contigo. Nos vemos.",
		"respuesta": _obtener_reaccion_despedida_rutina(),
		"evento": "despedida_amable",
		"despedida": true,
		"importancia": 1.0
	})
	return elegidas



## Los temas bloqueados por confianza, amistad o conversaciones previas
## representan avances personales y deben poder reaparecer como recuerdos.
func _obtener_importancia_tema(tema: Dictionary) -> float:
	if tema.has("importancia"):
		return clampf(float(tema.get("importancia", 1.0)), 1.0, 5.0)
	var requisito_social_variant: Variant = tema.get("requisito_social", {})
	if requisito_social_variant is Dictionary and not (requisito_social_variant as Dictionary).is_empty():
		return 3.0
	if not str(tema.get("requiere_tema", "")).strip_edges().is_empty():
		return 3.0
	return 1.0


func _cumple_requisitos_tema_conversacion(tema: Dictionary, relacion: Dictionary, recuerdos: Array) -> bool:
	var requisito_social_variant: Variant = tema.get("requisito_social", {})
	if requisito_social_variant is Dictionary:
		var requisito_social := requisito_social_variant as Dictionary
		for eje in ["amistad", "confianza", "respeto", "afecto"]:
			var valor := float(relacion.get(eje, 0.0))
			if requisito_social.has(eje + "_min") and valor < float(requisito_social.get(eje + "_min", 0.0)):
				return false
			if requisito_social.has(eje + "_max") and valor > float(requisito_social.get(eje + "_max", 0.0)):
				return false
	var requiere_tema := str(tema.get("requiere_tema", "")).strip_edges()
	if not requiere_tema.is_empty() and not _recuerdos_contienen_tema(recuerdos, requiere_tema):
		return false
	return true


func _recuerdos_contienen_tema(recuerdos: Array, clave_tema: String) -> bool:
	return _contar_veces_tema(recuerdos, clave_tema) > 0


func _contar_veces_tema(recuerdos: Array, clave_tema: String) -> int:
	if clave_tema.is_empty():
		return 0
	var cantidad := 0
	for recuerdo_variant in recuerdos:
		if not recuerdo_variant is Dictionary:
			continue
		var recuerdo := recuerdo_variant as Dictionary
		if (
			str(recuerdo.get("tipo", "")) == "tema_conversacion"
			and str(recuerdo.get("clave", "")).strip_edges() == clave_tema
		):
			cantidad += 1
	return cantidad


## Las conversaciones repetidas pueden rotar entre varias respuestas.
## Se aceptan tanto respuestas_repetidas como una respuesta_repetida única
## para conservar compatibilidad con los temas ya guardados.
## Selecciona una respuesta según la relación actual y rota sus respuestas posteriores.
## Las variantes no alteran el desbloqueo del tema: sólo cambian la actitud con que
## el personaje responde una vez que el jugador ha llegado a esa conversación.
func _obtener_respuesta_tema(
	tema: Dictionary,
	clave_tema: String,
	recuerdos: Array,
	relacion: Dictionary = {}
) -> String:
	var veces_conversado := _contar_veces_tema(recuerdos, clave_tema)
	var respuesta_fuente: Dictionary = tema
	var variantes_variant: Variant = tema.get("variantes_actitud", [])
	var mejor_prioridad := -2147483648
	if variantes_variant is Array:
		for variante_variant in variantes_variant as Array:
			if not variante_variant is Dictionary:
				continue
			var variante := variante_variant as Dictionary
			var requisito_variant: Variant = variante.get("requisito_social", {})
			if not requisito_variant is Dictionary:
				continue
			var requisito := requisito_variant as Dictionary
			if requisito.is_empty() or not _cumple_requisito_social_contextual(requisito, relacion):
				continue
			var prioridad := int(variante.get("prioridad", 0))
			if prioridad > mejor_prioridad:
				mejor_prioridad = prioridad
				respuesta_fuente = variante

	var respuesta_inicial := str(
		respuesta_fuente.get("respuesta", tema.get("respuesta", ""))
	).strip_edges()
	if veces_conversado <= 0:
		return respuesta_inicial

	var repetidas_variant: Variant = respuesta_fuente.get(
		"respuestas_repetidas",
		respuesta_fuente.get(
			"respuesta_repetida",
			tema.get("respuestas_repetidas", tema.get("respuesta_repetida", []))
		)
	)
	if repetidas_variant is Array:
		var opciones_validas: Array[String] = []
		for respuesta_variant in repetidas_variant as Array:
			var texto := str(respuesta_variant).strip_edges()
			if not texto.is_empty():
				opciones_validas.append(texto)
		if not opciones_validas.is_empty():
			var indice := posmod(veces_conversado - 1, opciones_validas.size())
			return opciones_validas[indice]

	var repetida := str(repetidas_variant).strip_edges()
	return repetida if not repetida.is_empty() else respuesta_inicial


func _seleccionar_tema_conversacion(opcion: Dictionary) -> void:
	if not _abierto or not is_instance_valid(_fuente):
		return
	var jugador := str(opcion.get("jugador", "")).strip_edges()
	var respuesta := str(opcion.get("respuesta", "")).strip_edges()
	if jugador.is_empty() or respuesta.is_empty():
		return
	var personaje_id := _fuente.get_personaje_game_id().strip_edges()
	var clave_tema := str(opcion.get("clave", "")).strip_edges()
	var evento := str(opcion.get("evento", "interesarse")).strip_edges()
	if relationship_system != null and not personaje_id.is_empty():
		if not clave_tema.is_empty():
			relationship_system.registrar_recuerdo(personaje_id, {
				"tipo": "tema_conversacion",
				"clave": clave_tema,
				"titulo": str(opcion.get("texto", "")),
				"frase_jugador": jugador,
				"respuesta_npc": respuesta,
				"importancia": float(opcion.get("importancia", 1.0)),
				"momento": Time.get_datetime_string_from_system(true)
			})
		var contexto := {"origen": "tema_conversacion", "tema": str(opcion.get("texto", "")), "clave_tema": clave_tema}
		relationship_system.registrar_evento_social(personaje_id, evento, _crear_id_evento_respuesta(personaje_id, evento), contexto)
	_cerrar_selector_conversacion()
	_acciones.clear()
	_respuestas.clear()
	_limpiar_botones_respuesta()
	_lineas = [
		{"hablante": "Tú", "texto": jugador},
		{"hablante": _fuente.get_nombre_visual(), "texto": respuesta}
	]
	_indice_linea = 0
	_mostrar_linea_actual()
	_actualizar_boton_accion()


func _crear_botones_respuesta() -> void:
	if _respuestas_container == null:
		return
	for indice in range(_respuestas.size()):
		var opcion: Dictionary = _respuestas[indice]
		var boton := Button.new()
		boton.text = str(opcion.get("texto", "Responder"))
		boton.custom_minimum_size = Vector2(0, 34)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.add_theme_font_size_override("font_size", 11)
		boton.pressed.connect(_seleccionar_respuesta.bind(indice))
		_respuestas_container.add_child(boton)
	PIXEL_UI_THEME.apply(_respuestas_container)


func _limpiar_botones_respuesta() -> void:
	if _respuestas_container == null:
		return
	for hijo in _respuestas_container.get_children():
		_respuestas_container.remove_child(hijo)
		hijo.queue_free()
	_respuestas_container.visible = false


func _seleccionar_respuesta(indice: int) -> void:
	if indice < 0 or indice >= _respuestas.size() or not _abierto:
		return
	var opcion: Dictionary = _respuestas[indice]
	var texto_jugador := str(opcion.get("jugador", opcion.get("texto_jugador", opcion.get("texto", "")))).strip_edges()
	var texto_npc := str(opcion.get("respuesta", opcion.get("reaccion", ""))).strip_edges()
	if texto_jugador.is_empty() or texto_npc.is_empty():
		return

	var personaje_id := _fuente.get_personaje_game_id().strip_edges() if is_instance_valid(_fuente) else ""
	var evento := str(opcion.get("evento", "")).strip_edges().to_lower()
	var clave_opcion := str(opcion.get("clave", texto_jugador)).strip_edges()
	if not personaje_id.is_empty() and relationship_system != null:
		if not evento.is_empty():
			var contexto := {
				"origen": "respuesta_dialogo",
				"clave_dialogo": str(_lineas[0].get("texto", "")) if not _lineas.is_empty() else "",
				"respuesta_jugador": texto_jugador,
				"clave_opcion": clave_opcion
			}
			var evento_id := _crear_id_evento_respuesta(personaje_id, evento, clave_opcion)
			relationship_system.registrar_evento_social(personaje_id, evento, evento_id, contexto)
		if not clave_opcion.is_empty() and not bool(opcion.get("despedida", false)):
			relationship_system.registrar_recuerdo(personaje_id, {
				"tipo": "tema_conversacion",
				"clave": clave_opcion,
				"titulo": str(opcion.get("texto", "")),
				"frase_jugador": texto_jugador,
				"respuesta_npc": texto_npc,
				"importancia": float(opcion.get("importancia", 1.0)),
				"momento": Time.get_datetime_string_from_system(true)
			})

	var es_despedida := bool(opcion.get("despedida", false))
	_respuestas.clear()
	if not es_despedida and is_instance_valid(_fuente):
		_respuestas = _crear_opciones_conversacion()
	_limpiar_botones_respuesta()
	_lineas.append({"hablante": "Tú", "texto": texto_jugador})
	_lineas.append({
		"hablante": _fuente.get_nombre_visual() if is_instance_valid(_fuente) else "",
		"texto": texto_npc
	})
	_indice_linea += 1
	_mostrar_linea_actual()
	_actualizar_boton_accion()


func _crear_id_evento_respuesta(
	personaje_id: String,
	evento: String,
	identificador_opcion: String = ""
) -> String:
	var dia_clave := Time.get_date_string_from_system()
	if relationship_system != null and relationship_system.has_method("obtener_contexto_temporal"):
		var contexto_temporal_variant: Variant = relationship_system.call("obtener_contexto_temporal")
		if contexto_temporal_variant is Dictionary:
			var contexto_temporal := contexto_temporal_variant as Dictionary
			if bool(contexto_temporal.get("calendario_cargado", false)):
				dia_clave = "mundo:%d:%d" % [
					int(contexto_temporal.get("anio", 0)),
					int(contexto_temporal.get("dia", 1))
				]
	var sufijo_opcion := ""
	if not identificador_opcion.strip_edges().is_empty():
		sufijo_opcion = ":%s" % str(hash(identificador_opcion.strip_edges()))
	return "%s:dialogo:%s:%s%s" % [personaje_id, evento, dia_clave, sufijo_opcion]


func _obtener_mensaje_reaccion_social(evento: String, nombre: String) -> String:
	var mensajes := {
		"ayudar": "Agradece tu ayuda.",
		"apoyar": "Valora que lo hayas apoyado.",
		"promesa_cumplida": "Recuerda que cumpliste tu promesa.",
		"promesa_rota": "No olvidará que rompiste tu promesa.",
		"decir_verdad": "Valora tu sinceridad.",
		"mentir": "Tu mentira ha afectado su confianza.",
		"demostrar_habilidad": "Ha tomado nota de tu habilidad.",
		"compartir_conocimiento": "Aprecia lo que compartiste.",
		"faltar_respeto": "Se ha sentido ofendido.",
		"traicionar": "La traición ha dañado vuestra relación."
	}
	return nombre + ": " + str(mensajes.get(evento, "Recordará lo ocurrido."))


func _normalizar_lineas(datos: Dictionary) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []

	var lineas_variant: Variant = datos.get(
		"lineas",
		datos.get("lines", [])
	)

	if not lineas_variant is Array:
		var texto := str(
			datos.get(
				"texto",
				datos.get("text", "")
			)
		).strip_edges()

		if not texto.is_empty():
			resultado.append({
				"texto": texto,
				"hablante": str(
					datos.get(
						"hablante",
						datos.get("speaker", "")
					)
				)
			})

		return resultado

	for linea_variant in lineas_variant as Array:
		if linea_variant is String:
			var texto_linea := str(linea_variant).strip_edges()
			if not texto_linea.is_empty():
				resultado.append({
					"texto": texto_linea,
					"hablante": ""
				})
			continue

		if not linea_variant is Dictionary:
			continue

		var linea := (linea_variant as Dictionary).duplicate(true)
		var texto := str(
			linea.get(
				"texto",
				linea.get("text", "")
			)
		).strip_edges()

		if texto.is_empty():
			continue

		resultado.append({
			"texto": texto,
			"hablante": str(
				linea.get(
					"hablante",
					linea.get("speaker", "")
				)
			).strip_edges()
		})

	return resultado



func _crear_icono_interaccion(tipo: String) -> Texture2D:
	var svg := ""
	if tipo == "regalo":
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><g fill="none" stroke="#FFF3D6" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7 21h34v21H7zM4 14h40v8H4zM24 14v28"/><path d="M24 14c-2-11-16-11-16-4 0 6 8 6 16 4Zm0 0c2-11 16-11 16-4 0 6-8 6-16 4Z"/></g></svg>"""
	elif tipo == "dialogo":
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 48 48"><g fill="none" stroke="#FFF3D6" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M7 9h34v25H22l-10 8v-8H7z"/><path d="M15 18h18M15 25h12"/></g></svg>"""
	else:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 48 48"><g fill="none" stroke="#FFF3D6" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M17 17a7.5 7.5 0 1 1 12.8 5.3c-3.2 3.1-5.8 4-5.8 9.2"/><path d="M24 39h.02"/></g></svg>"""
	var imagen := Image.new()
	var error_svg := imagen.load_svg_from_string(svg)
	if error_svg != OK or imagen.is_empty():
		return null
	imagen.resize(28, 28, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(imagen)


func _abrir_selector_items(modo: String) -> void:
	if not _abierto or _selector_items == null or _inventario == null:
		if _inventario == null:
			Events.notification_pushed.emit("No se pudo acceder al inventario.")
		return
	if not is_instance_valid(_fuente):
		return
	_modo_selector_items = modo
	_selector_items_titulo.text = "Regalar un objeto" if modo == "regalo" else "¿Qué objeto quieres consultar?"
	for hijo in _selector_items_grid.get_children():
		_selector_items_grid.remove_child(hijo)
		hijo.queue_free()

	var items: Array[Dictionary] = _inventario.runtime.state.items
	var cantidad_items := 0
	var personaje_id := _fuente.get_personaje_game_id().strip_edges()
	for indice in range(items.size()):
		var objeto: Dictionary = items[indice]
		if objeto.is_empty():
			continue
		cantidad_items += 1
		var item_id := str(objeto.get("item_id", objeto.get("id", ""))).strip_edges()
		var nombre := str(objeto.get("nombre", "Objeto")).strip_edges()
		var boton := Button.new()
		boton.custom_minimum_size = Vector2(138, 48)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.icon = ItemIconResolver.obtener_icono(objeto)
		boton.text = nombre + "  x" + str(maxi(1, int(objeto.get("cantidad", 1))))
		boton.tooltip_text = nombre
		if modo == "regalo":
			boton.tooltip_text += "\n" + _obtener_etiqueta_preferencia_regalo(personaje_id, item_id)
		boton.set_meta("indice_inventario", indice)
		boton.pressed.connect(_seleccionar_item_interaccion.bind(indice, item_id, modo))
		_selector_items_grid.add_child(boton)

	if cantidad_items == 0:
		var vacio := Label.new()
		vacio.text = "No tienes objetos disponibles."
		vacio.custom_minimum_size = Vector2(420, 44)
		_selector_items_grid.add_child(vacio)
	PIXEL_UI_THEME.apply(_selector_items)
	# El brillo se aplica después del tema para conservar el borde dorado.
	if modo == "pregunta":
		for indice in range(items.size()):
			var objeto: Dictionary = items[indice]
			if objeto.is_empty():
				continue
			var item_id_brillo := str(objeto.get("item_id", objeto.get("id", ""))).strip_edges()
			if relationship_system == null or not relationship_system.conoce_item(personaje_id, item_id_brillo):
				continue
			var boton_conocido := _buscar_boton_item(indice)
			if boton_conocido != null:
				var brillo := StyleBoxFlat.new()
				brillo.bg_color = Color("#4B3924")
				brillo.border_color = Color("#F2D18A")
				brillo.set_border_width_all(2)
				brillo.shadow_color = Color(0.95, 0.72, 0.30, 0.72)
				brillo.shadow_size = 7
				brillo.corner_radius_top_left = 4
				brillo.corner_radius_top_right = 4
				brillo.corner_radius_bottom_left = 4
				brillo.corner_radius_bottom_right = 4
				boton_conocido.add_theme_stylebox_override("normal", brillo)
				boton_conocido.add_theme_stylebox_override("hover", brillo)
				boton_conocido.add_theme_stylebox_override("pressed", brillo)
	_selector_items.visible = true


func _buscar_boton_item(indice_inventario: int) -> Button:
	for boton_variant in _selector_items_grid.get_children():
		if not boton_variant is Button:
			continue
		var boton := boton_variant as Button
		if boton.has_meta("indice_inventario") and int(boton.get_meta("indice_inventario")) == indice_inventario:
			return boton
	return null


func _cerrar_selector_items() -> void:
	if _selector_items != null:
		_selector_items.visible = false
	_modo_selector_items = ""


func _seleccionar_item_interaccion(indice: int, item_id_esperado: String, modo: String) -> void:
	if not _abierto or _inventario == null or not is_instance_valid(_fuente):
		return
	var objeto := _inventario.obtener_item(indice)
	if objeto.is_empty():
		_cerrar_selector_items()
		return
	var item_id := str(objeto.get("item_id", objeto.get("id", ""))).strip_edges()
	if item_id != item_id_esperado:
		_cerrar_selector_items()
		Events.notification_pushed.emit("El inventario cambió. Vuelve a seleccionar el objeto.")
		return
	var personaje_id := _fuente.get_personaje_game_id().strip_edges()
	var nombre_item := str(objeto.get("nombre", "objeto")).strip_edges()
	var respuesta_npc := ""

	if modo == "regalo":
		if relationship_system == null or relationship_system.obtener_relacion(personaje_id).is_empty():
			Events.notification_pushed.emit("No se pudo registrar el regalo.")
			return
		if not _inventario.quitar_cantidad_desde_ui(indice, 1):
			Events.notification_pushed.emit("No se pudo retirar el objeto del inventario.")
			return
		var relacion_resultado: Dictionary = relationship_system.registrar_regalo(personaje_id, item_id, nombre_item)
		if relacion_resultado.is_empty():
			_inventario.agregar_objeto_desde_ui(objeto)
			Events.notification_pushed.emit("No se pudo registrar el regalo; el objeto volvió a tu inventario.")
			return
		var datos_regalo := relationship_system.evaluar_regalo(personaje_id, item_id)
		respuesta_npc = _crear_reaccion_regalo(nombre_item, datos_regalo, _fuente.get_nombre_visual())
	else:
		respuesta_npc = _crear_respuesta_pregunta_item(objeto, personaje_id, item_id)

	_cerrar_selector_items()
	var texto_jugador := "Quiero darte esto: " + nombre_item + "." if modo == "regalo" else "¿Qué puedes contarme sobre " + nombre_item + "?"
	_mostrar_intercambio_item(texto_jugador, respuesta_npc)
	if modo == "regalo":
		Events.notification_pushed.emit(_fuente.get_nombre() + " recibió " + nombre_item + ".")


func _obtener_etiqueta_preferencia_regalo(personaje_id: String, item_id: String) -> String:
	if relationship_system == null or not relationship_system.conoce_item(personaje_id, item_id):
		return "Todavía no sabe qué piensa de este objeto"
	var reaccion := str(relationship_system.evaluar_regalo(personaje_id, item_id).get("reaccion", "neutral")).strip_edges().to_lower()
	match reaccion:
		"encanta":
			return "Le encanta"
		"gusta":
			return "Le gusta"
		"no_gusta":
			return "No le gusta"
		"detesta":
			return "Lo detesta"
		_:
			return "Le resulta indiferente"


func _crear_reaccion_regalo(nombre_item: String, datos_regalo: Dictionary, personaje_nombre: String = "") -> String:
	var reaccion := str(datos_regalo.get("reaccion", "neutral")).strip_edges().to_lower()
	var respuestas_por_personaje := {
		"elian": {
			"encanta": "¡Muchas gracias! {item} me viene perfecto. Me gusta poder guardar un detalle así para disfrutarlo con calma.",
			"gusta": "Gracias por {item}. Es un detalle sencillo, pero de esos que alegran el día.",
			"neutral": "Gracias por pensar en mí. No es algo que suela buscar, pero aprecio el gesto.",
			"no_gusta": "Gracias por el detalle. No es algo que necesite, aunque valoro que te hayas acordado de mí.",
			"detesta": "Prefiero ser sincero: {item} no es algo que me agrade. Aun así, gracias por la intención."
		},
		"bruna": {
			"encanta": "Esto sí que me sirve. Gracias por {item}; voy a encontrarle un buen uso.",
			"gusta": "Gracias por {item}. Es útil y eso ya es bastante más de lo que puedo decir de muchos regalos.",
			"neutral": "Gracias. No es algo que hubiera elegido, pero no voy a despreciar el gesto.",
			"no_gusta": "No es de mi gusto, pero entiendo la intención. Gracias.",
			"detesta": "No voy a fingir que me gusta {item}. Aun así, agradezco que hayas pensado en mí."
		},
		"darven": {
			"encanta": "Gracias. {item} me será de mucha utilidad; aprecio que hayas pensado en algo práctico.",
			"gusta": "Gracias por {item}. Seguro que puedo darle un buen uso.",
			"neutral": "Te agradezco el detalle. No es algo que necesite ahora mismo, pero lo tendré en cuenta.",
			"no_gusta": "Gracias por la intención. No es algo que vaya a utilizar mucho, pero aprecio el gesto.",
			"detesta": "No es un objeto que me agrade, pero no quiero que confundas eso con despreciar tu intención."
		},
		"saira": {
			"encanta": "¡Qué buen hallazgo! {item} tiene justo esa clase de encanto que me gusta encontrar en los caminos.",
			"gusta": "¡Gracias! Me gusta {item}; seguro que terminaré contándote de dónde viene o qué me recuerda.",
			"neutral": "Gracias por el detalle. No es algo que hubiera buscado, pero siempre es interesante recibir algo inesperado.",
			"no_gusta": "No termina de convencerme, pero no voy a rechazarlo sin más. Gracias por acordarte de mí.",
			"detesta": "No es precisamente lo que me gusta encontrar en mis viajes. Aun así, agradezco el gesto."
		},
		"narel": {
			"encanta": "Interesante elección. Gracias por {item}; me gustaría observarlo con más detenimiento.",
			"gusta": "Gracias por {item}. Puede que encuentre algún detalle que merezca la pena estudiar.",
			"neutral": "Gracias. No tengo una opinión formada sobre este objeto, pero aprecio que lo compartas conmigo.",
			"no_gusta": "No es un objeto que me interese especialmente, aunque agradezco la consideración.",
			"detesta": "Debo admitir que {item} no me agrada. Eso no quita que valore tu intención."
		}
	}
	var personaje := personaje_nombre.strip_edges().to_lower()
	var respuestas: Dictionary = respuestas_por_personaje.get(personaje, {})
	var respuesta := str(respuestas.get(reaccion, "")).replace("{item}", nombre_item)
	if not respuesta.is_empty():
		return respuesta
	if reaccion == "encanta":
		return "¡Muchas gracias! " + nombre_item + " es uno de mis objetos favoritos. Me alegra que pensaras en mí."
	if reaccion == "gusta":
		return "Gracias por " + nombre_item + ". Es un detalle que aprecio."
	if reaccion == "no_gusta":
		return "Gracias por el gesto, aunque " + nombre_item + " no es algo que suela apreciar."
	if reaccion == "detesta":
		return "No debiste traerme " + nombre_item + ". No es algo que me agrade."
	return "Gracias por el regalo. Recordaré que pensaste en mí."


func _crear_respuesta_pregunta_item(objeto: Dictionary, personaje_id: String, item_id: String) -> String:
	var nombre_item := str(objeto.get("nombre", "ese objeto")).strip_edges()
	if relationship_system != null and relationship_system.conoce_item(personaje_id, item_id):
		var datos_conocidos := relationship_system.evaluar_regalo(personaje_id, item_id)
		var descripcion := str(objeto.get("descripcion", "")).strip_edges()
		var reaccion := str(datos_conocidos.get("reaccion", "neutral")).strip_edges().to_lower()
		var respuesta := "Sí, conozco " + nombre_item + "."
		if not descripcion.is_empty():
			respuesta += " " + descripcion
		match reaccion:
			"adorado", "favorito", "muy_amado", "encanta", "muy_positivo":
				respuesta += " Es uno de los objetos que más aprecio."
			"le_gusta", "gusta", "positivo", "bueno", "muy_bueno":
				respuesta += " Me parece un objeto útil y agradable."
			"no_gusta", "no_le_gusta", "desagrado", "negativo", "malo":
				respuesta += " No es uno de mis objetos preferidos."
			"odia", "detesta", "muy_negativo":
				respuesta += " No me agrada demasiado."
			_:
				respuesta += " Lo conozco, aunque no tengo una opinión especial sobre él."
		return respuesta
	return "No conozco " + nombre_item + ". ¿Dónde lo encontraste? No recuerdo haber visto uno antes."


func _mostrar_intercambio_item(texto_jugador: String, texto_npc: String) -> void:
	if texto_jugador.is_empty() or texto_npc.is_empty():
		return
	_respuestas.clear()
	_limpiar_botones_respuesta()
	_acciones.clear()
	if action_button != null:
		action_button.visible = false
	if cancel_button != null:
		cancel_button.visible = false
	_lineas.append({"hablante": "Tú", "texto": texto_jugador})
	_lineas.append({
		"hablante": _fuente.get_nombre_visual() if is_instance_valid(_fuente) else "",
		"texto": texto_npc
	})
	_indice_linea = _lineas.size() - 2
	_mostrar_linea_actual()


func _crear_interfaz() -> void:
	if ui_root == null:
		return

	if dialogue_panel != null and is_instance_valid(dialogue_panel):
		return

	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.visible = false
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.z_index = 3000
	# El HUD es el Control raíz dentro del CanvasLayer. Usamos
	# coordenadas relativas al centro inferior para no depender de
	# tamaños heredados de otros paneles del HUD.
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_panel.offset_left = -360.0
	dialogue_panel.offset_top = -278.0
	dialogue_panel.offset_right = 360.0
	dialogue_panel.offset_bottom = -18.0
	dialogue_panel.custom_minimum_size = Vector2(720.0, 260.0)
	dialogue_panel.size = Vector2(720.0, 260.0)
	dialogue_panel.clip_contents = false
	dialogue_panel.z_as_relative = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.05, 0.032, 0.97)
	style.border_color = Color(0.58, 0.43, 0.24, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	dialogue_panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 14)
	dialogue_panel.add_child(margin)

	var content_row := HBoxContainer.new()
	_dialogue_content_row = content_row
	content_row.name = "DialogueContent"
	content_row.add_theme_constant_override("separation", 14)
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content_row)

	portrait_rect = TextureRect.new()
	portrait_rect.name = "SpeakerPortrait"
	# El retrato ocupa prácticamente toda la altura interior del panel.
	# Al ser cuadrado y conservar el aspecto, el sprite crece sin deformarse.
	portrait_rect.custom_minimum_size = Vector2(176, 176)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(portrait_rect)

	var column := VBoxContainer.new()
	column.name = "DialogueText"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	content_row.add_child(column)

	speaker_label = Label.new()
	speaker_label.name = "Speaker"
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	speaker_label.add_theme_color_override(
		"font_color",
		Color(0.93, 0.84, 0.65, 1.0)
	)
	speaker_label.add_theme_font_size_override("font_size", 14)
	column.add_child(speaker_label)

	text_label = Label.new()
	text_label.name = "Text"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 76)
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.75, 0.63, 1.0)
	)
	text_label.add_theme_font_size_override("font_size", 13)
	column.add_child(text_label)

	_botones_accion = HBoxContainer.new()
	_botones_accion.name = "DialogueActions"
	_botones_accion.alignment = BoxContainer.ALIGNMENT_CENTER
	_botones_accion.add_theme_constant_override("separation", 10)
	column.add_child(_botones_accion)

	action_button = Button.new()
	action_button.name = "DialogueAction"
	action_button.visible = false
	action_button.custom_minimum_size = Vector2(180, 34)
	action_button.add_theme_font_size_override("font_size", 11)
	action_button.pressed.connect(_ejecutar_accion_dialogo)
	_botones_accion.add_child(action_button)

	cancel_button = Button.new()
	cancel_button.name = "DialogueCancel"
	cancel_button.text = "Salir"
	cancel_button.visible = false
	cancel_button.custom_minimum_size = Vector2(120, 34)
	cancel_button.add_theme_font_size_override("font_size", 11)
	cancel_button.pressed.connect(cerrar)
	_botones_accion.add_child(cancel_button)

	_respuestas_container = GridContainer.new()
	_respuestas_container.name = "DialogueResponses"
	_respuestas_container.columns = 2
	_respuestas_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_respuestas_container.visible = false
	_respuestas_container.add_theme_constant_override("h_separation", 8)
	_respuestas_container.add_theme_constant_override("v_separation", 6)
	column.add_child(_respuestas_container)

	var columna_social := VBoxContainer.new()
	columna_social.name = "DialogueSocialActions"
	columna_social.custom_minimum_size = Vector2(48, 0)
	columna_social.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columna_social.add_theme_constant_override("separation", 8)
	content_row.add_child(columna_social)

	_boton_regalo = Button.new()
	_boton_regalo.name = "DialogueGiftButton"
	_boton_regalo.custom_minimum_size = Vector2(48, 48)
	_boton_regalo.icon = _crear_icono_interaccion("regalo")
	_boton_regalo.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boton_regalo.tooltip_text = "Regalar un objeto"
	_boton_regalo.pressed.connect(_abrir_selector_items.bind("regalo"))
	columna_social.add_child(_boton_regalo)

	_boton_preguntar_item = Button.new()
	_boton_preguntar_item.name = "DialogueAskItemButton"
	_boton_preguntar_item.custom_minimum_size = Vector2(48, 48)
	_boton_preguntar_item.icon = _crear_icono_interaccion("pregunta")
	_boton_preguntar_item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boton_preguntar_item.tooltip_text = "Preguntar por un objeto"
	_boton_preguntar_item.pressed.connect(_abrir_selector_items.bind("pregunta"))
	columna_social.add_child(_boton_preguntar_item)

	_selector_conversacion = PanelContainer.new()
	_selector_conversacion.name = "DialogueTopicSelector"
	_selector_conversacion.visible = false
	_selector_conversacion.mouse_filter = Control.MOUSE_FILTER_STOP
	_selector_conversacion.z_index = 30
	_selector_conversacion.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selector_conversacion.offset_left = 12.0
	_selector_conversacion.offset_top = 12.0
	_selector_conversacion.offset_right = -12.0
	_selector_conversacion.offset_bottom = -12.0
	dialogue_panel.add_child(_selector_conversacion)
	var topic_margin := MarginContainer.new()
	topic_margin.add_theme_constant_override("margin_left", 18)
	topic_margin.add_theme_constant_override("margin_top", 14)
	topic_margin.add_theme_constant_override("margin_right", 18)
	topic_margin.add_theme_constant_override("margin_bottom", 14)
	_selector_conversacion.add_child(topic_margin)
	var topic_column := VBoxContainer.new()
	topic_column.add_theme_constant_override("separation", 10)
	topic_margin.add_child(topic_column)
	var topic_header := HBoxContainer.new()
	topic_column.add_child(topic_header)
	var topic_title := Label.new()
	topic_title.text = "¿De qué te gustaría hablar?"
	topic_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topic_title.add_theme_font_size_override("font_size", 14)
	topic_header.add_child(topic_title)
	var topic_back := Button.new()
	topic_back.text = "Volver"
	topic_back.custom_minimum_size = Vector2(72, 30)
	topic_back.pressed.connect(_cerrar_selector_conversacion)
	topic_header.add_child(topic_back)
	_selector_conversacion_grid = GridContainer.new()
	_selector_conversacion_grid.columns = 2
	_selector_conversacion_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector_conversacion_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selector_conversacion_grid.add_theme_constant_override("h_separation", 8)
	_selector_conversacion_grid.add_theme_constant_override("v_separation", 8)
	topic_column.add_child(_selector_conversacion_grid)

	_selector_items = PanelContainer.new()
	_selector_items.name = "DialogueItemSelector"
	_selector_items.visible = false
	_selector_items.mouse_filter = Control.MOUSE_FILTER_STOP
	_selector_items.z_index = 20
	_selector_items.set_anchors_preset(Control.PRESET_CENTER)
	_selector_items.offset_left = -238.0
	_selector_items.offset_top = -112.0
	_selector_items.offset_right = 238.0
	_selector_items.offset_bottom = 112.0
	_selector_items.custom_minimum_size = Vector2(476, 224)
	dialogue_panel.add_child(_selector_items)

	var selector_margin := MarginContainer.new()
	selector_margin.add_theme_constant_override("margin_left", 12)
	selector_margin.add_theme_constant_override("margin_top", 10)
	selector_margin.add_theme_constant_override("margin_right", 12)
	selector_margin.add_theme_constant_override("margin_bottom", 10)
	_selector_items.add_child(selector_margin)

	var selector_column := VBoxContainer.new()
	selector_column.add_theme_constant_override("separation", 8)
	selector_margin.add_child(selector_column)

	var selector_header := HBoxContainer.new()
	selector_column.add_child(selector_header)
	_selector_items_titulo = Label.new()
	_selector_items_titulo.name = "ItemSelectorTitle"
	_selector_items_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector_items_titulo.add_theme_font_size_override("font_size", 13)
	selector_header.add_child(_selector_items_titulo)

	var selector_close := Button.new()
	selector_close.text = "X"
	selector_close.custom_minimum_size = Vector2(28, 28)
	selector_close.pressed.connect(_cerrar_selector_items)
	selector_header.add_child(selector_close)

	var selector_scroll := ScrollContainer.new()
	selector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selector_column.add_child(selector_scroll)

	_selector_items_grid = GridContainer.new()
	_selector_items_grid.columns = 3
	_selector_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selector_items_grid.add_theme_constant_override("h_separation", 6)
	_selector_items_grid.add_theme_constant_override("v_separation", 6)
	selector_scroll.add_child(_selector_items_grid)

	ui_root.add_child(dialogue_panel)
	PIXEL_UI_THEME.apply(dialogue_panel)
	dialogue_panel.visible = false
