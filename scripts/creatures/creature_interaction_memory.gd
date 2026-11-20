extends RefCounted
class_name CreatureInteractionMemory

## Memoria temporal y local a una criatura. No persiste entre sesiones.
## Cada actor se identifica por su instancia viva; no se guardan nodos fuertes.
const MAX_RECUERDOS: int = 16
const MAX_INTENSIDAD: float = 5.0
const INTERVALO_AVISTAMIENTO: float = 4.0
const DECAY_FAMILIARIDAD: float = 0.01
const MAX_CONFIANZA: float = 5.0
const DECAY_CONFIANZA: float = 0.005

var _recuerdos: Dictionary = {}


func registrar_agresion(actor: Node, intensidad: float = 1.0, duracion: float = 45.0) -> void:
	if not _actor_valido(actor):
		return
	var intensidad_segura := clampf(_numero_finito(intensidad, 0.0), 0.0, MAX_INTENSIDAD)
	var duracion_segura := clampf(_numero_finito(duracion, 0.0), 0.0, 600.0)
	if intensidad_segura <= 0.0 or duracion_segura <= 0.0:
		return

	var recuerdo := _obtener_o_crear_recuerdo(actor)
	recuerdo["agresion"] = minf(float(recuerdo.get("agresion", 0.0)) + intensidad_segura, MAX_INTENSIDAD)
	recuerdo["tiempo_restante"] = maxf(float(recuerdo.get("tiempo_restante", 0.0)), duracion_segura)
	_guardar_recuerdo(actor, recuerdo)


## Un avistamiento repetido crea familiaridad lentamente, sin convertir la
## mera detección en confianza ni alterar por sí solo la respuesta hostil.
func registrar_avistamiento(
	actor: Node,
	intensidad: float = 0.25,
	duracion: float = 120.0,
	intervalo: float = INTERVALO_AVISTAMIENTO
) -> void:
	if not _actor_valido(actor):
		return
	var intensidad_segura := clampf(_numero_finito(intensidad, 0.0), 0.0, 1.0)
	var duracion_segura := clampf(_numero_finito(duracion, 0.0), 0.0, 600.0)
	var intervalo_seguro := clampf(_numero_finito(intervalo, INTERVALO_AVISTAMIENTO), 0.1, 60.0)
	if intensidad_segura <= 0.0 or duracion_segura <= 0.0:
		return

	var recuerdo := _obtener_o_crear_recuerdo(actor)
	if float(recuerdo.get("cooldown_avistamiento", 0.0)) > 0.0:
		return
	recuerdo["familiaridad"] = minf(
		float(recuerdo.get("familiaridad", 0.0)) + intensidad_segura,
		MAX_INTENSIDAD
	)
	recuerdo["cooldown_avistamiento"] = intervalo_seguro
	recuerdo["tiempo_restante"] = maxf(float(recuerdo.get("tiempo_restante", 0.0)), duracion_segura)
	_guardar_recuerdo(actor, recuerdo)


## Registra una interacción positiva explícita; no debe llamarse por mera proximidad.
func registrar_interaccion_positiva(actor: Node, intensidad: float = 0.5, duracion: float = 180.0) -> void:
	if not _actor_valido(actor):
		return
	var intensidad_segura := clampf(_numero_finito(intensidad, 0.0), 0.0, 1.0)
	var duracion_segura := clampf(_numero_finito(duracion, 0.0), 0.0, 600.0)
	if intensidad_segura <= 0.0 or duracion_segura <= 0.0:
		return
	var recuerdo := _obtener_o_crear_recuerdo(actor)
	recuerdo["confianza"] = minf(float(recuerdo.get("confianza", 0.0)) + intensidad_segura, MAX_CONFIANZA)
	recuerdo["tiempo_restante"] = maxf(float(recuerdo.get("tiempo_restante", 0.0)), duracion_segura)
	_guardar_recuerdo(actor, recuerdo)

func _actor_valido(actor: Node) -> bool:
	return (
		actor != null
		and is_instance_valid(actor)
		and not actor.is_queued_for_deletion()
		and not actor.is_in_group("garumis")
	)


func _numero_finito(valor: float, respaldo: float) -> float:
	return valor if is_finite(valor) else respaldo


func _obtener_o_crear_recuerdo(actor: Node) -> Dictionary:
	var actor_id := actor.get_instance_id()
	var recuerdo: Variant = _recuerdos.get(actor_id, {})
	if not recuerdo is Dictionary:
		recuerdo = {}
	var datos := (recuerdo as Dictionary).duplicate()
	var referencia: Variant = datos.get("actor_ref", null)
	if not referencia is WeakRef or referencia.get_ref() != actor:
		datos = {}
	datos["actor_ref"] = weakref(actor)
	return datos


func _guardar_recuerdo(actor: Node, recuerdo: Dictionary) -> void:
	_recuerdos[actor.get_instance_id()] = recuerdo
	_limitar_recuerdos()


## Evita que una criatura acumule referencias débiles sin límite durante una sesión.
func _limitar_recuerdos() -> void:
	while _recuerdos.size() > MAX_RECUERDOS:
		var id_mas_debil := -1
		var menor_valor := INF
		var menor_duracion := INF
		for id_variant in _recuerdos:
			var datos: Dictionary = _recuerdos[id_variant]
			var valor := float(datos.get("agresion", 0.0)) + float(datos.get("familiaridad", 0.0)) + float(datos.get("confianza", 0.0))
			var duracion_restante := float(datos.get("tiempo_restante", 0.0))
			if valor < menor_valor or (is_equal_approx(valor, menor_valor) and duracion_restante < menor_duracion):
				id_mas_debil = int(id_variant)
				menor_valor = valor
				menor_duracion = duracion_restante
		if id_mas_debil < 0:
			return
		_recuerdos.erase(id_mas_debil)


func _obtener_valor(actor: Node, clave: String) -> float:
	if actor == null or not is_instance_valid(actor):
		return 0.0
	var recuerdo: Variant = _recuerdos.get(actor.get_instance_id(), null)
	if not recuerdo is Dictionary:
		return 0.0
	var datos := recuerdo as Dictionary
	var referencia: Variant = datos.get("actor_ref", null)
	if not referencia is WeakRef or referencia.get_ref() != actor:
		return 0.0
	return clampf(_numero_finito(float(datos.get(clave, 0.0)), 0.0), 0.0, MAX_INTENSIDAD)


func obtener_agresion(actor: Node) -> float:
	return _obtener_valor(actor, "agresion")


func obtener_familiaridad(actor: Node) -> float:
	return _obtener_valor(actor, "familiaridad")


func obtener_confianza(actor: Node) -> float:
	return _obtener_valor(actor, "confianza")


## Relación derivada de recuerdos, no una etiqueta persistente o global.
func obtener_tipo_relacion(actor: Node, umbral_hostilidad: float = 1.0, umbral_confianza: float = 1.0, umbral_familiaridad: float = 0.5) -> String:
	var agresion := obtener_agresion(actor)
	var confianza := obtener_confianza(actor)
	var familiaridad := obtener_familiaridad(actor)
	if agresion >= maxf(umbral_hostilidad, 0.0):
		return "hostil"
	if agresion > 0.0:
		return "desconfiado"
	if confianza >= maxf(umbral_confianza, 0.0):
		return "confiable"
	if familiaridad >= maxf(umbral_familiaridad, 0.0):
		return "conocido"
	return "desconocido"


func actualizar(delta: float, decaimiento_por_segundo: float = 0.2) -> void:
	var tiempo := maxf(_numero_finito(delta, 0.0), 0.0)
	var decaimiento := maxf(_numero_finito(decaimiento_por_segundo, 0.0), 0.0) * tiempo
	for actor_id_variant in _recuerdos.keys():
		var actor_id := int(actor_id_variant)
		var recuerdo: Dictionary = _recuerdos[actor_id]
		var referencia: Variant = recuerdo.get("actor_ref", null)
		var actor: Node = referencia.get_ref() as Node if referencia is WeakRef else null
		if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
			_recuerdos.erase(actor_id)
			continue
		recuerdo["agresion"] = maxf(float(recuerdo.get("agresion", 0.0)) - decaimiento, 0.0)
		recuerdo["familiaridad"] = maxf(
			float(recuerdo.get("familiaridad", 0.0)) - DECAY_FAMILIARIDAD * tiempo,
			0.0
		)
		recuerdo["confianza"] = maxf(
			float(recuerdo.get("confianza", 0.0)) - DECAY_CONFIANZA * tiempo,
			0.0
		)
		recuerdo["cooldown_avistamiento"] = maxf(
			float(recuerdo.get("cooldown_avistamiento", 0.0)) - tiempo,
			0.0
		)
		recuerdo["tiempo_restante"] = maxf(float(recuerdo.get("tiempo_restante", 0.0)) - tiempo, 0.0)
		if (
			float(recuerdo["agresion"]) <= 0.0
			and float(recuerdo["familiaridad"]) <= 0.0
			and float(recuerdo["confianza"]) <= 0.0
		) or float(recuerdo["tiempo_restante"]) <= 0.0:
			_recuerdos.erase(actor_id)
		else:
			_recuerdos[actor_id] = recuerdo


func cantidad_recuerdos() -> int:
	return _recuerdos.size()


func limpiar() -> void:
	_recuerdos.clear()
