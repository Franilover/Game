extends CanvasLayer
class_name GarumiBattleParty

## Selector y director del combate de Garumis vinculados.
## Un único aliado puede estar activo; al caer, se ofrece elegir otro.

const MAX_VINCULOS := 3
const INTERVALO_ATAQUE_ALIADO := 1.0
const INTERVALO_ATAQUE_RIVAL := 1.35
const INTERVALO_CURACION_ETERIUM := 0.55
const COSTO_CURACION_GARUMI := 5

var jugador: Node2D
var rival: Garumi
var disponibles: Array[Garumi] = []
var activo: Garumi
var _panel: PanelContainer
var _lista: VBoxContainer
var _estado: Label
var _panel_aliado: PanelContainer
var _panel_enemigo: PanelContainer
var _info_aliado: Label
var _info_enemigo: Label
var _vida_aliado: ProgressBar
var _vida_enemigo: ProgressBar
var _cooldown_aliado := 0.0
var _cooldown_rival := 0.0
var _cooldown_curacion_eterium := 0.0
var _seleccion_pendiente := false
var _forzar_disponible := false


func iniciar(nuevo_jugador: Node2D, nuevo_rival: Garumi) -> void:
	jugador = nuevo_jugador
	rival = nuevo_rival
	_disponibles_desde_vinculos()
	_guardar_garumis_antes_de_seleccionar()
	_cambiar_panel_garumis_hud(false)
	_crear_interfaz()
	_crear_marcos_combate()
	_seleccion_pendiente = not disponibles.is_empty()
	_actualizar_interfaz()
	if disponibles.is_empty():
		_estado.text = "No tienes Garumis vinculados disponibles. Puedes retirarte o luchar por tu cuenta."
		print("GarumiBattleParty: no hay Garumis vinculados disponibles.")
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
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -285.0
	_panel.offset_top = -165.0
	_panel.offset_right = 285.0
	_panel.offset_bottom = 165.0
	_panel.custom_minimum_size = Vector2(570.0, 330.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 100
	add_child(_panel)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.03, 0.025, 0.98)
	estilo.border_color = Color(0.78, 0.61, 0.34, 1.0)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 18.0
	estilo.content_margin_top = 18.0
	estilo.content_margin_right = 18.0
	estilo.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", estilo)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 7)
	_panel.add_child(_lista)


func _actualizar_interfaz() -> void:
	if is_instance_valid(activo):
		remove_from_group("modal_ui")
	else:
		add_to_group("modal_ui")
	if not is_instance_valid(_lista) or not is_instance_valid(_panel):
		return
	for hijo in _lista.get_children():
		hijo.queue_free()
	_panel.visible = not is_instance_valid(activo)
	var titulo := Label.new()
	titulo.text = "ELIGE TU GARUMI"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(0.96, 0.82, 0.56))
	_lista.add_child(titulo)
	_estado = Label.new()
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.add_theme_font_size_override("font_size", 12)
	_estado.add_theme_color_override("font_color", Color(0.82, 0.76, 0.66))
	_lista.add_child(_estado)
	if is_instance_valid(activo):
		_estado.text = "En combate: %s · Nv. %d" % [_nombre(activo), activo.nivel]
	elif not disponibles.is_empty():
		var instruccion := Label.new()
		instruccion.text = "Selecciona una criatura para entrar en la arena · teclas 1–3"
		instruccion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instruccion.add_theme_font_size_override("font_size", 12)
		_lista.add_child(instruccion)
		var tarjetas := HBoxContainer.new()
		tarjetas.alignment = BoxContainer.ALIGNMENT_CENTER
		tarjetas.add_theme_constant_override("separation", 12)
		tarjetas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_lista.add_child(tarjetas)
		for i in range(disponibles.size()):
			var garumi := disponibles[i]
			var tarjeta := Button.new()
			tarjeta.custom_minimum_size = Vector2(160.0, 175.0)
			tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tarjeta.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tarjeta.focus_mode = Control.FOCUS_ALL
			tarjeta.pressed.connect(seleccionar_garumi.bind(i))
			var tarjeta_estilo := StyleBoxFlat.new()
			tarjeta_estilo.bg_color = Color(0.10, 0.075, 0.05, 1.0)
			tarjeta_estilo.border_color = Color(0.42, 0.31, 0.19, 1.0)
			tarjeta_estilo.set_border_width_all(1)
			tarjeta_estilo.set_corner_radius_all(7)
			tarjeta.add_theme_stylebox_override("normal", tarjeta_estilo)
			var enfocado := StyleBoxFlat.new()
			enfocado.bg_color = Color(0.13, 0.095, 0.055, 1.0)
			enfocado.border_color = Color(0.96, 0.75, 0.38, 1.0)
			enfocado.set_border_width_all(2)
			enfocado.set_corner_radius_all(7)
			tarjeta.add_theme_stylebox_override("hover", enfocado)
			tarjeta.add_theme_stylebox_override("focus", enfocado)
			var contenido := VBoxContainer.new()
			contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
			contenido.alignment = BoxContainer.ALIGNMENT_CENTER
			contenido.add_theme_constant_override("separation", 8)
			tarjeta.add_child(contenido)
			var numero := Label.new()
			numero.text = "GARUMI %d" % (i + 1)
			numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			numero.add_theme_color_override("font_color", Color(0.96, 0.82, 0.56))
			numero.add_theme_font_size_override("font_size", 11)
			contenido.add_child(numero)
			var retrato := TextureRect.new()
			retrato.custom_minimum_size = Vector2(80.0, 80.0)
			retrato.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
			retrato.texture = _buscar_textura_garumi(garumi)
			contenido.add_child(retrato)
			var nombre := Label.new()
			nombre.text = _nombre(garumi)
			nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nombre.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
			nombre.add_theme_font_size_override("font_size", 14)
			contenido.add_child(nombre)
			var nivel := Label.new()
			nivel.text = "Nivel %d" % garumi.nivel
			nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nivel.add_theme_color_override("font_color", Color(0.75, 0.68, 0.56))
			nivel.add_theme_font_size_override("font_size", 12)
			contenido.add_child(nivel)
			tarjetas.add_child(tarjeta)
		_estado.text = "Solo un Garumi puede combatir a la vez."
	else:
		_estado.text = "No tienes otros Garumis disponibles."
	if _forzar_disponible and not is_instance_valid(activo):
		var boton_vinculo := Button.new()
		boton_vinculo.text = "Forzar vínculo"
		boton_vinculo.custom_minimum_size = Vector2(260.0, 32.0)
		boton_vinculo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		boton_vinculo.pressed.connect(_forzar_vinculo)
		_lista.add_child(boton_vinculo)
	var boton_retirarse := Button.new()
	boton_retirarse.text = "Retirarse del enfrentamiento"
	boton_retirarse.custom_minimum_size = Vector2(260.0, 30.0)
	boton_retirarse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton_retirarse.pressed.connect(_retirarse)
	_lista.add_child(boton_retirarse)
	if is_instance_valid(activo):
		_panel.visible = false
	_actualizar_marcos_combate()


func _crear_marcos_combate() -> void:
	_panel_aliado = _crear_marco_luchador("Aliado", true)
	_panel_aliado.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel_aliado.offset_left = 18.0
	_panel_aliado.offset_top = 18.0
	_panel_aliado.offset_right = 258.0
	_panel_aliado.offset_bottom = 126.0
	_panel_enemigo = _crear_marco_luchador("Enemigo", false)
	_panel_enemigo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel_enemigo.anchor_left = 1.0
	_panel_enemigo.anchor_right = 1.0
	_panel_enemigo.offset_left = -258.0
	_panel_enemigo.offset_top = 18.0
	_panel_enemigo.offset_right = -18.0
	_panel_enemigo.offset_bottom = 126.0
	add_child(_panel_aliado)
	add_child(_panel_enemigo)
	_actualizar_marcos_combate()


func _crear_marco_luchador(rotulo: String, es_aliado: bool) -> PanelContainer:
	var marco := PanelContainer.new()
	marco.name = "MarcoCombate" + rotulo
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.z_index = 20
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.03, 0.025, 0.92)
	estilo.border_color = Color(0.78, 0.61, 0.34, 0.95)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(7)
	estilo.content_margin_left = 9.0
	estilo.content_margin_top = 7.0
	estilo.content_margin_right = 9.0
	estilo.content_margin_bottom = 7.0
	marco.add_theme_stylebox_override("panel", estilo)
	var fila := HBoxContainer.new()
	fila.name = "Fila"
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(fila)
	var retrato := TextureRect.new()
	retrato.name = "Retrato"
	retrato.custom_minimum_size = Vector2(64.0, 64.0)
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(retrato)
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 4)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(columna)
	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = rotulo.to_upper()
	titulo.add_theme_font_size_override("font_size", 10)
	titulo.add_theme_color_override("font_color", Color(0.96, 0.82, 0.56))
	columna.add_child(titulo)
	var info := Label.new()
	info.name = "Info"
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	columna.add_child(info)
	var vida := ProgressBar.new()
	vida.name = "Vida"
	vida.custom_minimum_size = Vector2(0.0, 12.0)
	vida.show_percentage = false
	vida.min_value = 0
	vida.max_value = 100
	columna.add_child(vida)
	if es_aliado:
		_info_aliado = info
		_vida_aliado = vida
	else:
		_info_enemigo = info
		_vida_enemigo = vida
	return marco


func _actualizar_marcos_combate() -> void:
	if is_instance_valid(_panel_aliado):
		_panel_aliado.visible = is_instance_valid(activo)
		if is_instance_valid(activo):
			var retrato_aliado := _panel_aliado.get_node_or_null("Fila/Retrato") as TextureRect
			if retrato_aliado != null:
				retrato_aliado.texture = _buscar_textura_garumi(activo)
			if is_instance_valid(_info_aliado):
				_info_aliado.text = "%s · Nv. %d" % [_nombre(activo), activo.nivel]
			if is_instance_valid(_vida_aliado):
				_vida_aliado.max_value = maxi(1, activo.max_health)
				_vida_aliado.value = clampi(activo.health, 0, activo.max_health)
	if is_instance_valid(_panel_enemigo):
		_panel_enemigo.visible = is_instance_valid(rival) and rival.esta_enfrentamiento()
		if is_instance_valid(rival):
			var retrato_enemigo := _panel_enemigo.get_node_or_null("Fila/Retrato") as TextureRect
			if retrato_enemigo != null:
				retrato_enemigo.texture = _buscar_textura_garumi(rival)
			if is_instance_valid(_info_enemigo):
				_info_enemigo.text = "%s · Nv. %d" % [_nombre(rival), rival.nivel]
			if is_instance_valid(_vida_enemigo):
				_vida_enemigo.max_value = maxi(1, rival.max_health)
				_vida_enemigo.value = clampi(rival.health, 0, rival.max_health)


func _buscar_textura_garumi(nodo: Node) -> Texture2D:
	if not is_instance_valid(nodo):
		return null
	if nodo is Sprite2D and (nodo as Sprite2D).texture != null:
		return (nodo as Sprite2D).texture
	if nodo is AnimatedSprite2D:
		var animado := nodo as AnimatedSprite2D
		if animado.sprite_frames != null and animado.sprite_frames.has_animation(animado.animation):
			var textura := animado.sprite_frames.get_frame_texture(animado.animation, animado.frame)
			if textura != null:
				return textura
	if nodo is TextureRect and (nodo as TextureRect).texture != null:
		return (nodo as TextureRect).texture
	for hijo in nodo.get_children():
		var textura_hijo := _buscar_textura_garumi(hijo)
		if textura_hijo != null:
			return textura_hijo
	return null


func _guardar_garumis_antes_de_seleccionar() -> void:
	# Guardar todos los Garumis vinculados presentes, incluso si un guardado antiguo
	# contiene más de tres o alguno no puede entrar en esta selección.
	for nodo in get_tree().get_nodes_in_group("garumis"):
		if not is_instance_valid(nodo) or not nodo is Garumi:
			continue
		var garumi := nodo as Garumi
		if garumi == rival or not garumi.esta_vinculado():
			continue
		if garumi.has_method("esta_guardado") and not bool(garumi.call("esta_guardado")):
			if garumi.has_method("guardar_para_seleccion_combate"):
				garumi.call("guardar_para_seleccion_combate")
			else:
				garumi.call("_guardar_garumi")


func _cambiar_panel_garumis_hud(mostrar: bool) -> void:
	for nodo_hud in get_tree().get_nodes_in_group("hud"):
		if not is_instance_valid(nodo_hud):
			continue
		if nodo_hud.has_method("mostrar_panel_garumis_durante_combate"):
			nodo_hud.call("mostrar_panel_garumis_durante_combate", mostrar)
		if nodo_hud.has_method("establecer_estado_combate_garumi"):
			nodo_hud.call("establecer_estado_combate_garumi", not mostrar)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var tecla := event as InputEventKey
	if tecla.keycode == KEY_F and _forzar_disponible:
		_forzar_vinculo()
		get_viewport().set_input_as_handled()
		return
	if not _seleccion_pendiente or is_instance_valid(activo):
		return
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
	if not is_instance_valid(rival):
		finalizar()
		return
	if not rival.esta_enfrentamiento():
		return
	var puede_forzar := rival.puede_forzar_vinculo()
	if puede_forzar != _forzar_disponible:
		_forzar_disponible = puede_forzar
		_actualizar_interfaz()
	_actualizar_marcos_combate()
	if not is_instance_valid(activo):
		return
	if not activo.esta_vinculado() or not bool(activo.get("is_alive")):
		_derrotar_activo()
		return
	_cooldown_aliado -= delta
	_cooldown_rival -= delta
	_cooldown_curacion_eterium = maxf(0.0, _cooldown_curacion_eterium - delta)
	# Mantener 1, 2 o 3 pulsado canaliza Eterium del jugador para curar al Garumi activo.
	if _tecla_curacion_mantenida() and _cooldown_curacion_eterium <= 0.0:
		_curar_garumi_con_eterium()
	if _cooldown_aliado <= 0.0:
		_cooldown_aliado = INTERVALO_ATAQUE_ALIADO
		# El Garumi aliado deja de atacar al rival al llegar a 7 HP.
		# Si el siguiente golpe lo dejaría por debajo, se reduce para dejarlo exactamente en 7.
		if rival.health > 7 and activo.has_method("calcular_danio_ofensivo"):
			var danio := int(activo.call("calcular_danio_ofensivo", 100.0))
			danio = mini(maxi(0, danio), rival.health - 7)
			if danio > 0:
				rival.take_damage(danio, "Garumi vinculado: " + _nombre(activo))
			if is_instance_valid(rival) and rival.health <= 7:
				_estado.text = "¡Rival debilitado! Tu Garumi deja de atacar con 7 de vida."
	if _cooldown_rival <= 0.0:
		_cooldown_rival = INTERVALO_ATAQUE_RIVAL
		if activo.has_method("recibir_danio_combate"):
			var danio_rival := int(rival.calcular_danio_ofensivo(75.0))
			activo.call("recibir_danio_combate", maxi(1, danio_rival), rival)
			if not bool(activo.get("is_alive")):
				_derrotar_activo()


func _tecla_curacion_mantenida() -> bool:
	return (
		Input.is_key_pressed(KEY_1)
		or Input.is_key_pressed(KEY_2)
		or Input.is_key_pressed(KEY_3)
		or Input.is_key_pressed(KEY_KP_1)
		or Input.is_key_pressed(KEY_KP_2)
		or Input.is_key_pressed(KEY_KP_3)
	)


func _curar_garumi_con_eterium() -> void:
	if not is_instance_valid(activo) or activo.health >= activo.max_health:
		return
	if not is_instance_valid(jugador):
		return
	var eterium: Variant = jugador.get("eterium")
	if eterium == null or not eterium.has_method("gastar"):
		return
	if not bool(eterium.call("gastar", COSTO_CURACION_GARUMI)):
		return
	var cantidad_curacion := maxi(1, roundi(float(activo.max_health) * 0.20))
	var recuperada := int(activo.call("curar_con_eterium", cantidad_curacion))
	if recuperada <= 0:
		# Si no se pudo aplicar la curación, devolvemos el Eterium para no cobrar en vano.
		if eterium.has_method("restaurar"):
			eterium.call("restaurar", COSTO_CURACION_GARUMI)
		return
	_cooldown_curacion_eterium = INTERVALO_CURACION_ETERIUM
	if jugador.has_signal("mana_changed"):
		jugador.emit_signal("mana_changed", int(jugador.get("mana")), int(jugador.get("max_mana")))
	_actualizar_marcos_combate()


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
	_cambiar_panel_garumis_hud(true)
	if is_instance_valid(_panel):
		_panel.queue_free()
	if is_instance_valid(_panel_aliado):
		_panel_aliado.queue_free()
	if is_instance_valid(_panel_enemigo):
		_panel_enemigo.queue_free()
	queue_free()


func _nombre(garumi: Garumi) -> String:
	if not is_instance_valid(garumi):
		return "Garumi"
	var nombre := str(garumi.get("criatura_nombre")).strip_edges()
	return nombre if not nombre.is_empty() else str(garumi.name)
