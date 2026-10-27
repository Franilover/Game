extends Node2D
class_name GarumiCombatArena

@export var tamano_arena: Vector2 = Vector2(480.0, 300.0)
@export var margen_exterior: float = 24.0

var jugador: Node2D
var garumi: Node2D
var centro_arena: Vector2 = Vector2.ZERO
var limites_globales: Rect2 = Rect2()
var activa: bool = false


func iniciar(nuevo_jugador: Node2D, nuevo_garumi: Node2D) -> void:
	jugador = nuevo_jugador
	garumi = nuevo_garumi
	if not is_instance_valid(jugador) or not is_instance_valid(garumi):
		return
	centro_arena = (jugador.global_position + garumi.global_position) * 0.5
	limites_globales = Rect2(centro_arena - tamano_arena * 0.5, tamano_arena)
	global_position = centro_arena
	activa = true
	add_to_group("garumi_combat_arena")
	_ajustar_participantes()
	queue_redraw()


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
	_ajustar_participantes()
	_excluir_criaturas_ajenas()


func _ajustar_participantes() -> void:
	var posicion_jugador_anterior := jugador.global_position
	var posicion_garumi_anterior := garumi.global_position
	jugador.global_position = _limitar_posicion(posicion_jugador_anterior)
	garumi.global_position = _limitar_posicion(posicion_garumi_anterior)
	if jugador is CharacterBody2D and jugador.global_position != posicion_jugador_anterior:
		(jugador as CharacterBody2D).velocity = Vector2.ZERO
	if garumi is CharacterBody2D and garumi.global_position != posicion_garumi_anterior:
		(garumi as CharacterBody2D).velocity = Vector2.ZERO


func _limitar_posicion(posicion: Vector2) -> Vector2:
	var margen := 12.0
	return Vector2(
		clampf(posicion.x, limites_globales.position.x + margen, limites_globales.end.x - margen),
		clampf(posicion.y, limites_globales.position.y + margen, limites_globales.end.y - margen)
	)


func _esta_en_borde(posicion: Vector2) -> bool:
	return posicion != _limitar_posicion(posicion)


func _excluir_criaturas_ajenas() -> void:
	var candidatas: Array[Node] = []
	for grupo in ["creatures", "garumis"]:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if nodo not in candidatas:
				candidatas.append(nodo)
	for nodo in candidatas:
		if not nodo is Node2D or nodo == garumi or nodo == jugador:
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
