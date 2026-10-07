@tool
extends Node2D

const TILE_SIZE: int = 32
const GRASS_TEXTURE_PATH: String = "res://assets/tilesets/Pradera.png"

var tilemap: TileMapDual


func _ready() -> void:
    tilemap = get_node("TileMapDual") as TileMapDual
    call_deferred("_preparar_prueba")


func _preparar_prueba() -> void:
    if tilemap == null:
        return

    if tilemap.tile_set == null:
        tilemap.tile_set = _crear_tileset_grass()

    # El TileMapDual necesita un frame para construir el watcher,
    # leer las peering bits del atlas y generar las reglas DualGrid.
    await get_tree().process_frame
    tilemap._changed()
    await get_tree().process_frame
    _dibujar_prueba()


func _dibujar_prueba() -> void:
    if tilemap == null or tilemap.tile_set == null:
        return

    tilemap.clear()

    # Prueba mixta: cuatro terrenos para comparar si el problema es específico
    # de Tierra o de la integración de un terrain distinto de Pradera.
    var rng := RandomNumberGenerator.new()
    rng.seed = 48127

    var celdas: Array[Vector2i] = []
    for y in range(-5, 6):
        for x in range(-8, 9):
            var cell := Vector2i(x, y)
            var terrain := 1
            var roll := rng.randf()
            if roll < 0.12:
                terrain = 2
            elif roll < 0.24:
                terrain = 3
            elif roll < 0.36:
                terrain = 4
            tilemap.draw_cell(cell, terrain)
            celdas.append(cell)

    _refrescar_dual(celdas)

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
    tile_set.set_terrain_name(0, 1, "Grass")
    tile_set.add_terrain(0)
    tile_set.set_terrain_name(0, 2, "Dirt")

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
        tilemap.draw_cell(cell, 1)
        _refrescar_dual([cell])
    elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
        tilemap.draw_cell(cell, 0)
        _refrescar_dual([cell])
