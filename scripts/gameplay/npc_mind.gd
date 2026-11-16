extends Node
class_name NPCMindService

## Núcleo de estado interno y aprendizaje incremental de los habitantes.
## No genera texto ni controla directamente navegación o animaciones.
## La identidad inicial llega como datos; los valores ausentes son neutrales.

signal estado_mental_cambiado(personaje_id: String, estado: Dictionary)
signal aprendizaje_actualizado(personaje_id: String, actividad: String, preferencia: float)
signal decision_evaluada(personaje_id: String, actividad: String, puntuacion: float)

const VERSION_ESTADO: int = 1
const CLAVE_GUARDADO: String = "npc_mentes"
const MAX_OBJETIVOS: int = 5
const MAX_HORAS_POR_ACTUALIZACION: float = 48.0
const NECESIDADES_INICIALES := {
	"descanso": 20.0,
	"socializacion": 25.0,
	"diversion": 20.0,
	"seguridad": 10.0,
	"curiosidad": 20.0,
	"autonomia": 15.0
}
const TASAS_NECESIDAD_POR_HORA := {
	"descanso": 1.15,
	"socializacion": 0.65,
	"diversion": 0.45,
	"seguridad": 0.12,
	"curiosidad": 0.35,
	"autonomia": 0.25
}
const RASGOS_NEUTRALES := {
	"sociabilidad": 0.5,
	"curiosidad": 0.5,
	"prudencia": 0.5,
	"independencia": 0.5,
	"disciplina": 0.5,
	"generosidad": 0.5,
	"agresividad": 0.5
}

var _game_state: Node = null
var _mentes: Dictionary = {}


func _ready() -> void:
	var estado := get_node_or_null("/root/GameState")
	if estado != null:
		configurar(estado)


func configurar(game_state: Node) -> void:
	_game_state = game_state
	_mentes = _leer_mentes_guardadas()


func esta_configurado() -> bool:
	return _game_state != null and is_instance_valid(_game_state)


func registrar_personaje(personaje_id: String, perfil_inicial: Dictionary = {}) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	if id.is_empty():
		return {}
	if not _mentes.has(id):
		_mentes[id] = _crear_estado_inicial(perfil_inicial)
		_guardar_mentes()
	else:
		# Un perfil recibido posteriormente puede completar rasgos aún neutros,
		# pero nunca sobrescribe necesidades, aprendizaje ni objetivos guardados.
		_aplicar_perfil_solo_si_neutro(id, perfil_inicial)
	return obtener_estado(id)


func existe_personaje(personaje_id: String) -> bool:
	return _mentes.has(personaje_id.strip_edges().to_lower())


func obtener_estado(personaje_id: String) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	if id.is_empty():
		return {}
	if not _mentes.has(id):
		return registrar_personaje(id)
	var estado_variant: Variant = _mentes.get(id, {})
	if not estado_variant is Dictionary:
		return registrar_personaje(id)
	return (estado_variant as Dictionary).duplicate(true)


func obtener_necesidades(personaje_id: String) -> Dictionary:
	var estado := obtener_estado(personaje_id)
	var necesidades_variant: Variant = estado.get("necesidades", {})
	if necesidades_variant is Dictionary:
		return (necesidades_variant as Dictionary).duplicate(true)
	return {}


func obtener_rasgos(personaje_id: String) -> Dictionary:
	var estado := obtener_estado(personaje_id)
	var rasgos_variant: Variant = estado.get("rasgos", {})
	if rasgos_variant is Dictionary:
		return (rasgos_variant as Dictionary).duplicate(true)
	return {}


func obtener_preferencia_actividad(personaje_id: String, actividad: String) -> float:
	var estado := obtener_estado(personaje_id)
	var aprendizaje: Dictionary = estado.get("aprendizaje", {})
	var registro_variant: Variant = aprendizaje.get(actividad.strip_edges().to_lower(), {})
	if not registro_variant is Dictionary:
		return 0.0
	return float((registro_variant as Dictionary).get("preferencia", 0.0))


## Avanza necesidades por horas de mundo. No simula fotogramas ni movimiento.
func avanzar_tiempo(personaje_id: String, horas: float) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	if id.is_empty() or horas <= 0.0:
		return obtener_estado(id)
	var estado := _obtener_estado_mutable(id)
	var delta_horas := clampf(horas, 0.0, MAX_HORAS_POR_ACTUALIZACION)
	var necesidades: Dictionary = estado.get("necesidades", {}).duplicate(true)
	for clave in TASAS_NECESIDAD_POR_HORA:
		var actual := float(necesidades.get(clave, 0.0))
		var tasa := float(TASAS_NECESIDAD_POR_HORA[clave])
		necesidades[clave] = clampf(actual + tasa * delta_horas, 0.0, 100.0)
	estado["necesidades"] = necesidades
	_mentes[id] = estado
	_guardar_mentes()
	_emitir_cambio(id)
	return obtener_estado(id)


## Procesa un tramo de tiempo y sus efectos en una sola escritura de guardado.
## satisfacciones contiene puntos de alivio por hora para cada necesidad.
func procesar_intervalo(
	personaje_id: String,
	horas: float,
	satisfacciones_por_hora: Dictionary = {}
) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	if id.is_empty() or horas <= 0.0:
		return obtener_estado(id)
	var delta_horas := clampf(horas, 0.0, MAX_HORAS_POR_ACTUALIZACION)
	var estado := _obtener_estado_mutable(id)
	var necesidades: Dictionary = estado.get("necesidades", {}).duplicate(true)
	for clave in TASAS_NECESIDAD_POR_HORA:
		var presion := float(necesidades.get(clave, 0.0))
		var aumento := float(TASAS_NECESIDAD_POR_HORA[clave]) * delta_horas
		var alivio := maxf(0.0, float(satisfacciones_por_hora.get(clave, 0.0))) * delta_horas
		necesidades[clave] = clampf(presion + aumento - alivio, 0.0, 100.0)
	estado["necesidades"] = necesidades

	var presion_total := 0.0
	for valor in necesidades.values():
		presion_total += float(valor)
	var presion_media := presion_total / maxf(1.0, float(necesidades.size()))
	var emocion: Dictionary = estado.get("estado_emocional", {}).duplicate(true)
	emocion["animo"] = clampf((50.0 - presion_media) / 50.0, -1.0, 1.0)
	emocion["estres"] = clampf(
		(float(necesidades.get("descanso", 0.0)) * 0.45
		+ float(necesidades.get("seguridad", 0.0)) * 0.35
		+ float(necesidades.get("socializacion", 0.0)) * 0.2) / 100.0,
		0.0,
		1.0
	)
	emocion["energia"] = clampf(100.0 - float(necesidades.get("descanso", 0.0)), 0.0, 100.0)
	estado["estado_emocional"] = emocion
	_mentes[id] = estado
	_guardar_mentes()
	_emitir_cambio(id)
	return obtener_estado(id)


## Aumenta o reduce la presión de una necesidad concreta.
func modificar_necesidad(personaje_id: String, necesidad: String, cantidad: float) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	var clave := necesidad.strip_edges().to_lower()
	if id.is_empty() or not NECESIDADES_INICIALES.has(clave):
		return obtener_estado(id)
	var estado := _obtener_estado_mutable(id)
	var necesidades: Dictionary = estado.get("necesidades", {}).duplicate(true)
	necesidades[clave] = clampf(float(necesidades.get(clave, 0.0)) + cantidad, 0.0, 100.0)
	estado["necesidades"] = necesidades
	_mentes[id] = estado
	_guardar_mentes()
	_emitir_cambio(id)
	return obtener_estado(id)


## Satisface necesidades: cada valor indica cuánto reduce su presión (0-100).
func aplicar_satisfaccion(personaje_id: String, satisfacciones: Dictionary) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	if id.is_empty():
		return {}
	var estado := _obtener_estado_mutable(id)
	var necesidades: Dictionary = estado.get("necesidades", {}).duplicate(true)
	for clave_variant in satisfacciones:
		var clave := str(clave_variant).strip_edges().to_lower()
		if not NECESIDADES_INICIALES.has(clave):
			continue
		var alivio := maxf(0.0, float(satisfacciones.get(clave_variant, 0.0)))
		necesidades[clave] = clampf(float(necesidades.get(clave, 0.0)) - alivio, 0.0, 100.0)
	estado["necesidades"] = necesidades
	_mentes[id] = estado
	_guardar_mentes()
	_emitir_cambio(id)
	return obtener_estado(id)


## Puntúa una actividad propuesta por otro sistema.
## Formato: {id, necesidades, afinidad_rasgos, prioridad, coste, riesgo, bloqueada}.
func evaluar_actividad(personaje_id: String, actividad: Dictionary) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	var clave := str(actividad.get("id", "")).strip_edges().to_lower()
	if id.is_empty() or clave.is_empty():
		return {}
	if bool(actividad.get("bloqueada", false)):
		return {"actividad": clave, "puntuacion": -INF, "disponible": false, "componentes": {}}

	var estado := obtener_estado(id)
	var necesidades: Dictionary = estado.get("necesidades", {})
	var rasgos: Dictionary = estado.get("rasgos", {})
	var componentes := {
		"necesidades": 0.0,
		"personalidad": 0.0,
		"aprendizaje": 0.0,
		"prioridad": 0.0,
		"coste": 0.0,
		"riesgo": 0.0
	}

	var necesidades_actividad: Variant = actividad.get("necesidades", {})
	if necesidades_actividad is Dictionary:
		for necesidad_variant in necesidades_actividad:
			var necesidad := str(necesidad_variant).strip_edges().to_lower()
			if not NECESIDADES_INICIALES.has(necesidad):
				continue
			var peso := clampf(float(necesidades_actividad[necesidad_variant]), 0.0, 1.0)
			componentes["necesidades"] += float(necesidades.get(necesidad, 0.0)) * peso * 0.35

	var afinidades_variant: Variant = actividad.get("afinidad_rasgos", {})
	if afinidades_variant is Dictionary:
		for rasgo_variant in afinidades_variant:
			var rasgo := str(rasgo_variant).strip_edges().to_lower()
			if not RASGOS_NEUTRALES.has(rasgo):
				continue
			var objetivo := clampf(float(afinidades_variant[rasgo_variant]), 0.0, 1.0)
			var valor_actual := float(rasgos.get(rasgo, 0.5))
			componentes["personalidad"] += (1.0 - absf(valor_actual - objetivo)) * 8.0

	componentes["aprendizaje"] = obtener_preferencia_actividad(id, clave) * 12.0
	componentes["prioridad"] = clampf(float(actividad.get("prioridad", 0.0)), 0.0, 100.0) * 0.1
	componentes["coste"] = -clampf(float(actividad.get("coste", 0.0)), 0.0, 100.0) * 0.15
	componentes["riesgo"] = -clampf(float(actividad.get("riesgo", 0.0)), 0.0, 100.0) * 0.2

	var puntuacion := 0.0
	for valor in componentes.values():
		puntuacion += float(valor)
	return {
		"actividad": clave,
		"puntuacion": puntuacion,
		"disponible": true,
		"componentes": componentes
	}


## Selecciona la actividad con mayor utilidad. No ejecuta la actividad.
func elegir_actividad(personaje_id: String, actividades: Array) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	if id.is_empty():
		return {}
	var mejor: Dictionary = {}
	var mejor_puntuacion := -INF
	for actividad_variant in actividades:
		if not actividad_variant is Dictionary:
			continue
		var resultado := evaluar_actividad(id, actividad_variant as Dictionary)
		if not bool(resultado.get("disponible", false)):
			continue
		var puntuacion := float(resultado.get("puntuacion", -INF))
		var clave := str(resultado.get("actividad", ""))
		decision_evaluada.emit(id, clave, puntuacion)
		if puntuacion > mejor_puntuacion:
			mejor_puntuacion = puntuacion
			mejor = resultado
	if mejor.is_empty():
		return {}
	var estado := _obtener_estado_mutable(id)
	estado["decisiones_tomadas"] = int(estado.get("decisiones_tomadas", 0)) + 1
	estado["ultima_actividad_elegida"] = str(mejor.get("actividad", ""))
	_mentes[id] = estado
	_guardar_mentes()
	return mejor.duplicate(true)


## Aprende del resultado de una actividad sin permitir que una sola experiencia
## convierta una preferencia en una regla absoluta.
## resultado: -1.0 (muy malo) a 1.0 (muy bueno).
func registrar_resultado_actividad(personaje_id: String, actividad: String, resultado: float) -> float:
	var id := personaje_id.strip_edges().to_lower()
	var clave := actividad.strip_edges().to_lower()
	if id.is_empty() or clave.is_empty():
		return 0.0
	var estado := _obtener_estado_mutable(id)
	var aprendizaje: Dictionary = estado.get("aprendizaje", {}).duplicate(true)
	var registro_variant: Variant = aprendizaje.get(clave, {})
	var registro: Dictionary = registro_variant.duplicate(true) if registro_variant is Dictionary else {}
	var muestras := maxi(0, int(registro.get("muestras", 0))) + 1
	var media_anterior := float(registro.get("resultado_medio", 0.0))
	var nuevo_resultado := clampf(resultado, -1.0, 1.0)
	var media := media_anterior + (nuevo_resultado - media_anterior) / float(muestras)
	var confianza := float(muestras) / (float(muestras) + 3.0)
	var preferencia := clampf(media * confianza, -1.0, 1.0)
	registro["muestras"] = muestras
	registro["resultado_medio"] = media
	registro["preferencia"] = preferencia
	registro["ultimo_resultado"] = nuevo_resultado
	aprendizaje[clave] = registro
	estado["aprendizaje"] = aprendizaje
	_mentes[id] = estado
	_guardar_mentes()
	aprendizaje_actualizado.emit(id, clave, preferencia)
	_emitir_cambio(id)
	return preferencia


func establecer_objetivo(personaje_id: String, objetivo: Dictionary) -> bool:
	var id := personaje_id.strip_edges().to_lower()
	var clave := str(objetivo.get("id", "")).strip_edges().to_lower()
	if id.is_empty() or clave.is_empty():
		return false
	var estado := _obtener_estado_mutable(id)
	var objetivos: Array = estado.get("objetivos", []).duplicate(true)
	for i in range(objetivos.size()):
		if not objetivos[i] is Dictionary:
			continue
		if str((objetivos[i] as Dictionary).get("id", "")).to_lower() == clave:
			objetivos[i] = objetivo.duplicate(true)
			estado["objetivos"] = objetivos
			_mentes[id] = estado
			_guardar_mentes()
			_emitir_cambio(id)
			return true
	while objetivos.size() >= MAX_OBJETIVOS:
		var indice_terminal := -1
		for i in range(objetivos.size()):
			if not objetivos[i] is Dictionary:
				indice_terminal = i
				break
			var estado_objetivo := str((objetivos[i] as Dictionary).get("estado", "activo"))
			if estado_objetivo == "completado" or estado_objetivo == "abandonado":
				indice_terminal = i
				break
		if indice_terminal < 0:
			return false
		objetivos.remove_at(indice_terminal)
	var nuevo := objetivo.duplicate(true)
	nuevo["id"] = clave
	nuevo["estado"] = "activo"
	nuevo["prioridad"] = clampf(float(nuevo.get("prioridad", 0.5)), 0.0, 1.0)
	objetivos.append(nuevo)
	estado["objetivos"] = objetivos
	_mentes[id] = estado
	_guardar_mentes()
	_emitir_cambio(id)
	return true


func completar_objetivo(personaje_id: String, objetivo_id: String, completado: bool = true) -> bool:
	var id := personaje_id.strip_edges().to_lower()
	var clave := objetivo_id.strip_edges().to_lower()
	if id.is_empty() or clave.is_empty():
		return false
	var estado := _obtener_estado_mutable(id)
	var objetivos: Array = estado.get("objetivos", []).duplicate(true)
	for i in range(objetivos.size()):
		if not objetivos[i] is Dictionary:
			continue
		var objetivo: Dictionary = (objetivos[i] as Dictionary).duplicate(true)
		if str(objetivo.get("id", "")).to_lower() != clave:
			continue
		objetivo["estado"] = "completado" if completado else "abandonado"
		objetivos[i] = objetivo
		estado["objetivos"] = objetivos
		_mentes[id] = estado
		_guardar_mentes()
		_emitir_cambio(id)
		return true
	return false


func obtener_objetivos_activos(personaje_id: String) -> Array:
	var objetivos: Array = obtener_estado(personaje_id).get("objetivos", [])
	var resultado: Array = []
	for objetivo_variant in objetivos:
		if objetivo_variant is Dictionary and str((objetivo_variant as Dictionary).get("estado", "activo")) == "activo":
			resultado.append((objetivo_variant as Dictionary).duplicate(true))
	resultado.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("prioridad", 0.5)) > float(b.get("prioridad", 0.5))
	)
	return resultado


func _crear_estado_inicial(perfil: Dictionary = {}) -> Dictionary:
	var necesidades := NECESIDADES_INICIALES.duplicate(true)
	var necesidades_perfil: Variant = perfil.get("necesidades", {})
	if necesidades_perfil is Dictionary:
		for clave_variant in necesidades_perfil:
			var clave := str(clave_variant).strip_edges().to_lower()
			if necesidades.has(clave):
				necesidades[clave] = clampf(float(necesidades_perfil[clave_variant]), 0.0, 100.0)
	var rasgos := RASGOS_NEUTRALES.duplicate(true)
	var rasgos_perfil: Variant = perfil.get("rasgos", {})
	if rasgos_perfil is Dictionary:
		for clave_variant in rasgos_perfil:
			var clave := str(clave_variant).strip_edges().to_lower()
			if rasgos.has(clave):
				rasgos[clave] = _normalizar_rasgo(rasgos_perfil[clave_variant])
	return {
		"version": VERSION_ESTADO,
		"necesidades": necesidades,
		"rasgos": rasgos,
		"estado_emocional": {"animo": 0.0, "estres": 10.0, "energia": 75.0},
		"aprendizaje": {},
		"objetivos": [],
		"decisiones_tomadas": 0,
		"ultima_actividad_elegida": ""
	}


func _aplicar_perfil_solo_si_neutro(personaje_id: String, perfil: Dictionary) -> void:
	if perfil.is_empty():
		return
	var estado := _obtener_estado_mutable(personaje_id)
	var rasgos: Dictionary = estado.get("rasgos", {}).duplicate(true)
	var perfil_rasgos: Variant = perfil.get("rasgos", {})
	var cambiado := false
	if perfil_rasgos is Dictionary:
		for clave_variant in perfil_rasgos:
			var clave := str(clave_variant).strip_edges().to_lower()
			if rasgos.has(clave) and is_equal_approx(float(rasgos[clave]), 0.5):
				rasgos[clave] = _normalizar_rasgo(perfil_rasgos[clave_variant])
				cambiado = true
	if not cambiado:
		return
	estado["rasgos"] = rasgos
	_mentes[personaje_id] = estado
	_guardar_mentes()


func _obtener_estado_mutable(personaje_id: String) -> Dictionary:
	var id := personaje_id.strip_edges().to_lower()
	if not _mentes.has(id):
		_mentes[id] = _crear_estado_inicial()
	var estado_variant: Variant = _mentes.get(id, {})
	if not estado_variant is Dictionary:
		_mentes[id] = _crear_estado_inicial()
		estado_variant = _mentes[id]
	var estado: Dictionary = (estado_variant as Dictionary).duplicate(true)
	_normalizar_estado(estado)
	return estado


func _normalizar_rasgo(valor: Variant) -> float:
	var numero := float(valor)
	# RelationshipSystem entrega perfiles sociales en escala 0-100;
	# los perfiles propios de NPCMind pueden usar 0.0-1.0.
	if numero > 1.0:
		numero /= 100.0
	return clampf(numero, 0.0, 1.0)


func _normalizar_estado(estado: Dictionary) -> void:
	var necesidades: Dictionary = estado.get("necesidades", {}).duplicate(true)
	for clave in NECESIDADES_INICIALES:
		necesidades[clave] = clampf(float(necesidades.get(clave, NECESIDADES_INICIALES[clave])), 0.0, 100.0)
	estado["necesidades"] = necesidades
	var rasgos: Dictionary = estado.get("rasgos", {}).duplicate(true)
	for clave in RASGOS_NEUTRALES:
		rasgos[clave] = clampf(float(rasgos.get(clave, RASGOS_NEUTRALES[clave])), 0.0, 1.0)
	estado["rasgos"] = rasgos
	if not estado.get("aprendizaje", {}) is Dictionary:
		estado["aprendizaje"] = {}
	if not estado.get("objetivos", []) is Array:
		estado["objetivos"] = []
	estado["version"] = VERSION_ESTADO


func _leer_mentes_guardadas() -> Dictionary:
	if not esta_configurado() or not _game_state.has_method("obtener_mentes_npc"):
		return {}
	var datos: Variant = _game_state.call("obtener_mentes_npc")
	if datos is Dictionary:
		return (datos as Dictionary).duplicate(true)
	return {}


func _guardar_mentes() -> void:
	if esta_configurado() and _game_state.has_method("guardar_mentes_npc"):
		_game_state.call("guardar_mentes_npc", _mentes.duplicate(true))


func _emitir_cambio(personaje_id: String) -> void:
	estado_mental_cambiado.emit(personaje_id, obtener_estado(personaje_id))
