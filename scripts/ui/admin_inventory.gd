extends Control
class_name AdminInventory

const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")

var _jugador: Player = null
var _world_entity_spawner: WorldEntitySpawner = null
var _inventario: GarliaInventory = null
var _world_items: GarliaWorldItems = null
var _modo: String = "criaturas"
var _seleccion: Dictionary = {}
var _lista: VBoxContainer
var _detalle: VBoxContainer
var _titulo: Label
var _estado: Label
var _cantidad: SpinBox
var _boton_accion: Button
var _botones: Dictionary = {}
var _contenido_catalogo: HBoxContainer
var _panel_tiempo: ScrollContainer
var _atmosfera: WorldAtmosphere = null
var _estado_tiempo: Label
var _estado_tiempo_accion: Label
var _boton_bloqueo_tiempo: Button
var _botones_velocidad_tiempo: Dictionary = {}
var _hora_spin: SpinBox
var _minuto_spin: SpinBox
var _dias_spin: SpinBox
var _estacion_selector: OptionButton
var _anio_spin: SpinBox
var _relationship_system: Node = null
var _zone_manager: Node = null
var _campos_relacion: Dictionary = {}
var _boton_guardar_relacion: Button = null
var _dialogue_system: DialogueSystem = null
var _cutscene_director: CutsceneDirector = null
var _npc_conversation_system: NPCConversationSystem = null
var _contenido_narrativo: VBoxContainer = null
var _pestana_narrativa := "dialogos"
var _dialogos_admin: Array[Dictionary] = []
var _escenas_admin: Array[Dictionary] = []
var _eventos_admin: Array[Dictionary] = []
var _botones_pestana_narrativa: Dictionary = {}
var _escenario_debug: Dictionary = {}
var _controles_debug: Dictionary = {}
var _resultado_debug: VBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_ui()
	PIXEL_UI_THEME.apply(self, false)
	visible = false


func configurar(jugador: Player, spawner: WorldEntitySpawner, inventario: GarliaInventory, world_items: GarliaWorldItems = null) -> void:
	_jugador = jugador
	_world_entity_spawner = spawner
	_inventario = inventario
	_world_items = world_items


func configurar_aldeanos(relationship_system: Node, zone_manager: Node) -> void:
	_relationship_system = relationship_system
	_zone_manager = zone_manager


func configurar_narrativa(dialogue_system: DialogueSystem, cutscene_director: CutsceneDirector, npc_conversation_system: NPCConversationSystem) -> void:
	_dialogue_system = dialogue_system
	_cutscene_director = cutscene_director
	_npc_conversation_system = npc_conversation_system


func configurar_tiempo(atmosfera: WorldAtmosphere) -> void:
	_atmosfera = atmosfera
	if is_instance_valid(_atmosfera):
		if not _atmosfera.dia_cambiado.is_connected(_al_cambio_calendario):
			_atmosfera.dia_cambiado.connect(_al_cambio_calendario)
		if not _atmosfera.estacion_cambiada.is_connected(_al_cambio_estacion):
			_atmosfera.estacion_cambiada.connect(_al_cambio_estacion)
	if WorldData.has_signal("mundo_listo") and not WorldData.mundo_listo.is_connected(_al_calendario_disponible):
		WorldData.mundo_listo.connect(_al_calendario_disponible)
	_actualizar_panel_tiempo()


func abrir(jugador: Node = null) -> void:
	if jugador != null:
		_jugador = jugador
	_actualizar_visibilidad()


func _es_admin() -> bool:
	if _jugador == null or not is_instance_valid(_jugador):
		return false

	var datos_variant: Variant = GameState.obtener_configuracion_personaje_admin()
	if not datos_variant is Dictionary:
		return false

	return str((datos_variant as Dictionary).get("rol", "explorador")).to_lower() == "admin"


func _actualizar_visibilidad() -> void:
	var activo := _es_admin()
	visible = activo
	if not activo:
		return

	if _botones.has("tiempo"):
		(_botones["tiempo"] as Button).disabled = not _puede_controlar_tiempo()
	_cargar_lista()
	_actualizar_panel_tiempo()


func _crear_ui() -> void:
	var titulo_columna := VBoxContainer.new()
	titulo_columna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titulo_columna.add_theme_constant_override("separation", 4)
	add_child(titulo_columna)

	var encabezado := HBoxContainer.new()
	encabezado.add_theme_constant_override("separation", 3)
	titulo_columna.add_child(encabezado)

	for entrada in [["criaturas", "Criaturas"], ["objetos", "Objetos"], ["aldeanos", "Aldeanos"], ["tiempo", "Tiempo"]]:
		var boton := Button.new()
		boton.text = str(entrada[1])
		boton.toggle_mode = true
		boton.custom_minimum_size = Vector2(0, 24)
		boton.pressed.connect(_cambiar_modo.bind(str(entrada[0])))
		PIXEL_UI_THEME.apply(boton, false)
		encabezado.add_child(boton)
		_botones[str(entrada[0])] = boton

	var contenido := HBoxContainer.new()
	_contenido_catalogo = contenido
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 5)
	titulo_columna.add_child(contenido)

	var izquierda := VBoxContainer.new()
	izquierda.custom_minimum_size = Vector2(90, 0)
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izquierda.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(izquierda)

	var scroll := ScrollContainer.new()
	scroll.name = "CreatureObjectListScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	izquierda.add_child(scroll)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.custom_minimum_size = Vector2(0, 300)
	_lista.add_theme_constant_override("separation", 2)
	scroll.add_child(_lista)

	var scroll_detalle := ScrollContainer.new()
	scroll_detalle.name = "CreatureObjectDetailScroll"
	scroll_detalle.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_detalle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_detalle.follow_focus = false
	contenido.add_child(scroll_detalle)

	_detalle = VBoxContainer.new()
	_detalle.custom_minimum_size = Vector2(90, 0)
	_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalle.add_theme_constant_override("separation", 4)
	scroll_detalle.add_child(_detalle)

	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.add_child(_estado)

	_boton_accion = Button.new()
	_boton_accion.custom_minimum_size = Vector2(0, 26)
	_boton_accion.pressed.connect(_ejecutar_accion)
	_detalle.add_child(_boton_accion)

	_cantidad = SpinBox.new()
	_cantidad.min_value = 1
	_cantidad.max_value = 999
	_cantidad.step = 1
	_cantidad.value = 1
	_cantidad.custom_minimum_size = Vector2(0, 24)
	_cantidad.visible = false
	_detalle.add_child(_cantidad)

	_crear_panel_tiempo(titulo_columna)
	_cambiar_modo("criaturas")


func _cambiar_modo(modo: String) -> void:
	if modo == "tiempo" and not _puede_controlar_tiempo():
		return

	_modo = modo
	for clave in _botones:
		var boton: Button = _botones[clave]
		boton.button_pressed = clave == _modo

	var es_tiempo := _modo == "tiempo"
	_contenido_catalogo.visible = not es_tiempo
	_panel_tiempo.visible = es_tiempo
	if es_tiempo:
		_actualizar_panel_tiempo()
		return

	_seleccion.clear()
	_cargar_lista()
	_mostrar_detalle()


func _limpiar_lista() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()


func _cargar_lista() -> void:
	if _lista == null:
		return

	_limpiar_lista()

	if _modo == "criaturas":
		_cargar_criaturas()
	elif _modo == "objetos":
		_cargar_objetos()
	else:
		_cargar_aldeanos()


func _cargar_criaturas() -> void:
	var criaturas: Array[Dictionary] = WorldData.obtener_criaturas()
	criaturas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()
	)

	for criatura in criaturas:
		_crear_fila(
			str(criatura.get("nombre", "Criatura")),
			criatura
		)


func _cargar_objetos() -> void:
	if _world_items == null or not is_instance_valid(_world_items):
		var aviso := Label.new()
		aviso.text = "No se encontró el catálogo de objetos."
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(aviso)
		return

	var catalogo: Array[Dictionary] = _world_items.obtener_catalogo()
	var grupos: Dictionary = {}

	for item in catalogo:
		var grupo := _obtener_grupo_objeto(item)
		if not grupos.has(grupo):
			grupos[grupo] = []
		grupos[grupo].append(item)

	var claves: Array = grupos.keys()
	claves.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(a).to_lower() < str(b).to_lower()
	)

	for grupo in claves:
		var separador := Label.new()
		separador.text = str(grupo)
		separador.add_theme_font_size_override("font_size", 12)
		_lista.add_child(separador)

		var objetos: Array = grupos[grupo]
		objetos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()
		)

		for item in objetos:
			_crear_fila(str(item.get("nombre", "Objeto")), item)


func _cargar_aldeanos() -> void:
	var personajes: Array[Dictionary] = WorldData.obtener_personajes_game()
	personajes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()
	)
	for personaje in personajes:
		_crear_fila(str(personaje.get("nombre", "Personaje")), personaje)


func _obtener_grupo_objeto(item: Dictionary) -> String:
	var tags_variant: Variant = item.get("tags", item.get("etiquetas", null))

	if tags_variant is Array:
		var tags := tags_variant as Array
		if not tags.is_empty():
			return str(tags[0])

	if tags_variant is String and not str(tags_variant).strip_edges().is_empty():
		return str(tags_variant).strip_edges()

	var propiedades_variant: Variant = item.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		for clave in ["categoria", "tipo", "grupo"]:
			var valor := str(propiedades.get(clave, "")).strip_edges()
			if not valor.is_empty():
				return valor

	for clave in ["categoria", "tipo", "tipo_item", "grupo"]:
		var valor := str(item.get(clave, "")).strip_edges()
		if not valor.is_empty():
			return valor

	return "Otros"


func _crear_fila(nombre: String, datos: Dictionary) -> void:
	var boton := Button.new()
	boton.text = nombre
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.custom_minimum_size = Vector2(0, 34)
	boton.pressed.connect(_seleccionar.bind(datos))
	PIXEL_UI_THEME.apply(boton, false)
	_lista.add_child(boton)


func _seleccionar(datos: Dictionary) -> void:
	_seleccion = datos.duplicate(true)
	_mostrar_detalle()


func _limpiar_detalle() -> void:
	for hijo in _detalle.get_children():
		if hijo == _estado or hijo == _boton_accion or hijo == _cantidad:
			continue
		hijo.queue_free()


func _mostrar_detalle() -> void:
	if _detalle == null:
		return

	_limpiar_detalle()

	if _seleccion.is_empty():
		_estado.text = "Selecciona un elemento para ver su información."
		_boton_accion.disabled = true
		_cantidad.visible = false
		return

	if _modo == "aldeanos":
		_mostrar_detalle_aldeano()
		return

	var nombre := str(_seleccion.get("nombre", "Elemento"))
	var descripcion := str(_seleccion.get("descripcion", "Sin descripción."))

	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(120, 120)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if _modo == "criaturas":
		var ruta := "res://assets/art/creatures/" + nombre + ".png"
		if nombre.to_lower() == "humano":
			ruta = "res://assets/art/creatures/Humano.png"
		if ResourceLoader.exists(ruta):
			icono.texture = load(ruta)
	else:
		icono.texture = ItemIconResolver.obtener_icono(_seleccion)

	_detalle.add_child(icono)
	_detalle.move_child(icono, 0)

	var titulo := Label.new()
	titulo.text = nombre
	titulo.add_theme_font_size_override("font_size", 18)
	_detalle.add_child(titulo)
	_detalle.move_child(titulo, 1)

	var info := Label.new()
	info.text = descripcion
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.add_child(info)
	_detalle.move_child(info, 2)

	if _modo == "objetos":
		_cantidad.visible = true
		_boton_accion.text = "Dar al jugador"
	else:
		_cantidad.visible = false
		_boton_accion.text = "Invocar criatura"

	_boton_accion.disabled = false


func _mostrar_detalle_aldeano() -> void:
	var nombre := str(_seleccion.get("nombre", "Personaje"))
	var personaje_id := str(_seleccion.get("id", ""))
	var npc := _buscar_npc_aldeano(personaje_id, nombre)
	var titulo := Label.new()
	titulo.text = nombre
	titulo.add_theme_font_size_override("font_size", 18)
	_detalle.add_child(titulo)

	var estado_actual := Label.new()
	if npc != null:
		var actividad := str(npc.datos.get("actividad_actual", npc.get_meta("rutina_actual", "Sin actividad")))
		var ubicacion := str(npc.get_meta("rutina_ubicacion", _seleccion.get("ubicacion_clave", "Sin ubicación")))
		estado_actual.text = "Ahora: %s\nLugar: %s" % [actividad.replace("_", " ").capitalize(), ubicacion.replace("_", " ").capitalize()]
	else:
		estado_actual.text = "Este personaje no está presente en la zona actual."
	estado_actual.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.add_child(estado_actual)

	_boton_accion.text = "Teletransportarme hasta " + nombre
	_boton_accion.disabled = npc == null
	_cantidad.visible = false

	_detalle.add_child(_crear_separador_tiempo("Horario semanal"))
	var rutinas_variant: Variant = _seleccion.get("rutinas", [])
	var rutinas: Array = rutinas_variant if rutinas_variant is Array else []
	if rutinas.is_empty():
		var sin_horario := Label.new()
		sin_horario.text = "No tiene horarios configurados."
		_detalle.add_child(sin_horario)
	else:
		for rutina_variant in rutinas:
			if not rutina_variant is Dictionary:
				continue
			var rutina := rutina_variant as Dictionary
			var dias := _nombres_dias(rutina.get("dias_semana", []))
			var actividad := str(rutina.get("actividad_clave", "Actividad")).replace("_", " ").capitalize()
			var ubicacion := str(rutina.get("ubicacion_clave", "Sin lugar")).replace("_", " ").capitalize()
			var horario := Label.new()
			horario.text = "%s · %s–%s\n%s · %s" % [dias, str(rutina.get("hora_inicio", "--:--")), str(rutina.get("hora_fin", "--:--")), actividad, ubicacion]
			horario.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detalle.add_child(horario)
	var descanso := Label.new()
	descanso.text = "Día 5 · Descanso semanal"
	_detalle.add_child(descanso)
	_crear_inspector_narrativo(personaje_id)

	var separador_relaciones := _crear_separador_tiempo("Relación con el jugador")
	_detalle.add_child(separador_relaciones)
	_campos_relacion.clear()
	if _relationship_system == null or not is_instance_valid(_relationship_system) or not _relationship_system.has_method("obtener_relacion"):
		var sin_sistema := Label.new()
		sin_sistema.text = "No se encontró el sistema de relaciones."
		_detalle.add_child(sin_sistema)
		return
	var relacion_variant: Variant = _relationship_system.call("obtener_relacion", personaje_id)
	if not relacion_variant is Dictionary or (relacion_variant as Dictionary).is_empty():
		var sin_datos := Label.new()
		sin_datos.text = "Todavía no hay datos sociales disponibles para este personaje."
		_detalle.add_child(sin_datos)
		return
	var relacion := relacion_variant as Dictionary
	for clave in ["amistad", "confianza", "respeto", "afecto"]:
		var campo := SpinBox.new()
		campo.min_value = -100.0
		campo.max_value = 100.0
		campo.step = 0.5
		campo.value = float(relacion.get(clave, 0.0))
		campo.custom_minimum_size = Vector2(82, 26)
		_campos_relacion[clave] = campo
		var fila := HBoxContainer.new()
		var etiqueta := Label.new()
		etiqueta.text = clave.capitalize()
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)
		fila.add_child(campo)
		_detalle.add_child(fila)
	_boton_guardar_relacion = Button.new()
	_boton_guardar_relacion.text = "Guardar valores"
	_boton_guardar_relacion.custom_minimum_size = Vector2(0, 26)
	_boton_guardar_relacion.pressed.connect(_guardar_relacion_aldeano)
	PIXEL_UI_THEME.apply(_boton_guardar_relacion, false)
	_detalle.add_child(_boton_guardar_relacion)



func _crear_inspector_narrativo(personaje_id: String) -> void:
	_detalle.add_child(_crear_separador_tiempo("Contenido narrativo"))
	var pestanas := HBoxContainer.new()
	pestanas.add_theme_constant_override("separation", 3)
	_detalle.add_child(pestanas)
	_botones_pestana_narrativa.clear()
	for entrada in [["dialogos", "Diálogos"], ["escenas", "Escenas"], ["eventos", "Eventos"], ["pruebas", "Pruebas"]]:
		var boton := Button.new()
		boton.text = str(entrada[1])
		boton.toggle_mode = true
		boton.button_pressed = _pestana_narrativa == str(entrada[0])
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.pressed.connect(_cambiar_pestana_narrativa.bind(str(entrada[0])))
		PIXEL_UI_THEME.apply(boton, false)
		pestanas.add_child(boton)
		_botones_pestana_narrativa[str(entrada[0])] = boton
	_contenido_narrativo = VBoxContainer.new()
	_contenido_narrativo.add_theme_constant_override("separation", 5)
	_detalle.add_child(_contenido_narrativo)
	var catalogo: Dictionary = {}
	if is_instance_valid(_npc_conversation_system):
		var datos: Variant = _npc_conversation_system.call("obtener_narrativa_personaje", personaje_id)
		if datos is Dictionary:
			catalogo = datos
	_dialogos_admin = _copiar_registros(catalogo.get("dialogos", []))
	_escenas_admin = _copiar_registros(catalogo.get("escenas", []))
	_eventos_admin = _copiar_registros(catalogo.get("eventos", []))
	_inicializar_escenario_debug(personaje_id)
	_mostrar_pestana_narrativa()


func _copiar_registros(valor: Variant) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if valor is Array:
		for item in valor:
			if item is Dictionary:
				resultado.append((item as Dictionary).duplicate(true))
	return resultado


func _cambiar_pestana_narrativa(pestana: String) -> void:
	_pestana_narrativa = pestana
	for clave in _botones_pestana_narrativa:
		var boton := _botones_pestana_narrativa[clave] as Button
		if is_instance_valid(boton):
			boton.button_pressed = str(clave) == _pestana_narrativa
	_mostrar_pestana_narrativa()


func _limpiar_narrativa() -> void:
	if not is_instance_valid(_contenido_narrativo):
		return
	for hijo in _contenido_narrativo.get_children():
		hijo.queue_free()


func _texto_narrativo(texto: String, titulo: bool = false) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if titulo:
		etiqueta.add_theme_font_size_override("font_size", 12)
	_contenido_narrativo.add_child(etiqueta)


func _requisitos_narrativos(registro: Dictionary, dialogo: Dictionary = {}) -> String:
	var partes: Array[String] = []
	for fuente in [registro, dialogo]:
		for clave in ["requisitos", "requisitos_game", "condiciones", "condiciones_game", "requisito", "desbloqueo", "desbloqueo_game", "restricciones", "requirements"]:
			if not fuente.has(clave):
				continue
			var valor: Variant = fuente.get(clave)
			if valor is String and not str(valor).is_empty():
				partes.append(str(valor))
			elif valor is Array or valor is Dictionary:
				partes.append(JSON.stringify(valor))
	return "\n".join(partes) if not partes.is_empty() else "Sin requisitos declarados en los datos."


func _mostrar_pestana_narrativa() -> void:
	_limpiar_narrativa()
	match _pestana_narrativa:
		"dialogos":
			_mostrar_dialogos_admin()
		"escenas":
			_mostrar_escenas_admin()
		"eventos":
			_mostrar_eventos_admin()
		"pruebas":
			_mostrar_pruebas_narrativas()


func _mostrar_dialogos_admin() -> void:
	_texto_narrativo("Diálogos registrados: %d" % _dialogos_admin.size(), true)
	if _dialogos_admin.is_empty():
		_texto_narrativo("No hay diálogos de este personaje en WorldData.")
		return
	for registro in _dialogos_admin:
		var contenido_variant: Variant = registro.get("dialogo", {})
		var dialogo: Dictionary = contenido_variant.duplicate(true) if contenido_variant is Dictionary else {}
		if contenido_variant is Array:
			dialogo["lineas"] = (contenido_variant as Array).duplicate(true)
		var clave := str(registro.get("clave", "principal"))
		dialogo["clave"] = clave
		_texto_narrativo(str(dialogo.get("titulo", registro.get("titulo", clave))), true)
		_texto_narrativo("Requisitos: " + _requisitos_narrativos(registro, dialogo))
		_texto_narrativo("Escenario actual: " + str(_evaluar_requisitos_narrativos(registro, dialogo).get("estado", "No evaluado")))
		var lineas: Array = dialogo.get("lineas", []) if dialogo.get("lineas", []) is Array else []
		for linea_variant in lineas:
			if linea_variant is Dictionary:
				var linea := linea_variant as Dictionary
				_texto_narrativo(str(linea.get("hablante", linea.get("npc", ""))) + ": " + str(linea.get("texto", "")))
		var boton := Button.new()
		boton.text = "Simular diálogo"
		boton.disabled = not is_instance_valid(_dialogue_system) or lineas.is_empty()
		boton.pressed.connect(_simular_dialogo_admin.bind(dialogo))
		PIXEL_UI_THEME.apply(boton, false)
		_contenido_narrativo.add_child(boton)


func _simular_dialogo_admin(dialogo: Dictionary) -> void:
	if not _es_admin() or not is_instance_valid(_dialogue_system):
		return
	# La fuente nula evita registrar recuerdos, relaciones o avance de misión.
	if _dialogue_system.abrir(dialogo.duplicate(true), null, true):
		_estado.text = "Vista previa de diálogo: sin guardar progreso."


func _mostrar_escenas_admin() -> void:
	_texto_narrativo("Escenas registradas: %d" % _escenas_admin.size(), true)
	if _escenas_admin.is_empty():
		_texto_narrativo("No hay escenas narrativas registradas.")
		return
	for escena in _escenas_admin:
		_texto_narrativo(str(escena.get("titulo", escena.get("clave", "Escena"))), true)
		_texto_narrativo("Participantes: %s y %s\nEtapas: %s\nRequisitos: %s" % [
			str(escena.get("npc_a", "?")), str(escena.get("npc_b", "?")),
			str(escena.get("etapas", "1–3")), str(escena.get("requisitos_texto", "Etapa narrativa disponible."))
		])
		_texto_narrativo("Escenario actual: " + str(_evaluar_requisitos_narrativos(escena).get("estado", "No evaluado")))
		_mostrar_lineas_escena_admin("Etapa 1", escena.get("lineas", []))
		_mostrar_lineas_escena_admin("Etapa 2", escena.get("lineas_siguientes", []))
		_mostrar_lineas_escena_admin("Etapa 3", escena.get("lineas_tercera_etapa", []))
		_mostrar_lineas_escena_admin("Variante con tensión", escena.get("lineas_tercera_tension", []))
		_mostrar_lineas_escena_admin("Variante alternativa", escena.get("lineas_alternativas", []))
		var boton := Button.new()
		boton.text = "Ver escena"
		boton.disabled = not is_instance_valid(_cutscene_director)
		boton.pressed.connect(_ver_escena_admin.bind(escena))
		PIXEL_UI_THEME.apply(boton, false)
		_contenido_narrativo.add_child(boton)


func _mostrar_lineas_escena_admin(titulo: String, valor: Variant) -> void:
	if not valor is Array or (valor as Array).is_empty():
		return
	_texto_narrativo(titulo, true)
	for linea_variant in valor as Array:
		if linea_variant is Dictionary:
			var linea := linea_variant as Dictionary
			_texto_narrativo(str(linea.get("npc", "")) + ": " + str(linea.get("texto", "")))


func _ver_escena_admin(escena: Dictionary) -> void:
	if not _es_admin() or not is_instance_valid(_cutscene_director):
		return
	var nombre_a := str(escena.get("npc_a", ""))
	var nombre_b := str(escena.get("npc_b", ""))
	var npc_a := _buscar_npc_aldeano("", nombre_a)
	var npc_b := _buscar_npc_aldeano("", nombre_b)
	if npc_a == null or npc_b == null:
		_estado.text = "Ambos NPC deben estar presentes en Torres."
		return
	if _cutscene_director.esta_activo():
		_estado.text = "Ya hay una cinemática en reproducción."
		return
	var centro := (npc_a.global_position + npc_b.global_position) * 0.5
	var camara := get_viewport().get_camera_2d()
	var zoom := camara.zoom.x * 1.12 if camara != null else 2.0
	var pasos: Array[Dictionary] = [
		{"tipo":"camara","x":centro.x,"y":centro.y,"zoom":zoom,"duracion":0.75},
		{"tipo":"mirar_npc","npc":nombre_a,"hacia_npc":nombre_b},
		{"tipo":"mirar_npc","npc":nombre_b,"hacia_npc":nombre_a}
	]
	var lineas_preview: Array[Dictionary] = []
	for item in escena.get("lineas", []):
		if item is Dictionary:
			var linea := item as Dictionary
			lineas_preview.append({"hablante":str(linea.get("npc","")),"texto":str(linea.get("texto",""))})
	if not lineas_preview.is_empty():
		pasos.append({"tipo":"dialogo","datos":{"clave":"admin_preview_" + str(escena.get("clave","escena")),"lineas":lineas_preview}})
	pasos.append({"tipo":"gesto_npc","npc":nombre_a,"gesto":str(escena.get("gesto_a","asentir")),"duracion":0.65})
	pasos.append({"tipo":"gesto_npc","npc":nombre_b,"gesto":str(escena.get("gesto_b","asentir")),"duracion":0.65})
	pasos.append({"tipo":"esperar","segundos":0.5})
	_estado.text = "Reproduciendo vista previa: " + str(escena.get("titulo", "Escena"))
	await _cutscene_director.ejecutar("admin_preview_" + str(escena.get("clave", "escena")), pasos)



func _inicializar_escenario_debug(personaje_id: String) -> void:
	_escenario_debug = {
		"amistad": 0.0, "confianza": 0.0, "respeto": 0.0, "afecto": 0.0,
		"mision_clave": "", "mision_estado": "sin_aceptar",
		"etapa": 0, "dia": 1, "anio": 1, "hora": 12
	}
	if is_instance_valid(_relationship_system) and _relationship_system.has_method("obtener_relacion"):
		var relacion: Variant = _relationship_system.call("obtener_relacion", personaje_id)
		if relacion is Dictionary:
			for clave in ["amistad", "confianza", "respeto", "afecto"]:
				_escenario_debug[clave] = float(relacion.get(clave, 0.0))
	if is_instance_valid(_atmosfera):
		var tiempo := _atmosfera.obtener_tiempo()
		_escenario_debug["dia"] = int(tiempo.get("dia", 1))
		_escenario_debug["anio"] = int(tiempo.get("anio", 1))
		_escenario_debug["hora"] = int(floor(float(tiempo.get("hora_del_dia", 12.0))))
	_controles_debug.clear()


func _crear_spin_debug(valor: float, minimo: float, maximo: float, paso: float = 1.0) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimo
	spin.max_value = maximo
	spin.step = paso
	spin.value = valor
	spin.custom_minimum_size = Vector2(72, 25)
	return spin


func _fila_control_debug(etiqueta_texto: String, control: Control) -> void:
	var fila := HBoxContainer.new()
	var etiqueta := Label.new()
	etiqueta.text = etiqueta_texto
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	fila.add_child(control)
	_contenido_narrativo.add_child(fila)


func _mostrar_pruebas_narrativas() -> void:
	_texto_narrativo("Laboratorio de condiciones narrativas", true)
	_texto_narrativo("Valores temporales: no modifican la partida, las relaciones, el calendario ni las misiones reales.")
	for clave in ["amistad", "confianza", "respeto", "afecto"]:
		var spin := _crear_spin_debug(float(_escenario_debug.get(clave, 0.0)), -100.0, 100.0, 0.5)
		_controles_debug[clave] = spin
		_fila_control_debug(clave.capitalize(), spin)
	var mision := LineEdit.new()
	mision.placeholder_text = "Clave de misión (opcional)"
	mision.text = str(_escenario_debug.get("mision_clave", ""))
	_controles_debug["mision_clave"] = mision
	_fila_control_debug("Misión", mision)
	var estado_mision := OptionButton.new()
	for opcion in [["Sin aceptar", "sin_aceptar"], ["Activa", "activa"], ["Completada", "completada"]]:
		estado_mision.add_item(str(opcion[0]))
		estado_mision.set_item_metadata(estado_mision.item_count - 1, str(opcion[1]))
	for i in range(estado_mision.item_count):
		if str(estado_mision.get_item_metadata(i)) == str(_escenario_debug.get("mision_estado", "sin_aceptar")):
			estado_mision.select(i)
	_controles_debug["mision_estado"] = estado_mision
	_fila_control_debug("Estado de misión", estado_mision)
	for par in [["etapa", "Etapa narrativa", 0.0, 3.0], ["dia", "Día", 1.0, 365.0], ["anio", "Año", -100000.0, 100000.0], ["hora", "Hora", 0.0, 23.0]]:
		var spin := _crear_spin_debug(float(_escenario_debug.get(str(par[0]), 0.0)), float(par[2]), float(par[3]))
		_controles_debug[str(par[0])] = spin
		_fila_control_debug(str(par[1]), spin)
	var acciones := HBoxContainer.new()
	var aplicar := Button.new()
	aplicar.text = "Evaluar escenario"
	aplicar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aplicar.pressed.connect(_aplicar_escenario_debug)
	PIXEL_UI_THEME.apply(aplicar, false)
	acciones.add_child(aplicar)
	var reiniciar := Button.new()
	reiniciar.text = "Restablecer"
	reiniciar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reiniciar.pressed.connect(_restablecer_escenario_debug)
	PIXEL_UI_THEME.apply(reiniciar, false)
	acciones.add_child(reiniciar)
	_contenido_narrativo.add_child(acciones)
	_resultado_debug = VBoxContainer.new()
	_resultado_debug.add_theme_constant_override("separation", 4)
	_contenido_narrativo.add_child(_resultado_debug)
	_mostrar_resultados_debug()


func _aplicar_escenario_debug() -> void:
	if not _es_admin():
		return
	for clave in ["amistad", "confianza", "respeto", "afecto", "etapa", "dia", "anio", "hora"]:
		var control := _controles_debug.get(clave) as SpinBox
		if is_instance_valid(control):
			_escenario_debug[clave] = control.value
	var mision := _controles_debug.get("mision_clave") as LineEdit
	if is_instance_valid(mision):
		_escenario_debug["mision_clave"] = mision.text.strip_edges()
	var estado := _controles_debug.get("mision_estado") as OptionButton
	if is_instance_valid(estado) and estado.selected >= 0:
		_escenario_debug["mision_estado"] = str(estado.get_item_metadata(estado.selected))
	_mostrar_resultados_debug()
	_estado.text = "Escenario narrativo temporal aplicado. La partida no fue modificada."


func _restablecer_escenario_debug() -> void:
	_inicializar_escenario_debug(str(_seleccion.get("id", "")))
	_mostrar_pestana_narrativa()


func _mostrar_resultados_debug() -> void:
	if not is_instance_valid(_resultado_debug):
		return
	for hijo in _resultado_debug.get_children():
		hijo.queue_free()
	var todos: Array[Dictionary] = []
	for registro in _dialogos_admin:
		var dialogo_variant: Variant = registro.get("dialogo", {})
		var dialogo: Dictionary = dialogo_variant if dialogo_variant is Dictionary else {}
		todos.append({"tipo":"Diálogo","nombre":str(registro.get("titulo", registro.get("clave", "Diálogo"))),"datos":registro,"contenido":dialogo})
	for escena in _escenas_admin:
		todos.append({"tipo":"Escena","nombre":str(escena.get("titulo", escena.get("clave", "Escena"))),"datos":escena,"contenido":{}})
	for evento in _eventos_admin:
		todos.append({"tipo":"Evento","nombre":str(evento.get("titulo", evento.get("clave", "Evento"))),"datos":evento,"contenido":{}})
	var compatibles := 0
	for entrada in todos:
		var evaluacion := _evaluar_requisitos_narrativos(entrada["datos"], entrada["contenido"])
		var estado := str(evaluacion.get("estado", "No evaluable"))
		if estado == "Cumple":
			compatibles += 1
		var etiqueta := Label.new()
		etiqueta.text = "%s · %s — %s" % [str(entrada["tipo"]), str(entrada["nombre"]), estado]
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_resultado_debug.add_child(etiqueta)
		for detalle in evaluacion.get("detalles", []):
			var nota := Label.new()
			nota.text = "  · " + str(detalle)
			nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_resultado_debug.add_child(nota)
	var resumen := Label.new()
	resumen.text = "Compatibles: %d / %d. Requisitos no estructurados quedan como no verificables." % [compatibles, todos.size()]
	resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resultado_debug.add_child(resumen)


func _evaluar_requisitos_narrativos(registro: Dictionary, contenido: Dictionary = {}) -> Dictionary:
	var fallos: Array[String] = []
	var detalles: Array[String] = []
	var reconocidos := 0
	var fuentes: Array[Dictionary] = [registro, contenido]
	var escenario := _escenario_debug
	var alias_relacion := {
		"amistad":["amistad_minima","amistad_min","min_amistad","amistad_requerida"],
		"confianza":["confianza_minima","confianza_min","min_confianza","confianza_requerida"],
		"respeto":["respeto_minimo","respeto_min","min_respeto","respeto_requerido"],
		"afecto":["afecto_minimo","afecto_min","min_afecto","afecto_requerido"]
	}
	for fuente in fuentes:
		for relacion in alias_relacion:
			for clave in alias_relacion[relacion]:
				if fuente.has(clave) and (fuente[clave] is int or fuente[clave] is float):
					reconocidos += 1
					var requerido := float(fuente[clave])
					var actual := float(escenario.get(relacion, 0.0))
					var cumple := actual >= requerido
					detalles.append("%s: %.1f / %.1f %s" % [relacion.capitalize(), actual, requerido, "OK" if cumple else "NO"])
					if not cumple:
						fallos.append(relacion)
		for clave_etapa in ["etapa_minima","etapa_min","min_etapa","etapa_requerida"]:
			if fuente.has(clave_etapa) and (fuente[clave_etapa] is int or fuente[clave_etapa] is float):
				reconocidos += 1
				var requerido_etapa := int(fuente[clave_etapa])
				var cumple_etapa := int(escenario.get("etapa", 0)) >= requerido_etapa
				detalles.append("Etapa: %d / %d %s" % [int(escenario.get("etapa", 0)), requerido_etapa, "OK" if cumple_etapa else "NO"])
				if not cumple_etapa:
					fallos.append("etapa")
		for clave_dia in ["dia_minimo","dia_min","min_dia","dia_requerido"]:
			if fuente.has(clave_dia) and (fuente[clave_dia] is int or fuente[clave_dia] is float):
				reconocidos += 1
				var requerido_dia := int(fuente[clave_dia])
				var cumple_dia := int(escenario.get("dia", 1)) >= requerido_dia
				detalles.append("Día: %d / %d %s" % [int(escenario.get("dia", 1)), requerido_dia, "OK" if cumple_dia else "NO"])
				if not cumple_dia:
					fallos.append("día")
		for clave_anio in ["anio_minimo","anio_min","min_anio","anio_requerido"]:
			if fuente.has(clave_anio) and (fuente[clave_anio] is int or fuente[clave_anio] is float):
				reconocidos += 1
				var requerido_anio := int(fuente[clave_anio])
				var cumple_anio := int(escenario.get("anio", 1)) >= requerido_anio
				detalles.append("Año: %d / %d %s" % [int(escenario.get("anio", 1)), requerido_anio, "OK" if cumple_anio else "NO"])
				if not cumple_anio:
					fallos.append("año")
		var mision_clave := str(fuente.get("mision_clave", fuente.get("mission_key", ""))).strip_edges()
		var mision_estado_requerido := str(fuente.get("mision_estado", fuente.get("mission_status", ""))).strip_edges().to_lower()
		if not mision_clave.is_empty() or not mision_estado_requerido.is_empty():
			reconocidos += 1
			var clave_coincide := mision_clave.is_empty() or mision_clave == str(escenario.get("mision_clave", ""))
			var estado_coincide := mision_estado_requerido.is_empty() or mision_estado_requerido == str(escenario.get("mision_estado", ""))
			var cumple_mision := clave_coincide and estado_coincide
			detalles.append("Misión: %s · %s %s" % [str(escenario.get("mision_clave", "sin clave")), str(escenario.get("mision_estado", "sin_aceptar")), "OK" if cumple_mision else "NO"])
			if not cumple_mision:
				fallos.append("misión")
	if reconocidos == 0:
		return {"estado":"No evaluable","detalles":["No hay requisitos estructurados compatibles con este simulador; revisa el texto original."]}
	if not fallos.is_empty():
		return {"estado":"No cumple","detalles":detalles}
	return {"estado":"Cumple","detalles":detalles}


func _mostrar_eventos_admin() -> void:
	_texto_narrativo("Eventos asociados: %d" % _eventos_admin.size(), true)
	if _eventos_admin.is_empty():
		_texto_narrativo("No hay acontecimientos registrados.")
		return
	for evento in _eventos_admin:
		_texto_narrativo(str(evento.get("titulo", evento.get("clave", "Evento"))), true)
		_texto_narrativo("Tipo: %s\nParticipantes: %s y %s\nRequisitos: %s" % [
			str(evento.get("tipo", "cotidiano")), str(evento.get("npc_a", "?")),
			str(evento.get("npc_b", "?")), str(evento.get("requisitos_texto", "Fecha y NPC disponibles."))
		])
		_texto_narrativo("Escenario actual: " + str(_evaluar_requisitos_narrativos(evento).get("estado", "No evaluado")))
		var lineas: Array = evento.get("lineas", []) if evento.get("lineas", []) is Array else []
		for linea_variant in lineas:
			if linea_variant is Dictionary:
				var linea := linea_variant as Dictionary
				_texto_narrativo(str(linea.get("npc", "")) + ": " + str(linea.get("texto", "")))
		var boton := Button.new()
		boton.text = "Simular evento"
		boton.disabled = not is_instance_valid(_dialogue_system) or lineas.is_empty()
		boton.pressed.connect(_simular_evento_admin.bind(evento))
		PIXEL_UI_THEME.apply(boton, false)
		_contenido_narrativo.add_child(boton)


func _simular_evento_admin(evento: Dictionary) -> void:
	if not _es_admin() or not is_instance_valid(_dialogue_system):
		return
	var lineas_preview: Array[Dictionary] = []
	for item in evento.get("lineas", []):
		if item is Dictionary:
			var linea := item as Dictionary
			lineas_preview.append({"hablante":str(linea.get("npc","")),"texto":str(linea.get("texto",""))})
	if lineas_preview.is_empty():
		return
	var datos := {"clave":"admin_preview_" + str(evento.get("clave","evento")),"lineas":lineas_preview}
	if _dialogue_system.abrir(datos, null, true):
		_estado.text = "Vista previa de evento: sin guardar progreso."


func _nombres_dias(dias_variant: Variant) -> String:
	if not dias_variant is Array or (dias_variant as Array).is_empty():
		return "Todos los días"
	var nombres := ["Día 1", "Día 2", "Día 3", "Día 4", "Día 5"]
	var resultado: Array[String] = []
	for dia_variant in dias_variant as Array:
		var dia := int(dia_variant)
		if dia >= 0 and dia < nombres.size():
			resultado.append(nombres[dia])
	return ", ".join(PackedStringArray(resultado)) if not resultado.is_empty() else "Sin días asignados"


func _buscar_npc_aldeano(personaje_id: String, nombre: String) -> Creature:
	for npc_variant in get_tree().get_nodes_in_group("torres_game_npc"):
		if not npc_variant is Creature or not is_instance_valid(npc_variant):
			continue
		var npc := npc_variant as Creature
		if not personaje_id.is_empty() and str(npc.datos.get("personaje_game_id", "")) == personaje_id:
			return npc
		if str(npc.get_nombre_visual()).strip_edges().to_lower() == nombre.strip_edges().to_lower():
			return npc
	return null


func _guardar_relacion_aldeano() -> void:
	if not _es_admin() or _seleccion.is_empty() or _relationship_system == null:
		return
	var personaje_id := str(_seleccion.get("id", ""))
	var actual_variant: Variant = _relationship_system.call("obtener_relacion", personaje_id)
	if not actual_variant is Dictionary:
		_estado.text = "No se pudieron leer los valores actuales."
		return
	var actual := actual_variant as Dictionary
	var cambios := {}
	for clave in _campos_relacion:
		var campo := _campos_relacion[clave] as SpinBox
		cambios[clave] = float(campo.value) - float(actual.get(clave, 0.0))
	var resultado: Variant = _relationship_system.call("modificar_relacion", personaje_id, cambios)
	if resultado is Dictionary and not (resultado as Dictionary).is_empty():
		_estado.text = "Valores de relación actualizados."
	else:
		_estado.text = "No se pudieron guardar los valores."


func _teletransportar_a_aldeano() -> void:
	if not _es_admin() or _seleccion.is_empty():
		return
	var npc := _buscar_npc_aldeano(str(_seleccion.get("id", "")), str(_seleccion.get("nombre", "")))
	if npc == null:
		_estado.text = "El personaje no está presente en esta zona."
		return
	if _zone_manager == null or not is_instance_valid(_zone_manager):
		_estado.text = "No se encontró el administrador de zonas."
		return
	var zona: Node = _zone_manager.call("obtener_zona_actual") as Node
	if zona == null or not zona.has_method("teletransportar_jugador_a_npc"):
		_estado.text = "Esta zona todavía no permite teletransportarse hasta aldeanos."
		return
	if bool(zona.call("teletransportar_jugador_a_npc", npc)):
		_estado.text = "Te teletransportaste hasta " + str(_seleccion.get("nombre", "el aldeano")) + "."
	else:
		_estado.text = "No se pudo encontrar una posición segura junto al personaje."


func _ejecutar_accion() -> void:
	if _seleccion.is_empty():
		return

	if _modo == "criaturas":
		_invocar()
	elif _modo == "aldeanos":
		_teletransportar_a_aldeano()
	else:
		_dar_objeto()


func _invocar() -> void:
	var spawner := _world_entity_spawner
	if spawner == null or not is_instance_valid(spawner) or not spawner.has_method("summon_criatura"):
		_estado.text = "No se encontró WorldEntitySpawner."
		return

	var nombre := str(_seleccion.get("nombre", "")).strip_edges()
	var posicion := Vector2.ZERO
	if _jugador is Node2D and is_instance_valid(_jugador):
		posicion = (_jugador as Node2D).global_position
	var resultado: Variant = spawner.call("summon_criatura", nombre, posicion)

	if resultado is Dictionary and bool((resultado as Dictionary).get("ok", false)):
		_estado.text = "Invocada: " + str((resultado as Dictionary).get("nombre", nombre))
	elif resultado is Dictionary:
		_estado.text = str((resultado as Dictionary).get("mensaje", "No se pudo invocar."))
	else:
		_estado.text = "No se pudo invocar."


func _dar_objeto() -> void:
	var jugador := _jugador
	if jugador == null or not is_instance_valid(jugador):
		_estado.text = "No se encontró el jugador."
		return

	var inventario := _inventario
	if inventario == null or not is_instance_valid(inventario) or not inventario.has_method("agregar_objeto"):
		_estado.text = "No se encontró el inventario del jugador."
		return

	var cantidad := maxi(1, int(_cantidad.value))
	var objeto := _seleccion.duplicate(true)
	objeto["cantidad"] = cantidad

	if inventario.call("agregar_objeto_desde_ui", objeto):
		_estado.text = "Añadido: " + str(objeto.get("nombre", "Objeto")) + " x" + str(cantidad)
	else:
		_estado.text = "No hay espacio suficiente en el inventario."

func _puede_controlar_tiempo() -> bool:
	var datos_variant: Variant = GameState.obtener_configuracion_personaje_admin()
	if not datos_variant is Dictionary:
		return false
	var datos := datos_variant as Dictionary
	if str(datos.get("rol", "explorador")).to_lower() != "admin":
		return false
	var capacidades_variant: Variant = datos.get("capacidades", [])
	return capacidades_variant is Array and "controlar_tiempo" in (capacidades_variant as Array)


func _crear_panel_tiempo(contenedor: VBoxContainer) -> void:
	_panel_tiempo = ScrollContainer.new()
	_panel_tiempo.name = "TimeControls"
	_panel_tiempo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_tiempo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_tiempo.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel_tiempo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_tiempo.visible = false
	contenedor.add_child(_panel_tiempo)

	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 7)
	_panel_tiempo.add_child(columna)

	_estado_tiempo = Label.new()
	_estado_tiempo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado_tiempo.add_theme_font_size_override("font_size", 13)
	columna.add_child(_estado_tiempo)

	_boton_bloqueo_tiempo = _crear_boton_tiempo("Bloquear avance del tiempo")
	_boton_bloqueo_tiempo.pressed.connect(_alternar_bloqueo_tiempo)
	columna.add_child(_boton_bloqueo_tiempo)

	columna.add_child(_crear_separador_tiempo("Velocidad del reloj"))
	var fila_velocidad := HBoxContainer.new()
	fila_velocidad.add_theme_constant_override("separation", 5)
	columna.add_child(fila_velocidad)
	for multiplicador in [1, 10, 60]:
		var boton_velocidad := _crear_boton_tiempo("×%d" % multiplicador)
		boton_velocidad.toggle_mode = true
		boton_velocidad.pressed.connect(_establecer_velocidad_tiempo.bind(multiplicador))
		fila_velocidad.add_child(boton_velocidad)
		_botones_velocidad_tiempo[multiplicador] = boton_velocidad

	columna.add_child(_crear_separador_tiempo("Hora del día"))
	var fila_hora := HBoxContainer.new()
	fila_hora.add_theme_constant_override("separation", 5)
	columna.add_child(fila_hora)
	_hora_spin = _crear_spin_tiempo(0, 23, 1)
	_minuto_spin = _crear_spin_tiempo(0, 59, 1)
	fila_hora.add_child(_campo_tiempo("Hora", _hora_spin))
	fila_hora.add_child(_campo_tiempo("Minuto", _minuto_spin))
	var aplicar_hora := _crear_boton_tiempo("Aplicar hora")
	aplicar_hora.pressed.connect(_aplicar_hora_tiempo)
	fila_hora.add_child(aplicar_hora)

	var fila_periodo := HBoxContainer.new()
	fila_periodo.add_theme_constant_override("separation", 5)
	columna.add_child(fila_periodo)
	var boton_dia := _crear_boton_tiempo("Mediodía")
	boton_dia.pressed.connect(_establecer_dia_tiempo)
	fila_periodo.add_child(boton_dia)
	var boton_noche := _crear_boton_tiempo("Medianoche")
	boton_noche.pressed.connect(_establecer_noche_tiempo)
	fila_periodo.add_child(boton_noche)

	columna.add_child(_crear_separador_tiempo("Días"))
	var fila_dias := HBoxContainer.new()
	fila_dias.add_theme_constant_override("separation", 5)
	columna.add_child(fila_dias)
	_dias_spin = _crear_spin_tiempo(1, 36500, 1)
	fila_dias.add_child(_campo_tiempo("Cantidad", _dias_spin))
	var retroceder := _crear_boton_tiempo("Retroceder")
	retroceder.pressed.connect(_desplazar_tiempo.bind(-1))
	fila_dias.add_child(retroceder)
	var avanzar := _crear_boton_tiempo("Avanzar")
	avanzar.pressed.connect(_desplazar_tiempo.bind(1))
	fila_dias.add_child(avanzar)

	columna.add_child(_crear_separador_tiempo("Estación"))
	var fila_estacion := HBoxContainer.new()
	fila_estacion.add_theme_constant_override("separation", 5)
	columna.add_child(fila_estacion)
	_estacion_selector = OptionButton.new()
	_estacion_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_estacion.add_child(_estacion_selector)
	var aplicar_estacion := _crear_boton_tiempo("Cambiar")
	aplicar_estacion.pressed.connect(_aplicar_estacion_tiempo)
	fila_estacion.add_child(aplicar_estacion)

	columna.add_child(_crear_separador_tiempo("Año"))
	var fila_anio := HBoxContainer.new()
	fila_anio.add_theme_constant_override("separation", 5)
	columna.add_child(fila_anio)
	_anio_spin = _crear_spin_tiempo(-100000, 100000, 1)
	fila_anio.add_child(_campo_tiempo("Año", _anio_spin))
	var aplicar_anio := _crear_boton_tiempo("Cambiar año")
	aplicar_anio.pressed.connect(_aplicar_anio_tiempo)
	fila_anio.add_child(aplicar_anio)

	_estado_tiempo_accion = Label.new()
	_estado_tiempo_accion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_estado_tiempo_accion)


func _crear_separador_tiempo(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 12)
	return etiqueta


func _crear_spin_tiempo(minimo: float, maximo: float, paso: float) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimo
	control.max_value = maximo
	control.step = paso
	control.custom_minimum_size = Vector2(75, 26)
	return control


func _crear_boton_tiempo(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0, 26)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PIXEL_UI_THEME.apply(boton, false)
	return boton


func _campo_tiempo(texto: String, control: Control) -> Control:
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 10)
	columna.add_child(etiqueta)
	columna.add_child(control)
	return columna


func _actualizar_panel_tiempo() -> void:
	if not is_instance_valid(_estado_tiempo):
		return
	if _atmosfera == null or not is_instance_valid(_atmosfera):
		_estado_tiempo.text = "No se encontró el calendario del mundo."
		_boton_bloqueo_tiempo.disabled = true
		return

	var datos := _atmosfera.obtener_tiempo()
	if not bool(datos.get("calendario_cargado", false)):
		_estado_tiempo.text = "Cargando calendario del mundo..."
		_boton_bloqueo_tiempo.disabled = true
		return

	_estado_tiempo.text = "Día %d · %s · Año %d · %s" % [int(datos.get("dia", 1)), str(datos.get("estacion", "—")), int(datos.get("anio", 0)), str(datos.get("hora", "00:00"))]
	_boton_bloqueo_tiempo.disabled = false
	_boton_bloqueo_tiempo.text = "Reanudar avance del tiempo" if _atmosfera.esta_bloqueado() else "Bloquear avance del tiempo"
	var velocidad_actual := _atmosfera.obtener_multiplicador_tiempo()
	for multiplicador in _botones_velocidad_tiempo:
		var boton_velocidad: Button = _botones_velocidad_tiempo[multiplicador]
		boton_velocidad.button_pressed = int(multiplicador) == velocidad_actual
		boton_velocidad.disabled = false
	var minutos_totales := int(floor(float(datos.get("hora_del_dia", 0.0)) * 60.0))
	_hora_spin.max_value = maxi(0, int(ceil(float(datos.get("horas_por_dia", 24.0)))) - 1)
	_hora_spin.value = int(floor(float(minutos_totales) / 60.0))
	_minuto_spin.value = minutos_totales % 60
	_anio_spin.value = int(datos.get("anio", 0))

	var estacion_actual := str(datos.get("estacion_id", ""))
	_estacion_selector.clear()
	for estacion_variant in _atmosfera.estaciones:
		if not estacion_variant is Dictionary:
			continue
		var estacion := estacion_variant as Dictionary
		var id := str(estacion.get("id", ""))
		var nombre := str(estacion.get("nombre", id))
		if id.is_empty():
			continue
		_estacion_selector.add_item(nombre)
		_estacion_selector.set_item_metadata(_estacion_selector.item_count - 1, id)
		if id == estacion_actual:
			_estacion_selector.select(_estacion_selector.item_count - 1)


func _registrar_accion_tiempo(ok: bool, mensaje: String) -> void:
	_estado_tiempo_accion.text = mensaje if ok else "No se pudo aplicar: " + mensaje
	_actualizar_panel_tiempo()


func _establecer_velocidad_tiempo(multiplicador: int) -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_multiplicador_tiempo(multiplicador)
	var mensaje := "Velocidad del reloj: ×%d." % multiplicador
	_registrar_accion_tiempo(ok, mensaje if ok else "Velocidad no admitida.")


func _alternar_bloqueo_tiempo() -> void:
	if _atmosfera == null:
		return
	if _atmosfera.esta_bloqueado():
		_atmosfera.desbloquear_tiempo()
		_registrar_accion_tiempo(true, "El tiempo vuelve a avanzar.")
	else:
		_atmosfera.bloquear_tiempo()
		_registrar_accion_tiempo(true, "El tiempo quedó bloqueado.")


func _aplicar_hora_tiempo() -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_hora_del_dia(int(_hora_spin.value), int(_minuto_spin.value))
	_registrar_accion_tiempo(ok, "Hora actualizada." if ok else "El calendario aún no está cargado.")


func _establecer_dia_tiempo() -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_dia()
	_registrar_accion_tiempo(ok, "Hora establecida al mediodía." if ok else "El calendario aún no está cargado.")


func _establecer_noche_tiempo() -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_noche()
	_registrar_accion_tiempo(ok, "Hora establecida a medianoche." if ok else "El calendario aún no está cargado.")


func _desplazar_tiempo(direccion: int) -> void:
	if _atmosfera == null:
		return
	var cantidad := maxi(1, int(_dias_spin.value)) * direccion
	var ok := _atmosfera.desplazar_dias(cantidad)
	var mensaje := "Se avanzaron %d días." % cantidad if cantidad > 0 else "Se retrocedieron %d días." % absi(cantidad)
	_registrar_accion_tiempo(ok, mensaje if ok else "El calendario aún no está cargado.")


func _aplicar_estacion_tiempo() -> void:
	if _atmosfera == null or _estacion_selector.selected < 0:
		return
	var id := str(_estacion_selector.get_item_metadata(_estacion_selector.selected))
	var ok := _atmosfera.establecer_estacion(id)
	_registrar_accion_tiempo(ok, "Estación actualizada." if ok else "No se pudo cambiar la estación.")


func _aplicar_anio_tiempo() -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_anio(int(_anio_spin.value))
	_registrar_accion_tiempo(ok, "Año actualizado." if ok else "El calendario aún no está cargado.")


func _al_calendario_disponible() -> void:
	_actualizar_panel_tiempo()


func _al_cambio_calendario(_dia_del_anio: int, _anio: int) -> void:
	_actualizar_panel_tiempo()


func _al_cambio_estacion(_estacion: Dictionary) -> void:
	_actualizar_panel_tiempo()
