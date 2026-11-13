shader_type canvas_item;

// Brillo de superficie discreto: conserva los píxeles originales y anima
// bandas suaves de luz sin desplazar UV ni deformar los bordes del atlas.
uniform float velocidad_onda : hint_range(0.0, 2.0) = 0.48;
uniform float intensidad_brillo : hint_range(0.0, 0.12) = 0.075;
uniform float escala_onda : hint_range(1.0, 120.0) = 42.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float fase = UV.y * escala_onda + TIME * velocidad_onda;
	float onda = sin(fase + sin(UV.x * 23.0 + TIME * 0.18) * 0.35);
	float destello = smoothstep(0.72, 0.98, onda * 0.5 + 0.5);
	float variacion = (onda * 0.5 + 0.5 - 0.5) * intensidad_brillo;
	base.rgb *= 1.0 + variacion;
	base.rgb += vec3(0.10, 0.15, 0.18) * destello * intensidad_brillo;
	COLOR = base;
}
