extends SceneTree

const CombatClockScript = preload("res://scripts/gameplay/combat/combat_clock.gd")
const CombatEventQueueScript = preload("res://scripts/gameplay/combat/combat_event_queue.gd")
const CombatActionLifecycleScript = preload("res://scripts/gameplay/combat/combat_action_lifecycle.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array[String] = []
	_test_monotonic_clock(errors)
	_test_stable_event_order_and_deduplication(errors)
	_test_due_batch_and_clock_advance(errors)
	_test_action_lifecycle_and_interruptions(errors)

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

func _test_action_lifecycle_and_interruptions(errors: Array[String]) -> void:
	var action := CombatActionLifecycleScript.new() as CombatActionLifecycle
	if not action.begin_preparation("attack-1", true):
		errors.append("La acción no pudo comenzar la preparación.")
		return
	if not action.can_interrupt():
		errors.append("Una acción marcada como interrumpible no permite reemplazo.")
		return
	if not action.interrupt("replacement_order"):
		errors.append("La orden interrumpible no pudo interrumpirse.")
		return
	if action.state_name() != "interrupted" or action.can_interrupt():
		errors.append("La acción interrumpida no quedó en estado terminal.")
	if action.complete():
		errors.append("Una acción interrumpida pudo completarse después.")

	var committed := CombatActionLifecycleScript.new() as CombatActionLifecycle
	committed.begin_preparation("attack-2", true)
	if not committed.commit():
		errors.append("La acción no pudo alcanzar el punto de compromiso.")
		return
	if committed.can_interrupt() or committed.interrupt("replacement_order"):
		errors.append("Una acción comprometida pudo interrumpirse por reemplazo.")
	if not committed.begin_execution(false):
		errors.append("La acción comprometida no pudo comenzar su ejecución.")
		return
	if not committed.complete() or committed.state_name() != "completed":
		errors.append("La acción no pudo completar su ciclo de vida.")

	var rejected := CombatActionLifecycleScript.new() as CombatActionLifecycle
	if not rejected.reject("invalid_requirements") or rejected.state_name() != "rejected":
		errors.append("Una orden inválida no pudo rechazarse antes de comenzar.")
	if rejected.begin_preparation("should-not-start", true):
		errors.append("Una orden rechazada pudo reiniciarse.")
