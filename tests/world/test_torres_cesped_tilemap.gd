extends SceneTree

const TORRES_SCENE: PackedScene = preload("res://scenes/kingdom/reino_torres.tscn")
const EXPECTED_CELL_COUNT := 104 * 68
const EXPECTED_ORIGIN := Vector2(-1664.0, -1088.0)
const EXPECTED_ATLASES := {
	0: "res://assets/tilesets/Pradera.png",
	1: "res://assets/tilesets/Tierra.png",
	8: "res://assets/tilesets/Bosque.png",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var torres := TORRES_SCENE.instantiate() as Node2D
	if torres == null:
		_fail("No se pudo instanciar la escena de Torres.")
		return
	root.add_child(torres)

	var espera := 0
	while not bool(torres.get("_terreno_dual_listo")) and espera < 120:
		await process_frame
		espera += 1
	if not bool(torres.get("_terreno_dual_listo")):
		_fail("Torres no terminó de componer su terreno TileMapDual.")
		return

	if torres.get_node_or_null("TerrainRenderer") != null:
		_fail("Torres todavía crea un TerrainRenderer dinámico.")
		return

	if not _validar_distribucion_urbana(torres):
		return

	var total_cells := 0
	for zone in EXPECTED_ATLASES.keys():
		var layer := torres.get_node_or_null("TerrainDual_Zone_%02d" % int(zone)) as TileMapDual
		if layer == null:
			_fail("Falta la capa editable TileMapDual de la zona %d." % int(zone))
			return
		if not layer.visible:
			_fail("La capa TileMapDual de la zona %d no quedó visible." % int(zone))
			return
		if layer.position != EXPECTED_ORIGIN:
			_fail("La capa editable de la zona %d no coincide con el origen ampliado." % int(zone))
			return
		var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
		if atlas == null or atlas.texture == null:
			_fail("La zona %d no tiene un atlas válido." % int(zone))
			return
		if atlas.texture.resource_path != str(EXPECTED_ATLASES[zone]):
			_fail("La zona %d no usa el atlas esperado." % int(zone))
			return
		if atlas.texture_region_size != Vector2i(32, 32) or atlas.get_tiles_count() != 16:
			_fail("La zona %d no conserva las 16 máscaras de 32x32." % int(zone))
			return
		var cells := layer.get_used_cells().size()
		if cells <= 0:
			_fail("La zona %d no recibió celdas." % int(zone))
			return
		var diagnostico: Dictionary = layer.call("obtener_diagnostico")
		if not bool(diagnostico.get("renderer_valid", false)):
			_fail("La zona %d no inicializó su renderer visual." % int(zone))
			return
		if int(diagnostico.get("display_cells", 0)) <= 0:
			_fail("La zona %d no generó tiles en Display." % int(zone))
			return
		total_cells += cells

	if total_cells != EXPECTED_CELL_COUNT:
		_fail("Se esperaban 7.072 celdas repartidas entre pradera, caminos y borde arbolado.")
		return

	var tierra := torres.get_node_or_null("TerrainDual_Zone_01") as TileMapDual
	var bosque := torres.get_node_or_null("TerrainDual_Zone_08") as TileMapDual
	var pradera := torres.get_node_or_null("TerrainDual_Zone_00") as TileMapDual
	for celda in [Vector2i(52, 34), Vector2i(80, 34), Vector2i(13, 34)]:
		if tierra == null or tierra.get_cell_source_id(celda) == -1:
			_fail("La plaza o una calle principal/secundaria no quedó pintada como Tierra: %s." % str(celda))
			return
	if bosque == null or bosque.get_cell_source_id(Vector2i(0, 0)) == -1:
		_fail("Falta el borde arbolado en la esquina del reino.")
		return
	if pradera == null or pradera.get_cell_source_id(Vector2i(26, 45)) == -1:
		_fail("Falta una zona abierta de pradera entre los barrios.")
		return

	print("PASS: Torres usa 7.072 celdas TileMapDual con plaza, calles conectadas y borde arbolado.")
	torres.queue_free()
	quit()



func _validar_distribucion_urbana(torres: Node2D) -> bool:
	var posiciones: Dictionary = {
		"Grupo_edificio_castillo": Vector2(0.-850),
		"Grupo_edificio_archivo_real": Vector2(-170.-280),
		"Grupo_edificio_sala_consejo": Vector2(170.-280),
		"Grupo_edificio_cuartel": Vector2(520.-430),
		"Grupo_edificio_carpinteria": Vector2(-160.430),
		"Grupo_casa_bruna": Vector2(-1000.-350),
		"Grupo_casa_elian": Vector2(700.-350),
		"Grupo_casa_darven": Vector2(850.-350),
		"Grupo_casa_saira": Vector2(1000.-350),
		"Grupo_casa_narel": Vector2(-850.-350),
		"Grupo_casa_vacia_06": Vector2(-850.150),
		"Grupo_casa_granjeros": Vector2(950.850),
	}
	for nombre: String in posiciones:
		var edificio := torres.get_node_or_null(nombre) as Node2D
		if edificio == null:
			_fail("Falta el nodo urbano %s." % nombre)
			return false
		if edificio.position.distance_to(posiciones[nombre]) > 0.1:
			_fail("La posición de %s no coincide con el nuevo barrio." % nombre)
			return false

	var archivo := torres.get_node("Grupo_edificio_archivo_real/Entrada") as Marker2D
	var consejo := torres.get_node("Grupo_edificio_sala_consejo/Entrada") as Marker2D
	if archivo.global_position.distance_to(Vector2(-170.0, -217.0)) > 0.1:
		_fail("La entrada del Archivo Real no coincide con su nueva ubicación.")
		return false
	if consejo.global_position.distance_to(Vector2(170.0, -212.0)) > 0.1:
		_fail("La entrada de la Sala del Consejo no coincide con su nueva ubicación.")
		return false

	var entrada_cuartel := torres.get_node("Grupo_edificio_cuartel/Entrada") as Marker2D
	if entrada_cuartel.global_position.distance_to(Vector2(520.0, -362.0)) > 0.1:
		_fail("El acceso del cuartel no coincide con su nueva ubicación cercana al centro.")
		return false
	var entrada_carpinteria := torres.get_node("Grupo_edificio_carpinteria/Entrada") as Marker2D
	if entrada_carpinteria.global_position.distance_to(Vector2(-160.0, 494.0)) > 0.1:
		_fail("El acceso de la carpintería no coincide con su nueva ubicación cercana al centro.")
		return false

	var salida := torres.get_node_or_null("ExpeditionEntrance") as Area2D
	if salida == null or salida.position.distance_to(Vector2(1600.0, 0.0)) > 0.1:
		_fail("La salida oriental no se trasladó al límite ampliado.")
		return false
	return true


func _fail(message: String) -> void:
	push_error("Torres shared terrain regression: " + message)
	quit(1)
