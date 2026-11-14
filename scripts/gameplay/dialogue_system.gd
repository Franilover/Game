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
var _selector_items: PanelContainer = null
var _selector_items_grid: GridContainer = null
var _selector_items_titulo: Label = null
var _modo_selector_items: String = ""

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


func configurar(
	nuevo_player: Player,
	nuevo_ui_root: HUD,
	nuevo_mission_manager: MissionManagerService = null,
	nuevo_relationship_system: RelationshipSystemService = null,
	nuevo_inventario: InventoryController = null
) -> void:
	player = nuevo_player
	ui_root = nuevo_ui_root
	mission_manager = nuevo_mission_manager
	relationship_system = nuevo_relationship_system
	_inventario = nuevo_inventario
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
		# Los clics sobre controles de diálogo pertenecen a la interfaz.
		if event is InputEventMouseButton:
			var posicion_mouse := get_viewport().get_mouse_position()
			if _selector_items != null and _selector_items.visible and _selector_items.get_global_rect().has_point(posicion_mouse):
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
	_respuestas.clear()
	var respuestas_variant: Variant = datos_seleccionados.get("respuestas", datos_seleccionados.get("choices", []))
	if respuestas_variant is Array:
		for respuesta_variant in respuestas_variant as Array:
			if respuesta_variant is Dictionary and _respuestas.size() < 4:
				_respuestas.append((respuesta_variant as Dictionary).duplicate(true))
	var clave_dialogo_respuestas := str(datos_seleccionados.get("clave", "principal")).strip_edges().to_lower()
	var acciones_final_variant: Variant = datos_seleccionados.get("acciones", [])
	var tiene_acciones_finales := acciones_final_variant is Array and not (acciones_final_variant as Array).is_empty()
	if (
		_respuestas.is_empty()
		and not tiene_acciones_finales
		and (clave_dialogo_respuestas == "principal" or clave_dialogo_respuestas.begins_with("rutina_"))
	):
		_respuestas = _crear_respuestas_rutina()
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
		_boton_regalo.visible = true
	if _boton_preguntar_item != null:
		_boton_preguntar_item.visible = true
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
	_respuestas.clear()
	_limpiar_botones_respuesta()
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
	_cerrar_selector_items()
	if dialogue_panel != null:
		dialogue_panel.visible = false

	dialogue_finished.emit()
	Events.dialog_closed.emit()


func _avanzar() -> void:
	if _indice_caracter < _texto_completo.length():
		_indice_caracter = _texto_completo.length()
		text_label.text = _texto_completo
		return

	if _indice_linea >= _lineas.size() - 1 and not _respuestas.is_empty():
		_actualizar_boton_accion()
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
				if mission_manager_local != null and mission_manager_local.cumple_requisito_dialogo(requisito):
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
		var contextual := _seleccionar_variante_contextual(variantes_variant as Array, personaje_id)
		if not contextual.is_empty():
			return contextual

		var social: RelationshipSystemService = relationship_system
		if social != null:
			var seleccion: Dictionary = social.seleccionar_variante_dialogo(variantes_variant as Array, personaje_id)
			if not seleccion.is_empty() and str(seleccion.get("clave", "")).strip_edges().to_lower() != "principal":
				return seleccion.duplicate(true)

	var dialogo_rutina := _crear_dialogo_rutina_contextual()
	if not dialogo_rutina.is_empty():
		return dialogo_rutina

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
	return (
		float(relacion_actual.get("amistad", 0.0)) >= 20.0
		or float(relacion_actual.get("afecto", 0.0)) >= 15.0
		or float(relacion_actual.get("confianza", 0.0)) >= 20.0
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
	if not personaje_id.is_empty() and not evento.is_empty() and relationship_system != null:
		var contexto := {
			"origen": "respuesta_dialogo",
			"clave_dialogo": str(_lineas[0].get("texto", "")) if not _lineas.is_empty() else "",
			"respuesta_jugador": texto_jugador
		}
		var evento_id := _crear_id_evento_respuesta(personaje_id, evento)
		relationship_system.registrar_evento_social(personaje_id, evento, evento_id, contexto)

	_respuestas.clear()
	_limpiar_botones_respuesta()
	_lineas.append({"hablante": "Tú", "texto": texto_jugador})
	_lineas.append({
		"hablante": _fuente.get_nombre_visual() if is_instance_valid(_fuente) else "",
		"texto": texto_npc
	})
	_indice_linea += 1
	_mostrar_linea_actual()
	_actualizar_boton_accion()


func _crear_id_evento_respuesta(personaje_id: String, evento: String) -> String:
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
	return "%s:dialogo:%s:%s" % [personaje_id, evento, dia_clave]


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
	else:
		svg = """<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><g fill="none" stroke="#FFF3D6" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M17 17a7.5 7.5 0 1 1 12.8 5.3c-3.2 3.1-5.8 4-5.8 9.2"/><path d="M24 39h.02"/></g></svg>"""
	var imagen := Image.new()
	var error_svg := imagen.load_svg_from_string(svg)
	if error_svg != OK or imagen.is_empty():
		return null
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
		boton.icon_max_width = 30
		boton.text = nombre + "  x" + str(maxi(1, int(objeto.get("cantidad", 1))))
		boton.tooltip_text = nombre
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
		var relacion_resultado: Dictionary = relationship_system.registrar_regalo(personaje_id, item_id)
		if relacion_resultado.is_empty():
			_inventario.agregar_objeto_desde_ui(objeto)
			Events.notification_pushed.emit("No se pudo registrar el regalo; el objeto volvió a tu inventario.")
			return
		var datos_regalo := relationship_system.evaluar_regalo(personaje_id, item_id)
		respuesta_npc = _crear_reaccion_regalo(nombre_item, datos_regalo)
	else:
		respuesta_npc = _crear_respuesta_pregunta_item(objeto, personaje_id, item_id)

	_cerrar_selector_items()
	var texto_jugador := "Quiero darte esto: " + nombre_item + "." if modo == "regalo" else "¿Qué puedes contarme sobre " + nombre_item + "?"
	_mostrar_intercambio_item(texto_jugador, respuesta_npc)
	if modo == "regalo":
		Events.notification_pushed.emit(_fuente.get_nombre() + " recibió " + nombre_item + ".")


func _crear_reaccion_regalo(nombre_item: String, datos_regalo: Dictionary) -> String:
	var reaccion := str(datos_regalo.get("reaccion", "neutral")).strip_edges().to_lower()
	match reaccion:
		"adorado", "favorito", "muy_amado", "encanta":
			return "¡Muchas gracias! " + nombre_item + " es uno de mis objetos favoritos. Me alegra que pensaras en mí."
		"le_gusta", "gusta", "positivo", "bueno":
			return "Gracias por " + nombre_item + ". Es un detalle que aprecio."
		"no_le_gusta", "desagrado", "negativo", "malo":
			return "Gracias por el gesto, aunque " + nombre_item + " no es algo que suela apreciar."
		"odia", "detesta", "muy_negativo":
			return "No debiste traerme " + nombre_item + ". No es algo que me agrade."
	return "Gracias por el regalo. Recordaré que pensaste en mí."


func _crear_respuesta_pregunta_item(objeto: Dictionary, personaje_id: String, item_id: String) -> String:
	var nombre_item := str(objeto.get("nombre", "ese objeto")).strip_edges()
	if relationship_system != null and relationship_system.conoce_item(personaje_id, item_id):
		var datos_conocidos := relationship_system.evaluar_regalo(personaje_id, item_id)
		var descripcion := str(objeto.get("descripcion", "")).strip_edges()
		var reaccion := str(datos_conocidos.get("reaccion", "")).strip_edges()
		var respuesta := "Sí, conozco " + nombre_item + "."
		if not descripcion.is_empty():
			respuesta += " " + descripcion
		if not reaccion.is_empty() and reaccion.to_lower() != "neutral":
			respuesta += " Tengo una opinión bastante clara sobre ese objeto: " + reaccion + "."
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
	_boton_regalo.icon_max_width = 28
	_boton_regalo.tooltip_text = "Regalar un objeto"
	_boton_regalo.pressed.connect(_abrir_selector_items.bind("regalo"))
	columna_social.add_child(_boton_regalo)

	_boton_preguntar_item = Button.new()
	_boton_preguntar_item.name = "DialogueAskItemButton"
	_boton_preguntar_item.custom_minimum_size = Vector2(48, 48)
	_boton_preguntar_item.icon = _crear_icono_interaccion("pregunta")
	_boton_preguntar_item.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boton_preguntar_item.icon_max_width = 28
	_boton_preguntar_item.tooltip_text = "Preguntar por un objeto"
	_boton_preguntar_item.pressed.connect(_abrir_selector_items.bind("pregunta"))
	columna_social.add_child(_boton_preguntar_item)

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
