extends Control


var player: Node = null
var world_generator: Node = null

var mostrar_contexto_mundo: bool = false

var _tiempo_debug: float = 0.0
var _tiempo_contexto: float = 0.0

var location_panel: Control = null
var location_label: Label = null

var health_bar: ProgressBar = null
var health_value: Label = null

var stamina_bar: ProgressBar = null
var stamina_value: Label = null

var eterium_bar: ProgressBar = null
var eterium_value: Label = null

var interaction_prompt: Label = null


func _ready() -> void:
	_buscar_nodos_hud()
	_preparar_location()

	if location_panel:
		location_panel.visible = false

	if interaction_prompt:
		interaction_prompt.visible = false

	_buscar_player()
	_buscar_world_generator()

	print("HUD: iniciado.")


func configurar(jugador: Node = null, generador: Node = null) -> void:
	# Main.gd utiliza este método para entregar al HUD
	# las referencias importantes del mundo.

	if jugador != null:
		player = jugador

	if generador != null:
		world_generator = generador

	if not is_instance_valid(player):
		_buscar_player()

	if not is_instance_valid(world_generator):
		_buscar_world_generator()

	_conectar_senales_player()

	print(
		"HUD: configurar() → Player=",
		player != null,
		" WorldGenerator=",
		world_generator != null
	)

	_actualizar_vida()
	_actualizar_stamina()
	_actualizar_eterium()

	if mostrar_contexto_mundo:
		_actualizar_contexto()


func _buscar_nodos_hud() -> void:
	health_bar = _buscar_nodo_tipo("HealthBar", ProgressBar)
	health_value = _buscar_nodo_tipo("HealthValue", Label)

	stamina_bar = _buscar_nodo_tipo("StaminaBar", ProgressBar)
	stamina_value = _buscar_nodo_tipo("StaminaValue", Label)

	eterium_bar = _buscar_nodo_tipo("EteriumBar", ProgressBar)
	eterium_value = _buscar_nodo_tipo("EteriumValue", Label)

	interaction_prompt = _buscar_nodo_tipo("InteractionPrompt", Label)

	print(
		"HUD: nodos → ",
		"HealthBar=", health_bar != null,
		" HealthValue=", health_value != null,
		" StaminaBar=", stamina_bar != null,
		" StaminaValue=", stamina_value != null,
		" EteriumBar=", eterium_bar != null,
		" EteriumValue=", eterium_value != null,
		" InteractionPrompt=", interaction_prompt != null
	)


func _buscar_nodo_tipo(nombre: String, tipo: Variant) -> Variant:
	var nodo := find_child(nombre, true, false)

	if nodo == null:
		print("HUD: no se encontró nodo → ", nombre)
		return null

	if not is_instance_of(nodo, tipo):
		print(
			"HUD: nodo ",
			nombre,
			" existe pero es ",
			nodo.get_class(),
			" y no ",
			str(tipo)
		)
		return null

	return nodo


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		_buscar_player()

	if not is_instance_valid(world_generator):
		_buscar_world_generator()

	if not is_instance_valid(player):
		return

	_actualizar_vida()
	_actualizar_stamina()
	_actualizar_eterium()

	_tiempo_contexto += delta

	if _tiempo_contexto >= 0.25:
		_tiempo_contexto = 0.0
		_actualizar_contexto()

	_tiempo_debug += delta

	if _tiempo_debug >= 0.5:
		_tiempo_debug = 0.0

		print(
			"HUD DEBUG → Vida: ",
			_obtener_entero(player, "health", 0),
			" | Stamina: ",
			_obtener_float(player, "stamina", 0.0),
			" | Eterium: ",
			_obtener_float(player, "mana", 0.0)
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed:
			return

		if key_event.echo:
			return

		if key_event.keycode == KEY_F3:
			mostrar_contexto_mundo = not mostrar_contexto_mundo

			if location_panel:
				location_panel.visible = mostrar_contexto_mundo

			if mostrar_contexto_mundo:
				_actualizar_contexto()

			get_viewport().set_input_as_handled()


func _preparar_location() -> void:
	var nodo := find_child("LocationLabel", true, false)

	if nodo == null:
		print("HUD: no se encontró LocationLabel.")
		return

	if nodo is Control:
		location_panel = nodo as Control

		var label := location_panel.find_child("Label", true, false)

		if label is Label:
			location_label = label as Label
			return

		label = location_panel.find_child("Text", true, false)

		if label is Label:
			location_label = label as Label
			return

		var primer_label := _buscar_primer_label(location_panel)

		if primer_label != null:
			location_label = primer_label
			return

	print("HUD: LocationLabel existe, pero no contiene ningún Label.")


func _buscar_primer_label(nodo: Node) -> Label:
	for child in nodo.get_children():
		if child is Label:
			return child as Label

		var encontrado := _buscar_primer_label(child)

		if encontrado != null:
			return encontrado

	return null


func _buscar_player() -> void:
	var encontrado := get_tree().get_first_node_in_group("player")

	if encontrado == null:
		return

	player = encontrado

	print("HUD: Player asignado → ", player.name)

	_conectar_senales_player()


func _buscar_world_generator() -> void:
	var mundo := get_tree().current_scene

	if not is_instance_valid(mundo):
		return

	var encontrado := mundo.find_child(
		"WorldGenerator",
		true,
		false
	)

	if encontrado == null:
		return

	world_generator = encontrado

	print(
		"HUD: WorldGenerator asignado → ",
		world_generator.name
	)


func _conectar_senales_player() -> void:
	if not is_instance_valid(player):
		return

	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_al_recibir_cambio_vida):
			player.health_changed.connect(_al_recibir_cambio_vida)

	if player.has_signal("stamina_changed"):
		if not player.stamina_changed.is_connected(_al_recibir_cambio_stamina):
			player.stamina_changed.connect(_al_recibir_cambio_stamina)

	if player.has_signal("mana_changed"):
		if not player.mana_changed.is_connected(_al_recibir_cambio_mana):
			player.mana_changed.connect(_al_recibir_cambio_mana)


func _al_recibir_cambio_vida(actual: int, maximo: int) -> void:
	_actualizar_barra(
		health_bar,
		health_value,
		actual,
		maximo
	)


func _al_recibir_cambio_stamina(actual: float, maximo: float) -> void:
	_actualizar_barra_float(
		stamina_bar,
		stamina_value,
		actual,
		maximo
	)


func _al_recibir_cambio_mana(actual: int, maximo: int) -> void:
	_actualizar_barra(
		eterium_bar,
		eterium_value,
		actual,
		maximo
	)


func _actualizar_vida() -> void:
	var vida_actual := _obtener_entero(
		player,
		"health",
		0
	)

	var vida_maxima := _obtener_entero(
		player,
		"max_health",
		100
	)

	_actualizar_barra(
		health_bar,
		health_value,
		vida_actual,
		vida_maxima
	)


func _actualizar_stamina() -> void:
	var stamina_actual := _obtener_float(
		player,
		"stamina",
		0.0
	)

	var stamina_maxima := _obtener_float(
		player,
		"max_stamina",
		100.0
	)

	_actualizar_barra_float(
		stamina_bar,
		stamina_value,
		stamina_actual,
		stamina_maxima
	)


func _actualizar_eterium() -> void:
	var eterium_actual := _obtener_float(
		player,
		"mana",
		0.0
	)

	var eterium_maximo := _obtener_float(
		player,
		"max_mana",
		100.0
	)

	_actualizar_barra_float(
		eterium_bar,
		eterium_value,
		eterium_actual,
		eterium_maximo
	)


func _actualizar_barra(
	barra: ProgressBar,
	texto: Label,
	actual: int,
	maximo: int
) -> void:
	if barra == null:
		return

	barra.max_value = maximo
	barra.value = actual

	if texto != null:
		texto.text = str(actual) + " / " + str(maximo)


func _actualizar_barra_float(
	barra: ProgressBar,
	texto: Label,
	actual: float,
	maximo: float
) -> void:
	if barra == null:
		return

	barra.max_value = maximo
	barra.value = actual

	if texto != null:
		texto.text = str(roundi(actual)) + " / " + str(roundi(maximo))


func _actualizar_contexto() -> void:
	if not mostrar_contexto_mundo:
		if location_panel:
			location_panel.visible = false

		return

	if location_panel:
		location_panel.visible = true

	if location_label == null:
		return

	if not is_instance_valid(player):
		location_label.text = "Sin jugador"
		return

	if not is_instance_valid(world_generator):
		_buscar_world_generator()

	if not is_instance_valid(world_generator):
		location_label.text = "Sin WorldGenerator"
		return

	var contexto := _obtener_contexto_mundo(
		player.global_position
	)

	if contexto.is_empty():
		location_label.text = "Sin información del mundo"
		print(
			"HUD: get_contexto_at() no devolvió información para ",
			player.global_position
		)
		return

	var bioma = _obtener_nombre_contexto(
		contexto,
		"bioma"
	)

	var ecosistema = _obtener_nombre_contexto(
		contexto,
		"ecosistema"
	)

	var habitat = _obtener_nombre_contexto(
		contexto,
		"habitat"
	)

	location_label.text = (
		"Bioma: " + bioma +
		"\nEcosistema: " + ecosistema +
		"\nHábitat: " + habitat
	)


func _obtener_contexto_mundo(posicion: Vector2) -> Dictionary:
	if not is_instance_valid(world_generator):
		return {}

	if world_generator.has_method("get_contexto_at"):
		var resultado = world_generator.call(
			"get_contexto_at",
			posicion
		)

		if resultado is Dictionary:
			return resultado

	var contexto: Dictionary = {}

	if world_generator.has_method("get_bioma_at"):
		contexto["bioma"] = world_generator.call(
			"get_bioma_at",
			posicion
		)

	if world_generator.has_method("get_ecosistema_at"):
		contexto["ecosistema"] = world_generator.call(
			"get_ecosistema_at",
			posicion
		)

	if world_generator.has_method("get_habitats_at"):
		var habitats = world_generator.call(
			"get_habitats_at",
			posicion
		)

		if habitats is Array and not habitats.is_empty():
			contexto["habitat"] = habitats[0]

	return contexto


func _obtener_nombre_contexto(
	contexto: Dictionary,
	clave: String
) -> String:
	var valor = contexto.get(clave, null)

	if valor == null:
		valor = contexto.get(
			clave + "_nombre",
			null
		)

	if valor == null:
		return "Desconocido"

	if valor is String:
		return valor

	if valor is Dictionary:
		if valor.has("nombre"):
			return str(valor["nombre"])

		if valor.has("name"):
			return str(valor["name"])

		if valor.has(clave + "_nombre"):
			return str(valor[clave + "_nombre"])

		return "Desconocido"

	if valor is Object:
		var nombre = valor.get("nombre")

		if nombre != null:
			return str(nombre)

		nombre = valor.get("name")

		if nombre != null:
			return str(nombre)

	return str(valor)


func _obtener_entero(
	objeto: Object,
	propiedad: String,
	valor_por_defecto: int
) -> int:
	if not is_instance_valid(objeto):
		return valor_por_defecto

	var valor = objeto.get(propiedad)

	if valor == null:
		return valor_por_defecto

	return int(valor)


func _obtener_float(
	objeto: Object,
	propiedad: String,
	valor_por_defecto: float
) -> float:
	if not is_instance_valid(objeto):
		return valor_por_defecto

	var valor = objeto.get(propiedad)

	if valor == null:
		return valor_por_defecto

	return float(valor)


func mostrar_interaccion(texto: String) -> void:
	if interaction_prompt == null:
		return

	interaction_prompt.text = texto
	interaction_prompt.visible = true


func ocultar_interaccion() -> void:
	if interaction_prompt == null:
		return

	interaction_prompt.visible = false
