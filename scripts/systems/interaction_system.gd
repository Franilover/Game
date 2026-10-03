extends Node


signal objetivo_cambiado(objetivo: Node)


@export var interaction_distance: float = 48.0
@export var scan_interval: float = 0.10


var player: Node = null
var hud: Control = null

var objetivo_actual: Node = null

var _scan_timer: float = 0.0
var _interaction_distance_sq: float = 0.0


func configurar(
	nuevo_player: Node,
	nuevo_hud: Control
) -> void:
	player = nuevo_player
	hud = nuevo_hud
	_interaction_distance_sq = interaction_distance * interaction_distance

	print(
		"InteractionSystem: configurado."
	)

	print(
		"InteractionSystem: interactuables actuales = ",
		get_tree().get_nodes_in_group(
			"interactable"
		).size()
	)

	_cambiar_objetivo(null)


func _process(delta: float) -> void:
	if player == null:
		return

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = maxf(scan_interval, 0.05)
		_buscar_objetivo()

	if objetivo_actual != null and not is_instance_valid(objetivo_actual):
		_cambiar_objetivo(null)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_alive:
		return
	if not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	_interactuar()
	get_viewport().set_input_as_handled()


func _buscar_objetivo() -> void:
	var mejor_objetivo: Node = null

	var mejor_distancia_sq: float = _interaction_distance_sq

	var candidatos: Array[Node] = (
		get_tree().get_nodes_in_group(
			"interactable"
		)
	)

	for candidato in candidatos:
		if not is_instance_valid(
			candidato
		):
			continue

		if candidato == player:
			continue

		if not candidato is Node2D:
			continue

		if not candidato.is_inside_tree():
			continue

		if candidato.has_method(
			"can_interact"
		):
			var puede: bool = bool(
				candidato.call(
					"can_interact",
					player
				)
			)

			if not puede:
				continue

		var candidato_2d := (
			candidato as Node2D
		)

		var distancia_sq: float = player.global_position.distance_squared_to(
			candidato_2d.global_position
		)

		if distancia_sq > _interaction_distance_sq:
			continue

		if distancia_sq < mejor_distancia_sq:
			mejor_distancia_sq = distancia_sq
			mejor_objetivo = candidato

	_cambiar_objetivo(
		mejor_objetivo
	)


func _cambiar_objetivo(
	nuevo_objetivo: Node
) -> void:
	if objetivo_actual == nuevo_objetivo:
		return

	objetivo_actual = nuevo_objetivo

	objetivo_cambiado.emit(
		objetivo_actual
	)

	if objetivo_actual == null:
		print(
			"InteractionSystem: sin objetivo."
		)

		if hud != null:
			if hud.has_method(
				"ocultar_interaccion"
			):
				hud.call(
					"ocultar_interaccion"
				)

		return

	var nombre: String = (
		objetivo_actual.name
	)

	var texto: String = (
		"Examinar"
	)

	if objetivo_actual.has_method(
		"get_nombre"
	):
		texto = str(
			objetivo_actual.call(
				"get_nombre"
			)
		)

	elif objetivo_actual.has_method(
		"get_interaction_text"
	):
		texto = str(
			objetivo_actual.call(
				"get_interaction_text"
			)
		)

	print(
		"InteractionSystem: objetivo = ",
		nombre
	)

	print(
		"InteractionSystem: texto = ",
		texto
	)

	if hud != null:
		if hud.has_method(
			"mostrar_interaccion"
		):
			hud.call(
				"mostrar_interaccion",
				texto
			)


func _interactuar() -> void:
	if objetivo_actual == null:
		return

	if not is_instance_valid(
		objetivo_actual
	):
		_cambiar_objetivo(null)
		return

	if objetivo_actual.has_method(
		"interact"
	):
		objetivo_actual.call(
			"interact",
			player
		)

	# No volver a disparar inmediatamente.
	await get_tree().process_frame
