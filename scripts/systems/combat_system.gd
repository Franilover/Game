extends Node

signal ataque_realizado(atacante: Node, objetivo: Node, danio: int)
signal ataque_sin_objetivo(atacante: Node)
signal accion_contextual_solicitada(objeto: Dictionary, usuario: Node)

@export var alcance_desarmado: float = 48.0
@export var ancho_ataque: float = 48.0
@export var danio_desarmado: int = 8

@export var duracion_ataque: float = 0.12
@export var color_ataque: Color = Color(0.86, 0.74, 0.52, 0.65)

var player: Node = null


func configurar(nuevo_player: Node) -> void:
	player = nuevo_player
	print("CombatSystem: configurado.")


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return

	if not event.is_action_pressed("primary_action"):
		return

	atacar()


func atacar() -> void:
	if player == null:
		return

	var objeto_activo := _obtener_objeto_activo()

	# La acción principal depende del objeto activo de la hotbar.
	# Un slot vacío conserva el ataque desarmado; un objeto no ofensivo
	# se deriva al sistema contextual en lugar de tratarlo como arma.
	if not objeto_activo.is_empty() and not bool(objeto_activo.get("es_arma", false)):
		accion_contextual_solicitada.emit(objeto_activo, player)
		print("CombatSystem: acción contextual solicitada para ", str(objeto_activo.get("nombre", "Objeto")))
		return

	var direccion: Vector2 = _obtener_direccion_ataque()
	var objetivo: Node = _buscar_objetivo(direccion)
	_mostrar_area_ataque(direccion)

	if objetivo == null:
		ataque_sin_objetivo.emit(player)
		return

	var danio: int = _calcular_danio(objeto_activo)
	if objetivo.has_method("take_damage"):
		objetivo.call("take_damage", danio)
		_animar_objetivo(objetivo)
		ataque_realizado.emit(player, objetivo, danio)
		print("CombatSystem: ", player.name, " atacó a ", objetivo.name, " por ", danio, " de daño.")


func _obtener_objeto_activo() -> Dictionary:
	var inventario := get_tree().get_first_node_in_group("inventory")
	if inventario == null or not inventario.has_method("obtener_objeto_activo"):
		return {}
	var objeto: Variant = inventario.call("obtener_objeto_activo")
	if objeto is Dictionary:
		return objeto
	return {}


func _calcular_danio(arma: Dictionary) -> int:
	if arma.is_empty():
		return danio_desarmado

	# Usa el campo canónico dado_dano recibido desde el catálogo.
	# Acepta un entero o notación de dados como 1d6 o 2d4+1.
	var expresion := str(arma.get("dado_dano", "")).strip_edges().to_lower()
	if expresion.is_valid_int():
		return maxi(0, int(expresion))

	var regex := RegEx.new()
	if regex.compile("^(\\d+)d(\\d+)([+-]\\d+)?$") != OK:
		return danio_desarmado

	var coincidencia := regex.search(expresion)
	if coincidencia == null:
		return danio_desarmado

	var cantidad_dados := clampi(int(coincidencia.get_string(1)), 1, 100)
	var caras := clampi(int(coincidencia.get_string(2)), 1, 1000)
	var modificador := int(coincidencia.get_string(3)) if coincidencia.get_string(3) != "" else 0
	var total := modificador
	for _i in range(cantidad_dados):
		total += randi_range(1, caras)
	return maxi(0, total)


func _obtener_direccion_ataque() -> Vector2:
	# El ataque siempre sigue hacia donde está mirando el jugador.
	if "facing" in player:
		var direccion: Vector2 = player.facing

		if direccion.length_squared() > 0.01:
			return direccion.normalized()

	# Seguridad por si el jugador todavía no tiene una
	# dirección válida.
	return Vector2.DOWN


func _buscar_objetivo(direccion: Vector2) -> Node:
	var mejor_objetivo: Node = null
	var mejor_distancia: float = INF

	var candidatos: Array[Node] = get_tree().get_nodes_in_group(
		"damageable"
	)

	var lado_medio: float = ancho_ataque * 0.5

	for candidato in candidatos:
		if not is_instance_valid(candidato):
			continue

		if candidato == player:
			continue

		if not candidato is Node2D:
			continue

		if not candidato.is_inside_tree():
			continue

		if "is_alive" in candidato and not bool(candidato.is_alive):
			continue

		var candidato_2d := candidato as Node2D

		var relativo: Vector2 = (
			candidato_2d.global_position
			- player.global_position
		)

		# Distancia en la dirección hacia la que mira el jugador.
		var frente: float = relativo.dot(direccion)

		# Distancia lateral respecto al centro del golpe.
		var lateral: float = abs(relativo.cross(direccion))

		# El área comienza un poco delante del jugador.
		var inicio: float = 8.0
		var final: float = (
			inicio + alcance_desarmado
		)

		if frente < inicio or frente > final:
			continue

		if lateral > lado_medio:
			continue

		var distancia: float = relativo.length()

		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor_objetivo = candidato

	return mejor_objetivo


func _mostrar_area_ataque(direccion: Vector2) -> void:
	if player == null:
		return

	var area_visual := Polygon2D.new()

	# Rectángulo que representa la zona del golpe.
	var mitad: float = ancho_ataque * 0.5
	var inicio: float = 8.0
	var final: float = (
		inicio + alcance_desarmado
	)

	area_visual.polygon = PackedVector2Array([
		Vector2(inicio, -mitad),
		Vector2(final, -mitad),
		Vector2(final, mitad),
		Vector2(inicio, mitad)
	])

	area_visual.color = color_ataque
	area_visual.z_index = 100

	var escena_actual := get_tree().current_scene

	if escena_actual == null:
		area_visual.queue_free()
		return

	escena_actual.add_child(area_visual)

	area_visual.global_position = player.global_position
	area_visual.rotation = direccion.angle()

	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		area_visual,
		"modulate:a",
		0.0,
		duracion_ataque
	)

	tween.tween_property(
		area_visual,
		"scale",
		Vector2(1.08, 1.08),
		duracion_ataque
	)

	tween.chain().tween_callback(
		area_visual.queue_free
	)


func _animar_objetivo(objetivo: Node) -> void:
	if not objetivo is CanvasItem:
		return

	var objetivo_visual := objetivo as CanvasItem

	var modulate_original: Color = (
		objetivo_visual.modulate
	)

	var tween := create_tween()

	tween.tween_property(
		objetivo_visual,
		"modulate",
		Color(
			1.0,
			0.45,
			0.45,
			modulate_original.a
		),
		0.04
	)

	tween.tween_property(
		objetivo_visual,
		"modulate",
		modulate_original,
		0.08
	)
