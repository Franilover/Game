extends Node


signal objetivo_cambiado(objetivo: Node)


@export var interaction_distance: float = 48.0
@export var scan_interval: float = 0.10


var player: Node = null
var hud: Control = null

var interaction_controller := InteractionController.new()
var objetivo_actual: Node = null

var _scan_timer: float = 0.0


func configurar(
	nuevo_player: Node,
	nuevo_hud: Control
) -> void:
	player = nuevo_player
	hud = nuevo_hud
	if not interaction_controller.objetivo_cambiado.is_connected(_cambiar_objetivo):
		interaction_controller.objetivo_cambiado.connect(_cambiar_objetivo)

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


func _input(event: InputEvent) -> void:
	if player == null or not player.is_alive:
		return

	if _interaccion_bloqueada():
		return

	if not event.is_action_pressed("primary_action"):
		return

	# Revalidamos el objetivo justo al hacer click. Así un objeto que
	# entró en alcance entre dos escaneos no pierde la interacción.
	_buscar_objetivo()

	# La interacción contextual tiene prioridad absoluta.
	# Si hay algo recogible/dialogable dentro del alcance, el click
	# izquierdo se consume aquí antes de mirar la hotbar.
	if interaction_controller.interactuar(player):
		get_viewport().set_input_as_handled()
		return

	var inventory: Node = get_tree().get_first_node_in_group("inventory")
	var objeto_activo: Dictionary = {}

	if inventory != null and inventory.has_method("obtener_objeto_activo"):
		var objeto_activo_variant: Variant = inventory.call("obtener_objeto_activo")
		if objeto_activo_variant is Dictionary:
			objeto_activo = (objeto_activo_variant as Dictionary).duplicate(true)

	# Sin interacción contextual, los objetos colocables se usan con
	# el click izquierdo de la hotbar.
	if not objeto_activo.is_empty():
		var world_items: Node = GarliaWorldItems
		if (
			world_items != null
			and world_items.has_method("es_objeto_colocable")
			and bool(world_items.call("es_objeto_colocable", objeto_activo))
		):
			if world_items.has_method("colocar_objeto"):
				var colocado: bool = bool(
					world_items.call(
						"colocar_objeto",
						objeto_activo,
						(player as Node2D).get_global_mouse_position()
					)
				)
				if colocado:
					if inventory.has_method("consumir_objeto_activo"):
						inventory.call("consumir_objeto_activo", 1)
					get_viewport().set_input_as_handled()
					return

		# Si el objeto activo no es colocable, no lo consumimos aquí:
		# CombatSystem debe ejecutar su acción primaria (arma/herramienta).
		# No devolver ni marcar el evento como manejado.



func _interaccion_bloqueada() -> bool:
	return GameState.esta_entrada_de_juego_bloqueada()


func _buscar_objetivo() -> void:
	interaction_controller.buscar_objetivo(
		player,
		interaction_distance
	)


func _contar_objetivos_contextuales() -> int:
	var cantidad := 0

	for candidato in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(candidato) and interaction_controller.es_objetivo_contextual(candidato):
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
