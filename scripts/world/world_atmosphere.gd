extends Node

class_name WorldAtmosphere

## Ciclo ambiental local: modifica la iluminación del mundo y muestra
## la hora junto al bioma/ecosistema/hábitat donde está el jugador.

@export_range(2.0, 60.0, 1.0) var minutos_por_dia: float = 12.0
@export_range(0.0, 1.0, 0.01) var hora_inicial: float = 0.28

var hora_del_dia: float = 0.28
var _modulacion: CanvasModulate
var _etiqueta: Label
var _ultimo_tile: Vector2i = Vector2i(2147483647, 2147483647)
var _world_generator: Node


func _ready() -> void:
	hora_del_dia = clampf(hora_inicial, 0.0, 1.0)
	_modulacion = CanvasModulate.new()
	_modulacion.name = "DayNightModulation"
	get_tree().current_scene.add_child.call_deferred(_modulacion)

	var capa := CanvasLayer.new()
	capa.name = "WorldContextLayer"
	get_tree().current_scene.add_child.call_deferred(capa)

	_etiqueta = Label.new()
	_etiqueta.name = "WorldContextLabel"
	_etiqueta.position = Vector2(12.0, 12.0)
	_etiqueta.add_theme_font_size_override("font_size", 12)
	_etiqueta.add_theme_color_override("font_color", Color(0.93, 0.91, 0.84))
	_etiqueta.add_theme_color_override("font_shadow_color", Color(0.08, 0.07, 0.12, 0.9))
	_etiqueta.add_theme_constant_override("shadow_offset_x", 1)
	_etiqueta.add_theme_constant_override("shadow_offset_y", 1)
	capa.add_child.call_deferred(_etiqueta)

	_world_generator = get_parent()
	_actualizar_iluminacion()


func _process(delta: float) -> void:
	var duracion := maxf(minutos_por_dia * 60.0, 1.0)
	hora_del_dia = fposmod(hora_del_dia + delta / duracion, 1.0)
	_actualizar_iluminacion()


func procesar_jugador() -> void:
	if _world_generator == null or _etiqueta == null:
		return
	var jugador := get_tree().get_first_node_in_group("player")
	if not jugador is Node2D:
		return
	if not _world_generator.has_method("get_tile_at") or not _world_generator.has_method("get_contexto_at"):
		return
	var tile_variant: Variant = _world_generator.call("get_tile_at", jugador.global_position)
	if not tile_variant is Vector2i:
		return
	var tile := tile_variant as Vector2i
	if tile == _ultimo_tile:
		return
	_ultimo_tile = tile
	var contexto_variant: Variant = _world_generator.call("get_contexto_at", jugador.global_position)
	if not contexto_variant is Dictionary:
		return
	var contexto := contexto_variant as Dictionary
	_etiqueta.text = "%s  |  %s\nBioma: %s\nEcosistema: %s\nHábitat: %s" % [
		_obtener_periodo(),
		_obtener_hora_texto(),
		str(contexto.get("bioma", "—")),
		str(contexto.get("ecosistema", "—")),
		str(contexto.get("habitat", "—"))
	]


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
