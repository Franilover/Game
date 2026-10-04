extends Node
class_name CombatController

signal ataque_solicitado(direccion: Vector2, objeto: Dictionary, modo: String)

var input_gate: Node = null

func configurar_gate(gate: Node) -> void:
	input_gate = gate

func puede_actuar() -> bool:
	if input_gate == null or not is_instance_valid(input_gate):
		return true
	if input_gate.has_method("esta_bloqueado"):
		return not bool(input_gate.call("esta_bloqueado"))
	return true

func solicitar_ataque(direccion: Vector2, objeto: Dictionary, modo: String) -> bool:
	if not puede_actuar():
		return false
	ataque_solicitado.emit(direccion, objeto.duplicate(true), modo)
	return true
