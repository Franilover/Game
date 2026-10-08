@tool
extends Node2D

const TILE_SIZE: int = 32
const GRASS_TEXTURE_PATH: String = "res://assets/tilesets/Pradera.png"

var tilemap: TileMapDual
var terreno_seleccionado: int = 1
var selector: OptionButton
var estado_label: Label


func _ready() -> void:
    var escena_tilemap := get_node("TileMapDual") as TileMapDual
    if escena_tilemap == null:
        push_error("TileMapDualTest: falta el nodo TileMapDual de la escena")
        return

    # El renderer de TileMapDual se construye durante _ready() a partir del
    # TileSet existente. Reemplazar el TileSet después de ese punto obliga al
    # addon a reconstruir sus DisplayLayer de forma diferida y deja al
    # laboratorio en un estado distinto al de Aventura.
    #
    # Creamos el TileMapDual de prueba con su TileSet definitivo ANTES de
    # entrar al árbol. Así su _ready() construye directamente el renderer
    # correcto y el laboratorio prueba exactamente el mismo pipeline.
    tilemap = TileMapDual.new()
    tilemap.name = "TileMapDualRuntime"
    tilemap.material = escena_tilemap.material
    tilemap.tile_set = _crear_tileset_grass()
    tilemap.godot_4_3_compatibility = false
    add_child(tilemap)
    escena_tilemap.queue_free()

    call_deferred("_preparar_prueba")
    _crear_menu_prueba()


func _preparar_prueba() -> void:
    if tilemap == null or tilemap.tile_set == null:
        return

    # El TileSet ya fue asignado antes de que TileMapDual entrara al árbol.
    # Sólo esperamos a que termine su inicialización normal.
    await get_tree().process_frame
    _dibujar_prueba()


func _dibujar_prueba() -> void:
    if tilemap == null or tilemap.tile_set == null:
        return

    tilemap.clear()

    for y in range(-5, 6):
        for x in range(-8, 9):
            tilemap.draw_cell(Vector2i(x, y), 1)

    _refrescar_dual(tilemap.get_used_cells())

func _refrescar_dual(celdas: Array[Vector2i]) -> void:
    if celdas.is_empty():
        return
    tilemap._update_cells(celdas, false)


func _crear_tileset_grass() -> TileSet:
    var grass_texture: Texture2D = load(GRASS_TEXTURE_PATH) as Texture2D
    var dirt_texture: Texture2D = load("res://assets/tilesets/Tierra.png") as Texture2D

    if grass_texture == null or dirt_texture == null:
        push_error("TileMapDualTest: no se pudieron cargar Pradera.png y Tierra.png")
        return TileSet.new()

    var tile_set: TileSet = TileSet.new()
    tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
    tile_set.add_terrain_set()
    tile_set.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)

    tile_set.add_terrain(0)
    tile_set.set_terrain_name(0, 0, "<any>")
    tile_set.add_terrain(0)
    tile_set.set_terrain_name(0, 1, "Pradera")
    tile_set.add_terrain(0)
    tile_set.set_terrain_name(0, 2, "Tierra")
    tile_set.add_terrain(0)
    tile_set.set_terrain_name(0, 3, "Bosque")
    tile_set.add_terrain(0)
    tile_set.set_terrain_name(0, 4, "Desierto")

    var sequence: Array[Vector2i] = [
        Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2),
        Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1),
        Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2),
        Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1),
    ]

    var neighbors: Array[TileSet.CellNeighbor] = [
        TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
        TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
        TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
        TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
    ]

    var bosque_texture: Texture2D = load("res://assets/tilesets/Bosque.png") as Texture2D
    var desierto_texture: Texture2D = load("res://assets/tilesets/Desierto.png") as Texture2D

    if bosque_texture == null or desierto_texture == null:
        push_error("TileMapDualTest: no se pudieron cargar Bosque.png y Desierto.png")
        return tile_set

    var configs: Array[Dictionary] = [
        {"texture": grass_texture, "terrain": 1, "source_id": 1},
        {"texture": dirt_texture, "terrain": 2, "source_id": 2},
        {"texture": bosque_texture, "terrain": 3, "source_id": 3},
        {"texture": desierto_texture, "terrain": 4, "source_id": 4},
    ]

    for config_variant in configs:
        var config: Dictionary = config_variant
        var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
        atlas.texture = config["texture"] as Texture2D
        atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

        for sequence_pos in sequence:
            atlas.create_tile(sequence_pos)

        for index in range(sequence.size()):
            var data: TileData = atlas.get_tile_data(sequence[index], 0)
            data.terrain_set = 0
            data.terrain = int(config["terrain"])

            var bits: int = index
            for neighbor in neighbors:
                var terrain: int = int(config["terrain"]) if (bits & 1) != 0 else 0
                data.set_terrain_peering_bit(neighbor, terrain)
                bits >>= 1

        tile_set.add_source(atlas, int(config["source_id"]))

    return tile_set

func _crear_menu_prueba() -> void:
    var panel := PanelContainer.new()
    panel.name = "MenuAssets"
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.position = Vector2(-230, 20)
    panel.size = Vector2(210, 330)
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    margin.add_child(box)

    var title := Label.new()
    title.text = "LABORATORIO — TERRENOS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    selector = OptionButton.new()
    selector.name = "SelectorTerreno"
    selector.add_item("Pradera", 1)
    selector.add_item("Tierra", 2)
    selector.add_item("Bosque", 3)
    selector.add_item("Desierto", 4)
    selector.selected = 0
    selector.item_selected.connect(_seleccionar_terreno)
    box.add_child(selector)

    var separador := HSeparator.new()
    box.add_child(separador)

    var limpiar := Button.new()
    limpiar.text = "Limpiar mapa"
    limpiar.pressed.connect(_limpiar_mapa)
    box.add_child(limpiar)

    var bloque := Button.new()
    bloque.text = "Rellenar con seleccionado"
    bloque.pressed.connect(_rellenar_seleccionado)
    box.add_child(bloque)

    var mezcla := Button.new()
    mezcla.text = "Generar mezcla aleatoria"
    mezcla.pressed.connect(_generar_mezcla)
    box.add_child(mezcla)

    estado_label = Label.new()
    estado_label.text = "Seleccionado: Pradera"
    estado_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(estado_label)

    var copiar_logs := Button.new()
    copiar_logs.text = "Copiar logs"
    copiar_logs.pressed.connect(_copiar_logs)
    box.add_child(copiar_logs)

    var copiar_render := Button.new()
    copiar_render.text = "Copiar render"
    copiar_render.pressed.connect(_copiar_render)
    box.add_child(copiar_render)

    var ayuda := Label.new()
    ayuda.text = "Click izquierdo: pintar\\nClick derecho: borrar\\nCopiar render: imagen al portapapeles"
    ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(ayuda)


func _copiar_logs() -> void:
    var lineas: Array[String] = []
    lineas.append("=== TILEMAP DUAL LAB ===")
    lineas.append("Terreno seleccionado: %d (%s)" % [
        terreno_seleccionado,
        selector.get_item_text(selector.selected) if selector != null else "?"
    ])
    lineas.append("TileMapDual: %s" % ("OK" if tilemap != null else "NULL"))
    lineas.append("TileSet: %s" % ("OK" if tilemap != null and tilemap.tile_set != null else "NULL"))

    if tilemap != null:
        var celdas := tilemap.get_used_cells()
        lineas.append("Celdas usadas: %d" % celdas.size())
        lineas.append("Rect usado: %s" % str(tilemap.get_used_rect()))
        var conteo := {}
        for cell in celdas:
            var terrain := tilemap.get_cell_terrain_set(cell)
            var terrain_id := tilemap.get_cell_terrain(cell)
            var key := "%d/%d" % [terrain, terrain_id]
            conteo[key] = int(conteo.get(key, 0)) + 1
        lineas.append("Terrenos registrados por celda: %s" % str(conteo))

    lineas.append("Atlas TILE_SEQUENCE:")
    lineas.append(str([
        Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2),
        Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1),
        Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2),
        Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1),
    ]))
    lineas.append("Atlas: Pradera.png / Tierra.png / Bosque.png / Desierto.png")
    lineas.append("Tile size: %d" % TILE_SIZE)
    DisplayServer.clipboard_set("\n".join(lineas))
    estado_label.text = "Logs copiados al portapapeles"


func _copiar_render() -> void:
    var image := get_viewport().get_texture().get_image()
    if image == null:
        estado_label.text = "No se pudo capturar el render"
        return

    var path := "user://tilemap_dual_lab_render.png"
    var error := image.save_png(path)
    if error != OK:
        estado_label.text = "Error guardando render: %s" % error
        return

    var absolute_path := ProjectSettings.globalize_path(path)
    var command := "command -v wl-copy >/dev/null 2>&1 && wl-copy --type image/png < \"%s\"" % absolute_path
    var exit_code := OS.execute("sh", ["-c", command], [], true)

    if exit_code == 0:
        estado_label.text = "Render copiado al portapapeles"
    else:
        estado_label.text = "Render guardado en user://tilemap_dual_lab_render.png (wl-copy no disponible)"


func _seleccionar_terreno(index: int) -> void:
    terreno_seleccionado = selector.get_item_id(index)
    estado_label.text = "Seleccionado: " + selector.get_item_text(index)


func _limpiar_mapa() -> void:
    if tilemap == null:
        return
    tilemap.clear()
    _refrescar_dual(tilemap.get_used_cells())


func _rellenar_seleccionado() -> void:
    if tilemap == null:
        return
    var celdas: Array[Vector2i] = []
    for y in range(-5, 6):
        for x in range(-8, 9):
            var cell := Vector2i(x, y)
            tilemap.draw_cell(cell, terreno_seleccionado)
            celdas.append(cell)
    _refrescar_dual(celdas)


func _generar_mezcla() -> void:
    if tilemap == null:
        return
    tilemap.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = 48127
    var celdas: Array[Vector2i] = []
    for y in range(-5, 6):
        for x in range(-8, 9):
            var cell := Vector2i(x, y)
            var roll := rng.randf()
            var terrain := 1
            if roll < 0.12:
                terrain = 2
            elif roll < 0.24:
                terrain = 3
            elif roll < 0.36:
                terrain = 4
            tilemap.draw_cell(cell, terrain)
            celdas.append(cell)
    _refrescar_dual(celdas)

func _unhandled_input(event: InputEvent) -> void:
    if tilemap == null:
        return

    if not event is InputEventMouseButton:
        return

    var mouse_event: InputEventMouseButton = (
        event as InputEventMouseButton
    )

    if not mouse_event.pressed:
        return

    var world_position: Vector2 = (
        get_global_mouse_position()
    )

    var cell: Vector2i = tilemap.local_to_map(
        tilemap.to_local(world_position)
    )

    if mouse_event.button_index == MOUSE_BUTTON_LEFT:
        tilemap.draw_cell(cell, terreno_seleccionado)
        _refrescar_dual([cell])
    elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
        tilemap.draw_cell(cell, 0)
        _refrescar_dual([cell])
