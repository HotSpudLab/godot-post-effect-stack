shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float line_count : hint_range(1.0, 1080.0) = 240.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float smoothness : hint_range(0.01, 2.0) = 0.5;

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    float y = SCREEN_UV.y * line_count;
    float scanline = sin(y * 3.14159265359);
    scanline = pow(abs(scanline), 1.0 / max(0.01, smoothness));
    float blend = scanline * intensity;
    COLOR = vec4(color.rgb * (1.0 - blend), color.a);
}
