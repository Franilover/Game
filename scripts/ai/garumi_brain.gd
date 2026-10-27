extends Node
class_name GarumiBrain

## Intérprete genérico de conducta para Garumis.
## Supabase aporta el perfil y sus parámetros; este nodo solo traduce perfiles
## soportados a órdenes para CreatureMovement. No define relaciones persistentes.

var garumi: Garumi = null
var configuracion: Dictionary = {}
var movimiento: Dictionary = {}
var _perfil: String = ""

var _rng := RandomNumberGenerator.new()
var _tiempo_decision: float = 0.0
var _direccion_objetivo: Vector2 = Vector2.ZERO


const PERFILES_MECANICOS := [
	"errante",
	"curioso",
	"sociable",
	"timido",
	"evasivo",
	"territorial",
	"explorador",
	"acompanante",
	"acompañante",
	"quieto",
	"inmovil"
]


func configurar(nuevo_garumi: Garumi) -> void:
	garumi = nuevo_garumi
	_rng.randomize()
	_recargar_configuracion()
	_tiempo_decision = 0.0
	_aplicar_control()


func _recargar_configuracion() -> void:
	configuracion = {}
	movimiento = {}
	_perfil = ""

	if not is_instance_valid(garumi):
		return

	var ia := garumi.obtener_config_ia()
	var garumi_variant: Variant = ia.get("garumi", {})
	var datos_garumi: Dictionary = garumi_variant if garumi_variant is Dictionary else {}
	var movimiento_garumi_variant: Variant = datos_garumi.get("movimiento", {})
	var movimiento_garumi: Dictionary = movimiento_garumi_variant if movimiento_garumi_variant is Dictionary else {}

	# La configuración específica de Garumi tiene prioridad. Si no declara
	# perfil, se permite el perfil genérico existente; nunca se inventa uno.
	var movimiento_general_variant: Variant = ia.get("movimiento", {})
	var movimiento_general: Dictionary = movimiento_general_variant if movimiento_general_variant is Dictionary else {}
	movimiento = movimiento_garumi if movimiento_garumi.has("perfil") else movimiento_general
	configuracion = datos_garumi
	_perfil = str(movimiento.get("perfil", "")).strip_edges().to_lower()


func _tiene_perfil_ejecutable() -> bool:
	return not _perfil.is_empty() and PERFILES_MECANICOS.has(_perfil)


func _aplicar_control() -> void:
	if not is_instance_valid(garumi) or garumi._movimiento == null:
		return
	if _tiene_perfil_ejecutable():
		garumi._movimiento.tomar_control()
	else:
		# Sin una instrucción válida de Supabase, el cerebro no suplanta el
		# movimiento genérico ni transforma un perfil desconocido en errante.
		garumi._movimiento.liberar_control()
		garumi._movimiento.detener()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(garumi) or not garumi.is_inside_tree():
		return
	if garumi._movimiento == null:
		return
	if garumi.esta_vinculado() or garumi.esta_enfrentamiento() or garumi.esta_guardado():
		return

	_recargar_configuracion()
	if not _tiene_perfil_ejecutable():
		_aplicar_control()
		return

	_aplicar_control()
	_tiempo_decision -= delta
	if _tiempo_decision <= 0.0:
		_elegir_intencion()
		var intervalo_min := maxf(float(movimiento.get("intervalo_min", garumi.min_move_time)), 0.2)
		var intervalo_max := maxf(float(movimiento.get("intervalo_max", garumi.max_move_time)), intervalo_min)
		_tiempo_decision = _rng.randf_range(intervalo_min, intervalo_max)

	garumi._movimiento.establecer_direccion(_direccion_objetivo)


func _elegir_intencion() -> void:
	if not bool(movimiento.get("desplazamiento_propio", true)):
		_direccion_objetivo = Vector2.ZERO
		return
	if str(movimiento.get("tipo", "")).strip_edges().to_lower() == "inmovil" or _perfil in ["quieto", "inmovil"]:
		_direccion_objetivo = Vector2.ZERO
		return

	var radio_social := maxf(float(movimiento.get("radio_social", 100.0)), 0.0)
	var jugador := _buscar_jugador_cercano(radio_social)
	var tiene_jugador := is_instance_valid(jugador)
	var hacia_jugador := Vector2.ZERO
	var distancia := INF
	if tiene_jugador:
		hacia_jugador = garumi.global_position.direction_to(jugador.global_position)
		distancia = garumi.global_position.distance_to(jugador.global_position)

	var distancia_preferida := maxf(float(movimiento.get("distancia_preferida", 40.0)), 8.0)
	match _perfil:
		"curioso", "sociable":
			_direccion_objetivo = hacia_jugador if tiene_jugador and distancia > distancia_preferida else _direccion_errante()
		"timido", "evasivo":
			var distancia_escape := maxf(float(movimiento.get("distancia_escape", 72.0)), 0.0)
			_direccion_objetivo = -hacia_jugador if tiene_jugador and distancia < distancia_escape else _direccion_errante()
		"territorial":
			_direccion_objetivo = hacia_jugador if tiene_jugador and distancia > distancia_preferida * 1.5 else Vector2.ZERO
		"explorador":
			_direccion_objetivo = _direccion_exploracion()
		"acompanante", "acompañante":
			_direccion_objetivo = hacia_jugador if tiene_jugador else _direccion_errante()
		"errante":
			_direccion_objetivo = _direccion_errante()
		_:
			# El validador impide llegar aquí con un perfil desconocido.
			_direccion_objetivo = Vector2.ZERO


func _direccion_errante() -> Vector2:
	var probabilidad_pausa := clampf(float(movimiento.get("probabilidad_pausa", 0.3)), 0.0, 1.0)
	if _rng.randf() < probabilidad_pausa:
		return Vector2.ZERO
	return Vector2.from_angle(_rng.randf_range(-PI, PI))


func _direccion_exploracion() -> Vector2:
	var probabilidad_pausa := clampf(float(movimiento.get("probabilidad_pausa", 0.12)), 0.0, 1.0)
	if _rng.randf() < probabilidad_pausa:
		return Vector2.ZERO
	return Vector2.from_angle(_rng.randf_range(-PI, PI))


func _buscar_jugador_cercano(radio: float) -> Node2D:
	var mejor: Node2D = null
	var mejor_distancia := radio
	for nodo in get_tree().get_nodes_in_group("player"):
		if not nodo is Node2D or not is_instance_valid(nodo):
			continue
		var candidato := nodo as Node2D
		var distancia := garumi.global_position.distance_to(candidato.global_position)
		if distancia <= mejor_distancia:
			mejor = candidato
			mejor_distancia = distancia
	return mejor
