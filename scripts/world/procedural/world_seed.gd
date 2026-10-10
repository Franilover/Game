extends RefCounted
class_name WorldSeed

## Stable seed derivation. Does not use String.hash() or list positions.
## Output is a non-negative 31-bit integer accepted by FastNoiseLite.

static func derive(base_seed: int, stable_key: String, layer: int = 0, algorithm_version: int = 1) -> int:
	var value: int = 2166136261
	var bytes: PackedByteArray = stable_key.to_utf8_buffer()
	for byte_value in bytes:
		value = int((value ^ int(byte_value)) * 16777619) & 0x7fffffff
	value = int((value ^ (base_seed & 0x7fffffff)) * 16777619) & 0x7fffffff
	value = int((value ^ (layer & 0x7fffffff)) * 16777619) & 0x7fffffff
	value = int((value ^ (algorithm_version & 0x7fffffff)) * 16777619) & 0x7fffffff
	return value
