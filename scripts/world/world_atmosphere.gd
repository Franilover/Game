extends Node

class_name WorldAtmosphere

## Ciclo ambiental local: modifica la iluminación del mundo y muestra
## la hora junto al bioma/ecosistema/hábitat donde está el jugador.

@export_range(2.0, 60.0, 1.0) var minutos_por_dia: float = 12.0
@export_range(0.0, 1.0, 0.01) var hora_inicial: float = 0.28

var hora_del_dia: float = 0.28
var _modulacion: CanvasModulate
var _world_generator: Node


func _ready() -> void:
	hora_del_dia = clampf(hora_inicial, 0.0, 1.0)
	_modulacion = CanvasModulate.new()
	_modulacion.name = "DayNightModulation"
	get_tree().current_scene.add_child.call_deferred(_modulacion)

	_world_generator = get_parent()
	_actualizar_iluminacion()


func _process(delta: float) -> void:
	var duracion := maxf(minutos_por_dia * 60.0, 1.0)
	hora_del_dia = fposmod(hora_del_dia + delta / duracion, 1.0)
	_actualizar_iluminacion()


func _actualizar_iluminacion() -> void:
	if _modulacion == null or not is_instance_valid(_modulacion):
		return
	# Amanecer y atardecer suaves; mediodía claro y noche azulada.
	var luz: Color
	if hora_del_dia < 0.20:
		luz = Color(0.28, 0.32, 0.52)
	elif hora_del_dia < 0.30:
		luz = Color(0.28, 0.32, 0.52).lerp(Color(1.0, 0.79, 0.62), (hora_del_dia - 0.20) / 0.10)
	elif hora_del_dia < 0.72:
		luz = Color(1.0, 0.97, 0.88)
	elif hora_del_dia < 0.82:
		luz = Color(1.0, 0.97, 0.88).lerp(Color(0.65, 0.42, 0.48), (hora_del_dia - 0.72) / 0.10)
	else:
		luz = Color(0.28, 0.32, 0.52)
	_modulacion.color = luz


func _obtener_periodo() -> String:
	if hora_del_dia < 0.20 or hora_del_dia >= 0.82:
		return "Noche"
	if hora_del_dia < 0.30:
		return "Amanecer"
	if hora_del_dia < 0.72:
		return "Día"
	return "Atardecer"


func _obtener_hora_texto() -> String:
	var minutos_totales := int(floor(hora_del_dia * 24.0 * 60.0))
	var horas := int(floor(float(minutos_totales) / 60.0))
	var minutos := minutos_totales % 60
	return "%02d:%02d" % [horas, minutos]


func obtener_tiempo() -> Dictionary:
	return {
		"hora": _obtener_hora_texto(),
		"periodo": _obtener_periodo()
	}
