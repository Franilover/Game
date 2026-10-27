extends Creature
class_name Garumi

signal vinculo_establecido(garumi: Garumi, jugador: Node, tipo: String)
signal propuesta_vinculo_rechazada(garumi: Garumi, jugador: Node)
signal salud_combate_cambiada(actual: int, maxima: int)
signal encuentro_iniciado(garumi: Garumi, jugador: Node)

const OPCION_OFRECER_VINCULO := 0
const OPCION_ENFRENTAR := 1
const OPCION_FORZAR_VINCULO := 2
const OPCION_RETIRARSE := 3

@export_category("Vínculo y combate")
@export_range(1, 1000, 1) var salud_combate_predeterminada: int = 40
@export_range(0.05, 0.75, 0.05) var umbral_vinculo_forzado: float = 0.25

var _enfrentamiento_activo: bool = false
var _vinculado: bool = false
var _tipo_vinculo: String = ""
var _jugador_del_encuentro: Node = null
var _menu_contextual: CanvasLayer = null


func _ready() -> void:
	super._ready()
	_normalizar_grupos_garumi()


func configurar(datos_garumi: Dictionary) -> void:
	var datos_separados := datos_garumi.duplicate(true)
	datos_separados["categoria_entidad"] = "garumi"
	if not datos_separados.has("asset_key"):
		datos_separados["asset_key"] = str(datos_separados.get("nombre", ""))
	super.configurar(datos_separados)
	_vinculado = bool(datos_separados.get("vinculado", false))
	_tipo_vinculo = str(datos_separados.get("tipo_vinculo", ""))


func activar_como_proxy() -> void:
	super.activar_como_proxy()
	_normalizar_grupos_garumi()


func _normalizar_grupos_garumi() -> void:
	remove_from_group("creatures")
	remove_from_group("damageable")
	add_to_group("garumis")


func es_garumi() -> bool:
	return true


func es_dialogable() -> bool:
	return not _vinculado


func can_interact(_jugador: Node) -> bool:
	return is_inside_tree() and not _vinculado


func get_interaction_priority() -> int:
	return 20


func get_interaction_distance() -> float:
	return 48.0


func get_interaction_text() -> String:
	if _vinculado:
		return ""
	if _enfrentamiento_activo and puede_forzar_vinculo():
		return "Garumi debilitado: interactuar"
	if _enfrentamiento_activo:
		return "Enfrentamiento: interactuar"
	return "Interactuar con " + (criatura_nombre if not criatura_nombre.is_empty() else name)


## Se invoca desde InteractionSystem al acercarse y usar la acción contextual.
func interact(jugador: Node) -> void:
	if jugador == null or not is_instance_valid(jugador) or _vinculado:
		return
	_mostrar_menu_contextual(jugador)


func _mostrar_menu_contextual(jugador: Node) -> void:
	if is_instance_valid(_menu_contextual):
		_menu_contextual.queue_free()

	# Capa propia para que el menú no dependa de la posición del cursor
	# ni de la transformación/cámara del mundo.
	_menu_contextual = CanvasLayer.new()
	_menu_contextual.name = "GarumiBondMenuLayer"
	_menu_contextual.layer = 120
	get_tree().root.add_child(_menu_contextual)

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_contextual.add_child(overlay)

	var fondo := ColorRect.new()
	fondo.name = "FondoOscuro"
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.025, 0.02, 0.015, 0.68)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(fondo)

	var panel := PanelContainer.new()
	panel.name = "GarumiBondMenu"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190.0, -145.0)
	panel.size = Vector2(380.0, 290.0)
	panel.custom_minimum_size = Vector2(380.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var estilo_panel := StyleBoxFlat.new()
	estilo_panel.bg_color = Color(0.08, 0.055, 0.035, 0.99)
	estilo_panel.border_color = Color(0.58, 0.43, 0.24, 1.0)
	estilo_panel.set_border_width_all(2)
	estilo_panel.set_corner_radius_all(6)
	estilo_panel.content_margin_left = 22.0
	estilo_panel.content_margin_top = 18.0
	estilo_panel.content_margin_right = 22.0
	estilo_panel.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", estilo_panel)
	overlay.add_child(panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	panel.add_child(columna)

	var titulo := Label.new()
	titulo.text = criatura_nombre if not criatura_nombre.strip_edges().is_empty() else name
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.add_theme_color_override("font_color", Color(0.93, 0.84, 0.65, 1.0))
	titulo.add_theme_font_size_override("font_size", 18)
	columna.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "¿Cómo quieres acercarte a este Garumi?"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitulo.add_theme_color_override("font_color", Color(0.72, 0.64, 0.52, 1.0))
	subtitulo.add_theme_font_size_override("font_size", 11)
	columna.add_child(subtitulo)

	var separador := HSeparator.new()
	columna.add_child(separador)

	if _enfrentamiento_activo:
		if puede_forzar_vinculo():
			_agregar_boton_menu_garumi(columna, "Forzar vínculo", OPCION_FORZAR_VINCULO, jugador)
		_agregar_boton_menu_garumi(columna, "Retirarse del enfrentamiento", OPCION_RETIRARSE, jugador)
	else:
		_agregar_boton_menu_garumi(columna, "Ofrecer vínculo", OPCION_OFRECER_VINCULO, jugador)
		_agregar_boton_menu_garumi(columna, "Enfrentar", OPCION_ENFRENTAR, jugador)

	var cerrar := _crear_boton_menu_garumi("Cerrar", -1)
	cerrar.pressed.connect(_al_cerrar_menu_contextual)
	columna.add_child(cerrar)


func _agregar_boton_menu_garumi(contenedor: VBoxContainer, texto: String, opcion: int, jugador: Node) -> void:
	var boton := _crear_boton_menu_garumi(texto, opcion)
	boton.pressed.connect(_al_seleccionar_opcion.bind(opcion, jugador))
	contenedor.add_child(boton)


func _crear_boton_menu_garumi(texto: String, opcion: int) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0.0, 38.0)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.focus_mode = Control.FOCUS_ALL
	boton.add_theme_color_override("font_color", Color(0.91, 0.83, 0.68, 1.0))
	boton.add_theme_color_override("font_hover_color", Color(0.98, 0.91, 0.75, 1.0))
	boton.add_theme_color_override("font_pressed_color", Color(0.98, 0.91, 0.75, 1.0))
	boton.add_theme_font_size_override("font_size", 13)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.105, 0.065, 1.0)
	normal.border_color = Color(0.38, 0.28, 0.16, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	boton.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.17, 0.095, 1.0)
	hover.border_color = Color(0.78, 0.61, 0.34, 1.0)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.075, 0.045, 1.0)
	boton.add_theme_stylebox_override("pressed", pressed)
	return boton


func _al_cerrar_menu_contextual() -> void:
	if is_instance_valid(_menu_contextual):
		_menu_contextual.queue_free()
	_menu_contextual = null


func _al_seleccionar_opcion(opcion: int, jugador: Node) -> void:
	if is_instance_valid(_menu_contextual):
		_menu_contextual.queue_free()
	_menu_contextual = null
	match opcion:
		OPCION_OFRECER_VINCULO:
			ofrecer_vinculo(jugador)
		OPCION_ENFRENTAR:
			iniciar_enfrentamiento(jugador)
		OPCION_FORZAR_VINCULO:
			forzar_vinculo(jugador)
		OPCION_RETIRARSE:
			finalizar_enfrentamiento()


func _al_ocultar_menu() -> void:
	_al_cerrar_menu_contextual()


func ofrecer_vinculo(jugador: Node) -> bool:
	if _vinculado or _enfrentamiento_activo or jugador == null or not is_instance_valid(jugador):
		return false
	var probabilidad := clampf(float(datos.get("aceptacion_vinculo", 0.5)), 0.0, 1.0)
	if _rng.randf() > probabilidad:
		propuesta_vinculo_rechazada.emit(self, jugador)
		print("Garumi: ", criatura_nombre, " rechaza la propuesta de vínculo.")
		return false
	_establecer_vinculo(jugador, "voluntario")
	return true


func iniciar_enfrentamiento(jugador: Node) -> bool:
	if _vinculado or _enfrentamiento_activo:
		return false
	if jugador == null or not is_instance_valid(jugador):
		return false

	_jugador_del_encuentro = jugador
	_enfrentamiento_activo = true
	max_health = maxi(1, int(datos.get("salud_combate", salud_combate_predeterminada)))
	vital_state.configurar(max_health, max_mana)
	restaurar_estado_vital(max_health, true)
	add_to_group("damageable")
	salud_combate_cambiada.emit(health, max_health)
	encuentro_iniciado.emit(self, jugador)
	return true


func puede_forzar_vinculo() -> bool:
	if _vinculado or not _enfrentamiento_activo or max_health <= 0:
		return false
	return float(health) / float(max_health) <= umbral_vinculo_forzado


## El daño común sigue sin afectar a los Garumis. Solo el daño durante un
## enfrentamiento explícito reduce su salud y nunca puede matarlos.
func take_damage(cantidad: int, origen: String = "desconocido") -> void:
	if not _enfrentamiento_activo or _vinculado or not is_alive:
		return
	if cantidad <= 0:
		return

	var salud_anterior := health
	health = maxi(1, health - cantidad)
	vital_state.health = health
	vital_state.is_alive = true
	_sync_desde_vital()
	if health != salud_anterior:
		health_changed.emit(health, max_health)
		salud_combate_cambiada.emit(health, max_health)
		print("Garumi: ", criatura_nombre, " recibe ", salud_anterior - health, " de daño (", origen, ") | ", health, "/", max_health)


func forzar_vinculo(jugador: Node) -> bool:
	if not puede_forzar_vinculo() or jugador == null or not is_instance_valid(jugador):
		return false
	_establecer_vinculo(jugador, "forzado")
	return true


func _establecer_vinculo(jugador: Node, tipo: String) -> void:
	_vinculado = true
	_tipo_vinculo = tipo
	_enfrentamiento_activo = false
	_jugador_del_encuentro = null
	remove_from_group("damageable")
	datos["vinculado"] = true
	datos["tipo_vinculo"] = tipo
	set_meta("vinculado", true)
	set_meta("tipo_vinculo", tipo)
	vinculo_establecido.emit(self, jugador, tipo)
	print("Garumi: vínculo ", tipo, " establecido con ", jugador.name)


func finalizar_enfrentamiento() -> void:
	_enfrentamiento_activo = false
	_jugador_del_encuentro = null
	remove_from_group("damageable")
	restaurar_estado_vital(max_health, true)


func esta_vinculado() -> bool:
	return _vinculado


func obtener_tipo_vinculo() -> String:
	return _tipo_vinculo


func esta_enfrentamiento() -> bool:
	return _enfrentamiento_activo
