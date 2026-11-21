extends SceneTree

const ConfigScript = preload("res://scripts/world/procedural/world_generation_config.gd")
const KernelScript = preload("res://scripts/world/procedural/world_generator_kernel.gd")
const SeedScript = preload("res://scripts/world/procedural/world_seed.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var config = ConfigScript.new(481516, 128, 128, 16, 1)
	assert(config.is_valid(), "La configuración válida debe aceptarse.")
	assert(SeedScript.derive(10, "bioma:uuid-1") == SeedScript.derive(10, "bioma:uuid-1"), "Una clave estable debe producir la misma semilla.")
	assert(SeedScript.derive(10, "bioma:uuid-1") != SeedScript.derive(10, "bioma:uuid-2"), "Claves distintas deberían producir semillas distintas.")
	var chunk_a = KernelScript.generate_chunk(Vector2i(0, 0), config)
	var chunk_b = KernelScript.generate_chunk(Vector2i(-1, 2), config)
	var chunk_a_again = KernelScript.generate_chunk(Vector2i(0, 0), config)
	assert(chunk_a != null and chunk_a.is_valid(), "El chunk A debe tener datos válidos.")
	assert(chunk_b != null and chunk_b.is_valid(), "Los chunks con coordenadas negativas deben ser válidos.")
	assert(chunk_a.elevation == chunk_a_again.elevation, "Elevación debe ser determinista.")
	assert(chunk_a.humidity == chunk_a_again.humidity, "Humedad debe ser determinista.")
	assert(chunk_a.temperature == chunk_a_again.temperature, "Temperatura debe ser determinista.")
	assert(chunk_a.origin_tile == Vector2i.ZERO, "El origen del chunk 0,0 debe ser cero.")
	assert(chunk_b.origin_tile == Vector2i(-16, 32), "El origen debe derivarse de las coordenadas globales.")
	assert(chunk_a.index_at(-1, 0) == -1, "Un índice fuera del chunk debe rechazarse.")
	var spawn_rules = SpawnRulesScript.new()
	var candidatos := [
		{"criatura": {"id": "especie_a"}, "peso_spawn": 1.0},
		{"criatura": {"id": "especie_b"}, "peso_spawn": 3.0},
		{"criatura": {"id": "especie_c"}, "peso_spawn": 2.0}
	]
	var excluidas := {"especie_a": true}
	for seed in range(1, 25):
		var rng_esperado := RandomNumberGenerator.new()
		var rng_nuevo := RandomNumberGenerator.new()
		rng_esperado.seed = seed
		rng_nuevo.seed = seed
		var candidatos_esperados: Array = [candidatos[1], candidatos[2]]
		var esperado: Dictionary = spawn_rules.elegir_criatura(candidatos_esperados, rng_esperado)
		var obtenido: Dictionary = spawn_rules.elegir_criatura_excluyendo(candidatos, excluidas, rng_nuevo)
		assert(obtenido.get("criatura", {}).get("id", "") == esperado.get("criatura", {}).get("id", ""), "La selección sin arrays debe conservar el sorteo ponderado.")
	var todos_excluidos := {"especie_a": true, "especie_b": true, "especie_c": true}
	assert(spawn_rules.elegir_criatura_excluyendo(candidatos, todos_excluidos, RandomNumberGenerator.new()).is_empty(), "No debe elegir especies excluidas.")
	var candidatos_uniformes := [
		{"criatura": {"id": "criatura_a"}},
		{"criatura": {"id": "criatura_b"}},
		{"criatura": {"id": "criatura_c"}},
		{"criatura": {"id": "criatura_d"}}
	]
	var excluidas_uniformes := {"criatura_b": true}
	for seed_uniforme in range(1, 25):
		var rng_uniforme_esperado := RandomNumberGenerator.new()
		var rng_uniforme_nuevo := RandomNumberGenerator.new()
		rng_uniforme_esperado.seed = seed_uniforme
		rng_uniforme_nuevo.seed = seed_uniforme
		var validos_uniformes: Array[Dictionary] = [
			candidatos_uniformes[0],
			candidatos_uniformes[2],
			candidatos_uniformes[3]
		]
		var esperado_uniforme: Dictionary = validos_uniformes[rng_uniforme_esperado.randi_range(0, validos_uniformes.size() - 1)]
		var obtenido_uniforme: Dictionary = spawn_rules.elegir_candidato_uniforme_excluyendo(candidatos_uniformes, excluidas_uniformes, rng_uniforme_nuevo)
		assert(obtenido_uniforme.get("criatura", {}).get("id", "") == esperado_uniforme.get("criatura", {}).get("id", ""), "La selección uniforme sin arrays debe conservar el resultado del RNG.")
	print("WorldGeneratorKernel: pruebas smoke completadas.")
	quit(0)
