shader_type canvas_item;

// La textura base sigue usando UV para respetar el atlas de cada tile.
// El patrón usa coordenadas globales y permanece completamente estático.
// Todas las piezas de agua comparten las mismas ondas entre tiles y capas.
varying vec2 posicion_mundo;

uniform float intensidad_onda : hint_range(0.0, 0.35) = 0.19;
uniform float escala_onda : hint_range(0.005, 0.08) = 0.025;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;

	// Cuantización sutil para conservar el carácter pixel-art sin reiniciar
	// el patrón en los límites de cada celda.
	vec2 p = floor(posicion_mundo / 2.0) * 2.0;

	// Ondas largas y diagonales fijas que atraviesan toda la superficie continua.
	float fase = p.y * escala_onda + p.x * escala_onda * 0.34;
	float modulacion = sin(p.x * escala_onda * 0.58) * 0.42;
	float onda = sin(fase + modulacion);
	float cresta = smoothstep(0.18, 0.92, onda);

	// Reflejos secundarios con otra dirección y longitud de onda.
	float fase_reflejo = p.y * escala_onda * 1.56 - p.x * escala_onda * 0.48;
	float reflejo = smoothstep(0.70, 0.98, sin(fase_reflejo) * 0.5 + 0.5);

	float pulso = onda * 0.5 + 0.5;
	base.rgb *= 1.0 + (pulso - 0.5) * intensidad_onda;
	base.rgb += vec3(0.10, 0.17, 0.20) * cresta * intensidad_onda * 0.72;
	base.rgb += vec3(0.15, 0.21, 0.22) * reflejo * intensidad_onda * 0.48;

	COLOR = base;
}
