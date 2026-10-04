shader_type canvas_item;

uniform vec4 blade_color : source_color = vec4(0.05, 0.16, 0.025, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.65, 0.85, 0.20, 1.0);
uniform float blade_count : hint_range(4.0, 32.0) = 14.0;
uniform float blade_width : hint_range(0.01, 0.25) = 0.075;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.90;
uniform float wind_strength : hint_range(0.0, 0.15) = 0.025;
uniform float wind_speed : hint_range(0.0, 3.0) = 0.8;
uniform float seed = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float blade_shape(vec2 uv, float center, float width, float height, float bend) {
	float h = 1.0 - uv.y;
	float visible = smoothstep(0.0, 0.06, h) * smoothstep(height + 0.05, height, h);
	float center_x = center + bend * h;
	float half_width = mix(width, 0.012, h / max(height, 0.001));
	float edge = 1.0 - smoothstep(half_width, half_width + 0.012, abs(uv.x - center_x));
	return edge * visible;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	if (base.a <= 0.01) {
		COLOR = base;
	} else {
		float count = blade_count;
		float x_scaled = UV.x * count;
		float cell = floor(x_scaled);
		float local_x = fract(x_scaled);
		float r1 = hash21(vec2(cell, seed));
		float r2 = hash21(vec2(cell + 37.0, seed + 11.0));
		float r3 = hash21(vec2(cell + 71.0, seed + 23.0));

		float center = 0.5 + (r1 - 0.5) * 0.55;
		float width = blade_width * (0.65 + r2 * 0.7);
		float height = 0.35 + r3 * 0.55;

		float sway = sin(TIME * wind_speed + r1 * 6.28318) * wind_strength;
		float blade = blade_shape(vec2(local_x, UV.y), center, width, height, sway);

		// Segunda capa de briznas, desplazada, para que el patrón no parezca una
		// fila uniforme de líneas.
		float cell2 = floor(UV.x * count * 0.55 + 2.7);
		float lx2 = fract(UV.x * count * 0.55 + 2.7);
		float rr = hash21(vec2(cell2, seed + 101.0));
		float rr2 = hash21(vec2(cell2 + 19.0, seed + 131.0));
		float blade2 = blade_shape(
			vec2(lx2, UV.y),
			0.5 + (rr - 0.5) * 0.5,
			blade_width * 0.65,
			0.25 + rr2 * 0.45,
			-sway * 0.7
		);

		float mask = max(blade, blade2);
		float color_mix = hash21(vec2(cell + 9.0, seed + 50.0));
		vec3 detail = mix(blade_color.rgb, highlight_color.rgb, color_mix);

		// Contraste fuerte a propósito: esta prueba debe permitir ver claramente
		// si el shader está generando geometría visual sobre el tile.
		COLOR = vec4(mix(base.rgb, detail, mask * detail_strength), base.a);
	}
}
