shader_type canvas_item;

uniform vec4 blade_color : source_color = vec4(0.07, 0.15, 0.025, 1.0);
uniform vec4 blade_light : source_color = vec4(0.24, 0.38, 0.055, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.52;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.58;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.025;
uniform float wind_speed : hint_range(0.0, 3.0) = 0.65;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.5);
    return fract(p.x * p.y);
}

float pixel_blade(vec2 uv, vec2 cell, float seed, float scale) {
    float r = hash21(cell + vec2(seed, seed * 2.17));
    float r2 = hash21(cell + vec2(seed + 19.7, seed + 43.1));
    float center = 0.5 + (r - 0.5) * 0.55;
    float height = mix(0.16, 0.43, r2) * scale;
    float y = 1.0 - uv.y;

    if (y <= 0.0 || y >= height) {
        return 0.0;
    }

    float progress = y / height;
    float sway = sin(TIME * wind_speed + r * 6.28318) * wind_strength;
    float x = center + sway * progress;

    float stepped_y = floor(progress * 5.0) / 5.0;
    float stepped_width = mix(0.060, 0.010, stepped_y);
    return step(abs(uv.x - x), stepped_width);
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    if (base.a <= 0.01) {
        COLOR = base;
    } else {
        vec2 grid_a = vec2(18.0, 10.0);
        vec2 grid_b = vec2(28.0, 14.0);

        vec2 cell_a = floor(UV * grid_a);
        vec2 local_a = fract(UV * grid_a);
        vec2 cell_b = floor(UV * grid_b);
        vec2 local_b = fract(UV * grid_b);

        float ra = hash21(cell_a + 7.3);
        float rb = hash21(cell_b + 31.7);

        float blades_a = pixel_blade(local_a, cell_a, 3.1, 1.0);
        float blades_b = pixel_blade(local_b, cell_b, 8.7, 0.72);

        blades_a *= step(1.0 - density, ra);
        blades_b *= step(1.0 - density * 0.65, rb);

        float mask = max(blades_a, blades_b * 0.7);
        float color_random = hash21(cell_a + 91.4);
        vec3 grass = mix(blade_color.rgb, blade_light.rgb, color_random);

        COLOR = vec4(mix(base.rgb, grass, mask * detail_strength), base.a);
    }
}
