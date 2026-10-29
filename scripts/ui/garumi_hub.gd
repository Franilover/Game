extends Control
class_name GarumiHub

const ENCYCLOPEDIA_SCRIPT: Script = preload("res://scripts/ui/encyclopedia.gd")
const TEXTO := Color(0.90, 0.79, 0.58, 1.0)
const SECUNDARIO := Color(0.65, 0.52, 0.35, 1.0)
const BORDE := Color(0.29, 0.19, 0.12, 1.0)

var _subtab: String = "garumis"
var _boton_garumis: Button
var _boton_garudex: Button
var _pagina_garumis: VBoxContainer
var _lista_vinculados: VBoxContainer
var _lista_amigos: VBoxContainer
var _garudex: Control
var _estado: Label
var _detalle: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_interfaz()
	if GameState.has_signal("garumis_vinculados_actualizados") and not GameState.garumis_vinculados_actualizados.is_connected(actualizar):
		GameState.garumis_vinculados_actualizados.connect(actualizar)
	if GameState.has_signal("garumis_amigos_actualizados") and not GameState.garumis_amigos_actualizados.is_connected(actualizar):
		GameState.garumis_amigos_actualizados.connect(actualizar)
	actualizar()


func _crear_interfaz() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 5)
	margen.add_theme_constant_override("margin_right", 5)
	margen.add_theme_constant_override("margin_bottom", 5)
	add_child(margen)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 0)
	margen.add_child(columna)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	columna.add_child(tabs)
	_boton_garumis = _crear_boton_tab("Garumis")
	_boton_garumis.button_pressed = true
	_boton_garumis.pressed.connect(_mostrar_garumis)
	tabs.add_child(_boton_garumis)
	_boton_garudex = _crear_boton_tab("Garudex")
	_boton_garudex.pressed.connect(_mostrar_garudex)
	tabs.add_child(_boton_garudex)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	columna.add_child(body)
	_pagina_garumis = VBoxContainer.new()
	_pagina_garumis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pagina_garumis.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pagina_garumis.add_theme_constant_override("separation", 5)
	body.add_child(_pagina_garumis)

	_lista_vinculados = VBoxContainer.new()
	_lista_vinculados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_vinculados.add_theme_constant_override("separation", 3)
	_pagina_garumis.add_child(_lista_vinculados)

	var separador := HSeparator.new()
	separador.add_theme_color_override("separator", BORDE)
	_pagina_garumis.add_child(separador)
	var titulo_amigos := Label.new()
	titulo_amigos.text = "AMIGOS"
	titulo_amigos.add_theme_color_override("font_color", TEXTO)
	titulo_amigos.add_theme_font_size_override("font_size", 11)
	_pagina_garumis.add_child(titulo_amigos)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pagina_garumis.add_child(scroll)
	_lista_amigos = VBoxContainer.new()
	_lista_amigos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_amigos.add_theme_constant_override("separation", 3)
	scroll.add_child(_lista_amigos)

	_detalle = VBoxContainer.new()
	_detalle.custom_minimum_size = Vector2(205, 0)
	_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detalle.alignment = BoxContainer.ALIGNMENT_CENTER
	_detalle.add_theme_constant_override("separation", 6)
	body.add_child(_detalle)

	_garudex = Control.new()
	_garudex.name = "GarudexCatalog"
	_garudex.set_script(ENCYCLOPEDIA_SCRIPT)
	_garudex.set("solo_garumis", true)
	_garudex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_garudex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_garudex.visible = false
	body.add_child(_garudex)
	_estado = Label.new()
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.add_theme_color_override("font_color", SECUNDARIO)
	_estado.add_theme_font_size_override("font_size", 10)
	columna.add_child(_estado)


func _crear_boton_tab(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.toggle_mode = true
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.custom_minimum_size = Vector2(0, 23)
	boton.add_theme_font_size_override("font_size", 11)
	boton.add_theme_color_override("font_color", SECUNDARIO)
	boton.add_theme_color_override("font_hover_color", TEXTO)
	boton.add_theme_color_override("font_pressed_color", TEXTO)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.075, 0.045, 0.95)
	normal.border_color = BORDE
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	boton.add_theme_stylebox_override("normal", normal)
	var activo := normal.duplicate() as StyleBoxFlat
	activo.bg_color = Color(0.28, 0.20, 0.12, 1)
	activo.border_color = Color(0.74, 0.62, 0.34, 1)
	activo.border_width_bottom = 2
	boton.add_theme_stylebox_override("pressed", activo)
	boton.add_theme_stylebox_override("hover", activo)
	boton.add_theme_stylebox_override("focus", activo)
	return boton


func abrir_en_garumis() -> void:
	_mostrar_garumis()


func _mostrar_garumis() -> void:
	_subtab = "garumis"
	_boton_garumis.button_pressed = true
	_boton_garudex.button_pressed = false
	_pagina_garumis.visible = true
	_detalle.visible = true
	_garudex.visible = false
	actualizar()


func _mostrar_garudex() -> void:
	_subtab = "garudex"
	_boton_garumis.button_pressed = false
	_boton_garudex.button_pressed = true
	_pagina_garumis.visible = false
	_detalle.visible = false
	_garudex.visible = true
	if _garudex.has_method("abrir_en_garumis"):
		_garudex.call("abrir_en_garumis")


func actualizar() -> void:
	if not is_instance_valid(_lista_vinculados):
		return
	for hijo in _lista_vinculados.get_children():
		hijo.queue_free()
	for hijo in _lista_amigos.get_children():
		hijo.queue_free()
	var vinculados: Array = GameState.call("obtener_garumis_vinculados") if GameState.has_method("obtener_garumis_vinculados") else []
	for registro in vinculados:
		if registro is Dictionary:
			_agregar_fila(_lista_vinculados, registro as Dictionary, "Vinculado")
	var amigos: Array = GameState.call("obtener_garumis_amigos") if GameState.has_method("obtener_garumis_amigos") else []
	for registro in amigos:
		if registro is Dictionary:
			_agregar_fila(_lista_amigos, registro as Dictionary, "Amigo")


func _agregar_fila(contenedor: VBoxContainer, registro: Dictionary, estado_registro: String) -> void:
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 5)
	contenedor.add_child(fila)

	var sprite := _crear_sprite_fila(registro)
	if sprite != null:
		var boton_sprite := TextureButton.new()
		boton_sprite.custom_minimum_size = Vector2(58, 58)
		boton_sprite.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		boton_sprite.texture_normal = sprite.texture
		boton_sprite.ignore_texture_size = true
		boton_sprite.pressed.connect(_mostrar_detalle.bind(registro.duplicate(true), estado_registro))
		fila.add_child(boton_sprite)

	if estado_registro == "Vinculado":
		var columna_vida := VBoxContainer.new()
		columna_vida.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columna_vida.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		columna_vida.add_theme_constant_override("separation", 2)
		fila.add_child(columna_vida)
		var salud := _obtener_salud_garumi(registro)
		var vida_maxima: int = salud["max"]
		var vida_actual: int = salud["actual"]
		var barra := ProgressBar.new()
		barra.min_value = 0
		barra.max_value = vida_maxima
		barra.value = vida_actual
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, 12)
		columna_vida.add_child(barra)
		var numeros_vida := Label.new()
		numeros_vida.text = "%d / %d" % [vida_actual, vida_maxima]
		numeros_vida.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numeros_vida.add_theme_font_size_override("font_size", 10)
		numeros_vida.add_theme_color_override("font_color", TEXTO)
		columna_vida.add_child(numeros_vida)
	else:
		var boton_vincular := Button.new()
		boton_vincular.text = "Vincular"
		boton_vincular.custom_minimum_size = Vector2(65, 30)
		boton_vincular.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		boton_vincular.add_theme_font_size_override("font_size", 10)
		boton_vincular.pressed.connect(_vincular_desde_amigos.bind(registro.duplicate(true)))
		fila.add_child(boton_vincular)


func _obtener_salud_garumi(registro: Dictionary) -> Dictionary:
	var id_instancia := str(registro.get("garumi_instancia_id", "")).strip_edges()
	for nodo in get_tree().get_nodes_in_group("garumis"):
		if not is_instance_valid(nodo):
			continue
		var id_nodo := str(nodo.get("_garumi_instancia_id")).strip_edges()
		if id_instancia.is_empty() or id_nodo != id_instancia:
			continue
		var maximo := maxi(1, int(nodo.get("max_health")))
		return {"actual": clampi(int(nodo.get("health")), 0, maximo), "max": maximo}
	var max_guardado := maxi(1, int(registro.get("max_health", registro.get("vida_maxima", 100))))
	return {"actual": clampi(int(registro.get("health", registro.get("vida", max_guardado))), 0, max_guardado), "max": max_guardado}


func _crear_sprite_fila(registro: Dictionary) -> TextureRect:
	var claves: Array[String] = []
	var asset_key := str(registro.get("asset_key", "")).strip_edges()
	var nombre := str(registro.get("nombre", registro.get("criatura_nombre", ""))).strip_edges()
	if not asset_key.is_empty():
		claves.append(asset_key)
	if not nombre.is_empty() and not claves.has(nombre):
		claves.append(nombre)

	for clave in claves:
		for ruta in [
			"res://assets/art/garumis/" + clave + ".png",
			"res://assets/art/garumis/" + clave + ".PNG",
			"res://assets/art/garumis/" + clave + ".svg",
			"res://assets/art/garumis/" + clave + ".SVG",
			"res://assets/art/creatures/" + clave + ".png",
			"res://assets/art/creatures/" + clave + ".PNG",
			"res://assets/art/creatures/" + clave + "/" + clave + ".png",
			"res://assets/art/creatures/" + clave + "/" + clave + ".PNG",
		]:
			if not ResourceLoader.exists(ruta):
				continue
			var textura := load(ruta) as Texture2D
			if textura == null:
				continue
			var sprite := TextureRect.new()
			sprite.texture = textura
			sprite.custom_minimum_size = Vector2(48, 48)
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			return sprite
	return null


func _agregar_mensaje(contenedor: VBoxContainer, mensaje: String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = mensaje
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.add_theme_color_override("font_color", SECUNDARIO)
	contenedor.add_child(etiqueta)


func _mostrar_detalle(registro: Dictionary, estado_registro: String) -> void:
	for hijo in _detalle.get_children():
		_detalle.remove_child(hijo)
		hijo.queue_free()

	var sprite := _crear_sprite_fila(registro)
	if sprite != null:
		sprite.custom_minimum_size = Vector2(190, 190)
		sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_detalle.add_child(sprite)

	var boton_accion := Button.new()
	boton_accion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_accion.add_theme_font_size_override("font_size", 11)
	if estado_registro == "Vinculado":
		boton_accion.text = "Quitar vínculo"
		boton_accion.pressed.connect(_quitar_vinculo.bind(registro.duplicate(true)))
	else:
		boton_accion.text = "Vincular"
		boton_accion.disabled = not GameState.puede_vincular_garumi()
		boton_accion.pressed.connect(_vincular_desde_amigos.bind(registro.duplicate(true)))
	_detalle.add_child(boton_accion)


func _quitar_vinculo(registro: Dictionary) -> void:
	var id_instancia := str(registro.get("garumi_instancia_id", "")).strip_edges()
	if id_instancia.is_empty():
		return
	var registro_amigo := registro.duplicate(true)
	var salud := _obtener_salud_garumi(registro)
	registro_amigo["health"] = salud["actual"]
	registro_amigo["max_health"] = salud["max"]
	GameState.guardar_garumi_amigo(registro_amigo)
	var vinculo_roto := false
	var instancia_en_escena := false
	for nodo in get_tree().get_nodes_in_group("garumis"):
		if not is_instance_valid(nodo):
			continue
		if str(nodo.get("_garumi_instancia_id")).strip_edges() != id_instancia:
			continue
		instancia_en_escena = true
		if nodo.has_method("romper_vinculo"):
			vinculo_roto = bool(nodo.call("romper_vinculo"))
		break
	if not instancia_en_escena:
		vinculo_roto = GameState.eliminar_garumi_vinculado(id_instancia)
	if vinculo_roto:
		actualizar()
		_mostrar_detalle(registro_amigo, "Amigo")
	else:
		GameState.eliminar_garumi_amigo(id_instancia)


func _vincular_desde_amigos(registro: Dictionary) -> void:
	if not GameState.puede_vincular_garumi():
		_estado.text = "Ya tienes 3 Garumis vinculados."
		return
	var id_instancia := str(registro.get("garumi_instancia_id", "")).strip_edges()
	if id_instancia.is_empty():
		return
	var registro_vinculado := registro.duplicate(true)
	registro_vinculado["vinculado"] = true
	if str(registro_vinculado.get("tipo_vinculo", "")).strip_edges().is_empty():
		registro_vinculado["tipo_vinculo"] = "amistad"

	# Activar el vínculo en la instancia del mundo cuando siga presente.
	var jugador := get_tree().get_first_node_in_group("player")
	for nodo in get_tree().get_nodes_in_group("garumis"):
		if not is_instance_valid(nodo) or str(nodo.get("_garumi_instancia_id")).strip_edges() != id_instancia:
			continue
		if is_instance_valid(jugador) and nodo.has_method("restaurar_vinculo_persistido"):
			var posicion: Vector2 = nodo.global_position if nodo is Node2D else Vector2.ZERO
			nodo.call("restaurar_vinculo_persistido", jugador, false, posicion)
			if nodo.has_method("obtener_datos_persistencia_vinculo"):
				var datos_actuales: Variant = nodo.call("obtener_datos_persistencia_vinculo")
				if datos_actuales is Dictionary and not (datos_actuales as Dictionary).is_empty():
					registro_vinculado = datos_actuales as Dictionary
		for nodo_hud in get_tree().get_nodes_in_group("hud"):
			if is_instance_valid(nodo_hud) and nodo_hud.has_method("registrar_garumi_restaurado"):
				nodo_hud.call("registrar_garumi_restaurado", nodo)
		break

	if GameState.guardar_garumi_vinculado(registro_vinculado):
		GameState.eliminar_garumi_amigo(id_instancia)
		_estado.text = ""
		actualizar()
		_mostrar_detalle(registro_vinculado, "Vinculado")


func mostrar_resultado_amistad_garumi(garumi: Node, exito: bool) -> void:
	var nombre := "Garumi"
	if is_instance_valid(garumi):
		nombre = str(garumi.get("criatura_nombre"))
	_estado.text = nombre + (" aceptó tu amistad." if exito else " no aceptó la propuesta de amistad.")


func _exit_tree() -> void:
	if is_instance_valid(GameState):
		if GameState.has_signal("garumis_vinculados_actualizados") and GameState.garumis_vinculados_actualizados.is_connected(actualizar):
			GameState.garumis_vinculados_actualizados.disconnect(actualizar)
		if GameState.has_signal("garumis_amigos_actualizados") and GameState.garumis_amigos_actualizados.is_connected(actualizar):
			GameState.garumis_amigos_actualizados.disconnect(actualizar)
