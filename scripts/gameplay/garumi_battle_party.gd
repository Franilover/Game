extends CanvasLayer
class_name GarumiBattleParty

## Selector y director del combate de Garumis vinculados.
## Un único aliado puede estar activo; al caer, se ofrece elegir otro.

const MAX_VINCULOS := 3
const INTERVALO_ATAQUE_ALIADO := 1.0
const INTERVALO_ATAQUE_RIVAL := 1.35

var jugador: Node2D
var rival: Garumi
var disponibles: Array[Garumi] = []
var activo: Garumi
var _panel: PanelContainer
var _lista: VBoxContainer
var _estado: Label
var _cooldown_aliado := 0.0
var _cooldown_rival := 0.0
var _seleccion_pendiente := false
var _forzar_disponible := false


func iniciar(nuevo_jugador: Node2D, nuevo_rival: Garumi) -> void:
	jugador = nuevo_jugador
	rival = nuevo_rival
	_disponibles_desde_vinculos()
	_crear_interfaz()
	_seleccion_pendiente = not disponibles.is_empty()
	_actualizar_interfaz()
	if disponibles.is_empty():
		remove_from_group("modal_ui")
		_estado.text = "No tienes Garumis vinculados. Puedes retirarte o combatir por tu cuenta."
		print("GarumiBattleParty: el jugador no tiene vínculos disponibles para el combate.")
	else:
		print("GarumiBattleParty: combate iniciado; selecciona un Garumi con las teclas 1-3.")


func _disponibles_desde_vinculos() -> void:
	disponibles.clear()
	var game_state := get_node_or_null("/root/GameState")
	var orden_ids: Array[String] = []
	if game_state != null and game_state.has_method("obtener_garumis_vinculados"):
		var registros: Variant = game_state.call("obtener_garumis_vinculados")
		if registros is Array:
			for registro_variant in registros as Array:
				if registro_variant is Dictionary:
					var id := str((registro_variant as Dictionary).get("garumi_instancia_id", "")).strip_edges()
					if not id.is_empty():
						orden_ids.append(id)
	var encontrados: Array[Garumi] = []
	for nodo in get_tree().get_nodes_in_group("garumis"):
		if not nodo is Garumi or not is_instance_valid(nodo):
			continue
		var garumi := nodo as Garumi
		if not garumi.esta_vinculado() or garumi == rival or not bool(garumi.get("is_alive")):
			continue
		encontrados.append(garumi)
	for id in orden_ids:
		for garumi in encontrados:
			if str(garumi.obtener_datos_persistencia_vinculo().get("garumi_instancia_id", "")) == id and not disponibles.has(garumi):
				disponibles.append(garumi)
	for garumi in encontrados:
		if not disponibles.has(garumi):
			disponibles.append(garumi)
	if disponibles.size() > MAX_VINCULOS:
		disponibles.resize(MAX_VINCULOS)


func _crear_interfaz() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = PanelContainer.new()
	_panel.name = "GarumiBattleSelection"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(16.0, 16.0)
	_panel.custom_minimum_size = Vector2(300.0, 0.0)
	add_child(_panel)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.055, 0.045, 0.035, 0.96)
	estilo.border_color = Color(0.78, 0.61, 0.34, 0.95)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(5)
	estilo.content_margin_left = 14.0
	estilo.content_margin_top = 12.0
	estilo.content_margin_right = 14.0
	estilo.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", estilo)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	_panel.add_child(_lista)


func _actualizar_interfaz() -> void:
	if is_instance_valid(activo):
		remove_from_group("modal_ui")
	elif _seleccion_pendiente:
		add_to_group("modal_ui")
	if is_instance_valid(_panel):
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not is_instance_valid(_lista):
		return
	for hijo in _lista.get_children():
		hijo.queue_free()
	var titulo := Label.new()
	titulo.text = "COMBATE GARUMI"
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color(0.96, 0.82, 0.56))
	_lista.add_child(titulo)
	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.add_theme_font_size_override("font_size", 12)
	_lista.add_child(_estado)
	if is_instance_valid(activo):
		_estado.text = "En combate: %s · Nv. %d" % [_nombre(activo), activo.nivel]
		var ayuda := Label.new()
		ayuda.text = "Solo un Garumi puede combatir a la vez."
		ayuda.add_theme_font_size_override("font_size", 11)
		_lista.add_child(ayuda)
	elif _seleccion_pendiente:
		var instruccion := Label.new()
		instruccion.text = "Elige quién entra (teclas 1–3):"
		instruccion.add_theme_font_size_override("font_size", 12)
		_lista.add_child(instruccion)
		for i in range(disponibles.size()):
			var garumi := disponibles[i]
			var boton := Button.new()
			boton.text = "%d  %s  ·  Nv. %d" % [i + 1, _nombre(garumi), garumi.nivel]
			boton.custom_minimum_size = Vector2(260.0, 32.0)
			boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			boton.pressed.connect(seleccionar_garumi.bind(i))
			_lista.add_child(boton)
		_estado.text = "Solo puedes usar uno por combate." if not disponibles.is_empty() else "No tienes Garumis vinculados disponibles."
	if _forzar_disponible:
		var boton_vinculo := Button.new()
		boton_vinculo.text = "Forzar vínculo"
		boton_vinculo.custom_minimum_size = Vector2(260.0, 32.0)
		boton_vinculo.pressed.connect(_forzar_vinculo)
		_lista.add_child(boton_vinculo)
	var boton_retirarse := Button.new()
	boton_retirarse.text = "Retirarse del enfrentamiento"
	boton_retirarse.custom_minimum_size = Vector2(260.0, 30.0)
	boton_retirarse.pressed.connect(_retirarse)
	_lista.add_child(boton_retirarse)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not _seleccion_pendiente or is_instance_valid(activo):
		return
	var tecla := event as InputEventKey
	var codigo := tecla.keycode
	if codigo == KEY_KP_1:
		codigo = KEY_1
	elif codigo == KEY_KP_2:
		codigo = KEY_2
	elif codigo == KEY_KP_3:
		codigo = KEY_3
	elif codigo == KEY_KP_4:
		codigo = KEY_4
	elif codigo == KEY_KP_5:
		codigo = KEY_5
	var indice := codigo - KEY_1
	if indice >= 0 and indice < mini(MAX_VINCULOS, disponibles.size()):
		seleccionar_garumi(indice)
		get_viewport().set_input_as_handled()


func seleccionar_garumi(indice: int) -> void:
	if not _seleccion_pendiente or is_instance_valid(activo):
		return
	if indice < 0 or indice >= disponibles.size():
		return
	var elegido := disponibles[indice]
	if not is_instance_valid(elegido) or not elegido.esta_vinculado() or not bool(elegido.get("is_alive")):
		return
	activo = elegido
	_seleccion_pendiente = false
	_cooldown_aliado = 0.35
	_cooldown_rival = 0.8
	if activo.has_method("entrar_combate_vinculado"):
		activo.call("entrar_combate_vinculado", jugador, rival)
	_actualizar_interfaz()
	print("GarumiBattleParty: entra ", _nombre(activo), " (", indice + 1, ").")


func _process(delta: float) -> void:
	if not is_instance_valid(rival) or not rival.esta_enfrentamiento():
		return
	var puede_forzar := rival.puede_forzar_vinculo()
	if puede_forzar != _forzar_disponible:
		_forzar_disponible = puede_forzar
		_actualizar_interfaz()
	if not is_instance_valid(activo):
		return
	if not activo.esta_vinculado() or not bool(activo.get("is_alive")):
		_derrotar_activo()
		return
	_cooldown_aliado -= delta
	_cooldown_rival -= delta
	if _cooldown_aliado <= 0.0:
		_cooldown_aliado = INTERVALO_ATAQUE_ALIADO
		if activo.has_method("calcular_danio_ofensivo"):
			var danio := int(activo.call("calcular_danio_ofensivo", 100.0))
			rival.take_damage(maxi(1, danio), "Garumi vinculado: " + _nombre(activo))
	if _cooldown_rival <= 0.0:
		_cooldown_rival = INTERVALO_ATAQUE_RIVAL
		if activo.has_method("recibir_danio_combate"):
			var danio_rival := int(rival.calcular_danio_ofensivo(75.0))
			activo.call("recibir_danio_combate", maxi(1, danio_rival), rival)
			if not bool(activo.get("is_alive")):
				_derrotar_activo()


func _forzar_vinculo() -> void:
	if not is_instance_valid(rival) or not is_instance_valid(jugador):
		return
	if rival.puede_forzar_vinculo():
		rival.forzar_vinculo(jugador)


func _retirarse() -> void:
	if is_instance_valid(rival) and rival.esta_enfrentamiento():
		rival.finalizar_enfrentamiento()


func _derrotar_activo() -> void:
	if not is_instance_valid(activo):
		return
	var derrotado := activo
	disponibles.erase(derrotado)
	if derrotado.has_method("salir_combate_vinculado"):
		derrotado.call("salir_combate_vinculado", true)
	activo = null
	_seleccion_pendiente = not disponibles.is_empty()
	_actualizar_interfaz()
	if disponibles.is_empty():
		remove_from_group("modal_ui")
		_estado.text = "No quedan Garumis disponibles. Puedes seguir combatiendo por tu cuenta."
	print("GarumiBattleParty: ", _nombre(derrotado), " fue derrotado; puedes elegir otro Garumi.")


func finalizar() -> void:
	if is_instance_valid(activo) and activo.has_method("salir_combate_vinculado"):
		activo.call("salir_combate_vinculado", false)
	activo = null
	_seleccion_pendiente = false
	if is_instance_valid(_panel):
		_panel.queue_free()
	queue_free()


func _nombre(garumi: Garumi) -> String:
	if not is_instance_valid(garumi):
		return "Garumi"
	var nombre := str(garumi.get("criatura_nombre")).strip_edges()
	return nombre if not nombre.is_empty() else str(garumi.name)
