extends Node2D
class_name HogarZone
## Parcela privada asociada al guardado local activo.
## El terreno se dibuja en coordenadas de mundo; las decoraciones se serializan
## en GameState.world_state.flags y se editan desde el modo construcción.

const ANCHO := 2400.0
const ALTO := 1600.0
const TAMANO_CELDA := 32.0
const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

const CATALOGO := {
	"arbol": {"nombre": "Árbol", "ruta": "res://assets/art/props/Árbol.png"},
	"arbusto_mediano": {"nombre": "Arbusto", "ruta": "res://assets/art/props/Arbusto Mediano.png"},
	"arbusto_pequeno": {"nombre": "Arbusto pequeño", "ruta": "res://assets/art/props/Arbusto Pequeño.png"},
	"flor_azul": {"nombre": "Flor azul", "ruta": "res://assets/art/props/Flor Azul.png"},
	"flor_morada": {"nombre": "Flor morada", "ruta": "res://assets/art/props/Flor Morada.png"},
	"piedra_grande": {"nombre": "Piedra grande", "ruta": "res://assets/art/props/Piedra Grande.png"},
	"piedra_mediana": {"nombre": "Piedra mediana", "ruta": "res://assets/art/props/Piedra Mediana.png"},
	"piedra_pequena": {"nombre": "Piedra pequeña", "ruta": "res://assets/art/props/Piedra Pequeña.png"},
	"cama": {"nombre": "Cama", "ruta": "res://assets/art/places/Muebles/cama.png"},
	"cofre": {"nombre": "Cofre", "ruta": "res://assets/art/places/Muebles/cofre.png"},
	"horno": {"nombre": "Horno", "ruta": "res://assets/art/places/Muebles/horno.png"},
	"mesa": {"nombre": "Mesa", "ruta": "res://assets/art/places/Muebles/mesa.png"}
}

var _decoraciones: Array[Dictionary] = []
var _sprites_decoracion: Array[Sprite2D] = []
var _version_estado := 1

var _modo_construccion := false
var _tipo_colocacion := ""
var _giro_colocacion := 0.0
var _indice_seleccionado := -1
var _indice_arrastrado := -1
var _sprite_previo: Sprite2D
var _posicion_previa_valida := false
var _boton_modo: Button
var _panel_construccion: PanelContainer
var _etiqueta_estado: Label
var _etiqueta_entrada: Label
var _interior_abierto := false
var _interior_guardado_pendiente := false
var _tiempo_actualizacion_estado := 0.0


func _ready() -> void:
	_sprite_previo = Sprite2D.new()
	_sprite_previo.name = "VistaPreviaConstruccion"
	_sprite_previo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_previo.z_index = 100
	_sprite_previo.visible = false
	add_child(_sprite_previo)
	_crear_interfaz_construccion()
	_reconstruir_visual_decoraciones()
	_crear_prompt_entrada()
	var interior_inicial := _obtener_interior()
	if is_instance_valid(interior_inicial):
		interior_inicial.call("establecer_activo", false)
	call_deferred("_inicializar_terreno_dual")
	call_deferred("_restaurar_interior_guardado")


func _inicializar_terreno_dual() -> void:
	var terreno := get_node_or_null("WorldTerrain") as WorldTerrain
	if not is_instance_valid(terreno):
		push_error("HogarZone: falta WorldTerrain.")
		return

	# Hogar reutiliza el renderer Dual con una extensión fija, sin streaming compartido.
	terreno.position = Vector2(-ANCHO * 0.5, -ALTO * 0.5)
	terreno.configurar(20261113, 32, 32, WorldData)
	terreno.cargar_datos_mundo()
	await get_tree().process_frame
	if not is_instance_valid(terreno) or not is_instance_valid(terreno.visual):
		return

	terreno.visual.finalizar_preparacion_renderer()
	terreno.visual.comenzar_lote()

	var ancho_celdas := int(ANCHO / TAMANO_CELDA)
	var alto_celdas := int(ALTO / TAMANO_CELDA)
	for y in range(alto_celdas):
		for x in range(ancho_celdas):
			terreno.visual.set_zone(Vector2i(x, y), WorldTerrain.Zone.GRASS, 0, "Pradera")

	# Camino de tierra desde la casa hasta la entrada de la parcela.
	for y in range(19, 46):
		for x in range(35, 40):
			terreno.visual.set_zone(Vector2i(x, y), WorldTerrain.Zone.DIRT, 0, "Pradera")

	# Suelo de cultivo inicial, separado del camino.
	for y in range(30, 39):
		for x in range(45, 58):
			terreno.visual.set_zone(Vector2i(x, y), WorldTerrain.Zone.DIRT, 0, "Pradera")

	terreno.visual.terminar_lote()
	var orden: Array = []
	orden.resize(ancho_celdas * alto_celdas)
	for indice in range(orden.size()):
		orden[indice] = indice
	terreno.visual.marcar_region_generada_dirty(Vector2i.ZERO, orden, ancho_celdas, 0, orden.size())
	terreno.visual.flush()


func obtener_estado_guardado() -> Dictionary:
	var estado_interior: Dictionary = {}
	var interior := _obtener_interior()
	if is_instance_valid(interior) and interior.has_method("obtener_estado_guardado"):
		estado_interior = interior.call("obtener_estado_guardado")
	return {
		"version": _version_estado,
		"decoraciones": _decoraciones.duplicate(true),
		"interior_abierto": _interior_abierto,
		"interior_decoraciones": estado_interior
	}


func cargar_estado_guardado(estado: Dictionary) -> void:
	_version_estado = maxi(1, int(estado.get("version", 1)))
	var datos: Variant = estado.get("decoraciones", [])
	_decoraciones.clear()
	if datos is Array:
		for entrada in datos:
			if not entrada is Dictionary:
				continue
			var item := (entrada as Dictionary).duplicate(true)
			_decoraciones.append({
				"tipo": str(item.get("tipo", "decoracion")),
				"x": clampf(float(item.get("x", 0.0)), -ANCHO * 0.5, ANCHO * 0.5),
				"y": clampf(float(item.get("y", 0.0)), -ALTO * 0.5, ALTO * 0.5),
				"giro": float(item.get("giro", 0.0))
			})
	_interior_guardado_pendiente = bool(estado.get("interior_abierto", false))
	var interior := _obtener_interior()
	if is_instance_valid(interior):
		var estado_interior: Variant = estado.get("interior_decoraciones", {})
		if estado_interior is Dictionary:
			interior.call("cargar_estado_guardado", estado_interior as Dictionary)
	if is_inside_tree():
		_reconstruir_visual_decoraciones()


func establecer_decoraciones(decoraciones: Array) -> void:
	cargar_estado_guardado({"version": _version_estado, "decoraciones": decoraciones})


func agregar_decoracion(tipo: String, posicion: Vector2, giro: float = 0.0) -> bool:
	if not CATALOGO.has(tipo) or not _es_posicion_valida(tipo, posicion, giro):
		return false
	_decoraciones.append({
		"tipo": tipo,
		"x": posicion.x,
		"y": posicion.y,
		"giro": giro
	})
	_agregar_sprite_decoracion(_decoraciones.size() - 1)
	return true


func mover_decoracion(indice: int, posicion: Vector2) -> bool:
	if indice < 0 or indice >= _decoraciones.size():
		return false
	var item: Dictionary = _decoraciones[indice]
	var tipo := str(item.get("tipo", ""))
	var giro := float(item.get("giro", 0.0))
	if not _es_posicion_valida(tipo, posicion, giro):
		return false
	_decoraciones[indice]["x"] = posicion.x
	_decoraciones[indice]["y"] = posicion.y
	_actualizar_sprite_decoracion(indice)
	return true


func quitar_decoracion(indice: int) -> bool:
	if indice < 0 or indice >= _decoraciones.size():
		return false
	_decoraciones.remove_at(indice)
	if indice < _sprites_decoracion.size():
		var sprite: Sprite2D = _sprites_decoracion[indice]
		_sprites_decoracion.remove_at(indice)
		if is_instance_valid(sprite):
			sprite.queue_free()
	_reconstruir_visual_decoraciones()
	return true


func obtener_decoraciones() -> Array[Dictionary]:
	return _decoraciones.duplicate(true)


func obtener_limites() -> Rect2:
	return Rect2(-ANCHO * 0.5, -ALTO * 0.5, ANCHO, ALTO)


func _crear_interfaz_construccion() -> void:
	var capa := CanvasLayer.new()
	capa.name = "InterfazConstruccion"
	capa.layer = 30
	add_child(capa)

	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_PASS
	capa.add_child(raiz)

	_boton_modo = Button.new()
	_boton_modo.text = "Construir [B]"
	_boton_modo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_boton_modo.offset_left = -164.0
	_boton_modo.offset_top = 14.0
	_boton_modo.offset_right = -16.0
	_boton_modo.offset_bottom = 52.0
	_boton_modo.pressed.connect(_alternar_modo_construccion)
	PIXEL_UI_THEME.apply(_boton_modo)
	raiz.add_child(_boton_modo)

	_panel_construccion = PanelContainer.new()
	_panel_construccion.position = Vector2(16.0, 60.0)
	_panel_construccion.custom_minimum_size = Vector2(330.0, 0.0)
	_panel_construccion.visible = false
	PIXEL_UI_THEME.apply(_panel_construccion)
	raiz.add_child(_panel_construccion)

	var contenido := VBoxContainer.new()
	_panel_construccion.add_child(contenido)

	var titulo := Label.new()
	titulo.text = "CONSTRUCCIÓN"
	contenido.add_child(titulo)

	_etiqueta_estado = Label.new()
	_etiqueta_estado.text = "Selecciona un objeto para colocarlo"
	_etiqueta_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(_etiqueta_estado)

	var catalogo_ui := GridContainer.new()
	catalogo_ui.columns = 3
	contenido.add_child(catalogo_ui)

	for tipo in CATALOGO.keys():
		var boton := Button.new()
		boton.text = str(CATALOGO[tipo]["nombre"])
		boton.custom_minimum_size = Vector2(96.0, 34.0)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.pressed.connect(_seleccionar_tipo.bind(str(tipo)))
		PIXEL_UI_THEME.apply(boton)
		catalogo_ui.add_child(boton)

	var ayuda := Label.new()
	ayuda.text = "Clic: colocar/mover · R: girar · Supr: quitar · Clic derecho: cancelar · Esc: salir"
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenido.add_child(ayuda)


func _alternar_modo_construccion() -> void:
	_establecer_modo_construccion(not _modo_construccion)


func _establecer_modo_construccion(activo: bool) -> void:
	if _modo_construccion == activo:
		return
	_modo_construccion = activo
	_panel_construccion.visible = activo
	_boton_modo.text = "Salir construcción [B]" if activo else "Construir [B]"
	if activo:
		if not is_in_group("modal_ui"):
			add_to_group("modal_ui")
		_actualizar_estado_interfaz()
	else:
		if is_in_group("modal_ui"):
			remove_from_group("modal_ui")
		_tipo_colocacion = ""
		_indice_arrastrado = -1
		_indice_seleccionado = -1
		_sprite_previo.visible = false
		_actualizar_resaltado_seleccion()


func _seleccionar_tipo(tipo: String) -> void:
	if not CATALOGO.has(tipo):
		return
	_indice_arrastrado = -1
	_tipo_colocacion = tipo
	_indice_seleccionado = -1
	_actualizar_resaltado_seleccion()
	_giro_colocacion = 0.0
	_sprite_previo.texture = _obtener_textura(tipo)
	_sprite_previo.rotation = 0.0
	_sprite_previo.visible = true
	_sprite_previo.modulate = Color(1.0, 1.0, 1.0, 0.55)
	_actualizar_sprite_previo()
	_actualizar_estado_interfaz()


func _actualizar_estado_interfaz() -> void:
	if not is_instance_valid(_etiqueta_estado):
		return
	if not _tipo_colocacion.is_empty():
		_etiqueta_estado.text = "Colocando: " + str(CATALOGO[_tipo_colocacion]["nombre"])
	elif _indice_seleccionado >= 0 and _indice_seleccionado < _decoraciones.size():
		_etiqueta_estado.text = "Objeto seleccionado: " + str(CATALOGO.get(str(_decoraciones[_indice_seleccionado]["tipo"]), {}).get("nombre", "Objeto"))
	else:
		_etiqueta_estado.text = "Selecciona un objeto para colocarlo"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not (event is InputEventKey and (event as InputEventKey).echo):
		if _interior_abierto:
			var interior := _obtener_interior()
			if is_instance_valid(interior) and interior.has_method("esta_editando") and bool(interior.call("esta_editando")):
				return
		if _puede_usar_puerta():
			_establecer_interior(not _interior_abierto, true)
			get_viewport().set_input_as_handled()
			return

	# Finalizar el arrastre antes de la fase GUI, incluso si se suelta el ratón
	# encima del panel de construcción.
	if _modo_construccion and event is InputEventMouseButton:
		var raton := event as InputEventMouseButton
		if raton.button_index == MOUSE_BUTTON_LEFT and not raton.pressed and _indice_arrastrado >= 0:
			mover_decoracion(_indice_arrastrado, _obtener_posicion_ajustada(get_global_mouse_position()))
			_indice_arrastrado = -1
			_guardar_cambios_hogar()
			get_viewport().set_input_as_handled()
			return

	if event is not InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed or tecla.echo:
		return

	if tecla.keycode == KEY_B:
		if _interior_abierto:
			var interior := _obtener_interior()
			if is_instance_valid(interior):
				interior.call("alternar_editor")
		else:
			_alternar_modo_construccion()
		get_viewport().set_input_as_handled()
		return

	if not _modo_construccion:
		return

	match tecla.keycode:
		KEY_ESCAPE:
			_establecer_modo_construccion(false)
			get_viewport().set_input_as_handled()
		KEY_R:
			_girar_objeto()
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			if _indice_seleccionado >= 0 and quitar_decoracion(_indice_seleccionado):
				_indice_seleccionado = -1
				_actualizar_resaltado_seleccion()
				_actualizar_estado_interfaz()
				_guardar_cambios_hogar()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _modo_construccion:
		return

	if event is InputEventMouseMotion:
		if _indice_arrastrado >= 0:
			mover_decoracion(_indice_arrastrado, _obtener_posicion_ajustada(get_global_mouse_position()))
		elif not _tipo_colocacion.is_empty():
			_actualizar_sprite_previo()
		return

	if event is not InputEventMouseButton:
		return
	var raton := event as InputEventMouseButton

	if raton.button_index == MOUSE_BUTTON_RIGHT and raton.pressed:
		_tipo_colocacion = ""
		_indice_arrastrado = -1
		_sprite_previo.visible = false
		_actualizar_estado_interfaz()
		get_viewport().set_input_as_handled()
		return

	if raton.button_index != MOUSE_BUTTON_LEFT:
		return

	if raton.pressed:
		var posicion := _obtener_posicion_ajustada(get_global_mouse_position())
		if not _tipo_colocacion.is_empty():
			if agregar_decoracion(_tipo_colocacion, posicion, _giro_colocacion):
				_guardar_cambios_hogar()
			_actualizar_sprite_previo()
		else:
			_indice_seleccionado = _buscar_decoracion(get_global_mouse_position())
			_indice_arrastrado = _indice_seleccionado
			_actualizar_resaltado_seleccion()
			_actualizar_estado_interfaz()
	else:
		if _indice_arrastrado >= 0:
			_indice_arrastrado = -1
			_guardar_cambios_hogar()
		get_viewport().set_input_as_handled()


func _girar_objeto() -> void:
	if not _tipo_colocacion.is_empty():
		_giro_colocacion = wrapf(_giro_colocacion + PI * 0.5, 0.0, TAU)
		_sprite_previo.rotation = _giro_colocacion
		_actualizar_sprite_previo()
	elif _indice_seleccionado >= 0 and _indice_seleccionado < _decoraciones.size():
		var item: Dictionary = _decoraciones[_indice_seleccionado]
		var nuevo_giro := wrapf(float(item.get("giro", 0.0)) + PI * 0.5, 0.0, TAU)
		var posicion := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
		if _es_posicion_valida(str(item.get("tipo", "")), posicion, nuevo_giro):
			_decoraciones[_indice_seleccionado]["giro"] = nuevo_giro
			_actualizar_sprite_decoracion(_indice_seleccionado)
			_guardar_cambios_hogar()


func _buscar_decoracion(posicion_global: Vector2) -> int:
	for indice in range(_sprites_decoracion.size() - 1, -1, -1):
		var sprite: Sprite2D = _sprites_decoracion[indice]
		if not is_instance_valid(sprite) or sprite.texture == null:
			continue
		var local := sprite.to_local(posicion_global)
		var tamano := sprite.texture.get_size() * sprite.scale
		if Rect2(-tamano * 0.5, tamano).has_point(local):
			return indice
	return -1


func _actualizar_sprite_previo() -> void:
	if not is_instance_valid(_sprite_previo):
		return
	var posicion := _obtener_posicion_ajustada(get_global_mouse_position())
	_posicion_previa_valida = not _tipo_colocacion.is_empty() and _es_posicion_valida(_tipo_colocacion, posicion, _giro_colocacion)
	_sprite_previo.position = to_local(posicion)
	_sprite_previo.rotation = _giro_colocacion
	_sprite_previo.modulate = Color(1.0, 1.0, 1.0, 0.65) if _posicion_previa_valida else Color(1.0, 0.35, 0.3, 0.65)
	_sprite_previo.visible = not _tipo_colocacion.is_empty()


func _obtener_posicion_ajustada(posicion_global: Vector2) -> Vector2:
	var local := to_local(posicion_global)
	var origen := Vector2(-ANCHO * 0.5, -ALTO * 0.5)
	var celda := Vector2i(
		floori((local.x - origen.x) / TAMANO_CELDA),
		floori((local.y - origen.y) / TAMANO_CELDA)
	)
	return origen + Vector2(celda) * TAMANO_CELDA + Vector2.ONE * TAMANO_CELDA * 0.5


func _es_posicion_valida(tipo: String, posicion: Vector2, giro: float = 0.0) -> bool:
	if not CATALOGO.has(tipo):
		return false
	var textura := _obtener_textura(tipo)
	if textura == null:
		return false
	var extents := textura.get_size() * 0.5
	var coseno := absf(cos(giro))
	var seno := absf(sin(giro))
	var extents_rotados := Vector2(
		extents.x * coseno + extents.y * seno,
		extents.x * seno + extents.y * coseno
	)
	var limites := obtener_limites()
	return (
		posicion.x - extents_rotados.x >= limites.position.x
		and posicion.x + extents_rotados.x <= limites.end.x
		and posicion.y - extents_rotados.y >= limites.position.y
		and posicion.y + extents_rotados.y <= limites.end.y
	)


func _actualizar_resaltado_seleccion() -> void:
	for indice in range(_sprites_decoracion.size()):
		var sprite: Sprite2D = _sprites_decoracion[indice]
		if not is_instance_valid(sprite):
			continue
		sprite.modulate = Color("#FFE3A3") if indice == _indice_seleccionado else Color.WHITE


func _reconstruir_visual_decoraciones() -> void:
	for sprite in _sprites_decoracion:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_sprites_decoracion.clear()
	for indice in range(_decoraciones.size()):
		_agregar_sprite_decoracion(indice)


func _agregar_sprite_decoracion(indice: int) -> void:
	if indice < 0 or indice >= _decoraciones.size():
		return
	var item: Dictionary = _decoraciones[indice]
	var tipo := str(item.get("tipo", ""))
	var textura := _obtener_textura(tipo)
	if textura == null:
		_sprites_decoracion.append(null)
		return
	var sprite := Sprite2D.new()
	sprite.name = "Decoracion_" + str(indice)
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_sprites_decoracion.append(sprite)
	_actualizar_sprite_decoracion(indice)
	_actualizar_resaltado_seleccion()


func _actualizar_sprite_decoracion(indice: int) -> void:
	if indice < 0 or indice >= _decoraciones.size() or indice >= _sprites_decoracion.size():
		return
	var sprite: Sprite2D = _sprites_decoracion[indice]
	if not is_instance_valid(sprite):
		return
	var item: Dictionary = _decoraciones[indice]
	sprite.position = Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
	sprite.rotation = float(item.get("giro", 0.0))
	sprite.z_index = clampi(4 + int((sprite.position.y + ALTO * 0.5) / TAMANO_CELDA), 4, 60)


func _obtener_textura(tipo: String) -> Texture2D:
	if not CATALOGO.has(tipo):
		return null
	return load(str(CATALOGO[tipo]["ruta"])) as Texture2D


func _guardar_cambios_hogar() -> void:
	var estado := obtener_estado_guardado()
	var jugador := _obtener_jugador()
	if is_instance_valid(jugador):
		estado["jugador"] = {"x": jugador.global_position.x, "y": jugador.global_position.y}
	GameState.world_state.flags["hogar_estado"] = estado
	if not GameState.active_save_id.is_empty():
		GameState.call_deferred("guardar_partida")



func _process(delta: float) -> void:
	_tiempo_actualizacion_estado += delta
	var jugador := _obtener_jugador()
	if is_instance_valid(_etiqueta_entrada):
		var cerca := _puede_usar_puerta()
		_etiqueta_entrada.visible = cerca
		_etiqueta_entrada.text = "E · Salir de la casa" if _interior_abierto else "E · Entrar a la casa"
	if _tiempo_actualizacion_estado >= 0.35 and is_instance_valid(jugador):
		_tiempo_actualizacion_estado = 0.0
		var estado := obtener_estado_guardado()
		estado["jugador"] = {"x": jugador.global_position.x, "y": jugador.global_position.y}
		GameState.world_state.flags["hogar_estado"] = estado


func _crear_prompt_entrada() -> void:
	var raiz := get_node_or_null("InterfazConstruccion/Raiz") as Control
	if not is_instance_valid(raiz):
		return
	_etiqueta_entrada = Label.new()
	_etiqueta_entrada.name = "PromptEntradaCasa"
	_etiqueta_entrada.text = "E · Entrar a la casa"
	_etiqueta_entrada.visible = false
	_etiqueta_entrada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_entrada.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_etiqueta_entrada.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_etiqueta_entrada.offset_left = -130.0
	_etiqueta_entrada.offset_top = -76.0
	_etiqueta_entrada.offset_right = 130.0
	_etiqueta_entrada.offset_bottom = -48.0
	_etiqueta_entrada.add_theme_color_override("font_color", Color("#F1E2C7"))
	_etiqueta_entrada.add_theme_color_override("font_outline_color", Color("#33251D"))
	_etiqueta_entrada.add_theme_constant_override("outline_size", 4)
	raiz.add_child(_etiqueta_entrada)


func _obtener_jugador() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _puede_usar_puerta() -> bool:
	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		return false
	var objetivo := Vector2(4000.0, 144.0) if _interior_abierto else Vector2(0.0, -160.0)
	return jugador.global_position.distance_to(objetivo) <= 68.0


func _obtener_interior() -> Node2D:
	return get_node_or_null("InteriorCasa") as Node2D


func _establecer_interior(activo: bool, mover_jugador: bool) -> void:
	if _interior_abierto == activo:
		return
	_interior_abierto = activo
	_establecer_modo_construccion(false)
	var interior := _obtener_interior()
	if is_instance_valid(interior):
		interior.visible = activo
		interior.set_process(activo)
		interior.set_process_unhandled_input(activo)
		if interior.has_method("establecer_activo"):
			interior.call("establecer_activo", activo)
	var terreno := get_node_or_null("WorldTerrain") as Node2D
	var casa := get_node_or_null("Casa") as CanvasItem
	var limites := get_node_or_null("Limites") as CanvasItem
	if is_instance_valid(terreno):
		terreno.visible = not activo
	if is_instance_valid(casa):
		casa.visible = not activo
	if is_instance_valid(limites):
		limites.visible = not activo
	for sprite in _sprites_decoracion:
		if is_instance_valid(sprite):
			sprite.visible = not activo
	_boton_modo.visible = not activo
	if mover_jugador:
		var jugador := _obtener_jugador()
		if is_instance_valid(jugador):
			jugador.global_position = Vector2(4000.0, 0.0) if activo else Vector2(0.0, -96.0)
	_actualizar_limites_camara_interior(activo)
	if mover_jugador:
		_guardar_cambios_hogar()


func _actualizar_limites_camara_interior(activo: bool) -> void:
	var camara := get_viewport().get_camera_2d()
	if not is_instance_valid(camara):
		return
	if activo:
		camara.limit_left = 3712
		camara.limit_right = 4288
		camara.limit_top = -192
		camara.limit_bottom = 192
	else:
		camara.limit_left = -1200
		camara.limit_right = 1200
		camara.limit_top = -800
		camara.limit_bottom = 800
	camara.limit_enabled = true


func _restaurar_interior_guardado() -> void:
	if not _interior_guardado_pendiente:
		return
	_interior_guardado_pendiente = false
	_establecer_interior(true, false)
