extends RefCounted
class_name CreatureInteractionMemory

## Memoria temporal y local a una criatura. No persiste entre sesiones.
## Cada actor se identifica por su instancia viva; no se guardan nodos fuertes.
const MAX_RECUERDOS: int = 16

var _recuerdos: Dictionary = {}


func registrar_agresion(actor: Node, intensidad: float = 1.0, duracion: float = 45.0) -> void:
	if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return
	if actor.is_in_group("garumis"):
		return
	var intensidad_segura := maxf(intensidad, 0.0)
	var duracion_segura := maxf(duracion, 0.0)
	if intensidad_segura <= 0.0 or duracion_segura <= 0.0:
		return

	var actor_id := actor.get_instance_id()
	var recuerdo: Dictionary = _recuerdos.get(actor_id, {})
	var referencia: WeakRef = recuerdo.get("actor_ref", weakref(actor))
	if referencia.get_ref() != actor:
		recuerdo = {"agresion": 0.0}
	recuerdo["actor_ref"] = weakref(actor)
	recuerdo["agresion"] = minf(float(recuerdo.get("agresion", 0.0)) + intensidad_segura, 5.0)
	recuerdo["tiempo_restante"] = duracion_segura
	_recuerdos[actor_id] = recuerdo
	_limitar_recuerdos()



## Evita que una criatura acumule referencias débiles sin límite durante una sesión.
func _limitar_recuerdos() -> void:
	while _recuerdos.size() > MAX_RECUERDOS:
		var id_mas_debil := -1
		var menor_agresion := INF
		var menor_duracion := INF
		for id_variant in _recuerdos:
			var datos: Dictionary = _recuerdos[id_variant]
			var agresion := float(datos.get("agresion", 0.0))
			var duracion_restante := float(datos.get("tiempo_restante", 0.0))
			if agresion < menor_agresion or (is_equal_approx(agresion, menor_agresion) and duracion_restante < menor_duracion):
				id_mas_debil = int(id_variant)
				menor_agresion = agresion
				menor_duracion = duracion_restante
		if id_mas_debil < 0:
			return
		_recuerdos.erase(id_mas_debil)


func obtener_agresion(actor: Node) -> float:
	if actor == null or not is_instance_valid(actor):
		return 0.0
	var recuerdo: Variant = _recuerdos.get(actor.get_instance_id(), null)
	if not recuerdo is Dictionary:
		return 0.0
	var datos := recuerdo as Dictionary
	var referencia: Variant = datos.get("actor_ref", null)
	if not referencia is WeakRef or referencia.get_ref() != actor:
		return 0.0
	return maxf(float(datos.get("agresion", 0.0)), 0.0)


func actualizar(delta: float, decaimiento_por_segundo: float = 0.2) -> void:
	var tiempo := maxf(delta, 0.0)
	var decaimiento := maxf(decaimiento_por_segundo, 0.0) * tiempo
	for actor_id_variant in _recuerdos.keys():
		var actor_id := int(actor_id_variant)
		var recuerdo: Dictionary = _recuerdos[actor_id]
		var referencia: Variant = recuerdo.get("actor_ref", null)
		var actor: Object = referencia.get_ref() if referencia is WeakRef else null
		if actor == null or not is_instance_valid(actor):
			_recuerdos.erase(actor_id)
			continue
		recuerdo["agresion"] = maxf(float(recuerdo.get("agresion", 0.0)) - decaimiento, 0.0)
		recuerdo["tiempo_restante"] = maxf(float(recuerdo.get("tiempo_restante", 0.0)) - tiempo, 0.0)
		if float(recuerdo["agresion"]) <= 0.0 or float(recuerdo["tiempo_restante"]) <= 0.0:
			_recuerdos.erase(actor_id)
		else:
			_recuerdos[actor_id] = recuerdo


func cantidad_recuerdos() -> int:
	return _recuerdos.size()


func limpiar() -> void:
	_recuerdos.clear()
