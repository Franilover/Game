extends Node
## GameState — estado persistente entre escenas.

# ── Player ───────────────────────────────────────────────────────────────────
var player_health: int = 100
var player_mana: int   = 100
var player_position: Vector2 = Vector2.ZERO

# ── World ────────────────────────────────────────────────────────────────────
var current_scene: String = ""
var elapsed_time: float   = 0.0

# ── Flags ─────────────────────────────────────────────────────────────────────
var flags: Dictionary = {}   # flags["intro_seen"] = true

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value

func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)


func _process(delta: float) -> void:
	elapsed_time += delta
