extends RefCounted
class_name CreatureTargetSelector

## Escoge el candidato válido más cercano.
## La política específica de cada especie se inyecta desde CreatureAI.
static func seleccionar_mas_cercano(
	origen: Node2D,
	candidatos: Array[Node2D],
	es_candidato_valido: Callable
) -> Node2D:
	if origen == null or not is_instance_valid(origen) or not es_candidato_valido.is_valid():
		return null

	var mejor: Node2D = null
	var mejor_distancia := INF
	for candidato in candidatos:
		if candidato == null or not is_instance_valid(candidato):
			continue
		if not candidato.is_inside_tree() or candidato.is_queued_for_deletion():
			continue
		if "is_alive" in candidato and not bool(candidato.get("is_alive")):
			continue
		if not bool(es_candidato_valido.call(candidato)):
			continue

		var distancia := origen.global_position.distance_squared_to(candidato.global_position)
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = candidato

	return mejor
