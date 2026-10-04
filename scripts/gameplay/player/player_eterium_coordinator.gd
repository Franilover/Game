extends RefCounted
class_name PlayerEteriumCoordinator

## Adaptador entre Player y PlayerEteriumRuntime.
## Player conserva temporalmente sus nodos/animación; las reglas y cálculos
## de Eterium viven en el runtime.

var runtime: PlayerEteriumRuntime
var stamina: PlayerStaminaController

func configurar(nuevo_runtime: PlayerEteriumRuntime, nueva_stamina: PlayerStaminaController) -> void:
	runtime = nuevo_runtime
	stamina = nueva_stamina

func configurar_vital(vital: VitalState) -> void:
	if runtime != null:
		runtime.configurar_vital(vital)

func aplicar_runtime(reglas: Dictionary, organismos: Array) -> void:
	if runtime != null:
		runtime.aplicar_runtime(reglas, organismos)

func aplicar_especie(regla: Dictionary, especie_id: String) -> bool:
	if runtime == null:
		return false
	return runtime.aplicar_especie(regla, especie_id)

func esta_listo() -> bool:
	return runtime != null and runtime.runtime_ready

func vida_eterium_compartidos() -> bool:
	return runtime != null and runtime.vida_eterium_compartidos()

func mana() -> int:
	return 0 if runtime == null else runtime.mana()

func max_mana() -> int:
	return 0 if runtime == null else runtime.max_mana()

func multiplicador_carrera() -> float:
	if runtime == null:
		return 1.0
	return runtime.multiplicador_carrera_eterium()


func gastar(cantidad: int) -> bool:
	return runtime != null and runtime.gastar(cantidad)

func restaurar(cantidad: int) -> bool:
	return runtime != null and runtime.restaurar(cantidad)

func actualizar_recuperacion(delta: float, puede_recuperar: bool) -> int:
	if runtime == null:
		return 0
	return runtime.actualizar_recuperacion(delta, puede_recuperar)

func procesar_carrera(delta: float) -> bool:
	if runtime == null or not runtime.runtime_ready:
		return false
	if runtime.mana() <= 0:
		return false

	var costo_s := runtime.costo_carrera_eterium_por_segundo()
	if costo_s <= 0.0:
		return false

	var unidades := runtime.calcular_costo_carrera(delta)
	if unidades > 0:
		runtime.confirmar_costo_carrera(unidades)

	if runtime.mana() <= 0:
		return false

	var recuperacion := runtime.recuperacion_stamina_carrera_eterium()
	if stamina != null and recuperacion > 0.0:
		stamina.restaurar(recuperacion * delta)

	return true

func calcular_curacion(delta: float) -> Dictionary:
	if runtime == null:
		return {}
	return runtime.calcular_curacion(delta)

func aplicar_curacion(curacion: int, costo: int) -> bool:
	return runtime != null and runtime.aplicar_curacion(curacion, costo)

func calcular_absorcion(datos_criatura: Dictionary) -> int:
	if runtime == null:
		return 0
	return runtime.calcular_absorcion(datos_criatura)

func absorber(cantidad: int) -> int:
	if runtime == null:
		return 0
	return runtime.absorber(cantidad)

func reiniciar() -> void:
	if runtime != null:
		runtime.reiniciar_temporizadores()
