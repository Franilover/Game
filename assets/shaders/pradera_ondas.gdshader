shader_type canvas_item;

// La Pradera conserva su textura y sus máscaras de TileMapDual.
// El efecto usa coordenadas globales para no reiniciarse en cada celda/chunk.
varying vec2 posicion_mundo;

uniform float velocidad_expansion : hint_range(0.0, 1.5) = 0.28;
uniform float intensidad_onda : hint_range(0.0, 0.25) = 0.075;
uniform float separacion_ondas : hint_range(0.005, 0.08) = 0.024;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 p = floor(posicion_mundo / 2.0) * 2.0;

	// Frentes amplios que se expanden en diagonal, con centros muy separados
	// para que el patrón se perciba como un fenómeno del terreno completo.
	vec2 celda = floor(p / 384.0);
	vec2 centro = celda * 384.0 + vec2(192.0);
	float distancia = length((p - centro) * vec2(0.82, 1.0));
	float fase = distancia * separacion_ondas - TIME * velocidad_expansion;
	float onda = sin(fase);
	float cresta = smoothstep(0.72, 0.98, onda);

	// Una segunda dirección rompe la repetición circular sin crear oleaje.
	float diagonal = p.x * 0.010 - p.y * 0.006;
	float modulacion = 0.5 + 0.5 * sin(diagonal + fase * 0.22);
	float brillo = cresta * modulacion;

	base.rgb += vec3(0.075, 0.095, 0.045) * brillo * intensidad_onda;
	base.rgb *= 1.0 + (onda * 0.5 + 0.5 - 0.5) * intensidad_onda * 0.24;
	COLOR = base;
}
