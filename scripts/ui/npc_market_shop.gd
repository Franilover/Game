extends PanelContainer
class_name NPCMarketShop

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const MAX_PRODUCTOS := 7
const STOCK_MINIMO := 2
const STOCK_MAXIMO := 5

signal solicitar_cierre

var _npc: Creature = null
var _inventario: InventoryController = null
var _world_items: GarliaWorldItems = null
var _game_state: Node = null
var _dia_clave := "1"
var _modo := "comprar"
var _productos: Array[Dictionary] = []
var _stock: Dictionary = {}
var _titulo: Label
var _saldo: Label
var _estado: Label
var _lista: VBoxContainer
var _boton_comprar: Button
var _boton_vender: Button


func configurar(npc: Creature, inventario: InventoryController, world_items: GarliaWorldItems) -> void:
	_npc = npc
	_inventario = inventario
	_world_items = world_items
	_game_state = get_node_or_null("/root/GameState")
	_dia_clave = _obtener_dia_clave()
	_generar_catalogo_personal()
	_cargar_stock_persistente()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 8.0
	offset_top = 8.0
	offset_right = -8.0
	offset_bottom = -8.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_interfaz()
	PIXEL_UI_THEME.apply(self, false)
	_actualizar_lista()


func _crear_interfaz() -> void:
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 12)
	margen.add_theme_constant_override("margin_top", 8)
	margen.add_theme_constant_override("margin_right", 12)
	margen.add_theme_constant_override("margin_bottom", 8)
	add_child(margen)
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 5)
	margen.add_child(contenido)

	var encabezado := HBoxContainer.new()
	contenido.add_child(encabezado)
	_titulo = Label.new()
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.add_theme_font_size_override("font_size", 14)
	encabezado.add_child(_titulo)
	var cerrar := Button.new()
	cerrar.text = "Volver"
	cerrar.custom_minimum_size = Vector2(76, 28)
	cerrar.pressed.connect(func() -> void: solicitar_cierre.emit())
	encabezado.add_child(cerrar)

	_saldo = Label.new()
	_saldo.add_theme_font_size_override("font_size", 11)
	contenido.add_child(_saldo)

	var pestanas := HBoxContainer.new()
	contenido.add_child(pestanas)
	_boton_comprar = Button.new()
	_boton_comprar.text = "Comprar"
	_boton_comprar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_comprar.pressed.connect(func() -> void:
		_modo = "comprar"
		_actualizar_lista()
	)
	pestanas.add_child(_boton_comprar)
	_boton_vender = Button.new()
	_boton_vender.text = "Vender"
	_boton_vender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_vender.pressed.connect(func() -> void:
		_modo = "vender"
		_actualizar_lista()
	)
	pestanas.add_child(_boton_vender)

	var desplazamiento := ScrollContainer.new()
	desplazamiento.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazamiento.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenido.add_child(desplazamiento)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 3)
	desplazamiento.add_child(_lista)

	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.add_theme_font_size_override("font_size", 10)
	contenido.add_child(_estado)


func _actualizar_lista() -> void:
	if not is_instance_valid(_lista):
		return
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	if not is_instance_valid(_npc):
		return
	_titulo.text = "Mercado de " + _npc.get_nombre_visual()
	_saldo.text = "Tus monedas: %d" % _obtener_saldo()
	_boton_comprar.disabled = _modo == "comprar"
	_boton_vender.disabled = _modo == "vender"
	_estado.text = ""
	if _modo == "comprar":
		var disponibles := 0
		for producto in _productos:
			var item_id := str(producto.get("item_id", ""))
			var cantidad := int(_stock.get(item_id, 0))
			if cantidad <= 0:
				continue
			disponibles += 1
			_crear_fila_producto(producto, cantidad)
		if disponibles == 0:
			_estado.text = "Se ha agotado la mercancía de hoy."
	else:
		var objetos: Array[Dictionary] = _inventario.runtime.state.items.duplicate(true) if is_instance_valid(_inventario) else []
		var vendibles := 0
		for indice in range(objetos.size()):
			var objeto: Dictionary = objetos[indice]
			if objeto.is_empty() or not _es_comerciable(objeto):
				continue
			vendibles += 1
			_crear_fila_venta(objeto, indice)
		if vendibles == 0:
			_estado.text = "No tienes objetos que este aldeano pueda comprar."


func _crear_fila_producto(producto: Dictionary, stock: int) -> void:
	var fila := HBoxContainer.new()
	fila.custom_minimum_size = Vector2(0, 32)
	_lista.add_child(fila)
	var nombre := Label.new()
	nombre.text = "%s  ×%d" % [str(producto.get("nombre", "Objeto")), stock]
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fila.add_child(nombre)
	var precio := maxi(1, int(producto.get("precio", 1)))
	var boton := Button.new()
	boton.text = "Comprar · %d" % precio
	boton.custom_minimum_size = Vector2(116, 28)
	boton.disabled = _obtener_saldo() < precio
	boton.pressed.connect(_comprar.bind(str(producto.get("item_id", ""))))
	fila.add_child(boton)


func _crear_fila_venta(objeto: Dictionary, indice: int) -> void:
	var fila := HBoxContainer.new()
	fila.custom_minimum_size = Vector2(0, 32)
	_lista.add_child(fila)
	var nombre := Label.new()
	var cantidad := maxi(1, int(objeto.get("cantidad", 1)))
	nombre.text = "%s  ×%d" % [str(objeto.get("nombre", "Objeto")), cantidad]
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fila.add_child(nombre)
	var precio := maxi(1, floori(float(_precio_base(objeto)) * 0.5))
	var boton := Button.new()
	boton.text = "Vender · %d" % precio
	boton.custom_minimum_size = Vector2(116, 28)
	boton.pressed.connect(_vender.bind(indice, str(objeto.get("item_id", objeto.get("id", ""))), precio))
	fila.add_child(boton)


func _comprar(item_id: String) -> void:
	if item_id.is_empty() or not is_instance_valid(_inventario) or not is_instance_valid(_world_items) or not is_instance_valid(_game_state):
		return
	var cantidad_stock := int(_stock.get(item_id, 0))
	if cantidad_stock <= 0:
		_estado.text = "Ese producto ya se agotó."
		_actualizar_lista()
		return
	var producto := _world_items.buscar_item_por_id(item_id)
	if producto.is_empty():
		_estado.text = "El catálogo ya no contiene ese objeto."
		return
	var precio := _precio_producto(item_id)
	if _obtener_saldo() < precio:
		_estado.text = "No tienes suficientes monedas."
		return
	producto["cantidad"] = 1
	producto["max_stack"] = maxi(1, int(producto.get("max_stack", 1)))
	if not _inventario.agregar_objeto_desde_ui(producto):
		_estado.text = "No tienes espacio en el inventario."
		return
	if not bool(_game_state.call("modificar_dinero", -precio)):
		var indice_agregado := _buscar_ultimo_item(item_id)
		if indice_agregado >= 0:
			_inventario.quitar_cantidad_desde_ui(indice_agregado, 1)
		_estado.text = "No se pudo completar el pago."
		return
	_stock[item_id] = cantidad_stock - 1
	_guardar_stock_persistente()
	_estado.text = "Compraste %s." % str(producto.get("nombre", "el objeto"))
	_actualizar_lista()


func _vender(indice: int, item_id: String, precio: int) -> void:
	if not is_instance_valid(_inventario) or not is_instance_valid(_game_state):
		return
	var actual := _inventario.obtener_item(indice)
	if actual.is_empty() or str(actual.get("item_id", actual.get("id", ""))) != item_id:
		_estado.text = "El inventario cambió. Inténtalo otra vez."
		_actualizar_lista()
		return
	if not _inventario.quitar_cantidad_desde_ui(indice, 1):
		_estado.text = "No se pudo retirar el objeto."
		return
	_game_state.call("modificar_dinero", precio)
	_estado.text = "Vendiste %s por %d monedas." % [str(actual.get("nombre", "el objeto")), precio]
	_actualizar_lista()


func _buscar_ultimo_item(item_id: String) -> int:
	if not is_instance_valid(_inventario):
		return -1
	var objetos: Array[Dictionary] = _inventario.runtime.state.items.duplicate(true)
	for indice in range(objetos.size() - 1, -1, -1):
		var item := _inventario.obtener_item(indice)
		if str(item.get("item_id", item.get("id", ""))) == item_id:
			return indice
	return -1


func _generar_catalogo_personal() -> void:
	_productos.clear()
	if not is_instance_valid(_world_items):
		return
	var perfil := _perfil_comerciante()
	var candidatos: Array[Dictionary] = []
	for item in _world_items.obtener_catalogo():
		if item.is_empty() or not _es_comerciable(item):
			continue
		var id := str(item.get("item_id", "")).strip_edges()
		if id.is_empty():
			continue
		var texto := (str(item.get("nombre", "")) + " " + str(item.get("descripcion", "")) + " " + str(item.get("tipo", "")) + " " + str((item.get("tipo_objeto", {}) as Dictionary).get("categoria_canonica", ""))).to_lower()
		var puntuacion := 0
		for palabra in perfil:
			if texto.contains(palabra):
				puntuacion += 3
		if puntuacion > 0:
			candidatos.append({"item_id": id, "nombre": str(item.get("nombre", "Objeto")), "precio": _precio_base(item), "puntuacion": puntuacion})
	if candidatos.is_empty():
		var catalogo_fallback: Array[Dictionary] = []
		for item in _world_items.obtener_catalogo():
			if item.is_empty() or not _es_comerciable(item):
				continue
			catalogo_fallback.append({"item_id": str(item.get("item_id", "")), "nombre": str(item.get("nombre", "Objeto")), "precio": _precio_base(item), "puntuacion": 0})
		catalogo_fallback.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("item_id", "")) < str(b.get("item_id", ""))
		)
		# Si no hay etiquetas semánticas en el catálogo, cada vecino recibe
		# una selección distinta y estable, no una copia de la tienda ajena.
		var inicio := posmod(_npc.get_personaje_game_id().hash(), maxi(1, catalogo_fallback.size())) if is_instance_valid(_npc) else 0
		for offset in range(catalogo_fallback.size()):
			candidatos.append(catalogo_fallback[posmod(inicio + offset, catalogo_fallback.size())])
	candidatos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("puntuacion", 0)) == int(b.get("puntuacion", 0)):
			return str(a.get("item_id", "")) < str(b.get("item_id", ""))
		return int(a.get("puntuacion", 0)) > int(b.get("puntuacion", 0))
	)
	if candidatos.is_empty():
		return
	var inicio_catalogo := 0
	if int(candidatos[0].get("puntuacion", 0)) == 0 and is_instance_valid(_npc):
		inicio_catalogo = posmod(_npc.get_personaje_game_id().hash(), candidatos.size())
	for offset in range(mini(MAX_PRODUCTOS, candidatos.size())):
		_productos.append(candidatos[posmod(inicio_catalogo + offset, candidatos.size())].duplicate(true))


func _perfil_comerciante() -> Array[String]:
	var nombre := _npc.get_nombre_visual().to_lower() if is_instance_valid(_npc) else ""
	match nombre:
		"elian":
			return ["pan", "harina", "comida", "alimento", "fruta", "horneado"]
		"bruna":
			return ["herramienta", "metal", "mineral", "hierro", "madera", "forja"]
		"darven":
			return ["protección", "armadura", "curación", "salud", "comida", "antorcha"]
		"saira":
			return ["ropa", "comida", "material", "herramienta", "objeto"]
		"narel", "nima":
			return ["libro", "papel", "tinta", "cristal", "mineral", "investigación", "oris"]
		"mara":
			return ["ropa", "comida", "herramienta", "material", "medicina"]
		"ivo":
			return ["comida", "juego", "libro", "música", "ropa"]
	return ["comida", "material", "herramienta"]


func _es_comerciable(item: Dictionary) -> bool:
	var propiedades_variant: Variant = item.get("propiedades_game", {})
	var propiedades: Dictionary = propiedades_variant as Dictionary if propiedades_variant is Dictionary else {}
	if not bool(propiedades.get("comerciable", true)) or bool(propiedades.get("objeto_de_mision", false)) or bool(propiedades.get("no_vendible", false)):
		return false
	return not str(item.get("item_id", item.get("id", ""))).strip_edges().is_empty()


func _precio_base(item: Dictionary) -> int:
	var propiedades_variant: Variant = item.get("propiedades_game", {})
	var propiedades: Dictionary = propiedades_variant as Dictionary if propiedades_variant is Dictionary else {}
	var valor: Variant = propiedades.get("precio", propiedades.get("valor", item.get("precio", 0)))
	if valor is int or valor is float:
		return maxi(1, int(valor))
	var tipo := str(item.get("tipo", "")).to_lower()
	if tipo.contains("herramienta") or tipo.contains("equipo"):
		return 18
	if tipo.contains("material") or tipo.contains("mineral"):
		return 8
	if tipo.contains("comida") or tipo.contains("alimento"):
		return 5
	return 10


func _precio_producto(item_id: String) -> int:
	for producto in _productos:
		if str(producto.get("item_id", "")) == item_id:
			return maxi(1, int(producto.get("precio", 1)))
	return 1


func _obtener_saldo() -> int:
	return int(_game_state.call("obtener_dinero")) if is_instance_valid(_game_state) else 0


func _obtener_dia_clave() -> String:
	var atmosfera := get_tree().root.find_child("WorldAtmosphere", true, false)
	if not is_instance_valid(atmosfera) or not atmosfera.has_method("obtener_tiempo"):
		return "1"
	var tiempo: Dictionary = atmosfera.call("obtener_tiempo")
	return str(int(tiempo.get("dia", 1)))


func _clave_stock() -> String:
	var id_npc := _npc.get_personaje_game_id() if is_instance_valid(_npc) else "aldeano"
	return "mercado:%s:%s" % [id_npc.to_lower(), _dia_clave]


func _obtener_flags_partida() -> Dictionary:
	if not is_instance_valid(_game_state):
		return {}
	var estado_variant: Variant = _game_state.get("world_state")
	if not estado_variant is Object:
		return {}
	var flags_variant: Variant = (estado_variant as Object).get("flags")
	return flags_variant as Dictionary if flags_variant is Dictionary else {}


func _cargar_stock_persistente() -> void:
	if not is_instance_valid(_game_state):
		return
	var flags := _obtener_flags_partida()
	var todos_variant: Variant = flags.get("mercado_stock", {})
	var todos: Dictionary = todos_variant as Dictionary if todos_variant is Dictionary else {}
	var stock_variant: Variant = todos.get(_clave_stock(), {})
	_stock = stock_variant.duplicate(true) if stock_variant is Dictionary else {}
	if _stock.is_empty():
		var dia_numero := int(_dia_clave)
		for producto in _productos:
			var item_id := str(producto.get("item_id", ""))
			_stock[item_id] = STOCK_MINIMO + posmod(item_id.hash() + dia_numero, STOCK_MAXIMO - STOCK_MINIMO + 1)
		_guardar_stock_persistente()


func _guardar_stock_persistente() -> void:
	if not is_instance_valid(_game_state):
		return
	var flags := _obtener_flags_partida()
	var todos_variant: Variant = flags.get("mercado_stock", {})
	var todos: Dictionary = todos_variant.duplicate(true) if todos_variant is Dictionary else {}
	todos[_clave_stock()] = _stock.duplicate(true)
	flags["mercado_stock"] = todos
	if is_instance_valid(_game_state):
		_game_state.call_deferred("_ejecutar_guardado_rapido")
