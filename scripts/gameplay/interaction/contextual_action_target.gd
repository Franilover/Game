extends Node2D
class_name ContextualActionTarget
## Punto del mundo que participa en el InteractionSystem y reutiliza
## el aviso [LMB] del HUD, sin implementar una interfaz propia.

var _texto: String = ""
var _distancia := 48.0
var _condicion: Callable
var _accion: Callable


func configurar(texto: String, distancia: float, condicion: Callable, accion: Callable) -> void:
	_texto = texto.strip_edges()
	_distancia = maxf(distancia, 0.0)
	_condicion = condicion
	_accion = accion
	if not is_in_group("interactable"):
		add_to_group("interactable")


func establecer_texto(texto: String) -> void:
	_texto = texto.strip_edges()


func es_dialogable() -> bool:
	return true


func get_interaction_distance() -> float:
	return _distancia


func get_interaction_priority() -> int:
	return 100


func get_interaction_text() -> String:
	return _texto


func can_interact(jugador: Node) -> bool:
	if not is_instance_valid(jugador) or not jugador is Node2D:
		return false
	if not _condicion.is_valid() or not bool(_condicion.call(jugador)):
		return false
	return (jugador as Node2D).global_position.distance_to(global_position) <= _distancia


func interact(jugador: Node) -> void:
	if not can_interact(jugador) or not _accion.is_valid():
		return
	_accion.call(jugador)
