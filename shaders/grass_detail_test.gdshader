shader_type canvas_item;

uniform vec4 blade_color : source_color = vec4(0.08, 0.18, 0.035, 1.0);
uniform vec4 blade_light : source_color = vec4(0.30, 0.48, 0.08, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.62;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.72;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.055;
uniform float wind_speed : hint_range(0.0, 3.0) = 0.8;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.5);
    return fract(p.x * p.y);
}

float blade(vec2 uv, vec2 cell, float seed, float scale) {
    float r = hash21(cell + vec2(seed, seed * 2.17));
    float r2 = hash21(cell + vec2(seed + 19.7, seed + 43.1));

    float center = 0.5 + (r - 0.5) * 0.58;
    float height = mix(0.28, 0.82, r2) * scale;
    float y = 1.0 - uv.y;

    if (y <= 0.0 || y >= height) {
        return 0.0;
    }

    float progress = y / height;

    // Curva muy ligera: las puntas se inclinan con el viento.
    float sway = sin(TIME * wind_speed + r * 6.28318) * wind_strength;
    float x = center + sway * progress;

    // Base más ancha, punta muy fina.
    float width = mix(0.095, 0.008, progress);
    float edge = width * 0.42;

    return 1.0 - smoothstep(width, width + edge, abs(uv.x - x));
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    if (base.a <= 0.01) {
        COLOR = base;
    } else {
        // Dos escalas: grupos principales + briznas pequeñas.
        vec2 grid_big = vec2(7.0, 4.0);
        vec2 grid_small = vec2(15.0, 8.0);

        vec2 cell_big = floor(UV * grid_big);
        vec2 local_big = fract(UV * grid_big);

        vec2 cell_small = floor(UV * grid_small);
        vec2 local_small = fract(UV * grid_small);

        float rb = hash21(cell_big + 7.3);
        float rs = hash21(cell_small + 31.7);

        float big_mask = blade(local_big, cell_big, 3.1, 1.0);
        float small_mask = blade(local_small, cell_small, 8.7, 0.62);

        // No llenamos cada celda: dejamos espacios naturales.
        big_mask *= step(1.0 - density, rb);
        small_mask *= step(1.0 - density * 0.72, rs);

        // La segunda capa queda más discreta.
        float mask = max(big_mask, small_mask * 0.58);

        float color_random = hash21(cell_big + 91.4);
        vec3 grass = mix(blade_color.rgb, blade_light.rgb, color_random);

        // El detalle se integra con el tile en vez de reemplazarlo por completo.
        vec3 result = mix(base.rgb, grass, mask * detail_strength);

        COLOR = vec4(result, base.a);
    }
}
