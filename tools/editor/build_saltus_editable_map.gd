@tool
extends EditorScript
## Genera una escena física y editable de Saltus a partir del diseño V2 actual.
## Ejecutar desde el editor con cualquier escena abierta: File > Run.

const OUTPUT_PATH := "res://scenes/world/saltus_map_v2.tscn"


func _run() -> void:
	var generador := SaltusExpedition.new()
	generador.name = "GeneradorTemporalSaltus"
	# Se construye fuera del árbol para que no ejecute el _ready() de la expedición.
	generador.call("_crear_terreno")

	var mapa := Node2D.new()
	mapa.name = "MapaSaltusV2"
	mapa.set_meta("editable_tilemap", true)
	var hijos := generador.get_children().duplicate()
	for hijo: Node in hijos:
		generador.remove_child(hijo)
		mapa.add_child(hijo)
		hijo.owner = mapa

	var tilemap := mapa.get_node_or_null("TerrenoSaltusV2") as TileMapDual
	if tilemap == null or tilemap.get_used_cells().is_empty():
		push_error("Saltus: no se generó el TileMapDual. No se guardó la escena.")
		mapa.free()
		generador.free()
		return

	var packed := PackedScene.new()
	var pack_error := packed.pack(mapa)
	if pack_error != OK:
		push_error("Saltus: error empaquetando mapa: " + error_string(pack_error))
		mapa.free()
		generador.free()
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		push_error("Saltus: error guardando mapa: " + error_string(save_error))
		mapa.free()
		generador.free()
		return

	print("Saltus: escena editable guardada en ", OUTPUT_PATH)
	print("Celdas del TileMapDual: ", tilemap.get_used_cells().size())
	print("Abre scenes/world/saltus_map_v2.tscn para pintar, borrar y mover tiles desde el editor.")
	mapa.free()
	generador.free()
