extends RefCounted
class_name InteractionController

## Selecciona y ejecuta interacciones contextuales.
## No conoce HUD, inventario ni Supabase.

signal objetivo_cambiado(objetivo: Node)

var objetivo_actual: Node = null
var entity_manager: WorldEntityManager = null

func configurar_entidades(nuevo_entity_manager: WorldEntityManager) -> void:
	entity_manager = nuevo_entity_manager

func buscar_objetivo(player: Node, distancia_base: float) -> Node:
	if player == null or not is_instance_valid(player):
		establecer_objetivo(null)
		return null

	var mejor_objetivo: Node = null
	var mejor_prioridad: int = -2147483648
	var mejor_distancia_sq: float = INF

	var candidatos: Array = []
	var vistos: Dictionary = {}

	# Fuente canónica principal: el EntityManager de la zona activa.
	# Tras una transición de zona puede existir un pequeño intervalo en el que
	# una entidad ya está en el SceneTree pero todavía no está registrada.
	if entity_manager != null and is_instance_valid(entity_manager):
		for candidato_variant in entity_manager.obtener_entidades_activas():
			if not candidato_variant is Node:
				continue
			var candidato_registrado := candidato_variant as Node
			if is_instance_valid(candidato_registrado):
				candidatos.append(candidato_registrado)
				vistos[candidato_registrado.get_instance_id()] = true

	# Fallback de runtime: las entidades interactuables siguen marcadas con
	# "interactable". Esto evita perder la interacción durante cambios de zona
	# si el registro del EntityManager todavía no se ha sincronizado.
	var candidatos_grupo := player.get_tree().get_nodes_in_group("interactable")
	for candidato_variant in candidatos_grupo:
		if not candidato_variant is Node:
			continue
		var candidato_grupo := candidato_variant as Node
		if not is_instance_valid(candidato_grupo):
			continue
		var instance_id := candidato_grupo.get_instance_id()
		if vistos.has(instance_id):
			continue
		vistos[instance_id] = true
		candidatos.append(candidato_grupo)

	for candidato_variant in candidatos:
		if not candidato_variant is Node:
			continue
		var candidato := candidato_variant as Node
		if not is_instance_valid(candidato):
			continue
		if candidato == player:
			continue
		if not candidato is Node2D:
			continue
		if not candidato.is_inside_tree():
			continue
		if not es_objetivo_contextual(candidato):
			continue

		var puede := true
		if candidato.has_method("can_interact"):
			puede = bool(candidato.call("can_interact", player))
		if not puede:
			continue

		var candidato_2d := candidato as Node2D
		var distancia_maxima := maxf(distancia_base, 0.0)
		if candidato.has_method("get_interaction_distance"):
			distancia_maxima = maxf(
				float(candidato.call("get_interaction_distance")),
				0.0
			)

		var distancia_sq: float = player.global_position.distance_squared_to(
			candidato_2d.global_position
		)
		if distancia_sq > distancia_maxima * distancia_maxima:
			continue

		var prioridad := 0
		if candidato.has_method("get_interaction_priority"):
			prioridad = int(candidato.call("get_interaction_priority"))

		if prioridad > mejor_prioridad or (
			prioridad == mejor_prioridad
			and distancia_sq < mejor_distancia_sq
		):
			mejor_prioridad = prioridad
			mejor_distancia_sq = distancia_sq
			mejor_objetivo = candidato

	establecer_objetivo(mejor_objetivo)
	return objetivo_actual

func es_objetivo_contextual(candidato: Node) -> bool:
	if candidato == null:
		return false
	if candidato.has_method("es_recolectable") and bool(candidato.call("es_recolectable")):
		return true
	if candidato.has_method("es_dialogable") and bool(candidato.call("es_dialogable")):
		return true
	return false

func interactuar(player: Node) -> bool:
	if objetivo_actual == null or not is_instance_valid(objetivo_actual):
		return false
	if not objetivo_actual.has_method("interact"):
		return false
	objetivo_actual.call("interact", player)
	return true

func obtener_texto() -> String:
	if objetivo_actual == null or not is_instance_valid(objetivo_actual):
		return ""
	if objetivo_actual.has_method("get_interaction_text"):
		return str(objetivo_actual.call("get_interaction_text"))
	return "Recoger"

func establecer_objetivo(nuevo_objetivo: Node) -> void:
	if objetivo_actual == nuevo_objetivo:
		return
	objetivo_actual = nuevo_objetivo
	objetivo_cambiado.emit(objetivo_actual)
