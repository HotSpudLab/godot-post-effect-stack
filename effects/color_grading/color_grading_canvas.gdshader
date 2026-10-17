shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D lut_r : source_color;
uniform sampler2D lut_g : source_color;
uniform sampler2D lut_b : source_color;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    float r = texture(lut_r, vec2(color.r, 0.5)).r;
    float g = texture(lut_g, vec2(color.g, 0.5)).g;
    float b = texture(lut_b, vec2(color.b, 0.5)).b;
    vec3 graded = vec3(r, g, b);
    COLOR = vec4(mix(color.rgb, graded, intensity), color.a);
}
