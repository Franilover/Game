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
	print("WorldGeneratorKernel: pruebas smoke completadas.")
	quit(0)
