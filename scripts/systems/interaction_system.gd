extends Node


signal objetivo_cambiado(objetivo: Node)


@export var interaction_distance: float = 48.0
@export var scan_interval: float = 0.10


var player: Node = null
var hud: Control = null

var objetivo_actual: Node = null

var _scan_timer: float = 0.0


func configurar(
	nuevo_player: Node,
	nuevo_hud: Control
) -> void:
	player = nuevo_player
	hud = nuevo_hud

	print(
		"InteractionSystem: configurado."
	)

	print(
		"InteractionSystem: recolectables actuales = ",
		_contar_objetivos_contextuales()
	)

	_cambiar_objetivo(null)
	_buscar_objetivo()


func _process(delta: float) -> void:
	if player == null:
		return

	if _interaccion_bloqueada():
		if objetivo_actual != null:
			_cambiar_objetivo(null)
		return

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = maxf(scan_interval, 0.05)
		_buscar_objetivo()
		_actualizar_prompt_actual()

	if objetivo_actual != null and not is_instance_valid(objetivo_actual):
		_cambiar_objetivo(null)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_alive:
		return

	if _interaccion_bloqueada():
		return

	if not event.is_action_pressed("primary_action"):
		return

	if objetivo_actual == null or not is_instance_valid(objetivo_actual):
		return

	if not objetivo_actual.has_method("interact"):
		return

	objetivo_actual.call("interact", player)
	get_viewport().set_input_as_handled()


func _interaccion_bloqueada() -> bool:
	if get_tree().paused:
		return true

	var inventory: Node = get_tree().get_first_node_in_group("inventory")
	if inventory is CanvasItem and bool((inventory as CanvasItem).visible):
		return true

	var admin_console: Node = get_tree().get_first_node_in_group("admin_console")
	if admin_console is CanvasItem and bool((admin_console as CanvasItem).visible):
		return true

	var dialogue_system := get_tree().get_first_node_in_group("dialogue_system")
	if dialogue_system != null and dialogue_system.has_method("esta_abierto"):
		if bool(dialogue_system.call("esta_abierto")):
			return true

	var hud_modal: Variant = null
	if hud != null and hud.has_method("esta_mostrando_panel_interaccion"):
		hud_modal = hud.call("esta_mostrando_panel_interaccion")

	if hud_modal != null and bool(hud_modal):
		return true

	return false


func _buscar_objetivo() -> void:
	var mejor_objetivo: Node = null
	var mejor_prioridad: int = -2147483648
	var mejor_distancia_sq: float = INF

	var candidatos: Array[Node] = (
		get_tree().get_nodes_in_group("interactable")
	)

	for candidato in candidatos:
		if not is_instance_valid(candidato):
			continue

		if candidato == player:
			continue

		if not candidato is Node2D:
			continue

		if not candidato.is_inside_tree():
			continue

		if not _es_objetivo_contextual(candidato):
			continue

		var puede: bool = true
		if candidato.has_method("can_interact"):
			puede = bool(candidato.call("can_interact", player))

		if not puede:
			continue

		var candidato_2d := candidato as Node2D
		var distancia_maxima: float = interaction_distance

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

		var prioridad: int = 0
		if candidato.has_method("get_interaction_priority"):
			prioridad = int(candidato.call("get_interaction_priority"))

		if (
			prioridad > mejor_prioridad
			or (
				prioridad == mejor_prioridad
				and distancia_sq < mejor_distancia_sq
			)
		):
			mejor_prioridad = prioridad
			mejor_distancia_sq = distancia_sq
			mejor_objetivo = candidato

	_cambiar_objetivo(mejor_objetivo)


func _es_objetivo_contextual(candidato: Node) -> bool:
	if candidato.has_method("es_recolectable"):
		if bool(candidato.call("es_recolectable")):
			return true

	if candidato.has_method("es_dialogable"):
		if bool(candidato.call("es_dialogable")):
			return true

	return false


func _contar_objetivos_contextuales() -> int:
	var cantidad := 0

	for candidato in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(candidato) and _es_objetivo_contextual(candidato):
			cantidad += 1

	return cantidad


func _actualizar_prompt_actual() -> void:
	if hud == null:
		return

	if objetivo_actual == null or not is_instance_valid(objetivo_actual):
		if hud.has_method("ocultar_interaccion"):
			hud.call("ocultar_interaccion")
		return

	var texto := "Recoger"

	if objetivo_actual.has_method("get_interaction_text"):
		texto = str(objetivo_actual.call("get_interaction_text"))

	if hud.has_method("mostrar_interaccion"):
		hud.call("mostrar_interaccion", texto)


func _cambiar_objetivo(nuevo_objetivo: Node) -> void:
	if objetivo_actual == nuevo_objetivo:
		return

	objetivo_actual = nuevo_objetivo
	objetivo_cambiado.emit(objetivo_actual)

	if objetivo_actual == null:
		if hud != null and hud.has_method("ocultar_interaccion"):
			hud.call("ocultar_interaccion")
		return

	var texto := "Recoger"

	if objetivo_actual.has_method("get_interaction_text"):
		texto = str(objetivo_actual.call("get_interaction_text"))

	print(
		"InteractionSystem: objetivo contextual = ",
		objetivo_actual.name,
		" | accion = ",
		texto
	)

	if hud != null and hud.has_method("mostrar_interaccion"):
		hud.call("mostrar_interaccion", texto)
