extends CanvasLayer
class_name GarliaShopUI

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")
const ITEM_ICON_RESOLVER = preload("res://scripts/ui/item_icon_resolver.gd")

const TIENDAS: Dictionary = {
	"panaderia": {
		"nombre": "Panadería",
		"productos": ["pan", "manzana"]
	},
	"forja": {
		"nombre": "Forja",
		"productos": ["espada", "escudo", "botas", "flecha"]
	},
	"carpinteria": {
		"nombre": "Carpintería",
		"productos": ["pala", "pico", "arco", "madera"]
	},
	"casa_comercio": {
		"nombre": "Casa de comercio",
		"productos": ["manzana", "pluma", "flecha", "botas"]
	}
}

const PRECIOS_BASE: Dictionary = {
	"pan": 4,
	"manzana": 3,
	"espada de madera": 20,
	"espada de piedra": 35,
	"flecha de madera": 2,
	"escudo": 28,
	"botas de hierro": 45,
	"pala de madera": 12,
	"pico de madera": 14,
	"pala de piedra": 20,
	"pico de piedra": 24,
	"pluma aoris": 10,
	"arco aoris": 30
}

var _vendedor: Node = null
var _inventario: GarliaInventory = null
var _world_items: GarliaWorldItems = null
var _tienda: Dictionary = {}
var _productos: Array[Dictionary] = []
var _panel: PanelContainer
var _lista: VBoxContainer
var _balance: Label
var _estado: Label
var _jugador: Node = null
var _jugador_fisica_previa := true
var _jugador_input_previo := true
var _jugador_unhandled_previo := true


static func tienda_para_npc(npc: Node) -> Dictionary:
	if not is_instance_valid(npc):
		return {}
	if not bool(npc.get_meta("rutina_en_edificio", false)):
		return {}
	var ubicacion := str(npc.get_meta("rutina_ubicacion", "")).strip_edges().to_lower()
	var tienda_variant: Variant = TIENDAS.get(ubicacion, {})
	if not tienda_variant is Dictionary:
		return {}
	var resultado := (tienda_variant as Dictionary).duplicate(true)
	resultado["ubicacion"] = ubicacion
	resultado["vendedor"] = str(npc.call("get_nombre_visual")) if npc.has_method("get_nombre_visual") else "Comerciante"
	return resultado


func configurar(vendedor: Node, inventario: GarliaInventory, world_items: GarliaWorldItems, jugador: Node) -> void:
	_vendedor = vendedor
	_inventario = inventario
	_world_items = world_items
	_jugador = jugador
	_tienda = tienda_para_npc(vendedor)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	_bloquear_jugador()
	_construir_interfaz()
	if is_instance_valid(_world_items) and not _world_items.catalogo_cargado.is_connected(_al_catalogo_cargado):
		_world_items.catalogo_cargado.connect(_al_catalogo_cargado)
	call_deferred("_actualizar_catalogo")


func _bloquear_jugador() -> void:
	if not is_instance_valid(_jugador):
		return
	_jugador_fisica_previa = _jugador.is_physics_processing()
	_jugador_input_previo = _jugador.is_processing_input()
	_jugador_unhandled_previo = _jugador.is_processing_unhandled_input()
	_jugador.set_physics_process(false)
	_jugador.set_process_input(false)
	_jugador.set_process_unhandled_input(false)
	if _jugador is CharacterBody2D:
		(_jugador as CharacterBody2D).velocity = Vector2.ZERO


func _construir_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.025, 0.02, 0.015, 0.78)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620.0, 420.0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centro.add_child(_panel)
	PIXEL_UI_THEME.apply(_panel, false)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 16)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 16)
	margen.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margen)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	margen.add_child(columna)

	var encabezado := HBoxContainer.new()
	columna.add_child(encabezado)

	var titulo := Label.new()
	titulo.text = str(_tienda.get("nombre", "Tienda"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_theme_font_size_override("font_size", 18)
	encabezado.add_child(titulo)

	var hablar := Button.new()
	hablar.text = "Hablar"
	hablar.pressed.connect(_hablar_con_vendedor)
	encabezado.add_child(hablar)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.pressed.connect(cerrar_tienda)
	encabezado.add_child(cerrar)

	_balance = Label.new()
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	columna.add_child(_balance)

	var separador := HSeparator.new()
	columna.add_child(separador)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_child(scroll)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 7)
	scroll.add_child(_lista)

	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_estado)

	_actualizar_balance()


func _al_catalogo_cargado(_items: Array) -> void:
	_actualizar_catalogo()


func _actualizar_catalogo() -> void:
	if not is_instance_valid(_lista):
		return
	for hijo in _lista.get_children():
		hijo.queue_free()
	_productos.clear()

	if not is_instance_valid(_world_items):
		_mostrar_estado("No se pudo cargar el catálogo de la tienda.")
		return
	if _world_items.obtener_catalogo().is_empty():
		_mostrar_estado("Cargando productos…")
		return

	var palabras: Array = _tienda.get("productos", [])
	for item_variant in _world_items.obtener_catalogo():
		if not item_variant is Dictionary:
			continue
		var item := (item_variant as Dictionary).duplicate(true)
		var nombre := str(item.get("nombre", "")).strip_edges()
		var nombre_busqueda := nombre.to_lower()
		var coincide := false
		for palabra_variant in palabras:
			if nombre_busqueda.contains(str(palabra_variant)):
				coincide = true
				break
		if not coincide:
			continue
		var textura := ITEM_ICON_RESOLVER.obtener_icono(item)
		if textura == null:
			continue
		item["precio_tienda"] = _obtener_precio(item)
		_productos.append(item)

	_productos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("nombre", "")) < str(b.get("nombre", ""))
	)

	if _productos.is_empty():
		_mostrar_estado("Esta tienda todavía no tiene productos con imagen disponibles en el catálogo.")
		return

	_estado.text = ""
	for producto in _productos:
		_crear_fila_producto(producto)
	_actualizar_balance()


func _crear_fila_producto(producto: Dictionary) -> void:
	var fila := PanelContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_child(fila)
	PIXEL_UI_THEME.apply(fila, false)

	var contenido := HBoxContainer.new()
	contenido.add_theme_constant_override("separation", 12)
	fila.add_child(contenido)

	var imagen := TextureRect.new()
	imagen.custom_minimum_size = Vector2(64.0, 64.0)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagen.texture = ITEM_ICON_RESOLVER.obtener_icono(producto)
	contenido.add_child(imagen)

	var detalles := VBoxContainer.new()
	detalles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalles.add_theme_constant_override("separation", 2)
	contenido.add_child(detalles)

	var nombre := Label.new()
	nombre.text = str(producto.get("nombre", "Objeto"))
	nombre.add_theme_font_size_override("font_size", 13)
	detalles.add_child(nombre)

	var descripcion := Label.new()
	var texto_descripcion := str(producto.get("descripcion", "")).strip_edges()
	descripcion.text = texto_descripcion if not texto_descripcion.is_empty() else "Sin descripción registrada."
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descripcion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalles.add_child(descripcion)

	var precio := Label.new()
	precio.text = "Precio: %d monedas" % int(producto.get("precio_tienda", 1))
	detalles.add_child(precio)

	var comprar := Button.new()
	comprar.text = "Comprar"
	comprar.custom_minimum_size = Vector2(92.0, 38.0)
	comprar.pressed.connect(func() -> void:
		_comprar_producto(producto)
	)
	contenido.add_child(comprar)


func _obtener_precio(item: Dictionary) -> int:
	var propiedades_variant: Variant = item.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		for clave in ["precio", "precio_compra", "valor_compra"]:
			if propiedades.has(clave):
				return maxi(1, int(propiedades.get(clave, 1)))
	var nombre := str(item.get("nombre", "")).strip_edges().to_lower()
	if PRECIOS_BASE.has(nombre):
		return int(PRECIOS_BASE[nombre])
	return 10


func _comprar_producto(producto: Dictionary) -> void:
	if not is_instance_valid(_inventario):
		_mostrar_estado("No se encontró tu inventario.")
		return
	var precio := maxi(1, int(producto.get("precio_tienda", 1)))
	if GameState.obtener_dinero() < precio:
		_mostrar_estado("No tienes suficientes monedas.")
		return
	if not GameState.modificar_dinero(-precio):
		_mostrar_estado("No se pudo completar el pago.")
		return

	var objeto := producto.duplicate(true)
	objeto["cantidad"] = 1
	objeto["max_stack"] = maxi(1, int(objeto.get("max_stack", 1)))
	if not _inventario.agregar_objeto_desde_ui(objeto):
		GameState.modificar_dinero(precio)
		_mostrar_estado("No tienes espacio en el inventario.")
		return

	_actualizar_balance()
	_mostrar_estado("Compraste %s." % str(producto.get("nombre", "el objeto")))
	Events.notification_pushed.emit("Compraste " + str(producto.get("nombre", "un objeto")))
	GameState.call_deferred("_ejecutar_guardado_rapido")


func _actualizar_balance() -> void:
	if is_instance_valid(_balance):
		_balance.text = "Tu dinero: %d monedas" % GameState.obtener_dinero()


func _mostrar_estado(mensaje: String) -> void:
	if is_instance_valid(_estado):
		_estado.text = mensaje


func _hablar_con_vendedor() -> void:
	var npc := _vendedor
	cerrar_tienda()
	if is_instance_valid(npc) and npc.has_method("abrir_dialogo"):
		npc.call("abrir_dialogo")


func cerrar_tienda() -> void:
	if is_instance_valid(_world_items) and _world_items.catalogo_cargado.is_connected(_al_catalogo_cargado):
		_world_items.catalogo_cargado.disconnect(_al_catalogo_cargado)
	if is_instance_valid(_jugador):
		_jugador.set_physics_process(_jugador_fisica_previa)
		_jugador.set_process_input(_jugador_input_previo)
		_jugador.set_process_unhandled_input(_jugador_unhandled_previo)
	if is_in_group("modal_ui"):
		remove_from_group("modal_ui")
	get_viewport().gui_release_focus()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cerrar_tienda()
			get_viewport().set_input_as_handled()
