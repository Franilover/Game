extends Node

const WorldEntityManagerScript = preload("res://scripts/world/world_entity_manager.gd")
const WorldPropScript = preload("res://scripts/world/world_prop.gd")


func _ready() -> void:
	call_deferred("_run")


func _crear_prop(manager: Variant, chunk: Vector2i, key: String) -> WorldProp:
	var prop: WorldProp = WorldPropScript.new() as WorldProp
	prop.datos = {
		"id": key,
		"nombre": "Recurso de prueba",
		"tipo": "recurso",
		"chunk": chunk
	}
	prop.set_meta("runtime_instance_key", key)
	if not manager.registrar(prop, chunk):
		prop.free()
		return null
	return prop


func _run() -> void:
	var errores: Array[String] = []
	var manager: Variant = WorldEntityManagerScript.new()
	var entities_root := Node.new()
	get_tree().root.add_child(entities_root)
	manager.configurar(entities_root)

	var chunk_recoleccion := Vector2i(2, -3)
	var recolectado := _crear_prop(manager, chunk_recoleccion, "prop:0:recurso_a")
	if recolectado == null:
		errores.append("No se pudo registrar el prop de recolección.")
	else:
		recolectado.queue_free()
		await get_tree().process_frame
		var estado_recolectado := manager.obtener_estado_prop(chunk_recoleccion, "prop:0:recurso_a")
		if estado_recolectado.is_empty() or bool(estado_recolectado.get("is_present", true)):
			errores.append("La eliminación por recolección no creó un tombstone persistente.")
		var datos_guardados := manager.obtener_datos_chunk(chunk_recoleccion, "props")
		var tombstone_en_chunk := false
		for dato_variant in datos_guardados:
			if dato_variant is Dictionary:
				var dato := dato_variant as Dictionary
				if str(dato.get("runtime_instance_key", "")) == "prop:0:recurso_a":
					tombstone_en_chunk = not bool(dato.get("is_present", true))
		if not tombstone_en_chunk:
			errores.append("Los datos DATA del chunk todavía permiten regenerar el prop recolectado.")

	var chunk_descarga := Vector2i(4, 1)
	var prop_descargado := _crear_prop(manager, chunk_descarga, "prop:0:recurso_b")
	if prop_descargado == null:
		errores.append("No se pudo registrar el prop de descarga.")
	else:
		manager.despawn_props_chunk(chunk_descarga)
		await get_tree().process_frame
		var estado_descargado := manager.obtener_estado_prop(chunk_descarga, "prop:0:recurso_b")
		if estado_descargado.is_empty() or not bool(estado_descargado.get("is_present", true)):
			errores.append("Descargar un chunk convirtió un prop intacto en recolectado.")

	entities_root.queue_free()
	await get_tree().process_frame
	manager.free()

	if not errores.is_empty():
		for error in errores:
			push_error("WorldPropPersistence: FAIL: " + error)
		get_tree().quit(1)
		return
	print("WorldPropPersistence: PASS")
	get_tree().quit(0)
