extends RefCounted
class_name WorldGeneratorKernel

## First data-only generation kernel.
## Every sample uses global tile coordinates, so chunk request order cannot affect
## results and neighboring chunks sample the same continuous noise field.

const ChunkDataScript = preload("res://scripts/world/procedural/world_chunk_data.gd")
const SeedScript = preload("res://scripts/world/procedural/world_seed.gd")

static func generate_chunk(chunk_coord: Vector2i, config: WorldGenerationConfig) -> WorldChunkData:
	if config == null or not config.is_valid():
		push_error("WorldGeneratorKernel: configuración nula o inválida.")
		return null

	var chunk_size: int = config.chunk_size_tiles
	var origin := chunk_coord * chunk_size
	var data := ChunkDataScript.new(
		chunk_coord,
		origin,
		chunk_size,
		chunk_size,
		config.algorithm_version
	) as WorldChunkData

	var elevation_noise := _make_noise(config, "elevation", 0.004)
	var humidity_noise := _make_noise(config, "humidity", 0.006)
	var temperature_noise := _make_noise(config, "temperature", 0.003)

	for local_y in range(chunk_size):
		for local_x in range(chunk_size):
			var index: int = local_y * chunk_size + local_x
			var global_x: int = origin.x + local_x
			var global_y: int = origin.y + local_y
			data.elevation[index] = (elevation_noise.get_noise_2d(global_x, global_y) + 1.0) * 0.5
			data.humidity[index] = (humidity_noise.get_noise_2d(global_x, global_y) + 1.0) * 0.5
			var latitude: float = 1.0 - clampf(absf(float(global_y)) / maxf(1.0, float(config.world_height_tiles)), 0.0, 1.0)
			var local_temperature: float = (temperature_noise.get_noise_2d(global_x, global_y) + 1.0) * 0.5
			data.temperature[index] = clampf(latitude * 0.65 + local_temperature * 0.35, 0.0, 1.0)

	return data

static func _make_noise(config: WorldGenerationConfig, key: String, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = SeedScript.derive(config.seed, key, 0, config.algorithm_version)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	return noise
