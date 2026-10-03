@tool
extends Node2D

const TILE_SIZE: int = 32
const GRASS_TEXTURE_PATH: String = "res://assets/tilesets/Grass.png"

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

    # Mancha principal de grass para probar las 15 configuraciones.
    for y in range(-5, 6):
        for x in range(-8, 9):
            if abs(x) == 8 and abs(y) >= 4:
                continue
            tilemap.draw_cell(Vector2i(x, y), 1)

    # Entrantes y huecos para forzar esquinas y transiciones diferentes.
    for cell_variant in [
        Vector2i(-4, -5),
        Vector2i(-3, -5),
        Vector2i(3, -5),
        Vector2i(4, -5),
        Vector2i(-8, 0),
        Vector2i(-8, 1),
        Vector2i(7, 2),
        Vector2i(7, 3),
    ]:
        var cell: Vector2i = cell_variant
        tilemap.draw_cell(cell, 0)


func _crear_tileset_grass() -> TileSet:
    var texture: Texture2D = load(
        GRASS_TEXTURE_PATH
    ) as Texture2D

    if texture == null:
        push_error(
            "TileMapDualTest: no se pudo cargar "
            + GRASS_TEXTURE_PATH
        )
        return TileSet.new()

    var tile_set: TileSet = TileSet.new()
    tile_set.tile_size = Vector2i(
        TILE_SIZE,
        TILE_SIZE
    )

    var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
    atlas.texture = texture
    atlas.texture_region_size = Vector2i(
        TILE_SIZE,
        TILE_SIZE
    )

    for y in range(4):
        for x in range(4):
            atlas.create_tile(
                Vector2i(x, y)
            )

    tile_set.add_source(
        atlas,
        0
    )

    tile_set.add_terrain_set()
    tile_set.set_terrain_set_mode(
        0,
        TileSet.TERRAIN_MODE_MATCH_CORNERS
    )

    tile_set.add_terrain(0)
    tile_set.set_terrain_name(
        0,
        0,
        "<any>"
    )

    tile_set.add_terrain(0)
    tile_set.set_terrain_name(
        0,
        1,
        "Grass"
    )

    var sequence: Array[Vector2i] = [
        Vector2i(0, 3),
        Vector2i(3, 3),
        Vector2i(0, 2),
        Vector2i(1, 2),
        Vector2i(0, 0),
        Vector2i(3, 2),
        Vector2i(2, 3),
        Vector2i(3, 1),
        Vector2i(1, 3),
        Vector2i(0, 1),
        Vector2i(1, 0),
        Vector2i(2, 2),
        Vector2i(3, 0),
        Vector2i(2, 0),
        Vector2i(1, 1),
        Vector2i(2, 1),
    ]

    var neighbors: Array[TileSet.CellNeighbor] = [
        TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
        TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
        TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
        TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
    ]

    for index in range(sequence.size()):
        var data: TileData = atlas.get_tile_data(
            sequence[index],
            0
        )

        data.terrain_set = 0

        var bits: int = index
        for neighbor_index in range(neighbors.size()):
            var neighbor: TileSet.CellNeighbor = neighbors[neighbor_index]
            var terrain: int = 1 if (bits & 1) != 0 else 0
            data.set_terrain_peering_bit(
                neighbor,
                terrain
            )
            bits >>= 1

    atlas.get_tile_data(
        Vector2i(0, 3),
        0
    ).terrain = 0

    atlas.get_tile_data(
        Vector2i(2, 1),
        0
    ).terrain = 1

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
    elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
        tilemap.draw_cell(cell, 0)
