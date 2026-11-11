extends ColorRect
class_name WorldClimateVisuals

## Capa de niebla atmosférica. El shader conserva la escena y reduce la
## visibilidad progresivamente desde el centro de cámara hacia los bordes.

const SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.72, 0.75, 0.78, 1.0);
uniform float visibilidad : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 escena = texture(screen_texture, SCREEN_UV);
	float intensidad = clamp((1.0 - visibilidad) * 1.12, 0.0, 0.86);
	float radio = mix(0.92, 0.30, intensidad);
	float distancia_centro = length((SCREEN_UV - vec2(0.5)) * vec2(1.0, 0.68));
	float mascara = smoothstep(radio * 0.34, radio, distancia_centro);
	float grano = fract(sin(dot(floor(SCREEN_UV * vec2(180.0, 100.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float opacidad = mascara * intensidad * (0.48 + grano * 0.12);
	COLOR = mix(escena, fog_color, clamp(opacidad, 0.0, 0.78));
}
"""

@export var climate_system_path: NodePath = NodePath("../../Systems/WorldAtmosphere/ClimateSystem")

var _climate_system: Node
var _shader_material: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -100
	_climate_system = get_node_or_null(climate_system_path)
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material = _shader_material
	color = Color.WHITE
	_actualizar_niebla()


func _process(_delta: float) -> void:
	_actualizar_niebla()


func _actualizar_niebla() -> void:
	if _shader_material == null:
		return
	var visibilidad := 1.0
	if _climate_system != null and is_instance_valid(_climate_system) and _climate_system.has_method("obtener_estado"):
		var estado: Dictionary = _climate_system.call("obtener_estado")
		var clima_variant: Variant = estado.get("clima", {})
		if clima_variant is Dictionary:
			visibilidad = clampf(float((clima_variant as Dictionary).get("visibilidad", 1.0)), 0.0, 1.0)
	_shader_material.set_shader_parameter("visibilidad", visibilidad)
