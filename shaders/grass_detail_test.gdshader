shader_type canvas_item;

uniform vec4 blade_color : source_color = vec4(0.02, 0.10, 0.01, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.55, 0.90, 0.12, 1.0);
uniform float blade_density : hint_range(2.0, 16.0) = 7.0;
uniform float blade_width : hint_range(0.02, 0.30) = 0.12;
uniform float blade_height : hint_range(0.20, 1.0) = 0.75;
uniform float wind_strength : hint_range(0.0, 0.10) = 0.02;
uniform float wind_speed : hint_range(0.0, 3.0) = 0.8;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	if (base.a <= 0.01) {
		COLOR = base;
	} else {
		float gx = UV.x * blade_density;
		float cell = floor(gx);
		float x = fract(gx);

		float r = hash21(vec2(cell, 12.7));
		float r2 = hash21(vec2(cell, 81.3));
		float r3 = hash21(vec2(cell, 144.9));

		// Una brizna grande y claramente visible por celda.
		float center = 0.5 + (r - 0.5) * 0.45;
		float width = blade_width * (0.75 + r2 * 0.5);
		float height = blade_height * (0.65 + r3 * 0.35);

		float h = 1.0 - UV.y;
		float progress = clamp(h / height, 0.0, 1.0);

		float wind = sin(TIME * wind_speed + r * 6.28318) * wind_strength;
		float blade_center = center + wind * progress;

		// Punta arriba y base ancha abajo.
		float current_width = width * (1.0 - progress * 0.82);
		float distance_x = abs(x - blade_center);

		float blade_mask = 1.0 - smoothstep(
			current_width,
			current_width + 0.025,
			distance_x
		);

		// Recorta todo lo que quede por encima de la punta.
		float height_mask = 1.0 - step(height, h);
		blade_mask *= height_mask;

		// Una pequeña segunda brizna ocasional.
		float r4 = hash21(vec2(cell + 31.0, 55.0));
		float small_mask = 0.0;

		if (r4 > 0.45) {
			float c2 = 0.22 + r4 * 0.45;
			float w2 = width * 0.55;
			float h2 = height * 0.55;
			float p2 = clamp(h / h2, 0.0, 1.0);
			float cx2 = c2 - wind * 0.5 * p2;
			float m2 = 1.0 - smoothstep(
				w2 * (1.0 - p2 * 0.75),
				w2 * (1.0 - p2 * 0.75) + 0.02,
				abs(x - cx2)
			);
			small_mask = m2 * (1.0 - step(h2, h));
		}

		float mask = max(blade_mask, small_mask);
		float variation = hash21(vec2(cell + 100.0, 9.0));
		vec3 detail_color = mix(blade_color.rgb, highlight_color.rgb, variation);

		// Mezcla fuerte para que el test sea inequívoco.
		COLOR = vec4(mix(base.rgb, detail_color, mask * 0.95), base.a);
	}
}
