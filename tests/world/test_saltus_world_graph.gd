extends SceneTree

const GraphScript = preload("res://scripts/world/saltus_world_graph.gd")
const RoomScript = preload("res://scripts/world/saltus_room_definition.gd")
const ConnectionScript = preload("res://scripts/world/saltus_world_connection.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var graph := GraphScript.new()
	var entry = RoomScript.new()
	var grove = RoomScript.new()
	var roots = RoomScript.new()

	entry.room_id = &"entrada"
	entry.region_id = &"claro"
	entry.bounds = Rect2(0.0, 0.0, 400.0, 400.0)
	grove.room_id = &"arboleda"
	grove.region_id = &"bosque"
	grove.bounds = Rect2(300.0, 0.0, 200.0, 200.0)
	roots.room_id = &"raices"
	roots.region_id = &"subsuelo"
	roots.bounds = Rect2(300.0, 300.0, 400.0, 400.0)

	var open_path = ConnectionScript.new()
	open_path.connection_id = &"sendero_claro"
	open_path.room_a = &"entrada"
	open_path.room_b = &"arboleda"

	var ability_path = ConnectionScript.new()
	ability_path.connection_id = &"raiz_agrietada"
	ability_path.room_a = &"arboleda"
	ability_path.room_b = &"raices"
	ability_path.requirement_type = ConnectionScript.RequirementType.ABILITY
	ability_path.requirement_key = &"impacto_descendente"

	var one_way_path = ConnectionScript.new()
	one_way_path.connection_id = &"caida_controlada"
	one_way_path.room_a = &"raices"
	one_way_path.room_b = &"entrada"
	one_way_path.one_way_from_a = true

	graph.rooms = [entry, grove, roots]
	graph.connections = [open_path, ability_path, one_way_path]
	root.add_child(graph)
	await process_frame

	if graph.get_room_at(Vector2(350.0, 100.0)) != grove:
		errors.append("La habitación más específica debe prevalecer cuando los límites se solapan.")
	if not graph.can_traverse(&"sendero_claro", &"entrada"):
		errors.append("Una conexión sin requisito debe estar abierta.")
	if graph.can_traverse(&"raiz_agrietada", &"arboleda"):
		errors.append("Una conexión con habilidad debe permanecer bloqueada sin ella.")
	if graph.get_destination(&"raiz_agrietada", &"arboleda", {&"impacto_descendente": true}) != &"raices":
		errors.append("La habilidad correcta debe permitir atravesar la conexión.")
	if graph.can_traverse(&"caida_controlada", &"entrada"):
		errors.append("Una conexión unidireccional no debe permitir el recorrido inverso.")
	if graph.get_destination(&"caida_controlada", &"raices") != &"entrada":
		errors.append("La conexión unidireccional debe permitir el sentido configurado.")

	if not graph.discover_room(&"arboleda") or graph.discover_room(&"arboleda"):
		errors.append("Una habitación solo debe descubrirse una vez.")
	if not graph.unlock_connection(&"raiz_agrietada"):
		errors.append("Una conexión válida debe poder desbloquearse permanentemente.")

	var saved_progress: Dictionary = graph.serialize_progress()
	var restored_graph := GraphScript.new()
	restored_graph.rooms = [entry, grove, roots]
	restored_graph.connections = [open_path, ability_path, one_way_path]
	root.add_child(restored_graph)
	await process_frame
	restored_graph.restore_progress(saved_progress)

	if not restored_graph.is_room_discovered(&"arboleda"):
		errors.append("El descubrimiento de habitaciones debe persistir.")
	if not restored_graph.is_connection_unlocked(&"raiz_agrietada"):
		errors.append("El desbloqueo de conexiones debe persistir.")

	graph.queue_free()
	restored_graph.queue_free()
	await process_frame

	if not errors.is_empty():
		for error in errors:
			push_error("SaltusWorldGraph: " + error)
		quit(1)
		return

	print("SaltusWorldGraph: PASS")
	quit(0)
