extends Control
class_name GarumiHub

const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")
const TEXTO := Color(0.90, 0.79, 0.58, 1.0)
const SECUNDARIO := Color(0.65, 0.52, 0.35, 1.0)
const BORDE := Color(0.29, 0.19, 0.12, 1.0)

var _pagina_garumis: VBoxContainer
var _lista_vinculados: GridContainer
var _lista_amigos: GridContainer
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
	PIXEL_UI_THEME.apply(self, false)


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

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	columna.add_child(body)
	_pagina_garumis = VBoxContainer.new()
	_pagina_garumis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pagina_garumis.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pagina_garumis.add_theme_constant_override("separation", 5)
	body.add_child(_pagina_garumis)

	_lista_vinculados = GridContainer.new()
	_lista_vinculados.columns = 3
	_lista_vinculados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_vinculados.add_theme_constant_override("h_separation", 8)
	_lista_vinculados.add_theme_constant_override("v_separation", 8)
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
	_lista_amigos = GridContainer.new()
	_lista_amigos.columns = 3
	_lista_amigos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_amigos.add_theme_constant_override("h_separation", 8)
	_lista_amigos.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_lista_amigos)

	_detalle = VBoxContainer.new()
	_detalle.custom_minimum_size = Vector2(150, 0)
	_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detalle.alignment = BoxContainer.ALIGNMENT_CENTER
	_detalle.add_theme_constant_override("separation", 6)
	body.add_child(_detalle)

	_estado = Label.new()
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.add_theme_color_override("font_color", SECUNDARIO)
	_estado.add_theme_font_size_override("font_size", 10)
	columna.add_child(_estado)


func abrir_en_garumis() -> void:
	actualizar()


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


func _agregar_fila(contenedor: GridContainer, registro: Dictionary, estado_registro: String) -> void:
	var celda := VBoxContainer.new()
	celda.custom_minimum_size = Vector2(88, 0)
	celda.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	celda.add_theme_constant_override("separation", 3)
	contenedor.add_child(celda)

	var sprite := _crear_sprite_fila(registro)
	if sprite != null:
		var marco_sprite := PanelContainer.new()
		marco_sprite.custom_minimum_size = Vector2(88, 88)
		marco_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var estilo_marco: StyleBox = PIXEL_UI_THEME.slot_style(false)
		if estilo_marco != null:
			marco_sprite.add_theme_stylebox_override("panel", estilo_marco)
		celda.add_child(marco_sprite)
		var boton_sprite := TextureButton.new()
		boton_sprite.custom_minimum_size = Vector2(78, 78)
		boton_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		boton_sprite.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		boton_sprite.texture_normal = sprite.texture
		boton_sprite.ignore_texture_size = true
		boton_sprite.pressed.connect(_mostrar_detalle.bind(registro.duplicate(true), estado_registro))
		marco_sprite.add_child(boton_sprite)

	# El origen se muestra incluso si el Garumi no tiene un sprite cargado.
	var origen := _obtener_origen_garumi(registro)
	if not origen.is_empty():
		var etiqueta_origen := Label.new()
		etiqueta_origen.text = origen
		etiqueta_origen.custom_minimum_size = Vector2(88, 14)
		etiqueta_origen.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		etiqueta_origen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		etiqueta_origen.clip_text = true
		etiqueta_origen.tooltip_text = "Origen: " + origen
		etiqueta_origen.add_theme_font_size_override("font_size", 8)
		etiqueta_origen.add_theme_color_override("font_color", SECUNDARIO)
		celda.add_child(etiqueta_origen)

	if estado_registro == "Amigo":
		var boton_vincular := Button.new()
		boton_vincular.text = "Vincular"
		boton_vincular.custom_minimum_size = Vector2(84, 27)
		boton_vincular.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_estilizar_boton_accion(boton_vincular)
		boton_vincular.pressed.connect(_vincular_desde_amigos.bind(registro.duplicate(true)))
		celda.add_child(boton_vincular)


func _obtener_origen_garumi(registro: Dictionary) -> String:
	for clave in ["origen_nombre", "nombre_original", "origen", "linaje"]:
		var valor := str(registro.get(clave, "")).strip_edges()
		if not valor.is_empty():
			return valor
	return ""


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
		sprite.custom_minimum_size = Vector2(160, 160)
		sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_detalle.add_child(sprite)

	var boton_accion := Button.new()
	boton_accion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estilizar_boton_accion(boton_accion)
	if estado_registro == "Vinculado":
		boton_accion.text = "Quitar vínculo"
		boton_accion.pressed.connect(_quitar_vinculo.bind(registro.duplicate(true)))
	else:
		boton_accion.text = "Vincular"
		boton_accion.disabled = not GameState.puede_vincular_garumi()
		boton_accion.pressed.connect(_vincular_desde_amigos.bind(registro.duplicate(true)))
	_detalle.add_child(boton_accion)


func _estilizar_boton_accion(boton: Button) -> void:
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.custom_minimum_size = Vector2(0, 27)
	boton.clip_text = true
	boton.add_theme_font_size_override("font_size", 10)
	boton.add_theme_color_override("font_color", TEXTO)
	boton.add_theme_color_override("font_hover_color", Color(0.98, 0.88, 0.66, 1.0))
	boton.add_theme_color_override("font_pressed_color", TEXTO)
	PIXEL_UI_THEME.apply(boton, false)


func _quitar_vinculo(registro: Dictionary) -> void:
	var id_instancia := str(registro.get("garumi_instancia_id", "")).strip_edges()
	if id_instancia.is_empty():
		return
	var registro_amigo := registro.duplicate(true)
	registro_amigo.erase("health")
	registro_amigo.erase("max_health")
	registro_amigo.erase("vida")
	registro_amigo.erase("vida_maxima")
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
	var instancia_encontrada := false
	for nodo in get_tree().get_nodes_in_group("garumis"):
		if not is_instance_valid(nodo) or str(nodo.get("_garumi_instancia_id")).strip_edges() != id_instancia:
			continue
		instancia_encontrada = true
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
		# Si el amigo estaba guardado fuera de escena, reconstruir la instancia
		# desde el registro persistido para que el HUD y las teclas 1/2/3 lo controlen.
		if not instancia_encontrada:
			var escena_actual := get_tree().current_scene
			if is_instance_valid(escena_actual) and escena_actual.has_method("_restaurar_garumis_vinculados"):
				escena_actual.call_deferred("_restaurar_garumis_vinculados")
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
