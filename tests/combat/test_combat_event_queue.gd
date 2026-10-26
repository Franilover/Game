extends SceneTree

const CombatClockScript = preload("res://scripts/gameplay/combat/combat_clock.gd")
const CombatEventQueueScript = preload("res://scripts/gameplay/combat/combat_event_queue.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	_test_monotonic_clock(errors)
	_test_stable_event_order_and_deduplication(errors)
	_test_due_batch_and_clock_advance(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("CombatEventQueueContract: FAIL: " + error)
		quit(1)
		return

	print("CombatEventQueueContract: PASS")
	quit(0)


func _test_monotonic_clock(errors: Array[String]) -> void:
	var clock := CombatClockScript.new() as CombatClock
	clock.reset(100)
	if clock.advance_to(90) != 100:
		errors.append("El reloj retrocedió al recibir una marca antigua.")
	if clock.advance_by(25) != 125:
		errors.append("advance_by no avanzó el reloj correctamente.")
	if clock.advance_by(-10) != 125:
		errors.append("Un delta negativo alteró el reloj.")


func _test_stable_event_order_and_deduplication(errors: Array[String]) -> void:
	var queue := CombatEventQueueScript.new() as CombatEventQueue
	queue.reset()
	var a := queue.schedule("evt-a", 100, "impact", {"target": "A"})
	var b := queue.schedule("evt-b", 100, "recovery", {"target": "B"})
	var c := queue.schedule("evt-c", 50, "order", {})
	if not bool(a.get("accepted", false)) or not bool(b.get("accepted", false)) or not bool(c.get("accepted", false)):
		errors.append("La cola rechazó eventos válidos.")
		return

	var duplicate := queue.schedule("evt-a", 120, "impact", {})
	if bool(duplicate.get("accepted", false)) or duplicate.get("reason", "") != "duplicate_event_id":
		errors.append("La cola aceptó dos veces el mismo event_id.")

	var first := queue.pop_next()
	var second := queue.pop_next()
	var third := queue.pop_next()
	if first.get("event_id", "") != "evt-c":
		errors.append("La cola no ordenó primero el evento de menor tiempo.")
	if second.get("event_id", "") != "evt-a" or third.get("event_id", "") != "evt-b":
		errors.append("Los eventos del mismo tiempo no respetaron la secuencia de inserción.")
	if queue.event_status("evt-a") != "resolved":
		errors.append("El estado del evento no pasó a resolved tras extraerlo.")
	if queue.was_seen("evt-a") != true:
		errors.append("La cola olvidó un ID ya resuelto.")


func _test_due_batch_and_clock_advance(errors: Array[String]) -> void:
	var queue := CombatEventQueueScript.new() as CombatEventQueue
	queue.reset(10)
	queue.schedule("due-1", 15, "move", {})
	queue.schedule("due-2", 20, "impact", {})
	queue.schedule("future", 30, "recovery", {})

	var due := queue.pop_due(20)
	if due.size() != 2:
		errors.append("pop_due no devolvió todos y solo los eventos vencidos.")
	if queue.clock.now_us != 20:
		errors.append("pop_due no avanzó el reloj hasta el límite solicitado.")
	if queue.pending_count() != 1 or queue.peek_next().get("event_id", "") != "future":
		errors.append("pop_due alteró o perdió el evento futuro.")
	var past := queue.schedule("past-event", 19, "late", {})
	if bool(past.get("accepted", false)) or past.get("reason", "") != "event_in_past":
		errors.append("La cola aceptó un evento anterior al reloj actual.")
