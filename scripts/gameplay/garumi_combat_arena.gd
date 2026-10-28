extends Node2D
class_name GarumiCombatArena

@export var tamano_arena: Vector2 = Vector2(480.0, 300.0)
@export var margen_exterior: float = 24.0

var jugador: Node2D
var garumi: Node2D
var garumis: Array[Node2D] = []
var centro_arena: Vector2 = Vector2.ZERO
var limites_globales: Rect2 = Rect2()
var activa: bool = false


func iniciar(nuevo_jugador: Node2D, nuevo_garumi: Node2D) -> void:
	jugador = nuevo_jugador
	garumi = nuevo_garumi
	garumis.clear()
	if is_instance_valid(garumi):
		garumis.append(garumi)
	if not is_instance_valid(jugador) or not is_instance_valid(garumi):
		return
	centro_arena = (jugador.global_position + garumi.global_position) * 0.5
	# La arena debe caber en el área visible de la cámara, especialmente arriba y abajo.
	var camara := get_viewport().get_camera_2d()
	if camara != null:
		var tamano_visible := get_viewport().get_visible_rect().size / camara.zoom
		tamano_arena.x = minf(tamano_arena.x, maxf(160.0, tamano_visible.x - 48.0))
		tamano_arena.y = minf(tamano_arena.y, maxf(160.0, tamano_visible.y - 72.0))
	limites_globales = Rect2(centro_arena - tamano_arena * 0.5, tamano_arena)
	global_position = centro_arena
	activa = true
	add_to_group("garumi_combat_arena")
	_ajustar_participantes()
	queue_redraw()


func agregar_garumi(nuevo_garumi: Node2D) -> void:
	if not activa or not is_instance_valid(nuevo_garumi) or garumis.has(nuevo_garumi):
		return
	garumis.append(nuevo_garumi)
	var angulo := TAU * float(garumis.size() - 1) / 3.0
	nuevo_garumi.global_position = _limitar_posicion(centro_arena + Vector2(cos(angulo), sin(angulo)) * 62.0)
	queue_redraw()


func obtener_garumis() -> Array[Node2D]:
	return garumis.duplicate()


func terminar() -> void:
	activa = false
	remove_from_group("garumi_combat_arena")
	queue_free()


func esta_activa() -> bool:
	return activa


func obtener_centro() -> Vector2:
	return centro_arena


func _physics_process(_delta: float) -> void:
	if not activa:
		return
	if not is_instance_valid(jugador) or not is_instance_valid(garumi):
		terminar()
		return
	garumis = garumis.filter(func(item: Node2D) -> bool: return is_instance_valid(item))
	_ajustar_participantes()
	_excluir_criaturas_ajenas()


func _ajustar_participantes() -> void:
	var posicion_jugador_anterior := jugador.global_position
	jugador.global_position = _limitar_posicion(posicion_jugador_anterior)
	if jugador is CharacterBody2D and jugador.global_position != posicion_jugador_anterior:
		(jugador as CharacterBody2D).velocity = Vector2.ZERO
	for rival_actual in garumis:
		if not is_instance_valid(rival_actual):
			continue
		var posicion_anterior := rival_actual.global_position
		rival_actual.global_position = _limitar_posicion(posicion_anterior)
		if rival_actual is CharacterBody2D and rival_actual.global_position != posicion_anterior:
			(rival_actual as CharacterBody2D).velocity = Vector2.ZERO


func _limitar_posicion(posicion: Vector2) -> Vector2:
	var margen := 12.0
	return Vector2(
		clampf(posicion.x, limites_globales.position.x + margen, limites_globales.end.x - margen),
		clampf(posicion.y, limites_globales.position.y + margen, limites_globales.end.y - margen)
	)


func ajustar_jugador_tras_movimiento() -> void:
	if not activa or not is_instance_valid(jugador):
		return
	var antes := jugador.global_position
	jugador.global_position = _limitar_posicion(antes)
	if jugador is CharacterBody2D and jugador.global_position != antes:
		(jugador as CharacterBody2D).velocity = Vector2.ZERO


## Solo se escapa al tocar un borde y gastar un dash hacia fuera de ese borde.
func intentar_escapar(nodo_jugador: Node2D, direccion_dash: Vector2) -> bool:
	if not activa or nodo_jugador != jugador or direccion_dash.length_squared() < 0.01:
		return false
	var posicion := jugador.global_position
	var margen := 15.0
	var sale_por_borde := (
		(posicion.x <= limites_globales.position.x + margen and direccion_dash.x < -0.55)
		or (posicion.x >= limites_globales.end.x - margen and direccion_dash.x > 0.55)
		or (posicion.y <= limites_globales.position.y + margen and direccion_dash.y < -0.55)
		or (posicion.y >= limites_globales.end.y - margen and direccion_dash.y > 0.55)
	)
	if not sale_por_borde:
		return false
	print("GarumiCombatArena: escape confirmado por dash hacia el exterior.")
	for rival_actual in garumis:
		if is_instance_valid(rival_actual) and rival_actual.has_method("finalizar_enfrentamiento"):
			rival_actual.call("finalizar_enfrentamiento")
	terminar()
	return true


func _esta_en_borde(posicion: Vector2) -> bool:
	return posicion != _limitar_posicion(posicion)


func _excluir_criaturas_ajenas() -> void:
	var candidatas: Array[Node] = []
	for grupo in ["creatures", "garumis"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if nodo not in candidatas:
				candidatas.append(nodo)
	for nodo in candidatas:
		if not nodo is Node2D or nodo in garumis or nodo == jugador:
			continue
		if nodo.is_in_group("garumi_combat_ally"):
			continue
		if nodo is Garumi and (nodo as Garumi).esta_vinculado():
			continue
		var criatura := nodo as Node2D
		if not limites_globales.has_point(criatura.global_position):
			continue
		var distancias := [
			absf(criatura.global_position.x - limites_globales.position.x),
			absf(limites_globales.end.x - criatura.global_position.x),
			absf(criatura.global_position.y - limites_globales.position.y),
			absf(limites_globales.end.y - criatura.global_position.y)
		]
		var menor := 0
		for i in range(1, distancias.size()):
			if distancias[i] < distancias[menor]:
				menor = i
		var posicion := criatura.global_position
		match menor:
			0: posicion.x = limites_globales.position.x - margen_exterior
			1: posicion.x = limites_globales.end.x + margen_exterior
			2: posicion.y = limites_globales.position.y - margen_exterior
			3: posicion.y = limites_globales.end.y + margen_exterior
		criatura.global_position = posicion
		if criatura is CharacterBody2D:
			(criatura as CharacterBody2D).velocity = Vector2.ZERO


func _draw() -> void:
	if not activa:
		return
	var rect := Rect2(-tamano_arena * 0.5, tamano_arena)
	draw_rect(rect, Color(0.75, 0.49, 0.20, 0.10), true)
	draw_rect(rect, Color(0.95, 0.72, 0.36, 0.95), false, 4.0, true)
	draw_rect(rect.grow(-5.0), Color(0.95, 0.72, 0.36, 0.38), false, 1.0, true)
