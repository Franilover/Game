extends Node
## Events — bus global de señales desacopladas.
## Uso: Events.player_died.emit() / Events.player_died.connect(callback)


# ── Player ───────────────────────────────────────────────────────────────────

signal player_died
signal player_respawned(position: Vector2)
signal player_state_changed(new_state: int)


# ── World ────────────────────────────────────────────────────────────────────

signal scene_changed(scene_name: String)
signal entity_spawned(entity: Node)
signal entity_removed(entity: Node)


# ── UI ───────────────────────────────────────────────────────────────────────

signal dialog_opened(speaker: String, text: String)
signal dialog_closed

@warning_ignore("unused_signal")
signal notification_pushed(message: String)

signal interaction_executed(
	objeto: Node,
	jugador: Node,
	accion: String
)
