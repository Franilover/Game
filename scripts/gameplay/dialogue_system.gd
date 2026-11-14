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

var _abierto: bool = false
var _lineas: Array[Dictionary] = []
var _indice_linea: int = 0
var _fuente: Creature = null

var _texto_completo: String = ""
var _indice_caracter: int = 0
var _temporizador_texto: float = 0.0
var _intervalo_caracter: float = 0.018


func _ready() -> void:
	add_to_group("dialogue_system")


func configurar(nuevo_player: Player, nuevo_ui_root: HUD, nuevo_mission_manager: MissionManagerService = null, nuevo_relationship_system: RelationshipSystemService = null) -> void:
	player = nuevo_player
	ui_root = nuevo_ui_root
	mission_manager = nuevo_mission_manager
	relationship_system = nuevo_relationship_system
	_crear_interfaz()


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


func _input(event: InputEvent) -> void:
	if not _abierto:
		return

	if event.is_action_pressed("primary_action"):
		# Los clics sobre el botón quedan para el sistema GUI; los clics
		# fuera de él siguen avanzando el diálogo normalmente.
		if action_button != null and action_button.visible and event is InputEventMouseButton:
			var posicion_mouse := get_viewport().get_mouse_position()
			if action_button.get_global_rect().has_point(posicion_mouse):
				return
		_avanzar()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_ESCAPE:
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

	_lineas = lineas
	_acciones.clear()

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
	print(
		"DialogueSystem: PANEL VISIBLE → ",
		dialogue_panel.get_path(),
		" | pos=",
		dialogue_panel.position,
		" | size=",
		dialogue_panel.size
	)
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
	_indice_linea = 0
	_texto_completo = ""
	_indice_caracter = 0
	_temporizador_texto = 0.0

	if is_instance_valid(_fuente):
		_fuente.reanudar_movimiento_temporal()

	_fuente = null
	_acciones.clear()

	if action_button != null:
		action_button.visible = false
	if cancel_button != null:
		cancel_button.visible = false

	if dialogue_panel != null:
		dialogue_panel.visible = false

	dialogue_finished.emit()
	Events.dialog_closed.emit()


func _avanzar() -> void:
	if _indice_caracter < _texto_completo.length():
		_indice_caracter = _texto_completo.length()
		text_label.text = _texto_completo
		return

	_indice_linea += 1

	if _indice_linea >= _lineas.size():
		cerrar()
		return

	_mostrar_linea_actual()


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



func _seleccionar_dialogo(datos: Dictionary) -> Dictionary:
	var variantes_variant: Variant = datos.get("variantes", [])
	if not variantes_variant is Array:
		var dialogo_rutina_sin_variantes := _crear_dialogo_rutina_en_transito()
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
				if mission_manager_local != null and mission_manager_local.cumple_requisito_dialogo(requisito):
					return variante
				continue

		if str(variante.get("clave", "")).strip_edges().to_lower() == "principal":
			principal = variante

	# Durante los desplazamientos, el NPC responde según su relación y
	# comunica el destino actual de su rutina sin interrumpir el horario.
	var dialogo_rutina := _crear_dialogo_rutina_en_transito()
	if not dialogo_rutina.is_empty():
		return dialogo_rutina

	# Los estados de misión tienen prioridad sobre los saludos sociales.
	# Si no hay una variante narrativa activa, se aplican amistad/confianza.
	var personaje_id := ""
	if is_instance_valid(_fuente):
		personaje_id = _fuente.get_personaje_game_id().strip_edges()
	if not personaje_id.is_empty():
		var contextual := _seleccionar_variante_contextual(variantes_variant as Array, personaje_id)
		if not contextual.is_empty():
			return contextual

		var social: RelationshipSystemService = relationship_system
		if social != null:
			var seleccion: Dictionary = social.seleccionar_variante_dialogo(variantes_variant as Array, personaje_id)
			if not seleccion.is_empty():
				return seleccion.duplicate(true)

	if not principal.is_empty():
		return principal
	return datos.duplicate(true)


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
	if not is_instance_valid(_fuente) or not bool(_fuente.get_meta("rutina_en_transito", false)):
		return {}

	var destino_clave := str(_fuente.get_meta("rutina_ubicacion", "plaza")).strip_edges().to_lower()
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
	var destino := str(destinos.get(destino_clave, "su próximo destino"))
	var nombre := _fuente.get_nombre_visual().strip_edges().to_lower()
	var amable := false
	var personaje_id := _fuente.get_personaje_game_id().strip_edges()
	if not personaje_id.is_empty() and relationship_system != null:
		var relacion_actual := relationship_system.obtener_relacion(personaje_id)
		amable = (
			float(relacion_actual.get("amistad", 0.0)) >= 20.0
			or float(relacion_actual.get("afecto", 0.0)) >= 15.0
			or float(relacion_actual.get("confianza", 0.0)) >= 20.0
		)

	var texto := ""
	match nombre:
		"elian":
			texto = ("¡Qué bueno verte! Llevo el pan todavía en la cabeza. Primero tengo que llegar a %s; búscame allí y te guardo un momento para conversar." if amable else "Disculpa, no puedo detenerme ahora. Tengo que llegar a %s antes de que se enfríe el trabajo. Allí podremos hablar.") % destino
		"bruna":
			texto = ("¡Eh, me alegra encontrarte! Voy a %s a terminar un encargo. Cuando deje las herramientas, hablamos tranquilamente." if amable else "Ahora no puedo parar; tengo un encargo entre manos. Voy a %s. Si necesitas algo, espérame allí.") % destino
		"darven":
			texto = ("Me alegra verte. Estoy siguiendo mi ronda hacia %s; cuando termine de asegurar la zona, tendrás toda mi atención." if amable else "En servicio. No puedo abandonar mi recorrido: me dirijo a %s. Si es importante, búscame allí.") % destino
		"saira":
			texto = ("¡Qué casualidad verte! Voy hacia %s, tengo unas cuentas que revisar. Si pasas por allí, podemos ponernos al día." if amable else "Ahora mismo voy con prisa; debo atender un asunto en %s. Allí estaré disponible cuando termine.") % destino
		"narel":
			texto = ("¡Ah, hola! Justo iba pensando en algo que debo consultar en %s. Acompáñame con la conversación allí; ahora temo perder el hilo." if amable else "Perdona, estoy intentando no olvidar una idea. Debo llegar a %s y dejar mis notas en orden. Hablemos después.") % destino
		"abel":
			texto = ("Me alegra que hayas venido. Me dirijo a %s; allí podremos hablar sin descuidar mis obligaciones." if amable else "Ahora debo continuar hacia %s. Cuando haya atendido mis responsabilidades, podremos conversar.") % destino
		"liam":
			texto = ("¡Hola! Voy camino a %s. Si me encuentras allí, podremos conversar un poco más." if amable else "Disculpa, tengo que llegar a %s. Búscame allí cuando termine lo que debo hacer.") % destino
		_:
			texto = ("Me alegra verte, pero tengo que llegar a %s. Allí podremos conversar." if amable else "Ahora debo continuar hacia %s. Puedes encontrarme allí cuando termine.") % destino

	return {
		"clave": "rutina_en_transito",
		"lineas": [{"hablante": _fuente.get_nombre_visual(), "texto": texto}]
	}


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
	dialogue_panel.offset_top = -238.0
	dialogue_panel.offset_right = 360.0
	dialogue_panel.offset_bottom = -18.0
	dialogue_panel.custom_minimum_size = Vector2(720.0, 220.0)
	dialogue_panel.size = Vector2(720.0, 220.0)
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

	ui_root.add_child(dialogue_panel)
	PIXEL_UI_THEME.apply(dialogue_panel)
	dialogue_panel.visible = false
