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
var _boton_modo: Button
var _panel_construccion: PanelContainer
var _etiqueta_estado: Label


func _ready() -> void:
	_sprite_previo = Sprite2D.new()
	_sprite_previo.name = "VistaPreviaConstruccion"
	_sprite_previo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_previo.z_index = 100
	_sprite_previo.visible = false
	add_child(_sprite_previo)
	_crear_interfaz_construccion()
	_reconstruir_visual_decoraciones()
	call_deferred("_inicializar_terreno_dual")


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
	return {
		"version": _version_estado,
		"decoraciones": _decoraciones.duplicate(true)
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
	if is_inside_tree():
		_reconstruir_visual_decoraciones()


func establecer_decoraciones(decoraciones: Array) -> void:
	cargar_estado_guardado({"version": _version_estado, "decoraciones": decoraciones})


func agregar_decoracion(tipo: String, posicion: Vector2, giro: float = 0.0) -> bool:
	if not CATALOGO.has(tipo) or not obtener_limites().has_point(posicion):
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
	if indice < 0 or indice >= _decoraciones.size() or not obtener_limites().has_point(posicion):
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


func _seleccionar_tipo(tipo: String) -> void:
	if not CATALOGO.has(tipo):
		return
	_tipo_colocacion = tipo
	_indice_seleccionado = -1
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
	if event is not InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed or tecla.echo:
		return

	if tecla.keycode == KEY_B:
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
				_actualizar_estado_interfaz()
				_guardar_cambios_hogar()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _modo_construccion:
		return

	if event is InputEventMouseMotion:
		if _indice_arrastrado >= 0:
			mover_decoracion(_indice_arrastrado, get_global_mouse_position())
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
		var posicion := get_global_mouse_position()
		if not _tipo_colocacion.is_empty():
			if agregar_decoracion(_tipo_colocacion, posicion, _giro_colocacion):
				_guardar_cambios_hogar()
			_actualizar_sprite_previo()
		else:
			_indice_seleccionado = _buscar_decoracion(posicion)
			_indice_arrastrado = _indice_seleccionado
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
		_decoraciones[_indice_seleccionado]["giro"] = wrapf(float(_decoraciones[_indice_seleccionado]["giro"]) + PI * 0.5, 0.0, TAU)
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
	var posicion := get_global_mouse_position()
	_sprite_previo.position = to_local(posicion)
	_sprite_previo.rotation = _giro_colocacion
	_sprite_previo.visible = not _tipo_colocacion.is_empty()


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
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(jugador):
		estado["jugador"] = {"x": jugador.global_position.x, "y": jugador.global_position.y}
	GameState.world_state.flags["hogar_estado"] = estado
	if not GameState.active_save_id.is_empty():
		GameState.call_deferred("guardar_partida")
