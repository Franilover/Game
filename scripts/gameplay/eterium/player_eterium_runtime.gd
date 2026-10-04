extends RefCounted
class_name PlayerEteriumRuntime

## Estado y reglas runtime de Eterium del jugador.
## Las reglas son suministradas por SupabaseClient; esta clase no consulta tablas directamente.

signal mana_changed(current: int, maximum: int)
signal fisiologia_changed(vida_eterium_compartidos: bool)

var reglas: Dictionary = {}
var organismos: Dictionary = {}
var especie_regla: Dictionary = {}

var runtime_ready: bool = false
var especie_ready: bool = false
var recupera: bool = true
var recovery_accumulator: float = 0.0
var sprint_cost_accumulator: float = 0.0

var mana: int = 100
var max_mana: int = 100

func aplicar_runtime(nuevas_reglas: Dictionary, organismos_lista: Array) -> void:
	if nuevas_reglas.is_empty():
		return

	reglas = nuevas_reglas.duplicate(true)
	organismos.clear()

	for value in organismos_lista:
		if not value is Dictionary:
			continue
		var organismo := value as Dictionary
		var id := str(organismo.get("organismo_id", ""))
		if not id.is_empty():
			organismos[id] = organismo.duplicate(true)

	var escala := _escala()
	var limite_s := float(reglas.get("limite_estable_s", 0.0))
	max_mana = maxi(1, roundi(limite_s * escala))
	mana = clampi(mana, 0, max_mana)
	runtime_ready = true
	mana_changed.emit(mana, max_mana)

func aplicar_regla_especie(regla: Dictionary) -> void:
	if regla.is_empty():
		return

	especie_regla = regla.duplicate(true)
	especie_ready = true
	var padre_variant: Variant = especie_regla.get("especie_eterium_v1", {})
	if padre_variant is Dictionary:
		var padre := padre_variant as Dictionary
		var capacidad := maxi(1, roundi(float(padre.get("capacidad_base", max_mana))))
		max_mana = capacidad
		mana = clampi(int(especie_regla.get("eterium_inicial", capacidad)), 0, max_mana)

	recupera = bool(especie_regla.get("recuperacion_eterium", true))
	mana_changed.emit(mana, max_mana)
	fisiologia_changed.emit(vida_eterium_compartidos())

func vida_eterium_compartidos() -> bool:
	return especie_ready and bool(especie_regla.get("vida_eterium_compartidos", false))

func gastar(cantidad: int) -> bool:
	var gasto := maxi(cantidad, 0)
	if gasto <= 0 or mana < gasto:
		return false
	mana -= gasto
	mana_changed.emit(mana, max_mana)
	return true

func restaurar(cantidad: int) -> bool:
	var recuperacion := maxi(cantidad, 0)
	if recuperacion <= 0 or mana >= max_mana:
		return false
	var anterior := mana
	mana = mini(mana + recuperacion, max_mana)
	if mana <= anterior:
		return false
	recovery_accumulator = 0.0
	mana_changed.emit(mana, max_mana)
	return true

func obtener_por_muerte(cantidad: int) -> bool:
	return restaurar(cantidad)

func actualizar_recuperacion(delta: float, puede_recuperar: bool) -> void:
	if not runtime_ready or not puede_recuperar or not recupera:
		return
	if mana >= max_mana:
		recovery_accumulator = 0.0
		return

	var tasa := maxf(float(reglas.get("recuperacion_pasiva_s_por_segundo", 0.0)), 0.0)
	if tasa <= 0.0:
		return

	recovery_accumulator += tasa * _escala() * delta
	var unidades := floori(recovery_accumulator)
	if unidades <= 0:
		return

	var recuperadas := mini(unidades, max_mana - mana)
	if recuperadas <= 0:
		recovery_accumulator = 0.0
		return

	mana += recuperadas
	recovery_accumulator -= recuperadas
	mana_changed.emit(mana, max_mana)

func carrera(delta: float, stamina_restaurar: Callable) -> bool:
	if not runtime_ready or mana <= 0:
		sprint_cost_accumulator = 0.0
		return false

	var costo := maxf(float(reglas.get("carrera_eterium_costo_s_por_segundo", 0.0)), 0.0)
	var recuperacion := maxf(float(reglas.get("carrera_eterium_recuperacion_stamina_por_segundo", 0.0)), 0.0)
	if costo <= 0.0:
		return false

	recovery_accumulator = 0.0
	sprint_cost_accumulator += costo * _escala() * delta

	var unidades := floori(sprint_cost_accumulator)
	if unidades > 0:
		var gastadas := mini(unidades, mana)
		if gastadas > 0:
			gastar(gastadas)
			sprint_cost_accumulator -= gastadas

	if mana <= 0:
		sprint_cost_accumulator = 0.0
		return false

	if recuperacion > 0.0:
		stamina_restaurar.call(recuperacion * delta)

	return true

func multiplicador_carrera() -> float:
	return maxf(float(reglas.get("carrera_eterium_multiplicador_velocidad", 1.0)), 1.0)

func _escala() -> float:
	return maxf(float(reglas.get("escala_runtime", 0.0)), 0.001)
