shader_type canvas_item;

uniform vec4 blade_color : source_color = vec4(0.04, 0.13, 0.02, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.45, 0.75, 0.12, 1.0);
uniform float density : hint_range(1.0, 20.0) = 9.0;
uniform float strength : hint_range(0.0, 1.0) = 0.95;
uniform float wind_strength : hint_range(0.0, 0.15) = 0.025;
uniform float wind_speed : hint_range(0.0, 3.0) = 0.8;
uniform float seed = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float blade(vec2 p, float center, float width, float height, float bend) {
	float h = 1.0 - p.y;
	float in_height = 1.0 - smoothstep(height, height + 0.04, h);
	float tip_center = center + bend * (h / max(height, 0.001));
	float w = mix(width, 0.008, clamp(h / max(height, 0.001), 0.0, 1.0));
	float edge = 1.0 - smoothstep(w, w + 0.018, abs(p.x - tip_center));
	return edge * in_height;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	if (base.a <= 0.01) {
		COLOR = base;
	} else {
		// Cada franja tiene su propia semilla. No hay degradado: son formas
		// discretas de brizna sobre el tile.
		float x = UV.x * density;
		float cell = floor(x);
		float local_x = fract(x);

		float r1 = hash21(vec2(cell, seed));
		float r2 = hash21(vec2(cell + 17.0, seed));
		float r3 = hash21(vec2(cell + 43.0, seed));

		float center = 0.5 + (r1 - 0.5) * 0.45;
		float width = 0.055 + r2 * 0.045;
		float height = 0.28 + r3 * 0.52;
		float sway = sin(TIME * wind_speed + r1 * 6.28318) * wind_strength;

		float b1 = blade(vec2(local_x, UV.y), center, width, height, sway);

		// Segunda brizna irregular entre algunas principales.
		float r4 = hash21(vec2(cell + 91.0, seed + 7.0));
		float b2 = 0.0;
		if (r4 > 0.48) {
			b2 = blade(
				vec2(fract(local_x + 0.37), UV.y),
				0.5 + (r4 - 0.5) * 0.4,
				width * 0.55,
				height * 0.72,
				-sway * 0.6
			);
		}

		float mask = max(b1, b2);
		float shade = hash21(vec2(cell + 131.0, seed + 19.0));
		vec3 detail = mix(blade_color.rgb, highlight_color.rgb, shade);

		COLOR = vec4(mix(base.rgb, detail, mask * strength), base.a);
	}
}
