extends SceneTree

const WORLD_DATA_SCRIPT = preload("res://scripts/world/world_data.gd")
const SPAWN_RULES_SCRIPT = preload("res://scripts/world/world_spawn_rules.gd")
const GARUMI_SCENE: PackedScene = preload("res://scenes/creatures/garumi.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var garumi_node: Node = GARUMI_SCENE.instantiate()
	root.add_child(garumi_node)
	_expect(garumi_node is Garumi, "El scene debe crear una instancia de la clase Garumi separada.")
	_expect(garumi_node.get_node_or_null("AIController") == null, "Los Garumis no deben heredar por accidente la IA de criaturas normales.")
	_expect(garumi_node.get_node_or_null("CreatureMovement") != null, "El Garumi debe conservar el controlador de movimiento compartido.")
	garumi_node.call("configurar", {"id": "g-scene", "nombre": "Garumi scene test"})
	garumi_node.call("activar_como_proxy")
	var datos_visual: Dictionary = garumi_node.get("datos")
	_expect(str(datos_visual.get("categoria_entidad", "")) == "garumi", "La clase debe fijar su categoría antes de resolver sprite y presentación.")
	_expect(garumi_node.is_in_group("garumis"), "Las instancias deben pertenecer al grupo propio de Garumis.")
	_expect(not garumi_node.is_in_group("creatures"), "Los Garumis no deben mezclarse con el grupo de criaturas comunes.")
	_expect(not garumi_node.is_in_group("damageable"), "El daño común no debe matar a un Garumi.")
	var salud_antes := int(garumi_node.get("health"))
	garumi_node.call("take_damage", 999, "test")
	_expect(int(garumi_node.get("health")) == salud_antes and bool(garumi_node.get("is_alive")), "El daño común debe dejar vivo al Garumi hasta tener absorción específica.")
	garumi_node.free()

	var data: Node = WORLD_DATA_SCRIPT.new()
	data.set("mundo", {
		"biomas": [],
		"ecosistemas_sin_bioma": [],
		"garumis_game": [
			{
				"id": "test-garumi-001",
				"nombre": "Garumi de prueba",
				"asset_key": "test-garumi-asset-that-does-not-exist",
				"aparicion": {
					"bioma_ids": ["bioma-prueba"],
					"ecosistema_ids": ["ecosistema-prueba"],
					"habitat_ids": ["habitat-prueba"],
					"probabilidad_chunk": 0.2
				}
			},
			{"id": "sin-nombre", "nombre": ""}
		]
	})
	data.call("_construir_indices")

	var catalogo: Array = data.call("obtener_garumis_game")
	_expect(catalogo.size() == 1, "El catálogo debe aceptar Garumis válidos y descartar registros sin nombre.")
	_expect(bool((data.call("obtener_garumi_game", "test-garumi-001") as Dictionary).has("aparicion")), "Debe poder consultarse un Garumi por ID.")
	_expect((data.call("obtener_criatura", "test-garumi-001") as Dictionary).is_empty(), "El catálogo Garumi no debe mezclarse con criaturas de hábitat.")

	if not catalogo.is_empty():
		(catalogo[0] as Dictionary)["nombre"] = "mutado"
		var original: Dictionary = data.call("obtener_garumi_game", "test-garumi-001")
		_expect(str(original.get("nombre", "")) == "Garumi de prueba", "El catálogo expuesto debe devolver copias, no referencias mutables.")
	var diagnostico: Dictionary = data.call("obtener_diagnostico_garumis_game")
	_expect(int(diagnostico.get("catalogo", 0)) == 1, "El diagnóstico debe contar el catálogo validado.")

	var rules: Node = SPAWN_RULES_SCRIPT.new()
	var garumi: Dictionary = {
		"id": "g-1",
		"nombre": "Garumi de prueba",
		"aparicion": {
			"bioma_ids": ["bioma-prueba", "bioma-alterno"],
			"ecosistema_ids": ["ecosistema-prueba"],
			"habitat_ids": ["habitat-prueba"],
			"habitat_claves": ["general"]
		}
	}
	var bioma := {"id": "bioma-prueba"}
	var ecosistema := {"id": "ecosistema-prueba"}
	var habitats: Array = [
		{"id": "habitat-prueba", "tipo_habitat": {"clave": "general"}}
	]
	_expect(bool(rules.call("garumi_puede_aparecer", garumi, bioma, ecosistema, habitats)), "Un Garumi compatible debe aparecer en su contexto ecológico.")
	_expect(not bool(rules.call("garumi_puede_aparecer", garumi, bioma, {"id": "ecosistema-ajeno"}, habitats)), "Un selector ecológico presente debe restringir la aparición.")
	_expect(not bool(rules.call("garumi_puede_aparecer", {"id": "sin-aparicion", "nombre": "Sin aparición"}, bioma, ecosistema, habitats)), "Un Garumi sin anclas ecológicas no debe aparecer globalmente.")
	_expect(not bool(rules.call("garumi_puede_aparecer", garumi, bioma, ecosistema, [{"id": "otro-habitat", "tipo_habitat": {"clave": "general"}}])), "El ID de hábitat debe respetarse cuando está definido.")

	var probabilidad_predeterminada := float(rules.call("obtener_probabilidad_spawn_garumi", {"aparicion": {}}, 0.15))
	var probabilidad_acotada := float(rules.call("obtener_probabilidad_spawn_garumi", {"aparicion": {"probabilidad_chunk": 4.0}}, 0.15))
	_expect(is_equal_approx(probabilidad_predeterminada, 0.15), "La probabilidad por chunk debe usar el valor predeterminado configurado.")
	_expect(is_equal_approx(probabilidad_acotada, 1.0), "La probabilidad por chunk debe limitarse a [0, 1].")

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var candidatos: Array[Dictionary] = [garumi]
	var elegido: Dictionary = rules.call("elegir_garumi", candidatos, rng)
	_expect(str(elegido.get("id", "")) == "g-1", "La selección ponderada debe devolver el candidato válido.")
	data.free()
	rules.free()

	if _failed:
		quit(1)
		return
	print("PASS: Garumi catalog remains separate, ecology selectors are respected, and spawn chance stays bounded.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("GarumiWorldPresence: FAIL: " + message)
