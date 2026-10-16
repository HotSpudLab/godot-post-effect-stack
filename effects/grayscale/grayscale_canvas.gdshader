shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    float gray = dot(color.rgb, vec3(0.2125, 0.7154, 0.0721));
    COLOR = vec4(vec3(gray), color.a);
}
