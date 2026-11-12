extends Control
class_name AdminInventory

const PIXEL_UI_THEME: Script = preload("res://scripts/ui/pixel_ui_theme.gd")

var _jugador: Player = null
var _world_entity_spawner: WorldEntitySpawner = null
var _inventario: GarliaInventory = null
var _world_items: GarliaWorldItems = null
var _modo: String = "criaturas"
var _seleccion: Dictionary = {}
var _lista: VBoxContainer
var _detalle: VBoxContainer
var _titulo: Label
var _estado: Label
var _cantidad: SpinBox
var _boton_accion: Button
var _botones: Dictionary = {}
var _contenido_catalogo: HBoxContainer
var _panel_tiempo: ScrollContainer
var _atmosfera: WorldAtmosphere = null
var _estado_tiempo: Label
var _estado_tiempo_accion: Label
var _boton_bloqueo_tiempo: Button
var _botones_velocidad_tiempo: Dictionary = {}
var _hora_spin: SpinBox
var _minuto_spin: SpinBox
var _dias_spin: SpinBox
var _estacion_selector: OptionButton
var _anio_spin: SpinBox


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_crear_ui()
	PIXEL_UI_THEME.apply(self, false)
	visible = false


func configurar(jugador: Player, spawner: WorldEntitySpawner, inventario: GarliaInventory, world_items: GarliaWorldItems = null) -> void:
	_jugador = jugador
	_world_entity_spawner = spawner
	_inventario = inventario
	_world_items = world_items


func configurar_tiempo(atmosfera: WorldAtmosphere) -> void:
	_atmosfera = atmosfera
	if is_instance_valid(_atmosfera):
		if not _atmosfera.dia_cambiado.is_connected(_al_cambio_calendario):
			_atmosfera.dia_cambiado.connect(_al_cambio_calendario)
		if not _atmosfera.estacion_cambiada.is_connected(_al_cambio_estacion):
			_atmosfera.estacion_cambiada.connect(_al_cambio_estacion)
	if WorldData.has_signal("mundo_listo") and not WorldData.mundo_listo.is_connected(_al_calendario_disponible):
		WorldData.mundo_listo.connect(_al_calendario_disponible)
	_actualizar_panel_tiempo()


func abrir(jugador: Node = null) -> void:
	if jugador != null:
		_jugador = jugador
	_actualizar_visibilidad()


func _es_admin() -> bool:
	if _jugador == null or not is_instance_valid(_jugador):
		return false

	var datos_variant: Variant = GameState.obtener_configuracion_personaje_admin()
	if not datos_variant is Dictionary:
		return false

	return str((datos_variant as Dictionary).get("rol", "explorador")).to_lower() == "admin"


func _actualizar_visibilidad() -> void:
	var activo := _es_admin()
	visible = activo
	if not activo:
		return

	if _botones.has("tiempo"):
		(_botones["tiempo"] as Button).disabled = not _puede_controlar_tiempo()
	_cargar_lista()
	_actualizar_panel_tiempo()


func _crear_ui() -> void:
	var titulo_columna := VBoxContainer.new()
	titulo_columna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titulo_columna.add_theme_constant_override("separation", 4)
	add_child(titulo_columna)

	var encabezado := HBoxContainer.new()
	encabezado.add_theme_constant_override("separation", 3)
	titulo_columna.add_child(encabezado)

	for entrada in [["criaturas", "Criaturas"], ["objetos", "Objetos"], ["tiempo", "Tiempo"]]:
		var boton := Button.new()
		boton.text = str(entrada[1])
		boton.toggle_mode = true
		boton.custom_minimum_size = Vector2(0, 24)
		boton.pressed.connect(_cambiar_modo.bind(str(entrada[0])))
		PIXEL_UI_THEME.apply(boton, false)
		encabezado.add_child(boton)
		_botones[str(entrada[0])] = boton

	var contenido := HBoxContainer.new()
	_contenido_catalogo = contenido
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_theme_constant_override("separation", 5)
	titulo_columna.add_child(contenido)

	var izquierda := VBoxContainer.new()
	izquierda.custom_minimum_size = Vector2(90, 0)
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izquierda.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(izquierda)

	var scroll := ScrollContainer.new()
	scroll.name = "CreatureObjectListScroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	izquierda.add_child(scroll)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.custom_minimum_size = Vector2(0, 300)
	_lista.add_theme_constant_override("separation", 2)
	scroll.add_child(_lista)

	var scroll_detalle := ScrollContainer.new()
	scroll_detalle.name = "CreatureObjectDetailScroll"
	scroll_detalle.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_detalle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_detalle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_detalle.follow_focus = false
	contenido.add_child(scroll_detalle)

	_detalle = VBoxContainer.new()
	_detalle.custom_minimum_size = Vector2(90, 0)
	_detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalle.add_theme_constant_override("separation", 4)
	scroll_detalle.add_child(_detalle)

	_estado = Label.new()
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.add_child(_estado)

	_boton_accion = Button.new()
	_boton_accion.custom_minimum_size = Vector2(0, 26)
	_boton_accion.pressed.connect(_ejecutar_accion)
	_detalle.add_child(_boton_accion)

	_cantidad = SpinBox.new()
	_cantidad.min_value = 1
	_cantidad.max_value = 999
	_cantidad.step = 1
	_cantidad.value = 1
	_cantidad.custom_minimum_size = Vector2(0, 24)
	_cantidad.visible = false
	_detalle.add_child(_cantidad)

	_crear_panel_tiempo(titulo_columna)
	_cambiar_modo("criaturas")


func _cambiar_modo(modo: String) -> void:
	if modo == "tiempo" and not _puede_controlar_tiempo():
		return

	_modo = modo
	for clave in _botones:
		var boton: Button = _botones[clave]
		boton.button_pressed = clave == _modo

	var es_tiempo := _modo == "tiempo"
	_contenido_catalogo.visible = not es_tiempo
	_panel_tiempo.visible = es_tiempo
	if es_tiempo:
		_actualizar_panel_tiempo()
		return

	_seleccion.clear()
	_cargar_lista()
	_mostrar_detalle()


func _limpiar_lista() -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()


func _cargar_lista() -> void:
	if _lista == null:
		return

	_limpiar_lista()

	if _modo == "criaturas":
		_cargar_criaturas()
	else:
		_cargar_objetos()


func _cargar_criaturas() -> void:
	var criaturas: Array[Dictionary] = WorldData.obtener_criaturas()
	criaturas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()
	)

	for criatura in criaturas:
		_crear_fila(
			str(criatura.get("nombre", "Criatura")),
			criatura
		)


func _cargar_objetos() -> void:
	if _world_items == null or not is_instance_valid(_world_items):
		var aviso := Label.new()
		aviso.text = "No se encontró el catálogo de objetos."
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(aviso)
		return

	var catalogo: Array[Dictionary] = _world_items.obtener_catalogo()
	var grupos: Dictionary = {}

	for item in catalogo:
		var grupo := _obtener_grupo_objeto(item)
		if not grupos.has(grupo):
			grupos[grupo] = []
		grupos[grupo].append(item)

	var claves: Array = grupos.keys()
	claves.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(a).to_lower() < str(b).to_lower()
	)

	for grupo in claves:
		var separador := Label.new()
		separador.text = str(grupo)
		separador.add_theme_font_size_override("font_size", 12)
		_lista.add_child(separador)

		var objetos: Array = grupos[grupo]
		objetos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("nombre", "")).to_lower() < str(b.get("nombre", "")).to_lower()
		)

		for item in objetos:
			_crear_fila(str(item.get("nombre", "Objeto")), item)


func _obtener_grupo_objeto(item: Dictionary) -> String:
	var tags_variant: Variant = item.get("tags", item.get("etiquetas", null))

	if tags_variant is Array:
		var tags := tags_variant as Array
		if not tags.is_empty():
			return str(tags[0])

	if tags_variant is String and not str(tags_variant).strip_edges().is_empty():
		return str(tags_variant).strip_edges()

	var propiedades_variant: Variant = item.get("propiedades_game", {})
	if propiedades_variant is Dictionary:
		var propiedades := propiedades_variant as Dictionary
		for clave in ["categoria", "tipo", "grupo"]:
			var valor := str(propiedades.get(clave, "")).strip_edges()
			if not valor.is_empty():
				return valor

	for clave in ["categoria", "tipo", "tipo_item", "grupo"]:
		var valor := str(item.get(clave, "")).strip_edges()
		if not valor.is_empty():
			return valor

	return "Otros"


func _crear_fila(nombre: String, datos: Dictionary) -> void:
	var boton := Button.new()
	boton.text = nombre
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.custom_minimum_size = Vector2(0, 34)
	boton.pressed.connect(_seleccionar.bind(datos))
	PIXEL_UI_THEME.apply(boton, false)
	_lista.add_child(boton)


func _seleccionar(datos: Dictionary) -> void:
	_seleccion = datos.duplicate(true)
	_mostrar_detalle()


func _limpiar_detalle() -> void:
	for hijo in _detalle.get_children():
		if hijo == _estado or hijo == _boton_accion or hijo == _cantidad:
			continue
		hijo.queue_free()


func _mostrar_detalle() -> void:
	if _detalle == null:
		return

	_limpiar_detalle()

	if _seleccion.is_empty():
		_estado.text = "Selecciona un elemento para ver su información."
		_boton_accion.disabled = true
		_cantidad.visible = false
		return

	var nombre := str(_seleccion.get("nombre", "Elemento"))
	var descripcion := str(_seleccion.get("descripcion", "Sin descripción."))

	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(120, 120)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if _modo == "criaturas":
		var ruta := "res://assets/art/creatures/" + nombre + ".png"
		if nombre.to_lower() == "humano":
			ruta = "res://assets/art/creatures/Humano.png"
		if ResourceLoader.exists(ruta):
			icono.texture = load(ruta)
	else:
		icono.texture = ItemIconResolver.obtener_icono(_seleccion)

	_detalle.add_child(icono)
	_detalle.move_child(icono, 0)

	var titulo := Label.new()
	titulo.text = nombre
	titulo.add_theme_font_size_override("font_size", 18)
	_detalle.add_child(titulo)
	_detalle.move_child(titulo, 1)

	var info := Label.new()
	info.text = descripcion
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.add_child(info)
	_detalle.move_child(info, 2)

	if _modo == "objetos":
		_cantidad.visible = true
		_boton_accion.text = "Dar al jugador"
	else:
		_cantidad.visible = false
		_boton_accion.text = "Invocar criatura"

	_boton_accion.disabled = false


func _ejecutar_accion() -> void:
	if _seleccion.is_empty():
		return

	if _modo == "criaturas":
		_invocar()
	else:
		_dar_objeto()


func _invocar() -> void:
	var spawner := _world_entity_spawner
	if spawner == null or not is_instance_valid(spawner) or not spawner.has_method("summon_criatura"):
		_estado.text = "No se encontró WorldEntitySpawner."
		return

	var nombre := str(_seleccion.get("nombre", "")).strip_edges()
	var posicion := Vector2.ZERO
	if _jugador is Node2D and is_instance_valid(_jugador):
		posicion = (_jugador as Node2D).global_position
	var resultado: Variant = spawner.call("summon_criatura", nombre, posicion)

	if resultado is Dictionary and bool((resultado as Dictionary).get("ok", false)):
		_estado.text = "Invocada: " + str((resultado as Dictionary).get("nombre", nombre))
	elif resultado is Dictionary:
		_estado.text = str((resultado as Dictionary).get("mensaje", "No se pudo invocar."))
	else:
		_estado.text = "No se pudo invocar."


func _dar_objeto() -> void:
	var jugador := _jugador
	if jugador == null or not is_instance_valid(jugador):
		_estado.text = "No se encontró el jugador."
		return

	var inventario := _inventario
	if inventario == null or not is_instance_valid(inventario) or not inventario.has_method("agregar_objeto"):
		_estado.text = "No se encontró el inventario del jugador."
		return

	var cantidad := maxi(1, int(_cantidad.value))
	var objeto := _seleccion.duplicate(true)
	objeto["cantidad"] = cantidad

	if inventario.call("agregar_objeto_desde_ui", objeto):
		_estado.text = "Añadido: " + str(objeto.get("nombre", "Objeto")) + " x" + str(cantidad)
	else:
		_estado.text = "No hay espacio suficiente en el inventario."

func _puede_controlar_tiempo() -> bool:
	var datos_variant: Variant = GameState.obtener_configuracion_personaje_admin()
	if not datos_variant is Dictionary:
		return false
	var datos := datos_variant as Dictionary
	if str(datos.get("rol", "explorador")).to_lower() != "admin":
		return false
	var capacidades_variant: Variant = datos.get("capacidades", [])
	return capacidades_variant is Array and "controlar_tiempo" in (capacidades_variant as Array)


func _crear_panel_tiempo(contenedor: VBoxContainer) -> void:
	_panel_tiempo = ScrollContainer.new()
	_panel_tiempo.name = "TimeControls"
	_panel_tiempo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_tiempo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_tiempo.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel_tiempo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_tiempo.visible = false
	contenedor.add_child(_panel_tiempo)

	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 7)
	_panel_tiempo.add_child(columna)

	_estado_tiempo = Label.new()
	_estado_tiempo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado_tiempo.add_theme_font_size_override("font_size", 13)
	columna.add_child(_estado_tiempo)

	_boton_bloqueo_tiempo = _crear_boton_tiempo("Bloquear avance del tiempo")
	_boton_bloqueo_tiempo.pressed.connect(_alternar_bloqueo_tiempo)
	columna.add_child(_boton_bloqueo_tiempo)

	columna.add_child(_crear_separador_tiempo("Velocidad del reloj"))
	var fila_velocidad := HBoxContainer.new()
	fila_velocidad.add_theme_constant_override("separation", 5)
	columna.add_child(fila_velocidad)
	for multiplicador in [1, 10, 60]:
		var boton_velocidad := _crear_boton_tiempo("×%d" % multiplicador)
		boton_velocidad.toggle_mode = true
		boton_velocidad.pressed.connect(_establecer_velocidad_tiempo.bind(multiplicador))
		fila_velocidad.add_child(boton_velocidad)
		_botones_velocidad_tiempo[multiplicador] = boton_velocidad

	columna.add_child(_crear_separador_tiempo("Hora del día"))
	var fila_hora := HBoxContainer.new()
	fila_hora.add_theme_constant_override("separation", 5)
	columna.add_child(fila_hora)
	_hora_spin = _crear_spin_tiempo(0, 23, 1)
	_minuto_spin = _crear_spin_tiempo(0, 59, 1)
	fila_hora.add_child(_campo_tiempo("Hora", _hora_spin))
	fila_hora.add_child(_campo_tiempo("Minuto", _minuto_spin))
	var aplicar_hora := _crear_boton_tiempo("Aplicar hora")
	aplicar_hora.pressed.connect(_aplicar_hora_tiempo)
	fila_hora.add_child(aplicar_hora)

	var fila_periodo := HBoxContainer.new()
	fila_periodo.add_theme_constant_override("separation", 5)
	columna.add_child(fila_periodo)
	var boton_dia := _crear_boton_tiempo("Mediodía")
	boton_dia.pressed.connect(_establecer_dia_tiempo)
	fila_periodo.add_child(boton_dia)
	var boton_noche := _crear_boton_tiempo("Medianoche")
	boton_noche.pressed.connect(_establecer_noche_tiempo)
	fila_periodo.add_child(boton_noche)

	columna.add_child(_crear_separador_tiempo("Días"))
	var fila_dias := HBoxContainer.new()
	fila_dias.add_theme_constant_override("separation", 5)
	columna.add_child(fila_dias)
	_dias_spin = _crear_spin_tiempo(1, 36500, 1)
	fila_dias.add_child(_campo_tiempo("Cantidad", _dias_spin))
	var retroceder := _crear_boton_tiempo("Retroceder")
	retroceder.pressed.connect(_desplazar_tiempo.bind(-1))
	fila_dias.add_child(retroceder)
	var avanzar := _crear_boton_tiempo("Avanzar")
	avanzar.pressed.connect(_desplazar_tiempo.bind(1))
	fila_dias.add_child(avanzar)

	columna.add_child(_crear_separador_tiempo("Estación"))
	var fila_estacion := HBoxContainer.new()
	fila_estacion.add_theme_constant_override("separation", 5)
	columna.add_child(fila_estacion)
	_estacion_selector = OptionButton.new()
	_estacion_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_estacion.add_child(_estacion_selector)
	var aplicar_estacion := _crear_boton_tiempo("Cambiar")
	aplicar_estacion.pressed.connect(_aplicar_estacion_tiempo)
	fila_estacion.add_child(aplicar_estacion)

	columna.add_child(_crear_separador_tiempo("Año"))
	var fila_anio := HBoxContainer.new()
	fila_anio.add_theme_constant_override("separation", 5)
	columna.add_child(fila_anio)
	_anio_spin = _crear_spin_tiempo(-100000, 100000, 1)
	fila_anio.add_child(_campo_tiempo("Año", _anio_spin))
	var aplicar_anio := _crear_boton_tiempo("Cambiar año")
	aplicar_anio.pressed.connect(_aplicar_anio_tiempo)
	fila_anio.add_child(aplicar_anio)

	_estado_tiempo_accion = Label.new()
	_estado_tiempo_accion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(_estado_tiempo_accion)


func _crear_separador_tiempo(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 12)
	return etiqueta


func _crear_spin_tiempo(minimo: float, maximo: float, paso: float) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimo
	control.max_value = maximo
	control.step = paso
	control.custom_minimum_size = Vector2(75, 26)
	return control


func _crear_boton_tiempo(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0, 26)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PIXEL_UI_THEME.apply(boton, false)
	return boton


func _campo_tiempo(texto: String, control: Control) -> Control:
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 10)
	columna.add_child(etiqueta)
	columna.add_child(control)
	return columna


func _actualizar_panel_tiempo() -> void:
	if not is_instance_valid(_estado_tiempo):
		return
	if _atmosfera == null or not is_instance_valid(_atmosfera):
		_estado_tiempo.text = "No se encontró el calendario del mundo."
		_boton_bloqueo_tiempo.disabled = true
		return

	var datos := _atmosfera.obtener_tiempo()
	if not bool(datos.get("calendario_cargado", false)):
		_estado_tiempo.text = "Cargando calendario del mundo..."
		_boton_bloqueo_tiempo.disabled = true
		return

	_estado_tiempo.text = "Día %d · %s · Año %d · %s" % [int(datos.get("dia", 1)), str(datos.get("estacion", "—")), int(datos.get("anio", 0)), str(datos.get("hora", "00:00"))]
	_boton_bloqueo_tiempo.disabled = false
	_boton_bloqueo_tiempo.text = "Reanudar avance del tiempo" if _atmosfera.esta_bloqueado() else "Bloquear avance del tiempo"
	var velocidad_actual := _atmosfera.obtener_multiplicador_tiempo()
	for multiplicador in _botones_velocidad_tiempo:
		var boton_velocidad: Button = _botones_velocidad_tiempo[multiplicador]
		boton_velocidad.button_pressed = int(multiplicador) == velocidad_actual
		boton_velocidad.disabled = false
	var minutos_totales := int(floor(float(datos.get("hora_del_dia", 0.0)) * 60.0))
	_hora_spin.max_value = maxi(0, int(ceil(float(datos.get("horas_por_dia", 24.0)))) - 1)
	_hora_spin.value = int(floor(float(minutos_totales) / 60.0))
	_minuto_spin.value = minutos_totales % 60
	_anio_spin.value = int(datos.get("anio", 0))

	var estacion_actual := str(datos.get("estacion_id", ""))
	_estacion_selector.clear()
	for estacion_variant in _atmosfera.estaciones:
		if not estacion_variant is Dictionary:
			continue
		var estacion := estacion_variant as Dictionary
		var id := str(estacion.get("id", ""))
		var nombre := str(estacion.get("nombre", id))
		if id.is_empty():
			continue
		_estacion_selector.add_item(nombre)
		_estacion_selector.set_item_metadata(_estacion_selector.item_count - 1, id)
		if id == estacion_actual:
			_estacion_selector.select(_estacion_selector.item_count - 1)


func _registrar_accion_tiempo(ok: bool, mensaje: String) -> void:
	_estado_tiempo_accion.text = mensaje if ok else "No se pudo aplicar: " + mensaje
	_actualizar_panel_tiempo()


func _establecer_velocidad_tiempo(multiplicador: int) -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_multiplicador_tiempo(multiplicador)
	var mensaje := "Velocidad del reloj: ×%d." % multiplicador
	_registrar_accion_tiempo(ok, mensaje if ok else "Velocidad no admitida.")


func _alternar_bloqueo_tiempo() -> void:
	if _atmosfera == null:
		return
	if _atmosfera.esta_bloqueado():
		_atmosfera.desbloquear_tiempo()
		_registrar_accion_tiempo(true, "El tiempo vuelve a avanzar.")
	else:
		_atmosfera.bloquear_tiempo()
		_registrar_accion_tiempo(true, "El tiempo quedó bloqueado.")


func _aplicar_hora_tiempo() -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_hora_del_dia(int(_hora_spin.value), int(_minuto_spin.value))
	_registrar_accion_tiempo(ok, "Hora actualizada." if ok else "El calendario aún no está cargado.")


func _establecer_dia_tiempo() -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_dia()
	_registrar_accion_tiempo(ok, "Hora establecida al mediodía." if ok else "El calendario aún no está cargado.")


func _establecer_noche_tiempo() -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_noche()
	_registrar_accion_tiempo(ok, "Hora establecida a medianoche." if ok else "El calendario aún no está cargado.")


func _desplazar_tiempo(direccion: int) -> void:
	if _atmosfera == null:
		return
	var cantidad := maxi(1, int(_dias_spin.value)) * direccion
	var ok := _atmosfera.desplazar_dias(cantidad)
	var mensaje := "Se avanzaron %d días." % cantidad if cantidad > 0 else "Se retrocedieron %d días." % absi(cantidad)
	_registrar_accion_tiempo(ok, mensaje if ok else "El calendario aún no está cargado.")


func _aplicar_estacion_tiempo() -> void:
	if _atmosfera == null or _estacion_selector.selected < 0:
		return
	var id := str(_estacion_selector.get_item_metadata(_estacion_selector.selected))
	var ok := _atmosfera.establecer_estacion(id)
	_registrar_accion_tiempo(ok, "Estación actualizada." if ok else "No se pudo cambiar la estación.")


func _aplicar_anio_tiempo() -> void:
	if _atmosfera == null:
		return
	var ok := _atmosfera.establecer_anio(int(_anio_spin.value))
	_registrar_accion_tiempo(ok, "Año actualizado." if ok else "El calendario aún no está cargado.")


func _al_calendario_disponible() -> void:
	_actualizar_panel_tiempo()


func _al_cambio_calendario(_dia_del_anio: int, _anio: int) -> void:
	_actualizar_panel_tiempo()


func _al_cambio_estacion(_estacion: Dictionary) -> void:
	_actualizar_panel_tiempo()
