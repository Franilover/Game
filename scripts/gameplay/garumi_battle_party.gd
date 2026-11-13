extends CanvasLayer
class_name GarumiBattleParty

## Encuentro directo: el jugador combate y el Garumi salvaje conserva su salud
## únicamente mientras está siendo enfrentado. Los compañeros no participan.

const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")
const INTERVALO_ATAQUE_RIVAL := 1.35
const DISTANCIA_ATAQUE_RIVAL := 58.0

var jugador: Node2D
var rival: Garumi
var _panel: PanelContainer
var _nombre_rival: Label
var _vida_rival: ProgressBar
var _valor_vida_rival: Label
var _estado: Label
var _boton_vincular: Button
var _boton_huir: Button
var _cooldown_rival := 0.8
var _finalizando := false

func iniciar(nuevo_jugador: Node2D, nuevo_rival: Garumi) -> void:
	jugador = nuevo_jugador
	rival = nuevo_rival
	if not is_instance_valid(jugador) or not is_instance_valid(rival):
		finalizar()
		return
	_cambiar_estado_hud(true)
	_crear_interfaz()
	_actualizar_interfaz()
	print("GarumiBattleParty: encuentro directo iniciado; combate el jugador, no sus compañeros.")

func _crear_interfaz() -> void:
	# Barra horizontal superior con el nombre y la salud del rival.
	_panel = PanelContainer.new()
	_panel.name = "GarumiWildEncounter"
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = 16.0
	_panel.offset_top = 12.0
	_panel.offset_right = -16.0
	_panel.offset_bottom = 62.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.z_index = 80
	add_child(_panel)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(fila)

	_nombre_rival = Label.new()
	_nombre_rival.custom_minimum_size = Vector2(116.0, 0.0)
	_nombre_rival.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nombre_rival.add_theme_font_size_override("font_size", 14)
	_nombre_rival.add_theme_color_override("font_color", Color(0.96, 0.82, 0.56))
	fila.add_child(_nombre_rival)

	_vida_rival = ProgressBar.new()
	_vida_rival.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vida_rival.custom_minimum_size = Vector2(80.0, 14.0)
	_vida_rival.show_percentage = false
	fila.add_child(_vida_rival)

	_valor_vida_rival = Label.new()
	_valor_vida_rival.custom_minimum_size = Vector2(72.0, 0.0)
	_valor_vida_rival.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_valor_vida_rival.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_valor_vida_rival.add_theme_font_size_override("font_size", 11)
	fila.add_child(_valor_vida_rival)
	PIXEL_UI_THEME.apply(_panel, false)

	# Mensaje y acción de vínculo bajo la barra.
	var panel_acciones := VBoxContainer.new()
	panel_acciones.anchor_left = 0.5
	panel_acciones.anchor_top = 0.0
	panel_acciones.anchor_right = 0.5
	panel_acciones.anchor_bottom = 0.0
	panel_acciones.offset_left = -132.0
	panel_acciones.offset_top = 70.0
	panel_acciones.offset_right = 132.0
	panel_acciones.offset_bottom = 132.0
	panel_acciones.z_index = 80
	panel_acciones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_acciones)

	_estado = Label.new()
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.add_theme_font_size_override("font_size", 10)
	_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_acciones.add_child(_estado)

	_boton_vincular = Button.new()
	_boton_vincular.text = "Vincular Garumi (F)"
	_boton_vincular.custom_minimum_size = Vector2(0.0, 28.0)
	_boton_vincular.disabled = true
	_boton_vincular.visible = false
	_boton_vincular.pressed.connect(_forzar_vinculo)
	panel_acciones.add_child(_boton_vincular)
	PIXEL_UI_THEME.apply(_boton_vincular, false)

	# Botón de retirada fijo en la esquina inferior izquierda.
	_boton_huir = Button.new()
	_boton_huir.name = "HuirGarumi"
	_boton_huir.text = "Huir"
	_boton_huir.custom_minimum_size = Vector2(104.0, 34.0)
	_boton_huir.anchor_left = 0.0
	_boton_huir.anchor_top = 1.0
	_boton_huir.anchor_right = 0.0
	_boton_huir.anchor_bottom = 1.0
	_boton_huir.offset_left = 14.0
	_boton_huir.offset_top = -48.0
	_boton_huir.offset_right = 118.0
	_boton_huir.offset_bottom = -14.0
	_boton_huir.z_index = 90
	_boton_huir.pressed.connect(_huir)
	add_child(_boton_huir)
	PIXEL_UI_THEME.apply(_boton_huir, false)


func _process(delta: float) -> void:
	if _finalizando:
		return
	if not is_instance_valid(jugador) or not is_instance_valid(rival):
		finalizar()
		return
	if not rival.esta_enfrentamiento():
		finalizar()
		return
	_actualizar_interfaz()
	_cooldown_rival = maxf(0.0, _cooldown_rival - delta)
	if _cooldown_rival <= 0.0:
		_intentar_ataque_rival()

func _actualizar_interfaz() -> void:
	if not is_instance_valid(rival):
		return
	var nombre := str(rival.get("criatura_nombre")).strip_edges()
	if nombre.is_empty():
		nombre = rival.name
	_nombre_rival.text = nombre
	var maximo := maxi(1, rival.max_health)
	var actual := clampi(rival.health, 0, maximo)
	_vida_rival.max_value = maximo
	_vida_rival.value = actual
	_valor_vida_rival.text = "%d / %d" % [actual, maximo]
	var debilitado := rival.puede_forzar_vinculo()
	_boton_vincular.disabled = not debilitado
	_boton_vincular.visible = debilitado
	_estado.text = "Está debilitado. Acércate y establece el vínculo." if debilitado else "Atácalo con tus armas y Dones."

func _intentar_ataque_rival() -> void:
	if not is_instance_valid(jugador) or not is_instance_valid(rival):
		return
	if not jugador is Entity or not (jugador as Entity).is_alive:
		return
	if jugador.global_position.distance_to(rival.global_position) > DISTANCIA_ATAQUE_RIVAL:
		return
	_cooldown_rival = maxf(0.35, float(rival.datos.get("intervalo_ataque_combate", INTERVALO_ATAQUE_RIVAL)))
	var danio := maxi(1, rival.calcular_danio_ofensivo(75.0))
	(jugador as Entity).take_damage(danio, "Garumi salvaje: " + _nombre(rival))
	if is_instance_valid(_estado):
		_estado.text = "El Garumi salvaje te ha atacado."

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var tecla := event as InputEventKey
	if tecla.pressed and not tecla.echo and tecla.keycode == KEY_F:
		if is_instance_valid(rival) and rival.puede_forzar_vinculo():
			_forzar_vinculo()
			get_viewport().set_input_as_handled()

func _huir() -> void:
	if _finalizando:
		return
	# Retirarse cierra el enfrentamiento y restaura al Garumi salvaje sin vincularlo.
	if is_instance_valid(rival) and rival.esta_enfrentamiento():
		rival.finalizar_enfrentamiento()
	finalizar()


func _forzar_vinculo() -> void:
	if not is_instance_valid(rival) or not is_instance_valid(jugador):
		return
	if rival.puede_forzar_vinculo():
		rival.forzar_vinculo(jugador)

func _cambiar_estado_hud(en_combate: bool) -> void:
	for nodo_hud in get_tree().get_nodes_in_group("hud"):
		if not is_instance_valid(nodo_hud):
			continue
		if nodo_hud.has_method("mostrar_panel_garumis_durante_combate"):
			nodo_hud.call("mostrar_panel_garumis_durante_combate", not en_combate)
		if nodo_hud.has_method("establecer_estado_combate_garumi"):
			nodo_hud.call("establecer_estado_combate_garumi", en_combate)

func finalizar() -> void:
	if _finalizando:
		return
	_finalizando = true
	_cambiar_estado_hud(false)
	if is_instance_valid(_panel):
		_panel.queue_free()
	if is_instance_valid(_boton_huir):
		_boton_huir.queue_free()
	queue_free()
