shader_type canvas_item;

uniform vec4 blade_color : source_color = vec4(0.02, 0.10, 0.01, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.55, 0.90, 0.12, 1.0);

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
		// PRUEBA: formas grandes y deliberadamente exageradas.
		// Si esto aparece, sabemos que el material/shader sí está activo.
		float x = UV.x * 10.0;
		float cell = floor(x);
		float local_x = fract(x);

		float r = hash21(vec2(cell, 42.0));
		float center = 0.5 + (r - 0.5) * 0.5;

		// Triángulo vertical: ancho abajo, punta arriba.
		float h = 1.0 - UV.y;
		float height = 0.45 + r * 0.45;
		float progress = clamp(h / height, 0.0, 1.0);
		float width = mix(0.14, 0.015, progress);

		float mask = 1.0 - smoothstep(
			width,
			width + 0.02,
			abs(local_x - center)
		);

		mask *= 1.0 - step(height, h);

		// Sin mezcla sutil: la brizna reemplaza completamente el color.
		vec3 grass = mix(blade_color.rgb, highlight_color.rgb, r);
		COLOR = vec4(mix(base.rgb, grass, mask), base.a);
	}
}
