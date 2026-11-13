shader_type canvas_item;

// Variación superficial determinista para Tierra.
// Combina iluminación escalonada y matices verdes discretos.
// El patrón usa coordenadas del mundo para continuar entre tiles y chunks.
varying vec2 posicion_mundo;

uniform float escala_mancha : hint_range(0.004, 0.05, 0.001) = 0.010;
uniform float intensidad : hint_range(0.0, 0.22, 0.005) = 0.09;
uniform float escala_detalle : hint_range(0.02, 0.16, 0.002) = 0.029;
uniform float variacion_color : hint_range(0.0, 0.6, 0.01) = 0.40;

float hash_2d(vec2 p) {
	// Hash compacto sin funciones trigonométricas: más apropiado para GPU integrada.
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float ruido_valor(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash_2d(i);
	float b = hash_2d(i + vec2(1.0, 0.0));
	float c = hash_2d(i + vec2(0.0, 1.0));
	float d = hash_2d(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;

	// Cuantizar la posición evita ruido subpíxel y conserva el aspecto pixel art.
	vec2 mundo_pixel = floor(posicion_mundo / 2.0) * 2.0;
	float manchas = ruido_valor(mundo_pixel * escala_mancha);
	float detalle = ruido_valor(mundo_pixel * escala_detalle);
	float tono = mix(manchas, detalle, 0.22);

	// Cuatro niveles de iluminación, sin introducir colores ajenos al sprite.
	float tono_escalonado = floor(tono * 4.0) / 3.0;
	float variacion_luz = (tono_escalonado - 0.5) * intensidad;
	base.rgb *= 1.0 + variacion_luz;

	// Matices cálidos y terrosos forman manchas de suelo compacto y polvo.
	float zona_color = floor(manchas * 3.0) / 2.0;
	vec3 tierra_sombra = vec3(1.035, 0.965, 0.885);
	vec3 tierra_sol = vec3(1.045, 1.015, 0.925);
	vec3 tinte = mix(verde_sombra, verde_sol, zona_color);
	base.rgb *= mix(vec3(1.0), tinte, variacion_color);
	base.rgb = clamp(base.rgb, vec3(0.0), vec3(1.0));

	// La transparencia original del atlas se conserva en los bordes DualTileMap.
	COLOR = base;
}
