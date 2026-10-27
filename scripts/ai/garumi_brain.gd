extends Node
class_name GarumiBrain

## Cerebro reutilizable de los Garumis.
## Decide intención y dirección; CreatureMovement sigue siendo responsable
## de colisiones, velocidad y desplazamiento físico.

var garumi: Garumi = null
var configuracion: Dictionary = {}
var personalidad: Dictionary = {}
var movimiento: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _tiempo_decision: float = 0.0
var _direccion_objetivo: Vector2 = Vector2.ZERO
var _jugador_cercano: Node2D = null


func configurar(nuevo_garumi: Garumi) -> void:
	garumi = nuevo_garumi
	_rng.randomize()
	_recargar_configuracion()
	_tiempo_decision = 0.0
	if is_instance_valid(garumi) and garumi._movimiento != null:
		garumi._movimiento.tomar_control()


func _recargar_configuracion() -> void:
	if not is_instance_valid(garumi):
		return
	var ia: Dictionary = garumi.obtener_config_ia()
	var garumi_variant: Variant = ia.get("garumi", {})
	configuracion = garumi_variant if garumi_variant is Dictionary else {}
	var personalidad_variant: Variant = configuracion.get("personalidad", {})
	personalidad = personalidad_variant if personalidad_variant is Dictionary else {}
	var movimiento_variant: Variant = configuracion.get("movimiento", ia.get("movimiento", {}))
	movimiento = movimiento_variant if movimiento_variant is Dictionary else {}


func _physics_process(delta: float) -> void:
	if not is_instance_valid(garumi) or not garumi.is_inside_tree():
		return
	# El seguimiento de un Garumi vinculado y la arena de combate tienen
	# prioridad sobre la conducta silvestre.
	if garumi.esta_vinculado() or garumi.esta_enfrentamiento() or garumi.esta_guardado():
		return
	if garumi._movimiento == null:
		return

	_tiempo_decision -= delta
	if _tiempo_decision <= 0.0:
		_elegir_intencion()
		_tiempo_decision = _rng.randf_range(
			maxf(float(movimiento.get("intervalo_min", 0.8)), 0.2),
			maxf(float(movimiento.get("intervalo_max", 2.2)), 0.3)
		)
	garumi._movimiento.establecer_direccion(_direccion_objetivo)


func _elegir_intencion() -> void:
	_recargar_configuracion()
	if not bool(movimiento.get("desplazamiento_propio", true)):
		_direccion_objetivo = Vector2.ZERO
		return
	if str(movimiento.get("tipo", "")).to_lower() == "inmovil":
		_direccion_objetivo = Vector2.ZERO
		return

	var perfil := str(movimiento.get("perfil", "errante")).strip_edges().to_lower()
	var rasgos_variant: Variant = personalidad.get("rasgos", [])
	var rasgos: Array = rasgos_variant if rasgos_variant is Array else []
	_jugador_cercano = _buscar_jugador_cercano(float(movimiento.get("radio_social", 100.0)))

	if is_instance_valid(_jugador_cercano):
		var hacia_jugador := garumi.global_position.direction_to(_jugador_cercano.global_position)
		var distancia := garumi.global_position.distance_to(_jugador_cercano.global_position)
		var distancia_preferida := maxf(float(movimiento.get("distancia_preferida", 40.0)), 8.0)
		if perfil in ["curioso", "sociable"] or rasgos.has("curioso") or rasgos.has("sociable"):
			_direccion_objetivo = hacia_jugador if distancia > distancia_preferida else Vector2.ZERO
			return
		if perfil in ["timido", "evasivo"] or rasgos.has("timido") or rasgos.has("cauteloso"):
			_direccion_objetivo = -hacia_jugador if distancia < float(movimiento.get("distancia_escape", 72.0)) else _direccion_errante()
			return
		if perfil == "territorial" or rasgos.has("territorial"):
			_direccion_objetivo = hacia_jugador if distancia > distancia_preferida * 1.5 else Vector2.ZERO
			return

	match perfil:
		"quieto", "inmovil":
			_direccion_objetivo = Vector2.ZERO
		"errante":
			_direccion_objetivo = _direccion_errante()
		"explorador":
			_direccion_objetivo = _direccion_exploracion()
		"acompanante", "acompañante":
			_direccion_objetivo = hacia_jugador if is_instance_valid(_jugador_cercano) else _direccion_errante()
		_:
			_direccion_objetivo = _direccion_errante()


func _direccion_errante() -> Vector2:
	if _rng.randf() < clampf(float(movimiento.get("probabilidad_pausa", 0.3)), 0.0, 1.0):
		return Vector2.ZERO
	return Vector2.from_angle(_rng.randf_range(-PI, PI))


func _direccion_exploracion() -> Vector2:
	# Exploradores alternan desplazamientos y pausas más cortas.
	if _rng.randf() < 0.12:
		return Vector2.ZERO
	return Vector2.from_angle(_rng.randf_range(-PI, PI))


func _buscar_jugador_cercano(radio: float) -> Node2D:
	var mejor: Node2D = null
	var mejor_distancia := maxf(radio, 0.0)
	for nodo in get_tree().get_nodes_in_group("player"):
		if not nodo is Node2D or not is_instance_valid(nodo):
			continue
		var candidato := nodo as Node2D
		var distancia := garumi.global_position.distance_to(candidato.global_position)
		if distancia <= mejor_distancia:
			mejor = candidato
			mejor_distancia = distancia
	return mejor


## Punto de entrada para que diálogo, ayuda o acciones de juego puedan
## registrar interacciones sin acoplar el cerebro a una interfaz concreta.
func registrar_interaccion(jugador: Node, tipo: String) -> void:
	if not is_instance_valid(garumi) or not is_instance_valid(jugador):
		return
	var relaciones_variant: Variant = garumi.get_meta("relaciones_garumi", {})
	var relaciones: Dictionary = relaciones_variant if relaciones_variant is Dictionary else {}
	var clave := str(jugador.get_instance_id())
	var relacion_variant: Variant = relaciones.get(clave, {})
	var relacion_jugador: Dictionary = relacion_variant if relacion_variant is Dictionary else {}
	var confianza := clampf(float(relacion_jugador.get("confianza", 0.0)), 0.0, 100.0)
	match tipo.strip_edges().to_lower():
		"ayuda", "proteger":
			confianza += 8.0
		"comida", "regalo":
			confianza += 4.0
		"amenaza", "golpe":
			confianza -= 12.0
		"hablar", "acercamiento_respetuoso":
			confianza += 1.0
	relacion_jugador["confianza"] = clampf(confianza, 0.0, 100.0)
	relacion_jugador["ultima_interaccion"] = tipo
	relaciones[clave] = relacion_jugador
	garumi.set_meta("relaciones_garumi", relaciones)


func obtener_relacion(jugador: Node) -> Dictionary:
	if not is_instance_valid(garumi) or not is_instance_valid(jugador):
		return {}
	var relaciones_variant: Variant = garumi.get_meta("relaciones_garumi", {})
	if not relaciones_variant is Dictionary:
		return {}
	var relacion_variant: Variant = (relaciones_variant as Dictionary).get(str(jugador.get_instance_id()), {})
	return relacion_variant.duplicate(true) if relacion_variant is Dictionary else {}
