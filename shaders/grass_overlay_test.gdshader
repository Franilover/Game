shader_type canvas_item;

uniform sampler2D overlay : repeat_enable, filter_nearest;
uniform float tile_size : hint_range(8.0, 256.0) = 32.0;
uniform float strength : hint_range(0.0, 1.0) = 0.42;

varying vec2 world_position;

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

        vec2 overlay_uv = world_position / tile_size;
        vec4 detail = texture(overlay, overlay_uv);

        float amount = detail.a * grass_surface * strength;
        COLOR = vec4(mix(base.rgb, detail.rgb, amount), base.a);
    }
}