extends RefCounted
class_name CombatEventQueue

## Cola de eventos ordenada por (tiempo, secuencia).
## No ejecuta reglas de combate; entrega eventos en orden determinista.
## Los event_id son idempotentes durante la vida de esta instancia.

var clock: CombatClock = CombatClock.new()
var _pending: Array[Dictionary] = []
var _known_ids: Dictionary = {}
var _next_sequence: int = 1


func reset(start_us: int = 0) -> void:
	_pending.clear()
	_known_ids.clear()
	_next_sequence = 1
	clock.reset(start_us)


func schedule(
	event_id: String,
	time_us: int,
	event_type: String,
	payload: Dictionary = {}
) -> Dictionary:
	if event_id.strip_edges().is_empty() or event_type.strip_edges().is_empty():
		return {"accepted": false, "reason": "invalid_identity"}
	if _known_ids.has(event_id):
		return {"accepted": false, "reason": "duplicate_event_id"}
	if time_us < clock.now_us:
		return {"accepted": false, "reason": "event_in_past"}

	var event := {
		"event_id": event_id,
		"time_us": time_us,
		"sequence": _next_sequence,
		"type": event_type,
		"payload": payload.duplicate(true),
		"status": "pending"
	}
	_next_sequence += 1
	_known_ids[event_id] = "pending"
	_pending.append(event)
	_sort_pending()
	return {"accepted": true, "event": event.duplicate(true)}


func has_pending() -> bool:
	return not _pending.is_empty()


func pending_count() -> int:
	return _pending.size()


func peek_next() -> Dictionary:
	if _pending.is_empty():
		return {}
	return _pending[0].duplicate(true)


func pop_next() -> Dictionary:
	if _pending.is_empty():
		return {}
	var event: Dictionary = _pending.pop_front()
	clock.advance_to(int(event["time_us"]))
	_known_ids[String(event["event_id"])] = "resolved"
	event["status"] = "resolved"
	return event


func pop_due(target_us: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if target_us < clock.now_us:
		return due
	while not _pending.is_empty() and int(_pending[0]["time_us"]) <= target_us:
		due.append(pop_next())
	clock.advance_to(target_us)
	return due


func was_seen(event_id: String) -> bool:
	return _known_ids.has(event_id)


func event_status(event_id: String) -> String:
	return String(_known_ids.get(event_id, "unknown"))


func _sort_pending() -> void:
	_pending.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["time_us"]) == int(b["time_us"]):
				return int(a["sequence"]) < int(b["sequence"])
			return int(a["time_us"]) < int(b["time_us"])
	)
