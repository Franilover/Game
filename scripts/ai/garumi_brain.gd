extends Node
class_name GarumiBrain

## Intérprete genérico de conducta para Garumis.
## Supabase aporta el perfil y sus parámetros; este nodo solo traduce perfiles
## soportados a órdenes para CreatureMovement. No define relaciones persistentes.

var garumi: Garumi = null
var configuracion: Dictionary = {}
var movimiento: Dictionary = {}
var comportamiento: Dictionary = {}
var elementos: Array[String] = []
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
	"inmovil",
	"agresivo",
	"cazador",
	"defensivo",
	"vigilante",
	"jugueton",
	"juguetón",
	"gregario",
	"independiente"
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
	comportamiento = {}
	elementos.clear()
	_perfil = ""

	if not is_instance_valid(garumi):
		return

	var ia := garumi.obtener_config_ia()
	var garumi_variant: Variant = ia.get("garumi", {})
	var datos_garumi: Dictionary = garumi_variant if garumi_variant is Dictionary else {}
	var movimiento_garumi_variant: Variant = datos_garumi.get("movimiento", {})
	var movimiento_garumi: Dictionary = movimiento_garumi_variant if movimiento_garumi_variant is Dictionary else {}

	# Prioridad: movimiento específico de Garumi, movimiento genérico y,
	# por último, perfil de alto nivel solo si coincide con una primitiva que
	# este intérprete realmente soporta. Nunca se traduce una especie desconocida.
	var comportamiento_especifico_variant: Variant = {}
	if datos_garumi.has("comportamiento"):
		comportamiento_especifico_variant = datos_garumi.get("comportamiento", {})
	else:
		comportamiento_especifico_variant = ia.get("comportamiento", {})
	comportamiento = comportamiento_especifico_variant if comportamiento_especifico_variant is Dictionary else {}

	var movimiento_general_variant: Variant = ia.get("movimiento", {})
	var movimiento_general: Dictionary = movimiento_general_variant if movimiento_general_variant is Dictionary else {}
	if movimiento_garumi.has("perfil"):
		movimiento = movimiento_garumi.duplicate(true)
	elif movimiento_general.has("perfil"):
		movimiento = movimiento_general.duplicate(true)
	else:
		var perfil_comportamiento := str(comportamiento.get("perfil", comportamiento.get("temperamento", ""))).strip_edges()
		var perfil_general := str(ia.get("perfil", "")).strip_edges()
		var perfil_elegido := perfil_comportamiento if not perfil_comportamiento.is_empty() else perfil_general
		if not perfil_elegido.is_empty():
			movimiento = {"perfil": perfil_elegido}

	# El perfil de movimiento define la acción; los rasgos aportan parámetros
	# solo cuando no contradicen una instrucción específica de movimiento.
	for clave in comportamiento.keys():
		if not movimiento.has(clave):
			movimiento[clave] = comportamiento[clave]

	var elementos_variant: Variant = datos_garumi.get("elementos", ia.get("elementos", []))
	if not (elementos_variant is Array):
		var elementos_ia_variant: Variant = ia.get("elementos", [])
		elementos_variant = elementos_ia_variant
	if elementos_variant is Array:
		for elemento_variant in elementos_variant:
			var elemento := str(elemento_variant).strip_edges()
			if not elemento.is_empty() and not elementos.has(elemento):
				elementos.append(elemento)

	configuracion = datos_garumi
	_perfil = _normalizar_perfil(str(movimiento.get("perfil", "")))


func _normalizar_perfil(valor: String) -> String:
	return valor.strip_edges().to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u")


func obtener_elementos() -> Array[String]:
	return elementos.duplicate()


func obtener_comportamiento() -> Dictionary:
	return comportamiento.duplicate(true)


func _tiene_perfil_ejecutable() -> bool:
	return not _perfil.is_empty() and PERFILES_MECANICOS.has(_perfil)


func _aplicar_control() -> void:
	if not is_instance_valid(garumi) or garumi._movimiento == null:
		return
	if _tiene_perfil_ejecutable():
		garumi._movimiento.tomar_control()
	else:
		# Sin una instrucción válida no se inventa conducta autónoma. Se mantiene
		# la dirección externa en cero para impedir que CreatureMovement aplique
		# su patrulla genérica como si fuera el perfil canónico de este Garumi.
		garumi._movimiento.tomar_control()
		garumi._movimiento.establecer_direccion(Vector2.ZERO)
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
	if _normalizar_perfil(str(movimiento.get("tipo", ""))) == "inmovil" or _perfil in ["quieto", "inmovil"]:
		_direccion_objetivo = Vector2.ZERO
		return

	var sociabilidad := clampf(float(comportamiento.get("sociabilidad", 0.5)), 0.0, 1.0)
	var radio_social_base := maxf(float(movimiento.get("radio_social", 100.0)), 0.0)
	var radio_social := radio_social_base * (0.5 + sociabilidad)
	var jugador := _buscar_jugador_cercano(radio_social)
	var tiene_jugador := is_instance_valid(jugador)
	var hacia_jugador := Vector2.ZERO
	var distancia := INF
	if tiene_jugador:
		hacia_jugador = garumi.global_position.direction_to(jugador.global_position)
		distancia = garumi.global_position.distance_to(jugador.global_position)

	var distancia_preferida := maxf(float(movimiento.get("distancia_preferida", 40.0)), 8.0)
	match _perfil:
		"curioso", "sociable", "gregario":
			var curiosidad := clampf(float(comportamiento.get("curiosidad", 0.5)), 0.0, 1.0)
			var radio_curiosidad := radio_social * (0.5 + curiosidad)
			_direccion_objetivo = hacia_jugador if tiene_jugador and distancia > distancia_preferida and distancia <= radio_curiosidad else _direccion_errante()
		"timido", "evasivo":
			var temor := clampf(float(comportamiento.get("temor", 0.5)), 0.0, 1.0)
			var distancia_escape := maxf(float(movimiento.get("distancia_escape", 72.0)), 0.0) * (0.5 + temor)
			_direccion_objetivo = -hacia_jugador if tiene_jugador and distancia < distancia_escape else _direccion_errante()
		"territorial":
			var territorialidad := clampf(float(comportamiento.get("territorialidad", 0.5)), 0.0, 1.0)
			var radio_defendido := distancia_preferida * (1.0 + territorialidad)
			_direccion_objetivo = hacia_jugador if tiene_jugador and distancia > radio_defendido else Vector2.ZERO
		"agresivo", "cazador":
			# Conducta de presión, no inicia daño por sí sola: el combate conserva
			# el flujo de interacción y las reglas de vínculo existentes.
			var agresividad := clampf(float(comportamiento.get("agresividad", 0.5)), 0.0, 1.0)
			var distancia_presion := distancia_preferida * (1.0 + agresividad)
			_direccion_objetivo = hacia_jugador if tiene_jugador and distancia > distancia_presion else _direccion_errante()
		"defensivo", "vigilante":
			var distancia_reaccion := maxf(float(movimiento.get("distancia_reaccion", distancia_preferida)), 8.0)
			_direccion_objetivo = -hacia_jugador if tiene_jugador and distancia < distancia_reaccion else Vector2.ZERO
		"jugueton":
			if tiene_jugador and distancia > distancia_preferida * 1.4:
				_direccion_objetivo = hacia_jugador
			elif tiene_jugador and distancia < distancia_preferida * 0.75:
				_direccion_objetivo = -hacia_jugador
			else:
				_direccion_objetivo = _direccion_errante()
		"independiente":
			_direccion_objetivo = _direccion_errante()
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
