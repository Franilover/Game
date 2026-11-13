shader_type canvas_item;

// Líneas diagonales completamente estáticas.
// Las coordenadas globales mantienen el patrón continuo entre tiles y chunks.
varying vec2 posicion_mundo;

uniform float separacion_lineas : hint_range(24.0, 160.0) = 72.0;
uniform float grosor_linea : hint_range(1.0, 14.0) = 4.0;
uniform float contraste : hint_range(1.0, 1.8) = 1.22;

void vertex() {
	posicion_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 p = floor(posicion_mundo / 2.0) * 2.0;

	// Bandas paralelas en diagonal; no dependen de TIME ni de UV por tile.
	float diagonal = (p.x + p.y * 0.62) / separacion_lineas;
	float distancia_linea = abs(fract(diagonal) - 0.5) * separacion_lineas;
	float linea = 1.0 - smoothstep(grosor_linea, grosor_linea + 2.0, distancia_linea);

	// Separa mejor los tonos del pasto: sombras más profundas y luces más claras.
	base.rgb = (base.rgb - vec3(0.42)) * contraste + vec3(0.42);
	base.rgb = clamp(base.rgb, vec3(0.0), vec3(1.0));

	// Alternancia verde oscura / verde claro para que las líneas se distingan
	// sin tapar el dibujo original del atlas.
	float alternancia = step(0.5, fract(diagonal * 0.5));
	vec3 tono_linea = mix(vec3(0.075, 0.16, 0.055), vec3(0.48, 0.62, 0.24), alternancia);
	base.rgb = mix(base.rgb, tono_linea, linea * 0.24);

	COLOR = base;
}
