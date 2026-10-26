extends RefCounted
class_name PlayerEteriumRuntime

signal mana_changed(current: int, maximum: int)
signal fisiologia_changed(vida_eterium_compartidos: bool)

var vital_state: VitalState = null
var reglas: Dictionary = {}
var organismos: Dictionary = {}
var especie_regla: Dictionary = {}
var runtime_ready: bool = false
var especie_ready: bool = false
var recupera: bool = true
var recovery_accumulator: float = 0.0
var sprint_cost_accumulator: float = 0.0
var heal_timer: float = 0.0

func configurar_vital(nuevo_vital: VitalState) -> void:
	vital_state = nuevo_vital

func aplicar_runtime(nuevas_reglas: Dictionary, nuevos_organismos: Array) -> void:
	if nuevas_reglas.is_empty():
		return
	reglas = nuevas_reglas.duplicate(true)
	organismos.clear()
	for organismo_variant in nuevos_organismos:
		if not organismo_variant is Dictionary:
			continue
		var organismo := organismo_variant as Dictionary
		var organismo_id := str(organismo.get("organismo_id", ""))
		if not organismo_id.is_empty():
			organismos[organismo_id] = organismo.duplicate(true)
	var escala := _escala_runtime()
	var limite_s := maxf(float(reglas.get("limite_estable_s", 0.0)), 0.0)
	_configurar_max_mana(maxi(1, roundi(limite_s * escala)))
	runtime_ready = true
	_emitir_mana()

func aplicar_especie(regla: Dictionary, especie_id: String) -> bool:
	if regla.is_empty() or especie_id.is_empty():
		return false
	var padre_variant: Variant = regla.get("especie_eterium_v1", {})
	if not padre_variant is Dictionary:
		return false
	var padre := padre_variant as Dictionary
	if str(padre.get("especie_id", "")) != especie_id:
		return false
	especie_regla = regla.duplicate(true)
	especie_ready = true
	var capacidad := maxi(1, roundi(float(padre.get("capacidad_base", max_mana()))))
	var eterium_inicial := clampi(int(regla.get("eterium_inicial", capacidad)), 0, capacidad)
	_configurar_max_mana(capacidad)
	establecer_mana(eterium_inicial)
	var compartido := vida_eterium_compartidos()
	if compartido:
		_configurar_max_vida(capacidad)
		establecer_mana(capacidad)
	recupera = bool(regla.get("recuperacion_eterium", true))
	fisiologia_changed.emit(compartido)
	return true

func vida_eterium_compartidos() -> bool:
	return especie_ready and bool(especie_regla.get("vida_eterium_compartidos", false))

func max_mana() -> int:
	return 0 if vital_state == null else vital_state.max_mana

func mana() -> int:
	return 0 if vital_state == null else vital_state.mana

func establecer_mana(valor: int) -> void:
	if vital_state == null:
		return
	vital_state.mana = clampi(valor, 0, vital_state.max_mana)
	if vida_eterium_compartidos():
		vital_state.health = vital_state.mana
		vital_state.is_alive = vital_state.health > 0
	_emitir_mana()

func gastar(cantidad: int) -> bool:
	if vital_state == null:
		return false
	var gasto := maxi(cantidad, 0)
	if gasto <= 0 or vital_state.mana < gasto:
		return false
	vital_state.mana -= gasto
	if vida_eterium_compartidos():
		vital_state.health = vital_state.mana
		vital_state.is_alive = vital_state.health > 0
	_emitir_mana()
	return true

func restaurar(cantidad: int) -> bool:
	if vital_state == null or not vital_state.is_alive:
		return false
	var recuperacion := maxi(cantidad, 0)
	if recuperacion <= 0 or vital_state.mana >= vital_state.max_mana:
		return false
	var anterior := vital_state.mana
	vital_state.mana = mini(vital_state.mana + recuperacion, vital_state.max_mana)
	if vida_eterium_compartidos():
		vital_state.health = vital_state.mana
	_emitir_mana()
	return vital_state.mana > anterior

func actualizar_recuperacion(delta: float, puede_recuperar: bool) -> int:
	if not runtime_ready or not puede_recuperar or not recupera:
		if not puede_recuperar:
			recovery_accumulator = 0.0
		return 0
	if vital_state == null:
		return 0
	# Al estar lleno, el reloj de recuperación se pausa. Conservamos la
	# fracción acumulada para continuar desde ella tras gastar Eterium.
	if vital_state.mana >= vital_state.max_mana:
		return 0
	var recuperacion_s := maxf(float(reglas.get("recuperacion_pasiva_s_por_segundo", 0.0)), 0.0)
	if recuperacion_s <= 0.0:
		return 0
	recovery_accumulator += recuperacion_s * _escala_runtime() * maxf(delta, 0.0)
	var unidades := floori(recovery_accumulator)
	if unidades <= 0:
		return 0
	var recuperadas := mini(unidades, vital_state.max_mana - vital_state.mana)
	if recuperadas <= 0:
		recovery_accumulator = 0.0
		return 0
	vital_state.mana += recuperadas
	recovery_accumulator -= recuperadas
	# Si el mismo paso llena el recurso, descartar unidades completas que
	# habrían ocurrido después de alcanzar el máximo. Se conserva solo el
	# progreso parcial; el tiempo mientras está lleno no queda almacenado.
	if vital_state.mana >= vital_state.max_mana:
		recovery_accumulator = fposmod(recovery_accumulator, 1.0)
	if vida_eterium_compartidos():
		vital_state.health = vital_state.mana
	_emitir_mana()
	return recuperadas

func costo_carrera_eterium_por_segundo() -> float:
	return maxf(float(reglas.get("carrera_eterium_costo_s_por_segundo", 0.0)), 0.0)

func multiplicador_carrera_eterium() -> float:
	return maxf(float(reglas.get("carrera_eterium_multiplicador_velocidad", 1.0)), 1.0)

func recuperacion_stamina_carrera_eterium() -> float:
	return maxf(float(reglas.get("carrera_eterium_recuperacion_stamina_por_segundo", 0.0)), 0.0)

func calcular_costo_carrera(delta: float) -> int:
	if not runtime_ready:
		return 0
	sprint_cost_accumulator += costo_carrera_eterium_por_segundo() * _escala_runtime() * maxf(delta, 0.0)
	return floori(sprint_cost_accumulator)

func confirmar_costo_carrera(cantidad: int) -> bool:
	if cantidad <= 0:
		return true
	var gastadas := mini(cantidad, mana())
	if gastadas <= 0:
		sprint_cost_accumulator = 0.0
		return false
	if not gastar(gastadas):
		return false
	sprint_cost_accumulator -= gastadas
	return true

func calcular_curacion(delta: float) -> Dictionary:
	if not runtime_ready or vital_state == null or vital_state.health >= vital_state.max_health:
		heal_timer = 0.0
		return {}
	var escala := _escala_runtime()
	var costo_s := maxf(float(reglas.get("curacion_costo_s_por_tick", 0.0)), 0.0)
	var intervalo_s := maxf(float(reglas.get("curacion_intervalo_s", 0.0)), 0.01)
	var curacion_por_s := maxf(float(reglas.get("curacion_vida_por_s", 0.0)), 0.0)
	var costo_runtime := maxi(1, roundi(costo_s * escala))
	if mana() < costo_runtime:
		heal_timer = 0.0
		return {}
	heal_timer -= maxf(delta, 0.0)
	if heal_timer > 0.0:
		return {}
	heal_timer = intervalo_s
	var curacion := mini(maxi(1, roundi(costo_s * curacion_por_s)), vital_state.max_health - vital_state.health)
	if curacion <= 0:
		return {}
	return {"curacion": curacion, "costo_eterium": costo_runtime}

func aplicar_curacion(curacion: int, costo_eterium: int) -> bool:
	if vital_state == null or curacion <= 0 or (costo_eterium > 0 and mana() < costo_eterium):
		return false
	var anterior := vital_state.health
	vital_state.health = mini(vital_state.health + curacion, vital_state.max_health)
	if vital_state.health <= anterior:
		return false
	if costo_eterium > 0 and not gastar(costo_eterium):
		vital_state.health = anterior
		return false
	return true

func calcular_absorcion(datos_criatura: Dictionary) -> int:
	if not runtime_ready or datos_criatura.is_empty():
		return 0
	var biologia_variant: Variant = datos_criatura.get("biologia_calculada", {})
	if not biologia_variant is Dictionary:
		return 0
	var biologia := biologia_variant as Dictionary
	var organismo_id := str(biologia.get("organismo_id", ""))
	var organismo_variant: Variant = organismos.get(organismo_id, {})
	if organismo_id.is_empty() or not organismo_variant is Dictionary:
		return 0
	var organismo := organismo_variant as Dictionary
	if not bool(organismo.get("posee_eterium", false)):
		return 0
	var base := str(organismo.get("base_eterium", "")).strip_edges().to_lower()
	var rendimientos_variant: Variant = reglas.get("rendimiento_por_base_s", {})
	if base.is_empty() or not rendimientos_variant is Dictionary:
		return 0
	var rendimiento_s := maxf(float((rendimientos_variant as Dictionary).get(base, 0.0)), 0.0)
	var eficiencia := clampf(float(reglas.get("absorcion_eficiencia", 0.0)), 0.0, 1.0)
	var cantidad := roundi(rendimiento_s * eficiencia * _escala_runtime())
	return clampi(cantidad, 0, maxi(max_mana() - mana(), 0))

func absorber(cantidad: int) -> int:
	if vital_state == null:
		return 0
	var real := clampi(cantidad, 0, maxi(vital_state.max_mana - vital_state.mana, 0))
	if real <= 0:
		return 0
	vital_state.mana += real
	# La absorción cambia el recurso, no el progreso del reloj pasivo.
	# Si llena el Eterium, el progreso queda pausado hasta el siguiente gasto.
	_emitir_mana()
	return real

func reiniciar_temporizadores() -> void:
	recovery_accumulator = 0.0
	sprint_cost_accumulator = 0.0
	heal_timer = 0.0

func _escala_runtime() -> float:
	return maxf(float(reglas.get("escala_runtime", 0.0)), 0.001)

func _configurar_max_mana(valor: int) -> void:
	if vital_state == null:
		return
	vital_state.max_mana = maxi(valor, 0)
	vital_state.mana = clampi(vital_state.mana, 0, vital_state.max_mana)

func _configurar_max_vida(valor: int) -> void:
	if vital_state == null:
		return
	vital_state.max_health = maxi(valor, 0)
	vital_state.health = clampi(vital_state.health, 0, vital_state.max_health)

func _emitir_mana() -> void:
	if vital_state != null:
		mana_changed.emit(vital_state.mana, vital_state.max_mana)
