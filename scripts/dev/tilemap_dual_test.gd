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
    var canvas_layer := CanvasLayer.new()
    canvas_layer.name = "LabUI"
    add_child(canvas_layer)

    var panel := PanelContainer.new()
    panel.name = "MenuAssets"
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.position = Vector2(20, 20)
    panel.size = Vector2(210, 360)
    canvas_layer.add_child(panel)

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

    var copiar_diagnostico := Button.new()
    copiar_diagnostico.text = "Copiar diagnóstico visual"
    copiar_diagnostico.pressed.connect(_copiar_diagnostico_visual)
    box.add_child(copiar_diagnostico)

    var ayuda := Label.new()
    ayuda.text = "Click izquierdo: pintar\\nClick derecho: borrar\\nDiagnóstico visual: texto del render"
    ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(ayuda)


func _copiar_logs() -> void:
    var lineas: Array[String] = []
    lineas.append("=== TILEMAP DUAL LAB ===")
    lineas.append("Terreno seleccionado: %d (%s)" % [terreno_seleccionado, selector.get_item_text(selector.selected) if selector != null else "?"])
    lineas.append("TileMapDual: %s" % ("OK" if tilemap != null else "NULL"))
    lineas.append("TileSet: %s" % ("OK" if tilemap != null and tilemap.tile_set != null else "NULL"))
    if tilemap != null:
        var celdas := tilemap.get_used_cells()
        lineas.append("Celdas usadas: %d" % celdas.size())
        lineas.append("Rect usado: %s" % str(tilemap.get_used_rect()))
        var conteo := {}
        for cell in celdas:
            var terrain_id: int = tilemap.get_cell(cell)
            var key := "0/%d" % terrain_id
            conteo[key] = int(conteo.get(key, 0)) + 1
        lineas.append("Terrenos registrados por celda: %s" % str(conteo))
    lineas.append("Atlas TILE_SEQUENCE:")
    lineas.append(str([Vector2i(0, 3), Vector2i(3, 3), Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 0), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 1), Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 2), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)]))
    lineas.append("Atlas: Pradera.png / Tierra.png / Bosque.png / Desierto.png")
    lineas.append("Tile size: %d" % TILE_SIZE)
    DisplayServer.clipboard_set("\n".join(lineas))
    estado_label.text = "Logs copiados al portapapeles"


func _copiar_diagnostico_visual() -> void:
    if tilemap == null or tilemap.tile_set == null:
        estado_label.text = "No hay TileMapDual para diagnosticar"
        return

    var lineas: Array[String] = []
    lineas.append("=== DIAGNOSTICO VISUAL TILEMAP DUAL ===")
    lineas.append("Este informe describe los tiles que realmente usa cada DisplayLayer.")
    lineas.append("No es una captura: muestra coordenada, source_id y coordenada del atlas.")
    lineas.append("")

    var terrain_names: Dictionary = {
        1: "Pradera",
        2: "Tierra",
        3: "Bosque",
        4: "Desierto",
    }

    var world_cells: Array[Vector2i] = tilemap.get_used_cells()
    lineas.append("=== TERRENO LOGICO DEL MUNDO ===")
    if world_cells.is_empty():
        lineas.append("(sin celdas)")
    else:
        var rect: Rect2i = tilemap.get_used_rect()
        lineas.append("Rect: %s" % str(rect))
        for y in range(rect.position.y, rect.end.y):
            var row: String = ""
            for x in range(rect.position.x, rect.end.x):
                var terrain_id: int = tilemap.get_cell(Vector2i(x, y))
                row += _terrain_symbol(terrain_id)
            lineas.append(row)
    lineas.append("")
    lineas.append("Leyenda: P=Pradera T=Tierra B=Bosque D=Desierto .=vacío")
    lineas.append("")

    lineas.append("=== DISPLAYLAYERS REALES ===")
    var display_layer_count: int = 0
    for child in tilemap.get_children():
        if not child is TileMapLayer:
            continue
        var display_layer: TileMapLayer = child as TileMapLayer
        display_layer_count += 1
        lineas.append("Capa: %s" % display_layer.name)
        var cells: Array[Vector2i] = display_layer.get_used_cells()
        lineas.append("  Celdas visibles: %d" % cells.size())
        var atlas_counts: Dictionary = {}
        for cell in cells:
            var source_id: int = display_layer.get_cell_source_id(cell)
            var atlas_coords: Vector2i = display_layer.get_cell_atlas_coords(cell)
            var key: String = "%d:%s" % [source_id, str(atlas_coords)]
            atlas_counts[key] = int(atlas_counts.get(key, 0)) + 1
        for key in atlas_counts.keys():
            var usage_count: int = int(atlas_counts[key])
            lineas.append("  %s -> %d usos" % [key, usage_count])
        lineas.append("  Detalle:")
        for cell in cells:
            var source_id: int = display_layer.get_cell_source_id(cell)
            var atlas_coords: Vector2i = display_layer.get_cell_atlas_coords(cell)
            var terrain_name: String = str(terrain_names.get(source_id, "source_%d" % source_id))
            lineas.append("    celda=%s terreno=%s source=%d atlas=%s" % [str(cell), terrain_name, source_id, str(atlas_coords)])
        lineas.append("")

    if display_layer_count == 0:
        lineas.append("(No se encontraron DisplayLayers.)")

    var renderer_diag: Dictionary = tilemap.obtener_diagnostico()
    lineas.append("=== METRICAS DEL RENDERER ===")
    lineas.append(str(renderer_diag))

    DisplayServer.clipboard_set("\n".join(lineas))
    estado_label.text = "Diagnóstico visual copiado al portapapeles"


func _terrain_symbol(terrain_id: int) -> String:
    match terrain_id:
        1:
            return "P"
        2:
            return "T"
        3:
            return "B"
        4:
            return "D"
        _:
            return "."


