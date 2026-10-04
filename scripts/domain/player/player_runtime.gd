extends RefCounted
class_name PlayerRuntime

## Estado runtime del jugador. No conoce UI, input ni Supabase.
var state := PlayerState.new()

func aplicar_estado_desde_nodo(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	state.health = int(player.get("health"))
	state.mana = int(player.get("mana"))
	state.stamina = float(player.get("stamina"))
	state.facing = player.get("facing") if player.get("facing") is Vector2 else Vector2.DOWN
	if player is Node2D:
		state.position = (player as Node2D).global_position
		state.position_valida = true

func aplicar_al_nodo(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player is Node2D and state.position_valida:
		(player as Node2D).global_position = state.position
	player.set("health", state.health)
	player.set("mana", state.mana)
	player.set("stamina", state.stamina)
	player.set("facing", state.facing)
