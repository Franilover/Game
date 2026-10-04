shader_type canvas_item;

uniform vec4 blade_color : source_color = vec4(0.16, 0.28, 0.10, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.38, 0.55, 0.18, 1.0);
uniform float detail_density : hint_range(0.0, 1.0) = 0.32;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.55;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.10;
uniform float wind_speed : hint_range(0.0, 3.0) = 0.45;
uniform float seed = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	if (base.a <= 0.01) {
		COLOR = base;
		return;
	}

	// Grid independiente de la textura: cada celda recibe una pequeña
	// variación determinista, evitando que el patrón sea idéntico en todos
	// los tiles.
	vec2 grid = vec2(8.0, 8.0);
	vec2 cell = floor(UV * grid);
	vec2 local = fract(UV * grid);
	float random = hash21(cell + seed);

	// Solo una parte de las celdas se convierte en una brizna.
	float blade = step(1.0 - detail_density, random);

	float center = 0.5 + (hash21(cell + seed + 17.0) - 0.5) * 0.65;
	float width = 0.12 + hash21(cell + seed + 31.0) * 0.08;

	float sway = sin(TIME * wind_speed + random * 6.28318) * wind_strength;
	float x = center + sway * (1.0 - local.y);
	float shape = 1.0 - smoothstep(width, width + 0.08, abs(local.x - x));

	// La punta ocupa menos área para que parezca una brizna pixelada.
	float tip = smoothstep(0.05, 0.45, local.y);
	float grass_mask = blade * shape * tip;

	// Mantener el efecto sutil: mezcla con el color existente.
	vec3 detail_color = mix(blade_color.rgb, highlight_color.rgb, random);
	float amount = grass_mask * detail_strength;

	COLOR = vec4(mix(base.rgb, detail_color, amount), base.a);
}
