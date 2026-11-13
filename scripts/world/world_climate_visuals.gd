extends ColorRect
class_name WorldClimateVisuals

## Renderiza niebla y precipitacion sobre el mundo. El estado meteorologico
## se consulta en el ecosistema donde esta el jugador.

const SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.72, 0.75, 0.78, 1.0);
uniform float visibilidad : hint_range(0.0, 1.0) = 1.0;
uniform float intensidad_carmesi : hint_range(0.0, 0.65) = 0.34;
uniform float densidad_particulas : hint_range(0.0, 0.01) = 0.0012;
uniform float velocidad_particulas : hint_range(0.1, 3.0) = 0.82;

void fragment() {
	vec4 escena = texture(screen_texture, SCREEN_UV);
	vec3 color = escena.rgb;

	// Filtro ambiental carmesí: oscurece ligeramente y desplaza los tonos
	// hacia rojos apagados sin borrar el contraste de los sprites.
	vec3 tono_carmesi = color * vec3(0.91, 0.53, 0.59) + vec3(0.025, 0.0, 0.012);
	color = mix(color, tono_carmesi, intensidad_carmesi);

	// Viñeta tenue para concentrar la mirada en el terreno.
	float distancia_centro = length((SCREEN_UV - vec2(0.5)) * vec2(1.0, 0.72));
	float viñeta = smoothstep(0.34, 0.92, distancia_centro) * 0.16;
	color *= 1.0 - viñeta;

	// Se conserva la niebla meteorológica existente.
	float intensidad_niebla = clamp((1.0 - visibilidad) * 1.12, 0.0, 0.86);
	float radio = mix(0.92, 0.30, intensidad_niebla);
	float mascara = smoothstep(radio * 0.34, radio, distancia_centro);
	float grano = fract(sin(dot(floor(SCREEN_UV * vec2(180.0, 100.0)), vec2(12.9898, 78.233))) * 43758.5453);
	float opacidad_niebla = mascara * intensidad_niebla * (0.48 + grano * 0.12);
	color = mix(color, fog_color.rgb, clamp(opacidad_niebla, 0.0, 0.78));

	// Pequeños píxeles rojos: cada intervalo genera una distribución nueva,
	// de modo que aparecen y desaparecen en ráfagas breves e irregulares.
	vec2 tamano_pixel = SCREEN_PIXEL_SIZE * 2.0;
	vec2 celda = floor(SCREEN_UV / tamano_pixel);
	float intervalo = floor(TIME * velocidad_particulas);
	vec2 semilla = celda + vec2(intervalo * 17.1, intervalo * 9.2);
	float azar = fract(sin(dot(semilla, vec2(12.9898, 78.233))) * 43758.5453);
	float particula = step(1.0 - densidad_particulas, azar);
	float fase = fract(TIME * velocidad_particulas);
	float pulso = smoothstep(0.02, 0.18, fase) * (1.0 - smoothstep(0.76, 0.98, fase));
	color += vec3(0.82, 0.035, 0.075) * particula * pulso * 0.9;

	COLOR = vec4(color, escena.a);
}
"""

@export var climate_system_path: NodePath = NodePath("../../Systems/WorldAtmosphere/ClimateSystem")
@export var player_path: NodePath = NodePath("../../Entities/Player")

var _climate_system: Node
var _player: Node2D
var _shader_material: ShaderMaterial
var _particulas: GPUParticles2D
var _material_particulas: ParticleProcessMaterial
var _textura_lluvia: Texture2D
var _textura_nieve: Texture2D
var _ultimo_tipo_clima: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -100
	_climate_system = get_node_or_null(climate_system_path)
	_player = get_node_or_null(player_path) as Node2D

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material = _shader_material
	color = Color.WHITE

	_crear_particulas()
	_actualizar_efectos()


func _process(_delta: float) -> void:
	_actualizar_efectos()


func _crear_particulas() -> void:
	_textura_lluvia = _crear_textura_lluvia()
	_textura_nieve = _crear_textura_nieve()
	_particulas = GPUParticles2D.new()
	_particulas.name = "WeatherParticles"
	_particulas.amount = 110
	_particulas.lifetime = 1.4
	_particulas.emitting = false
	_particulas.one_shot = false
	_particulas.local_coords = false
	_material_particulas = ParticleProcessMaterial.new()
	_material_particulas.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material_particulas.spread = 5.0
	_material_particulas.direction = Vector3(-0.1, 1.0, 0.0)
	_material_particulas.gravity = Vector3(0.0, 220.0, 0.0)
	_material_particulas.initial_velocity_min = 180.0
	_material_particulas.initial_velocity_max = 260.0
	_material_particulas.scale_min = 0.65
	_material_particulas.scale_max = 1.0
	_particulas.process_material = _material_particulas
	_particulas.texture = _textura_lluvia
	add_child(_particulas)
	_actualizar_area_particulas()


func _crear_textura_lluvia() -> Texture2D:
	var imagen := Image.create(2, 7, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(0.76, 0.85, 0.94, 0.58))
	return ImageTexture.create_from_image(imagen)


func _crear_textura_nieve() -> Texture2D:
	var imagen := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(1.0, 1.0, 1.0, 0.0))
	var blanco := Color(0.94, 0.97, 1.0, 0.9)
	for punto in [
		Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2),
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(4, 2), Vector2i(2, 3), Vector2i(2, 4)
	]:
		imagen.set_pixel(punto.x, punto.y, blanco)
	return ImageTexture.create_from_image(imagen)


func _actualizar_area_particulas() -> void:
	if _particulas == null or _material_particulas == null:
		return
	var tamano := get_viewport_rect().size
	_particulas.position = tamano * 0.5
	_particulas.visibility_rect = Rect2(-tamano * 0.5, tamano)
	_material_particulas.emission_box_extents = Vector3(
		tamano.x * 0.5 + 48.0,
		tamano.y * 0.5 + 64.0,
		0.0
	)


func _obtener_estado_climatico() -> Dictionary:
	if _climate_system == null or not is_instance_valid(_climate_system):
		return {}
	if is_instance_valid(_player) and _climate_system.has_method("obtener_estado_para_posicion"):
		return _climate_system.call(
			"obtener_estado_para_posicion",
			_player.global_position,
			""
		)
	if _climate_system.has_method("obtener_estado"):
		return _climate_system.call("obtener_estado")
	return {}


func _actualizar_efectos() -> void:
	var estado := _obtener_estado_climatico()
	var clima_variant: Variant = estado.get("clima", {})
	var clima: Dictionary = clima_variant if clima_variant is Dictionary else {}
	var visibilidad := clampf(float(clima.get("visibilidad", 1.0)), 0.0, 1.0)
	if _shader_material != null:
		_shader_material.set_shader_parameter("visibilidad", visibilidad)
	_actualizar_particulas(clima)


func _actualizar_particulas(clima: Dictionary) -> void:
	if _particulas == null or _material_particulas == null:
		return
	var tipo := str(clima.get("tipo", "despejado"))
	var precipitacion := clampf(float(clima.get("precipitacion", 0.0)), 0.0, 1.0)
	var es_nieve := tipo == "nieve"
	var es_lluvia := tipo in ["lluvia", "tormenta"] and precipitacion > 0.02
	if not es_nieve and not es_lluvia:
		_particulas.emitting = false
		_ultimo_tipo_clima = tipo
		return

	if tipo != _ultimo_tipo_clima:
		_particulas.restart()
	_ultimo_tipo_clima = tipo
	_actualizar_area_particulas()
	_particulas.texture = _textura_nieve if es_nieve else _textura_lluvia
	_particulas.amount = clampi(18 + int(precipitacion * 115.0), 18, 140)
	_particulas.lifetime = 2.0 if es_nieve else 1.15
	_material_particulas.spread = 18.0 if es_nieve else 4.0
	var viento := clampf(float(clima.get("viento", 0.0)), 0.0, 1.0)
	_material_particulas.direction = Vector3(-0.08 - viento * 0.48, 1.0, 0.0)
	if es_nieve:
		_material_particulas.gravity = Vector3(-viento * 16.0, 22.0, 0.0)
		_material_particulas.initial_velocity_min = 18.0
		_material_particulas.initial_velocity_max = 42.0
		_material_particulas.scale_min = 0.7
		_material_particulas.scale_max = 1.25
	else:
		_material_particulas.gravity = Vector3(-viento * 48.0, 220.0, 0.0)
		_material_particulas.initial_velocity_min = 190.0
		_material_particulas.initial_velocity_max = 285.0
		_material_particulas.scale_min = 0.7
		_material_particulas.scale_max = 1.15
	_particulas.emitting = true
