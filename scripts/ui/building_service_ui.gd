extends CanvasLayer
class_name BuildingServiceUI

const PIXEL_UI_THEME = preload("res://scripts/ui/pixel_ui_theme.gd")

const ITEM_MADERA := "768a51e5-e34b-4f11-92e7-a6e7dd3bf55c"
const ITEM_PIEDRA_MEDIANA := "0117d138-51ff-4b1b-a317-f8318bf161fa"
const ITEM_ESPADA_MADERA := "2eac0eb8-c33a-47ed-a7b6-dd0342d55ee8"
const ITEM_ESPADA_PIEDRA := "2655370c-2cf7-410e-8a3f-945feb3214d2"

const PRECIO_REPARACION_BRUNA := 15
const PRECIO_LICENCIA_ESPADA := 50
const PRECIO_ESPADA_MADERA := 30
const PRECIO_ESPADA_PIEDRA := 60

const CATALOGO_CARPINTERIA: Array[Dictionary] = [
	{"id":"silla", "nombre":"Silla", "madera":2, "precio":8},
	{"id":"mesa", "nombre":"Mesa", "madera":3, "precio":12},
	{"id":"cofre", "nombre":"Cofre", "madera":4, "precio":18},
	{"id":"armario", "nombre":"Armario", "madera":6, "precio":25}
]

var _tipo := ""
var _inventario: InventoryController
var _world_items: GarliaWorldItems
var _panel: PanelContainer
var _contenido: VBoxContainer
var _estado: Label
var _jugador: Node
var _jugador_fisica_previa := true
var _jugador_input_previo := true
var _jugador_unhandled_previo := true


func configurar(tipo: String, inventario: InventoryController, world_items: GarliaWorldItems, jugador: Node = null) -> void:
	_tipo = tipo
	_inventario = inventario
	_world_items = world_items
	_jugador = jugador
	if is_instance_valid(_jugador):
		_jugador_fisica_previa = _jugador.is_physics_processing()
		_jugador_input_previo = _jugador.is_processing_input()
		_jugador_unhandled_previo = _jugador.is_processing_unhandled_input()
		_jugador.set_physics_process(false)
		_jugador.set_process_input(false)
		_jugador.set_process_unhandled_input(false)
	call_deferred("_actualizar")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	_crear_interfaz()


func _crear_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.025, 0.02, 0.015, 0.78)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(390, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	centro.add_child(_panel)
	PIXEL_UI_THEME.apply(_panel, false)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 14)
	margen.add_theme_constant_override("margin_top", 12)
	margen.add_theme_constant_override("margin_right", 14)
	margen.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margen)

	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", 7)
	margen.add_child(_contenido)


func _actualizar() -> void:
	if not is_instance_valid(_contenido):
		return
	for hijo in _contenido.get_children():
		hijo.queue_free()
	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var titulo := Label.new()
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 18)
	match _tipo:
		"forja": titulo.text = "FORJA"
		"carpinteria": titulo.text = "CARPINTERÍA"
		"cuartel_licencia": titulo.text = "LICENCIAS · CUARTEL"
		"cuartel_armas": titulo.text = "ARSENAL · CUARTEL"
		_: titulo.text = "EDIFICIO"
	_contenido.add_child(titulo)

	var saldo := Label.new()
	saldo.text = "Tus monedas: %d" % GameState.obtener_dinero()
	saldo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_contenido.add_child(saldo)

	match _tipo:
		"forja": _construir_forja()
		"carpinteria": _construir_carpinteria()
		"cuartel_licencia": _construir_cuartel_licencia()
		"cuartel_armas": _construir_cuartel_armas()

	_contenido.add_child(_estado)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, 34)
	cerrar.pressed.connect(cerrar_interfaz)
	_contenido.add_child(cerrar)
	PIXEL_UI_THEME.apply(cerrar, false)


func _construir_forja() -> void:
	_agregar_texto("Selecciona una herramienta dañada. Puedes repararla con material o pagarle a Bruna.")
	if not is_instance_valid(_inventario):
		_agregar_texto("No se encontró el inventario.")
		return
	var items: Array = _inventario.runtime.state.items
	var encontrados := 0
	for indice in range(items.size()):
		var objeto: Dictionary = items[indice]
		if objeto.is_empty():
			continue
		var propiedades: Variant = objeto.get("propiedades_game", {})
		if not propiedades is Dictionary:
			continue
		var maximo := int((propiedades as Dictionary).get("durabilidad", 0))
		if maximo <= 0:
			continue
		var actual := int(objeto.get("durabilidad_actual", maximo))
		if actual >= maximo:
			continue
		encontrados += 1
		var nombre := str(objeto.get("nombre", "Herramienta"))
		var fila := HBoxContainer.new()
		_contenido.add_child(fila)
		var etiqueta := Label.new()
		etiqueta.text = "%s · %d/%d" % [nombre, actual, maximo]
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)
		var material_id := ITEM_MADERA if nombre.to_lower().contains("madera") else ITEM_PIEDRA_MEDIANA if nombre.to_lower().contains("piedra") else ""
		var reparar_material := Button.new()
		reparar_material.text = "Material"
		reparar_material.disabled = material_id.is_empty() or _contar_item(material_id) < 1
		reparar_material.pressed.connect(_reparar_con_material.bind(indice, material_id))
		fila.add_child(reparar_material)
		PIXEL_UI_THEME.apply(reparar_material, false)
		var reparar_bruna := Button.new()
		reparar_bruna.text = "Bruna · %d" % PRECIO_REPARACION_BRUNA
		reparar_bruna.disabled = GameState.obtener_dinero() < PRECIO_REPARACION_BRUNA
		reparar_bruna.pressed.connect(_reparar_con_bruna.bind(indice))
		fila.add_child(reparar_bruna)
		PIXEL_UI_THEME.apply(reparar_bruna, false)
	if encontrados == 0:
		_agregar_texto("No tienes herramientas dañadas en el inventario.")


func _reparar_con_material(indice: int, material_id: String) -> void:
	if not is_instance_valid(_inventario) or material_id.is_empty():
		return
	var slot_material := _buscar_slot_item(material_id)
	if slot_material < 0 or not _inventario.quitar_cantidad_desde_ui(slot_material, 1):
		_mostrar_estado("No tienes el material necesario.")
		return
	_reparar_herramienta(indice)
	_mostrar_estado("Herramienta reparada con material.")
	_actualizar()


func _reparar_con_bruna(indice: int) -> void:
	if not GameState.modificar_dinero(-PRECIO_REPARACION_BRUNA):
		_mostrar_estado("No tienes suficientes monedas.")
		return
	_reparar_herramienta(indice)
	_mostrar_estado("Bruna reparó tu herramienta.")
	_actualizar()


func _reparar_herramienta(indice: int) -> void:
	if not is_instance_valid(_inventario) or indice < 0 or indice >= _inventario.runtime.state.items.size():
		return
	var objeto: Dictionary = _inventario.runtime.state.items[indice]
	var propiedades: Variant = objeto.get("propiedades_game", {})
	if not propiedades is Dictionary:
		return
	var maximo := int((propiedades as Dictionary).get("durabilidad", 0))
	if maximo <= 0:
		return
	objeto["durabilidad_actual"] = maximo
	_inventario.runtime.state.items[indice] = objeto
	_inventario.inventario_cambio.emit()


func _construir_carpinteria() -> void:
	_agregar_texto("Encarga muebles entregando madera y pagando el trabajo. Los encargos quedan guardados en esta partida.")
	for mueble in CATALOGO_CARPINTERIA:
		var fila := HBoxContainer.new()
		_contenido.add_child(fila)
		var etiqueta := Label.new()
		etiqueta.text = "%s · %d madera · %d monedas" % [str(mueble.nombre), int(mueble.madera), int(mueble.precio)]
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)
		var boton := Button.new()
		boton.text = "Encargar"
		boton.disabled = _contar_item(ITEM_MADERA) < int(mueble.madera) or GameState.obtener_dinero() < int(mueble.precio)
		boton.pressed.connect(_encargar_mueble.bind(str(mueble.id)))
		fila.add_child(boton)
		PIXEL_UI_THEME.apply(boton, false)
	var disponibles: Variant = GameState.world_state.flags.get("carpinteria_muebles_disponibles", {})
	var total := 0
	if disponibles is Dictionary:
		for cantidad in (disponibles as Dictionary).values():
			total += int(cantidad)
	_agregar_texto("Muebles encargados en esta partida: %d" % total)


func _encargar_mueble(mueble_id: String) -> void:
	var definicion: Dictionary = {}
	for mueble in CATALOGO_CARPINTERIA:
		if str(mueble.id) == mueble_id:
			definicion = mueble
			break
	if definicion.is_empty():
		return
	var madera := int(definicion.madera)
	var precio := int(definicion.precio)
	if not is_instance_valid(_inventario) or _contar_item(ITEM_MADERA) < madera or GameState.obtener_dinero() < precio:
		_mostrar_estado("Te faltan madera o monedas.")
		return
	if not GameState.modificar_dinero(-precio):
		return
	if not _consumir_item_total(ITEM_MADERA, madera):
		GameState.modificar_dinero(precio)
		_mostrar_estado("No se pudo entregar la madera; se revirtió el pago.")
		return
	var disponibles_variant: Variant = GameState.world_state.flags.get("carpinteria_muebles_disponibles", {})
	var disponibles: Dictionary = disponibles_variant.duplicate(true) if disponibles_variant is Dictionary else {}
	disponibles[mueble_id] = int(disponibles.get(mueble_id, 0)) + 1
	GameState.world_state.flags["carpinteria_muebles_disponibles"] = disponibles
	GameState.call_deferred("_ejecutar_guardado_rapido")
	_mostrar_estado("Encargo terminado: %s. Quedó registrado en tu partida." % str(definicion.nombre))
	_actualizar()


func _construir_cuartel_licencia() -> void:
	var licencia := bool(GameState.world_state.flags.get("licencia_espadas", false))
	if licencia:
		_agregar_texto("Tu licencia de espadas ya está concedida.")
		return
	_agregar_texto("Solicita aquí la licencia necesaria para portar y comprar espadas.")
	var solicitar := Button.new()
	solicitar.text = "Solicitar licencia · %d monedas" % PRECIO_LICENCIA_ESPADA
	solicitar.disabled = GameState.obtener_dinero() < PRECIO_LICENCIA_ESPADA
	solicitar.pressed.connect(_solicitar_licencia)
	_contenido.add_child(solicitar)
	PIXEL_UI_THEME.apply(solicitar, false)


func _construir_cuartel_armas() -> void:
	if not bool(GameState.world_state.flags.get("licencia_espadas", false)):
		_agregar_texto("Necesitas obtener primero tu licencia en la mesa de solicitudes.")
		return
	_agregar_texto("Licencia verificada. Puedes adquirir estas armas:")
	_agregar_boton_arma("Espada de Madera", ITEM_ESPADA_MADERA, PRECIO_ESPADA_MADERA)
	_agregar_boton_arma("Espada de Piedra", ITEM_ESPADA_PIEDRA, PRECIO_ESPADA_PIEDRA)


func _solicitar_licencia() -> void:
	if not GameState.modificar_dinero(-PRECIO_LICENCIA_ESPADA):
		_mostrar_estado("No tienes suficientes monedas.")
		return
	GameState.world_state.flags["licencia_espadas"] = true
	GameState.call_deferred("_ejecutar_guardado_rapido")
	_mostrar_estado("Licencia de espadas concedida y guardada en esta partida.")
	_actualizar()


func _agregar_boton_arma(nombre: String, item_id: String, precio: int) -> void:
	var fila := HBoxContainer.new()
	_contenido.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = "%s · %d monedas" % [nombre, precio]
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	var boton := Button.new()
	boton.text = "Comprar"
	boton.disabled = GameState.obtener_dinero() < precio or not is_instance_valid(_world_items)
	boton.pressed.connect(_comprar_arma.bind(item_id, precio))
	fila.add_child(boton)
	PIXEL_UI_THEME.apply(boton, false)


func _comprar_arma(item_id: String, precio: int) -> void:
	if not bool(GameState.world_state.flags.get("licencia_espadas", false)) or not is_instance_valid(_world_items) or not is_instance_valid(_inventario):
		return
	var objeto := _world_items.buscar_item_por_id(item_id)
	if objeto.is_empty():
		_mostrar_estado("El arma no está disponible en el catálogo.")
		return
	if not GameState.modificar_dinero(-precio):
		_mostrar_estado("No tienes suficientes monedas.")
		return
	objeto["cantidad"] = 1
	if not _inventario.agregar_objeto_desde_ui(objeto):
		GameState.modificar_dinero(precio)
		_mostrar_estado("No tienes espacio en el inventario. Se revirtió el pago.")
		return
	_mostrar_estado("Compraste %s." % str(objeto.get("nombre", "el arma")))
	_actualizar()


func _contar_item(item_id: String) -> int:
	if not is_instance_valid(_inventario):
		return 0
	var total := 0
	for objeto_variant in _inventario.runtime.state.items:
		if not objeto_variant is Dictionary:
			continue
		var objeto := objeto_variant as Dictionary
		if str(objeto.get("item_id", objeto.get("id", ""))) == item_id:
			total += int(objeto.get("cantidad", 1))
	return total


func _consumir_item_total(item_id: String, cantidad: int) -> bool:
	if not is_instance_valid(_inventario) or cantidad <= 0 or _contar_item(item_id) < cantidad:
		return false
	var restante := cantidad
	for indice in range(_inventario.runtime.state.items.size()):
		if restante <= 0:
			break
		var objeto: Dictionary = _inventario.runtime.state.items[indice]
		if str(objeto.get("item_id", objeto.get("id", ""))) != item_id or objeto.is_empty():
			continue
		var disponible := maxi(1, int(objeto.get("cantidad", 1)))
		var retirar := mini(restante, disponible)
		if not _inventario.quitar_cantidad_desde_ui(indice, retirar):
			return false
		restante -= retirar
	return restante == 0


func _buscar_slot_item(item_id: String) -> int:
	if not is_instance_valid(_inventario):
		return -1
	for indice in range(_inventario.runtime.state.items.size()):
		var objeto: Dictionary = _inventario.runtime.state.items[indice]
		if str(objeto.get("item_id", objeto.get("id", ""))) == item_id and not objeto.is_empty():
			return indice
	return -1


func _agregar_texto(texto: String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(etiqueta)


func _mostrar_estado(texto: String) -> void:
	if is_instance_valid(_estado):
		_estado.text = texto
		Events.notification_pushed.emit(texto)


func cerrar_interfaz() -> void:
	if is_instance_valid(_jugador):
		_jugador.set_physics_process(_jugador_fisica_previa)
		_jugador.set_process_input(_jugador_input_previo)
		_jugador.set_process_unhandled_input(_jugador_unhandled_previo)
	if is_in_group("modal_ui"):
		remove_from_group("modal_ui")
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cerrar_interfaz()
		get_viewport().set_input_as_handled()
