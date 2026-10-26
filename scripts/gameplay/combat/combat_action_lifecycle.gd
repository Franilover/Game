extends RefCounted
class_name CombatActionLifecycle

## Estado temporal de una orden de combate.
## No ejecuta animaciones, costes ni efectos: únicamente valida transiciones.

enum State {
	REQUESTED,
	REJECTED,
	PREPARING,
	COMMITTED,
	EXECUTING,
	COMPLETED,
	INTERRUPTED,
	CANCELLED
}

var action_id: String = ""
var state: State = State.REQUESTED
var interruptible: bool = true
var interruption_cause: String = ""
var transition_history: Array[Dictionary] = []


func begin_preparation(id: String, can_interrupt: bool = true) -> bool:
	if state != State.REQUESTED or id.strip_edges().is_empty():
		return false
	action_id = id
	interruptible = can_interrupt
	return _transition(State.PREPARING, "preparation_started")


func reject(reason: String) -> bool:
	if state != State.REQUESTED:
		return false
	return _transition(State.REJECTED, reason)


func commit() -> bool:
	if state != State.PREPARING:
		return false
	# El compromiso cierra la ventana de cancelación por reemplazo de orden.
	interruptible = false
	return _transition(State.COMMITTED, "action_committed")


func begin_execution(can_interrupt: bool = false) -> bool:
	if state != State.COMMITTED:
		return false
	interruptible = can_interrupt
	return _transition(State.EXECUTING, "execution_started")


func complete() -> bool:
	if state != State.EXECUTING and state != State.COMMITTED:
		return false
	interruptible = false
	return _transition(State.COMPLETED, "action_completed")


func interrupt(cause: String) -> bool:
	if not can_interrupt():
		return false
	interruption_cause = cause
	interruptible = false
	return _transition(State.INTERRUPTED, cause)


func cancel(cause: String = "authorized_cancel") -> bool:
	if state != State.REQUESTED and state != State.PREPARING and state != State.EXECUTING:
		return false
	interruption_cause = cause
	interruptible = false
	return _transition(State.CANCELLED, cause)


func can_interrupt() -> bool:
	return interruptible and (state == State.PREPARING or state == State.EXECUTING)


func state_name() -> String:
	match state:
		State.REQUESTED: return "requested"
		State.REJECTED: return "rejected"
		State.PREPARING: return "preparing"
		State.COMMITTED: return "committed"
		State.EXECUTING: return "executing"
		State.COMPLETED: return "completed"
		State.INTERRUPTED: return "interrupted"
		State.CANCELLED: return "cancelled"
	return "unknown"


func _transition(next_state: State, reason: String) -> bool:
	if _is_terminal(state):
		return false
	transition_history.append({
		"from": state_name(),
		"to": _state_to_name(next_state),
		"reason": reason
	})
	state = next_state
	return true


func _is_terminal(value: State) -> bool:
	return value == State.REJECTED or value == State.COMPLETED or value == State.INTERRUPTED or value == State.CANCELLED


func _state_to_name(value: State) -> String:
	match value:
		State.REQUESTED: return "requested"
		State.REJECTED: return "rejected"
		State.PREPARING: return "preparing"
		State.COMMITTED: return "committed"
		State.EXECUTING: return "executing"
		State.COMPLETED: return "completed"
		State.INTERRUPTED: return "interrupted"
		State.CANCELLED: return "cancelled"
	return "unknown"
