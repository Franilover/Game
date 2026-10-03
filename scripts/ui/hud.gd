extends Control


var player: Node = null
var world_generator: Node = null

var mostrar_contexto_mundo: bool = false

var _tiempo_contexto: float = 0.0
var _ultima_tile_contexto: Vector2i = Vector2i(2147483647, 2147483647)

var location_panel: Control = null
var location_label: Label = null

var health_bar: ProgressBar = null
var health_value: Label = null

var stamina_bar: ProgressBar = null
var stamina_value: Label = null

var eterium_bar: ProgressBar = null
var eterium_value: Label = null
var heart_icon: Control = null

var interaction_prompt: PanelContainer = null
var interaction_prompt_action: Label = null
var interaction_panel: PanelContainer = null
var interaction_title: Label = null
var interaction_body: Label = null
var interaction_close: Button = null
var _interaction_panel_open: bool = false

var mission_panel: PanelContainer = null
var mission_list: VBoxContainer = null
var mission_hint: Label = null
var _mission_panel_open: bool = false

var discovery_notice: Label = null
var _discovery_notice_timer: float = 0.0


func _ready() -> void:
	add_to_group("hud")

	_buscar_nodos_hud()
	_preparar_location()
	_preparar_aviso_descubrimiento()
	_preparar_panel_interaccion()
	_preparar_panel_misiones()
	_conectar_senales_misiones()

	if location_panel:
		location_panel.visible = false

	if interaction_prompt:
		interaction_prompt.visible = false

	_buscar_player()
	_buscar_world_generator()

	if GameState.has_signal("descubrimiento_mundo"):
		GameState.descubrimiento_mundo.connect(_al_descubrimiento_mundo)

	print("HUD: iniciado.")

func _process(delta: float) -> void:
	if mostrar_contexto_mundo and not _interaction_panel_open and not _mission_panel_open:
		_tiempo_contexto += delta
		if _tiempo_contexto >= 0.5:
			_tiempo_contexto = 0.0
			_actualizar_contexto()
	else:
		_tiempo_contexto = 0.0

	if discovery_notice != null and discovery_notice.visible:
		_discovery_notice_timer -= delta
		if _discovery_notice_timer <= 0.0:
			discovery_notice.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed:
			return

		if key_event.echo:
			return

		if key_event.keycode == KEY_F3:
			mostrar_contexto_mundo = not mostrar_contexto_mundo

			if location_panel:
				location_panel.visible = mostrar_contexto_mundo

			if mostrar_contexto_mundo:
				_actualizar_contexto()

			get_viewport().set_input_as_handled()


func _buscar_nodos_hud() -> void:
	# Los elementos base del HUD viven en hud.tscn.
	# Se buscan por nombre para que el script no dependa de rutas rígidas.
	var nodo: Node = find_child("HealthBar", true, false)
	if nodo is ProgressBar:
		health_bar = nodo as ProgressBar

	nodo = find_child("HealthValue", true, false)
	if nodo is Label:
		health_value = nodo as Label

	nodo = find_child("StaminaBar", true, false)
	if nodo is ProgressBar:
		stamina_bar = nodo as ProgressBar

	nodo = find_child("StaminaValue", true, false)
	if nodo is Label:
		stamina_value = nodo as Label

	nodo = find_child("EteriumBar", true, false)
	if nodo is ProgressBar:
		eterium_bar = nodo as ProgressBar

	nodo = find_child("EteriumValue", true, false)
	if nodo is Label:
		eterium_value = nodo as Label

	nodo = find_child("HeartIcon", true, false)
	if nodo is Control:
		heart_icon = nodo as Control

	nodo = find_child("InteractionPrompt", true, false)
	if nodo is PanelContainer:
		interaction_prompt = nodo as PanelContainer

	nodo = find_child("Action", true, false)
	if nodo is Label:
		interaction_prompt_action = nodo as Label


func _preparar_aviso_descubrimiento() -> void:
	# Aviso creado por código para no añadir otra dependencia al .tscn.
	discovery_notice = Label.new()
	discovery_notice.name = "DiscoveryNotice"
	discovery_notice.visible = false
	discovery_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discovery_notice.z_index = 3000
	discovery_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discovery_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	discovery_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	discovery_notice.position = Vector2(-260.0, 28.0)
	discovery_notice.size = Vector2(520.0, 48.0)
	discovery_notice.add_theme_color_override(
		"font_color",
		Color(0.93, 0.84, 0.65, 1.0)
	)
	discovery_notice.add_theme_color_override(
		"font_outline_color",
		Color(0.075, 0.05, 0.035, 1.0)
	)
	discovery_notice.add_theme_constant_override("outline_size", 3)
	discovery_notice.add_theme_font_size_override("font_size", 16)
	add_child(discovery_notice)


func _al_descubrimiento_mundo(datos: Variant = null) -> void:
	if discovery_notice == null:
		return

	var texto := "Nuevo descubrimiento"
	if datos is Dictionary:
		texto = str(datos.get("nombre", datos.get("titulo", texto)))
	elif datos != null:
		texto = str(datos)

	discovery_notice.text = texto
	discovery_notice.visible = true
	_discovery_notice_timer = 4.0


func _preparar_location() -> void:
	var panel := find_child("LocationPanel", true, false)
	var label := find_child("LocationLabel", true, false)

	if panel is Control:
		location_panel = panel as Control

	if label is Label:
		location_label = label as Label

	if location_panel == null:
		print("HUD: no se encontró LocationPanel.")

	if location_label == null:
		print("HUD: no se encontró LocationLabel.")

func _buscar_primer_label(nodo: Node) -> Label:
	for child in nodo.get_children():
		if child is Label:
			return child as Label

		var encontrado := _buscar_primer_label(child)

		if encontrado != null:
			return encontrado

	return null


func _buscar_player() -> void:
	var encontrado := get_tree().get_first_node_in_group("player")

	if encontrado == null:
		return

	player = encontrado

	_conectar_senales_player()
	_actualizar_vida()
	_actualizar_stamina()
	_actualizar_eterium()
	_actualizar_ui_especie()


func _buscar_world_generator() -> void:
	var mundo := get_tree().current_scene

	if not is_instance_valid(mundo):
		return

	var encontrado := mundo.find_child(
		"WorldGenerator",
		true,
		false
	)

	if encontrado == null:
		return

	world_generator = encontrado

	print(
		"HUD: WorldGenerator asignado → ",
		world_generator.name
	)


func _conectar_senales_player() -> void:
	if not is_instance_valid(player):
		return

	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_al_recibir_cambio_vida):
			player.health_changed.connect(_al_recibir_cambio_vida)

	if player.has_signal("stamina_changed"):
		if not player.stamina_changed.is_connected(_al_recibir_cambio_stamina):
			player.stamina_changed.connect(_al_recibir_cambio_stamina)

	if player.has_signal("mana_changed"):
		if not player.mana_changed.is_connected(_al_recibir_cambio_mana):
			player.mana_changed.connect(_al_recibir_cambio_mana)

	if player.has_signal("fisiologia_changed"):
		if not player.fisiologia_changed.is_connected(_al_fisiologia_cambiada):
			player.fisiologia_changed.connect(_al_fisiologia_cambiada)


func _al_recibir_cambio_vida(actual: int, maximo: int) -> void:
	_actualizar_barra(
		health_bar,
		health_value,
		actual,
		maximo
	)


func _al_recibir_cambio_stamina(actual: float, maximo: float) -> void:
	_actualizar_barra_float(
		stamina_bar,
		stamina_value,
		actual,
		maximo
	)


func _al_recibir_cambio_mana(actual: int, maximo: int) -> void:
	_actualizar_barra(
		eterium_bar,
		eterium_value,
		actual,
		maximo
	)


func _al_fisiologia_cambiada(_vida_eterium_compartidos: bool) -> void:
	_actualizar_ui_especie()


func _actualizar_ui_especie() -> void:
	if not is_instance_valid(player):
		return

	var compartido := false
	if player.has_method("_eterium_vida_compartida"):
		compartido = bool(player.call("_eterium_vida_compartida"))

	var visible_vida := not compartido

	if health_bar != null:
		health_bar.visible = visible_vida
	if health_value != null:
		health_value.visible = visible_vida
	if heart_icon != null:
		heart_icon.visible = visible_vida

	if compartido:
		_actualizar_eterium()


func _actualizar_vida() -> void:
	var vida_actual := _obtener_entero(
		player,
		"health",
		0
	)

	var vida_maxima := _obtener_entero(
		player,
		"max_health",
		100
	)

	_actualizar_barra(
		health_bar,
		health_value,
		vida_actual,
		vida_maxima
	)


func _actualizar_stamina() -> void:
	var stamina_actual := _obtener_float(
		player,
		"stamina",
		0.0
	)

	var stamina_maxima := _obtener_float(
		player,
		"max_stamina",
		100.0
	)

	_actualizar_barra_float(
		stamina_bar,
		stamina_value,
		stamina_actual,
		stamina_maxima
	)


func _actualizar_eterium() -> void:
	var eterium_actual := _obtener_float(
		player,
		"mana",
		0.0
	)

	var eterium_maximo := _obtener_float(
		player,
		"max_mana",
		100.0
	)

	_actualizar_barra_float(
		eterium_bar,
		eterium_value,
		eterium_actual,
		eterium_maximo
	)


func _actualizar_barra(
	barra: ProgressBar,
	texto: Label,
	actual: int,
	maximo: int
) -> void:
	if barra == null:
		return

	barra.max_value = maximo
	barra.value = actual

	if texto != null:
		var nuevo_texto := str(actual) + " / " + str(maximo)
		if texto.text != nuevo_texto:
			texto.text = nuevo_texto


func _actualizar_barra_float(
	barra: ProgressBar,
	texto: Label,
	actual: float,
	maximo: float
) -> void:
	if barra == null:
		return

	barra.max_value = maximo
	barra.value = actual

	if texto != null:
		var nuevo_texto := str(roundi(actual)) + " / " + str(roundi(maximo))
		if texto.text != nuevo_texto:
			texto.text = nuevo_texto


func _actualizar_contexto() -> void:
	if not mostrar_contexto_mundo:
		if location_panel:
			location_panel.visible = false
		return

	if location_panel:
		location_panel.visible = true

	if location_label == null:
		return

	if not is_instance_valid(player):
		location_label.text = "Sin jugador"
		return

	if not is_instance_valid(world_generator):
		_buscar_world_generator()

	if not is_instance_valid(world_generator):
		location_label.text = "Sin WorldGenerator"
		return

	var tile_actual := Vector2i.ZERO
	if world_generator.has_method("get_tile_at"):
		tile_actual = world_generator.call("get_tile_at", player.global_position)

	if tile_actual == _ultima_tile_contexto and location_label.text != "RENDIMIENTO":
		return

	_ultima_tile_contexto = tile_actual

	var contexto := _obtener_contexto_mundo(player.global_position)
	var bioma := _obtener_nombre_contexto(contexto, "bioma")
	var ecosistema := _obtener_nombre_contexto(contexto, "ecosistema")
	var habitat := _obtener_nombre_contexto(contexto, "habitat")

	var tile := tile_actual

	var chunk_size := maxi(int(world_generator.get("chunk_size_tiles")), 1)
	var chunk := Vector2i(
		floori(float(tile.x) / float(chunk_size)),
		floori(float(tile.y) / float(chunk_size))
	)

	var reinos: Array[Dictionary] = []
	if world_generator.has_method("get_reinos_at_position"):
		var reinos_variant: Variant = world_generator.call(
			"get_reinos_at_position",
			player.global_position
		)
		if reinos_variant is Array:
			for reino_variant in reinos_variant:
				if reino_variant is Dictionary:
					reinos.append(reino_variant as Dictionary)

	var nombres_reinos: Array[String] = []
	for reino in reinos:
		var nombre_reino := str(reino.get("nombre", "")).strip_edges()
		if nombre_reino.is_empty():
			nombre_reino = str(reino.get("clave", "")).strip_edges()
		if not nombre_reino.is_empty() and nombre_reino not in nombres_reinos:
			nombres_reinos.append(nombre_reino)

	var reino_texto := "Sin reino"
	if not nombres_reinos.is_empty():
		reino_texto = " · ".join(nombres_reinos)

	var seed := str(world_generator.get("map_seed"))
	var version := str(WorldData.mundo.get("version", "—"))
	var supabase_estado := "Connected"
	if SupabaseClient.has_method("esta_conectado") and not SupabaseClient.call("esta_conectado"):
		supabase_estado = "Offline"

	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / float(maxi(fps, 1))
	var criaturas := get_tree().get_nodes_in_group("creatures").size()
	var props := get_tree().get_nodes_in_group("world_props").size()
	var entidades := criaturas + props

	var chunks_cargados := 0
	var terrain := world_generator.get_node_or_null("WorldTerrain")
	if terrain != null and terrain.has_method("chunks_cargados"):
		chunks_cargados = terrain.call("chunks_cargados").size()

	location_label.text = (
		"RENDIMIENTO\n"
		+ "FPS: " + str(fps) + "    Frame: " + ("%.1f" % frame_ms) + " ms\n\n"
		+ "MUNDO\n"
		+ "Reino: " + reino_texto + "\n"
		+ "Seed: " + seed + "\n"
		+ "World version: " + version + "\n"
		+ "Supabase: " + supabase_estado + "\n\n"
		+ "UBICACIÓN\n"
		+ "Posición: " + str(tile.x) + ", " + str(tile.y) + "\n"
		+ "Chunk: " + str(chunk.x) + ", " + str(chunk.y) + "\n"
		+ "Bioma: " + bioma + "\n"
		+ "Ecosistema: " + ecosistema + "\n"
		+ "Hábitat: " + habitat + "\n\n"
		+ "ENTIDADES\n"
		+ "Criaturas: " + str(criaturas) + "\n"
		+ "Props: " + str(props) + "\n"
		+ "Entidades: " + str(entidades) + "\n"
		+ "Chunks cargados: " + str(chunks_cargados)
	)

func _formatear_ambiente_efectivo(
	factores: Dictionary
) -> String:
	var partes: Array[String] = []

	var temperatura: Variant = _obtener_valor_factor(
		factores,
		"temperatura_media"
	)
	if temperatura != null:
		partes.append("T: " + _formatear_numero(float(temperatura)))

	var humedad: Variant = _obtener_valor_factor(
		factores,
		"humedad_relativa"
	)
	if humedad != null:
		partes.append(
			"H: " + _formatear_numero(
				float(humedad) * 100.0
			) + "%"
		)

	var agua: Variant = _obtener_valor_factor(
		factores,
		"disponibilidad_agua"
	)
	if agua != null:
		partes.append(
			"Agua: " + _formatear_numero(
				float(agua) * 100.0
			) + "%"
		)

	if partes.is_empty():
		return ""

	return "Ambiente: " + " · ".join(partes)


func _obtener_valor_factor(
	factores: Dictionary,
	clave: String
) -> Variant:
	var factor_variant: Variant = factores.get(
		clave,
		null
	)

	if not factor_variant is Dictionary:
		return null

	var factor: Dictionary = factor_variant as Dictionary

	if not factor.has("valor"):
		return null

	var valor: Variant = factor.get("valor")
	if valor == null:
		return null

	return valor


func _formatear_numero(
	valor: float
) -> String:
	return "%.2f" % valor


func _obtener_tiempo_mundo() -> Dictionary:
	if not is_instance_valid(world_generator):
		return {}

	var atmosfera = world_generator.get_node_or_null("WorldAtmosphere")
	if atmosfera == null or not atmosfera.has_method("obtener_tiempo"):
		return {}

	var resultado = atmosfera.call("obtener_tiempo")
	if resultado is Dictionary:
		return resultado

	return {}

func _obtener_contexto_mundo(posicion: Vector2) -> Dictionary:
	if not is_instance_valid(world_generator):
		return {}

	if world_generator.has_method("get_contexto_at"):
		var resultado = world_generator.call(
			"get_contexto_at",
			posicion
		)

		if resultado is Dictionary:
			return resultado

	var contexto: Dictionary = {}

	if world_generator.has_method("get_bioma_at"):
		contexto["bioma"] = world_generator.call(
			"get_bioma_at",
			posicion
		)

	if world_generator.has_method("get_ecosistema_at"):
		contexto["ecosistema"] = world_generator.call(
			"get_ecosistema_at",
			posicion
		)

	if world_generator.has_method("get_habitats_at"):
		var habitats = world_generator.call(
			"get_habitats_at",
			posicion
		)

		if habitats is Array and not habitats.is_empty():
			contexto["habitat"] = habitats[0]

	return contexto


func _obtener_nombre_contexto(
	contexto: Dictionary,
	clave: String
) -> String:
	var valor = contexto.get(clave, null)

	if valor == null:
		valor = contexto.get(
			clave + "_nombre",
			null
		)

	if valor == null:
		return "Desconocido"

	if valor is String:
		return valor

	if valor is Dictionary:
		if valor.has("nombre"):
			return str(valor["nombre"])

		if valor.has("name"):
			return str(valor["name"])

		if valor.has(clave + "_nombre"):
			return str(valor[clave + "_nombre"])

		return "Desconocido"

	if valor is Object:
		var nombre = valor.get("nombre")

		if nombre != null:
			return str(nombre)

		nombre = valor.get("name")

		if nombre != null:
			return str(nombre)

	return str(valor)


func _obtener_entero(
	objeto: Object,
	propiedad: String,
	valor_por_defecto: int
) -> int:
	if not is_instance_valid(objeto):
		return valor_por_defecto

	var valor = objeto.get(propiedad)

	if valor == null:
		return valor_por_defecto

	return int(valor)


func _obtener_float(
	objeto: Object,
	propiedad: String,
	valor_por_defecto: float
) -> float:
	if not is_instance_valid(objeto):
		return valor_por_defecto

	var valor = objeto.get(propiedad)

	if valor == null:
		return valor_por_defecto

	return float(valor)


func mostrar_interaccion(texto: String) -> void:
	if interaction_prompt == null:
		return

	if interaction_prompt_action != null:
		interaction_prompt_action.text = texto
	interaction_prompt.visible = true
	interaction_prompt.z_index = 1000


func ocultar_interaccion() -> void:
	if interaction_prompt == null:
		return

	interaction_prompt.visible = false


func _obtener_mission_manager() -> Node:
	return get_node_or_null("/root/MissionManager")


func _conectar_senales_misiones() -> void:
	var manager: Node = _obtener_mission_manager()
	if manager == null:
		return

	if not manager.misiones_cargadas.is_connected(_actualizar_panel_misiones):
		manager.misiones_cargadas.connect(_actualizar_panel_misiones)

	if not manager.progreso_actualizado.is_connected(_al_progreso_mision):
		manager.progreso_actualizado.connect(_al_progreso_mision)

	if not manager.mision_completada.is_connected(_al_mision_completada):
		manager.mision_completada.connect(_al_mision_completada)


func _al_progreso_mision(
	_mision_id: String,
	_objetivo_id: String,
	_progreso: int,
	_requerido: int
) -> void:
	if _mission_panel_open:
		_actualizar_panel_misiones()


func _al_mision_completada(_mision: Dictionary) -> void:
	if _mission_panel_open:
		_actualizar_panel_misiones()


func _preparar_panel_misiones() -> void:
	mission_panel = PanelContainer.new()
	mission_panel.name = "MissionPanel"
	mission_panel.visible = false
	mission_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mission_panel.z_index = 2500
	mission_panel.set_anchors_preset(Control.PRESET_CENTER)
	mission_panel.position = Vector2(-280.0, -210.0)
	mission_panel.size = Vector2(560.0, 420.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.055, 0.035, 0.98)
	style.border_color = Color(0.58, 0.43, 0.24, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	mission_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	mission_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "MISIONES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.93, 0.84, 0.65, 1.0))
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	mission_list = VBoxContainer.new()
	mission_list.name = "MissionList"
	mission_list.add_theme_constant_override("separation", 8)
	mission_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(mission_list)

	mission_hint = Label.new()
	mission_hint.text = "F · Cerrar    ESC · Cerrar"
	mission_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_hint.add_theme_color_override("font_color", Color(0.62, 0.53, 0.42, 1.0))
	mission_hint.add_theme_font_size_override("font_size", 10)
	column.add_child(mission_hint)

	add_child(mission_panel)


func _limpiar_lista_misiones() -> void:
	if mission_list == null:
		return

	for child in mission_list.get_children():
		child.queue_free()


func _actualizar_panel_misiones() -> void:
	if mission_list == null:
		return

	_limpiar_lista_misiones()

	var manager := _obtener_mission_manager()
	if manager == null:
		return

	var misiones: Array[Dictionary] = manager.obtener_misiones()
	if misiones.is_empty():
		var vacio := Label.new()
		vacio.text = "No hay misiones registradas."
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vacio.add_theme_color_override("font_color", Color(0.72, 0.64, 0.52, 1.0))
		mission_list.add_child(vacio)
		return

	for mision in misiones:
		var estado_mision: Dictionary = manager.obtener_estado_mision(
			str(mision.get("id", ""))
		)

		var estado := str(estado_mision.get("estado", "disponible"))
		var titulo_texto := str(mision.get("nombre", "Misión"))

		var bloque := VBoxContainer.new()
		bloque.add_theme_constant_override("separation", 3)
		mission_list.add_child(bloque)

		var encabezado := Label.new()
		var indicador := "✓" if estado == "completada" else "○"
		var estado_texto := "COMPLETADA" if estado == "completada" else ("EN CURSO" if estado == "activa" else "NO INICIADA")
		encabezado.text = indicador + "  " + titulo_texto + "  ·  " + estado_texto
		encabezado.add_theme_color_override(
			"font_color",
			Color(0.82, 0.92, 0.68, 1.0) if estado == "completada" else Color(0.9, 0.79, 0.58, 1.0)
		)
		encabezado.add_theme_font_size_override("font_size", 13)
		bloque.add_child(encabezado)

		var descripcion := str(mision.get("descripcion", "")).strip_edges()
		if not descripcion.is_empty():
			var desc_label := Label.new()
			desc_label.text = "   " + descripcion
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_label.add_theme_color_override("font_color", Color(0.70, 0.63, 0.51, 1.0))
			desc_label.add_theme_font_size_override("font_size", 10)
			bloque.add_child(desc_label)

		var objetivos_variant: Variant = estado_mision.get("objetivos", [])
		if objetivos_variant is Array:
			for objetivo_variant in objetivos_variant as Array:
				if not objetivo_variant is Dictionary:
					continue

				var objetivo := objetivo_variant as Dictionary
				var progreso := int(objetivo.get("progreso", 0))
				var requerido := maxi(1, int(objetivo.get("cantidad_requerida", 1)))
				var objetivo_completado := bool(objetivo.get("completado", false))
				var objetivo_indicador := "✓" if objetivo_completado else "•"
				var objetivo_texto := str(objetivo.get("descripcion", "Objetivo"))
				var linea := "   " + objetivo_indicador + " " + objetivo_texto
				linea += "  [" + str(progreso) + "/" + str(requerido) + "]"

				var objetivo_label := Label.new()
				objetivo_label.text = linea
				objetivo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				objetivo_label.add_theme_color_override(
					"font_color",
					Color(0.76, 0.88, 0.65, 1.0) if objetivo_completado else Color(0.78, 0.70, 0.57, 1.0)
				)
				objetivo_label.add_theme_font_size_override("font_size", 11)
				bloque.add_child(objetivo_label)


func mostrar_panel_misiones() -> void:
	if mission_panel == null:
		return

	if _interaction_panel_open:
		cerrar_panel_interaccion()

	_actualizar_panel_misiones()
	mission_panel.visible = true
	_mission_panel_open = true
	get_viewport().set_input_as_handled()


func cerrar_panel_misiones() -> void:
	if mission_panel == null:
		return

	mission_panel.visible = false
	_mission_panel_open = false


func _toggle_panel_misiones() -> void:
	if _mission_panel_open:
		cerrar_panel_misiones()
	else:
		mostrar_panel_misiones()


func esta_mostrando_panel_misiones() -> bool:
	return _mission_panel_open


func _preparar_panel_interaccion() -> void:
	interaction_panel = PanelContainer.new()
	interaction_panel.name = "InteractionPanel"
	interaction_panel.visible = false
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	interaction_panel.z_index = 2000

	interaction_panel.set_anchors_preset(Control.PRESET_CENTER)
	interaction_panel.position = Vector2(-230.0, -150.0)
	interaction_panel.size = Vector2(460.0, 300.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.055, 0.035, 0.98)
	style.border_color = Color(0.58, 0.43, 0.24, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	interaction_panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	interaction_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	interaction_title = Label.new()
	interaction_title.name = "Title"
	interaction_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_title.add_theme_color_override(
		"font_color",
		Color(0.93, 0.84, 0.65, 1.0)
	)
	interaction_title.add_theme_font_size_override(
		"font_size",
		18
	)
	column.add_child(interaction_title)

	interaction_body = Label.new()
	interaction_body.name = "Body"
	interaction_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	interaction_body.custom_minimum_size = Vector2(0, 160)
	interaction_body.add_theme_color_override(
		"font_color",
		Color(0.78, 0.70, 0.57, 1.0)
	)
	interaction_body.add_theme_font_size_override(
		"font_size",
		12
	)
	column.add_child(interaction_body)

	interaction_close = Button.new()
	interaction_close.name = "Close"
	interaction_close.text = "Cerrar"
	interaction_close.custom_minimum_size = Vector2(0, 34)
	interaction_close.focus_mode = Control.FOCUS_NONE
	interaction_close.pressed.connect(
		cerrar_panel_interaccion
	)
	column.add_child(interaction_close)

	add_child(interaction_panel)


func mostrar_panel_interaccion(datos: Dictionary) -> void:
	if interaction_panel == null:
		return

	var titulo: String = str(
		datos.get(
			"titulo",
			"Interacción"
		)
	)

	var accion: String = str(
		datos.get(
			"accion",
			""
		)
	)

	if not accion.is_empty():
		interaction_title.text = accion + " · " + titulo
	else:
		interaction_title.text = titulo

	var lineas: Array[String] = []

	var bioma: String = str(datos.get("bioma", "")).strip_edges()
	if not bioma.is_empty():
		lineas.append("Bioma: " + bioma)

	var ecosistema: String = str(datos.get("ecosistema", "")).strip_edges()
	if not ecosistema.is_empty():
		lineas.append("Ecosistema: " + ecosistema)

	var habitat: String = str(datos.get("habitat", "")).strip_edges()
	if not habitat.is_empty():
		lineas.append("Hábitat: " + habitat)

	var item_nombre: String = str(datos.get("item_nombre", "")).strip_edges()
	if not item_nombre.is_empty():
		lineas.append("Objeto relacionado: " + item_nombre)

	var descripcion: String = str(datos.get("descripcion", "")).strip_edges()
	if not descripcion.is_empty():
		lineas.append("")
		lineas.append(descripcion)

	if lineas.is_empty():
		lineas.append("No hay información adicional registrada.")

	interaction_body.text = "
".join(lineas)
	interaction_panel.visible = true
	_interaction_panel_open = true

	if interaction_close != null:
		interaction_close.grab_focus()


func cerrar_panel_interaccion() -> void:
	if interaction_panel == null:
		return

	interaction_panel.visible = false
	_interaction_panel_open = false

	if interaction_close != null:
		interaction_close.release_focus()


func esta_mostrando_panel_interaccion() -> bool:
	return _interaction_panel_open or _mission_panel_open


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F:
				_toggle_panel_misiones()
				get_viewport().set_input_as_handled()
				return

			if key_event.keycode == KEY_ESCAPE and _mission_panel_open:
				cerrar_panel_misiones()
				get_viewport().set_input_as_handled()
				return

	if not _interaction_panel_open:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_ESCAPE:
			cerrar_panel_interaccion()
			get_viewport().set_input_as_handled()
