shader_type canvas_item;

uniform sampler2D overlay : repeat_enable, filter_nearest;
uniform float pattern_size : hint_range(32.0, 1024.0) = 256.0;
uniform float strength : hint_range(0.0, 1.0) = 0.42;

varying vec2 world_position;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    if (base.a <= 0.01) {
        COLOR = base;
    } else {
        float green_base = base.g - max(base.r, base.b);
        float grass_surface = smoothstep(0.012, 0.070, green_base);

        // Cada bloque del mundo tiene una orientación distinta.
        // Esto rompe la sensación de patrón repetido sin perder el aspecto pixel-art.
        vec2 pattern_position = world_position / pattern_size;
        vec2 cell = floor(pattern_position);
        vec2 local_uv = fract(pattern_position);

        float variation = hash(cell);
        float rotation = floor(variation * 4.0);

        vec2 rotated_uv = local_uv;
        if (rotation < 1.0) {
            rotated_uv = vec2(local_uv.y, 1.0 - local_uv.x);
        } else if (rotation < 2.0) {
            rotated_uv = vec2(1.0 - local_uv.x, 1.0 - local_uv.y);
        } else if (rotation < 3.0) {
            rotated_uv = vec2(1.0 - local_uv.y, local_uv.x);
        }

        // Algunas zonas se espejan para añadir todavía más variación.
        if (hash(cell + vec2(41.0, 17.0)) > 0.55) {
            rotated_uv.x = 1.0 - rotated_uv.x;
        }

        vec2 overlay_uv = rotated_uv;
        vec4 detail = texture(overlay, overlay_uv);

        float amount = detail.a * grass_surface * strength;
        COLOR = vec4(mix(base.rgb, detail.rgb, amount), base.a);
    }
}