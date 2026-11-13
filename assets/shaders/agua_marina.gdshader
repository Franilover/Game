shader_type canvas_item;

// Ondas de luz animadas sobre el agua. Se conserva el UV original para
// evitar que el muestreo salga del atlas y genere bordes o píxeles deformados.
uniform float velocidad_onda : hint_range(0.0, 3.0) = 1.15;
uniform float intensidad_onda : hint_range(0.0, 0.35) = 0.19;
uniform float escala_onda : hint_range(1.0, 80.0) = 24.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;

	// Dos movimientos cruzados crean ondas que recorren la superficie.
	float fase = UV.y * escala_onda + UV.x * 7.0 + TIME * velocidad_onda;
	float modulacion = sin(UV.x * 17.0 - TIME * 0.72) * 0.42;
	float onda = sin(fase + modulacion);
	float cresta = smoothstep(0.18, 0.92, onda);

	// Una segunda línea de reflejo evita que el agua parezca sólo parpadear.
	float fase_reflejo = UV.y * 39.0 - UV.x * 11.0 - TIME * 1.55;
	float reflejo = smoothstep(0.70, 0.98, sin(fase_reflejo) * 0.5 + 0.5);

	float pulso = onda * 0.5 + 0.5;
	base.rgb *= 1.0 + (pulso - 0.5) * intensidad_onda;
	base.rgb += vec3(0.10, 0.17, 0.20) * cresta * intensidad_onda * 0.72;
	base.rgb += vec3(0.15, 0.21, 0.22) * reflejo * intensidad_onda * 0.48;

	COLOR = base;
}
