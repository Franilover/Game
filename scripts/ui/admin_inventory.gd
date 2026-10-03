extends Control
class_name AdminInventory

var _jugador: Node
var _modo: String = "criaturas"
var _seleccion: Dictionary = {}
var _lista: VBoxContainer
var _detalle: VBoxContainer
var _titulo: Label
var _estado: Label
var _cantidad: SpinBox
var _boton_accion: Button
var _botones: Dictionary = {}


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _crear_ui()
    visible = false


func _process(_delta: float) -> void:
    if not visible:
        return

    var jugador := get_tree().get_first_node_in_group("player")
    if jugador != _jugador:
        _jugador = jugador
        _actualizar_visibilidad()


func abrir(jugador: Node = null) -> void:
    if jugador != null:
        _jugador = jugador
    else:
        _jugador = get_tree().get_first_node_in_group("player")

    _actualizar_visibilidad()


func _es_admin() -> bool:
    if _jugador == null or not is_instance_valid(_jugador):
        return false

    var datos_variant: Variant = GameState.flags.get("personaje_admin", {})
    if not datos_variant is Dictionary:
        return false

    return str((datos_variant as Dictionary).get("rol", "explorador")).to_lower() == "admin"


func _actualizar_visibilidad() -> void:
    var activo := _es_admin()
    visible = activo
    if not activo:
        return

    _cargar_lista()


func _crear_ui() -> void:
    var titulo_columna := VBoxContainer.new()
    titulo_columna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    titulo_columna.add_theme_constant_override("separation", 8)
    add_child(titulo_columna)

    var encabezado := HBoxContainer.new()
    encabezado.add_theme_constant_override("separation", 6)
    titulo_columna.add_child(encabezado)

    for entrada in [["criaturas", "Criaturas"], ["objetos", "Objetos"]]:
        var boton := Button.new()
        boton.text = str(entrada[1])
        boton.toggle_mode = true
        boton.custom_minimum_size = Vector2(110, 30)
        boton.pressed.connect(_cambiar_modo.bind(str(entrada[0])))
        encabezado.add_child(boton)
        _botones[str(entrada[0])] = boton

    var contenido := HBoxContainer.new()
    contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
    contenido.add_theme_constant_override("separation", 14)
    titulo_columna.add_child(contenido)

    var izquierda := VBoxContainer.new()
    izquierda.custom_minimum_size = Vector2(300, 0)
    izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    contenido.add_child(izquierda)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    izquierda.add_child(scroll)

    _lista = VBoxContainer.new()
    _lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _lista.custom_minimum_size = Vector2(0, 600)
    _lista.add_theme_constant_override("separation", 3)
    scroll.add_child(_lista)

    _detalle = VBoxContainer.new()
    _detalle.custom_minimum_size = Vector2(280, 0)
    _detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _detalle.add_theme_constant_override("separation", 7)
    contenido.add_child(_detalle)

    _estado = Label.new()
    _estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _detalle.add_child(_estado)

    _boton_accion = Button.new()
    _boton_accion.custom_minimum_size = Vector2(0, 36)
    _boton_accion.pressed.connect(_ejecutar_accion)
    _detalle.add_child(_boton_accion)

    _cantidad = SpinBox.new()
    _cantidad.min_value = 1
    _cantidad.max_value = 999
    _cantidad.step = 1
    _cantidad.value = 1
    _cantidad.custom_minimum_size = Vector2(0, 32)
    _cantidad.visible = false
    _detalle.add_child(_cantidad)

    _cambiar_modo("criaturas")


func _cambiar_modo(modo: String) -> void:
    _modo = modo
    for clave in _botones:
        var boton: Button = _botones[clave]
        boton.button_pressed = clave == _modo

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
    var catalogo: Array[Dictionary] = GarliaWorldItems.catalogo
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
    var generator := get_tree().get_first_node_in_group("world_generator")
    if generator == null or not generator.has_method("summon_criatura"):
        _estado.text = "No se encontró WorldGenerator."
        return

    var nombre := str(_seleccion.get("nombre", "")).strip_edges()
    var resultado: Variant = generator.call("summon_criatura", nombre)

    if resultado is Dictionary and bool((resultado as Dictionary).get("ok", false)):
        _estado.text = "Invocada: " + str((resultado as Dictionary).get("nombre", nombre))
    elif resultado is Dictionary:
        _estado.text = str((resultado as Dictionary).get("mensaje", "No se pudo invocar."))
    else:
        _estado.text = "No se pudo invocar."


func _dar_objeto() -> void:
    var jugador := get_tree().get_first_node_in_group("player")
    if jugador == null:
        _estado.text = "No se encontró el jugador."
        return

    if not jugador.has_method("get_node_or_null"):
        return

    var inventario := jugador.get_node_or_null("Inventory")
    if inventario == null:
        inventario = get_tree().get_first_node_in_group("inventory")

    if inventario == null or not inventario.has_method("agregar_objeto"):
        _estado.text = "No se encontró el inventario del jugador."
        return

    var cantidad := maxi(1, int(_cantidad.value))
    var objeto := _seleccion.duplicate(true)
    objeto["cantidad"] = cantidad

    if inventario.call("agregar_objeto", objeto):
        _estado.text = "Añadido: " + str(objeto.get("nombre", "Objeto")) + " x" + str(cantidad)
    else:
        _estado.text = "No hay espacio suficiente en el inventario."


