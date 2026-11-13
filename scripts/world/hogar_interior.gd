extends Node2D
## Interior privado de Hogar. Usa el suelo del proyecto y guarda sus muebles
## por separado de las decoraciones exteriores.

const ANCHO := 560.0
const ALTO := 352.0
const CELDA := 32.0
const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const CHEST_UI_SCRIPT = preload("res://scripts/ui/hogar_chest_inventory.gd")
const CONTEXTUAL_ACTION_TARGET_SCRIPT = preload("res://scripts/gameplay/interaction/contextual_action_target.gd")
const WORLD_INTERACTABLE_SCRIPT = preload("res://scripts/gameplay/interaction/world_interactable.gd")
const CATALOGO := {
	"cama": {"nombre": "Cama", "ruta": "res://assets/art/places/Muebles/cama.png"},
	"cofre": {"nombre": "Cofre", "ruta": "res://assets/art/places/Muebles/cofre.png"},
	"horno": {"nombre": "Horno", "ruta": "res://assets/art/places/Muebles/horno.png"},
	"mesa": {"nombre": "Mesa", "ruta": "res://assets/art/places/Muebles/mesa.png"}
}

var _decoraciones: Array[Dictionary] = []
var _sprites: Array[Sprite2D] = []
var _objetivos_cofre: Array[Node2D] = []
var _editor_activo := false
var _inventario_abierto := false
var _menu_viaje_abierto := false
var _tipo_actual := ""
var _giro := 0.0
var _seleccion := -1
var _arrastrando := -1
var _previa: Sprite2D
var _panel: PanelContainer
var _estado: Label
var _capa_ui: CanvasLayer
var _boton_amueblar: Button
var _cofre_ui: Node = null
var _objetivo_cofre_activo: Node = null
var _siguiente_id_cofre := 1


func _ready() -> void:
	_crear_suelo()
	_crear_limites()
	_previa = Sprite2D.new()
	_previa.name = "VistaPreviaMueble"
	_previa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_previa.z_index = 100
	_previa.visible = false
	add_child(_previa)
	_crear_interfaz()
	_capa_ui.visible = visible
	_reconstruir()


func _crear_suelo() -> void:
	var textura := load("res://assets/tilesets/Suelo.png") as Texture2D
	if textura == null:
		push_warning("HogarInterior: no se pudo cargar assets/tilesets/Suelo.png")
		return
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = textura
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i.ZERO)
	tileset.add_source(atlas, 0)
	var capa := TileMapLayer.new()
	capa.name = "Suelo"
	capa.position = Vector2(-ANCHO * 0.5, -ALTO * 0.5)
	capa.tile_set = tileset
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	capa.z_index = -10
	add_child(capa)
	for y in range(int(ALTO / 16.0)):
		for x in range(int(ANCHO / 16.0)):
			capa.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)


func _crear_limites() -> void:
	_agregar_muro("MuroSuperior", Vector2(0, -ALTO * 0.5), Vector2(ANCHO, 24))
	_agregar_muro("MuroIzquierdo", Vector2(-ANCHO * 0.5, 0), Vector2(24, ALTO))
	_agregar_muro("MuroDerecho", Vector2(ANCHO * 0.5, 0), Vector2(24, ALTO))
	# Se deja un hueco central para la puerta de salida.
	_agregar_muro("MuroInferiorIzquierdo", Vector2(-ANCHO * 0.25 - 24, ALTO * 0.5), Vector2(ANCHO * 0.5 - 48, 24))
	_agregar_muro("MuroInferiorDerecho", Vector2(ANCHO * 0.25 + 24, ALTO * 0.5), Vector2(ANCHO * 0.5 - 48, 24))
	var borde := Line2D.new()
	borde.name = "BordeHabitacion"
	borde.points = PackedVector2Array([
		Vector2(-ANCHO * 0.5, -ALTO * 0.5),
		Vector2(ANCHO * 0.5, -ALTO * 0.5),
		Vector2(ANCHO * 0.5, ALTO * 0.5),
		Vector2(ANCHO * 0.5, ALTO * 0.5),
		Vector2(-ANCHO * 0.5, ALTO * 0.5),
		Vector2(-ANCHO * 0.5, -ALTO * 0.5)
	])
	borde.width = 5.0
	borde.default_color = Color("#493326")
	borde.z_index = 5
	add_child(borde)


func _agregar_muro(nombre: String, posicion: Vector2, tamano: Vector2) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.name = nombre
	cuerpo.position = posicion
	var forma := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = tamano
	forma.shape = rectangulo
	cuerpo.add_child(forma)
	add_child(cuerpo)


func _crear_interfaz() -> void:
	_capa_ui = CanvasLayer.new()
	_capa_ui.name = "InterfazAmueblado"
	_capa_ui.layer = 31
	add_child(_capa_ui)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_PASS
	_capa_ui.add_child(raiz)
	_boton_amueblar = Button.new()
	var boton := _boton_amueblar
	boton.text = "Amueblar [B]"
	boton.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	boton.offset_left = -164
	boton.offset_top = -52
	boton.offset_right = -16
	boton.offset_bottom = -14
	boton.pressed.connect(alternar_editor)
	PIXEL_UI_THEME.apply(boton)
	raiz.add_child(boton)
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 60)
	_panel.custom_minimum_size = Vector2(260, 0)
	_panel.visible = false
	PIXEL_UI_THEME.apply(_panel)
	raiz.add_child(_panel)
	var contenido := VBoxContainer.new()
	_panel.add_child(contenido)
	var titulo := Label.new()
	titulo.text = "MUEBLES"
	contenido.add_child(titulo)
	_estado = Label.new()
	_estado.text = "Selecciona un mueble"
	contenido.add_child(_estado)
	var lista := GridContainer.new()
	lista.columns = 2
	contenido.add_child(lista)
	for tipo in CATALOGO.keys():
		var item := Button.new()
		item.text = str(CATALOGO[tipo].nombre)
		item.custom_minimum_size = Vector2(110, 36)
		item.pressed.connect(_seleccionar.bind(str(tipo)))
		PIXEL_UI_THEME.apply(item)
		lista.add_child(item)


func establecer_activo(activo: bool) -> void:
	visible = activo
	if not activo:
		cerrar_cofre()
	if is_instance_valid(_capa_ui):
		_capa_ui.visible = activo and not _inventario_abierto and not _menu_viaje_abierto
	set_process(activo)
	set_process_unhandled_input(activo)
	if not activo:
		_establecer_editor(false)


func establecer_inventario_abierto(abierto: bool) -> void:
	_inventario_abierto = abierto
	if abierto:
		_establecer_editor(false)
	if is_instance_valid(_capa_ui):
		_capa_ui.visible = visible and not abierto and not _menu_viaje_abierto


func establecer_menu_viaje_abierto(abierto: bool) -> void:
	_menu_viaje_abierto = abierto
	if abierto:
		_establecer_editor(false)
	if is_instance_valid(_capa_ui):
		_capa_ui.visible = visible and not _inventario_abierto and not abierto


func alternar_editor() -> void:
	if _inventario_abierto or esta_cofre_abierto():
		return
	_establecer_editor(not _editor_activo)


func esta_editando() -> bool:
	return _editor_activo


func esta_cofre_abierto() -> bool:
	return is_instance_valid(_cofre_ui)


func registrar_cofre_abierto(interfaz: Node, objetivo: Node) -> void:
	_cofre_ui = interfaz
	_objetivo_cofre_activo = objetivo
	if is_instance_valid(_boton_amueblar):
		_boton_amueblar.visible = false


func registrar_cofre_cerrado(interfaz: Node, objetivo: Node) -> void:
	if _cofre_ui == interfaz:
		_cofre_ui = null
	if _objetivo_cofre_activo == objetivo:
		_objetivo_cofre_activo = null
	if is_instance_valid(_boton_amueblar):
		_boton_amueblar.visible = visible and not _inventario_abierto and not _menu_viaje_abierto


func _establecer_editor(activo: bool) -> void:
	if activo and esta_cofre_abierto():
		return
	_editor_activo = activo
	if activo:
		if not is_in_group("modal_ui"):
			add_to_group("modal_ui")
	elif is_in_group("modal_ui"):
		remove_from_group("modal_ui")
	_panel.visible = activo
	_previa.visible = false
	_tipo_actual = ""
	_arrastrando = -1
	if not activo:
		_seleccion = -1
		for indice in range(_sprites.size()):
			_actualizar_sprite(indice)


func cargar_estado_guardado(estado: Dictionary) -> void:
	var datos: Variant = estado.get("decoraciones", [])
	_siguiente_id_cofre = maxi(1, int(estado.get("siguiente_id_cofre", 1)))
	_decoraciones.clear()
	if datos is Array:
		for entrada in datos:
			if not entrada is Dictionary:
				continue
			var item := (entrada as Dictionary).duplicate(true)
			var tipo := str(item.get("tipo", ""))
			if not CATALOGO.has(tipo):
				continue
			var decoracion := {
				"tipo": tipo,
				"x": clampf(float(item.get("x", 0.0)), -ANCHO * 0.5, ANCHO * 0.5),
				"y": clampf(float(item.get("y", 0.0)), -ALTO * 0.5, ALTO * 0.5),
				"giro": float(item.get("giro", 0.0))
			}
			if tipo == "cofre":
				var id_cofre := str(item.get("cofre_id", "")).strip_edges()
				if id_cofre.is_empty() or _id_cofre_ya_existe(id_cofre):
					id_cofre = _crear_id_cofre()
				decoracion["cofre_id"] = id_cofre
				var contenido: Array = []
				var contenido_guardado: Variant = item.get("contenido", [])
				if contenido_guardado is Array:
					for objeto in contenido_guardado:
						contenido.append((objeto as Dictionary).duplicate(true) if objeto is Dictionary else {})
				contenido.resize(32)
				decoracion["contenido"] = contenido
			if _es_valida(str(decoracion.tipo), Vector2(float(decoracion.x), float(decoracion.y)), float(decoracion.giro)):
				_decoraciones.append(decoracion)
	if is_inside_tree():
		_reconstruir()


func obtener_estado_guardado() -> Dictionary:
	return {
		"version": 2,
		"siguiente_id_cofre": _siguiente_id_cofre,
		"decoraciones": _decoraciones.duplicate(true)
	}


func _crear_contenido_vacio() -> Array:
	var contenido: Array = []
	contenido.resize(32)
	return contenido


func _crear_id_cofre() -> String:
	var candidato := ""
	while candidato.is_empty() or _id_cofre_ya_existe(candidato):
		candidato = "cofre_" + str(_siguiente_id_cofre)
		_siguiente_id_cofre += 1
	return candidato


func _id_cofre_ya_existe(id_buscado: String) -> bool:
	for decoracion in _decoraciones:
		if str(decoracion.get("cofre_id", "")) == id_buscado:
			return true
	return false


func obtener_contenido_cofre(indice: int) -> Array:
	if indice < 0 or indice >= _decoraciones.size():
		return []
	if str(_decoraciones[indice].get("tipo", "")) != "cofre":
		return []
	var contenido_variant: Variant = _decoraciones[indice].get("contenido", [])
	var contenido: Array = []
	if contenido_variant is Array:
		for objeto in contenido_variant:
			contenido.append((objeto as Dictionary).duplicate(true) if objeto is Dictionary else {})
	contenido.resize(32)
	return contenido


func establecer_contenido_cofre(indice: int, objetos: Array) -> bool:
	if indice < 0 or indice >= _decoraciones.size():
		return false
	if str(_decoraciones[indice].get("tipo", "")) != "cofre":
		return false
	var contenido: Array = []
	for objeto in objetos:
		contenido.append((objeto as Dictionary).duplicate(true) if objeto is Dictionary else {})
	contenido.resize(32)
	_decoraciones[indice]["contenido"] = contenido
	_guardar()
	return true


func _cofre_tiene_contenido(indice: int) -> bool:
	for objeto in obtener_contenido_cofre(indice):
		if objeto is Dictionary and not (objeto as Dictionary).is_empty():
			return true
	return false


func _puede_abrir_cofre_desde_interaccion(jugador: Node, indice: int) -> bool:
	if not visible or _editor_activo or esta_cofre_abierto():
		return false
	if indice < 0 or indice >= _decoraciones.size() or indice >= _sprites.size():
		return false
	if str(_decoraciones[indice].get("tipo", "")) != "cofre":
		return false
	var sprite := _sprites[indice]
	if not is_instance_valid(sprite) or not jugador is Node2D:
		return false
	return (jugador as Node2D).global_position.distance_to(sprite.global_position) <= 112.0


func _abrir_cofre_desde_interaccion(jugador: Node, indice: int) -> void:
	if _puede_abrir_cofre_desde_interaccion(jugador, indice):
		_abrir_cofre(indice)


func _abrir_cofre(indice: int) -> void:
	if esta_cofre_abierto() or indice < 0 or indice >= _decoraciones.size():
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var sprite: Sprite2D = _sprites[indice] if indice < _sprites.size() else null
	if not is_instance_valid(jugador) or not is_instance_valid(sprite):
		return
	if jugador.global_position.distance_to(sprite.global_position) > 112.0:
		return
	var inventario := get_tree().get_first_node_in_group("inventory")
	if not is_instance_valid(inventario):
		push_warning("HogarInterior: no se encontró el inventario del jugador.")
		return
	var interfaz := CHEST_UI_SCRIPT.new() as CanvasLayer
	if not is_instance_valid(interfaz):
		return
	_cofre_ui = interfaz
	if is_instance_valid(_boton_amueblar):
		_boton_amueblar.visible = false
	add_child(interfaz)
	interfaz.call("abrir", self, inventario, indice)


func cerrar_cofre() -> void:
	if is_instance_valid(_objetivo_cofre_activo) and _objetivo_cofre_activo.has_method("cerrar_cofre"):
		_objetivo_cofre_activo.call("cerrar_cofre")
		return
	if not is_instance_valid(_cofre_ui):
		_cofre_ui = null
		return
	var interfaz := _cofre_ui
	_cofre_ui = null
	if interfaz.is_in_group("modal_ui"):
		interfaz.remove_from_group("modal_ui")
	interfaz.queue_free()
	if is_instance_valid(_boton_amueblar):
		_boton_amueblar.visible = visible and not _inventario_abierto and not _menu_viaje_abierto


func _reconstruir() -> void:
	for sprite in _sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	for objetivo in _objetivos_cofre:
		if is_instance_valid(objetivo):
			objetivo.queue_free()
	_sprites.clear()
	_objetivos_cofre.clear()
	for i in range(_decoraciones.size()):
		_agregar_sprite(i)


func _agregar_sprite(indice: int) -> void:
	var item: Dictionary = _decoraciones[indice]
	var textura := _textura(str(item.tipo))
	if textura == null:
		_sprites.append(null)
		_objetivos_cofre.append(null)
		return
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_sprites.append(sprite)
	var tipo := str(_decoraciones[indice].get("tipo", ""))
	if tipo in ["cofre", "cama"]:
		var objetivo: Node2D = WORLD_INTERACTABLE_SCRIPT.new() as Node2D
		if is_instance_valid(objetivo):
			objetivo.name = "InteraccionMueble_" + str(indice)
			objetivo.position = sprite.position
			if tipo == "cofre":
				objetivo.call("configurar_cofre", str(_decoraciones[indice].get("cofre_id", "hogar_interior_" + str(indice))), self, indice)
			else:
				objetivo.call("configurar_cama")
			add_child(objetivo)
		_objetivos_cofre.append(objetivo)
	else:
		_objetivos_cofre.append(null)
	_actualizar_sprite(indice)


func _actualizar_sprite(indice: int) -> void:
	if indice < 0 or indice >= _sprites.size() or indice >= _decoraciones.size():
		return
	var sprite := _sprites[indice]
	if not is_instance_valid(sprite):
		return
	var item: Dictionary = _decoraciones[indice]
	sprite.position = Vector2(float(item.x), float(item.y))
	sprite.rotation = float(item.giro)
	sprite.z_index = 2 + int((sprite.position.y + ALTO * 0.5) / CELDA)
	sprite.modulate = Color("#FFE3A3") if indice == _seleccion else Color.WHITE
	if indice < _objetivos_cofre.size() and is_instance_valid(_objetivos_cofre[indice]):
		_objetivos_cofre[indice].position = sprite.position


func _seleccionar(tipo: String) -> void:
	_arrastrando = -1
	_tipo_actual = tipo
	_seleccion = -1
	_giro = 0.0
	_previa.texture = _textura(tipo)
	_previa.visible = true
	_actualizar_previa()
	_estado.text = "Colocando: " + str(CATALOGO[tipo].nombre)


func _input(event: InputEvent) -> void:
	if not _editor_activo:
		return
	if event is InputEventMouseButton:
		var raton := event as InputEventMouseButton
		if raton.button_index == MOUSE_BUTTON_LEFT and not raton.pressed and _arrastrando >= 0:
			_mover(_arrastrando, _ajustar(get_global_mouse_position()))
			_arrastrando = -1
			_guardar()
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventKey:
		return
	var tecla := event as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_ESCAPE:
			_establecer_editor(false)
			get_viewport().set_input_as_handled()
		KEY_R:
			_giro = wrapf(_giro + PI * 0.5, 0.0, TAU)
			_previa.rotation = _giro
			_actualizar_previa()
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			if _seleccion >= 0 and _seleccion < _decoraciones.size():
				if str(_decoraciones[_seleccion].get("tipo", "")) == "cofre" and _cofre_tiene_contenido(_seleccion):
					_estado.text = "Vacía el cofre antes de retirarlo."
					get_viewport().set_input_as_handled()
					return
				_decoraciones.remove_at(_seleccion)
				_seleccion = -1
				_reconstruir()
				_guardar()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if esta_cofre_abierto() or not _editor_activo:
		return
	if event is InputEventMouseMotion:
		if _arrastrando >= 0:
			_mover(_arrastrando, _ajustar(get_global_mouse_position()))
		elif not _tipo_actual.is_empty():
			_actualizar_previa()
		return
	if not event is InputEventMouseButton:
		return
	var raton := event as InputEventMouseButton
	if raton.button_index == MOUSE_BUTTON_RIGHT and raton.pressed:
		_tipo_actual = ""
		_previa.visible = false
		get_viewport().set_input_as_handled()
		return
	if raton.button_index != MOUSE_BUTTON_LEFT:
		return
	if raton.pressed:
		var posicion := _ajustar(get_global_mouse_position())
		if not _tipo_actual.is_empty():
			if _es_valida(_tipo_actual, posicion, _giro):
				var nueva_decoracion := {"tipo": _tipo_actual, "x": posicion.x, "y": posicion.y, "giro": _giro}
				if _tipo_actual == "cofre":
					nueva_decoracion["cofre_id"] = _crear_id_cofre()
					nueva_decoracion["contenido"] = _crear_contenido_vacio()
				_decoraciones.append(nueva_decoracion)
				_reconstruir()
				_guardar()
				_actualizar_previa()
		else:
			_seleccion = _buscar(get_global_mouse_position())
			_arrastrando = _seleccion
			_reconstruir()
	else:
		if _arrastrando >= 0:
			_mover(_arrastrando, _ajustar(get_global_mouse_position()))
			_arrastrando = -1
			_guardar()
	get_viewport().set_input_as_handled()


func _mover(indice: int, posicion: Vector2) -> void:
	if indice < 0 or indice >= _decoraciones.size():
		return
	if not _es_valida(str(_decoraciones[indice].tipo), posicion, float(_decoraciones[indice].giro)):
		return
	_decoraciones[indice].x = posicion.x
	_decoraciones[indice].y = posicion.y
	_actualizar_sprite(indice)


func _buscar(posicion_global: Vector2) -> int:
	for i in range(_sprites.size() - 1, -1, -1):
		var sprite := _sprites[i]
		if not is_instance_valid(sprite) or sprite.texture == null:
			continue
		if Rect2(-sprite.texture.get_size() * 0.5, sprite.texture.get_size()).has_point(sprite.to_local(posicion_global)):
			return i
	return -1


func _actualizar_previa() -> void:
	if not is_instance_valid(_previa) or _tipo_actual.is_empty():
		return
	var posicion := _ajustar(get_global_mouse_position())
	_previa.position = to_local(posicion)
	_previa.rotation = _giro
	_previa.modulate = Color(1, 1, 1, 0.65) if _es_valida(_tipo_actual, posicion, _giro) else Color(1, 0.35, 0.3, 0.65)


func _ajustar(posicion_global: Vector2) -> Vector2:
	var local := to_local(posicion_global)
	var origen := Vector2(-ANCHO * 0.5, -ALTO * 0.5)
	var celda := Vector2i(floori((local.x - origen.x) / CELDA), floori((local.y - origen.y) / CELDA))
	return origen + Vector2(celda) * CELDA + Vector2.ONE * CELDA * 0.5


func _es_valida(tipo: String, posicion: Vector2, giro: float) -> bool:
	var textura := _textura(tipo)
	if textura == null:
		return false
	var ext := textura.get_size() * 0.5
	var c := absf(cos(giro))
	var s := absf(sin(giro))
	var rot := Vector2(ext.x * c + ext.y * s, ext.x * s + ext.y * c)
	return (
		posicion.x - rot.x >= -ANCHO * 0.5 and posicion.x + rot.x <= ANCHO * 0.5
		and posicion.y - rot.y >= -ALTO * 0.5 and posicion.y + rot.y <= ALTO * 0.5
	)


func _textura(tipo: String) -> Texture2D:
	if not CATALOGO.has(tipo):
		return null
	return load(str(CATALOGO[tipo].ruta)) as Texture2D


func _guardar() -> void:
	var hogar := get_parent()
	if not is_instance_valid(hogar) or not hogar.has_method("obtener_estado_guardado"):
		return
	var estado: Dictionary = hogar.call("obtener_estado_guardado")
	estado["interior_decoraciones"] = obtener_estado_guardado()
	GameState.world_state.flags["hogar_estado"] = estado
	if not GameState.active_save_id.is_empty():
		GameState.call_deferred("guardar_partida")
