extends Node
class_name GarliaRenderManager

## Orquestador central del trabajo visual diferible.
## Fase 3: presupuesto para trabajo visual diferible. TileMapDual sigue siendo el backend de composición.

@export var target_fps: float = 60.0
@export var render_budget_ms: float = 3.0

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

func registrar_trabajo(nombre: String, milisegundos: float, unidades: int = 1) -> void:
    var ms := maxf(milisegundos, 0.0)
    var unidades_validas := maxi(unidades, 1)
    var coste_unitario := ms / float(unidades_validas)

    _work_ms[nombre] = float(_work_ms.get(nombre, 0.0)) + ms
    _work_calls[nombre] = int(_work_calls.get(nombre, 0)) + 1
    _frame_work_ms[nombre] = float(_frame_work_ms.get(nombre, 0.0)) + ms

    # EMA: el presupuesto debe reaccionar al coste reciente sin quedar
    # dominado por un único pico de TileMapDual durante un cambio de chunk.
    var coste_anterior := float(_work_unit_ms.get(nombre, 0.0))
    if coste_anterior <= 0.0:
        _work_unit_ms[nombre] = coste_unitario
    else:
        _work_unit_ms[nombre] = lerpf(coste_anterior, coste_unitario, 0.25)

func presupuesto_unidades_adaptativo(nombre: String, base: int, minimo: int, maximo: int, objetivo_ms: float) -> int:
    var limite := maxi(minimo, mini(base, maximo))
    var disponible := presupuesto_disponible_ms()
    if disponible <= 0.0:
        return 0
    var objetivo := maxf(objetivo_ms, 0.1)
    var coste_por_unidad := float(_work_unit_ms.get(nombre, 0.0))
    if coste_por_unidad <= 0.0:
        return mini(limite, maxi(minimo, 16))
    var presupuesto_objetivo := minf(objetivo, disponible * 0.75)
    var estimadas := floori(presupuesto_objetivo / coste_por_unidad)
    if estimadas <= 0:
        return 0
    # Una vez aprendido el coste real, respetar el tiempo disponible tiene
    # prioridad sobre el mínimo nominal. Forzar el mínimo aquí podía convertir
    # un frame casi agotado en un lote de 4+ celdas por encima del presupuesto.
    return mini(limite, estimadas)

func registrar_trabajo_usec(nombre: String, inicio_usec: int) -> float:
    var ms := float(Time.get_ticks_usec() - inicio_usec) / 1000.0
    registrar_trabajo(nombre, ms)
    return ms

func registrar_trabajo_diferido(cantidad: int = 1) -> void:
    _deferred_work += maxi(cantidad, 0)

func consumir_trabajo_diferido(cantidad: int = 1) -> void:
    _deferred_work = maxi(_deferred_work - maxi(cantidad, 0), 0)

func presupuesto_disponible_ms() -> float:
    if _frame_start_usec == 0:
        return render_budget_ms
    var elapsed := float(Time.get_ticks_usec() - _frame_start_usec) / 1000.0
    return maxf(render_budget_ms - elapsed, 0.0)

func puede_ejecutar_trabajo(coste_estimado_ms: float = 0.0) -> bool:
    return presupuesto_disponible_ms() > coste_estimado_ms

func obtener_estado() -> Dictionary:
    return {
        "target_fps": target_fps,
        "render_budget_ms": render_budget_ms,
        "frame_used_ms": _frame_used_ms,
        "budget_remaining_ms": presupuesto_disponible_ms(),
        "deferred_work": _deferred_work,
        "work_ms": _work_ms.duplicate(),
        "work_calls": _work_calls.duplicate(),
        "frame_work_ms": _frame_work_ms.duplicate(),
        "work_unit_ms": _work_unit_ms.duplicate(),
    }