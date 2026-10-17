shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float time : hint_range(0.0, 1000.0) = 0.0;

float hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    vec2 uv = FRAGCOORD.xy;
    float grain = hash(vec3(uv.x, uv.y, time)) * 2.0 - 1.0;
    float lum = dot(clamp(color.rgb, 0.0, 1.0), vec3(0.2125, 0.7154, 0.0721));
    float response = 1.0 - sqrt(lum);
    color.rgb += color.rgb * grain * intensity * response;
    COLOR = color;
}
