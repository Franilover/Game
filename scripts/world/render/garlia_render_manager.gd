extends Node
class_name GarliaRenderManager

## Orquestador central del trabajo visual diferible.
## Fase 1: instrumentación y presupuesto. No cambia todavía el backend de terreno.

@export var target_fps: float = 60.0
@export var render_budget_ms: float = 3.0

var _frame_start_usec: int = 0
var _frame_used_ms: float = 0.0
var _work_ms: Dictionary = {}
var _work_calls: Dictionary = {}
var _deferred_work: int = 0

func iniciar_frame() -> void:
    _frame_start_usec = Time.get_ticks_usec()
    _frame_used_ms = 0.0

func finalizar_frame() -> void:
    if _frame_start_usec == 0:
        return
    _frame_used_ms = float(Time.get_ticks_usec() - _frame_start_usec) / 1000.0

func registrar_trabajo(nombre: String, milisegundos: float) -> void:
    _work_ms[nombre] = float(_work_ms.get(nombre, 0.0)) + milisegundos
    _work_calls[nombre] = int(_work_calls.get(nombre, 0)) + 1

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
    }