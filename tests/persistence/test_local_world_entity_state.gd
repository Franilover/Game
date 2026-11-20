extends Node

const ENTITY_MANAGER_SCRIPT = preload("res://scripts/world/world_entity_manager.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	var manager := ENTITY_MANAGER_SCRIPT.new() as Node
	var original := {
		"criaturas": {
			"0:0:lobo_instancia": {
				"criatura_id": "lobo",
				"position": Vector2(123.5, -456.25),
				"velocity": Vector2(1.5, -2.0),
				"health": 17,
				"necesidades_runtime": {"hambre": 0.65}
			}
		},
		"props": {
			"0:0:mineral_instancia": {
				"position": Vector2(64.0, 96.0),
				"runtime_instance_key": "mineral_instancia",
				"is_present": false,
				"datos": {"chunk": Vector2i(0, 0), "id": "mineral"}
			}
		}
	}
	manager.call("restaurar_estado_persistente_mundo", original)
	if not bool(GameState.call("capturar_estado_entidades_mundo_local", "mundo_abierto", manager)):
		errors.append("GameState no capturó el estado dinámico del manager.")

	var flags_variant: Variant = GameState.world_state.flags.get("entidades_mundo_local_por_zona", {})
	if not flags_variant is Dictionary:
		errors.append("No se creó el mapa de estado local por zona.")
	else:
		var encoded_by_zone := flags_variant as Dictionary
		var encoded_world: Variant = encoded_by_zone.get("mundo_abierto", {})
		if not encoded_world is Dictionary:
			errors.append("No se almacenó el estado de Mundo Abierto.")
		else:
			var json_roundtrip: Variant = JSON.parse_string(JSON.stringify(encoded_world))
			if not json_roundtrip is Dictionary:
				errors.append("El estado local de entidades no se puede serializar como JSON.")
			else:
				encoded_by_zone["mundo_abierto"] = json_roundtrip
				GameState.world_state.flags["entidades_mundo_local_por_zona"] = encoded_by_zone

	var decoded := GameState.call("obtener_estado_entidades_mundo_local", "mundo_abierto") as Dictionary
	var creatures: Dictionary = decoded.get("criaturas", {}) as Dictionary
	var creature: Dictionary = creatures.get("0:0:lobo_instancia", {}) as Dictionary
	if not creature.get("position") is Vector2 or creature.get("position") != Vector2(123.5, -456.25):
		errors.append("La posición Vector2 de la criatura no sobrevivió al JSON.")
	if not creature.get("velocity") is Vector2 or creature.get("velocity") != Vector2(1.5, -2.0):
		errors.append("La velocidad Vector2 de la criatura no sobrevivió al JSON.")
	var props: Dictionary = decoded.get("props", {}) as Dictionary
	var prop: Dictionary = props.get("0:0:mineral_instancia", {}) as Dictionary
	var prop_data: Dictionary = prop.get("datos", {}) as Dictionary
	if not prop_data.get("chunk") is Vector2i or prop_data.get("chunk") != Vector2i.ZERO:
		errors.append("La coordenada Vector2i del chunk no sobrevivió al JSON.")
	if bool(prop.get("is_present", true)):
		errors.append("El tombstone del prop recolectado no sobrevivió.")

	var second_manager := ENTITY_MANAGER_SCRIPT.new() as Node
	second_manager.call("restaurar_estado_persistente_mundo", decoded)
	var captured_again: Dictionary = second_manager.call("capturar_estado_persistente_mundo")
	if captured_again != decoded:
		errors.append("WorldEntityManager no recuperó el estado local capturado.")

	var expedition_manager := ENTITY_MANAGER_SCRIPT.new() as Node
	expedition_manager.call("restaurar_estado_persistente_mundo", {
		"criaturas": {"2:1:ciervo": {"criatura_id": "ciervo", "position": Vector2(900, 700)}},
		"props": {}
	})
	GameState.call("capturar_estado_entidades_mundo_local", "expedicion:bosque", expedition_manager)
	var world_after_expedition := GameState.call("obtener_estado_entidades_mundo_local", "mundo_abierto") as Dictionary
	var expedition_after := GameState.call("obtener_estado_entidades_mundo_local", "expedicion:bosque") as Dictionary
	if world_after_expedition != decoded:
		errors.append("Capturar otra zona sobrescribió el estado de Mundo Abierto.")
	if not (expedition_after.get("criaturas", {}) as Dictionary).has("2:1:ciervo"):
		errors.append("No se almacenó el estado separado de la expedición.")

	manager.free()
	second_manager.free()
	expedition_manager.free()
	GameState.world_state.flags.erase("entidades_mundo_local_por_zona")
	if not errors.is_empty():
		for error in errors:
			push_error("LocalWorldEntityPersistence: FAIL: " + error)
		get_tree().quit(1)
		return
	print("LocalWorldEntityPersistence: PASS")
	get_tree().quit(0)
