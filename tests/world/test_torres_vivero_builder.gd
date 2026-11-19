extends Node

const BUILDER = preload("res://scripts/world/torres_vivero_builder.gd")
const WATERING_SCRIPT = preload("res://scripts/gameplay/watering_interactable.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errores: Array[String] = []
	var vivero := Node2D.new()
	vivero.name = "ViveroBuilderTestRoot"
	add_child(vivero)

	var tilemap: TileMapDual = BUILDER.crear_tilemap_tierra(vivero)
	var humedad: TileMapLayer = BUILDER.crear_capa_tierra_mojada(vivero)
	if tilemap == null or humedad == null:
		errores.append("El builder no creó ambas capas del vivero.")
	else:
		if tilemap.name != "TierraCultivableDual":
			errores.append("El TileMapDual perdió su nombre contractual.")
		var atlas_tierra := tilemap.tile_set.get_source(1) as TileSetAtlasSource
		if atlas_tierra == null or atlas_tierra.get_tiles_count() != 16:
			errores.append("La tierra cultivable no conserva las 16 máscaras del atlas.")
		elif atlas_tierra.texture.resource_path != "res://assets/tilesets/Tierra.png":
			errores.append("La capa de cultivo no usa el atlas de tierra esperado.")
		var atlas_humedad := humedad.tile_set.get_source(0) as TileSetAtlasSource
		if atlas_humedad == null or atlas_humedad.get_tiles_count() != 16:
			errores.append("La capa de humedad no conserva las 16 celdas del atlas.")
		elif atlas_humedad.texture.resource_path != "res://assets/tilesets/Tierra Mojada.png":
			errores.append("La capa de humedad no usa el atlas de tierra mojada esperado.")

		var parcelas := [
			["BancalOeste", Vector2(-155, -5), Vector2i(3, 2)],
			["BancalCentro", Vector2(0, -5), Vector2i(3, 2)],
			["BancalEste", Vector2(155, -5), Vector2i(3, 2)],
			["BancalSurOeste", Vector2(-155, 92), Vector2i(3, 1)],
			["BancalSurCentro", Vector2(0, 92), Vector2i(3, 1)]
		]
		for parcela: Array in parcelas:
			BUILDER.agregar_parcela(vivero, tilemap, humedad, parcela[0], parcela[1], parcela[2])
		await get_tree().process_frame

		var nodos_parcela := 0
		var nodos_centrales := 0
		for hijo: Node in vivero.get_children():
			if hijo.get_script() != WATERING_SCRIPT:
				continue
			nodos_parcela += 1
			if not hijo.is_in_group("interactable"):
				errores.append("Una parcela perdió el grupo de interacción.")
			if not hijo.has_method("configurar_parcela"):
				errores.append("Una parcela perdió su contrato de configuración.")
			if not str(hijo.name).begins_with("Bancal"):
				errores.append("Una parcela recibió un nombre inesperado.")
			if hijo.get("_clave_legacy") != "":
				nodos_centrales += 1

		if nodos_parcela != 24:
			errores.append("Se esperaban 24 celdas de cultivo; se crearon %d." % nodos_parcela)
		if nodos_centrales != 5:
			errores.append("Se esperaban cinco claves centrales persistentes; se encontraron %d." % nodos_centrales)
		if tilemap.get_used_cells().size() != 24:
			errores.append("El TileMapDual no recibió las 24 celdas de cultivo.")

	vivero.queue_free()
	await get_tree().process_frame
	if not errores.is_empty():
		for error in errores:
			push_error("TorresViveroBuilder: FAIL: " + error)
		get_tree().quit(1)
		return
	print("TorresViveroBuilder: PASS")
	get_tree().quit(0)
