shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float strength : hint_range(0.0, 0.1) = 0.0;
uniform float radial : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = SCREEN_UV * 2.0 - 1.0;
    vec2 offset = uv * strength * (1.0 + radial * length(uv));
    
    vec4 color = texture(screen_texture, SCREEN_UV);
    float r = texture(screen_texture, SCREEN_UV + offset * vec2(1.0, 0.0)).r;
    float g = color.g;
    float b = texture(screen_texture, SCREEN_UV - offset * vec2(1.0, 0.0)).b;
    
    COLOR = vec4(r, g, b, color.a);
}
