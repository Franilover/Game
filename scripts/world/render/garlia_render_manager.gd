extends Node
class_name GarliaRenderManager

## Orquestador central del trabajo visual diferible.
## Fase 3: presupuesto para trabajo visual diferible. TileMapDual sigue siendo el backend de composición.

@export var target_fps: float = 60.0
@export var render_budget_ms: float = 5.0
## Fracción del presupuesto visual reservada para que el terreno base
## siempre reciba servicio aunque otro sistema haya consumido el resto.
## No aumenta el presupuesto total por defecto: define una garantía de servicio.
@export_range(0.05, 0.50, 0.05) var terrain_service_fraction: float = 0.25
@export var terrain_service_min_ms: float = 0.75
@export var terrain_service_max_ms: float = 1.50

var _frame_start_usec: int = 0
var _frame_used_ms: float = 0.0
var _work_ms: Dictionary = {}
var _work_calls: Dictionary = {}
var _deferred_work: int = 0
var _frame_work_ms: Dictionary = {}
var _work_unit_ms: Dictionary = {}


func iniciar_frame() -> void:
	_frame_start_usec = Time.get_ticks_usec()
	_frame_used_ms = 0.0
	_frame_work_ms.clear()


func finalizar_frame() -> void:
	if _frame_start_usec == 0:
		return
	_frame_used_ms = float(Time.get_ticks_usec() - _frame_start_usec) / 1000.0


func registrar_trabajo(
	nombre: String,
	milisegundos: float,
	unidades: int = 1
) -> void:
	var ms := maxf(milisegundos, 0.0)
	var unidades_validas := maxi(unidades, 1)
	var coste_unitario := ms / float(unidades_validas)

	_work_ms[nombre] = float(_work_ms.get(nombre, 0.0)) + ms
	_work_calls[nombre] = int(_work_calls.get(nombre, 0)) + 1
	_frame_work_ms[nombre] = float(_frame_work_ms.get(nombre, 0.0)) + ms

	# EMA: el presupuesto debe reaccionar al coste reciente sin quedar
	# dominado por un único pico de TileMapDual durante un cambio de chunk.
	# terrain_flush nunca debe aprender un coste unitario a partir de
	# un micro-lote forzado. Si un frame sólo pudo ejecutar 1-4 celdas,
	# ese valor puede inflar artificialmente la EMA y hacer que el siguiente
	# frame vuelva a elegir 1 celda, creando una espiral de lentitud.
	var actualizar_coste := true
	if nombre == "terrain_flush" and unidades_validas < 8:
		actualizar_coste = false
	if actualizar_coste:
		var coste_anterior := float(_work_unit_ms.get(nombre, 0.0))
		if coste_anterior <= 0.0:
			_work_unit_ms[nombre] = coste_unitario
		else:
			_work_unit_ms[nombre] = lerpf(
				coste_anterior,
				coste_unitario,
				0.25
			)


func presupuesto_unidades_terreno(
	nombre: String,
	base: int,
	minimo: int,
	maximo: int,
	objetivo_ms: float
) -> int:
	# El terreno base tiene una garantía de servicio independiente del trabajo
	# visual secundario. Si el presupuesto restante ya alcanzó la reserva, se
	# usa normalmente; si no, se concede sólo la reserva calculada para evitar
	# que la cola quede varios segundos sin un commit visual.
	var limite: int = maxi(minimo, mini(base, maximo))
	var reserva: float = clampf(
		render_budget_ms * terrain_service_fraction,
		terrain_service_min_ms,
		terrain_service_max_ms
	)
	var disponible: float = presupuesto_disponible_ms()
	var presupuesto_servicio: float = maxf(disponible, reserva)
	var objetivo: float = minf(maxf(objetivo_ms, 0.1), presupuesto_servicio)
	var coste_por_unidad: float = float(_work_unit_ms.get(nombre, 0.0))

	if coste_por_unidad <= 0.0:
		return mini(limite, maxi(minimo, 1))

	var estimadas: int = floori(objetivo / coste_por_unidad)
	if estimadas <= 0:
		# Garantía de progreso: una unidad puede superar el objetivo por un
		# pico puntual de TileMapDual, pero no deja la cola bloqueada.
		return 1
	return mini(limite, estimadas)


func presupuesto_unidades_adaptativo(
	nombre: String,
	base: int,
	minimo: int,
	maximo: int,
	objetivo_ms: float
) -> int:
	var limite: int = maxi(
		minimo,
		mini(base, maximo)
	)

	var disponible: float = presupuesto_disponible_ms()

	# Nunca dejar una cola visual bloqueada indefinidamente porque otro
	# sistema consumió el presupuesto antes de llegar aquí. En ese caso se
	# procesa exactamente una unidad y se cede el resto al siguiente frame.
	# Esto es especialmente importante para la generación inicial del mundo:
	# un presupuesto agotado no puede significar "cero terreno para siempre".
	if disponible <= 0.0:
		return 1

	var objetivo: float = maxf(objetivo_ms, 0.1)
	var coste_por_unidad: float = float(
		_work_unit_ms.get(nombre, 0.0)
	)

	if coste_por_unidad <= 0.0:
		return mini(
			limite,
			maxi(minimo, 16)
		)

	var presupuesto_objetivo: float = minf(
		objetivo,
		disponible * 0.75
	)
	var estimadas: int = floori(
		presupuesto_objetivo / coste_por_unidad
	)

	if estimadas <= 0:
		return 1

	return mini(
		limite,
		estimadas
	)


func registrar_trabajo_usec(
	nombre: String,
	inicio_usec: int
) -> float:
	var ms := float(
		Time.get_ticks_usec() - inicio_usec
	) / 1000.0
	registrar_trabajo(nombre, ms)
	return ms


func registrar_trabajo_diferido(cantidad: int = 1) -> void:
	_deferred_work += maxi(cantidad, 0)


func consumir_trabajo_diferido(cantidad: int = 1) -> void:
	_deferred_work = maxi(
		_deferred_work - maxi(cantidad, 0),
		0
	)


func presupuesto_disponible_ms() -> float:
	if _frame_start_usec == 0:
		return render_budget_ms

	var elapsed := float(
		Time.get_ticks_usec() - _frame_start_usec
	) / 1000.0

	return maxf(
		render_budget_ms - elapsed,
		0.0
	)


func puede_ejecutar_trabajo(
	coste_estimado_ms: float = 0.0
) -> bool:
	return presupuesto_disponible_ms() > coste_estimado_ms


func obtener_estado() -> Dictionary:
	return {
		"target_fps": target_fps,
		"render_budget_ms": render_budget_ms,
		"frame_used_ms": _frame_used_ms,
		"budget_remaining_ms": presupuesto_disponible_ms(),
		"terrain_service_reserve_ms": clampf(render_budget_ms * terrain_service_fraction, terrain_service_min_ms, terrain_service_max_ms),
		"deferred_work": _deferred_work,
		"work_ms": _work_ms.duplicate(),
		"work_calls": _work_calls.duplicate(),
		"frame_work_ms": _frame_work_ms.duplicate(),
		"work_unit_ms": _work_unit_ms.duplicate(),
	}


func obtener_diagnostico() -> Dictionary:
	return obtener_estado()
