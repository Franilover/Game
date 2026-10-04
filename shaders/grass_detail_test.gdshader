shader_type canvas_item;

uniform float density : hint_range(0.0, 1.0) = 0.52;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.38;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.012;
uniform float wind_speed : hint_range(0.0, 3.0) = 0.55;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.5);
    return fract(p.x * p.y);
}

float tuft(vec2 uv, vec2 cell) {
    float r = hash21(cell + 17.4);
    float r2 = hash21(cell + 43.8);
    float r3 = hash21(cell + 91.2);

    // Small pixel-art tufts rather than tall procedural blades.
    float height = mix(0.22, 0.44, r2);
    float width = mix(0.055, 0.105, r3);
    float center = 0.5 + (r - 0.5) * 0.50;

    float y = 1.0 - uv.y;
    if (y <= 0.0 || y >= height) {
        return 0.0;
    }

    float progress = y / height;

    // Two or three stepped pieces give the tuft a hand-drawn pixel shape.
    float step_y = floor(progress * 3.0) / 3.0;
    float sway = sin(TIME * wind_speed + r * 6.28318) * wind_strength;
    float x = center + sway * progress;

    // Slightly irregular sides stop every tuft from looking stamped.
    float asymmetry = (r3 - 0.5) * 0.018 * (1.0 - step_y);
    float half_width = mix(width, width * 0.35, step_y) + asymmetry;

    return step(abs(uv.x - x), half_width);
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    // Keep the effect tied to the existing grass pixels.
    float green_base = base.g - max(base.r, base.b);
    float grass_surface = smoothstep(0.012, 0.070, green_base);

    if (base.a <= 0.01) {
        COLOR = base;
    } else {
        // Two different scales create natural clusters instead of a visible grid.
        vec2 grid_a = vec2(12.0, 8.0);
    vec2 grid_b = vec2(19.0, 13.0);

    vec2 cell_a = floor(UV * grid_a);
    vec2 local_a = fract(UV * grid_a);
    vec2 cell_b = floor(UV * grid_b);
    vec2 local_b = fract(UV * grid_b);

    float pick_a = step(1.0 - density, hash21(cell_a + 7.3));
    float pick_b = step(1.0 - density * 0.55, hash21(cell_b + 31.7));

    float tuft_a = tuft(local_a, cell_a + vec2(4.2, 8.1)) * pick_a;
    float tuft_b = tuft(local_b, cell_b + vec2(13.7, 2.9)) * pick_b;

    float mask = max(tuft_a, tuft_b * 0.62) * grass_surface;

    // Derive the detail from the tile itself so it belongs to the palette.
    float variation = hash21(cell_a + 61.8);
    vec3 dark = base.rgb * mix(0.68, 0.82, variation);
    vec3 light = base.rgb + vec3(0.035, 0.045, 0.010);
    vec3 detail = mix(dark, light, step(0.52, variation));

        COLOR = vec4(mix(base.rgb, detail, mask * detail_strength), base.a);
    }
}
